"""Validate actual local GLB/PNG bytes, source traceability and post-export budgets."""
import hashlib
import json
import math
from pathlib import Path
import struct
from common import ROOT


def accessor(gltf, binary, index):
    a = gltf['accessors'][index]
    view = gltf['bufferViews'][a['bufferView']]
    types = {5126: ('f', 4), 5123: ('H', 2), 5121: ('B', 1), 5125: ('I', 4)}
    code, width = types[a['componentType']]
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = view.get('byteStride', width * count)
    return [struct.unpack_from('<' + code * count, binary, offset + i * stride) for i in range(a['count'])]


def validate(root=ROOT):
    manifest = json.loads((root/'art_source/painterly_grass/manifest.json').read_text())
    assert len(manifest) == 3
    rows = []
    for entry in manifest:
        for key in ['source', 'export', 'texture']:
            path = root/entry[key]
            assert path.is_file(), path
            assert hashlib.sha256(path.read_bytes()).hexdigest() == entry[key + '_sha256'], path
        raw = (root/entry['export']).read_bytes()
        assert struct.unpack_from('<III', raw) == (0x46546C67, 2, len(raw))
        length, chunk = struct.unpack_from('<II', raw, 12)
        assert chunk == 0x4E4F534A
        gltf = json.loads(raw[20:20+length])
        binary_size, binary_type = struct.unpack_from('<II', raw, 20+length)
        assert binary_type == 0x004E4942
        binary = raw[28+length:28+length+binary_size]
        assert len(gltf['meshes']) == 1 and not gltf.get('images') and not gltf.get('materials')
        primitives = gltf['meshes'][0]['primitives']
        assert len(primitives) == 1
        primitive = primitives[0]
        assert primitive.get('mode', 4) == 4
        attrs = primitive['attributes']
        assert all(k in attrs for k in ['POSITION', 'NORMAL', 'TEXCOORD_0', 'COLOR_0'])
        points = accessor(gltf, binary, attrs['POSITION'])
        colors = accessor(gltf, binary, attrs['COLOR_0'])
        indices = [i[0] for i in accessor(gltf, binary, primitive['indices'])]
        assert len(indices) == 24 and len(points) <= 32
        assert all(math.isfinite(v) for point in points for v in point)
        assert min(p[1] for p in points) >= -1e-5
        size = [max(p[k] for p in points)-min(p[k] for p in points) for k in range(3)]
        assert all(abs(a-b) < 1e-5 for a,b in zip(size, entry['dimensions_y_up']))
        assert any(c[0] == 0 for c in colors) and max(c[0] for c in colors) > 0
        for i in range(0, len(indices), 3):
            p,q,r = (points[indices[i+j]] for j in range(3))
            a = [q[j]-p[j] for j in range(3)]; b = [r[j]-p[j] for j in range(3)]
            cross = [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
            assert sum(c*c for c in cross) > 1e-12
        rows.append({'asset_id':entry['asset_id'], 'triangles':len(indices)//3,
                     'exported_vertices':len(points), 'surfaces':1,'dimensions_y_up':size,
                     'export_sha256':entry['export_sha256']})
    texture = root/manifest[0]['texture']
    assert all(e['texture'] == manifest[0]['texture'] for e in manifest)
    png = texture.read_bytes()
    assert png[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack_from('>II', png, 16) == (2048, 2048)
    return {'assets':rows,'texture_size':[2048,2048],'shared_textures':1,
            'source_hashes_match':True,'passed':True,'repository_asset_terms':'pending; local derivatives only'}


if __name__ == '__main__':
    result = validate()
    output = ROOT/'reports/week_14/g1/asset_validation.json'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print('G1 ASSET VALIDATION PASS:', len(result['assets']))
