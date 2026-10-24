"""Reproducible art-direction pass 01: painted, layered P0 forest plants.

Blender 5.1.2, no add-ons. Run with ``--background --python ... -- --root ROOT``.
Only writes art_source/art_pass_01/nature and assets/nature/art_pass_01.
Joined opaque crown volumes carry the large values; a restrained layer of painted
leaf clusters breaks their edges without turning the canopy into floating scraps.
"""

import argparse
import hashlib
import json
import math
import random
import struct
import sys
import zlib
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector


PARSER = argparse.ArgumentParser()
PARSER.add_argument("--root", required=True)
PARSER.add_argument("--preview", action="store_true")
PARSER.add_argument("--preview-lod", action="store_true")
PARSER.add_argument("--audit-only", action="store_true")
ARGS = PARSER.parse_args(sys.argv[sys.argv.index("--") + 1 :])
ROOT = Path(ARGS.root).resolve()
SOURCE = ROOT / "art_source/art_pass_01/nature"
EXPORT = ROOT / "assets/nature/art_pass_01"
SOURCE.mkdir(parents=True, exist_ok=True)
EXPORT.mkdir(parents=True, exist_ok=True)
SEED = 251019
RNG = random.Random(SEED)
TAU = math.tau


def write_png(path, array):
    """Store paint bytes without a display transform or third-party image package."""
    height, width, _ = array.shape
    raw = b"".join(b"\0" + row.tobytes() for row in array)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">2I5B", width, height, 8, 6, 0, 0, 0))
        + chunk(b"sRGB", b"\0")
        + chunk(b"IDAT", zlib.compress(raw, 8))
        + chunk(b"IEND", b"")
    )


