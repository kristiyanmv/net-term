# ...new file...

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import sys

OUT = Path(r"c:\Users\Kris\Documents\Masters\net-term\net-term.srcs\sources_1\test_data\font_printable.coe")

# try common open-source monospace fonts; change FONT_PATH to a TTF you prefer
CANDIDATES = [
    r"C:\Windows\Fonts\DejaVuSansMono.ttf",
    r"C:\Windows\Fonts\consola.ttf",
    r"C:\Windows\Fonts\Consola.ttf",
    r"C:\Windows\Fonts\lucon.ttf"
]
FONT_PATH = None
for p in CANDIDATES:
    if Path(p).exists():
        FONT_PATH = p
        break
if FONT_PATH is None:
    print("No candidate font found. Edit FONT_PATH in the script to point to a monospace TTF.")
    sys.exit(1)

W, H = 8, 16
# choose size that best fits 8x16 in the chosen TTF; adjust if glyphs clip
font = ImageFont.truetype(FONT_PATH, 14)

printable_codes = list(range(0x20, 0x7F))  # 0x20..0x7E inclusive
bytes_out = []

for code in printable_codes:
    ch = chr(code)
    img = Image.new("L", (W, H), 0)  # black background
    draw = ImageDraw.Draw(img)

    tw, th = draw.textsize(ch, font=font)
    x = max(0, (W - tw) // 2)
    y = max(0, (H - th) // 2)
    draw.text((x, y), ch, fill=255, font=font)

    for row in range(H):
        row_byte = 0
        for bit in range(W):
            px = img.getpixel((bit, row))
            if px > 128:
                row_byte |= (1 << (7 - bit))  # MSB = leftmost pixel
        bytes_out.append(f"{row_byte:02X}")

# Write COE header and only the printable glyph bytes
with OUT.open("w") as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    # 16 bytes per row for readability
    for i in range(0, len(bytes_out), 16):
        f.write(",".join(bytes_out[i:i+16]) + ",\n")
    f.write(";\n")

print(f"Wrote {OUT.resolve()} ({len(bytes_out)} bytes) using {FONT_PATH}")
# ...new file...