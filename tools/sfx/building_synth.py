"""Gebaeude-Geraeusche je Volk und Gebaeudeart per Synthese (ohne KI-Modell).
Wird gespielt, wenn man ein eigenes Gebaeude anwaehlt (UnitVoicesController._play_building_sound).
  <python mit numpy/scipy/soundfile> building_synth.py   ->  assets/sounds/buildings/<volk>_<rolle>.wav
Klangcharakter: Shibas sauber/hell (Piepser, Servos, Sinus), Katzen dunkel/leise (Drohnen, Schimmern),
Baeren schwer/metallisch (Klonk, Dampf, Verzerrung)."""
import os
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sounds", "buildings"))
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(5)
DUR = 2.0
N = int(DUR * SR)
TT = np.arange(N) / SR


def band(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], btype="band", fs=SR, output="sos"), x)


def low(x, f):
    return sosfilt(butter(2, f, btype="low", fs=SR, output="sos"), x)


def place(sig, at):
    y = np.zeros(N)
    i = int(at * SR)
    if i < N:
        y[i:i + len(sig)] = sig[: N - i]
    return y


def decay(n_s, tau, attack=0.002):
    t = np.arange(int(n_s * SR)) / SR
    return np.minimum(t / attack, 1) * np.exp(-t / tau)


def noise(n_s, lo=200, hi=8000):
    return band(rng.normal(size=int(n_s * SR)), lo, hi)


def tone(f, n_s, tau, harm=(1.0,), attack=0.002, fm=None):
    t = np.arange(int(n_s * SR)) / SR
    ph = 2 * np.pi * f * t + (fm(t) if fm else 0)
    return sum(a * np.sin(ph * (k + 1)) for k, a in enumerate(harm)) * decay(n_s, tau, attack)


def sweep(f0, f1, n_s, tau, attack=0.003):
    t = np.arange(int(n_s * SR)) / SR
    f = f0 + (f1 - f0) * t / n_s
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * decay(n_s, tau, attack)


def clank(f, g=1.0, tau=0.08):
    ring = tone(f, 0.5, tau, (1.0, 0.0, 0.0)) + tone(f * 1.52, 0.5, tau * 0.8) * 0.6 + tone(f * 2.33, 0.5, tau * 0.6) * 0.4
    burst = noise(0.05, 1500, 9000) * decay(0.05, 0.01) * 2.0
    return (ring + np.concatenate([burst, np.zeros(len(ring) - len(burst))])) * g


def thump(g=1.0, f=70):
    return sweep(f * 2.2, f, 0.25, 0.07) * g


def beep(f, n=0.07, g=0.5):
    return tone(f, n, n * 0.9, (1.0, 0.2)) * g


def hum(f, g=0.5, harm=(1.0, 0.5, 0.3, 0.15), wobble=0.0):
    fm = (lambda t: wobble * np.sin(2 * np.pi * 5 * t)) if wobble else None
    env = np.minimum(TT / 0.15, 1) * np.exp(-np.maximum(TT - 1.2, 0) / 0.4)
    t = TT
    ph = 2 * np.pi * f * t + (fm(t) if fm else 0)
    return sum(a * np.sin(ph * (k + 1)) for k, a in enumerate(harm)) * env * g


def steam(at, g=0.6, n=0.6):
    return place(noise(n, 1800, 9000) * decay(n, n * 0.4, 0.03) * g, at)


def rumble(g=0.5, f=90):
    return low(rng.normal(size=N), f) * np.minimum(TT / 0.2, 1) * np.exp(-np.maximum(TT - 1.0, 0) / 0.5) * g * 4


def shimmer(g=0.3, f=1200):
    y = sum(np.sin(2 * np.pi * (f * r) * TT + 3 * np.sin(2 * np.pi * (0.5 + k) * TT)) for k, r in enumerate((1.0, 1.5, 2.01, 2.76)))
    return y * np.minimum(TT / 0.3, 1) * np.exp(-np.maximum(TT - 0.9, 0) / 0.5) * g * 0.25


def servo(at, n=0.5, f0=250, f1=700, g=0.35):
    t = np.arange(int(n * SR)) / SR
    f = f0 + (f1 - f0) * t / n
    s = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.5 + np.sin(2 * np.pi * np.cumsum(f * 2) / SR) * 0.3
    return place(band(s, 300, 4000) * np.hanning(len(t)) * g, at)