def paint_atlas():
    """One editable recipe produces the shared 2K MAT-03 replacement.

    Tiles: 0/1/2 broad leaves, 3 fruit-tree leaves, 4 pine sprig,
    5 meadow blade, 6 daisy, 7 lavender, 8 bark, 9 limestone,
    10 moss, 11 opaque pine needles, 12 fern leaflet, 13 warm fruit,
    14 opaque leaf mass, 15 high-coverage LOD compound crown.
    RGB extends under zero alpha: no white fringes in mipmaps.
    """
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    x, y = (xx + 0.5) / size, 1 - (yy + 0.5) / size
    tiles = []
    colors = [
        (111, 139, 91), (87, 118, 80), (63, 96, 74), (103, 134, 86),
        (59, 94, 79), (104, 130, 79), (235, 225, 195), (147, 137, 174),
        (107, 96, 76), (151, 152, 135), (88, 115, 69), (65, 99, 77),
        (100, 131, 82), (190, 113, 49), (81, 113, 80), (108, 136, 91),
    ]
    for index, base in enumerate(colors):
        rr = np.random.default_rng(SEED + index * 31)
        noise = (
            0.55 * np.sin(x * 29 + np.sin(y * 13) * 2)
            + 0.40 * np.sin(y * 43 + x * 9)
            + 0.25 * np.sin(x * 112 + y * 73)
            + rr.normal(0, 0.15, x.shape)
        )
        rgb = np.zeros((size, size, 3), dtype=np.float32) + np.array(base)
        alpha = np.ones(x.shape, dtype=np.float32)
        rgb += noise[..., None] * np.array([2.4, 2.7, 2.0])
        if index in [0, 1, 2, 3, 4, 11, 14, 15]:
            # Value masses come first. Their size is deliberately larger than an
            # individual leaf so distant mipmaps retain cool shade and lit planes.
            broad = np.sin(x * 7.2 + np.sin(y * 4.7)) + np.cos(y * 8.0 - x * 2.2)
            broad = np.tanh(broad * 1.3)
            rgb += broad[..., None] * np.array([8, 11, 7])
            rgb += (y - 0.46)[..., None] * np.array([15, 20, 10])
            for _ in range(16):
                cx, cy = rr.uniform(-0.12, 1.12, 2)
                sx, sy = rr.uniform(0.09, 0.24), rr.uniform(0.05, 0.15)
                wash = np.clip((1 - ((x - cx) / sx) ** 2 - ((y - cy) / sy) ** 2) * 2, 0, 1)
                tint = np.array([8, 12, 11]) if cy < 0.48 else np.array([16, 18, 9])
                rgb += wash[..., None] * tint * rr.uniform(-0.7, 0.8)
        if index in [0, 1, 2, 3, 4, 15]:
            # Interlocking paint shapes give an airy edge around a joined centre.
            # No dark central twig or repeated bright veins cut across the value.
            alpha = np.zeros(x.shape, dtype=np.float32)
            sprigs = []
            centres = [(-0.19, -0.22), (0.17, -0.21), (-0.21, 0.04), (0.20, 0.06), (-0.10, 0.27), (0.12, 0.29)]
            for group, (cx, cy) in enumerate(centres):
                for j in range(8):
                    angle = j * 2.399963 + group * 0.27
                    reach = math.sqrt((j + 0.5) / 8) * 0.115
                    sprigs.append((cx + math.cos(angle) * reach, cy + math.sin(angle) * reach * 0.75, angle + 0.4))
            if index == 4:
                sprigs = [(sign * (0.23 - j * 0.033), -0.25 + j * 0.087, sign * 0.79) for j in range(7) for sign in [-1, 1]]
            elif index == 15:
                # The same silhouette/value family avoids a distant colour pop.
                sprigs += [(-0.08, -0.03, -0.70), (0.07, 0.10, 0.64)]
            for number, (cx, cy, angle) in enumerate(sprigs):
                dx, dy = x - (0.50 + cx), y - (0.49 + cy)
                lx = dx * math.cos(angle) - dy * math.sin(angle)
                ly = dx * math.sin(angle) + dy * math.cos(angle)
                length = 0.23 if index != 4 else 0.27
                width = 0.105 if index != 4 else 0.095
                t = np.clip(ly / length + 0.5, 0, 1)
                w = np.sin(t * math.pi).clip(0, 1) ** 0.69 * width
                if index in [0, 1]:
                    w *= 0.90 + 0.10 * np.sin(t * 11 * math.pi)
                if index == 4:
                    w *= 0.84 + 0.16 * np.sin(t * 17 * math.pi) ** 2
                coverage = np.clip((w - abs(lx)) * 900, 0, 1) * (abs(ly) < length * 0.49)
                edge = abs(lx) / np.maximum(w, 0.001)
                colour = np.zeros_like(rgb) + np.array(base)
                light = 4 * t + (1 - edge.clip(0, 1)) * 3 + cy * 15 + (number % 5 - 2) * 2.5
                colour += light[..., None] * np.array([0.85, 1, 0.65])
                colour += broad[..., None] * np.array([5, 7, 6])
                colour += noise[..., None] * 1.2
                for dab in range(3):
                    paint_mark = np.exp(-(((lx - (dab - 1) * 0.045) / 0.036) ** 2 + ((ly - (dab % 2 - 0.5) * 0.09) / 0.065) ** 2))
                    colour += paint_mark[..., None] * np.array([6, 9, 5]) * (1 if (number + dab) % 3 else -1)
                rgb = rgb * (1 - coverage[..., None]) + colour * coverage[..., None]
                alpha = np.maximum(alpha, coverage)
        elif index in [5, 12]:
            t = np.clip((y - 0.06) / 0.88, 0, 1)
            width = np.power(np.maximum(np.sin(t * math.pi), 0), 0.72) * 0.365
            if index in [0, 1]:
                width *= 0.91 + 0.09 * np.sin(t * 11 * math.pi)
            if index == 4:
                width *= 0.70 + 0.30 * np.sin(t * 15 * math.pi) ** 2
            if index == 5:
                width *= 0.35
            if index == 12:
                width *= 0.81 + 0.19 * np.sin(t * 17 * math.pi) ** 2
            centre = 0.5 + np.sin(t * math.pi) * 0.026
            edge = np.abs(x - centre) / np.maximum(width, 0.001)
            alpha = np.clip((1 - edge) * 130, 0, 1) * ((y > 0.055) & (y < 0.945))
            rgb += ((1 - edge.clip(0, 1)) * 9 + y * 13 - 9)[..., None]
            midrib = np.exp(-((x - centre) / 0.006) ** 2) * (y > 0.09) * (y < 0.9)
            rgb += midrib[..., None] * np.array([20, 22, 7])
            for vein in np.linspace(0.18, 0.82, 7):
                for side in [-1, 1]:
                    vx = x - centre
                    line = vein + side * vx * 0.58
                    stroke = np.exp(-((y - line) / 0.004) ** 2)
                    stroke *= (side * vx > 0.015) & (edge < 0.86)
                    rgb += stroke[..., None] * np.array([11, 13, 3])
        elif index == 6:
            # Painted daisy head. Geometry retains scallops even at small mip levels.
            dx, dy = x - 0.5, y - 0.5
            radius = np.sqrt(dx * dx + dy * dy)
            theta = np.arctan2(dy, dx)
            limit = 0.31 + 0.12 * np.power(np.cos(theta * 5), 2)
            alpha = np.clip((limit - radius) * 160, 0, 1)
            rgb += (radius * 24)[..., None]
            heart = np.clip((0.105 - radius) * 180, 0, 1)
            rgb = rgb * (1 - heart[..., None]) + np.array([203, 164, 63]) * heart[..., None]
        elif index == 7:
            dx, dy = (x - 0.5) / 0.27, (y - 0.5) / 0.40
            edge = dx * dx + dy * dy
            alpha = np.clip((1 - edge) * 120, 0, 1)
            rgb += (y * 12 - x * 6)[..., None]
        elif index == 8:
            # Broad brush marks with drifting bark fissures, no photographic grain.
            for line in np.linspace(0.04, 0.96, 13):
                drift = line + 0.014 * np.sin(y * 15 + line * 73)
                crease = np.exp(-((x - drift) / 0.008) ** 2)
                shoulder = np.exp(-((x - drift - 0.015) / 0.015) ** 2)
                rgb -= crease[..., None] * np.array([9, 9, 7])
                rgb += shoulder[..., None] * np.array([7, 7, 5])
            rgb += (np.sin(y * 8) * 2)[..., None]
            # Pale, slightly mossy root-side wash.
            rgb = rgb * (0.96 + y[..., None] * 0.04)
        elif index == 11:
            # Opaque, directional pine-bough brush marks survive distant mipmaps.
            for _ in range(72):
                cx, cy = rr.uniform(-0.1, 1.1, 2)
                angle = rr.uniform(-0.88, 0.88)
                dx = (x - cx) * math.cos(angle) - (y - cy) * math.sin(angle)
                dy = (x - cx) * math.sin(angle) + (y - cy) * math.cos(angle)
                width, length = rr.uniform(0.025, 0.050), rr.uniform(0.06, 0.15)
                stroke = np.clip((1 - (dx / width) ** 2 - (dy / length) ** 2) * 4, 0, 1)
                value = rr.uniform(-9, 13)
                rgb += stroke[..., None] * np.array([value * 0.72, value, value * 0.76])
        elif index == 9:
            for _ in range(48):
                cx, cy = rr.uniform(-0.15, 1.15, 2)
                sx, sy = rr.uniform(0.025, 0.16, 2)
                patch = np.exp(-(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2))
                tint = np.array([1, 1, 0.8]) * rr.uniform(-16, 18)
                rgb += patch[..., None] * tint
            for _ in range(12):
                cx, cy = rr.uniform(-0.2, 1.2, 2)
                sx, sy = rr.uniform(0.06, 0.25, 2)
                wash = np.clip((1 - ((x - cx) / sx) ** 2 - ((y - cy) / sy) ** 2) * 2, 0, 1)
                value = rr.uniform(-20, 20)
                rgb += wash[..., None] * np.array([value, value * 0.94, value * 0.68])
            for line in [0.21, 0.64]:
                fissure = line + np.sin(x * 13 + line * 19) * 0.018 + np.sin(x * 43) * 0.006
                mark = np.exp(-((y - fissure) / 0.0023) ** 2)
                mark *= (np.sin(x * 15 + line * 20) > -0.15)
                rgb -= mark[..., None] * np.array([28, 25, 18])
            rgb += (y * 7)[..., None]
        elif index == 10:
            for _ in range(100):
                cx, cy = rr.uniform(0, 1, 2)
                patch = np.exp(-(((x - cx) / 0.032) ** 2 + ((y - cy) / 0.019) ** 2))
                rgb += patch[..., None] * np.array([17, 19, 2])
            pattern = np.sin(x * 12 + np.sin(y * 23) * 1.2) + np.cos(y * 17 + np.sin(x * 9))
            pattern += np.sin(x * 71 + y * 63) * 0.23
            alpha = np.clip((pattern + 0.58) * 5, 0, 1)
        elif index == 13:
            edge = np.sqrt(((x - 0.5) / 0.44) ** 2 + ((y - 0.5) / 0.43) ** 2)
            rgb += (15 * y - edge * 8)[..., None]
            blush = np.exp(-(((x - 0.34) / 0.29) ** 2 + ((y - 0.63) / 0.34) ** 2))
            rgb += blush[..., None] * np.array([13, -12, -4])
        else:
            # Opaque watercolor leaf masses with overlapping brush-shaped leaves.
            # A twig's numerous leaves read as one painterly value from far away.
            for _ in range(112):
                cx, cy = rr.uniform(-0.08, 1.08, 2)
                angle = rr.uniform(0, TAU)
                dx = (x - cx) * math.cos(angle) + (y - cy) * math.sin(angle)
                dy = -(x - cx) * math.sin(angle) + (y - cy) * math.cos(angle)
                width, length = rr.uniform(0.025, 0.058), rr.uniform(0.045, 0.095)
                stroke = np.clip((1 - (dx / width) ** 2 - (dy / length) ** 2) * 6.0, 0, 1)
                value = rr.uniform(-23, 28)
                rgb += stroke[..., None] * np.array([value * 0.83, value, value * 0.73])
        rgba = np.empty((size, size, 4), dtype=np.uint8)
        rgba[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        rgba[:, :, 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
        tiles.append(rgba)
    image = np.concatenate(
        [np.concatenate(tiles[row * 4 : row * 4 + 4], axis=1) for row in [3, 2, 1, 0]], axis=0
    )
    write_png(SOURCE / "painted_forest_atlas.png", image)
    write_png(EXPORT / "painted_forest_atlas.png", image)
    (SOURCE / "atlas_recipe.json").write_text(
        json.dumps({"seed": SEED, "size": 2048, "tiles": colors, "author": "Project original procedural brush painting", "generator": "tools/art/build_art_foliage.py", "rgba": "RGB is extended through transparent texels; COLOR_0 is wind data, not tint"}, indent=2) + "\n"
    )


def uv_tile(tile, u, v):
    padding = 0.012
    return ((tile % 4 + padding + u * (1 - 2 * padding)) / 4, (tile // 4 + padding + v * (1 - 2 * padding)) / 4)


class MeshBuilder:
    def __init__(self, name, tile=0):
        self.name = name
        self.tile = tile
        self.vertices = []
        self.faces = []
        self.uvs = []
        self.colors = []
        self.normals = []

    def vert(self, point, uv=(0.5, 0.5), wind=0, phase=0, fruit=0, normal=None, tile=None):
        index = len(self.vertices)
        self.vertices.append(tuple(point))
        self.uvs.append(uv_tile(self.tile if tile is None else tile, *uv))
        self.colors.append((float(wind), float(phase), float(fruit), 1))
        self.normals.append(tuple(normal) if normal is not None else (0, 0, 0))
        return index

    def face(self, *indices):
        self.faces.append(tuple(indices))

    def finish(self, mat):
        if not self.vertices:
            return None
        data = bpy.data.meshes.new(self.name + "Mesh")
        data.from_pydata(self.vertices, [], self.faces)
        data.update()
        uv = data.uv_layers.new(name="UVMap")
        color = data.color_attributes.new(name="wind_mask", type="FLOAT_COLOR", domain="POINT")
        for index, value in enumerate(self.colors):
            color.data[index].color = value
        for polygon in data.polygons:
            polygon.use_smooth = True
            for index in polygon.loop_indices:
                uv.data[index].uv = self.uvs[data.loops[index].vertex_index]
        obj = bpy.data.objects.new(self.name, data)
        bpy.context.collection.objects.link(obj)
        data.materials.append(mat)
        # Leaf normals are deliberately guided upward/outward, avoiding card glare.
        if all(any(abs(c) > 0 for c in normal) for normal in self.normals):
            data.normals_split_custom_set_from_vertices(self.normals)
        return obj


def wind_at(point, height):
    return max(0, min(1, (point[2] - 0.13) / max(0.1, height - 0.13)))


def tube(builder, points, radii, sides=7):
    rings = []
    for index, point in enumerate(points):
        p = Vector(point)
        tangent = Vector(points[min(index + 1, len(points) - 1)]) - Vector(points[max(index - 1, 0)])
        tangent.normalize()
        axis = tangent.cross(Vector((0, 0, 1)))
        if axis.length < 0.1:
            axis = tangent.cross(Vector((0, 1, 0)))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        ring = []
        for j in range(sides + 1):
            angle = j * TAU / sides
            normal = axis * math.cos(angle) + other * math.sin(angle)
            irregular = 1 + 0.045 * math.sin(j * 2.3 + index * 0.8)
            ring.append(builder.vert(p + normal * radii[index] * irregular, (j / sides, index / max(1, len(points) - 1))))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(sides):
            builder.face(rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j])
    builder.face(*reversed(rings[0][:-1]))
    builder.face(*rings[-1][:-1])


def leaf(builder, centre, length, width, direction, normal, tile, height, phase=0.4, fruit=False):
    """A folded, four-triangle lanceolate blade, not an intersecting billboard."""
    c = Vector(centre)
    axis = Vector(direction).normalized()
    up = Vector(normal).normalized()
    side = axis.cross(up).normalized()
    up = side.cross(axis).normalized()
    if up.z < 0:
        up = -up
        side = -side
    if tile <= 4 or tile == 15:
        points = [c - axis * length * 0.5 - side * width * 0.5, c - axis * length * 0.5 + side * width * 0.5, c + axis * length * 0.5 + side * width * 0.5, c + axis * length * 0.5 - side * width * 0.5, c + up * length * 0.035]
        uv = [(0.01, 0.01), (0.99, 0.01), (0.99, 0.99), (0.01, 0.99), (0.5, 0.5)]
    else:
        points = [c - axis * length * 0.5, c - side * width * 0.5, c + axis * length * 0.5, c + side * width * 0.5, c + up * length * 0.035]
        uv = [(0.5, 0.05), (0.07, 0.5), (0.5, 0.95), (0.93, 0.5), (0.5, 0.5)]
    indices = []
    for p, uv_value in zip(points, uv):
        # Broad leaf illumination remains soft; radial normal on folded faces is small.
        illumination = (up * 0.88 + Vector((0, 0, 1)) * 0.12).normalized()
        indices.append(builder.vert(p, uv_value, wind_at(p, height), phase, int(fruit), illumination, tile))
    for i in range(4):
        if tile <= 4 or tile == 15:
            builder.face(indices[i], indices[(i + 1) % 4], indices[4])
        else:
            builder.face(indices[(i + 1) % 4], indices[i], indices[4])


def crown_lobe(builder, centre, radius, tile, height, seed, segments=10, rings=4):
    rr = random.Random(seed)
    c = Vector(centre)
    poles = []
    phase = rr.random()
    # Flattened and offset rings join as a broken canopy plane. The large form
    # stays closed, while changing ring centres avoids a row of visible balls.
    top = builder.vert(c + Vector((0, 0, radius[2] * 0.98)), (0.5, 0.94), wind_at(c, height), phase, normal=(0, 0, 1), tile=tile)
    for i in range(1, rings + 1):
        angle = i * math.pi / (rings + 1)
        ring = []
        for j in range(segments + 1):
            azimuth = (j % segments) * TAU / segments
            ripple = 1 + 0.13 * math.sin(azimuth * 3 + seed) + 0.07 * math.cos(azimuth * 5 + angle * 3)
            normal = Vector((math.sin(angle) * math.cos(azimuth), math.sin(angle) * math.sin(azimuth), math.cos(angle)))
            spread = math.sin(angle) ** 0.80
            offset = Vector((math.sin(angle * 1.8 + seed) * 0.075, math.cos(angle * 1.6 + seed) * 0.06, 0))
            p = c + offset + Vector((math.cos(azimuth) * spread * radius[0] * ripple, math.sin(azimuth) * spread * radius[1] * ripple, normal.z * radius[2] * (1 + 0.11 * math.sin(azimuth * 3 + seed))))
            # Keep the normal near the actual shell. Strong artificial upward
            # normals on side walls produce striped self-shadow bias artifacts.
            soft = (Vector((normal.x / radius[0], normal.y / radius[1], normal.z / radius[2])) + Vector((0, 0, 0.10))).normalized()
            ring.append(builder.vert(p, (j / segments, 1 - i / (rings + 1)), wind_at(p, height), phase, normal=soft, tile=tile))
        poles.append(ring)
    bottom = builder.vert(c - Vector((0, 0, radius[2] * 0.90)), (0.5, 0.05), wind_at(c, height), phase, normal=(0, 0, -1), tile=tile)
    for j in range(segments):
        builder.face(top, poles[0][j], poles[0][j + 1])
        builder.face(bottom, poles[-1][j + 1], poles[-1][j])
    for i in range(len(poles) - 1):
        for j in range(segments):
            builder.face(poles[i][j], poles[i + 1][j], poles[i + 1][j + 1], poles[i][j + 1])


def sphere_points(number, seed):
    rr = random.Random(seed)
    result = []
    for i in range(number):
        z = 1 - 2 * (i + 0.5) / number
        a = i * 2.39996323 + rr.uniform(-0.22, 0.22)
        r = math.sqrt(max(0, 1 - z * z))
        result.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    return result


def leafy_spray(builder, centre, radius, count, tile, height, seed):
    rr = random.Random(seed)
    c = Vector(centre)
    for n in sphere_points(count, seed):
        radius_scale = rr.uniform(0.88, 1.01)
        p = c + Vector((n.x * radius[0], n.y * radius[1], n.z * radius[2])) * radius_scale
        a = math.atan2(n.y, n.x) + rr.uniform(-1.25, 1.25)
        axis = Vector((math.cos(a), math.sin(a), rr.uniform(-0.15, 0.6)))
        normal = Vector((n.x * 0.65, n.y * 0.65, max(0.32, n.z))).normalized()
        length = rr.uniform(0.41, 0.58)
        leaf(builder, p, length, length * rr.uniform(0.69, 0.86), axis, normal, tile + (1 if rr.random() < 0.27 and tile < 2 else 0), height, rr.random())


def broadleaf(lod=False, fruit=False):
    rr = random.Random(SEED + int(fruit) * 919)
    height = 4.55 if fruit else 5.35
    bark = MeshBuilder("bark_branching_trunk", 8)
    mass = MeshBuilder("foliage_painted_crown", 14)
    leaves = MeshBuilder("foliage_leaf_sprays", 0)
    fruits = MeshBuilder("fruit_warm_accents", 13)
    trunk_height = 2.55 if fruit else 3.25
    points = [(0, 0, 0), (0.02, -0.04, 0.24), (-0.08, -0.015, 0.85), (-0.02, 0.04, 1.48), (0.15, 0.06, 2.15), (0.12, 0.09, trunk_height)]
    radii = [0.25 if fruit else 0.31, 0.19 if fruit else 0.24, 0.15 if fruit else 0.19, 0.12 if fruit else 0.15, 0.075, 0.025]
    tube(bark, points, radii, 6 if lod else 8)
    # Roots are closed tapered geometry and descend to exactly the ground plane.
    for i in range(3 if lod else 5):
        a = i * 2.39996 + 0.2
        tube(bark, [(math.cos(a) * 0.45, math.sin(a) * 0.45, 0.025), (math.cos(a) * 0.25, math.sin(a) * 0.25, 0.11), (0, 0, 0.39)], [0.025, 0.07, 0.12], 4)
    lobes = []
    for i in range(7 if fruit else 9):
        a = i * 2.399963
        r = (0.80 if fruit else 1.03) * math.sqrt((i + 0.7) / (7 if fruit else 9))
        centre = Vector((math.cos(a) * r + 0.1, math.sin(a) * r, (3.16 if fruit else 3.85) + 0.39 * math.sin(i * 1.7)))
        radius = ((0.82 if fruit else 0.99) * rr.uniform(0.88, 1.05), (0.76 if fruit else 0.90) * rr.uniform(0.88, 1.05), (0.68 if fruit else 0.89) * rr.uniform(0.85, 1.1))
        start = Vector((0.02, 0.04, 1.35 + (i % 3) * 0.20))
        middle = start.lerp(centre, 0.54) + Vector((0.10 * math.sin(i), 0, -0.12))
        tube(bark, [start, middle, centre + Vector((0, 0, -0.12))], [0.10 if i < 3 else 0.07, 0.055, 0.012], 4 if lod else 5)
        crown_lobe(mass, centre, tuple(v * (0.92 if axis < 2 else 0.83) for axis, v in enumerate(radius)), 14, height, SEED + i * 43 + int(fruit), 8 if lod else 12, 4 if lod else 5)
        leafy_spray(leaves, centre, tuple(v * 0.98 for v in radius), (21 if lod else 50), 15 if lod else (3 if fruit else (0 if centre.z > 3.8 else 1)), height, SEED + i * 74)
        lobes.append((centre, radius))
    if fruit:
        for i in range(7 if lod else 12):
            c, radius = lobes[i % len(lobes)]
            a = i * 2.399963 + 0.25
            p = c + Vector((math.cos(a) * radius[0] * 0.89, math.sin(a) * radius[1] * 0.89, -radius[2] * (0.30 + (i % 3) * 0.12)))
            crown_lobe(fruits, p, (0.105, 0.11, 0.12), 13, height, i * 31, 6, 2)
            # Existing COLOR_0.b contract marks every fruit vertex, not the leaves.
        fruits.colors = [(c[0], c[1], 1.0, 1.0) for c in fruits.colors]
    return [bark, mass, leaves, fruits]


def pine_bough(builder, centre, angle, length, width, tile, height, phase, lod=False):
    """Drooping layered conifer spray with irregular scalloped edge lobes."""
    c = Vector(centre)
    forward = Vector((math.cos(angle), math.sin(angle), 0))
    side = Vector((-math.sin(angle), math.cos(angle), 0))
    # A folded bough consists of 6 triangular leaf sprays; fully dimensional.
    for j in range(2 if lod else 3):
        t = (j + 0.33) / (2 if lod else 3)
        p = c + forward * length * t + Vector((0, 0, -length * 0.22 * t * t))
        for sign in [-1, 1]:
            axis = (forward * 0.74 + side * sign * 0.58 + Vector((0, 0, -0.16))).normalized()
            leaf(builder, p + side * sign * width * (1 - t) * 0.25, length * (0.65 - 0.24 * t), width * (0.95 - 0.50 * t), axis, Vector((side.x * sign * 0.2, side.y * sign * 0.2, 1)), tile, height, phase)
        if lod or j == 0:
            leaf(builder, p + Vector((0, 0, 0.11)), length * (0.63 - 0.10 * t), width * 0.75, forward + Vector((0, 0, -0.10)), Vector((0, 0, 1)), tile, height, phase)


def pine_pad(builder, centre, angle, radius, height, phase, lod=False):
    """Closed tapered bough fan, not a sphere, cone or intersecting billboards."""
    outline = [(0.0, -0.12), (0.24, -0.28), (0.43, -0.31), (0.56, -0.23), (0.74, -0.16), (0.91, -0.06), (1.08, 0.0), (0.91, 0.06), (0.74, 0.16), (0.56, 0.23), (0.43, 0.31), (0.24, 0.28), (0.0, 0.12)]
    if lod:
        outline = [outline[index] for index in [0, 2, 4, 6, 8, 10, 12]]
    c = Vector(centre)
    ca, sa = math.cos(angle), math.sin(angle)

    def position(x, y, z):
        return c + Vector((x * ca - y * sa, x * sa + y * ca, z))

    boundary = []
    for x, y in outline:
        p = position(x * radius, y * radius, 0.035 - x * 0.16 * radius - abs(y) * 0.05)
        normal = Vector((ca * 0.24 - sa * y * 0.6, sa * 0.24 + ca * y * 0.6, 0.92)).normalized()
        boundary.append(builder.vert(p, (y * 1.3 + 0.5, x * 0.8 + 0.06), wind_at(p, height), phase, normal=normal))
    upper_fill = 0.11 * (1 - min(radius / 1.5, 1))
    top = position(radius * 0.38, 0, 0.13 + radius * 0.055 + upper_fill)
    bottom = position(radius * 0.42, 0, -0.13 - upper_fill)
    upper = builder.vert(top, (0.5, 0.40), wind_at(top, height), phase, normal=(0, 0, 1))
    lower = builder.vert(bottom, (0.5, 0.40), wind_at(bottom, height), phase, normal=(0, 0, -1))
    for j in range(len(boundary)):
        builder.face(upper, boundary[j], boundary[(j + 1) % len(boundary)])
        builder.face(lower, boundary[(j + 1) % len(boundary)], boundary[j])


def conifer(lod=False):
    height = 5.80
    bark = MeshBuilder("bark_pine_trunk", 8)
    mass = MeshBuilder("foliage_full_pine_branch_pads", 11)
    leaves = MeshBuilder("foliage_drooping_pine_sprays", 4)
    tube(bark, [(0, 0, 0), (0.02, 0, 0.5), (-0.025, 0.02, 2.0), (0.01, 0.015, 3.9), (-0.04, 0, 5.7)], [0.23, 0.17, 0.13, 0.065, 0.008], 6 if lod else 8)
    for tier in range(10):
        t = tier / 9
        z = 1.08 + t * 4.24
        radius = 1.44 * (1 - t * 0.90)
        count = 4 if lod else 6
        for j in range(count):
            a = j * TAU / count + tier * 0.73
            phase = (j * 0.17 + tier * 0.31) % 1
            reach = radius * (0.94 + math.sin(tier * 2.1 + j * 1.7) * 0.12)
            branch_z = z + math.sin(j * 2.3 + tier) * 0.13
            centre = Vector((math.cos(a) * radius * 0.08, math.sin(a) * radius * 0.08, branch_z))
            pine_pad(mass, centre, a, reach, height, phase, lod)
            pine_bough(leaves, (math.cos(a) * radius * 0.21, math.sin(a) * radius * 0.21, branch_z + 0.04), a, reach * 0.99, reach * 0.46, 4, height, phase, lod)
            if not lod and tier < 4 and j % 3 == 0:
                tube(bark, [(0, 0, z + 0.14), (math.cos(a) * radius * 0.8, math.sin(a) * radius * 0.8, z - 0.18)], [0.034, 0.008], 4)
    return [bark, mass, leaves]


def fern():
    foliage = MeshBuilder("foliage_arching_fern", 12)
    stem = MeshBuilder("bark_fern_stems", 8)
    for i in range(7):
        a = i * 2.399963 + 0.18
        length = 0.47 + (i % 3) * 0.052
        forward = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-math.sin(a), math.cos(a), 0))
        points = []
        for j in range(5):
            t = j / 4
            p = forward * length * t + Vector((0, 0, 0.06 + math.sin(t * math.pi * 0.78) * (0.39 + 0.04 * (i % 2))))
            points.append(p)
        # Thin, rooted stem, rendered in the atlas rather than external wood material.
        for j in range(4):
            p, q = points[j], points[j + 1]
            s = side * (0.006 - j * 0.0008)
            indices = [stem.vert(v, (u, t), 0, 0) for v, u, t in [(p - s, 0, 0), (p + s, 1, 0), (q + s, 1, 1), (q - s, 0, 1)]]
            stem.face(*indices)
        for j in range(1, 8):
            t = j / 8
            p = forward * length * t + Vector((0, 0, 0.06 + math.sin(t * math.pi * 0.78) * (0.39 + 0.04 * (i % 2))))
            reach = 0.17 * math.sin(t * math.pi * 0.95) ** 0.70
            for sign in [-1, 1]:
                direction = (side * sign * 0.87 + forward * 0.43 + Vector((0, 0, -0.08))).normalized()
                leaf(foliage, p + direction * reach * 0.48, reach, reach * 0.48, direction, Vector((0, 0, 1)), 12, 0.67, i / 7)
    return [foliage, stem]


def wildflower():
    leaves = MeshBuilder("foliage_meadow_blades", 5)
    flowers = MeshBuilder("flower_ivory_daisies", 6)
    purple = MeshBuilder("flower_lavender_accents", 7)
    # Grass leaves have tapered triangulated geometry and curved, non-uniform tips.
    for i in range(30):
        a = i * 2.399963
        r = 0.32 * math.sqrt((i + 0.5) / 30)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0.004))
        height = 0.20 + (i * 17 % 11) * 0.022
        side = Vector((-math.sin(a), math.cos(a), 0)) * (0.018 + i % 3 * 0.004)
        bend = Vector((math.cos(a), math.sin(a), 0)) * height * 0.4
        middle = base + bend * 0.35 + Vector((0, 0, height * 0.55))
        tip = base + bend + Vector((0, 0, height))
        ids = [leaves.vert(p, uv, wind_at(p, 0.65), i / 30, normal=(0, 0, 1)) for p, uv in [(base - side * 0.4, (0.1, 0.08)), (base + side * 0.4, (0.9, 0.08)), (middle + side, (0.9, 0.55)), (middle - side, (0.1, 0.55)), (tip, (0.5, 0.94))]]
        leaves.face(ids[0], ids[1], ids[2], ids[3])
        leaves.face(ids[3], ids[2], ids[4])
    for i in range(8):
        a = i * 2.399963 + 0.4
        r = 0.28 * math.sqrt((i + 0.2) / 8)
        height = 0.34 + (i % 3) * 0.075
        stem = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        tip = stem + Vector((math.sin(i) * 0.045, math.cos(i) * 0.035, height))
        side = Vector((math.cos(a), math.sin(a), 0)) * 0.006
        idx = [leaves.vert(p, uv, wind_at(p, 0.65), i / 8) for p, uv in [(stem - side, (0.4, 0.1)), (stem + side, (0.6, 0.1)), (tip + side, (0.6, 0.9)), (tip - side, (0.4, 0.9))]]
        leaves.face(*idx)
        leaf(leaves, stem.lerp(tip, 0.45) + Vector((0.04, 0, 0.02)), 0.14, 0.055, Vector((math.cos(a), math.sin(a), 0.5)), (0, 0, 1), 3, 0.65, i / 8)
        if i < 6:
            # Ten scalloped petals in one fan, not dozens of sphere primitives.
            centre = flowers.vert(tip + Vector((0, 0, 0.008)), (0.5, 0.5), wind_at(tip, 0.65), i / 8, normal=(0, 0, 1))
            ring = []
            for j in range(20):
                angle = j * TAU / 20
                radius = 0.072 if j % 2 == 0 else 0.049
                p = tip + Vector((math.cos(angle) * radius, math.sin(angle) * radius, -0.009 if j % 2 else 0.004))
                ring.append(flowers.vert(p, (0.5 + math.cos(angle) * radius / 0.072 * 0.43, 0.5 + math.sin(angle) * radius / 0.072 * 0.43), wind_at(p, 0.65), i / 8, normal=(0, 0, 1)))
            for j in range(20):
                flowers.face(centre, ring[j], ring[(j + 1) % 20])
        else:
            for j in range(4):
                p = tip + Vector((math.sin(j * 2.4) * 0.016, math.cos(j * 2.4) * 0.016, j * 0.031))
                leaf(purple, p, 0.070, 0.054, Vector((1, 0, 0.1)), (0, 0, 1), 7, 0.7, i / 8)
    return [leaves, flowers, purple]


