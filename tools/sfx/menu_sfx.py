"""Menue-Geraeusche synthetisieren (kein Modell noetig):
  ui_click.wav  harter, knackiger Metall-Klick wie in Dark Reign (Relais-Schlag + tiefer Stoss + kurzer Servo)
  ui_hover.wav  leises elektronisches Ticken beim Ueberfahren
  python menu_sfx.py   (numpy, scipy, soundfile)"""
import os
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sounds"))
rng = np.random.default_rng(11)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def env(x, attack, decay):
    tt = np.arange(len(x)) / SR
    return x * np.minimum(tt / max(attack, 1e-5), 1.0) * np.exp(-tt / decay)


def band(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def pad(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]


def save(name, y):
    y = np.tanh(y / (np.abs(y).max() + 1e-9) * 1.6)
    y = y / (np.abs(y).max() + 1e-9) * 0.85
    sf.write(os.path.join(OUT, name), y.astype(np.float32), SR, subtype="PCM_16")
    print("wrote", name, round(len(y) / SR, 2), "s")


def click():
    n = int(0.42 * SR)
    # Relais-Schlag: zwei sehr kurze, helle Metall-Knacke
    snap = np.zeros(n)
    for off, g in ((0.0, 1.0), (0.018, 0.6)):
        k = env(band(rng.normal(size=int(0.03 * SR)), 1800, 9000), 0.0003, 0.004) * g
        i = int(off * SR)
        snap[i:i + len(k)] += k
    # metallisches Klingeln (unharmonische Teiltoene, sehr kurz)
    tt = t(0.25)
    ring = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((1430, 0.5), (2315, 0.35), (3770, 0.2)))
    ring = pad(env(ring, 0.0005, 0.035) * 0.35, n)
    # tiefer Stoss (Gewicht)
    tt = t(0.2)
    thump = np.sin(2 * np.pi * (95 * tt + 60 * (1 - np.exp(-tt * 40)) / 40 * -1))
    thump = pad(env(thump, 0.001, 0.05) * 0.9, n)
    # kurzer Servo hinterher
    tt = t(0.14)
    servo = np.sign(np.sin(2 * np.pi * (300 + 900 * tt) * tt)) * 0.12
    servo = band(servo, 400, 3000) * np.hanning(len(tt))
    s = np.zeros(n)
    i = int(0.035 * SR)
    s[i:i + len(servo)] = servo
    save("ui_click.wav", snap * 1.2 + ring + thump + s)


def hover():
    n = int(0.12 * SR)
    tt = t(0.12)
    blip = np.sin(2 * np.pi * (2400 - 900 * tt / 0.12) * tt)
    y = env(blip, 0.001, 0.025) * 0.5 + env(band(rng.normal(size=n), 3000, 8000), 0.0003, 0.006) * 0.4
    save("ui_hover.wav", y * 0.5)


os.makedirs(OUT, exist_ok=True)
click()
hover()
