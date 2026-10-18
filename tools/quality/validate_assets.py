"""Check source/export contracts without needing Blender on the CI runner."""

import argparse
import hashlib
import json
import struct
from pathlib import Path

from common import ROOT


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--week", type=int, default=1)
    args = parser.parse_args()
    manifest = []
    for week in range(1, args.week + 1):
        manifest.extend(json.loads((ROOT / f"art_source/week_{week:02d}/manifest.json").read_text()))
    ids = set()
    for asset in manifest:
        assert asset["asset_id"] not in ids, "duplicate asset ID"
        ids.add(asset["asset_id"])
        assert (ROOT / asset["source"]).is_file(), asset["source"]
        assert asset["triangles"] > 0
        raw = (ROOT / asset["export"]).read_bytes()
        magic, version, length = struct.unpack_from("<III", raw)
        assert magic == 0x46546C67 and version == 2 and length == len(raw), asset["export"]
        json_size, json_type = struct.unpack_from("<II", raw, 12)
        assert json_type == 0x4E4F534A
        gltf = json.loads(raw[20 : 20 + json_size])
        for mesh in gltf.get("meshes", []):
            for primitive in mesh["primitives"]:
                assert "COLOR_0" in primitive["attributes"], asset["export"]
                assert "TEXCOORD_0" in primitive["attributes"], asset["export"]
        for socket in asset["sockets"]:
            assert any(node.get("name") == socket for node in gltf["nodes"]), socket
        for texture in gltf.get("images", []):
            assert not texture.get("uri", "").startswith(("/", "file://"))
    expected = {"BLD-05", "BLD-06", "BLD-07", "SAMPLE-TREE", "SAMPLE-CLOTH", "SAMPLE-BENCH"}
    if args.week >= 2:
        expected |= {"BLD-08", "BLD-09", "NAT-01", "NAT-02", "NAT-03"}
        materials = json.loads((ROOT / "art_source/week_02/material_manifest.json").read_text())
        assert len(materials) == 8
        for material in materials:
            raw = (ROOT / material["export"]).read_bytes()
            assert raw[:8] == b"\x89PNG\r\n\x1a\n"
            assert list(struct.unpack_from(">II", raw, 16)) == material["resolution"]
            assert hashlib.sha256(raw).digest() == hashlib.sha256((ROOT / material["source"]).read_bytes()).digest()
        assert (ROOT / "art_source/week_02/painted_material_library.blend").is_file()
    assert expected == ids
    assert (ROOT / "docs/.gdignore").is_file()
    assert (ROOT / "art_source/.gdignore").is_file()
    print(f"ASSET CONTRACT PASS: {len(manifest)} editable sources + GLB exports, UV, COLOR_0, sockets")


if __name__ == "__main__":
    main()