def shrub():
    mass = MeshBuilder("foliage_compact_shrub_body", 14)
    leaves = MeshBuilder("foliage_shrub_edge_leaves", 0)
    for i in range(3):
        a = i * 2.399963
        centre = (math.cos(a) * 0.22, math.sin(a) * 0.20, 0.34 + i % 2 * 0.09)
        radius = (0.40, 0.34, 0.33)
        crown_lobe(mass, centre, radius, 14, 0.88, SEED + i, 8, 4)
        leafy_spray(leaves, centre, radius, 10, 0 if i > 0 else 1, 0.88, SEED + i * 29)
    return [mass, leaves]


def rock(flat=False):
    body = MeshBuilder("stone_closed_worn_body", 9)
    moss = MeshBuilder("moss_upper_surface", 10)
    segments, rings = (18, 10) if flat else (22, 12)
    sx, sy, sz = (0.79, 0.58, 0.23) if flat else (0.69, 0.57, 0.73)
    phase = 0.67 if flat else 1.39
    vertices = []
    for i in range(rings + 1):
        latitude = i * math.pi / rings
        ring = []
        for j in range(segments + 1):
            a = (j % segments) * TAU / segments
            normal = Vector((math.sin(latitude) * math.cos(a), math.sin(latitude) * math.sin(a), math.cos(latitude)))
            wobble = 1 + 0.09 * math.sin(a * 3 + phase) + 0.045 * math.cos(latitude * 4 + a * 2)
            z = normal.z * sz * (1 + math.sin(a * 3 + phase) * 0.075) + sz * 0.82
            nx = math.copysign(abs(normal.x) ** 0.88, normal.x)
            ny = math.copysign(abs(normal.y) ** 0.92, normal.y)
            p = Vector((nx * sx * wobble, ny * sy * wobble, max(0, z)))
            p.z = min(p.z, sz * 1.65 - p.x * 0.12 + math.sin(p.y * 9) * 0.014)
            p.x += math.sin(latitude * 2.4) * 0.05
            ring.append(body.vert(p, (j / segments, i / rings)))
        vertices.append(ring)
    for i in range(rings):
        for j in range(segments):
            if i == 0:
                body.face(vertices[i][j], vertices[i + 1][j], vertices[i + 1][j + 1])
            elif i == rings - 1:
                body.face(vertices[i][j], vertices[i + 1][j], vertices[i][j + 1])
            else:
                body.face(vertices[i][j], vertices[i + 1][j], vertices[i + 1][j + 1], vertices[i][j + 1])
    # Moss follows selected upper rock faces exactly; no green floating cap.
    for polygon in body.faces:
        centre = sum((Vector(body.vertices[v]) for v in polygon), Vector()) / len(polygon)
        pattern = math.sin(centre.x * 9 + centre.y * 7) + math.cos(centre.y * 12 - centre.x * 3)
        if centre.z > sz * 1.10:
            indices = []
            for vertex in polygon:
                p = Vector(body.vertices[vertex])
                normal = Vector((p.x / sx, p.y / sy, max(0.3, (p.z - sz * 0.82) / sz))).normalized()
                indices.append(moss.vert(p + normal * 0.004, (p.x / (sx * 2.3) + 0.5, p.y / (sy * 2.3) + 0.5), normal=normal))
            moss.face(*indices)
    # Moss is static. It remains a role within NAT-08/09, not P1 decals.
    moss.colors = [(0, 0, 0, 1) for _ in moss.colors]
    return [body, moss]


