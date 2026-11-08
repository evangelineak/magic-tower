"""Rebuild original Magic Tower UI/combat sounds using only Python stdlib.
Run: python tools/build_audio.py
No recordings, samples, external soundfonts, synthesis packages or network.
"""
from pathlib import Path
import hashlib
import json
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'audio'
RATE = 44100
TAU = math.tau


def smoothstep(x):
    x = min(1.0, max(0.0, x))
    return x*x*(3.0-2.0*x)


def envelope(t, duration, attack=.012, release=.04):
    if t <= 0 or t >= duration:
        return 0.0
    return smoothstep(t/attack) * smoothstep((duration-t)/release)


def mix_tone(buf, start, length, frequency, volume, decay=0.0, shimmer=0.0):
    """Soft sine with optional quiet second partial, no discontinuous oscillator."""
    for i in range(int(length*RATE)):
        j = int(start*RATE)+i
        if j >= len(buf):
            break
        t = i/RATE
        tone = math.sin(TAU*frequency*t)
        tone += shimmer*math.sin(TAU*frequency*2.003*t)
        buf[j] += volume*envelope(t,length)*math.exp(-decay*t)*tone


def noise_layer(buf, start, length, volume, seed, smoothing=.14, decay=0.0):
    """Low-passed deterministic noise; gentle low-end rather than harsh hiss."""
    rng = random.Random(seed)
    low = 0.0
    for i in range(int(length*RATE)):
        j = int(start*RATE)+i
        if j >= len(buf):
            break
        t = i/RATE
        low += smoothing*(rng.uniform(-1,1)-low)
        buf[j] += volume*envelope(t,length,.009,.035)*math.exp(-decay*t)*low


def make_move():
    buf=[0.0]*int(.13*RATE)
    mix_tone(buf,.010,.10,118,.06,decay=18)
    noise_layer(buf,.008,.085,.055,17,smoothing=.07,decay=20)
    return buf,.085


def make_pickup():
    buf=[0.0]*int(.52*RATE)
    for start,freq,volume in [(0.01,659.255,.10),(.085,987.767,.085),(.16,1318.510,.065)]:
        mix_tone(buf,start,.34,freq,volume,decay=7,shimmer=.10)
    return buf,.18


def make_door():
    buf=[0.0]*int(.42*RATE)
    noise_layer(buf,.012,.075,.14,31,smoothing=.22,decay=14)
    mix_tone(buf,.028,.20,105,.08,decay=10)
    mix_tone(buf,.10,.19,277.183,.065,decay=7,shimmer=.12)
    mix_tone(buf,.17,.22,415.305,.055,decay=8,shimmer=.08)
    return buf,.17


def make_impact():
    buf=[0.0]*int(.30*RATE)
    noise_layer(buf,.012,.19,.24,43,smoothing=.16,decay=15)
    # Downward drum sweep; integrated phase avoids clicks in the pitch change.
    for i in range(int(.24*RATE)):
        t=i/RATE
        phase=TAU*(150*t-160*t*t)
        buf[i] += .13*envelope(t,.24,.008,.07)*math.exp(-10*t)*math.sin(phase)
    return buf,.19


def make_victory():
    buf=[0.0]*int(1.65*RATE)
    for start,freq in [(0.02,261.626),(.18,329.628),(.34,391.995),(.52,523.251)]:
        mix_tone(buf,start,.49,freq,.075,decay=2.4,shimmer=.13)
    for freq in [261.626,329.628,391.995,523.251]:
        mix_tone(buf,.82,.70,freq,.038,decay=1.5,shimmer=.08)
    return buf,.18


def make_water():
    buf=[0.0]*int(.85*RATE)
    noise_layer(buf,.012,.72,.11,59,smoothing=.045,decay=1.1)
    # Discrete bubbles are phase-continuous damped downward chirps.
    for start,freq in [(.10,430),(.24,590),(.38,370),(.54,510)]:
        length=.18
        for i in range(int(length*RATE)):
            t=i/RATE; j=int(start*RATE)+i
            phase=TAU*(freq*t-550*t*t)
            buf[j]+=.055*envelope(t,length,.012,.07)*math.exp(-11*t)*math.sin(phase)
    mix_tone(buf,.02,.38,88,.04,decay=7)
    return buf,.14


def export(name, values, ceiling):
    # Five milliseconds of exact silence at both ends, plus a smooth 8ms blend.
    silence=math.ceil(.005*RATE)
    for i in range(len(values)):
        start=(i-silence)/(.008*RATE)
        end=(len(values)-1-i-silence)/(.012*RATE)
        values[i] *= smoothstep(start)*smoothstep(end)
    peak=max(abs(v) for v in values)
    gain=min(1.0,ceiling/peak) if peak else 1.0
    samples=[round(v*gain*32767) for v in values]
    assert all(-32768 < x < 32767 for x in samples), 'PCM clipping'
    assert samples[:silence]==[0]*silence and samples[-silence:]==[0]*silence
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(RATE)
        wav.writeframes(struct.pack('<%dh'%len(samples),*samples))
    with wave.open(str(path),'rb') as wav:
        assert (wav.getnchannels(),wav.getsampwidth(),wav.getframerate())==(1,2,RATE)
        assert wav.getnframes()==len(samples) and len(samples)/RATE<=2
    actual_peak=max(abs(x) for x in samples)/32768
    rms=math.sqrt(sum((x/32768)**2 for x in samples)/len(samples))
    return {'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'duration_seconds':round(len(samples)/RATE,5),'sample_rate':RATE,
            'channels':1,'sample_width_bits':16,'peak_dbfs':round(20*math.log10(actual_peak),2),
            'rms_dbfs':round(20*math.log10(rms),2),'exact_silent_edge_samples':silence}


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    entries=[]
    for name,fn in [('move',make_move),('pickup',make_pickup),('door',make_door),
                    ('impact',make_impact),('victory',make_victory),('water',make_water)]:
        entries.append(export(name,*fn()))
    (OUT/'manifest.json').write_text(json.dumps({'generator':'tools/build_audio.py','sounds':entries},indent=2)+'\n')
    (OUT/'SHA256SUMS').write_text(''.join(e['sha256']+'  '+e['file']+'\n' for e in entries))
    print(json.dumps(entries,indent=2))

if __name__=='__main__':
    main()
