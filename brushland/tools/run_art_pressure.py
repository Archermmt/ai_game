#!/usr/bin/env python3
"""Run the real five-minute scene, sampling only its process RSS."""
import subprocess,time,json
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/reports/art_i6';out.mkdir(parents=True,exist_ok=True)
with (out/'pressure.log').open('w') as log:
 start=time.monotonic();p=subprocess.Popen(['godot','--path',str(root),'--rendering-method','gl_compatibility','res://game/art_lab/pressure_art.tscn'],stdout=log,stderr=subprocess.STDOUT,cwd=root)
 rss=[]
 while p.poll() is None and time.monotonic()-start<420:
  v=subprocess.run(['ps','-o','rss=','-p',str(p.pid)],capture_output=True,text=True)
  if v.stdout.strip():rss.append(int(v.stdout.strip())*1024)
  time.sleep(2)
 if p.poll() is None:p.kill();p.wait()
 text=(out/'pressure.log').read_text();passed=p.returncode==0 and 'PRESSURE_PASS ' in text and 'SCRIPT ERROR:' not in text and '\nERROR:' not in text
 (out/'pressure_process.json').write_text(json.dumps(dict(passed=passed,exit_code=p.returncode,elapsed_seconds=time.monotonic()-start,rss_peak_bytes=max(rss) if rss else None,rss_samples=len(rss)),indent=2)+'\n')
 print('PASS pressure process' if passed else 'FAIL pressure process',flush=True)
 raise SystemExit(0 if passed else 1)
