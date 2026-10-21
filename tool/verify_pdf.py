"""Verify exported PDF pages and their QR contents independently of Flutter.

Usage: python tool/verify_pdf.py path/to/manifest.json
Requires Pillow, zxing-cpp, and Poppler's pdfinfo/pdftoppm on PATH.
Optional local packages: python -m pip install --target .dart_tool/verification Pillow zxing-cpp
"""
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / ".dart_tool" / "verification"))
from PIL import Image
import zxingcpp


def normalized_payload(value):
    return json.dumps(json.loads(value), sort_keys=True)


def verify(manifest_path):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not manifest:
        raise AssertionError("The PDF manifest is empty")
    folder = manifest_path.parent / "OrientMark QR"
    total_pages = total_codes = 0
    for name, expected in manifest.items():
        pdf = folder / name
        info = subprocess.run(
            ["pdfinfo", str(pdf)], check=True, capture_output=True, text=True
        ).stdout
        page_count = int(re.search(r"Pages:\s+(\d+)", info).group(1))
        assert page_count == len(expected["pages"]), (name, page_count)
        for page_index, payloads in enumerate(expected["pages"], start=1):
            page_info = subprocess.run(
                ["pdfinfo", "-f", str(page_index), "-l", str(page_index), str(pdf)],
                check=True, capture_output=True, text=True,
            ).stdout
            size = re.search(
                r"(?:Page\s+\d+\s+size|Page size):\s+([\d.]+) x ([\d.]+)",
                page_info,
            )
            assert size, (name, page_index, "missing page size")
            assert abs(float(size.group(1)) / 72 * 25.4 - expected["width"]) < 0.1
            assert abs(float(size.group(2)) / 72 * 25.4 - expected["height"]) < 0.1
            with tempfile.TemporaryDirectory(prefix="orientmark-pdf-page-") as temporary:
                prefix = Path(temporary) / "page"
                subprocess.run(
                    ["pdftoppm", "-f", str(page_index), "-l", str(page_index),
                     "-singlefile", "-r", "150", "-png", str(pdf), str(prefix)],
                    check=True, capture_output=True,
                )
                with Image.open(prefix.with_suffix(".png")) as original:
                    image = original.convert("RGB")
                try:
                    codes = zxingcpp.read_barcodes(image)
                    actual = Counter(normalized_payload(code.text) for code in codes)
                    wanted = Counter(normalized_payload(value) for value in payloads)
                    assert actual == wanted, (name, page_index, actual, wanted)
                    if "Small" in name and len(payloads) in (3, 4):
                        blank = image.crop(
                            (0, round(image.height * 105 / 210), image.width, image.height)
                        )
                        try:
                            assert blank.getextrema() == ((255, 255),) * 3, (
                                name, "odd remainder is not blank"
                            )
                        finally:
                            blank.close()
                finally:
                    image.close()
            total_codes += len(codes)
            total_pages += 1
        print(f"{name}: {page_count} pages, QR payloads verified", flush=True)
    print(f"Verified {len(manifest)} PDFs, {total_pages} A4 pages, {total_codes} QR codes")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python tool/verify_pdf.py path/to/manifest.json")
    verify(Path(sys.argv[1]).resolve())
