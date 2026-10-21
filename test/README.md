# Local verification

Run from the project root. PDF verification requires Python 3, Pillow, zxing-cpp, and Poppler (`pdfinfo` and `pdftoppm` available on PATH).

```powershell
python -m pip install --target .dart_tool/verification Pillow zxing-cpp
flutter test --no-pub --concurrency=1
```

To select another Python executable, set `ORIENTMARK_TEST_PYTHON`.
The PDF test invokes `tool/verify_pdf.py` automatically and fails if the required tools are unavailable or the exported pages do not match the expected size, count, or QR contents.
File export tests use unique temporary directories and remove them afterward.
