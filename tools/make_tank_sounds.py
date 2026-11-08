"""Erzeugt Panzer-Sounds synthetisch (kein Download, frei nutzbar):
tank_engine_loop.wav, tank_tracks_loop.wav (nahtlose Schleifen), tank_fire.wav, shell_impact.wav
  python tools/make_tank_sounds.py  -> assets/sounds/"""
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt

SR = 44100
rng = np.random.default_rng(7)
OUT = "assets/sounds/"


def lp(x, f, o=4):
    return sosfilt(butter(o, f, btype="low", fs=SR, output="sos"), x)


def bp(x, lo, hi, o=4):
    return sosfilt(butter(o, [lo, hi], btype="band", fs=SR, output="sos"), x)


def norm(x, peak=0.9):
    return (x / (np.abs(x).max() + 1e-9) * peak).astype(np.float32)


def loopify(x, fade=0.25):
    """Nahtlose Schleife: Ende in den Anfang überblenden."""
    n = int(fade * SR)
    head, tail = x[:n], x[-n:]
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


# Motor: Dieselbrummen aus Zündimpulsen (~28 Hz) mit Obertönen, Rauschen und Schwankung
dur = 4.0
t = np.arange(int(dur * SR)) / SR
f0 = 28 + 1.5 * np.sin(2 * np.pi * 0.5 * t)
phase = 2 * np.pi * np.cumsum(f0) / SR
engine = sum((0.9 / k) * np.sin(k * phase + rng.uniform(0, 6)) for k in range(1, 12))
pulses = np.maximum(0, np.sin(phase)) ** 6
engine = engine * (0.6 + 0.4 * pulses)
engine += lp(rng.normal(0, 1, len(t)), 300) * 0.8 * (0.5 + 0.5 * pulses)
engine += bp(rng.normal(0, 1, len(t)), 600, 1800) * 0.08
engine = lp(np.tanh(engine * 0.6), 2200)
sf.write(OUT + "tank_engine_loop.wav", norm(loopify(engine), 0.7), SR)

# Ketten: metallisches Klackern der Kettenglieder (~9 pro Sekunde) mit Quietschen
dur = 3.0
n = int(dur * SR)
tracks = np.zeros(n)
rate = 9.0
for k in range(int(dur * rate)):
    pos = int((k / rate + rng.uniform(-0.01, 0.01)) * SR)
    ln = int(0.05 * SR)
    if pos + ln >= n:
        break
    env = np.exp(-np.linspace(0, 9, ln))
    click = bp(rng.normal(0, 1, ln), 900, 4500) * env * rng.uniform(0.6, 1.0)
    clank = np.sin(2 * np.pi * rng.uniform(180, 260) * np.arange(ln) / SR) * env * 0.5
    tracks[pos:pos + ln] += click + clank
tracks += bp(rng.normal(0, 1, n), 2500, 6000) * 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * np.arange(n) / SR))
tracks += lp(rng.normal(0, 1, n), 200) * 0.4
sf.write(OUT + "tank_tracks_loop.wav", norm(loopify(tracks, 0.15), 0.6), SR)

# Abschuss: harter Knall, tiefer Wumms, Nachhall
dur = 1.8
n = int(dur * SR)
tt = np.arange(n) / SR
crack = bp(rng.normal(0, 1, n), 1500, 9000) * np.exp(-tt * 60)
boom = lp(rng.normal(0, 1, n), 180) * np.exp(-tt * 4.5) * 3.0
thump = np.sin(2 * np.pi * 45 * tt * np.exp(-tt * 1.5)) * np.exp(-tt * 6) * 1.5
tail = lp(rng.normal(0, 1, n), 900) * np.exp(-tt * 2.2) * 0.5
fire = np.tanh((crack * 1.4 + boom + thump + tail) * 1.6)
sf.write(OUT + "tank_fire.wav", norm(fire), SR)

# Einschlag: Explosion mit Splittern
dur = 2.0
n = int(dur * SR)
tt = np.arange(n) / SR
blast = lp(rng.normal(0, 1, n), 400) * np.exp(-tt * 3.0) * 2.5
debris = np.zeros(n)
for k in range(40):
    pos = int(rng.uniform(0.05, 1.2) * SR)
    ln = int(0.03 * SR)
    if pos + ln < n:
        debris[pos:pos + ln] += bp(rng.normal(0, 1, ln), 1500, 7000) * np.exp(-np.linspace(0, 8, ln)) * rng.uniform(0.1, 0.5)
crack = bp(rng.normal(0, 1, n), 800, 6000) * np.exp(-tt * 25)
impact = np.tanh((blast + crack + debris) * 1.4)
sf.write(OUT + "shell_impact.wav", norm(impact), SR)
print("ok")
