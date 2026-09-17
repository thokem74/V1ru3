"""Reproducible original sound synthesis; Python standard library only."""
import math, random, struct, wave
from pathlib import Path
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(1987)
for name, duration in [('thrust',1.0),('cannon',0.09),('explosion',0.8),('infection',0.18),('missile',0.5),('bomb',1.2),('warning',0.5)]:
    rate=22050
    samples=[]
    for i in range(int(rate*duration)):
        t=i/rate
        q=t/duration
        env=1 if name=='thrust' else (1-q)**2
        noise=random.uniform(-1,1)
        if name=='thrust': value=0.16*noise+0.18*math.sin(2*math.pi*55*t)
        elif name in ('explosion','bomb'): value=(0.65*noise+0.3*math.sin(2*math.pi*(70-30*q)*t))*env
        elif name=='cannon': value=(0.5*noise+0.4*math.sin(2*math.pi*170*t))*env
        elif name=='warning': value=0.5*math.sin(2*math.pi*(660 if q<0.5 else 880)*t)*env
        else: value=(0.35*noise+0.5*math.sin(2*math.pi*(700-500*q)*t))*env
        samples.append(struct.pack('<h',int(max(-1,min(1,value))*23000)))
    with wave.open(str(OUT/(name+'.wav')),'wb') as out:
        out.setparams((1,2,rate,0,'NONE','not compressed'))
        out.writeframes(b''.join(samples))
