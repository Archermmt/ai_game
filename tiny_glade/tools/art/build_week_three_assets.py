"""Blender 5.1.2: W03 shared layered atlas, authored trees/LOD and W04 nature drafts."""
from pathlib import Path
import json
import math
import sys
import shutil
import bpy
import numpy as np

helper = Path(__file__).with_name('build_week_one_assets.py').read_text().split('\nmanifest = []')[0]
exec(compile(helper, 'week_one_helpers', 'exec'), globals())
source_root = root / 'art_source/week_03'
source_root.mkdir(parents=True, exist_ok=True)
layers = source_root / 'atlas_layers'
layers.mkdir(exist_ok=True)
export_root = root / 'assets/nature/week_03'
export_root.mkdir(parents=True, exist_ok=True)
textures = root / 'assets/materials/textures'
size = 2048
axis = np.arange(size, dtype=np.float32) / size
x, y = np.meshgrid(axis, axis)
base = np.zeros((size, size, 4), dtype=np.float32)
# RGB fills transparent margins too: no white/black border when sampling mip levels.
for mask, color in [( (x<.5)&(y>=.5), (.31,.43,.17)), ((x>=.5)&(y>=.5),(.30,.18,.09)),
                    ((x<.5)&(y<.5),(.32,.44,.18)), ((x>=.5)&(y<.5),(.72,.51,.25))]:
    base[mask,:3] = color
base[:,:,3] = 1
brush = np.zeros_like(base)
variation = .025*np.sin(x*97 + np.sin(y*31)) + .012*np.cos(y*131+x*11)
brush[:,:,:3] = variation[:,:,None]
brush[:,:,3] = 1
alpha = np.ones((size,size), dtype=np.float32)
# Leaf silhouette and grassy/flower cutouts; extended RGB remains in transparent texels.
lx=(x-.25)/.23; ly=(y-.75)/.23
leaf=(x<.5)&(y>=.5)
alpha[leaf] = (lx[leaf]**2 + ly[leaf]**2 < 1).astype(np.float32)
grass=(x<.5)&(y<.5)
gshape = (np.abs(np.mod(x*12,1)-.5) < (.5-y)*.8) & (y<.47)
alpha[grass] = gshape[grass]
flower=(x>=.5)&(y<.5)
fx=(x-.75)/.2; fy=(y-.25)/.2
r=np.sqrt(fx*fx+fy*fy); angle=np.arctan2(fy,fx)
alpha[flower]=(r[flower] < .64+.19*np.cos(angle[flower]*5)).astype(np.float32)
composite = np.clip(base+brush*np.array([1,1,1,0],np.float32),0,1)
composite[:,:,3]=alpha

def save_image(name, pixels, path):
    image=bpy.data.images.new(name,width=size,height=size,alpha=True)
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.filepath_raw=str(path); image.file_format='PNG'; image.save()
    image.use_fake_user=True
    return image

save_image('atlas_base_layer',base,layers/'base.png')
save_image('atlas_brush_layer',np.clip(brush+.5,0,1),layers/'brush.png')
alpha_rgba=np.ones_like(base);alpha_rgba[:,:,:3]=alpha[:,:,None]
save_image('atlas_alpha_layer',alpha_rgba,layers/'alpha.png')
image=save_image('vegetation_atlas_source',composite,source_root/'vegetation_atlas.png')
shutil.copy2(source_root/'vegetation_atlas.png', textures/'vegetation_atlas.png')
np.savez_compressed(layers/'layers.npz',base=base,brush=brush,alpha=alpha)
(source_root/'atlas_manifest.json').write_text(json.dumps({
    'asset_id':'MAT-03','resolution':[2048,2048], 'source':'art_source/week_03/vegetation_atlas.png',
    'export':'assets/materials/textures/vegetation_atlas.png','layers':['base','brush','alpha'],
    'composition':'clip(base.rgb + brush.rgb, 0, 1); alpha mask; Blender image coordinates bottom-up',
    'regions':{'leaf':[0,.5,.5,1],'bark':[.5,.5,1,1],'grass':[0,0,.5,.5],'flower':[.5,0,1,.5]},
    'transparent_rgb_dilated':True},indent=2)+'\n')
atlas_material=bpy.data.materials.new('shared_vegetation_atlas');atlas_material.use_nodes=True
atlas_material.use_fake_user=True
tex=atlas_material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
atlas_material.node_tree.links.new(tex.outputs['Color'],atlas_material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
atlas_material.node_tree.links.new(tex.outputs['Alpha'],atlas_material.node_tree.nodes.get('Principled BSDF').inputs['Alpha'])
image.filepath='//vegetation_atlas.png'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.wm.save_as_mainfile(filepath=str(source_root/'vegetation_atlas.blend'))


def ico(name, loc, scale, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions,radius=1,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return o


def trunk(height=3.7):
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.23,radius2=.095,depth=height,location=(0,0,height/2))
    o=bpy.context.object;o.name='tree_trunk'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)


