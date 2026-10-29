#!/usr/bin/env python3
"""Supplement I6 with native parity, two composed scenes, UI and source galleries."""
from pathlib import Path
import subprocess,json,re
root=Path(__file__).resolve().parents[1];out=root/'docs/reports/art_i6';out.mkdir(parents=True,exist_ok=True)
steps=[]
def run(name,args,marker,expected=0):
 try:
  p=subprocess.run(['godot','--path',str(root),*args],cwd=root,capture_output=True,text=True,timeout=90)
  text=p.stdout+p.stderr;code=p.returncode
 except subprocess.TimeoutExpired:
  text='TIMEOUT';code=-999
 (out/(name+'.log')).write_text(text)
 passed=code==expected and marker in text and not re.search(r'SCRIPT ERROR:|^ERROR:',text,re.M)
 steps.append(dict(name=name,passed=passed,exit_code=code,expected_exit=expected));print(('PASS ' if passed else 'FAIL ')+name,flush=True)
for renderer,driver in [('gl_compatibility',[]),('forward_plus',['--rendering-driver','metal'])]:
 base=['--rendering-method',renderer,*driver]
 for suffix,flags,marker,code in [('',[],'MATERIAL_PROBE_PASS',0),('_negative',['--negative-control'],'MATERIAL_PROBE_NEGATIVE',1),('_normal_negative',['--normal-negative-control'],'MATERIAL_PROBE_NEGATIVE',1)]:
  run('materials_'+renderer+suffix,base+['res://game/art_lab/material_probe.tscn','--','--iteration=art_i6',*flags],marker,code)
base=['--rendering-method','gl_compatibility']
for label,flags in [('instancing_off',['--instancing=0']),('instancing_on',[]),('garden',['--composition=garden']),('lighthouse',['--composition=lighthouse'])]:
 run(label,base+['res://game/art_lab/art_lab.tscn','--','--iteration=art_i6','--label='+label,*flags],'ART_LAB_PASS')
run('instance_pixels',['--headless','--script','game/art_lab/check_instance_pixels.gd'],'PASS instance pixels')
run('catalog_gallery',base+['res://game/art_lab/catalog_gallery.tscn'],'PASS native art catalog gallery')
run('interface',base+['--','--capture','--capture-target=res://snapshots/art_i6/interface.png'],'CAPTURE')
passed=all(x['passed'] for x in steps);(out/'finish_validation.json').write_text(json.dumps(dict(passed=passed,steps=steps),indent=2)+'\n')
raise SystemExit(0 if passed else 1)
