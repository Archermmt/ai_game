"""W07 optimized BLD-09 source; continuous beveled ring replaces 32 beveled blocks."""
from pathlib import Path
import bpy,json,math
helper=Path(__file__).with_name('build_week_one_assets.py').read_text().split('\nmanifest = []')[0]
exec(compile(helper,'week_one_helpers','exec'),globals())
source_root=root/'art_source/week_07';source_root.mkdir(exist_ok=True)
target_root=root/'assets/week_07';target_root.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
section=[(.45,-.10),(.54,-.10),(.56,-.08),(.56,.08),(.54,.10),(.45,.10),(.43,.08),(.43,-.08)]
verts=[];faces=[];steps=48
for i in range(steps):
    angle=i*math.tau/steps
    verts += [(math.cos(angle)*r,y,.5+math.sin(angle)*r) for r,y in section]
for i in range(steps):
    for j in range(8): faces.append((i*8+j,((i+1)%steps)*8+j,((i+1)%steps)*8+(j+1)%8,i*8+(j+1)%8))
mesh=bpy.data.meshes.new('continuous_beveled_ring');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('window_round_continuous_frame',mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(material('wood'))
points=[(math.cos(i*math.tau/48)*.445,.5+math.sin(i*math.tau/48)*.445) for i in range(48)]
extrude_profile('window_light_round',points,.035,offset=.04,material_name='glass')
extrude_profile('closed_dark_back',points,.035,offset=.13,material_name='metal')
box('window_mullion',(0,-.10,.5),(.045,.04,.86),'wood',.006)
box('window_crossbar',(0,-.10,.5),(.86,.04,.045),'wood',.006)
socket('socket_wall_mount',(0,.10,0))
prepare_meshes()
# Recalculate the continuous manifold ring normals before glTF export.
import bmesh
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
src=source_root/'window_round.blend';dst=target_root/'window_round.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(src))
bpy.ops.export_scene.gltf(filepath=str(dst),export_format='GLB',export_yup=True,export_apply=True,export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='wind_mask',export_all_vertex_colors=False)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
assert triangles<=1600,triangles
item={'asset_id':'BLD-09','source':str(src.relative_to(root)),'export':str(dst.relative_to(root)),'triangles':triangles,'budget':1600,
      'units':'meters','up_axis':'gltf_y_up','blender':bpy.app.version_string,'sockets':['socket_wall_mount'],'supersedes':'week_02',
      'stage':'w07_formal_integration','source_license':'Project original; authored by Blender script'}
dst.with_suffix('.asset.json').write_text(json.dumps(item,indent=2)+'\n')
(source_root/'manifest.json').write_text(json.dumps([item],indent=2)+'\n')
print('W07_WINDOW_SOURCE_OK',triangles)
