"""Waffensounds fuer Laser (Shibas), Phaser (Katzen), Plasma (Baeren) und grosse Explosion.
Aufruf: python tools/make_weapon_sounds.py  (schreibt nach assets/sounds/)"""
import wave
from pathlib import Path
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
RNG = np.random.default_rng(2077)


def t(s):
    return np.arange(int(s * RATE)) / RATE


def env(n, attack=0.003, decay=8.0):
    x = np.arange(n) / RATE
    return np.minimum(1.0, x / attack) * np.exp(-decay * x)


def lowpass(x, k):
    return np.convolve(x, np.ones(k) / k, mode="same") if k > 1 else x


def chirp(s, f0, f1):
    x = t(s)
    f = f0 * (f1 / f0) ** (x / s)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def save(name, x):
    x = x / max(np.abs(x).max(), 1e-6) * 0.85
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


# Laser: schneller Abwaertssweep mit Obertoenen ("pew")
s = 0.22
x = chirp(s, 2600, 380) + 0.4 * chirp(s, 5200, 760)
save("laser_shot", x * env(len(x), 0.002, 14))
# Phaser: modulierter, schwebender Ton mit Vibrato
s = 0.45
tt = t(s)
f = 520 + 140 * np.sin(2 * np.pi * 38 * tt)
x = np.sin(2 * np.pi * np.cumsum(f) / RATE) + 0.5 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / RATE)
x += 0.15 * RNG.uniform(-1, 1, len(x))
save("phaser_shot", x * env(len(x), 0.01, 5))
# Plasma: dumpfer Wumms mit brummendem Abwaertssweep
s = 0.5
x = chirp(s, 320, 60) * 1.0 + lowpass(RNG.uniform(-1, 1, int(s * RATE)), 12) * 0.8
save("plasma_shot", x * env(len(x), 0.004, 7))
# Grosse Explosion: tiefes Grollen + Knall
s = 1.6
n = int(s * RATE)
boom = lowpass(RNG.uniform(-1, 1, n), 40) * env(n, 0.003, 2.6) * 2.5
crack = RNG.uniform(-1, 1, n) * env(n, 0.001, 30)
sub = chirp(s, 90, 30) * env(n, 0.005, 3)
save("explosion_huge", boom + crack * 0.6 + sub)
print("ok")
