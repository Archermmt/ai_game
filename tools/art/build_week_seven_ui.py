"""Editable UI-04 swatches; runtime thumbnails are captured by palette_render_probe.gd."""
import json, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
text = (ROOT/'features/material_palette/garden_palette.gd').read_text()
cards = [json.loads(s) for s in re.findall(r'\{\s*"id":.*?\}', text, re.S)]
source = ROOT/'art_source/week_07/ui'; source.mkdir(parents=True, exist_ok=True)
target = ROOT/'assets/week_07/ui'; target.mkdir(parents=True, exist_ok=True)
for card in cards:
    lines=''.join(f'<path d="M0 {y} Q48 {y-4} 96 {y+2}" stroke="#405d4c" opacity=".12" fill="none"/>' for y in range(4,96,8))
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><title>{card["label"]}</title><rect width="96" height="96" fill="#{card["tint"]}"/>{lines}</svg>\n'
    (source/(card['id']+'.svg')).write_text(svg)
    (target/(card['id']+'.svg')).write_text(svg)
(ROOT/'art_source/week_07/palette_manifest.json').write_text(json.dumps(cards,ensure_ascii=False,indent=2)+'\n')
(ROOT/'assets/week_07/palette_manifest.json').write_text(json.dumps(cards,ensure_ascii=False,indent=2)+'\n')
# Native captured PNGs supersede these bootstrap vector thumbnails after import.
pairs='\n'.join(f'\t"{c["id"]}": preload("res://assets/week_07/ui/{c["id"]}.png"),' for c in cards)
(ROOT/'ui/palette_thumbnails.gd').write_text('class_name PaletteThumbnails\nextends RefCounted\n\nconst TEXTURES: Dictionary = {\n'+pairs+'\n}\n')
print('12 editable cards generated')

# T049 ledger reuses approved per-family budgets; no new model production this week.
import csv, hashlib
specs={r['asset_id']:r for r in csv.DictReader((ROOT/'docs/art/asset_manifest.csv').open(encoding='utf-8-sig'))}
active={}
for path in sorted((ROOT/'assets').rglob('*.asset.json')):
    entry=json.loads(path.read_text())
    if entry.get('component'):continue
    key=entry['asset_id']; week=next((int(x) for x in re.findall(r'week_(\d+)',str(path))),0)
    if key not in active or week>active[key][0]:active[key]=(week,entry)
models=[]
for key,(_,entry) in sorted(active.items()):
    if not key.startswith(('NAT','PROP','BLD')):continue
    family=key.removesuffix('-LOD1')
    budget=int(re.search(r'≤(\d+)',specs[family]['technical_spec']).group(1))
    wrapper=f'features/assets/wrappers/{family.lower().replace("-","_")}.tscn' if family.startswith(('NAT','PROP')) else None
    models.append({**entry,'family_id':family,'budget':budget,'budget_basis':'Approved asset_manifest.csv suggested triangle budget',
                   'sha256':hashlib.sha256((ROOT/entry['export']).read_bytes()).hexdigest(),'wrapper':wrapper})
(ROOT/'assets/week_07/asset_ledger.json').write_text(json.dumps({'scope':'Existing model deliveries reused; wrappers and palette settings add no model families; NAT-07 reuses NAT-06.',
    'models':models},ensure_ascii=False,indent=2)+'\n')
