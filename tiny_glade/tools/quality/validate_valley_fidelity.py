"""Validate the actual four Valley derivatives, without a low-poly or density budget."""
import hashlib
import json
import math
import struct
from common import ROOT
from validate_painterly_grass import accessor

EXPECTED = {
    'Basic_Grass_13', 'Detailed_Wave_Grass_06',
    'Basic_Grass_04', 'Basic_Grass_Floor_10',
}


def validate(root=ROOT):
    manifest = json.loads((root / 'art_source/painterly_grass/valley_manifest.json').read_text())
    assert isinstance(manifest, list) and len(manifest) == 4
    assert {entry['vendor_object'] for entry in manifest} == EXPECTED
    rows = []
    textures = set()
    for entry in manifest:
        for key in ['source', 'export', 'texture']:
            path = root / entry[key]
            assert path.is_file(), path
            assert hashlib.sha256(path.read_bytes()).hexdigest() == entry[key + '_sha256'], path
        raw = (root / entry['export']).read_bytes()
        assert struct.unpack_from('<III', raw) == (0x46546C67, 2, len(raw))
        length, kind = struct.unpack_from('<II', raw, 12)
        assert kind == 0x4E4F534A
        gltf = json.loads(raw[20:20 + length])
        binary_size, binary_kind = struct.unpack_from('<II', raw, 20 + length)
        assert binary_kind == 0x004E4942
        binary = raw[28 + length:28 + length + binary_size]
        assert len(gltf['meshes']) == 1
        primitives = gltf['meshes'][0]['primitives']
        assert len(primitives) == 1
        primitive = primitives[0]
        assert primitive.get('mode', 4) == 4
        attrs = primitive['attributes']
        assert all(k in attrs for k in ['POSITION', 'NORMAL', 'TEXCOORD_0', 'COLOR_0'])
        points = accessor(gltf, binary, attrs['POSITION'])
        normals = accessor(gltf, binary, attrs['NORMAL'])
        colors = accessor(gltf, binary, attrs['COLOR_0'])
        indices = [index[0] for index in accessor(gltf, binary, primitive['indices'])]
        assert points and len(indices) > 0 and len(indices) % 3 == 0
        assert all(0 <= index < len(points) for index in indices)
        assert all(math.isfinite(v) for point in points + normals for v in point)
        assert len(colors) == len(points) and any(c[0] == 0 for c in colors)
        assert max(c[0] for c in colors) > 0
        triangles = len(indices) // 3
        assert triangles == entry['triangles'], entry['asset_id']
        dimensions = [max(p[k] for p in points) - min(p[k] for p in points) for k in range(3)]
        assert all(abs(a - b) < 1e-4 for a, b in zip(dimensions, entry['dimensions_y_up']))
        # The detailed tuft is a different, evaluated source. Do not accept an 8-triangle substitute.
        if entry['vendor_object'] == 'Detailed_Wave_Grass_06':
            assert triangles > 572, 'Original Subdivision must be applied for this fidelity study'
        texture = root / entry['texture']
        png = texture.read_bytes()
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack_from('>II', png, 16) == (4096, 4096)
        assert png[25] in [4, 6], 'Coverage must retain alpha instead of treating JPEG alpha as opacity'
        textures.add(entry['texture'])
        rows.append({'asset_id': entry['asset_id'], 'vendor_object': entry['vendor_object'],
                     'triangles': triangles, 'vertices': len(points), 'dimensions_y_up': dimensions,
                     'export_sha256': entry['export_sha256']})
    return {'passed': True, 'assets': rows, 'texture_size': [4096, 4096],
            'coverage_textures': sorted(textures), 'source_hashes_match': True,
            'performance_gate_run': False, 'visual_acceptance': 'requires user review'}


if __name__ == '__main__':
    output = ROOT / 'reports/valley_fidelity/asset_validation.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    result = validate()
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('VALLEY ASSET PROVENANCE PASS; visual acceptance remains manual')
