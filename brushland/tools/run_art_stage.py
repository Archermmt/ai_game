#!/usr/bin/env python3
"""Reproduce I2 evidence without modifying historical I1 reports."""
import subprocess,sys,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
STAGE=sys.argv[1] if len(sys.argv)>1 else 'art_i3'
assert STAGE in ['art_i3','art_i4','art_i5','art_i6']
OUT=ROOT/('docs/reports/'+STAGE)
OUT.mkdir(parents=True,exist_ok=True)
steps=[]
(OUT/"validation.json").unlink(missing_ok=True)
def run(name,args,marker):
 try:
  p=subprocess.run(['godot','--path',str(ROOT),*args],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
 except subprocess.TimeoutExpired as e:
  output=e.stdout.decode() if isinstance(e.stdout,bytes) else (e.stdout or '')
  (OUT/(name+'.log')).write_text(output+'\nTIMEOUT')
  steps.append(dict(name=name,passed=False,exit_code=-999));print('FAIL timeout '+name,flush=True);return
 (OUT/(name+'.log')).write_text(p.stdout)
 ok=p.returncode==0 and marker in p.stdout and not re.search(r'SCRIPT ERROR:|^ERROR:',p.stdout,re.M)
 steps.append(dict(name=name,passed=ok,exit_code=p.returncode));print(('PASS ' if ok else 'FAIL ')+name,flush=True)
 if not ok:print(p.stdout[-2000:])
run('preflight',['--headless','--check-only','--script','game/art_lab/art_lab.gd'],'Godot Engine')
if not steps[-1]['passed']:sys.exit(1)
if STAGE!='art_i3':run('rig',['--headless','--script','tests/test_rig.gd'],'PASS four')
run('foliage',['--headless','--script','tests/test_foliage.gd'],'PASS foliage')
run('surface',['--headless','--script','tests/test_surface.gd'],'PASS surface')
for renderer,driver in [('gl_compatibility',[]),('forward_plus',['--rendering-driver','metal'])]:
 run(renderer,['--rendering-method',renderer,*driver,'res://game/art_lab/art_lab.tscn','--','--label='+renderer,'--iteration='+STAGE],'ART_LAB_PASS')
 run('app_'+renderer,['--rendering-method',renderer,*driver,'--script','tests/test_app.gd'],'PASS UI signals')
passed=all(s['passed'] for s in steps)
(OUT/'validation.json').write_text(json.dumps(dict(passed=passed,steps=steps),indent=2)+'\n')
sys.exit(0 if passed else 1)
