#!/usr/bin/env python3
"""Synthesises the Dead Hours soundtrack, ambience and dialogue voices.

Everything is generated from maths, so the repo stays free of licensed audio and
the whole soundtrack can be re-tuned by editing this file.

    python3 tools/make_audio.py

Output (22050 Hz, 16-bit mono WAV, seamless loops):
    assets/audio/music/chapter{1,2,3}.wav
    assets/audio/ambient/{cold_drone_loop,gas_station_hum,industrial_hum,rain_loop,wind_loop}.wav
    assets/audio/voices/voice_{a,b,c,d}.wav
"""
import math, os, random, struct, wave

SR = 22050
rng = random.Random(20261106)


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    if peak > 0.99:                      # soft limit, keep headroom
        samples = [s / peak * 0.95 for s in samples]
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print(f"  {path}  {len(samples)/SR:.1f}s")


def env(i, n, attack=0.01, release=0.1):
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    if i < a:
        return i / a
    if i > n - r:
        return max(0.0, (n - i) / r)
    return 1.0


def tone(freq, dur, amp=0.2, kind="sine", decay=None, vib=0.0, vib_rate=5.0):
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        f = freq * (1.0 + vib * math.sin(2 * math.pi * vib_rate * t))
        ph = 2 * math.pi * f * t
        if kind == "sine":
            v = math.sin(ph)
        elif kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        elif kind == "saw":
            v = 2 * ((f * t) % 1.0) - 1
        else:
            v = 1.0 if math.sin(ph) > 0 else -1.0
        e = math.exp(-t / decay) if decay else env(i, n, 0.005, min(0.2, dur * 0.5))
        out[i] += v * amp * e
    return out


def mix(dst, src, at):
    start = int(at * SR)
    for i, s in enumerate(src):
        j = start + i
        if j < len(dst):
            dst[j] += s


def lowpass(samples, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    y = 0.0
    out = []
    for s in samples:
        y = (1 - a) * s + a * y
        out.append(y)
    return out


def noise_bed(dur, amp, cutoff):
    raw = [rng.uniform(-1, 1) for _ in range(int(dur * SR))]
    return [s * amp for s in lowpass(raw, cutoff)]


# ------------------------------------------------------------------ music

def chapter1(dur=24.0):
    n = int(dur * SR)
    out = [0.0] * n
    # two-cycle tremolo so the loop point is silent-free
    for i in range(n):
        t = i / SR
        lfo = 0.75 + 0.25 * math.sin(2 * math.pi * (2.0 / dur) * t)
        out[i] += (math.sin(2 * math.pi * 55 * t) * 0.16 + math.sin(2 * math.pi * 82.5 * t) * 0.07) * lfo
    for beat in range(int(dur / 3.0)):            # heartbeat
        at = beat * 3.0
        mix(out, tone(52, 0.34, 0.24, decay=0.11), at)
        mix(out, tone(46, 0.26, 0.15, decay=0.09), at + 0.24)
    for at in (6.0, 17.5):                        # distant metal
        mix(out, tone(1180, 1.6, 0.05, decay=0.6), at)
        mix(out, tone(1760, 1.2, 0.03, decay=0.45), at + 0.01)
    bed = noise_bed(dur, 0.05, 420)
    for i in range(n):
        out[i] += bed[i]
    return out


def chapter2(dur=24.0):
    n = int(dur * SR)
    out = [0.0] * n
    step = 0.25
    for k in range(int(dur / step)):
        at = k * step
        f = 82.0 if k % 4 else 123.0
        amp = 0.20 if k % 4 == 0 else 0.10
        mix(out, tone(f, 0.22, amp, kind="tri", decay=0.07), at)
        if k % 8 == 7:
            mix(out, tone(196, 0.5, 0.05, decay=0.22), at)
    for i in range(n):                            # fluorescent hum + ticks
        t = i / SR
        out[i] += math.sin(2 * math.pi * 120 * t) * 0.035 + math.sin(2 * math.pi * 240 * t) * 0.012
    for t in range(0, int(dur), 1):
        mix(out, tone(2400, 0.05, 0.02, decay=0.012), float(t))
    bed = noise_bed(dur, 0.03, 900)
    for i in range(n):
        out[i] += bed[i]
    return out


def chapter3(dur=24.0):
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        swell = 0.55 + 0.45 * math.sin(2 * math.pi * (3.0 / dur) * t)
        out[i] += (math.sin(2 * math.pi * 110 * t) * 0.10 +
                   math.sin(2 * math.pi * 165 * t) * 0.07 +
                   math.sin(2 * math.pi * 220 * t) * 0.05) * swell
    for at in (2.0, 8.0, 14.0, 20.0):
        mix(out, tone(330, 2.4, 0.05, decay=0.9), at)
    bed = noise_bed(dur, 0.035, 700)
    for i in range(n):
        out[i] += bed[i]
    return out


# ------------------------------------------------------------------ ambience

def amb_drone(dur=12.0):
    n = int(dur * SR)
    out = [math.sin(2 * math.pi * 45 * i / SR) * 0.12 + math.sin(2 * math.pi * 67.5 * i / SR) * 0.06 for i in range(n)]
    bed = noise_bed(dur, 0.04, 300)
    return [out[i] + bed[i] for i in range(n)]


def amb_station(dur=12.0):
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        out.append(math.sin(2 * math.pi * 120 * t) * 0.07 + math.sin(2 * math.pi * 240 * t) * 0.02)
    bed = noise_bed(dur, 0.03, 700)
    for i in range(n):
        out[i] += bed[i]
    return out


def amb_industrial(dur=12.0):
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * 8 * t)
        out.append((math.sin(2 * math.pi * 60 * t) * 0.08 + math.sin(2 * math.pi * 180 * t) * 0.03) * trem)
    bed = noise_bed(dur, 0.025, 500)
    for i in range(n):
        out[i] += bed[i]
    return out


