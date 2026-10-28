"""Blender 5.1.2: preserve Valley grass geometry, source layout and ground heightfield.

Run with --root PROJECT --library ORIGINAL.blend. The vendor source is read only;
all derived Blender/GLB/texture assets remain in the ignored local directories.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def height_at(bvh, x, y):
    location, _normal, _face, _distance = bvh.ray_cast(Vector((x, y, 100)), Vector((0, 0, -1)), 200)
    if location is None:
        location, _normal, _face, _distance = bvh.find_nearest(Vector((x, y, 0)))
    assert location is not None
    return float(location.z)


parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--library', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
root = args.root.resolve()
library = args.library.resolve()
original_hash = sha256(library)
source_dir = root / 'art_source/painterly_grass/local/valley'
export_dir = root / 'assets/painterly_grass/local/valley'
source_dir.mkdir(parents=True, exist_ok=True)
export_dir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(library), load_ui=False, use_scripts=False)
scene = bpy.context.scene
ground = bpy.data.objects['Plane_low_res']
center = ground.matrix_world.translation.copy()
ground_points = [ground.matrix_world @ v.co for v in ground.data.vertices]
ground_faces = [list(p.vertices) for p in ground.data.polygons]
bvh = BVHTree.FromPolygons(ground_points, ground_faces)
conversion = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
camera = scene.camera
source_camera = {
    'name': camera.name if camera else None,
    'matrix_blender': [list(row) for row in camera.matrix_world] if camera else None,
    'lens_mm': camera.data.lens if camera else None,
    'sensor_width_mm': camera.data.sensor_width if camera else None,
}
choices = [
    ('blades', 'Basic_Grass_13', 'Blades Grass'),
    ('detail', 'Detailed_Wave_Grass_06', 'Detail Puffs'),
    ('puffs', 'Basic_Grass_04', 'Puffs2'),
    ('floor', 'Basic_Grass_Floor_10', 'Floor Grass'),
]

# Preserve evaluated local geometry including the original Detailed subdivision.
# Object-scale belongs to the GN instance basis and must not be baked twice.
records = []
deps = bpy.context.evaluated_depsgraph_get()
for asset_id, object_name, modifier_name in choices:
    obj = bpy.data.objects[object_name]
    evaluated = obj.evaluated_get(deps)
    mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=deps)
    mesh.calc_loop_triangles()
    normals = [list(n.vector) for n in mesh.corner_normals]
    records.append({
        'asset_id': asset_id, 'vendor_object': object_name, 'modifier': modifier_name,
        'vertices': [list(v.co) for v in mesh.vertices],
        'faces': [list(p.vertices) for p in mesh.polygons],
        'uv_names': list(mesh.uv_layers.keys()),
        'uv': [[list(slot.uv) for slot in layer.data] for layer in mesh.uv_layers],
        'normals': normals, 'smooth': [p.use_smooth for p in mesh.polygons],
        'triangles': len(mesh.loop_triangles),
        'source_object_scale': list(obj.scale),
        'modifiers_applied': len(obj.modifiers),
    })
    print('VALLEY_MODEL', asset_id, len(mesh.vertices), len(mesh.loop_triangles), flush=True)

# Source masks are RGB grayscale opacity. Save white RGB plus full-resolution
# linear alpha, with no JPEG-alpha assumption, downscale or thresholding.
image = bpy.data.images['CGM_Flora_Atlas_C.jpg']
width, height = image.size
assert width == height == 4096
pixels = np.array(image.pixels[:], dtype=np.float32).reshape((height, width, 4))
coverage = np.ones((height, width, 4), dtype=np.float32)
coverage[:, :, 3] = np.clip(pixels[:, :, :3].mean(axis=2), 0, 1)

# Evaluate each source Geometry Nodes layer independently, retaining its actual
# poses, source burial offset, slope alignment, scale and camera-facing result.
for obj in scene.objects:
    if obj != ground:
        obj.hide_set(True)
ground.hide_set(False)
modifiers = list(ground.modifiers)
patch_layers = []
full_layers = []
for asset_id, object_name, modifier_name in choices:
    for modifier in modifiers:
        modifier.show_viewport = modifier.name == modifier_name
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    patch_instances = []
    full_instances = []
    for instance in deps.object_instances:
        if not instance.is_instance or not instance.parent or instance.parent.original != ground:
            continue
        matrix = instance.matrix_world.copy()
        origin = matrix.translation
        converted = conversion @ matrix @ conversion.inverted()
        basis = [list(converted.col[i][:3]) for i in range(3)]
        offset = float(origin.z - height_at(bvh, origin.x, origin.y))
        entry = {
            'basis': basis,
            'position_local': [float(origin.x - center.x), float(origin.z - center.z), float(center.y - origin.y)],
            'ground_offset_m': offset,
        }
        full_instances.append(entry)
        if -6 <= origin.x < 2 and 0 <= origin.y < 8:
            patch_entry = dict(entry)
            patch_entry['position_local'] = [float(origin.x + 6), float(origin.z), float(8 - origin.y)]
            patch_instances.append(patch_entry)
    patch_layers.append({'asset_id': asset_id, 'vendor_object': object_name, 'instances': patch_instances})
    full_layers.append({'asset_id': asset_id, 'vendor_object': object_name, 'instances': full_instances})
    print('VALLEY_SCATTER', asset_id, len(full_instances), 'crop', len(patch_instances), flush=True)

patch_data = {
    'version': 1, 'library_sha256': original_hash,
    'crop_bounds_blender_world': [-6, 2, 0, 8],
    'mapping': 'Godot x=Blender world x+6; y=world z; z=8-world y. Basis is column-major Y-up; mesh raw origin is preserved.',
    'source_camera': source_camera, 'layers': patch_layers,
}
write_json(export_dir / 'scatter_patch.json', patch_data)
write_json(export_dir / 'scatter_full.json', {
    'version': 1, 'library_sha256': original_hash,
    'mapping': 'Godot x=world x-center.x; y=world z-center.z; z=center.y-world y; basis column-major Y-up.',
    'source_center_blender': list(center), 'source_camera': source_camera,
    'layers': full_layers,
})

# A 64m terrain region sampled from the actual demo surface rather than noise.
# Exterior samples continue the nearest original boundary and are marked below.
resolution = 256
span = 64.0
heightmap = np.empty((resolution, resolution), dtype='<f4')
outside = 0
for row in range(resolution):
    z = -span / 2 + row * span / (resolution - 1)
    for column in range(resolution):
        x = -span / 2 + column * span / (resolution - 1)
        wx, wy = x + center.x, center.y - z
        ray, _n, _f, _d = bvh.ray_cast(Vector((wx, wy, 100)), Vector((0, 0, -1)), 200)
        if ray is None:
            outside += 1
        heightmap[row, column] = height_at(bvh, wx, wy) - center.z
heightmap.tofile(str(export_dir / 'terrain_height.r32'))
terrain_info = {
    'version': 1, 'library_sha256': original_hash, 'vendor_object': ground.name,
    'file': 'terrain_height.r32', 'format': 'little-endian float32, row-major, Godot x increasing within row and z increasing per row',
    'resolution': [resolution, resolution], 'origin_xz': [-32.0, -32.0], 'size_m': [64.0, 64.0],
    'vertex_spacing_m': span / (resolution - 1), 'source_center_blender': list(center),
    'minimum_m': float(heightmap.min()), 'maximum_m': float(heightmap.max()),
    'outside_samples_nearest_boundary': outside,
    'sha256': sha256(export_dir / 'terrain_height.r32'),
}
write_json(export_dir / 'terrain_height.json', terrain_info)
print('VALLEY_HEIGHTMAP', terrain_info, flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
shared = bpy.data.images.new('ValleyGrassCoverage4k', width, height, alpha=True, is_data=True)
shared.pixels.foreach_set(coverage.ravel())
shared.file_format = 'PNG'
shared.filepath_raw = str(export_dir / 'coverage4k.png')
shared.save()
reference = library.with_suffix('.png')
if reference.is_file():
    shutil.copy2(reference, export_dir / 'reference.png')
manifest = []
for record in records:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    mesh = bpy.data.meshes.new(record['asset_id'])
    mesh.from_pydata(record['vertices'], [], record['faces'])
    mesh.update()
    for face, smooth in zip(mesh.polygons, record['smooth']):
        face.use_smooth = smooth
    if record['normals']:
        mesh.normals_split_custom_set(record['normals'])
    for index, name in enumerate(record['uv_names']):
        layer = mesh.uv_layers.new(name=name)
        for slot, value in zip(layer.data, record['uv'][index]):
            slot.uv = value
    mesh.uv_layers.active_index = 0
    color = mesh.color_attributes.new(name='wind_mask', type='FLOAT_COLOR', domain='CORNER')
    min_z = min(v.co.z for v in mesh.vertices)
    max_z = max(v.co.z for v in mesh.vertices)
    for loop in mesh.loops:
        weight = max(0.0, min(1.0, (mesh.vertices[loop.vertex_index].co.z - min_z) / max(0.001, max_z-min_z)))
        color.data[loop.index].color = (weight, 0.35, 0.0, 1.0)
    obj = bpy.data.objects.new('GrassSample', mesh)
    scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    material = bpy.data.materials.new('ValleyGrassPreview')
    material.use_nodes = True
    material.use_backface_culling = False
    material.surface_render_method = 'DITHERED'
    bsdf = material.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (0.116373, 0.102514, 0.004747, 1)
    bsdf.inputs['Roughness'].default_value = 0.95
    texture = material.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image = bpy.data.images.load(str(export_dir / 'coverage4k.png'))
    texture.image.pack()
    material.node_tree.links.new(texture.outputs['Alpha'], bsdf.inputs['Alpha'])
    mesh.materials.append(material)
    socket = bpy.data.objects.new('socket_ground', None)
    scene.collection.objects.link(socket)
    socket.empty_display_size = 0.1
    source = source_dir / (record['asset_id'] + '.blend')
    export = export_dir / (record['asset_id'] + '.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(export), export_format='GLB', export_yup=True,
        export_apply=True, export_cameras=False, export_lights=False, export_materials='NONE',
        export_vertex_color='NAME', export_vertex_color_name='wind_mask',
        export_all_vertex_colors=False, export_texcoords=True, export_normals=True)
    mesh.calc_loop_triangles()
    assert len(mesh.loop_triangles) == record['triangles']
    entry = {key: value for key, value in record.items() if key not in ['vertices', 'faces', 'uv', 'normals', 'smooth']}
    entry.update({
        'source': str(source.relative_to(root)), 'export': str(export.relative_to(root)),
        'budget': record['triangles'], 'vertices': len(mesh.vertices), 'sockets': ['socket_ground'],
        'source_sha256': sha256(source), 'export_sha256': sha256(export),
        'dimensions_y_up': [float(obj.dimensions.x), float(obj.dimensions.z), float(obj.dimensions.y)],
        'material_surfaces': 1, 'generator_version': 'valley_grass_extract_1',
        'library_sha256': original_hash, 'texture': str((export_dir / 'coverage4k.png').relative_to(root)),
        'texture_sha256': sha256(export_dir / 'coverage4k.png'),
        'origin': 'original raw mesh origin; pair with GN instance basis and burial offset',
        'up_axis': 'gltf Y-up', 'normals': 'original evaluated corner normals preserved',
        'license_status': 'local-only; repository/distribution terms pending',
    })
    manifest.append(entry)
assert sha256(library) == original_hash
write_json(root / 'art_source/painterly_grass/valley_manifest.json', manifest)
print('VALLEY_EXTRACTION_PASS', len(manifest), 'source unchanged', original_hash, flush=True)
