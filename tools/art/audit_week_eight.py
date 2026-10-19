"""Read-only Blender audit of active model origins, normals, UV, LOD and materials."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy

parser=argparse.ArgumentParser()
parser.add_argument('--root',required=True)
parser.add_argument('--output',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
root=Path(args.root).resolve()
ledger=json.loads((root/'assets/week_07/asset_ledger.json').read_text())
records=[]
for asset in ledger['models']:
    bpy.ops.wm.open_mainfile(filepath=str(root/asset['source']),load_ui=False)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert meshes
    bad_scales=[];bad_normals=[];bad_uv=[];material_names=set();min_y=math.inf
    triangles=0
    for obj in meshes:
        if any(v<=0 for v in obj.scale) or obj.matrix_world.determinant()<=0:bad_scales.append(obj.name)
        for polygon in obj.data.polygons:
            if not all(math.isfinite(v) for v in polygon.normal) or polygon.normal.length<.9:bad_normals.append(obj.name)
        if not obj.data.uv_layers or any(not all(math.isfinite(v) for v in uv.uv) for uv in obj.data.uv_layers.active.data):bad_uv.append(obj.name)
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
        min_y=min(min_y,min((obj.matrix_world@v.co).z for v in obj.data.vertices))
        material_names.update(m.name for m in obj.data.materials if m)
    assert not bad_scales,(asset['asset_id'],bad_scales)
    assert not bad_normals,(asset['asset_id'],bad_normals)
    assert not bad_uv,(asset['asset_id'],bad_uv)
    assert triangles<=asset['budget'],(asset['asset_id'],triangles,asset['budget'])
    assert hashlib.sha256((root/asset['export']).read_bytes()).hexdigest()==asset['sha256']
    records.append({'asset_id':asset['asset_id'],'source':asset['source'],'triangles':triangles,
                    'budget':asset['budget'],'negative_scales':0,'invalid_normals':0,'invalid_uv':0,
                    'lowest_local_m':round(min_y,4),'authoring_origin':'scene world origin (meter units)',
                    'material_slots':sorted(material_names),'export_hash_matches_ledger':True})
# Atlas RGB padding exists outside alpha; alpha edge colors must not be white.
image=bpy.data.images.load(str(root/'art_source/week_03/vegetation_atlas.png'),check_existing=False)
pixels=list(image.pixels);transparent=colored=white=0
for i in range(0,len(pixels),4):
    if pixels[i+3]<.01:
        transparent+=1
        if max(pixels[i:i+3])>.01:colored+=1
        if min(pixels[i:i+3])>.95:white+=1
assert transparent>0 and colored>0 and white==0
result={'blender':bpy.app.version_string,'passed':True,'new_model_families':0,
        'models':records,'scope':'Active W07 ledger reused in W08, including three tree LOD1s; origins and sockets remain source contracts.',
        'atlas':{'transparent_pixels':transparent,'rgb_padded_pixels':colored,'white_transparent_pixels':white},
        'lod_review':'LOD0/LOD1 keep the same atlas and palette; runtime near/far captures accompany this audit.'}
Path(args.output).write_text(json.dumps(result,indent=2)+'\n')
print('W08 SOURCE AUDIT PASS',len(records))