def amb_rain(dur=12.0):
    bed = noise_bed(dur, 0.22, 2600)
    for _ in range(int(dur * 14)):
        mix(bed, tone(rng.uniform(600, 2600), 0.05, 0.05, decay=0.012), rng.uniform(0, dur))
    return bed


def amb_wind(dur=12.0):
    n = int(dur * SR)
    raw = [rng.uniform(-1, 1) for _ in range(n)]
    lp = lowpass(raw, 520)
    out = []
    for i in range(n):
        t = i / SR
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * (2.0 / dur) * t)
        out.append(lp[i] * 0.20 * lfo)
    return out


# ------------------------------------------------------------------ voices

def voice(base, dur=0.085, formants=(1.0, 2.4, 3.7)):
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        s = 0.0
        for h, g in enumerate(formants, start=1):
            f = base * h * (1.0 + 0.02 * math.sin(2 * math.pi * 11 * t))
            s += math.sin(2 * math.pi * f * t) * (g ** -1.35)
        e = math.exp(-t / (dur * 0.32)) * (1 - math.exp(-t / 0.004))
        out[i] = s * 0.5 * e
    return out


if __name__ == "__main__":
    print("music")
    write_wav("assets/audio/music/chapter1.wav", chapter1())
    write_wav("assets/audio/music/chapter2.wav", chapter2())
    write_wav("assets/audio/music/chapter3.wav", chapter3())
    print("ambience")
    write_wav("assets/audio/ambient/cold_drone_loop.wav", amb_drone())
    write_wav("assets/audio/ambient/gas_station_hum.wav", amb_station())
    write_wav("assets/audio/ambient/industrial_hum.wav", amb_industrial())
    write_wav("assets/audio/ambient/rain_loop.wav", amb_rain())
    write_wav("assets/audio/ambient/wind_loop.wav", amb_wind())
    print("voices")
    for name, base in (("a", 150), ("b", 185), ("c", 220), ("d", 255)):
        write_wav(f"assets/audio/voices/voice_{name}.wav", voice(base))
    print("done")
