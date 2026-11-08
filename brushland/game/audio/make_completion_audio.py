"""Original deterministic 48 kHz synthesized audio, no third-party recordings."""
from pathlib import Path
import math,random,struct,wave,json,hashlib
out=Path(__file__).parent/'clips';rate=48000
records=[]
def write(name,values,loop=False):
 data=bytearray()
 for value in values:data.extend(struct.pack('<h',round(max(-.95,min(.95,value))*32767)))
 path=out/(name+'.wav')
 with wave.open(str(path),'wb') as f:f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(data)
 records.append(dict(name=name,rate=rate,frames=len(data)//2,loop=loop,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
def tone(t,f):return math.sin(t*f*math.tau)+.16*math.sin(t*f*2*math.tau)
for name,freq,decay in [('paint',410,22),('road',290,28),('place',330,20),('move',450,18),('remove',180,22),('undo',260,22),('journal',660,8),('photo',1200,40),('click',520,35),('step_wood',190,45),('step_stone',310,55),('boat',140,9),('cup',1550,15),('greet',360,8),('cat',440,6),('lighthouse',780,5)]:
 rng=random.Random(name);duration=.6 if name in ['cat','greet','boat','lighthouse'] else .32
 write(name,(.10*(tone(i/rate,freq*(1+.12*math.sin(i/rate*16) if name in ['cat','greet'] else 1))+.1*(rng.random()*2-1))*min(1,i/100)*math.exp(-i/rate*decay) for i in range(int(rate*duration))))
for name in ['sea','wind','leaves','birds']:
 rng=random.Random(name);smooth=0;samples=[];n=rate*12
 for i in range(n):
  t=i/rate;smooth=.98*smooth+.02*(rng.random()*2-1)
  env=math.sin(math.pi*i/(n-1))**2
  value=smooth*(.4+.3*math.sin(t*.7)) if name=='sea' else smooth*.25 if name=='wind' else smooth*.16*(.5+.5*math.sin(t*7)) if name=='leaves' else math.sin(t*(1200+200*math.sin(t*5))*math.tau)*max(0,math.sin(t*math.pi/3))**30*.025
  samples.append(value*env)
 write(name,samples,True)
for name,notes in [('day',[48,55,60,64,67,64,60,55,50,57,62,65,69,65,62,57]),('sunset',[45,52,57,60,64,60,57,52,48,55,60,64,67,64,60,55])]:
 n=rate*32;samples=[0.0]*n
 for index,note in enumerate(notes):
  start=index*2*rate;freq=440*2**((note-69)/12)
  for i in range(rate*5):
   t=i/rate;samples[(start+i)%n]+=tone(t,freq)*min(1,t*45)*math.exp(-t*1.4)*.065
 # Short boundary envelope ensures PCM endpoints join without a step.
 for i in range(480):samples[i]*=i/480;samples[-i-1]*=i/480
 write(name,samples,True)
Path('docs/completion/audio_manifest.json').write_text(json.dumps({'origin':'Original deterministic synthesis; no samples; listening acceptance remains separate','records':records},indent=2)+'\n')
print('Wrote',len(records),'48 kHz clips')
