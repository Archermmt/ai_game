"""Rebuild the foreground homes with Blender --background --python <this file>."""

from dataclasses import dataclass
from pathlib import Path

import bmesh
import bpy

OUTPUT = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0


def swatch(name, hex_code):
    channels = [int(hex_code[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    linear = [
        v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels
    ]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*linear, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return mat


@dataclass
class House:
    name: str
    width: float
    depth: float
    wall: float
    sill: float
    rise: float
    roof_color: str
    trim: str
    roof_end: str
    plaster: str
    skirt: str
    footing: str


HOUSES = [
    House(
        "teal_house",
        3.006,
        3.00,
        2.513,
        0.87,
        0.85,
        "7fadb8",
        "567580",
        "405d6c",
        "e4d6d1",
        "8e6043",
        "a39782",
    ),
    House(
        "umber_house",
        2.591,
        2.279,
        2.385,
        0.89,
        0.702,
        "ae8a6b",
        "805f47",
        "967357",
        "d7c9c1",
        "76482b",
        "a79983",
    ),
    House(
        "slate_shed",
        1.985,
        2.260,
        2.085,
        0.09,
        0.560,
        "a6b2c2",
        "727e8d",
        "86929f",
        "d1d6e7",
        "858992",
        "95989c",
    ),
]


def solid(collection, name, vertices, faces, materials, face_material=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for mat in materials:
        mesh.materials.append(mat)
    if face_material:
        for polygon, index in zip(mesh.polygons, face_material):
            polygon.material_index = index
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    collection.objects.link(ob)
    return ob


def box(collection, name, mat, center, size):
    x, y, z = center
    w, d, h = [v / 2 for v in size]
    points = [
        (x + sx * w, y + sy * d, z + sz * h)
        for sz in (-1, 1)
        for sy in (-1, 1)
        for sx in (-1, 1)
    ]
    return solid(
        collection,
        name,
        points,
        [
            (0, 1, 3, 2),
            (4, 6, 7, 5),
            (0, 4, 5, 1),
            (2, 3, 7, 6),
            (1, 5, 7, 3),
            (0, 2, 6, 4),
        ],
        [mat],
    )


def make_house(spec):
    collection = bpy.data.collections.new(spec.name)
    bpy.context.scene.collection.children.link(collection)
    mats = {
        key: swatch(spec.name + "_" + key, getattr(spec, key))
        for key in ("roof_color", "trim", "roof_end", "plaster", "skirt", "footing")
    }
    w, d, h, sill = spec.width, spec.depth, spec.wall, spec.sill
    # The reference sees one broad slope with just the narrow ridge at the top.
    # Keep the shorter rear slope steep enough that the ridge owns the silhouette.
    overhang = 0.13
    half_span = d / 2 + overhang
    rear_span = min(half_span, spec.rise * 0.88)
    rear_wall_y = rear_span - overhang
    wall_mid_y = (rear_wall_y - d / 2) / 2
    wall_depth = rear_wall_y + d / 2
    box(
        collection,
        "StoneFooting",
        mats["footing"],
        (0, wall_mid_y, 0.065),
        (w + 0.055, wall_depth + 0.055, 0.13),
    )
    box(
        collection,
        "TimberSkirt",
        mats["skirt"],
        (0, wall_mid_y, 0.13 + sill / 2),
        (w, wall_depth, sill),
    )
    lower = 0.13 + sill
    box(
        collection,
        "PlasterWalls",
        mats["plaster"],
        (0, wall_mid_y, (h + lower) / 2),
        (w, wall_depth, h - lower),
    )
    half_width = w / 2 + overhang
    # Both ends are closed so moving the camera past the reference view reveals geometry.
    profile = [
        (0, h + spec.rise),
        (-half_span, h),
        (-half_span, h - 0.065),
        (rear_span, h - 0.065),
        (rear_span, h),
    ]
    verts = [(x, y, z) for x in (-half_width, half_width) for y, z in profile]
    faces = [list(range(5)), list(range(5, 10))] + [
        (i, (i + 1) % 5, (i + 1) % 5 + 5, i + 5) for i in range(5)
    ]
    solid(
        collection,
        "FoldedRoof",
        verts,
        faces,
        [mats["roof_color"], mats["roof_end"], mats["trim"]],
        [1, 1, 0, 2, 2, 2, 0],
    )
    box(
        collection,
        "RidgeCap",
        mats["trim"],
        (0, 0, h + spec.rise - 0.018),
        (w + 2 * overhang + 0.025, 0.115, 0.075),
    )
    # The reference camera sees broad uninterrupted wall and roof planes.
    # Use only a slender projecting board at their junction.
    if spec.name != "slate_shed":
        box(
            collection,
            "SkirtFlashing",
            mats["skirt"],
            (0, wall_mid_y, lower),
            (w + 0.014, wall_depth + 0.014, 0.028),
        )
    # Concealed rear entrance, visible on the turnaround.
    box(
        collection,
        "RearDoorFrame",
        mats["trim"],
        (w * 0.14, rear_wall_y + 0.018, 0.78),
        (0.65, 0.052, 1.42),
    )
    box(
        collection,
        "RearDoor",
        mats["skirt"],
        (w * 0.14, rear_wall_y + 0.048, 0.77),
        (0.54, 0.026, 1.30),
    )
    return collection


for idx, spec in enumerate(HOUSES):
    coll = make_house(spec)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in coll.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = coll.objects[0]
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / (spec.name + ".glb")),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
    )
    for obj in coll.objects:
        obj.location.x += (idx - 1) * 5.5

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "source" / "street_houses.blend"))
