"""Deterministic original SVG sources and PCM audio families; no sampled recordings."""
from pathlib import Path
import array,hashlib,json,math,random,shutil,wave
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art_source/week_06';AUDIO=ROOT/'assets/audio';UI=ROOT/'assets/ui'
(SRC/'audio').mkdir(parents=True,exist_ok=True);(SRC/'ui').mkdir(exist_ok=True)
AUDIO.mkdir(exist_ok=True);UI.mkdir(exist_ok=True)
paths={
'house':'M12 31 L32 13 L52 31 M18 27 V52 H46 V27 M28 52 V37 H37 V52',
'round_house':'M17 30 Q32 13 47 30 V48 Q32 58 17 48 Z M13 30 L32 11 L51 30 Z',
'path':'M10 52 Q50 42 28 30 Q15 17 52 11 M20 55 Q60 42 38 28 Q25 18 56 18',
'door':'M20 53 V25 Q32 7 44 25 V53 Z M38 36 H39',
'window':'M18 18 H46 V46 H18 Z M32 18 V46 M18 32 H46',
'raise':'M10 49 Q32 15 54 49 M32 40 V13 M23 22 L32 13 L41 22',
'lower':'M10 49 Q32 15 54 49 M32 12 V39 M23 30 L32 39 L41 30',
'smooth':'M9 42 Q20 22 31 35 T55 31 M15 50 H49',
'pond':'M10 32 C6 7 46 8 53 27 C63 52 20 59 10 32 Z M18 32 Q29 25 46 34',
'bridge':'M10 43 L54 21 M10 35 L54 13 M10 26 V48 M25 19 V40 M40 11 V33 M54 5 V27',
'stair':'M10 52 H23 V40 H36 V28 H49 V16 H56 M10 57 H56',
'fence':'M14 14 V54 M32 14 V54 M50 14 V54 M10 24 H54 M10 42 H54',
'tree':'M32 55 V34 M32 10 C5 8 5 38 24 39 C25 50 49 42 46 32 C62 12 41 5 32 10 Z',
'plant':'M32 54 V22 M32 35 Q5 33 15 16 Q36 15 32 35 M32 45 Q59 42 49 26 Q30 25 32 45',
'props':'M12 29 L32 18 L52 29 V51 L32 59 L12 51 Z M12 29 L32 40 L52 29 M32 40 V59',
'light':'M20 23 H44 V50 H20 Z M17 23 H47 L39 14 H25 Z M25 14 Q32 0 39 14 M32 31 V43',
'selected':'M10 24 V10 H24 M40 10 H54 V24 M54 40 V54 H40 M24 54 H10 V40 M23 33 L30 40 L43 24',
'snap':'M12 32 H26 M38 32 H52 M32 12 V26 M32 38 V52 M25 25 H39 V39 H25 Z',
'dimensions':'M10 12 V52 M7 16 L10 12 L13 16 M7 48 L10 52 L13 48 M20 52 H54 M24 49 L20 52 L24 55 M50 49 L54 52 L50 55',
'invalid':'M32 8 L57 52 H7 Z M32 23 V37 M32 44 V45'}
for name,d in paths.items():
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><title>{name}</title><path d="{d}" fill="none" stroke="#405d4c" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>\n'
 (SRC/'ui'/f'{name}.svg').write_text(svg);(UI/f'{name}.svg').write_text(svg)
(UI/'manifest.json').write_text(json.dumps({'tools':list(paths)[:16],'feedback':list(paths)[16:],'sizes':[64,128],'license':'Project original SVG paths','source':'art_source/week_06/ui'},indent=2)+'\n')
rate=48000;manifest=[]

def save(name,family,seconds,loop,kind,variant=0):
 n=int(rate*seconds);rng=random.Random(name);phases=[rng.random()*math.tau for _ in range(25)]
 # Integer-cycle harmonics are periodic over exactly n frames: seamless ambient layers.
 periodic=[(i*3+1,1/(i+2)**1.25,phases[i]) for i in range(25)]
 noise=[]
 if loop and kind!='music':
  raw=[rng.uniform(-1,1) for _ in range(n)]
  window=64 if kind=='wind' else (8 if kind=='forest' else 4)
  total=sum(raw[:window]);gain=math.sqrt(window)*.065
  for i in range(n):
   noise.append(total/window*gain)
   total+=raw[(i+window)%n]-raw[i]
  for i in range(n-480,n):
   mix=(i-(n-480))/479
   noise[i]=noise[i]*(1-mix)+noise[0]*mix
 samples=array.array('h');squares=0.0;peak=0.0
 for i in range(n):
  t=i/rate
  if loop and kind!='music':
   phase=math.tau*i/n
   y=noise[i]*(.8+.2*math.sin(phase*2))
   if kind=='water':y+=.005*math.sin(15431*phase+3*math.sin(phase*111))
  elif kind=='music':
   y=0
   for j,f in enumerate([261.6256,329.6276,391.9954,293.6648,349.2282,440]):
    onset=j*3.8+.3;dt=t-onset
    if 0<=dt<3.2:y+=.055*math.sin(math.tau*f*dt)*math.exp(-dt*1.7)*min(1,dt/.02)
   y*=min(1,t/.04,(seconds-t)/.08)
  else:
   f={'wood':210,'stone':520,'grass':90,'ui':660}[kind]*(1+variant*.11)
   env=math.exp(-t*({'wood':17,'stone':13,'grass':10,'ui':26}[kind]))*min(1,t/.004)
   y=(math.sin(math.tau*f*t)+.35*math.sin(math.tau*f*2.39*t))*env*.12
   if kind=='grass':y=(rng.random()*2-1)*env*.07
   y*=min(1,(seconds-t)/.025)
  y=max(-.85,min(.85,y));samples.append(round(y*32767));squares+=y*y;peak=max(peak,abs(y))
 target=10**((-36 if kind=='music' else -30)/20)
 gain=min(target/max(math.sqrt(squares/n),1e-8),.4/max(peak,1e-8))
 samples=array.array('h',(round(v*gain) for v in samples))
 squares=sum((v/32767)**2 for v in samples);peak=max(abs(v)/32767 for v in samples)
 with wave.open(str(AUDIO/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(samples.tobytes())
 shutil.copy2(AUDIO/(name+'.wav'),SRC/'audio'/(name+'.wav'))
 manifest.append({'name':name,'family':family,'source':f'art_source/week_06/audio/{name}.wav','export':f'assets/audio/{name}.wav','sample_rate':rate,'channels':1,'bits':16,'frames':n,'seconds':seconds,'loop':loop,'peak_dbfs':round(20*math.log10(max(peak,1e-8)),2),'rms_dbfs':round(20*math.log10(max(math.sqrt(squares/n),1e-8)),2),'seam_delta':abs(samples[-1]-samples[0]) if loop else 0,'sha256':hashlib.sha256(samples.tobytes()).hexdigest(),'license':'Project original DSP synthesis; no external samples','source_url':'tools/art/build_week_six_media.py'})
for args in [('forest','AUD-01',8,True,'forest'),('wind_low','AUD-02',8,True,'wind'),('wind_high','AUD-02',8,True,'wind_high'),('water','AUD-03',8,True,'water')]:save(*args)
for kind,family in [('wood','AUD-04'),('stone','AUD-04'),('grass','AUD-04'),('ui','AUD-05')]:
 for v in range(3):save(f'{kind}_{v+1}',family,.4 if kind!='ui' else .18,False,kind,v)
save('sparse_music','AUD-06',24,False,'music')
(AUDIO/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(SRC/'audio/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('W06_MEDIA_OK',len(paths),'SVG',len(manifest),'audio files')
