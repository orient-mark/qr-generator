# Testing

[Русский](TESTING.ru.md#тестирование)

## Verification scope

The tests check the course point model's QR data contract, pagination, and file
exports. Exported images are decoded independently of the generator.
PDF checks inspect the saved pages: dimensions, page counts, and QR contents.

| Area | Files |
|---|---|
| Course point model and data contract | [test/course_qr_test.dart](../test/course_qr_test.dart) |
| PNG export and QR decoding | [test/qr_exporter_test.dart](../test/qr_exporter_test.dart) |
| Layout geometry, pagination, and PDF export | [test/print_exporter_test.dart](../test/print_exporter_test.dart), [tool/verify_pdf.py](../tool/verify_pdf.py) |
| Screen interactions | [test/widget_test.dart](../test/widget_test.dart) |
| Shared test setup | [test/fonts.dart](../test/fonts.dart), [test/output_directory.dart](../test/output_directory.dart) |
| Additional full-image PNG checks | [tool/verify_png.py](../tool/verify_png.py) |
| Portable EXE startup and cleanup | [tool/test_portable.ps1](../tool/test_portable.ps1) |

## Setup and execution

Run from the project root. PDF verification requires Python 3, Pillow, zxing-cpp,
and Poppler (`pdfinfo` and `pdftoppm` available on PATH).

```powershell
flutter pub get
python -m pip install --target .dart_tool/verification Pillow zxing-cpp
flutter test --no-pub --concurrency=1
```

To select another Python executable, set `ORIENTMARK_TEST_PYTHON`.
The PDF test invokes `tool/verify_pdf.py` automatically and fails if the required
tools are unavailable or the exported pages do not match the expected size,
count, or QR contents.
File export tests use unique temporary directories and remove them afterward.

## Decoding tools

**zxing2** independently decodes QR codes in the PNG tests.
**zxing-cpp** reads QR codes from saved PDF pages rendered to images by Poppler.
This verifies the saved output independently of the generator and layout.

Component licenses are listed in [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md#third-party-licenses).
