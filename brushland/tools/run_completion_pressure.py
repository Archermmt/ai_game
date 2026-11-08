#!/usr/bin/env python3
"""Five-minute PRD fixture inside the actual macOS release; no concurrent GPU work."""
import subprocess,time,json,re,shutil,plistlib,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/reports/completion_r2';out.mkdir(parents=True,exist_ok=True)
app=next((root/'builds/macos').glob('*.app'));info=plistlib.loads((app/'Contents/Info.plist').read_bytes());binary=app/'Contents/MacOS'/info['CFBundleExecutable']
for stale in ['pressure.json','pressure_process.json']:(out/stale).unlink(missing_ok=True)
with (out/'pressure.log').open('w') as log:
 start=time.monotonic();process=subprocess.Popen([str(binary),'--resolution','640x360','--','--benchmark','--duration=300','--quality=medium','--compact'],stdout=log,stderr=subprocess.STDOUT,cwd=root)
 rss=[]
 while process.poll() is None and time.monotonic()-start<420:
  sample=subprocess.run(['ps','-o','rss=','-p',str(process.pid)],capture_output=True,text=True)
  if sample.stdout.strip():rss.append(int(sample.stdout.strip())*1024)
  time.sleep(2)
 if process.poll() is None:process.kill();process.wait()
 output=(out/'pressure.log').read_text();match=re.search(r'^BENCHMARK_REPORT (.+)$',output,re.M)
 executed=process.returncode==0 and 'PRESSURE_PASS ' in output and match is not None and not re.search(r'SCRIPT ERROR:|^ERROR:',output,re.M)
 directory=re.search(r'^BENCHMARK_DIRECTORY (.+)$',output,re.M)
 if directory:
  diagnostic=Path(directory.group(1))/'diagnostic.json'
  if diagnostic.exists():shutil.copy2(diagnostic,out/'pressure_coverage.json')
 data={}
 if executed:
  source=Path(match.group(1));data=json.loads(source.read_text());shutil.copy2(source,out/'pressure.json')
  executed=all(data.get(k)==v for k,v in dict(land_cells=1200,buildings=40,decorations=400,residents=12,animals=6).items()) and data.get('duration_wall_seconds',0)>=300 and data.get('edit_samples',0)>=140
  captures=root/'snapshots/completion_r2/pressure';captures.mkdir(parents=True,exist_ok=True)
  for capture in (source.parent/'captures').glob('*.png'):shutil.copy2(capture,captures/capture.name)
 pck=next((app/'Contents/Resources').glob('*.pck'))
 result=dict(binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),pck_sha256=hashlib.sha256(pck.read_bytes()).hexdigest(),executed=executed,exit_code=process.returncode,elapsed_seconds=time.monotonic()-start,rss_peak_bytes=max(rss) if rss else None,rss_samples=len(rss),draw_budget_passed=data.get('draw_calls_peak',999999)<=200 if executed else None,triangle_budget_passed=data.get('visible_primitives_peak',999999)<=350000 if executed else None,edit_budget_passed=data.get('edit_ms_p95',999999)<100 if executed else None,frame_60fps_p95_passed=data.get('frame_ms_p95',999999)<=1000/60 if executed else None,memory_sample_budget_passed=bool(rss) and max(rss)<1500000000,scope='Actual macOS release / M4 Pro / PRD 1200-cell fixture; M1/8GB, Windows and human acceptance untested')
 (out/'pressure_process.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
 raise SystemExit(0 if executed else 1)
