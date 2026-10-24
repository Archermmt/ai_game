"""Blender 5.1.2: W04 nature kit, bench/mailbox, W05 pot/cloth opening drafts."""
from pathlib import Path
import json,math,sys
import bpy
helper=Path(__file__).with_name('build_week_one_assets.py').read_text().split('\nmanifest = []')[0]
exec(compile(helper,'week_one_helpers','exec'),globals())
source_root=root/'art_source/week_04';source_root.mkdir(parents=True,exist_ok=True)
target_root=root/'assets/week_04';target_root.mkdir(parents=True,exist_ok=True)


def ico(name,loc,scale,sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return obj


def fern():
    for i in range(7):
        angle=i*2.399963
        for j in range(6):
            t=j/6;u=(j+1)/6
            a=(math.sin(angle)*t*.52,math.cos(angle)*t*.52,math.sin(t*math.pi*.8)*.48)
            b=(math.sin(angle)*u*.52,math.cos(angle)*u*.52,math.sin(u*math.pi*.8)*.48)
            mesh_object('leaves_fern_spine',[(a[0]-.01,a[1],a[2]),(b[0]-.01,b[1],b[2]),(b[0]+.01,b[1],b[2]),(a[0]+.01,a[1],a[2])],[(0,1,2,3)],'foliage')
        for j in range(1,6):
            t=j/6;r=t*.52;z=math.sin(t*math.pi*.8)*.48
            for sign in [-1,1]:
                p=(math.sin(angle)*r,math.cos(angle)*r,z)
                side=(math.cos(angle)*sign*.17*(1-t*.5),-math.sin(angle)*sign*.17*(1-t*.5),.025)
                vertices=[p,(p[0]+side[0]*.4,p[1]+side[1]*.4,p[2]+.07),
                    (p[0]+side[0],p[1]+side[1],p[2]+side[2]),(p[0]+side[0]*.35,p[1]+side[1]*.35,p[2]-.025)]
                mesh_object('leaves_fern',vertices,[(0,1,2,3)],'foliage')
    socket('socket_ground',(0,0,0))


def flowers():
    for i in range(4):
        a=i*2.399963;r=.18*math.sqrt(i/7);x=math.sin(a)*r;y=math.cos(a)*r;h=.28+(i%3)*.09
        obj=box('leaves_stem',(x,y,h/2),(.018,.018,h),'foliage',0)
        for petal in range(5):
            angle=petal*math.tau/5
            ico('flower_petal',(x+math.sin(angle)*.055,y+math.cos(angle)*.055,h),(.06,.06,.018),1)
    socket('socket_ground',(0,0,0))


def shrub():
    for i in range(5):
        a=i*2.4;ico('leaves_shrub',(math.sin(a)*.28,math.cos(a)*.28,.38+(i%2)*.15),(.43,.4,.45),2)
    socket('socket_ground',(0,0,0))


def rock(flat):
    obj=ico('stone_body',(0,0,.13 if flat else .35),(.83,.57,.19 if flat else .48),2)
    for v in obj.data.vertices:
        v.co.x*=1+.09*math.sin(v.co.y*17+v.co.z*5)
        v.co.z=max(0,v.co.z)
    ico('moss_patch',(.03,-.04,.23 if flat else .68),(.5,.37,.025 if flat else .055),1)
    socket('socket_ground',(0,0,0))


def mailbox():
    box('mailbox_post',(0,0,.55),(.12,.12,1.1),'wood',.015)
    box('mailbox_body',(0,0,1.25),(.62,.42,.4),'wood',.025)
    box('mail_slot',(0,-.218,1.29),(.4,.015,.055),'metal',.005)
    for sign in [-1,1]:
        o=box('mailbox_roof',(sign*.17,0,1.5),(.4,.53,.055),'tile',.012);o.rotation_euler.y=sign*.35
    box('mailbox_flag',(.37,0,1.43),(.045,.04,.26),'tile',.008)
    socket('socket_ground',(0,0,0))


def pot():
    bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=.23,radius2=.32,depth=.42,location=(0,0,.21))
    bpy.context.object.name='pot_body';bpy.context.object.data.materials.append(material('tile'))
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    ico('soil_cap',(0,0,.42),(.29,.29,.025),1)
    for i in range(5):
        a=i*2.4;ico('leaves_pot',(math.sin(a)*.17,math.cos(a)*.17,.6),(.14,.14,.24),1)
    socket('socket_ground',(0,0,0))


manifest=[]
for name,asset_id,builder,stage in [
 ('fern','NAT-04',fern,'w04_source'),('wildflower','NAT-05',flowers,'w04_source'),('shrub','NAT-06',shrub,'w04_source'),
 ('moss_rock','NAT-08',lambda:rock(False),'w04_source'),('flat_rock','NAT-09',lambda:rock(True),'w04_source'),
 ('bench','PROP-01',bench,'w04_source'),('mailbox','PROP-02',mailbox,'w04_source'),
 ('pot','PROP-03',pot,'w04_draft_finish_w05'),('clothesline','PROP-04',cloth,'w04_draft_finish_w05')]:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    builder();prepare_meshes()
    for obj in [o for o in bpy.context.scene.objects if o.type=='MESH']:
        is_plant=obj.name.startswith(('leaves','flower'))
        if is_plant:
            for uv in obj.data.uv_layers.active.data:
                if obj.name.startswith('flower'):
                    uv.uv=(.69+uv.uv.x*.12,.19+uv.uv.y*.12)
                elif 'fern' in obj.name:
                    uv.uv=(.16+uv.uv.x*.18,.66+uv.uv.y*.18)
                else:
                    uv.uv=(.16+uv.uv.x*.18,.66+uv.uv.y*.18)
        colors=obj.data.color_attributes['wind_mask']
        for v,c in zip(obj.data.vertices,colors.data):
            w=max(0,min(1,v.co.z/.8)) if is_plant else (max(0,min(1,(2.04-v.co.z)/1.25)) if obj.name.startswith('cloth') else 0)
            c.color=(w,w*w,0,1)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    src=source_root/(name+'.blend');dst=target_root/(name+'.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(src))
    bpy.ops.export_scene.gltf(filepath=str(dst),export_format='GLB',export_yup=True,export_apply=True,
        export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='wind_mask',export_all_vertex_colors=False)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    entry={'asset_id':asset_id,'source':str(src.relative_to(root)),'export':str(dst.relative_to(root)),
        'units':'meters','blender':bpy.app.version_string,'up_axis':'gltf_y_up',
        'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),
        'sockets':[o.name for o in bpy.context.scene.objects if o.type=='EMPTY'],'stage':stage,
        'source_license':'Project original; authored by Blender script'}
    if asset_id.startswith('NAT'):entry['supersedes']='week_03'
    dst.with_suffix('.asset.json').write_text(json.dumps(entry,indent=2)+'\n');manifest.append(entry)
(source_root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('WEEK_FOUR_ASSETS_OK',len(manifest))