def socket():
    obj = bpy.data.objects.new("socket_ground", None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.2
    bpy.context.collection.objects.link(obj)


def shared_material():
    image = bpy.data.images.load(str(SOURCE / "painted_forest_atlas.png"), check_existing=True)
    image.colorspace_settings.name = "sRGB"
    image.filepath = "//painted_forest_atlas.png"
    result = bpy.data.materials.new("painted_forest_shared_atlas")
    result.use_nodes = True
    result.use_fake_user = True
    result.diffuse_color = (0.48, 0.57, 0.28, 1)
    tree = result.node_tree
    shader = tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = 0.95
    shader.inputs["Specular IOR Level"].default_value = 0.08
    texture = tree.nodes.new("ShaderNodeTexImage")
    texture.name = "EditablePaintedAtlas"
    texture.image = image
    tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    tree.links.new(texture.outputs["Alpha"], shader.inputs["Alpha"])
    # Dithered preview; engine uses alpha scissor through the art foliage shader.
    result.surface_render_method = "DITHERED"
    return result


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablock in list(bpy.data.meshes):
        if datablock.users == 0:
            bpy.data.meshes.remove(datablock)


def finish_asset(name, asset_id, builder, budget, material, lod=False):
    clear_scene()
    for part in builder():
        part.finish(material)
    socket()
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    triangles = sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes)
    assert triangles <= budget, (name, triangles, budget)
    points = [v.co for obj in meshes for v in obj.data.vertices]
    minimum = [round(min(point[i] for point in points), 6) for i in range(3)]
    maximum = [round(max(point[i] for point in points), 6) for i in range(3)]
    source, target = SOURCE / (name + ".blend"), EXPORT / (name + ".glb")
    bpy.context.scene["art_direction"] = "Joined canopy planes, cool forest shadows, restrained leaf edges and broad brush values"
    bpy.context.scene["source_generator"] = "tools/art/build_art_foliage.py"
    bpy.context.scene["source_seed"] = SEED
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(
        filepath=str(target), export_format="GLB", export_yup=True, export_apply=True,
        export_cameras=False, export_lights=False, export_materials="NONE",
        export_vertex_color="NAME", export_vertex_color_name="wind_mask", export_all_vertex_colors=False,
        export_texcoords=True, export_normals=True, export_tangents=False,
    )
    result = {
        "asset_id": asset_id, "source": str(source.relative_to(ROOT)), "export": str(target.relative_to(ROOT)),
        "blender": bpy.app.version_string, "generator_version": "art_foliage_01.4", "units": "meters", "up_axis": "gltf_y_up",
        "triangles": triangles, "budget": budget, "mesh_objects": len(meshes), "sockets": ["socket_ground"],
        "bounds_source_z_up": {"min": minimum, "max": maximum}, "roles": [obj.name for obj in meshes],
        "source_license": "Project original; reproducible geometry and painted atlas recipe, no downloaded content",
        "wind_channels": {"R": "root-pinned bend weight", "G": "stable local flutter phase", "B": "fruit marker (1 only fruit)", "A": "1; texture supplies coverage"},
        "texture": "assets/nature/art_pass_01/painted_forest_atlas.png", "lod": 1 if lod else 0,
    }
    target.with_suffix(".asset.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def audit_exports(manifest):
    records = []
    types = {5126: np.dtype("<f4"), 5125: np.dtype("<u4"), 5123: np.dtype("<u2"), 5121: np.dtype("u1")}
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    for entry in manifest:
        raw = (ROOT / entry["export"]).read_bytes()
        assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 8)[0] == len(raw)
        length = struct.unpack_from("<I", raw, 12)[0]
        data = json.loads(raw[20 : 20 + length])
        blob = raw[28 + length :]

        def read_accessor(index):
            accessor = data["accessors"][index]
            view = data["bufferViews"][accessor["bufferView"]]
            dtype = types[accessor["componentType"]]
            width = widths[accessor["type"]]
            offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", dtype.itemsize * width)
            result = np.ndarray((accessor["count"], width), dtype=dtype, buffer=blob, offset=offset, strides=(stride, dtype.itemsize)).astype(np.float64)
            if accessor.get("normalized", False):
                result /= np.iinfo(dtype).max
            return result

        triangles, parts = 0, []
        for mesh in data["meshes"]:
            for primitive in mesh["primitives"]:
                attrs = primitive["attributes"]
                assert all(key in attrs for key in ["POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"])
                positions = read_accessor(attrs["POSITION"])
                normals = read_accessor(attrs["NORMAL"])
                uv = read_accessor(attrs["TEXCOORD_0"])
                colors = read_accessor(attrs["COLOR_0"])
                indices = read_accessor(primitive["indices"])
                assert all(np.isfinite(values).all() for values in [positions, normals, uv, colors, indices])
                assert np.allclose(np.linalg.norm(normals, axis=1), 1, atol=0.002)
                assert (uv >= 0).all() and (uv <= 1).all()
                assert (colors >= 0).all() and (colors <= 1).all()
                assert np.allclose(colors[:, 3], 1)
                assert indices.max() < len(positions) and len(indices) % 3 == 0
                if mesh["name"].startswith(("bark", "stone", "moss")):
                    assert np.allclose(colors[:, 0], 0) and np.allclose(colors[:, 2], 0)
                if mesh["name"].startswith("fruit"):
                    assert np.allclose(colors[:, 2], 1)
                triangles += len(indices) // 3
                parts.append({"name": mesh["name"], "vertices": len(positions), "wind_min": float(colors[:, 0].min()), "wind_max": float(colors[:, 0].max())})
        assert triangles == entry["triangles"] and triangles <= entry["budget"]
        assert all(any(node["name"] == socket for node in data["nodes"]) for socket in entry["sockets"])
        records.append({"export": entry["export"], "triangles": triangles, "parts": parts, "sha256": hashlib.sha256(raw).hexdigest(), "passed": True})
    (SOURCE / "glb_contract_audit.json").write_text(json.dumps({"passed": True, "exports": records}, indent=2) + "\n")
    print("ART_FOLIAGE_GLB_CONTRACT_PASS", len(records))


