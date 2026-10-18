"""Blender 5.1.2: W05 finished pot/rack/crate/can and W06 tea/lantern source drafts."""
from pathlib import Path
import json, math, sys
import bpy
helper=Path(__file__).with_name('build_week_one_assets.py').read_text().split('\nmanifest = []')[0]
exec(compile(helper,'week_one_helpers','exec'),globals())
source_root=root/'art_source/week_05';source_root.mkdir(parents=True,exist_ok=True)
target_root=root/'assets/week_05';target_root.mkdir(parents=True,exist_ok=True)


def lathe(name, profile, origin=(0,0,0), mat='metal', sides=16):
    vertices=[(origin[0]+r*math.cos(i*math.tau/sides), origin[1]+r*math.sin(i*math.tau/sides),origin[2]+z) for r,z in profile for i in range(sides)]
    faces=[]
    for row in range(len(profile)-1):
        for i in range(sides):
            j=(i+1)%sides;faces.append((row*sides+i,row*sides+j,(row+1)*sides+j,(row+1)*sides+i))
    return mesh_object(name,vertices,faces,mat)


def tube(name, points, radius=.025, mat='metal', sides=8):
    from mathutils import Vector
    vertices=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        frame=tangent.to_track_quat('Z','Y')
        for j in range(sides):
            v=Vector(p)+frame@Vector((radius*math.cos(j*math.tau/sides),radius*math.sin(j*math.tau/sides),0));vertices.append(tuple(v))
    faces=[tuple(reversed(range(sides)))]
    for i in range(len(points)-1):
        for j in range(sides):
            k=(j+1)%sides;faces.append((i*sides+j,i*sides+k,(i+1)*sides+k,(i+1)*sides+j))
    faces.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    return mesh_object(name,vertices,faces,mat)


def pot():
    lathe('pot_thick_rim',[(0,0),(.22,0),(.32,.39),(.34,.4),(.34,.45),(.29,.45),(.28,.39),(.2,.06),(0,.06)],mat='tile')
    lathe('soil_closed',[(0,.39),(.279,.39),(.279,.37),(0,.37)],mat='metal')
    for i in range(7):
        a=i*2.399;h=.57+(i%3)*.08
        tube('leaves_stem',[(0,0,.39),(.2*math.cos(a),.2*math.sin(a),h)],.012,'foliage',6)
        x=.2*math.cos(a);y=.2*math.sin(a)
        mesh_object('leaves_pot',[(x-.12,y,h),(x,y-.07,h+.17),(x+.12,y,h),(x,y+.07,h-.03)],[(0,1,2,3)],'foliage')
    socket('socket_ground',(0,0,0))


def rack():
    for x in [-1.25,1.25]:
        box('rack_post',(x,0,1.1),(.1,.12,2.2))
        box('rack_foot',(x,0,.06),(.16,.9,.12))
    rope=[(-1.25+2.5*i/16,0,2.13-.09*math.sin(i/16*math.pi)) for i in range(17)]
    tube('rack_rope',rope,.018,'wood')
    for k in range(2):
        verts=[]
        for row in range(9):
            for col in range(9):
                x=-1.05+k*1.2+col*.1
                top=2.13-.09*math.sin((x+1.25)/2.5*math.pi)
                verts.append((x,math.sin(col/8*math.pi*3)*.035*(row/8),top-row/8*1.15-.025*math.sin(col/8*math.pi)))
        faces=[(r*9+c,r*9+c+1,r*9+c+10,r*9+c+9) for r in range(8) for c in range(8)]
        mesh_object('cloth_sheet_'+str(k),verts,faces,'cloth')
        for x in [-1.05+k*1.2,-.25+k*1.2]:box('rack_peg',(x,-.015,2.09),(.035,.055,.12),'wood',.003)
    socket('socket_ground',(0,0,0))


def crate():
    for z in [.045,.755]:
        for i in range(4):box('crate_top_bottom',(0,-.3+i*.2,z),(.9,.19,.09),'wood',0)
    for sign in [-1,1]:
        for i in range(4):
            box('crate_side',(sign*.415,0,.15+i*.17),(.07,.8,.16),'wood',0)
            box('crate_front',(0,sign*.365,.15+i*.17),(.9,.07,.16),'wood',0)
    for x in [-.38,.38]:
        for y in [-.33,.33]:box('crate_corner',(x,y,.4),(.09,.09,.8),'wood',0)
    socket('socket_support_surface',(0,0,.8));socket('socket_ground',(0,0,0))


