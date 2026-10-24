"""Check committed original sources, GLB geometry budgets and painted-map hashes."""
import hashlib
import json
import struct
from pathlib import Path
from common import ROOT


def main():
    sources = json.loads((ROOT / "art_source/art_pass_01/nature/manifest.json").read_text())
    assert len(sources) == 11
    for item in sources:
        source = ROOT / item["source"]
        target = ROOT / item["export"]
        # Blender 5.1 saves Zstandard-compressed .blend files by default.
        assert source.read_bytes().startswith((b"BLENDER", b"\x28\xb5\x2f\xfd")), source
        raw = target.read_bytes()
        assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 4)[0] == 2, target
        size, chunk_type = struct.unpack_from("<II", raw, 12)
        assert chunk_type == 0x4E4F534A
        gltf = json.loads(raw[20:20 + size])
        triangles = 0
        for mesh in gltf["meshes"]:
            for part in mesh["primitives"]:
                assert {"POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"} <= part["attributes"].keys()
                accessor = part.get("indices", part["attributes"]["POSITION"])
                triangles += gltf["accessors"][accessor]["count"] // 3
        assert triangles == item["triangles"] <= item["budget"], (target, triangles)
        importer = Path(str(target) + ".import").read_text()
        assert "meshes/generate_lods=false" in importer, target
        assert item["sockets"] and item["source_license"]
    materials = json.loads((ROOT / "art_source/art_pass_01/materials/manifest.json").read_text())
    assert len(materials["textures"]) == 9
    for item in materials["textures"]:
        source = (ROOT / item["source"]).read_bytes()
        target = (ROOT / item["export"]).read_bytes()
        assert source == target
        assert hashlib.sha256(target).hexdigest() == item["sha256"], item["name"]
        assert target[:8] == b"\x89PNG\r\n\x1a\n"
        assert list(struct.unpack_from(">II", target, 16)) == item["resolution"]
        assert item["license"]
    library = ROOT / "art_source/art_pass_01/materials/painted_material_library.blend"
    assert library.read_bytes().startswith((b"BLENDER", b"\x28\xb5\x2f\xfd"))
    reopen = json.loads((ROOT / "art_source/art_pass_01/nature/source_reopen_audit.json").read_text())
    assert len(reopen["sources"]) == 11 and all(item["passed"] for item in reopen["sources"])
    exports = json.loads((ROOT / "art_source/art_pass_01/nature/glb_contract_audit.json").read_text())
    for item in exports["exports"]:
        assert item["passed"] and hashlib.sha256((ROOT / item["export"]).read_bytes()).hexdigest() == item["sha256"]
    assert (ROOT / "assets/nature/art_pass_01/painted_forest_atlas.png").read_bytes() == (ROOT / "art_source/art_pass_01/nature/painted_forest_atlas.png").read_bytes()
    ui = json.loads((ROOT / "art_source/art_pass_01/ui/manifest.json").read_text())
    thumbnail = (ROOT / ui["export"]).read_bytes()
    assert hashlib.sha256(thumbnail).hexdigest() == ui["sha256"]
    assert list(struct.unpack_from(">II", thumbnail, 16)) == ui["size"] == [512, 288]
    assert list(struct.unpack_from(">II", (ROOT / ui["source"]).read_bytes(), 16)) == [1920, 1080]
    print("ART-01 source/GLB/painted-map contracts pass: 11 Blender models, 9 maps, 1 atlas")


if __name__ == "__main__":
    main()
