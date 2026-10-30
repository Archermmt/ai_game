#!/usr/bin/env python3
"""Remaining-product regressions. Run native tests sequentially, never during pressure."""
import subprocess,re,json
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/reports/completion_r3';out.mkdir(parents=True,exist_ok=True)
def run(name,args):
 p=subprocess.run(['godot','--path',str(root),*args],cwd=root,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=70);(out/(name+'.log')).write_text(p.stdout)
 ok=p.returncode==0 and 'PASS' in p.stdout and not re.search(r'SCRIPT ERROR:|^ERROR:|were leaked at exit',p.stdout,re.M);print(name,ok,flush=True)
 if not ok:print(p.stdout[-2000:],flush=True)
 return dict(test=name,passed=ok,exit_code=p.returncode)
core=[run(name,['--headless','--script','tests/test_'+name+'.gd']) for name in ['world','building','residents','playable','bridge_activity','acceptance_rules','acceptance_core','save_faults','preferences','audio_delivery','surface']]
(out/'core_tests.json').write_text(json.dumps(core,indent=2)+'\n')
native=[run('app_gl',['--rendering-method','gl_compatibility','--script','tests/test_app.gd']),run('app_metal',['--rendering-method','forward_plus','--rendering-driver','metal','--script','tests/test_app.gd']),run('product_ui',['--rendering-method','gl_compatibility','--script','tests/test_product_ui.gd']),run('arrival_presentation',['--rendering-method','gl_compatibility','--script','tests/test_arrival_presentation.gd'])]
(out/'native_tests.json').write_text(json.dumps(native,indent=2)+'\n');raise SystemExit(0 if all(x['passed'] for x in core+native) else 1)
