"""Blender5.1.2: extract three local-only samples; never save the vendor source."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--library', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
root = args.root.resolve()
library = args.library.resolve()
original_hash = hashlib.sha256(library.read_bytes()).hexdigest()
source_dir = root / 'art_source/painterly_grass/local'
export_dir = root / 'assets/painterly_grass/local'
source_dir.mkdir(parents=True, exist_ok=True)
export_dir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(library), load_ui=False, use_scripts=False)
choices = [('grass_card_a', 'Basic_Grass_Card_01', 0.5),
           ('grass_card_b', 'Basic_Grass_Card_03', 0.5),
           ('grass_floor', 'Basic_Grass_Floor_04', 0.75)]
records = []
for asset_id, name, scale in choices:
    obj = bpy.data.objects[name]
    assert not obj.modifiers and len(obj.data.materials) == 1
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles) == 8
    records.append({'asset_id': asset_id, 'vendor_object': name, 'scale_factor': scale,
                    'vertices': [list(v.co) for v in obj.data.vertices],
                    'faces': [list(p.vertices) for p in obj.data.polygons],
                    'uv': [[list(x.uv) for x in layer.data] for layer in obj.data.uv_layers],
                    'uv_names': list(obj.data.uv_layers.keys())})
# The vendor material connects atlas RGB to opacity, not its nonexistent JPEG alpha.
image = bpy.data.images['CGC_Flora_Atlas_C.jpg']
image.scale(2048, 2048)
pixels = np.array(image.pixels[:], dtype=np.float32).reshape((2048, 2048, 4))
mask = np.clip(pixels[:, :, :3].mean(axis=2), 0, 1)
assert mask.max() > 0.95 and mask.min() < 0.01
rgba = np.ones((2048, 2048, 4), dtype=np.float32)
rgba[:, :, 3] = mask
bpy.ops.wm.read_factory_settings(use_empty=True)
shared = bpy.data.images.new('PainterlyGrassCoverage', 2048, 2048, alpha=True, is_data=True)
shared.pixels.foreach_set(rgba.ravel())
shared.file_format = 'PNG'
shared.filepath_raw = str(export_dir / 'grass_coverage.png')
shared.save()
manifest = []
for record in records:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    scene.render.engine = 'CYCLES'
    # Vendor coordinates are Z-up; glTF alone performs the conversion to Y-up.
    points = np.array(record['vertices']) * record['scale_factor']
    minimum = points[:, 2].min()
    points[:, 2] -= minimum
    xy_center = (points[:, :2].min(axis=0) + points[:, :2].max(axis=0)) / 2
    points[:, :2] -= xy_center
    mesh = bpy.data.meshes.new(record['asset_id'])
    mesh.from_pydata(points.tolist(), [], record['faces'])
    mesh.update()
    obj = bpy.data.objects.new('GrassSample', mesh)
    scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for index, name in enumerate(record['uv_names']):
        layer = mesh.uv_layers.new(name=name)
        for slot, value in zip(layer.data, record['uv'][index]):
            slot.uv = value
    mesh.uv_layers.active_index = 0
    colors = mesh.color_attributes.new(name='wind_mask', type='BYTE_COLOR', domain='CORNER')
    top = max(v.co.z for v in mesh.vertices)
    for loop in mesh.loops:
        weight = mesh.vertices[loop.vertex_index].co.z / top
        colors.data[loop.index].color = (weight, 0.35, 0, 1)
    material = bpy.data.materials.new('GrassPreview')
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (0.13, 0.23, 0.06, 1)
    bsdf.inputs['Roughness'].default_value = 0.95
    texture = material.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image = bpy.data.images.load(str(export_dir / 'grass_coverage.png'))
    texture.image.pack()
    material.node_tree.links.new(texture.outputs['Alpha'], bsdf.inputs['Alpha'])
    material.surface_render_method = 'DITHERED'
    material.use_backface_culling = False
    mesh.materials.append(material)
    ground = bpy.data.objects.new('socket_ground', None)
    scene.collection.objects.link(ground)
    ground.empty_display_size = 0.1
    source = source_dir / (record['asset_id'] + '.blend')
    export = export_dir / (record['asset_id'] + '.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(export), export_format='GLB', export_yup=True,
        export_apply=True, export_cameras=False, export_lights=False, export_materials='NONE',
        export_vertex_color='NAME', export_vertex_color_name='wind_mask',
        export_all_vertex_colors=False, export_texcoords=True, export_normals=True)
    mesh.calc_loop_triangles()
    assert len(mesh.loop_triangles) == 8
    entry = {k:v for k,v in record.items() if k not in ['vertices', 'faces', 'uv']}
    entry.update(source=str(source.relative_to(root)), export=str(export.relative_to(root)),
        triangles=8, budget=12, vertices=len(mesh.vertices), sockets=['socket_ground'],
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        export_sha256=hashlib.sha256(export.read_bytes()).hexdigest(),
        dimensions_y_up=[float(points[:, 0].max()-points[:, 0].min()), float(top),
                         float(points[:, 1].max()-points[:, 1].min())],
        material_surfaces=1, modifiers_applied=0, generator_version='painterly_grass_extract_1',
        library_sha256=original_hash, texture='assets/painterly_grass/local/grass_coverage.png',
        texture_sha256=hashlib.sha256((export_dir/'grass_coverage.png').read_bytes()).hexdigest(),
        uv_mapping={'UVMap':'TEXCOORD_0 coverage', 'UVRandom':'same UV; replace randomness with INSTANCE_CUSTOM',
                    'UVAniso':'same UV; no anisotropic dependency'},
        wind_channels={'R':'normalized local height; roots zero', 'G':'local flutter seed', 'B':'reserved', 'A':'1'},
        origin='ground centered', up_axis='gltf Y-up', license_status='local-only; repository/distribution terms pending')
    manifest.append(entry)
assert hashlib.sha256(library.read_bytes()).hexdigest() == original_hash
(root/'art_source/painterly_grass/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('PAINTERLY_GRASS_EXTRACTION_PASS',len(manifest),'source unchanged',original_hash)