def audit_new_sources(manifest):
    records = []
    for entry in manifest:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / entry["source"]), load_ui=False)
        assert bpy.context.scene.unit_settings.system == "METRIC"
        assert abs(bpy.context.scene.unit_settings.scale_length - 1) < 1e-6
        meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        count = 0
        for obj in meshes:
            assert tuple(obj.scale) == (1, 1, 1), obj.name
            assert obj.data.uv_layers and obj.data.color_attributes.get("wind_mask") is not None
            assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
            assert all(math.isfinite(c) for normal in obj.data.corner_normals for c in normal.vector)
            assert all(0 <= c <= 1 for color in obj.data.color_attributes["wind_mask"].data for c in color.color)
            count += sum(len(poly.vertices) - 2 for poly in obj.data.polygons)
            for color in obj.data.color_attributes["wind_mask"].data:
                if obj.name.startswith(("bark", "stone", "moss")):
                    assert color.color[0] == 0
        assert count == entry["triangles"] and count <= entry["budget"]
        assert all(bpy.context.scene.objects.get(name) is not None for name in entry["sockets"])
        mat = meshes[0].data.materials[0]
        texture = next(node.image for node in mat.node_tree.nodes if node.type == "TEX_IMAGE")
        assert list(texture.size) == [2048, 2048]
        assert Path(bpy.path.abspath(texture.filepath)).resolve() == SOURCE / "painted_forest_atlas.png"
        records.append({"source": entry["source"], "triangles": count, "mesh_objects": len(meshes), "image_reopened": True, "passed": True})
    report = {"blender": bpy.app.version_string, "generator": "tools/art/build_art_foliage.py", "sources": records, "passed": True}
    (SOURCE / "source_reopen_audit.json").write_text(json.dumps(report, indent=2) + "\n")
    audit_exports(manifest)
    print("ART_FOLIAGE_SOURCE_REOPEN_PASS", len(records))


