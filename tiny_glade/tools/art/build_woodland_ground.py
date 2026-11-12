"""Bake the woodland floor and snow pigments. Run with standard-library Python 3."""

from math import cos, sin, sqrt, tau
from pathlib import Path
import random
import struct
import zlib


SIZE = 256
DEST = Path(__file__).resolve().parents[2] / "assets/materials/woodland_ground"


def png(path, pixels):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    raw = b"".join(b"\0" + pixels[i:i + SIZE * 3] for i in range(0, len(pixels), SIZE * 3))
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                     + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def wash(base, strength):
    result = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            u, v = x * tau / SIZE, y * tau / SIZE
            broad = 0.55 * sin(2*u + v + 1.8*cos(v)) + 0.31 * sin(u - 3*v) + 0.14 * cos(6*u - 5*v)
            result.extend(round(c + broad * s) for c, s in zip(base, strength))
    return result


def paint_strokes(image, seed, count, palette, lengths):
    # Small tapered marks wrap over the edge so all four sides tile continuously.
    rng = random.Random(seed)
    for _ in range(count):
        cx, cy = rng.randrange(SIZE), rng.randrange(SIZE)
        length = rng.uniform(*lengths)
        width = rng.uniform(0.9, 2.9)
        angle = 0.5 + 0.75 * sin(tau * cy / SIZE) + rng.uniform(-0.6, 0.6)
        pigment = rng.choice(palette)
        bound = int(length + width) + 1
        for dy in range(-bound, bound + 1):
            for dx in range(-bound, bound + 1):
                a = (dx * cos(angle) + dy * sin(angle)) / length
                b = (dy * cos(angle) - dx * sin(angle)) / width
                opacity = max(0.0, 1.0 - abs(a) - b*b) * 0.54
                if opacity:
                    index = (((cy + dy) % SIZE) * SIZE + (cx + dx) % SIZE) * 3
                    for channel, color in enumerate(pigment):
                        old = image[index + channel]
                        image[index + channel] = round(old + (color - old) * opacity)


def snow_maps():
    # Wind flutes and rounded grains use the same height samples for pigment and normals.
    rng = random.Random(3725)
    heights = []
    color = bytearray()
    normal = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            u, v = x * tau / SIZE, y * tau / SIZE
            drift = 0.42*cos(2*u + 3*v + 1.6*sin(2*v)) + 0.21*cos(3*u - v)
            grain = rng.random() * 0.15 + 0.10 * cos(13*u + 9*v + 3*sin(6*v))
            h = drift + grain
            heights.append(h)
            color.extend((round(225 + h*13), round(231 + h*9), round(231 + h*5)))
    for y in range(SIZE):
        for x in range(SIZE):
            dx = heights[y*SIZE + (x-1)%SIZE] - heights[y*SIZE + (x+1)%SIZE]
            dy = heights[((y-1)%SIZE)*SIZE + x] - heights[((y+1)%SIZE)*SIZE + x]
            inv = 1.0 / sqrt(dx*dx + dy*dy + 0.36)
            normal.extend(round(127.5 + 127.5*c*inv) for c in (dx, dy, 0.60))
    return color, normal


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    grass = wash((139, 166, 94), (14, 10, 9))
    paint_strokes(grass, 7539, 1450, [(101, 142, 87), (171, 183, 102), (150, 178, 105)], (3, 11))
    soil = wash((138, 126, 94), (10, 9, 8))
    paint_strokes(soil, 7382, 920, [(120, 106, 79), (162, 148, 111), (131, 142, 92)], (2, 8))
    frost, frost_normal = snow_maps()
    for name, pixels in [("grass_wash", grass), ("leaf_mould", soil),
                         ("snow_drift", frost), ("snow_drift_normal", frost_normal)]:
        png(DEST / (name + ".png"), pixels)


if __name__ == "__main__":
    main()
