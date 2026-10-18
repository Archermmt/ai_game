"""Run with Blender --background --python this_file -- --root PROJECT_ROOT.

Deterministic, editable Week 1 source assets. No online content or optional add-ons.
"""

import argparse
import json
import math
import sys
from pathlib import Path

import bpy

parser = argparse.ArgumentParser()
parser.add_argument("--root", required=True)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
root = Path(args.root).resolve()
source_root = root / "art_source" / "week_01"
source_root.mkdir(parents=True, exist_ok=True)

PALETTE = {
    "wood": (0.56, 0.34, 0.17, 1),
    "plaster": (0.81, 0.74, 0.58, 1),
    "tile": (0.55, 0.25, 0.14, 1),
    "stone": (0.39, 0.43, 0.34, 1),
    "foliage": (0.29, 0.43, 0.19, 1),
    "cloth": (0.85, 0.81, 0.66, 1),
    "metal": (0.18, 0.23, 0.19, 1),
    "glass": (0.24, 0.39, 0.34, 1),
}


def material(name):
    result = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    result.diffuse_color = PALETTE[name]
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = PALETTE[name]
    shader.inputs["Roughness"].default_value = 0.88
    return result


def mesh_object(name, vertices, faces, material_name="wood"):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(material_name))
    return obj


def box(name, location, dimensions, material_name="wood", bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(material_name))
    if bevel:
        modifier = obj.modifiers.new("soft_edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def socket(name, location):
    obj = bpy.data.objects.new(name, None)
    obj.location = location
    bpy.context.collection.objects.link(obj)
    return obj


def extrude_profile(name, points, thickness, offset=0, material_name="wood"):
    vertices = [(x, offset - thickness / 2, z) for x, z in points]
    vertices += [(x, offset + thickness / 2, z) for x, z in points]
    n = len(points)
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh_object(name, vertices, faces, material_name)


def door(kind):
    if kind == "arch":
        points = [(-0.5, 0), (0.5, 0), (0.5, 1.5)]
        points += [(math.cos(i * math.pi / 16) * 0.5, 1.5 + math.sin(i * math.pi / 16) * 0.5) for i in range(1, 17)]
        extrude_profile("arched_door", points, 0.12)
        for i in range(16):
            angle = (i + 0.5) * math.pi / 16
            obj = box("arch_frame_%02d" % i, (math.cos(angle) * 0.57, 0, 1.5 + math.sin(angle) * 0.57), (0.13, 0.2, 0.14))
            obj.rotation_euler.y = math.pi / 2 - angle
    else:
        box("door_panel", (0, 0, 1), (1, 0.12, 2))
        box("frame_top", (0, 0, 2.04), (1.2, 0.2, 0.12))
        if kind == "glass":
            box("glass_insert", (0, -0.071, 1.42), (0.58, 0.035, 0.65), "glass", 0)
            box("window_mullion", (0, -0.105, 1.42), (0.05, 0.04, 0.65))
            box("window_crossbar", (0, -0.105, 1.42), (0.58, 0.04, 0.05))
    frame_height = 1.5 if kind == "arch" else 2.0
    for x in [-0.57, 0.57]:
        box("frame_post", (x, 0, frame_height / 2), (0.14, 0.2, frame_height))
    for z in [0.35, 1.3]:
        box("iron_hinge", (-0.33, -0.09, z), (0.27, 0.035, 0.05), "metal", 0.008)
    box("handle", (0.32, -0.12, 0.95), (0.06, 0.06, 0.12), "metal", 0.015)
    box("dark_inner_lining", (0, 0.14, 1.0), (1.0, 0.035, 1.98), "metal", 0)
    socket("socket_wall_mount", (0, 0.1, 0))


def tree():
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.28, radius2=0.12, depth=2.9, location=(0, 0, 1.45))
    bpy.context.object.name = "tree_trunk"
    bpy.context.object.data.materials.append(material("wood"))
    for index, (x, y, z, scale) in enumerate([
        (0, 0, 3.6, 1.45), (-0.9, 0.1, 2.9, 1.0), (0.8, 0.35, 3.0, 1.15),
        (0.1, -0.7, 3.0, 1.1), (0.15, 0.65, 3.7, 0.9), (-0.4, -0.15, 4.3, 0.8),
    ]):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=(x, y, z))
        obj = bpy.context.object
        obj.name = "leaves_%02d" % index
        obj.scale = (scale, scale * 0.85, scale * 0.78)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.data.materials.append(material("foliage"))
    socket("socket_ground", (0, 0, 0))