def preview(manifest):
    # Libraries cannot append from the currently reopened audit source.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    positions = [(-4.4, 0), (0, 1.0), (3.8, 0.1), (-3.7, -3.0), (-2.0, -3.1), (0, -3.0), (2.2, -3.0), (3.7, -3.1)]
    entries = [entry for entry in manifest if entry["lod"] == 0]
    if ARGS.preview_lod:
        entries = [entry for entry in manifest if entry["lod"] == 1] + [entry for entry in entries if not entry["asset_id"] in ["NAT-01", "NAT-02", "NAT-03"]]
    for entry, location in zip(entries, positions):
        with bpy.data.libraries.load(str(ROOT / entry["source"]), link=False) as (available, target):
            target.objects = available.objects
        for obj in target.objects:
            if obj is not None and obj.type == "MESH":
                bpy.context.collection.objects.link(obj)
                obj.location = (location[0], location[1], 0)
    bpy.ops.mesh.primitive_plane_add(size=200)
    ground = bpy.context.object
    mat = bpy.data.materials.new("WarmPaperPreviewGround")
    mat.diffuse_color = (0.59, 0.55, 0.39, 1)
    mat.use_nodes = True
    mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.59, 0.55, 0.39, 1)
    mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 1
    ground.data.materials.append(mat)
    ground.location.z = -0.025
    world = bpy.data.worlds.new("PaintedForestPreviewWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.66, 0.74, 0.73, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.6
    bpy.ops.object.light_add(type="AREA", location=(-3, -5, 10))
    light = bpy.context.object
    light.data.energy = 1700
    light.data.shape = "DISK"
    light.data.size = 8
    light.rotation_euler = (Vector((0, 0, 1.8)) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(11, -17, 10.5))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, -0.2, 2.4)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 14.4
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1100
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(SOURCE / ("foliage_contact_sheet_lod1_blender.png" if ARGS.preview_lod else "foliage_contact_sheet_blender.png"))
    bpy.ops.render.render(write_still=True)


