"""Repaint the repeating timber and fieldstone used on garden props, paths and bridges."""

import math
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "materials" / "woodland_cabin"


def pigment(u, v, stone):
    # Integer frequencies on the torus keep the brush marks continuous at each seam.
    wash = math.cos(2 * u - v + math.sin(v))
    if stone:
        fleck = math.sin(19 * u + 12 * v + 2 * math.sin(7 * v))
        grain = math.sin(4 * u + 8 * v + 2 * math.sin(3 * v - u))
        lichen = max(0.0, wash + 0.48 * math.sin(3 * v + 4 * u) - 0.62)
        shade = 4.0 * wash + 3.4 * grain + 1.6 * fleck
        return 160 + shade - 10 * lichen, 159 + shade - 2 * lichen, 147 + shade - 12 * lichen
    fibre = 19 * u + 1.6 * math.sin(2 * v - u) + 0.75 * math.sin(v + 3 * u)
    split = max(0.0, math.sin(fibre) - 0.70) * (0.6 + 0.4 * math.sin(3 * v + u))
    grain = math.sin(3 * u + math.sin(v)) + 0.32 * math.sin(2 * fibre)
    shade = 5.3 * grain + 2.2 * wash - 20.0 * split
    return 122 + shade, 102 + shade * 0.88, 80 + shade * 0.76


def chunk(name, payload):
    data = name + payload
    return struct.pack(">I", len(payload)) + data + struct.pack(">I", zlib.crc32(data))


def paint(path, stone):
    size = 256
    axis = [math.tau * i / size for i in range(size)]
    pixels = bytearray()
    for v in axis:
        pixels.append(0)
        for u in axis:
            pixels.extend(round(channel) for channel in pigment(u, v, stone))
    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
                     + chunk(b"sRGB", b"\0") + chunk(b"IDAT", zlib.compress(pixels, 9))
                     + chunk(b"IEND", b""))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    paint(OUT / "weathered_oak.png", False)
    paint(OUT / "fieldstone.png", True)