def build_tree(kind,lod):
    trunk(4 if kind=='conifer' else 3.1)
    count=18
    if kind=='conifer':
        for i in range(5):
            h=1.5+i*(.67)
            bpy.ops.mesh.primitive_cone_add(vertices=18 if not lod else 10,radius1=1.35-i*(.2),radius2=.05,depth=1.8,location=(0,0,h+.6))
            bpy.context.object.name='leaves_tier'
            bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    else:
        for i in range(count):
            a=i*2.399963;r=1.05*math.sqrt((i+.5)/count)
            ico('leaves_crown',(math.sin(a)*r,math.cos(a)*r,3.0+.55*math.sin(i*1.7)),(.85,.8,.9),1 if lod else 2)
        if kind=='fruit':
            for i in range(12):
                a=i*2.399963
                ico('fruit',(math.sin(a)*1.35,math.cos(a)*1.35,2.7+.3*math.sin(i)),(.105,.105,.12),1)
    socket('socket_ground',(0,0,0))


def draft_nature(kind):
    if kind in ['moss_rock','flat_rock']:
        ico('stone_body',(0,0,.3),(.8,.6,.45 if kind=='moss_rock' else .22),2)
    elif kind=='shrub':
        for i in range(4):
            a=i*2.4;ico('leaves_shrub',(math.sin(a)*.3,math.cos(a)*.3,.45),(.45,.4,.5),1)
    else:
        for i in range(7):
            a=i*2.399963
            o=mesh_object('leaves_'+kind,[(0,0,0),(.22,0,.25),(0,0,.65),(-.22,0,.25)],[(0,1,2,3)],'foliage')
            o.rotation_euler.z=a
            o.rotation_euler.x=.25
    socket('socket_ground',(0,0,0))


def finish_asset(name, asset_id, builder, stage):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    builder();prepare_meshes()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in objects:
        o.data.materials.clear();o.data.materials.append(atlas_material)
        # UV islands occupy explicit atlas regions. Crown samples stay in opaque leaf interior.
        region=(.56,.57,.94,.94) if o.name.startswith('tree_trunk') else (.16,.66,.34,.84)
        if 'fern' in o.name:region=(.02,.52,.48,.98)
        if 'wildflower' in o.name:region=(.52,.02,.98,.48)
        for uv in o.data.uv_layers.active.data:
            uv.uv=(region[0]+uv.uv.x*(region[2]-region[0]), region[1]+uv.uv.y*(region[3]-region[1]))
        colors=o.data.color_attributes['wind_mask']
        for vertex,color in zip(o.data.vertices,colors.data):
            h=vertex.co.z
            w=max(0,min(1,(h-.3)/4.5)) if o.name.startswith(('leaves','fruit')) else 0
            color.color=(w,w*w,1 if o.name.startswith('fruit') else 0,1)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    # Relative image stays in the editable source; Godot shares one atlas at runtime.
    image.filepath='//vegetation_atlas.png'
    source=source_root/(name+'.blend');target=export_root/(name+'.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_yup=True,export_apply=True,
        export_cameras=False,export_lights=False,export_materials="NONE",export_vertex_color='NAME',export_vertex_color_name='wind_mask',export_all_vertex_colors=False)
    item={'asset_id':asset_id,'source':str(source.relative_to(root)),'export':str(target.relative_to(root)),
        'blender':bpy.app.version_string,'units':'meters','up_axis':'gltf_y_up',
        'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),
        'sockets':['socket_ground'],'stage':stage,'source_license':'Project original; authored by project Blender script'}
    target.with_suffix('.asset.json').write_text(json.dumps(item,indent=2)+'\n')
    return item

manifest=[]
for kind,asset_id in [('broadleaf','NAT-01'),('conifer','NAT-02'),('fruit','NAT-03')]:
    base=finish_asset('tree_'+kind,asset_id,lambda k=kind:build_tree(k,False),'w03_source')
    base['supersedes']='week_02'
    lod=finish_asset('tree_'+kind+'_lod1',asset_id+'-LOD1',lambda k=kind:build_tree(k,True),'w03_lod1')
    base['lod1']=lod['export'];base['lod1_triangles']=lod['triangles']
    manifest.extend([base,lod])
for kind,asset_id in [('fern','NAT-04'),('wildflower','NAT-05'),('shrub','NAT-06'),('moss_rock','NAT-08'),('flat_rock','NAT-09')]:
    manifest.append(finish_asset(kind,asset_id,lambda k=kind:draft_nature(k),'w03_draft_pending_w04_finish'))
(source_root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('WEEK_THREE_ASSETS_OK',len(manifest))
