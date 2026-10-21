"""Blender 5.1.2: original, reproducible painted material studies for art pass 01.

Run: Blender --background --python tools/art/build_art_materials.py -- --root PATH
All RGB values below are authored sRGB bytes. The tiny PNG encoder deliberately
avoids Blender's render/view transform; the .blend library reopens these PNGs as
sRGB textures. No photographs, generated concept crops or third-party inputs.
"""

from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import struct
import sys
import zlib

import bpy
import numpy as np


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--verify-only", action="store_true")
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(values)


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def save_png(path, rgb):
    pixels = np.asarray(np.clip(rgb, 0, 255), dtype=np.uint8)
    height, width, channels = pixels.shape
    raw = b"".join(b"\0" + row.tobytes() for row in pixels)
    header = struct.pack(">IIBBBBB", width, height, 8, 2 if channels == 3 else 6, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"sRGB", b"\0")
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def periodic_field(size, seed, low=1, high=8, waves=18):
    """Non-grid, truly periodic broad paint masses; zero mean/unit deviation."""
    rng = np.random.default_rng(seed)
    axis = np.arange(size, dtype=np.float32) / size
    x, y = np.meshgrid(axis, axis)
    field = np.zeros((size, size), dtype=np.float32)
    for _ in range(waves):
        kx, ky = rng.integers(-high, high + 1, size=2)
        if abs(kx) + abs(ky) < low:
            kx = low
        frequency = max(1, abs(kx) + abs(ky))
        field += np.sin(math.tau * (kx * x + ky * y) + rng.random() * math.tau) / frequency**0.85
    field -= field.mean()
    return field / max(float(field.std()), 0.00001)


def washes(size, seed, base, strength=8.0):
    low = periodic_field(size, seed, high=5)
    medium = periodic_field(size, seed + 71, low=5, high=19, waves=27)
    rgb = np.empty((size, size, 3), dtype=np.float32)
    for channel, value in enumerate(base):
        rgb[:, :, channel] = value + low * strength + medium * strength * 0.18
    return rgb


def dabs(rgb, seed, count, colors, radius=(0.025, 0.08), aspect=0.45, opacity=0.25):
    """Sparse, layered dry-brush marks with feathered irregular margins."""
    size = rgb.shape[0]
    rng = np.random.default_rng(seed)
    for _ in range(count):
        cx, cy = rng.integers(0, size, size=2)
        rad = rng.uniform(*radius) * size
        half = max(3, int(rad * 1.5))
        axis = np.arange(-half, half + 1, dtype=np.float32)
        x, y = np.meshgrid(axis, axis)
        angle = rng.uniform(-0.8, 0.8)
        u = x * math.cos(angle) + y * math.sin(angle)
        v = -x * math.sin(angle) + y * math.cos(angle)
        edge = (u / rad) ** 2 + (v / (rad * aspect)) ** 2
        brush = np.maximum(0.0, 1.0 - edge)
        brush = brush**1.5 * opacity * (0.87 + 0.13 * np.sin(u * 0.45 + v * 0.2))
        rows = (cy + axis.astype(np.int32)) % size
        cols = (cx + axis.astype(np.int32)) % size
        region = rgb[rows[:, None], cols[None, :]]
        color = np.asarray(colors[rng.integers(len(colors))], dtype=np.float32)
        rgb[rows[:, None], cols[None, :]] = region * (1.0 - brush[:, :, None]) + color * brush[:, :, None]
    return rgb


def generate():
    size = 1024
    # Calibrated against the native art-pass camera, not just texture swatches:
    # sage has a little blue-gray body so warm sunlight does not turn it lime.
    meadow = washes(size, 1103, (108, 129, 91), 4.8)
    dabs(meadow, 1104, 180, [(140, 154, 111), (91, 119, 91), (125, 143, 103)], opacity=0.23)
    macro = washes(size, 1201, (117, 138, 98), 10.0)
    dabs(macro, 1202, 65, [(143, 157, 112), (93, 124, 97), (130, 146, 105)], radius=(0.035, 0.15), aspect=0.8, opacity=0.29)
    plaster = washes(size, 1301, (207, 196, 164), 5.5)
    dabs(plaster, 1302, 100, [(230, 216, 180), (185, 179, 155), (217, 201, 164)], radius=(0.02, 0.09), aspect=0.7, opacity=0.24)
    # Large trowel swathes, sparse darker pits; no photographic concrete grain.
    dabs(plaster, 1303, 90, [(182, 175, 148), (226, 213, 180)], radius=(0.002, 0.006), aspect=0.55, opacity=0.20)
    terracotta = washes(size, 1401, (174, 103, 64), 8.0)
    dabs(terracotta, 1402, 90, [(204, 132, 78), (143, 84, 58), (185, 112, 75)], radius=(0.02, 0.1), aspect=0.48, opacity=0.32)
    wood = washes(size, 1501, (142, 103, 62), 7.0)
    axis = np.arange(size, dtype=np.float32) / size
    x, y = np.meshgrid(axis, axis)
    flow = x * 27.0 + np.sin(y * math.tau * 2.0) * 0.25 + np.sin(y * math.tau * 7.0) * 0.05
    wood += (np.sin(flow * math.tau) * 3.8 + np.sin(flow * math.tau * 1.93) * 1.8)[:, :, None]
    dabs(wood, 1502, 40, [(172, 128, 74), (117, 84, 57)], radius=(0.02, 0.09), aspect=0.18, opacity=0.20)
    stone = washes(size, 1601, (148, 149, 127), 8.0)
    dabs(stone, 1602, 125, [(171, 166, 143), (128, 139, 119), (157, 155, 127)], radius=(0.02, 0.13), aspect=0.7, opacity=0.32)
    soil = washes(size, 1701, (150, 137, 104), 6.5)
    dabs(soil, 1702, 100, [(175, 160, 122), (130, 126, 98)], radius=(0.01, 0.04), aspect=0.5, opacity=0.2)
    wet = washes(size, 1801, (91, 111, 84), 5.0)
    dabs(wet, 1802, 110, [(110, 128, 88), (79, 99, 83)], radius=(0.02, 0.08), aspect=0.7, opacity=0.25)
    window = np.empty((256, 256, 3), dtype=np.float32)
    gy, gx = np.mgrid[0:256, 0:256] / 255.0
    edge = np.clip(np.minimum.reduce([gx, 1.0 - gx, gy, 1.0 - gy]) * 8.0, 0.0, 1.0)
    window[:, :, :] = np.asarray([242, 189, 100]) * edge[:, :, None]
    return {
        "meadow": meadow,
        "meadow_macro": macro,
        "plaster": plaster,
        "terracotta": terracotta,
        "honey_timber": wood,
        "moss_stone": stone,
        "warm_soil": soil,
        "wet_bank": wet,
        "window_glow": window,
    }


