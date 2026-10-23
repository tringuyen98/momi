#!/usr/bin/env python3
"""Generate Momi's simple leaf mark with no external image dependencies."""
from pathlib import Path
import json
import math
import struct
import zlib

root = Path(__file__).resolve().parents[1]
size = 1024
rows = bytearray()
cream = (246, 241, 233)
green = (76, 110, 87)
rose = (212, 163, 150)

def ellipse(x, y, cx, cy, rx, ry, angle):
    a = math.radians(angle)
    dx, dy = x - cx, y - cy
    u, v = dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)
    return (u / rx) ** 2 + (v / ry) ** 2 <= 1

for py in range(size):
    rows.append(0)
    y = py / size
    for px in range(size):
        x = px / size
        color = cream
        if ellipse(x, y, .40, .43, .115, .235, -38):
            color = green
        if ellipse(x, y, .64, .42, .105, .195, 38):
            color = rose
        # Stem and soft bottom tip.
        if .505 <= x <= .535 and .47 <= y <= .77 or ellipse(x, y, .52, .77, .015, .015, 0):
            color = green
        rows.extend(color)

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b'')
destination = root / 'Momi/Resources/Assets.xcassets/AppIcon.appiconset'
destination.mkdir(exist_ok=True)
(destination / 'AppIcon.png').write_bytes(png)
(destination / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2))
print('Generated 1024px app icon.')
