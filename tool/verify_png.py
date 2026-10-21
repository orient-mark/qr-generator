"""Optional full-image decoding check using native ZXing, without cropping or hints.

python -m pip install --target .dart_tool/verification zxing-cpp Pillow
python tool/verify_png.py path/to/labeled-pngs

The folder must contain en_CP_31.png through ru_CLEAR.png.
"""
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / '.dart_tool/verification'))
from PIL import Image
import zxingcpp

if len(sys.argv) != 2:
    raise SystemExit('Usage: python tool/verify_png.py path/to/labeled-pngs')
folder = Path(sys.argv[1]).resolve()

count = 0
for language in ('en', 'ru'):
    for point in [*(f'CP_{n}' for n in range(31, 100)), 'START', 'FINISH', 'CLEAR']:
        path = folder / f'{language}_{point}.png'
        expected = {'point': {'checkpoint': int(point[3:])}} if point.startswith('CP_') else {'point': {'START': 'start', 'FINISH': 'finish', 'CLEAR': 'cleaning'}[point]}
        with Image.open(path) as image:
            codes = zxingcpp.read_barcodes(image)
        assert len(codes) == 1, f'{path.name}: found {len(codes)} QR codes'
        assert json.loads(codes[0].text) == expected, f'{path.name}: wrong payload'
        count += 1
print(f'{count} full PNG files decoded successfully with native ZXing.')
