"""Bake the two tiled 3-D fields used by the woodland cloud shader (stdlib only)."""

import math
import random
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets/woodland/clouds"


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def write_volume(name, side, sample):
    # Each square is an XY slice. Godot's 3d_texture importer stacks these along Z.
    row_data = bytearray()
    for y in range(side):
        row_data.append(0)
        for z in range(side):
            for x in range(side):
                row_data.extend(sample(x, y, z))
    header = struct.pack(">IIBBBBB", side * side, side, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
    png += chunk(b"IDAT", zlib.compress(row_data, 9)) + chunk(b"IEND", b"")
    (OUT / (name + ".png")).write_bytes(png)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    side = 32
    phase = math.tau / side

    def curl(x, y, z):
        # A smooth periodic, divergence-free field. The vertical term is quieter.
        def channel(a, b):
            return round(127.5 + 61 * (math.cos(phase * a) - math.sin(phase * b)))
        return channel(y + z, y - z), channel(z + x, z - x), channel(x + y, x - y)

    rng = random.Random(3662)
    ranks = list(range(side * side))
    slices = []
    for _ in range(side):
        rng.shuffle(ranks)
        slices.append(bytes(value * 255 // (side * side - 1) for value in ranks))
    write_volume("wisps", side, curl)
    write_volume("sampling", side, lambda x, y, z: (slices[z][y * side + x],) * 3)


if __name__ == "__main__":
    main()
