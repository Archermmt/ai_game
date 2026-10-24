"""CPU-only coverage and LOD bounds audit; never rewrites production assets.

The PNG reader handles the filter-zero RGBA8 format emitted by this project's
write_png(). Bounds are measured from GLB POSITION bytes, not manifest values.
"""

import argparse
import hashlib
import json
import math
import struct
import zlib
from pathlib import Path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba_rows(path):
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n"
    width, height, depth, colour = struct.unpack_from(">IIBB", raw, 16)
    assert (width, height, depth, colour) == (2048, 2048, 8, 6)
    position, blocks = 8, []
    while position < len(raw):
        size = struct.unpack_from(">I", raw, position)[0]
        if raw[position + 4:position + 8] == b"IDAT":
            blocks.append(raw[position + 8:position + 8 + size])
        position += size + 12
    pixels = zlib.decompress(b"".join(blocks))
    stride = width * 4 + 1
    assert len(pixels) == stride * height
    assert all(pixels[y * stride] == 0 for y in range(height))
    return [pixels[y * stride + 1:(y + 1) * stride] for y in range(height)]


def dimensions(path):
    raw = path.read_bytes()
    assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 8)[0] == len(raw)
    json_size = struct.unpack_from("<I", raw, 12)[0]
    data = json.loads(raw[20:20 + json_size])
    assert all(not any(key in node for key in ["matrix", "translation", "rotation", "scale"])
               for node in data["nodes"]), "Audit expects the exported identity mesh nodes"
    blob = raw[28 + json_size:]
    minimum, maximum, count = [math.inf] * 3, [-math.inf] * 3, 0
    for mesh in data["meshes"]:
        for primitive in mesh["primitives"]:
            accessor = data["accessors"][primitive["attributes"]["POSITION"]]
            assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
            view = data["bufferViews"][accessor["bufferView"]]
            offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", 12)
            for index in range(accessor["count"]):
                point = struct.unpack_from("<3f", blob, offset + index * stride)
                assert all(math.isfinite(value) for value in point)
                for axis, value in enumerate(point):
                    minimum[axis] = min(minimum[axis], value)
                    maximum[axis] = max(maximum[axis], value)
                count += 1
    assert count > 0
    return [maximum[axis] - minimum[axis] for axis in range(3)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    source = root / "art_source/art_pass_01/nature"
    manifest_path = source / "manifest.json"
    entries = json.loads(manifest_path.read_text())
    assert len(entries) == 11
    versions = {entry["generator_version"] for entry in entries}
    assert len(versions) == 1
    version = versions.pop()
    atlas_path = root / "assets/nature/art_pass_01/painted_forest_atlas.png"
    watched = [manifest_path, atlas_path, source / "painted_forest_atlas.png"]
    watched += [root / entry[key] for entry in entries for key in ["source", "export"]]
    before = {str(path): sha256(path) for path in watched}
    common = {
        "generator_version": version,
        "status": "current_measured_inputs",
        "method": "CPU read-only: tools/art/audit_foliage_evidence.py",
        "manifest_sha256": sha256(manifest_path),
        "generator_sha256": sha256(root / "tools/art/build_art_foliage.py"),
    }
    rows, tiles = rgba_rows(atlas_path), []
    for tile in range(16):
        origin_x, origin_y = tile % 4 * 512, (3 - tile // 4) * 512
        covered, alpha_total = 0, 0
        for row in rows[origin_y:origin_y + 512]:
            alpha = row[origin_x * 4 + 3:(origin_x + 512) * 4:4]
            covered += sum(value / 255.0 > 0.43 for value in alpha)
            alpha_total += sum(alpha)
        tiles.append({"tile": tile,
                      "alpha_scissor_043_coverage": covered / 512 ** 2,
                      "alpha_mean": alpha_total / (512 ** 2 * 255)})
    assert tiles[14]["alpha_mean"] == 1.0
    assert all(0.45 <= tiles[tile]["alpha_scissor_043_coverage"] <= 0.80
               for tile in [0, 1, 2, 3, 15])
    coverage = dict(common, passed=True, atlas_sha256=sha256(atlas_path), tiles=tiles)
    by_id = {entry["asset_id"]: entry for entry in entries}
    records = []
    for asset_id in ["NAT-01", "NAT-02", "NAT-03"]:
        high, low = by_id[asset_id], by_id[asset_id + "-LOD1"]
        high_path, low_path = root / high["export"], root / low["export"]
        high_dimensions, lod_dimensions = dimensions(high_path), dimensions(low_path)
        errors = [abs(a - b) / a for a, b in zip(high_dimensions, lod_dimensions)]
        assert all(error <= 0.12 for error in errors), (asset_id, errors)
        records.append({"asset_id": asset_id, "high_dimensions": high_dimensions,
                        "lod_dimensions": lod_dimensions, "relative_error": errors,
                        "high_export_sha256": sha256(high_path),
                        "lod_export_sha256": sha256(low_path)})
    bounds = dict(common, passed=True, axes="gltf_y_up: x, y, z",
                  max_allowed_relative_dimension_delta=0.12, records=records)
    assert before == {str(path): sha256(path) for path in watched}, "Production inputs changed"
    (source / "atlas_coverage_audit.json").write_text(json.dumps(coverage, indent=2) + "\n")
    (source / "lod_bounds_audit.json").write_text(json.dumps(bounds, indent=2) + "\n")
    print("FOLIAGE_EVIDENCE_AUDIT_PASS", version, "16 atlas tiles, 3 LOD pairs; source hashes unchanged")


if __name__ == "__main__":
    main()
