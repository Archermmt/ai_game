#!/usr/bin/env python3
"""Inspect both packs outside the source tree, and smoke-test the native macOS release."""
from pathlib import Path
import subprocess,re,json,plistlib,tempfile,struct
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/reports/completion_r4';OUT.mkdir(parents=True,exist_ok=True)
(OUT/'low_smoke.json').unlink(missing_ok=True)
app=next((ROOT/'builds/macos').glob('*.app'));info=plistlib.loads((app/'Contents/Info.plist').read_bytes());exe=app/'Contents/MacOS'/info['CFBundleExecutable'];pck=next((app/'Contents/Resources').glob('*.pck'));steps=[]
commands=[('windows_pack',['godot','--headless','--main-pack',str(ROOT/'builds/windows/BreezelyIsles.exe'),'--script',str(ROOT/'tools/check_export_pack.gd')],'PASS standalone'),('macos_pack',['godot','--headless','--main-pack',str(pck),'--script',str(ROOT/'tools/check_export_pack.gd')],'PASS standalone'),('macos_signature',['codesign','--verify','--deep','--strict',str(app)],None)]
for index in range(3):commands.append(('macos_release_'+str(index),[str(exe),'--','--capture','--welcome','--capture-target='+str(ROOT/'snapshots/completion/release_welcome.png')],'CAPTURE'))
commands.append(('macos_low',[str(exe),'--resolution','640x360','--','--benchmark','--duration=10','--quality=low','--compact'],'PRESSURE_PASS'))
with tempfile.TemporaryDirectory(prefix='brushland-package-') as isolated:
 for name,args,marker in commands:
  p=subprocess.run(args,cwd=isolated,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=70);(OUT/(name+'.log')).write_text(p.stdout)
  ok=p.returncode==0 and (marker is None or marker in p.stdout) and not re.search(r'SCRIPT ERROR:|^ERROR:|were leaked at exit',p.stdout,re.M)
  record=dict(name=name,passed=ok,exit_code=p.returncode)
  boot=re.search(r'BOOT_READY_MS (\d+)',p.stdout)
  if boot:record['launcher_ready_ms']=int(boot.group(1))
  if name=='macos_low' and ok:
   data=json.loads(re.search(r'^PRESSURE_PASS (.+)$',p.stdout,re.M).group(1));ok=all(data.get(k)==v for k,v in dict(land_cells=1200,buildings=40,decorations=400,residents=12,animals=6,render_resolution=[1920,1080]).items());record['passed']=ok;(OUT/'low_smoke.json').write_text(json.dumps(data,indent=2)+'\n')
  steps.append(record);print(name,ok,flush=True)
  if not ok:print(p.stdout[-2500:],flush=True)
pe=(ROOT/'builds/windows/BreezelyIsles.exe').read_bytes();offset=struct.unpack_from('<I',pe,0x3c)[0]
steps.append(dict(name='windows_PE_x86_64_embedded_PCK',passed=pe[offset:offset+4]==b'PE\0\0' and struct.unpack_from('<H',pe,offset+4)[0]==0x8664 and pe[-4:]==b'GDPC',scope='Binary/pack inspection on macOS; not Windows execution'))
(OUT/'package_checks.json').write_text(json.dumps(steps,indent=2)+'\n');raise SystemExit(0 if all(x['passed'] for x in steps) else 1)
