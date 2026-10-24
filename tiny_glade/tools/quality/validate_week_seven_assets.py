"""W07 source/wrapper/palette/import contract; no Godot cache required."""
import hashlib, json, struct
from pathlib import Path
from common import ROOT


def main():
    cards = json.loads((ROOT/'assets/week_07/palette_manifest.json').read_text())
    assert len(cards) == 12 and len({c['id'] for c in cards}) == 12
    images=[]
    for card in cards:
        name=card['id']
        assert (ROOT/f'art_source/week_07/ui/{name}.svg').read_bytes() == (ROOT/f'assets/week_07/ui/{name}.svg').read_bytes()
        png=ROOT/f'assets/week_07/ui/{name}.png'
        raw=png.read_bytes(); assert raw[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II',raw[16:24]) == (96,96)
        assert png.with_suffix('.png.import').exists()
        images.append({'id':name,'sha256':hashlib.sha256(raw).hexdigest(),'size':[96,96]})
    ledger=json.loads((ROOT/'assets/week_07/asset_ledger.json').read_text())
    for model in ledger['models']:
        assert hashlib.sha256((ROOT/model['export']).read_bytes()).hexdigest()==model['sha256']
        assert (ROOT/model['source']).exists()
        assert model['triangles']<=model['budget']
    wrappers=[]
    for prefix,count in [('nat',9),('prop',8)]:
        for index in range(1,count+1):
            p=ROOT/f'features/assets/wrappers/{prefix}_{index:02}.tscn'
            text=p.read_text()
            assert 'res://features/assets/asset_wrapper.tscn' in text
            assert f'asset_id = "{prefix.upper()}-{index:02}"' in text
            wrappers.append(str(p.relative_to(ROOT)))
    result={'passed':True,'native_material_thumbnails':images,'wrappers':wrappers,
            'budget_models_checked':len(ledger['models']),
            'scope':'Existing source models reused; no new model families; NAT-07 generated from shared NAT-06 meshes/UVs.'}
    (ROOT/'reports/week_07_assets.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('W07 ASSET CONTRACT PASS')


if __name__=='__main__': main()
