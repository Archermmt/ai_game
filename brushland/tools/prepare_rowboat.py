"""blender --background --factory-startup --python tools/prepare_rowboat.py -- SOURCE.glb OUT.glb"""
import hashlib
import math
import sys
from pathlib import Path

import bpy

source, target = map(Path, sys.argv[sys.argv.index("--") + 1:])
source_hash = "1c67afedc7b443d30f00f94610e338e3709c93c5066f102432855f71ffea442e"
if hashlib.sha256(source.read_bytes()).hexdigest() != source_hash:
    raise ValueError("Expected the Grab3D Rowboat glTF revision recorded in THIRD_PARTY_NOTICES.md")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source), merge_vertices=True)
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH':
        continue
    if obj.name.startswith('rowboat_oar_'):
        # Stow both oars along the gunwales for the one-cell-wide berth.
        obj.rotation_mode = 'XYZ'
        obj.rotation_euler.z = math.copysign(math.pi / 2, -obj.location.x)
        obj.location.x *= 0.81
    modifier = obj.modifiers.new("Island camera LOD", 'DECIMATE')
    modifier.ratio = 0.24

# Keep the hull's painted wood and waterline. Fine PBR relief reads as
# sparkle at the scale of a one-cell boat.
for material in bpy.data.materials:
    if not material.use_nodes:
        continue
    principled = next((node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED'), None)
    if not principled:
        continue
    for slot in ("Normal", "Metallic", "Roughness"):
        for link in list(principled.inputs[slot].links):
            material.node_tree.links.remove(link)
    principled.inputs["Roughness"].default_value = 0.87
    principled.inputs["Metallic"].default_value = 0
    for link in principled.inputs["Base Color"].links:
        if link.from_node.type == 'TEX_IMAGE':
            img = link.from_node.image
            img.scale(512, 512)
            img.pack()
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', export_apply=True,
                          export_animations=False, export_yup=True)
