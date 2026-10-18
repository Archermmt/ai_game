"""Run in Blender: reopen editable sources, including unused material-library graphs."""
import argparse
import json
import sys
from pathlib import Path
import bpy

parser=argparse.ArgumentParser()
parser.add_argument('--root',required=True)
parser.add_argument('--output',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
root=Path(args.root).resolve()
records=[]
for week in [1,2]:
    manifest=json.loads((root/f'art_source/week_{week:02d}/manifest.json').read_text())
    for asset in manifest:
        bpy.ops.wm.open_mainfile(filepath=str(root/asset['source']),load_ui=False)
        meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
        assert meshes,asset['source']
        assert bpy.context.scene.unit_settings.system=='METRIC'
        assert abs(bpy.context.scene.unit_settings.scale_length-1)<1e-6
        for obj in meshes:
            assert obj.data.uv_layers,asset['source']
            assert obj.data.color_attributes.get('wind_mask') is not None,asset['source']
        for socket in asset['sockets']:
            assert bpy.context.scene.objects.get(socket) is not None,asset['source']
        records.append({'source':asset['source'],'mesh_objects':len(meshes),'passed':True})
library=root/'art_source/week_02/painted_material_library.blend'
bpy.ops.wm.open_mainfile(filepath=str(library),load_ui=False)
material_manifest=json.loads((root/'art_source/week_02/material_manifest.json').read_text())
for entry in material_manifest:
    material=bpy.data.materials.get('painted_'+entry['name'])
    assert material is not None and material.use_fake_user,entry['name']
    image_nodes=[n for n in material.node_tree.nodes if n.type=='TEX_IMAGE']
    assert len(image_nodes)==1 and image_nodes[0].image is not None,entry['name']
    image=image_nodes[0].image
    path=Path(bpy.path.abspath(image.filepath)).resolve()
    assert path==root/entry['source'] and path.is_file(),(entry['name'],str(path))
    assert list(image.size)==entry['resolution'],entry['name']
result={'blender':bpy.app.version_string,'sources':records,'material_library_graphs':len(material_manifest),
    'images_reopened':len(material_manifest),'passed':True}
Path(args.output).write_text(json.dumps(result,indent=2)+'\n')
print('SOURCE_AUDIT_PASS',len(records),len(material_manifest))
