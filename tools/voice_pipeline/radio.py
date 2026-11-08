"""Harter 90er-Militaerfunk: Bandpass, Kompression/Uebersteuerung, 8-kHz-Downsampling,
Rauschen + Knistern, Squelch-Klicks am Anfang/Ende.  python radio.py in.flac out.wav"""
import sys, numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt, resample_poly
def radio(path, out, seed=1):
    d, sr = sf.read(path)
    if d.ndim > 1: d = d.mean(1)
    d = d / (np.abs(d).max() + 1e-9)
    # Telefon-/Funkband
    y = sosfilt(butter(4, [380, 2900], btype="band", fs=sr, output="sos"), d)
    # Harter Kompressor-/Clipping-Eindruck
    y = np.tanh(y * 4.0) / np.tanh(4.0)
    y = np.sign(y) * np.abs(y) ** 0.8
    # 8 kHz + grobe Quantisierung (Digitalfunk-Krume)
    y = resample_poly(y, 8000, sr)
    y = np.round(y * 48) / 48
    rng = np.random.default_rng(seed)
    n = len(y)
    hiss = sosfilt(butter(2, [900, 3600], btype="band", fs=8000, output="sos"), rng.normal(0, 1, n)) * 0.06
    crack = np.zeros(n)
    idx = rng.integers(0, n, max(3, n // 900))
    crack[idx] = rng.choice([-1, 1], len(idx)) * rng.uniform(0.15, 0.5, len(idx))
    crack = sosfilt(butter(2, 1200, btype="high", fs=8000, output="sos"), crack)
    y = y * 0.85 + hiss + crack * 0.5
    sq = int(0.07 * 8000)
    env = np.linspace(1, 0, sq) ** 2
    start = sosfilt(butter(2, [700, 3200], btype="band", fs=8000, output="sos"), rng.normal(0, 1, sq)) * 0.55 * env
    end = start[::-1] * 0.8
    gap = np.zeros(int(0.03 * 8000))
    y = np.concatenate([start, gap, y, gap, end])
    y = resample_poly(y, 22050, 8000)
    y = y / (np.abs(y).max() + 1e-9) * 0.9
    sf.write(out, y.astype(np.float32), 22050, subtype="PCM_16")
if __name__ == "__main__": radio(sys.argv[1], sys.argv[2])
