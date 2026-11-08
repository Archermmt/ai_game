"""Original synthesized placeholder audio; deterministic source, no third-party samples."""
import math,random,struct,wave
from pathlib import Path
ROOT=Path(__file__).parent/'clips';ROOT.mkdir(exist_ok=True)
RATE=22050
rng=random.Random(27)
def write(name,values):
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v))*32767)) for v in values))
def ambience(kind):
    samples=[];smooth=0
    for i in range(RATE*12):
        t=i/RATE;smooth=smooth*.985+(rng.random()*2-1)*.015
        fade=math.sin(math.pi*t/12)**2
        samples.append(smooth*(.7+.3*math.sin(t*.7))*fade*.7 if kind=='sea' else smooth*.35*fade)
    return samples
write('sea',ambience('sea'));write('wind',ambience('wind'))
for name,freq in [('paint',410),('place',330),('undo',260),('journal',660),('click',520)]:
    write(name,[(math.sin(i/RATE*freq*math.tau)+.25*math.sin(i/RATE*freq*2*math.tau))*math.exp(-i/RATE*22)*.12 for i in range(int(RATE*.3))])
for name,notes in [('day',[48,55,60,64,67,64,60,55,50,57,62,65,69,65,62,57]),('sunset',[45,52,57,60,64,60,57,52,48,55,60,64,67,64,60,55])]:
    size=RATE*32;samples=[0.0]*size
    for n,note in enumerate(notes):
        start=int(n*2*RATE);freq=440*2**((note-69)/12)
        for i in range(min(RATE*5,size-start)):
            t=i/RATE;attack=min(1,t*45)
            samples[start+i]+=(math.sin(t*freq*math.tau)+.2*math.sin(t*freq*2*math.tau)+.08*math.sin(t*freq*3*math.tau))*math.exp(-t*1.4)*attack*.09
    write(name,samples)
