#!/usr/bin/env python3
"""Compare six frozen LOD0 views; requires Pillow and numpy."""
import json,sys
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[1];views={};after_label=sys.argv[1] if len(sys.argv)>1 else 'proxy_on'
for name in ['orbit','shore','house','whole','sunset','harbor']:
 before=np.asarray(Image.open(root/'snapshots/completion_r2/lod0_source'/f'{name}.png').convert('RGB'),dtype=float)/255
 after=np.asarray(Image.open(root/'snapshots/completion_r2'/after_label/f'{name}.png').convert('RGB'),dtype=float)/255
 assert before.shape==after.shape
 delta=np.abs(before-after);mean=float(delta.mean());fraction=float((delta.max(axis=2)>3/255+1e-8).mean())
 views[name]=dict(mean=mean,fraction_gt_3=fraction,passed=mean<.001 and fraction<.005)
report=dict(after_label=after_label,scope='Source LOD0 versus current proxies, same clock/world/six cameras; not dynamic or human acceptance',mean_limit=.001,changed_fraction_limit=.005,views=views,passed=all(view['passed'] for view in views.values()))
(root/'docs/reports/completion_r2/lod0_pixels.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));raise SystemExit(0 if report['passed'] else 1)