def cloth():
    for x in [-1.25, 1.25]:
        box("rack_post", (x, 0, 1.1), (0.09, 0.1, 2.2))
        box("rack_foot", (x, 0, 0.06), (0.16, 0.85, 0.12))
    box("rack_crossbar", (0, 0, 2.1), (2.65, 0.1, 0.1))
    for sheet_index in range(2):
        vertices = []
        for row in range(9):
            for col in range(9):
                x = -1.02 + col / 8 * 0.83 + sheet_index * 1.15
                z = 2.04 - row / 8 * 1.25
                y = math.sin(col / 8 * math.pi * 3) * 0.035 + math.sin(row / 8 * math.pi) * 0.05
                vertices.append((x, y, z))
        faces = []
        for row in range(8):
            for col in range(8):
                i = row * 9 + col
                faces.append((i, i + 1, i + 10, i + 9))
        mesh_object("cloth_%d" % sheet_index, vertices, faces, "cloth")
    socket("socket_ground", (0, 0, 0))


def bench():
    for x in [-0.75, 0.75]:
        for y in [-0.22, 0.22]:
            box("bench_leg", (x, y, 0.25), (0.12, 0.12, 0.5))
        box("back_post", (x, 0.25, 0.65), (0.1, 0.12, 1.0))
    for y in [-0.2, 0, 0.2]:
        box("seat_plank", (0, y, 0.53), (1.9, 0.17, 0.09))
    for z in [0.85, 1.08]:
        box("back_plank", (0, 0.26, z), (1.9, 0.08, 0.15))
    socket("socket_tea_surface", (0.2, 0, 0.58))
    socket("socket_ground", (0, 0, 0))


def prepare_meshes():
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        colors = obj.data.color_attributes.new(name="wind_mask", type="FLOAT_COLOR", domain="POINT")
        for vertex, color in zip(obj.data.vertices, colors.data):
            weight = 0
            if obj.name.startswith("leaves"):
                weight = max(0, min(1, vertex.co.z / 5))
            elif obj.name.startswith("cloth"):
                weight = max(0, min(1, (2.04 - vertex.co.z) / 1.25))
            color.color = (weight, weight * weight, 0, 1)
        obj.data.color_attributes.active_color = colors
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.uv.smart_project(island_margin=0.03)
        bpy.ops.object.mode_set(mode="OBJECT")


manifest = []
for name, asset_id, folder, build in [
    ("door_plank", "BLD-05", "buildings", lambda: door("plank")),
    ("door_arch", "BLD-06", "buildings", lambda: door("arch")),
    ("door_glass", "BLD-07", "buildings", lambda: door("glass")),
    ("tree_sample", "SAMPLE-TREE", "samples", tree),
    ("cloth_sample", "SAMPLE-CLOTH", "samples", cloth),
    ("bench_sample", "SAMPLE-BENCH", "samples", bench),
]:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    build()
    prepare_meshes()
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1
    source = source_root / (name + ".blend")
    destination = root / "assets" / folder / (name + ".glb")
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(
        filepath=str(destination), export_format="GLB", export_yup=True,
        export_cameras=False, export_lights=False, export_apply=True,
        export_vertex_color="NAME", export_vertex_color_name="wind_mask",
        export_all_vertex_colors=False, export_extras=False,
    )
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    triangles = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)
    metadata = {
        "asset_id": asset_id, "source": str(source.relative_to(root)),
        "export": str(destination.relative_to(root)), "blender": bpy.app.version_string,
        "units": "meters", "up_axis": "gltf_y_up", "triangles": triangles,
        "material_slots": sorted({m.name for o in objects for m in o.data.materials}),
        "sockets": [o.name for o in bpy.context.scene.objects if o.type == "EMPTY"],
        "wind_color": "COLOR_0.r primary; .g secondary; .b reserved; .a=1",
        "source_license": "Project original; generated by project-owned Blender Python script",
        "stage": "week_01_sample" if name.endswith("sample") else "source_model_pending_integration",
    }
    destination.with_suffix(".asset.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    manifest.append(metadata)
(source_root / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print("WEEK_ONE_ASSETS_OK", len(manifest))