def can():
    lathe('metal_can_body',[(0,0),(.25,0),(.3,.08),(.29,.4),(.22,.45),(.14,.45),(.14,.42),(.21,.42),(.26,.38),(.27,.08),(.23,.04),(0,.04)])
    tube('metal_spout',[(-.21,0,.15),(-.39,0,.28),(-.6,0,.57)],.055)
    lathe('metal_sprinkler',[(0,0),(.11,0),(.11,.04),(0,.04)],(-.6,0,.57))
    tube('metal_handle',[(.23+.23*math.sin(i/12*math.pi),0,.23+.24*math.cos(i/12*math.pi)) for i in range(13)],.03)
    socket('socket_ground',(0,0,0))


def tea():
    box('tea_tray',(0,0,.025),(.8,.55,.05),'wood',.012)
    for x in [-.39,.39]:box('tea_tray_rim',(x,0,.07),(.025,.55,.08),'wood',.005)
    for y in [-.265,.265]:box('tea_tray_rim',(0,y,.07),(.8,.025,.08),'wood',.005)
    lathe('pot_teapot',[(0,0),(.14,0),(.18,.12),(.13,.24),(0,.24)],(-.16,0,.05),'tile')
    tube('pot_spout',[(-.28,0,.17),(-.42,0,.3)],.04,'tile')
    for x,y in [(.18,-.14),(.18,.14)]:lathe('pot_cup',[(0,0),(.07,0),(.085,.12),(.065,.12),(.05,.025),(0,.025)],(x,y,.05),'tile',12)
    socket('socket_ground',(0,0,0))


def lantern():
    for z in [.06,.52]:box('metal_lantern_base',(0,0,z),(.34,.28,.1),'metal',.01)
    for x in [-.14,.14]:
        for y in [-.11,.11]:box('metal_lantern_frame',(x,y,.29),(.035,.035,.4),'metal',.005)
    box('lamp_emission',(0,0,.29),(.21,.16,.31),'glass',.012)
    tube('metal_lantern_handle',[(.12*math.cos(i/12*math.pi),0,.58+.16*math.sin(i/12*math.pi)) for i in range(13)],.018)
    socket('socket_ground',(0,0,0));socket('socket_light',(0,0,.29));socket('socket_hang',(0,0,.74))


manifest=[]
for name,asset_id,builder,budget in [('pot','PROP-03',pot,1800),('clothesline','PROP-04',rack,2500),('crate','PROP-05',crate,1200),('watering_can','PROP-06',can,1800),('tea_set','PROP-07',tea,2600),('lantern','PROP-08',lantern,2000)]:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    builder();prepare_meshes()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for obj in meshes:
        if obj.name.startswith('leaves'):
            for uv in obj.data.uv_layers.active.data:uv.uv=(.16+uv.uv.x*.18,.66+uv.uv.y*.18)
        for v,c in zip(obj.data.vertices,obj.data.color_attributes['wind_mask'].data):
            w=0
            if obj.name.startswith('cloth'):
                top=2.13-.09*math.sin((v.co.x+1.25)/2.5*math.pi)-.025*math.sin(((v.co.x+1.05)%1.2)/.8*math.pi)
                # Entire upper row is pinned, including rope sag.
                w=max(0,min(1,(top-v.co.z)/1.15))
                if w<.02:w=0
            elif obj.name.startswith('leaves'):w=max(0,min(1,(v.co.z-.39)/.4))
            c.color=(w,w*w,0,1)
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    assert triangles<=budget,(name,triangles,budget)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    src=source_root/(name+'.blend');dst=target_root/(name+'.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(src))
    bpy.ops.export_scene.gltf(filepath=str(dst),export_format='GLB',export_yup=True,export_apply=True,export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='wind_mask',export_all_vertex_colors=False)
    entry={'asset_id':asset_id,'source':str(src.relative_to(root)),'export':str(dst.relative_to(root)),'units':'meters','blender':bpy.app.version_string,'up_axis':'gltf_y_up','triangles':triangles,'budget':budget,'sockets':[o.name for o in bpy.context.scene.objects if o.type=='EMPTY'],'stage':'w05_source' if asset_id not in ['PROP-07','PROP-08'] else 'w05_draft_finish_w06','source_license':'Project original; authored by Blender script'}
    if asset_id in ['PROP-03','PROP-04']:entry['supersedes']='week_04'
    dst.with_suffix('.asset.json').write_text(json.dumps(entry,indent=2)+'\n');manifest.append(entry)
(source_root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('WEEK_FIVE_ASSETS_OK',len(manifest))
