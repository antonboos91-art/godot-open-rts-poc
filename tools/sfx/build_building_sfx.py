"""MOSS-Rohsounds (building_sfx.py) schneiden, ein- und ausblenden, Lautstaerke angleichen.
  <comfy-venv-python> build_building_sfx.py <comfy-output/bsfx>
Ergebnis: game/assets/sounds/buildings/<volk>_<rolle>.wav"""
import glob, os, re, sys
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

SRC = sys.argv[1]
DST = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sounds", "buildings"))
os.makedirs(DST, exist_ok=True)
for f in sorted(glob.glob(os.path.join(SRC, "*.flac"))):
    m = re.match(r"([a-z]+)_([a-z_]+?)_\d+_?\.flac$", os.path.basename(f))
    if not m:
        continue
    d, sr = sf.read(f)
    if d.ndim > 1:
        d = d.mean(1)
    d = sosfilt(butter(2, 40, btype="high", fs=sr, output="sos"), d)
    # Stille am Anfang weg, dann max. 2.2 s mit weichem Ausklang
    start = int(np.argmax(np.abs(d) > np.abs(d).max() * 0.05))
    d = d[max(0, start - int(0.01 * sr)):][: int(2.2 * sr)]
    fade = min(len(d), int(0.5 * sr))
    d[-fade:] *= np.linspace(1, 0, fade) ** 1.5
    d[: int(0.005 * sr)] *= np.linspace(0, 1, int(0.005 * sr))
    rms = np.sqrt(np.mean(d ** 2)) + 1e-9
    d = np.tanh(d * (0.2 / rms)) * 0.8
    out = os.path.join(DST, f"{m.group(1)}_{m.group(2)}.wav")
    sf.write(out, d.astype(np.float32), sr, subtype="PCM_16")
    print("wrote", os.path.basename(out))
