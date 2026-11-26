"""Turns font8x8_basic.h (public domain) into data/fonts/font8x8.png: a 16x8 grid of 8x8 glyphs for
ASCII 0-127, white on transparent. Cell 0 (NUL) is a solid block, used to draw filled rectangles.

usage: python3 tools/fonts/font8x8_to_png.py third_party/font8x8/font8x8_basic.h data/fonts/font8x8.png
"""
import re
import struct
import sys
import zlib

source, target = sys.argv[1], sys.argv[2]
rows = re.findall(r"\{((?:\s*0x[0-9A-Fa-f]{2},?){8})\s*\}", open(source).read())
glyphs = [[int(b, 16) for b in re.findall(r"0x([0-9A-Fa-f]{2})", r)] for r in rows][:128]
assert len(glyphs) == 128, len(glyphs)
glyphs[0] = [0xFF] * 8

W, H = 128, 64
pixels = bytearray(W * H * 4)
for code, glyph in enumerate(glyphs):
    cx, cy = (code % 16) * 8, (code // 16) * 8
    for y, bits in enumerate(glyph):
        for x in range(8):
            if bits & (1 << x):  # bit 0 is the leftmost pixel
                i = ((cy + y) * W + cx + x) * 4
                pixels[i:i + 4] = b"\xff\xff\xff\xff"

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

raw = b"".join(b"\x00" + bytes(pixels[y * W * 4:(y + 1) * W * 4]) for y in range(H))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)) + \
      chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
open(target, "wb").write(png)
print(f"wrote {target}")
