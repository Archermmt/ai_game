#!/usr/bin/env python3
"""Reproducible local release exports; no signing identity or publication required."""
import hashlib,json,re,shutil,subprocess,zipfile,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/reports/completion_r4';OUT.mkdir(parents=True,exist_ok=True)
BUILD=ROOT/'builds';BUILD.mkdir(exist_ok=True)
package_only='--package-only' in sys.argv
def run(name,args):
 p=subprocess.run(['godot','--headless','--path',str(ROOT),*args],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
 (OUT/(name+'.log')).write_text(p.stdout)
 if p.returncode or re.search(r'SCRIPT ERROR:|^ERROR:',p.stdout,re.M):raise RuntimeError(name+' failed; see '+str(OUT/(name+'.log')))
 print('PASS '+name,flush=True)
assert (ROOT/'.tools/export_templates/version.txt').read_text().strip()=='4.7.stable'
assert subprocess.check_output(['godot','--version'],text=True).strip().startswith('4.7.stable.')
if not package_only:
 run('import',['--editor','--import'])
 run('licenses',['--script','tools/write_engine_licenses.gd'])
for preset,platform,filename in [('macOS','macos','BreezelyIsles.zip'),('Windows Desktop','windows','BreezelyIsles.exe')]:
 target=BUILD/platform;target.mkdir(exist_ok=True)
 if not package_only:run('export_'+platform,['--export-release',preset,str(target/filename)])
 if platform=='macos' and not package_only:
  with zipfile.ZipFile(target/filename) as archive:archive.extractall(target)
  # Python's ZipFile does not restore executable modes.
  with zipfile.ZipFile(target/filename) as archive:
   for item in archive.infolist():
    mode=item.external_attr>>16
    if mode and not item.is_dir():(target/item.filename).chmod(mode)
  (target/filename).unlink()
 for item in (ROOT/'docs/completion/test_kit').iterdir():shutil.copy2(item,target/item.name)
 shutil.copy2(ROOT/'docs/completion/TEST_HANDOFF.md',target/'TEST_HANDOFF.md')
 licenses=target/'licenses';licenses.mkdir(exist_ok=True)
 for item in (ROOT/'.tools/licenses').iterdir():shutil.copy2(item,licenses/item.name)
 for source,name in [('THIRD_PARTY_NOTICES.md','THIRD_PARTY_NOTICES.md'),('game/ui/fonts/OFL.txt','NOTO_OFL.txt'),('game/art/materials/LICENSE-CC0.txt','POLYHAVEN_CC0.txt')]:shutil.copy2(ROOT/source,licenses/name)
 package=BUILD/('BreezelyIsles-0.3.0-'+platform+'-test.zip')
 with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
  for item in sorted(target.rglob('*')):
   if item.is_file():archive.write(item,item.relative_to(target))
 print('PACKAGED '+package.name,flush=True)
records=[]
for package in sorted(BUILD.glob('*-test.zip')):records.append(dict(file=package.name,bytes=package.stat().st_size,sha256=hashlib.sha256(package.read_bytes()).hexdigest()))
(OUT/'packages.json').write_text(json.dumps(dict(version='0.3.0',packages=records,signing={'macOS':'ad-hoc, not notarized','Windows':'unsigned'},windows_execution_tested=False,target_device_tested=False),indent=2)+'\n')
print('Release packages ready',flush=True)