if ARGS.audit_only:
    entries = json.loads((SOURCE / "manifest.json").read_text())
    audit_new_sources(entries)
    if ARGS.preview:
        preview(entries)
else:
    paint_atlas()
    material = shared_material()
    entries = []
    for kind, asset_id, budget in [("broadleaf", "NAT-01", 4000), ("conifer", "NAT-02", 3500), ("fruit", "NAT-03", 4000)]:
        builder = (lambda lod=False, kind=kind: conifer(lod) if kind == "conifer" else broadleaf(lod, kind == "fruit"))
        high = finish_asset("tree_" + kind, asset_id, lambda b=builder: b(False), budget, material)
        low = finish_asset("tree_" + kind + "_lod1", asset_id + "-LOD1", lambda b=builder: b(True), 1700, material, True)
        high["lod1"], high["lod1_triangles"] = low["export"], low["triangles"]
        (ROOT / high["export"]).with_suffix(".asset.json").write_text(json.dumps(high, indent=2) + "\n")
        entries.extend([high, low])
    for name, asset_id, builder, budget in [("fern", "NAT-04", fern, 500), ("wildflower", "NAT-05", wildflower, 450), ("shrub", "NAT-06", shrub, 500), ("moss_rock", "NAT-08", lambda: rock(False), 1000), ("flat_rock", "NAT-09", lambda: rock(True), 800)]:
        entries.append(finish_asset(name, asset_id, builder, budget, material))
    (SOURCE / "manifest.json").write_text(json.dumps(entries, indent=2) + "\n")
    audit_new_sources(entries)
    if ARGS.preview:
        preview(entries)
    print("ART_FOLIAGE_BUILD_OK", len(entries), sum(entry["triangles"] for entry in entries))
