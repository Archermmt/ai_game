"""Check source/export contracts without needing Blender on the CI runner."""

import json
import struct
from pathlib import Path

from common import ROOT


def main():
    manifest = json.loads((ROOT / "art_source/week_01/manifest.json").read_text())
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
    assert {"BLD-05", "BLD-06", "BLD-07", "SAMPLE-TREE", "SAMPLE-CLOTH", "SAMPLE-BENCH"} == ids
    assert (ROOT / "docs/.gdignore").is_file()
    assert (ROOT / "art_source/.gdignore").is_file()
    print(f"ASSET CONTRACT PASS: {len(manifest)} editable sources + GLB exports, UV, COLOR_0, sockets")


if __name__ == "__main__":
    main()
