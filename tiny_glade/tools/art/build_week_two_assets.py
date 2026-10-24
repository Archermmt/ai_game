"""Blender 5.1.2: editable W02 windows, tree blockouts and painted material sources."""
from pathlib import Path
import json
import math
import sys
import bpy
import numpy as np

# Reuse reviewed W01 geometry/UV/export helpers without executing its production loop.
helper = Path(__file__).with_name('build_week_one_assets.py').read_text().split('\nmanifest = []')[0]
exec(compile(helper, 'week_one_helpers', 'exec'), globals())
source_root = root / 'art_source/week_02'
source_root.mkdir(parents=True, exist_ok=True)
manifest = []


def window(round_shape):
    if round_shape:
        for index in range(32):
            a = index * math.tau / 32
            obj = box('round_frame_%02d' % index, (math.cos(a)*0.42, 0, 0.45+math.sin(a)*0.42), (0.11,0.2,0.095))
            obj.rotation_euler.y = -a
        points = [(math.cos(i*math.tau/48)*0.37, 0.45+math.sin(i*math.tau/48)*0.37) for i in range(48)]
        extrude_profile('window_light_round', points, 0.035, offset=0.04, material_name='glass')
        extrude_profile('closed_dark_back', points, 0.035, offset=0.13, material_name='metal')
    else:
        for x in [-0.46,0.46]:
            box('window_frame_post', (x,0,0.45), (0.12,0.2,1.02))
        for z in [-0.01,0.91]:
            box('window_frame_rail', (0,0,z), (1.04,0.2,0.12))
        box('window_light_rect', (0,0.04,0.45), (0.82,0.035,0.82),'glass',0)
        box('closed_dark_back', (0,0.14,0.45), (0.85,0.04,0.85),'metal',0)
    box('window_mullion', (0,-0.1,0.45), (0.045,0.04,0.77))
    box('window_crossbar', (0,-0.1,0.45), (0.77,0.04,0.045))
    socket('socket_wall_mount',(0,0.1,0))


def pine():
    bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=0.22,radius2=0.10,depth=3.7,location=(0,0,1.85))
    bpy.context.object.name='tree_trunk'
    bpy.context.object.data.materials.append(material('wood'))
    for i in range(4):
        bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=1.4-i*0.25,radius2=0.05,depth=1.8,location=(0,0,2.1+i*0.75))
        bpy.context.object.name='leaves_tier_%02d'%i
        bpy.context.object.data.materials.append(material('foliage'))
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    socket('socket_ground',(0,0,0))


def fruit_tree():
    tree()
    for i in range(9):
        a=i*2.399963
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=0.12,location=(math.sin(a)*1.05,math.cos(a)*1.05,2.65+(i%3)*0.3))
        bpy.context.object.name='fruit_%02d'%i
        bpy.context.object.data.materials.append(material('tile'))
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)


for name,asset_id,folder,builder,stage in [
    ('window_rect','BLD-08','buildings',lambda:window(False),'source_model_pending_integration'),
    ('window_round','BLD-09','buildings',lambda:window(True),'source_model_pending_integration'),
    ('tree_broadleaf','NAT-01','nature',tree,'w02_blockout_pending_w03_lod_atlas'),
    ('tree_conifer','NAT-02','nature',pine,'w02_blockout_pending_w03_lod_atlas'),
    ('tree_fruit','NAT-03','nature',fruit_tree,'w02_blockout_pending_w03_lod_atlas'),
]:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    builder()
    prepare_meshes()
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.context.scene.unit_settings.scale_length=1
    source=source_root/(name+'.blend')
    target=root/'assets'/folder/(name+'.glb')
    target.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_yup=True,export_apply=True,
        export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='wind_mask',
        export_all_vertex_colors=False,export_extras=False)
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    item={'asset_id':asset_id,'source':str(source.relative_to(root)),'export':str(target.relative_to(root)),
        'blender':bpy.app.version_string,'units':'meters','up_axis':'gltf_y_up',
        'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),
        'material_slots':sorted({m.name for o in objects for m in o.data.materials}),
        'sockets':[o.name for o in bpy.context.scene.objects if o.type=='EMPTY'],
        'stage':stage,'source_license':'Project original; authored by project Blender script'}
    target.with_suffix('.asset.json').write_text(json.dumps(item,indent=2)+'\n')
    manifest.append(item)

# Seamless layered brush-like swathes: original painted color studies, no photo inputs.
textures=root/'assets/materials/textures'
textures.mkdir(parents=True,exist_ok=True)
source_textures=source_root/'textures'
source_textures.mkdir(exist_ok=True)
material_manifest=[]
for name,base,size in [
    ('plaster',(0.76,0.69,0.53),1024),('wood',(0.48,0.29,0.13),1024),
    ('terracotta',(0.52,0.22,0.11),1024),('stone',(0.38,0.42,0.34),1024),
    ('grass',(0.32,0.40,0.23),2048),('soil',(0.38,0.29,0.17),2048),('wet_bank',(0.22,0.29,0.20),2048),
    ('window_emission',(1.0,0.83,0.43),1024),
]:
    axis=np.arange(size,dtype=np.float32)/size
    x,z=np.meshgrid(axis,axis)
    brush=(np.sin((x*3+np.sin(z*math.tau)*0.15)*math.tau+np.sin(z*4*math.tau))*0.009+
           np.sin((x*13+z*2)*math.tau)*0.003+np.cos(z*17*math.tau+np.sin(x*5*math.tau))*0.003)
    if name=='wood':
        brush+=np.sin((x*19+np.sin(z*math.tau)*0.3)*math.tau)*0.045
    if name=='terracotta':
        grout=(np.mod(z*8,1)<0.045) | (np.mod(x*6+np.floor(z*8)*0.5,1)<0.025)
        brush-=grout.astype(np.float32)*0.07
    if name=='stone':
        brush+=np.sin((x*5+np.sin(z*6*math.tau)*0.08)*math.tau)*0.022
    pixels=np.empty((size,size,4),dtype=np.float32)
    for channel in range(3):
        pixels[:,:,channel]=np.clip(base[channel]+brush,0,1)
    pixels[:,:,3]=1
    if name=='window_emission':
        edge=np.clip(np.minimum(np.minimum(x,1-x),np.minimum(z,1-z))*9,0,1)
        pixels[:,:,:3]*=edge[:,:,None]
    image=bpy.data.images.new(name+'_painted_source',width=size,height=size,alpha=True)
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw=str(textures/(name+'.png'))
    image.file_format='PNG'
    image.save()
    import shutil
    shutil.copyfile(image.filepath_raw,source_textures/(name+'.png'))
    mat=bpy.data.materials.new('painted_'+name)
    mat.use_fake_user=True
    image.use_fake_user=True
    mat.use_nodes=True
    nodes=mat.node_tree.nodes
    tex=nodes.new('ShaderNodeTexImage')
    tex.image=image
    tex.label='Editable original brush swathes: '+name
    mat.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    nodes.get('Principled BSDF').inputs['Roughness'].default_value=0.9
    image.filepath='//textures/'+name+'.png'
    material_manifest.append({'name':name,'resolution':[size,size],'source':str((source_textures/(name+'.png')).relative_to(root)),
        'export':str((textures/(name+'.png')).relative_to(root)),'colorspace':'sRGB','seamless':True})
bpy.ops.wm.save_as_mainfile(filepath=str(source_root/'painted_material_library.blend'))
(source_root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(source_root/'material_manifest.json').write_text(json.dumps(material_manifest,indent=2)+'\n')
print('WEEK_TWO_ASSETS_OK',len(manifest),len(material_manifest))
