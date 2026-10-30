#!/usr/bin/env python3
"""Fetch only macOS/Windows members of the official 4.7 template ZIP via Range.
ZipFile checks member CRC; SHA256 of each downloaded member is recorded locally.
This does not claim to verify the SHA of the entire 1.28 GB container.
"""
from pathlib import Path
import urllib.request,zipfile,io,hashlib,json,time,zlib
URL='https://godot-releases.nbg1.your-objectstorage.com/4.7-stable/Godot_v4.7-stable_export_templates.tpz'
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'.tools/export_templates';OUT.mkdir(parents=True,exist_ok=True)
class Remote(io.RawIOBase):
 def __init__(self):
  self.position=0
  with urllib.request.urlopen(urllib.request.Request(URL,method='HEAD'),timeout=30) as response:self.size=int(response.headers['Content-Length'])
 def seekable(self):return True
 def tell(self):return self.position
 def seek(self,offset,whence=0):
  self.position=offset if whence==0 else self.position+offset if whence==1 else self.size+offset
  return self.position
 def read(self,n=-1):
  n=min(n if n>=0 else self.size-self.position,self.size-self.position)
  if n<=0:return b''
  request=urllib.request.Request(URL,headers={'Range':f'bytes={self.position}-{self.position+n-1}','User-Agent':'BreezelyIsles-build/1'})
  for attempt in range(3):
   try:
    with urllib.request.urlopen(request,timeout=90) as response:
     if response.status!=206:raise RuntimeError('Server did not honor Range; refusing a full archive download')
     data=response.read()
    if len(data)!=n:raise RuntimeError('Incomplete Range response')
    self.position+=len(data);return data
   except Exception:
    if attempt==2:raise
    time.sleep(2)
records=[]
with zipfile.ZipFile(Remote()) as archive:
 for name in ['version.txt','macos.zip','windows_release_x86_64.exe']:
  member=next(i for i in archive.infolist() if i.filename.rsplit('/',1)[-1]==name)
  destination=OUT/name
  if not destination.exists() or destination.stat().st_size!=member.file_size:
   print('Downloading',name,member.file_size,flush=True)
   with archive.open(member) as source,destination.with_suffix(destination.suffix+'.part').open('wb') as target:
    while data:=source.read(4*1024*1024):target.write(data)
   destination.with_suffix(destination.suffix+'.part').replace(destination)
  assert zlib.crc32(destination.read_bytes())&0xffffffff==member.CRC, 'CRC mismatch: '+name
  records.append(dict(name=name,bytes=destination.stat().st_size,zip_crc32=f'{member.CRC:08x}',sha256=hashlib.sha256(destination.read_bytes()).hexdigest()))
(ROOT/'docs/completion/export_template_sources.json').write_text(json.dumps(dict(source=URL,version='4.7.stable',archive_bytes=1279207690,members=records,verification='TLS official origin, ZIP CRC and local member hashes; full archive hash not verified'),indent=2)+'\n')
print('Templates ready',flush=True)
