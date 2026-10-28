"""Read-only Blender asset inventory. Never saves or evaluates scatter instances."""
import argparse
import collections
import hashlib
import json
import sys
from pathlib import Path
import bpy

parser = argparse.ArgumentParser()
parser.add_argument('--asset-root', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
root = args.asset_root.resolve()
files = sorted(root.rglob('*.blend'))
results = []
for path in files:
    bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
    meshes = []
    for mesh in bpy.data.meshes:
        mesh.calc_loop_triangles()
        meshes.append({'name': mesh.name, 'vertices': len(mesh.vertices), 'triangles': len(mesh.loop_triangles),
                       'materials': [m.name if m else None for m in mesh.materials],
                       'uv_layers': list(mesh.uv_layers.keys()), 'attributes': list(mesh.attributes.keys())})
    objects = []
    for obj in bpy.data.objects:
        item = {'name': obj.name, 'type': obj.type, 'data': obj.data.name if obj.data else None,
                'dimensions': list(obj.dimensions), 'asset': bool(obj.asset_data),
                'modifiers': [{'name': m.name, 'type': m.type, 'node_group': getattr(getattr(m, 'node_group', None), 'name', None)} for m in obj.modifiers]}
        if obj.particle_systems:
            item['particles'] = [{'name': p.name, 'count': p.settings.count, 'child_type': p.settings.child_type,
                                  'rendered_child_count': p.settings.rendered_child_count,
                                  'render_type': p.settings.render_type,
                                  'instance_collection': getattr(p.settings.instance_collection, 'name', None),
                                  'instance_object': getattr(p.settings.instance_object, 'name', None)} for p in obj.particle_systems]
        objects.append(item)
    def tree_info(tree):
        return {'name': tree.name, 'types': dict(collections.Counter(n.bl_idname for n in tree.nodes)),
                'groups': sorted(set(n.node_tree.name for n in tree.nodes if n.type == 'GROUP' and n.node_tree)),
                'images': sorted(set(n.image.name for n in tree.nodes if n.type == 'TEX_IMAGE' and n.image)),
                'attributes': sorted(set(getattr(n, 'attribute_name', '') for n in tree.nodes if n.type == 'ATTRIBUTE'))}
    materials = [dict(name=m.name, **{'tree': tree_info(m.node_tree) if m.node_tree else None}) for m in bpy.data.materials]
    images = [{'name': i.name, 'size': list(i.size), 'source': i.source,
               'packed': bool(i.packed_file), 'filepath': i.filepath,
               'external_exists': Path(bpy.path.abspath(i.filepath)).is_file() if i.filepath else False} for i in bpy.data.images]
    results.append({'file': str(path.relative_to(root)), 'bytes': path.stat().st_size,
                    'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                    'scenes': [{'name': s.name, 'engine': s.render.engine, 'resolution': [s.render.resolution_x, s.render.resolution_y],
                                'samples': s.cycles.samples, 'world': getattr(s.world, 'name', None)} for s in bpy.data.scenes],
                    'meshes': meshes, 'objects': objects, 'materials': materials,
                    'node_groups': [tree_info(g) for g in bpy.data.node_groups], 'images': images,
                    'libraries': [l.filepath for l in bpy.data.libraries],
                    'texts': [{'name': t.name, 'text': t.as_string()[:12000]} for t in bpy.data.texts]})
    print('INVENTORY', path.name, len(meshes), 'meshes', flush=True)
assert results and any('CGC_Painterly_Grass_1.0.blend' in r['file'] for r in results)
# Keep the primary library detailed; demo inventories retain only decision-relevant data.
for result in results:
    result['counts'] = {key: len(result[key]) for key in ['meshes', 'objects', 'materials', 'images', 'node_groups']}
    if not result['file'].startswith('CGC_Painterly_Grass_1.0/'):
        result['scatter_modifiers'] = [dict(object=o['name'], modifiers=o['modifiers'])
                                       for o in result['objects'] if any(m['type'] == 'NODES' for m in o['modifiers'])]
        result['node_type_counts'] = dict(sum((collections.Counter(g['types']) for g in result['node_groups']), collections.Counter()))
        for key in ['meshes', 'objects', 'materials', 'node_groups']:
            del result[key]
    assert hashlib.sha256((root / result['file']).read_bytes()).hexdigest() == result['sha256'], result['file']
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'blender': bpy.app.version_string, 'read_only': True,
                                  'evaluated_scatter': False, 'files': results}, ensure_ascii=False, indent=2) + '\n')
print('INSPECTION_OK', len(results), flush=True)
