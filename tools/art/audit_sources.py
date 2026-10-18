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
for week in [1,2,3,4,5]:
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
        if week == 5:
            assert asset['triangles'] <= asset['budget']
            if asset['asset_id'] == 'PROP-03':
                assert any(o.name.startswith('pot_thick_rim') for o in meshes)
                assert any(o.name.startswith('soil_closed') for o in meshes)
            if asset['asset_id'] == 'PROP-04':
                sheets=[o for o in meshes if o.name.startswith('cloth_sheet')]
                assert len(sheets)==2
                assert any(o.name.startswith('rack_rope') for o in meshes)
                for sheet in sheets:
                    colors=sheet.data.color_attributes['wind_mask'].data
                    assert all(colors[i].color[0]==0 for i in range(9)),sheet.name
                    assert any(c.color[0]>.8 for c in colors),sheet.name
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
atlas=root/'art_source/week_03/vegetation_atlas.blend'
bpy.ops.wm.open_mainfile(filepath=str(atlas),load_ui=False)
mat=bpy.data.materials.get('shared_vegetation_atlas')
assert mat and mat.use_fake_user
img=next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE')
assert list(img.size)==[2048,2048]
assert Path(bpy.path.abspath(img.filepath)).resolve()==root/'art_source/week_03/vegetation_atlas.png'
result={'blender' :bpy.app.version_string,'sources':records,'material_library_graphs':len(material_manifest),
    'images_reopened':len(material_manifest)+1,'atlas_graphs':1,'atlas_resolution':[2048,2048],'passed':True}
Path(args.output).write_text(json.dumps(result,indent=2)+'\n')
print('SOURCE_AUDIT_PASS',len(records),len(material_manifest))