# --- Rezepte je Gebaeudeart; k = Klangfarbe des Volkes (f: Tonhoehe, hard: Klonk-Anteil, soft: Schimmer) ---
def recipe(role, k):
    f, h, s = k["f"], k["hard"], k["soft"]
    y = np.zeros(N)
    if role == "hq":
        for i, at in enumerate((0.0, 0.18, 0.36)):
            y += place(beep(900 * f * (1 + 0.25 * i)), at) * (1 - h * 0.5)
        y += place(noise(0.9, 800, 3500) * decay(0.9, 0.3) * 0.25, 0.5)  # Funkrauschen
        y += hum(110 * f, 0.35) + place(clank(300 * f, 0.5 * h), 0.0) + shimmer(s * 0.4)
    elif role in ("power", "power_big"):
        big = 1.6 if role == "power_big" else 1.0
        y += hum(60 * f / big, 0.7, wobble=2 * big) + place(sweep(200 * f, 900 * f * big, 1.2, 0.8) * 0.25, 0.0)
        y += place(noise(1.2, 3000, 9000) * np.abs(np.sin(2 * np.pi * 40 * TT[: int(1.2 * SR)])) * decay(1.2, 0.6) * 0.3, 0.1)
        y += rumble(0.4 * big, 70) + shimmer(s * 0.5, 900)
    elif role == "refinery":
        y += rumble(0.6, 120) + place(noise(1.6, 300, 3000) * np.abs(np.sin(2 * np.pi * 9 * TT[: int(1.6 * SR)])) * decay(1.6, 1.0) * 0.5, 0.0)
        for at in (0.1, 0.45, 0.9, 1.3):
            y += place(clank(220 * f, 0.5 * (0.5 + h), 0.05), at) + place(noise(0.25, 200, 2500) * decay(0.25, 0.08) * 0.5, at + 0.02)
    elif role == "barracks":
        y += place(thump(1.0, 60), 0.0) + steam(0.05, 0.4, 0.5)
        for at in (0.5, 0.85, 1.2, 1.55):
            y += place(thump(0.4, 90 * f), at) + place(noise(0.08, 400, 2500) * decay(0.08, 0.02) * 0.35, at)
        y += place(clank(500 * f, 0.4 * h), 0.3)
    elif role == "factory":
        y += place(thump(1.2, 50), 0.0) + place(clank(180 * f, 0.9 * (0.3 + h), 0.12), 0.0)
        y += servo(0.15, 0.9, 200 * f, 600 * f) + steam(0.7, 0.5, 0.6)
        for at in (1.0, 1.35):
            y += place(clank(350 * f, 0.5 * h, 0.04), at) + place(noise(0.15, 3000, 10000) * decay(0.15, 0.04) * 0.5, at)
    elif role == "silo":
        y += place(thump(1.0, 45), 0.0) + place(clank(130 * f, 0.9 * (0.3 + h), 0.25), 0.02)
        y += place(sweep(900 * f, 300 * f, 0.5, 0.3) * 0.2, 0.3) + steam(0.35, 0.5, 0.7) + rumble(0.25, 60)
    elif role == "radar":
        for at in (0.0, 0.9):
            y += place(tone(1500 * f, 1.0, 0.25, (1.0, 0.1)) * 0.55, at)  # Sonar-Ping
        y += servo(0.0, 1.8, 120 * f, 160 * f, 0.18) + place(beep(2200 * f, 0.05), 0.45) + place(beep(1800 * f, 0.05), 1.35)
        y += shimmer(s * 0.5, 1800)
    elif role == "airfield":
        y += place(sweep(150 * f, 900 * f, 1.7, 1.2) * 0.45, 0.0) + place(noise(1.6, 800, 5000) * decay(1.6, 0.9, 0.3) * 0.5, 0.0)
        y += rumble(0.4, 100) + place(clank(260 * f, 0.4 * h), 0.0)
    elif role == "repair":
        for at in (0.0, 0.3, 0.6):
            y += place(clank((400 + 60 * (at * 3)) * f, 0.7 * (0.4 + h), 0.05), at)
        y += servo(0.9, 0.4, 500 * f, 900 * f, 0.5)  # Druckluftschrauber
        y += servo(1.35, 0.3, 600 * f, 950 * f, 0.4) + shimmer(s * 0.3, 2000)
    elif role == "lab":
        y += hum(180 * f, 0.25, harm=(1.0, 0.3))
        for i, at in enumerate((0.1, 0.45, 0.8, 1.2)):
            y += place(tone((700 + 300 * (i % 3)) * f, 0.25, 0.1) * 0.5, at)
        y += place(noise(1.2, 1000, 6000) * np.abs(np.sin(2 * np.pi * 14 * TT[: int(1.2 * SR)])) * decay(1.2, 0.5) * 0.3, 0.2) + shimmer(s)
    elif role == "turret_ground":
        y += servo(0.0, 0.7, 150 * f, 350 * f, 0.5) + place(clank(500 * f, 0.9 * (0.3 + h), 0.07), 0.75)
        y += place(thump(0.8, 80), 0.8) + place(beep(1000 * f, 0.05), 1.1)
    elif role == "turret_air":
        y += servo(0.0, 0.35, 300 * f, 900 * f, 0.5) + servo(0.4, 0.35, 900 * f, 300 * f, 0.5)
        for at in (0.85, 1.0, 1.15, 1.3):
            y += place(clank(650 * f, 0.5 * (0.3 + h), 0.03), at)
        y += place(beep(2000 * f, 0.04), 1.6)
    elif role == "superweapon":
        y += place(sweep(60 * f, 600 * f, 2.0, 1.6) * 0.5, 0.0) + rumble(0.6, 80) + shimmer(s * 1.2, 700)
        for at in (0.0, 0.5, 1.0, 1.5):
            y += place(tone(880 * f, 0.22, 0.12) * 0.5, at) + place(tone(660 * f, 0.22, 0.12) * 0.5, at + 0.25)
    return y


FAC = {
    "shibas": {"f": 1.15, "hard": 0.35, "soft": 0.35, "dist": 1.3},
    "katzen": {"f": 0.8, "hard": 0.15, "soft": 1.3, "dist": 1.0},
    "baeren": {"f": 0.7, "hard": 1.0, "soft": 0.1, "dist": 2.4},
}
ROLES = ["hq", "power", "power_big", "refinery", "barracks", "factory", "silo", "radar", "airfield", "repair", "lab",
         "turret_ground", "turret_air", "superweapon"]

for fac, k in FAC.items():
    for role in ROLES:
        y = recipe(role, k)
        y = np.tanh(y / (np.abs(y).max() + 1e-9) * k["dist"]) / np.tanh(k["dist"])
        if fac == "katzen":
            y = low(y, 5500)
        y[-int(0.4 * SR):] *= np.linspace(1, 0, int(0.4 * SR))
        y = y / (np.abs(y).max() + 1e-9) * 0.8
        sf.write(os.path.join(OUT, f"{fac}_{role}.wav"), y.astype(np.float32), SR, subtype="PCM_16")
print("fertig:", len(FAC) * len(ROLES), "Sounds")
