"""W06: finished tea/lantern and shared architectural source sections, Blender 5.1.2."""
from pathlib import Path
import bpy,json,math,sys
helper=Path(__file__).with_name('build_week_five_assets.py').read_text().split('\nmanifest=[]')[0]
exec(compile(helper,'week_five_helpers','exec'),globals())
source_root=root/'art_source/week_06';source_root.mkdir(parents=True,exist_ok=True)
target_root=root/'assets/week_06';target_root.mkdir(parents=True,exist_ok=True)


def tea_finished():
    box('tea_tray',(0,0,.025),(.86,.58,.05),'wood',.01)
    for x in [-.415,.415]:box('tea_tray_rim',(x,0,.075),(.03,.58,.1),'wood',.006)
    for y in [-.275,.275]:box('tea_tray_rim',(0,y,.075),(.86,.03,.1),'wood',.006)
    lathe('pot_teapot_thick_body',[(0,0),(.12,0),(.18,.08),(.17,.19),(.11,.23),(.09,.23),(.14,.18),(.15,.08),(.11,.025),(0,.025)],(-.15,0,.05),'tile',20)
    lathe('pot_teapot_lid',[(0,0),(.115,0),(.12,.025),(.09,.055),(0,.055)],(-.15,0,.28),'tile',20)
    lathe('pot_lid_knob',[(0,0),(.03,0),(.04,.03),(0,.05)],(-.15,0,.335),'tile',12)
    tube('pot_teapot_handle',[(-.06+.14*math.sin(i*math.pi/12),0,.185+.1*math.cos(i*math.pi/12)) for i in range(13)],.023,'tile')
    tube('pot_spout',[(-.28,0,.15),(-.4,0,.27),(-.43,0,.31)],.032,'tile')
    for x,y in [(.22,-.145),(.22,.145)]:
        lathe('pot_cup_inner_wall',[(0,0),(.055,0),(.08,.12),(.063,.125),(.042,.025),(0,.025)],(x,y,.05),'tile',16)
        tube('pot_cup_handle',[(x+.067+.05*math.sin(i*math.pi/8),y,.12+.04*math.cos(i*math.pi/8)) for i in range(9)],.012,'tile',6)
    socket('socket_ground',(0,0,0));socket('socket_support_surface',(0,0,0))


def lantern_finished():
    for z in [.05,.51]:box('metal_lantern_base',(0,0,z),(.34,.28,.1),'metal',.01)
    for x in [-.14,.14]:
        for y in [-.11,.11]:box('metal_lantern_frame',(x,y,.28),(.035,.035,.4),'metal',.004)
    # Four emissive panes provide an explicit mask; no opaque glowing solid cube.
    for side in [-1,1]:
        box('lamp_emission_pane_x',(side*.125,0,.28),(.012,.18,.32),'glass',0)
        box('lamp_emission_pane_y',(0,side*.095,.28),(.24,.012,.32),'glass',0)
    lathe('metal_lantern_roof',[(0,0),(.19,0),(.14,.06),(.04,.11),(0,.11)],(0,0,.56),'metal',16)
    tube('metal_lantern_handle',[(.12*math.cos(i/12*math.pi),0,.67+.17*math.sin(i/12*math.pi)) for i in range(13)],.018)
    socket('socket_ground',(0,0,0));socket('socket_light',(0,0,.28));socket('socket_hang',(0,0,.84))


profiles=[('wood_post','BLD-11',(.11,.9,.11)),('wood_rail','BLD-11',(1,.07,.07)),('corner_post','BLD-11',(.13,.95,.13)),('foundation_piece','BLD-03',(1,.5,.22)),('timber_trim','BLD-19',(1,.09,.09)),('stone_tread','BLD-10',(1,.18,1.2))]
entries=[('tea_set','PROP-07',tea_finished,2600,False),('lantern','PROP-08',lantern_finished,2000,False)]
for name,parent,size in profiles:
    def build(n=name,s=size):
        mat='stone' if n.startswith(('stone','foundation')) else 'wood'
        box(n,(0,0,s[1]/2),(s[0],s[2],s[1]),mat,.008)
        socket('socket_start',(0,0,0) if n.endswith('post') else (-s[0]/2,0,0));socket('socket_end',(0,0,s[1]) if n.endswith('post') else (s[0]/2,0,0));socket('socket_ground',(0,0,0))
    entries.append((name,parent,build,1200,True))
manifest=[]
for name,asset_id,builder,budget,component in entries:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    builder();prepare_meshes();meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in meshes:
        for c in o.data.color_attributes['wind_mask'].data:c.color=(0,0,1 if o.name.startswith('lamp_emission') else 0,1)
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    assert triangles<=budget,(name,triangles,budget)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    src=source_root/(name+'.blend');dst=target_root/(name+'.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(src))
    bpy.ops.export_scene.gltf(filepath=str(dst),export_format='GLB',export_yup=True,export_apply=True,export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='wind_mask',export_all_vertex_colors=False)
    item={'asset_id':asset_id,'part':name,'component':component,'source':str(src.relative_to(root)),'export':str(dst.relative_to(root)),'units':'meters','blender':bpy.app.version_string,'up_axis':'gltf_y_up','triangles':triangles,'budget':budget,'sockets':[o.name for o in bpy.context.scene.objects if o.type=='EMPTY'],'stage':'w06_source','source_license':'Project original; authored by Blender script'}
    if not component:item['supersedes']='week_05'
    dst.with_suffix('.asset.json').write_text(json.dumps(item,indent=2)+'\n');manifest.append(item)
(source_root/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(target_root/'profiles.json').write_text(json.dumps({n:{'parent_asset_id':p,'size_godot':list(s),'axis':'y_height' if n.endswith('post') else 'x_length_y_up','source':f'art_source/week_06/{n}.blend'} for n,p,s in profiles},indent=2)+'\n')
print('WEEK_SIX_ASSETS_OK',len(manifest))
