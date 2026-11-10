"""Extract editable game pieces from the supplied island study. Requires NumPy."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from zipfile import ZipFile

import numpy as np


OUTPUT = Path(__file__).resolve().parents[1] / "game/art/healing/models"
MODEL = "examples/island/island_model.glb"
SOURCE_SHA256 = '382133d5a788824c594fcbab306fc61438fb02c826dc8c2952bbe05275ab40ca'
ATTRIBUTES = ("POSITION", "NORMAL", "COLOR_0")


def read_meshes(blob):
    json_length = struct.unpack_from("<I", blob, 12)[0]
    gltf = json.loads(blob[20:20 + json_length])
    raw = blob[28 + json_length:]
    meshes = {}
    for mesh in gltf["meshes"]:
        primitive = mesh["primitives"][0]
        arrays = []
        for key in ATTRIBUTES:
            accessor = gltf["accessors"][primitive["attributes"][key]]
            view = gltf["bufferViews"][accessor["bufferView"]]
            assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
            arr = np.frombuffer(raw, dtype="<f4", count=accessor["count"] * 3,
                                offset=view.get("byteOffset", 0))
            arrays.append(arr.reshape((-1, 3, 3)).copy())
        meshes[mesh["name"]] = np.stack(arrays)
    return meshes


def write_model(name, pieces):
    raw = bytearray()
    meta = dict(asset={"version": "2.0", "generator": "Brushland healing model extractor"},
                scene=0, scenes=[{"nodes": list(range(len(pieces)))}], nodes=[], meshes=[],
                materials=[{"name": "Paint", "doubleSided": True, "pbrMetallicRoughness": {
                    "metallicFactor": 0, "roughnessFactor": 1}}],
                accessors=[], bufferViews=[])
    for part, sample in pieces.items():
        attrs = {}
        for key, array in zip(ATTRIBUTES, sample):
            flat = np.ascontiguousarray(array.reshape(-1, 3), dtype="<f4")
            index = len(meta["accessors"])
            attrs[key] = index
            meta["bufferViews"].append({"buffer": 0, "byteOffset": len(raw),
                                        "byteLength": flat.nbytes, "target": 34962})
            accessor = {"bufferView": index, "componentType": 5126,
                        "count": len(flat), "type": "VEC3"}
            if key == "POSITION":
                accessor.update(min=flat.min(0).tolist(), max=flat.max(0).tolist())
            meta["accessors"].append(accessor)
            raw.extend(flat.tobytes())
        meta["nodes"].append({"name": part, "mesh": len(meta["meshes"])})
        meta["meshes"].append({"name": part, "primitives": [{"attributes": attrs, "material": 0}]})
    meta["buffers"] = [{"byteLength": len(raw)}]
    header = json.dumps(meta, separators=(",", ":")).encode()
    header += b" " * (-len(header) % 4)
    target = OUTPUT / (name + ".glb")
    target.write_bytes(struct.pack("<4sII", b"glTF", 2, 28 + len(header) + len(raw)) +
                       struct.pack("<I4s", len(header), b"JSON") + header +
                       struct.pack("<I4s", len(raw), b"BIN\0") + raw)
    print(name, sum(piece.shape[1] for piece in pieces.values()), "triangles")


def linear(hex_color):
    srgb = np.array(list(bytes.fromhex(hex_color))) / 255
    return np.where(srgb < .04045, srgb / 12.92, ((srgb + .055) / 1.055) ** 2.4)


def cottage(mesh):
    # Convert from the standalone island's coordinates to the 2-by-2 game footprint.
    mesh[0] = (mesh[0] - [-.58, .63, .40]) * [.386, .48, .42]
    mesh[1] /= [.386, .48, .42]
    mesh[1] /= np.linalg.norm(mesh[1], axis=-1, keepdims=True)
    colors = mesh[2, :, 0]
    palette = ("955239", "ad6245", "ba6747", "bd7152", "c37c59", "ac5e41",
               "cd8563", "b3694d", "bf7859")
    tile = np.any([np.isclose(colors, linear(color)).all(1) for color in palette], axis=0)
    window = np.isclose(colors, linear("839393")).all(1)
    tiles = mesh[:, tile].copy()
    # Preserve the original variations between tiles when a player changes roof tint.
    tiles[2] = np.clip(tiles[2, :, :, :1] / linear("cd8563")[0], 0, 1)
    write_model("cottage", {"TimberAndPlaster": mesh[:, ~(window | tile)],
                            "RoofTiles": tiles, "Casements": mesh[:, window]})


def tree(wood, canopy):
    # The study has 100 opaque overlapping tufts plus 5300 free leaves.
    # Sample the silhouette in 3D; keep some leaves around each surviving tuft.
    groups = canopy[:, :7200].reshape(3, 100, 72, 3, 3)
    centers = groups[0].mean(axis=(1, 2))
    selected = [int(centers[:, 1].argmin())]
    for _ in range(23):
        distances = ((centers[:, None] - centers[selected]) ** 2).sum(-1).min(1)
        selected.append(int(distances.argmax()))
    crown = []
    leaves = canopy[:, 7200:].reshape(3, 100, 53, 3, 3)
    for i in selected:
        sample = groups[:, i]
        center = centers[i]
        extent = np.ptp(sample[0].reshape(-1, 3), axis=0) * .56
        # Two staggered pentagonal rings and smooth ellipsoid normals.
        rings = []
        for radius, y, twist in [(0, 1, 0), (.89, .44, 0), (.90, -.42, .36), (0, -1, 0)]:
            a = np.arange(5) * 2 * np.pi / 5 + i + twist
            rings.append(np.stack([radius * np.cos(a), np.full(5, y), radius * np.sin(a)], axis=1))
        faces = []
        for j in range(5):
            k = (j + 1) % 5
            faces += [[rings[0][0], rings[1][k], rings[1][j]],
                      [rings[1][j], rings[1][k], rings[2][j]],
                      [rings[1][k], rings[2][k], rings[2][j]],
                      [rings[2][j], rings[2][k], rings[3][0]]]
        unit = np.asarray(faces)
        normals = unit / extent
        normals /= np.linalg.norm(normals, axis=-1, keepdims=True)
        positions = center + unit * extent
        # Store outward-facing triangles in glTF's counter-clockwise convention.
        inward = (np.cross(positions[:, 1]-positions[:, 0], positions[:, 2]-positions[:, 0])
                  * normals.mean(axis=1)).sum(axis=1) < 0
        positions[inward] = positions[inward, ::-1]
        normals[inward] = normals[inward, ::-1]
        tint = sample[2, 0, 0] * [1.25, 1.03, .86]
        colors = np.clip(tint * (.96 + .07 * normals[:, :, 1:2]), 0, 1)
        crown.append(np.stack([positions, normals, colors]))
        fringe = leaves[:, i, ::5].copy()
        roots = fringe[0, :, :1].copy()
        fringe[0] = roots + (fringe[0] - roots) * 1.7
        fringe[2] = np.clip(fringe[2] * [1.35, 1.10, .88], 0, 1)
        crown.append(fringe)
    crown = np.concatenate(crown, axis=1)
    for piece in (wood, crown, canopy):
        piece[0] = (piece[0] - [1.92, .62, -1.08]) * .55
    write_model("grove_oak", {"OakWood": wood, "AutumnLeaves": crown})
    # Keep every authored tuft and rim leaf on the focal tree. Its position still
    # belongs to an editable tree object, which can be moved or removed normally.
    write_model("autumn_oak", {"OakWood": wood, "AutumnLeaves": canopy})



def flowers(mesh):
    # The original foxglove patch contains 90 individual stalks, 48 triangles each.
    # Two stems per paint dab keep flowers pickable and cheap to repeat on large islands.
    stems = mesh.reshape(3, 90, 48, 3, 3)
    cuts = []
    for i, x, z in [(1, -.05, .025), (7, .065, -.04)]:
        stem = stems[:, i].copy()
        coords = stem[0].reshape(-1, 3)
        base = coords[coords[:, 1].argmin()].copy()
        stem[0] -= base
        stem[0] += [x, 0, z]
        cuts.append(stem)
    write_model("foxgloves", {"Foxgloves": np.concatenate(cuts, axis=1)})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference_zip", type=Path)
    args = parser.parse_args()
    with ZipFile(args.reference_zip) as archive:
        blob = archive.read(MODEL)
    if hashlib.sha256(blob).hexdigest() != SOURCE_SHA256:
        raise ValueError("Unexpected source GLB; verify the named mesh layout before rebuilding")
    meshes = read_meshes(blob)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    cottage(meshes["CottageWalls"])
    tree(meshes["OakWood"], meshes["AutumnOak"])
    flowers(meshes["FoxglovesAndWildflowers"])


if __name__ == "__main__":
    main()
