"""Rebuild the Windows app icon (requires Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent
image = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((8, 8, 248, 248), radius=62, fill='#176B52')
for x, y in ((48, 48), (144, 48), (48, 144)):
    draw.rectangle((x, y, x + 63, y + 63), fill='white')
    draw.rectangle((x + 11, y + 11, x + 52, y + 52), fill='#176B52')
    draw.rectangle((x + 22, y + 22, x + 41, y + 41), fill='white')
for x, y in ((126, 126), (151, 126), (176, 126), (126, 151), (176, 151), (126, 176), (151, 176), (176, 176), (201, 176), (176, 201)):
    draw.rectangle((x, y, x + 15, y + 15), fill='white')
image.save(root / 'windows/runner/resources/app_icon.ico', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