def verify_library(root):
    source = root / "art_source/art_pass_01/materials"
    manifest = json.loads((source / "manifest.json").read_text())
    bpy.ops.wm.open_mainfile(filepath=str(source / "painted_material_library.blend"), load_ui=False)
    records = []
    for entry in manifest["textures"]:
        material = bpy.data.materials.get("ArtPass01_" + entry["name"])
        assert material is not None and material.use_fake_user, entry["name"]
        nodes = [node for node in material.node_tree.nodes if node.type == "TEX_IMAGE"]
        assert len(nodes) == 1 and nodes[0].image is not None, entry["name"]
        image = nodes[0].image
        path = Path(bpy.path.abspath(image.filepath)).resolve()
        assert path == root / entry["source"] and path.is_file(), entry["name"]
        assert list(image.size) == entry["resolution"], entry["name"]
        assert image.colorspace_settings.name == "sRGB", entry["name"]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == entry["sha256"], entry["name"]
        assert hashlib.sha256((root / entry["export"]).read_bytes()).hexdigest() == digest
        records.append({"source": entry["source"], "sha256": digest, "passed": True})
    (source / "source_audit.json").write_text(json.dumps({
        "blender": bpy.app.version_string,
        "source_reopened": "art_source/art_pass_01/materials/painted_material_library.blend",
        "material_library_graphs": len(records),
        "images_reopened": len(records),
        "sources": records,
        "passed": True,
    }, indent=2) + "\n")
    print("ART_PASS_MATERIAL_SOURCE_AUDIT_PASS", len(records))


def main():
    args = arguments()
    root = args.root.resolve()
    if args.verify_only:
        verify_library(root)
        return
    source = root / "art_source/art_pass_01/materials"
    exports = root / "assets/materials/art_pass_01"
    source.mkdir(parents=True, exist_ok=True)
    exports.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    manifest = []
    for name, pixels in generate().items():
        path = source / (name + ".png")
        save_png(path, pixels)
        shutil.copyfile(path, exports / path.name)
        image = bpy.data.images.load(str(path), check_existing=False)
        image.name = "ArtPass01_" + name
        image.filepath = "//" + path.name
        image.colorspace_settings.name = "sRGB"
        image.use_fake_user = True
        material = bpy.data.materials.new("ArtPass01_" + name)
        material.use_fake_user = True
        material.use_nodes = True
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Roughness"].default_value = 0.92
        texture = material.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = image
        texture.label = "Original painted swathes; editable PNG and deterministic source"
        material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
        manifest.append({
            "name": name,
            "source": str(path.relative_to(root)),
            "export": str((exports / path.name).relative_to(root)),
            "resolution": [int(pixels.shape[1]), int(pixels.shape[0])],
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "color_space": "sRGB; bytes authored directly, no view transform",
            "seamless": name != "window_glow",
            "license": "Project original; CC0-1.0",
        })
    bpy.ops.wm.save_as_mainfile(filepath=str(source / "painted_material_library.blend"))
    (source / "manifest.json").write_text(json.dumps({
        "generator": "tools/art/build_art_materials.py",
        "blender": bpy.app.version_string,
        "numpy": np.__version__,
        "seed_scheme": "1103–1802, fixed numpy PCG64; no external image inputs",
        "intent": "Warm ivory/ochre plaster, muted terracotta, honey timber, moss stone, broad sage meadow washes",
        "calibration": "Native iteration_02: cool sage meadow body, restrained yellow strokes; wall, timber and clay retained",
        "textures": manifest,
    }, ensure_ascii=False, indent=2) + "\n")
    (source / "LICENSE.txt").write_text(
        "Original Windhaven Diorama painted material studies.\n"
        "Authored by the project generator tools/art/build_art_materials.py.\n"
        "No third-party images, photographs, concept image crops or trained image model outputs.\n"
        "Dedicated to the public domain under CC0-1.0.\n"
    )
    print("ART_PASS_MATERIALS_OK", len(manifest))
    verify_library(root)


if __name__ == "__main__":
    main()
