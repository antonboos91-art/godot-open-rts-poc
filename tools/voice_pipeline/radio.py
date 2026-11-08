"""90er-Funk-Effekt: Bandpass 300-3400 Hz, leichte Saettigung, kurzes Rauschen/Klick. python radio.py in.flac out.wav"""
import sys, numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt
def radio(path, out):
    d, sr = sf.read(path)
    if d.ndim > 1: d = d.mean(1)
    sos = butter(4, [300, 3400], btype="band", fs=sr, output="sos")
    y = sosfilt(sos, d)
    y = np.tanh(y / (np.abs(y).max() + 1e-9) * 2.2)
    rng = np.random.default_rng(1)
    click = int(0.06 * sr)
    noise = rng.normal(0, 0.08, click) * np.linspace(1, 0, click)
    y = np.concatenate([noise, y * 0.9, noise[::-1] * 0.6])
    y += rng.normal(0, 0.006, len(y))
    sf.write(out, (y / np.abs(y).max() * 0.9).astype(np.float32), sr)
if __name__ == "__main__": radio(sys.argv[1], sys.argv[2])
