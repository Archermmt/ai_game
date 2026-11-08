#!/usr/bin/env python3
"""Reproduce I2 evidence without modifying historical I1 reports."""
import subprocess,sys,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/reports/art_i2'
OUT.mkdir(parents=True,exist_ok=True)
steps=[]
def run(name,args,marker):
 p=subprocess.run(['godot','--path',str(ROOT),*args],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 (OUT/(name+'.log')).write_text(p.stdout)
 ok=p.returncode==0 and marker in p.stdout and not re.search(r'SCRIPT ERROR:|^ERROR:',p.stdout,re.M)
 steps.append(dict(name=name,passed=ok,exit_code=p.returncode));print(('PASS ' if ok else 'FAIL ')+name,flush=True)
 if not ok:print(p.stdout[-2000:])
run('surface',['--headless','--script','tests/test_surface.gd'],'PASS surface')
for renderer,driver in [('gl_compatibility',[]),('forward_plus',['--rendering-driver','metal'])]:
 run(renderer,['--rendering-method',renderer,*driver,'res://game/art_lab/art_lab.tscn','--','--label='+renderer,'--iteration=art_i2'],'ART_LAB_PASS')
 run('app_'+renderer,['--rendering-method',renderer,*driver,'--script','tests/test_app.gd'],'PASS UI signals')
passed=all(s['passed'] for s in steps)
(OUT/'validation.json').write_text(json.dumps(dict(passed=passed,steps=steps),indent=2)+'\n')
sys.exit(0 if passed else 1)
