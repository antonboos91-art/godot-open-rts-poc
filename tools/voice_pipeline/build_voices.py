"""Rohstimmen (tts_design.py) bearbeiten und ins Spiel bringen.
  <comfy-venv-python> build_voices.py <comfy-output/voice2>
- Einheiten: harter 90er-Funk (radio.py). Katzen werden vorher zu einem Fluestern umgerechnet
  (Stimmton durch Rauschen ersetzt, etwas Originalstimme bleibt fuer die Verstaendlichkeit).
- Ansagen der Zentrale: sauberer Lautsprecher-Klang ohne Knistern.
Ergebnis: game/assets/voice/<volk>/<paket>/<kategorie>_<i>.wav und source/match/players/human/FactionVoices.gd"""
import glob, os, re, sys
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, stft, istft

sys.path.insert(0, os.path.dirname(__file__))
from radio import radio

SRC = sys.argv[1]
GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DST = os.path.join(GAME, "assets", "voice")
GD = os.path.join(GAME, "source", "match", "players", "human", "FactionVoices.gd")
TMP = os.path.join(GAME, ".voice_tmp.wav")


def whisper(path, out, dry=0.22):
    d, sr = sf.read(path)
    if d.ndim > 1:
        d = d.mean(1)
    f, t, Z = stft(d, sr, nperseg=1024, noverlap=768)
    rng = np.random.default_rng(3)
    mag = np.abs(Z)
    # Fluestern: gleiche Klangfarbe (Huellkurve), aber stimmlose Anregung (Zufallsphase), Hoehen etwas betont
    tilt = np.clip((f / 2500.0) ** 0.35, 0.6, 1.6)[:, None]
    W = mag * tilt * np.exp(1j * rng.uniform(0, 2 * np.pi, Z.shape))
    _, w = istft(W, sr, nperseg=1024, noverlap=768)
    w = w[: len(d)]
    y = w / (np.abs(w).max() + 1e-9) * (1 - dry) + d / (np.abs(d).max() + 1e-9) * dry
    y = sosfilt(butter(2, 160, btype="high", fs=sr, output="sos"), y)
    sf.write(out, (y / (np.abs(y).max() + 1e-9) * 0.9).astype(np.float32), sr)


def announcer(path, out):
    d, sr = sf.read(path)
    if d.ndim > 1:
        d = d.mean(1)
    y = sosfilt(butter(3, [170, 6500], btype="band", fs=sr, output="sos"), d)
    y = np.tanh(y / (np.abs(y).max() + 1e-9) * 1.8) / np.tanh(1.8)
    # kurzer Hall wie ein Lautsprecher in der Basis
    delay = int(0.045 * sr)
    y = np.concatenate([y, np.zeros(delay * 3)])
    for k, g in ((1, 0.28), (2, 0.12), (3, 0.05)):
        y[delay * k:] += y[: len(y) - delay * k] * g
    sf.write(out, (y / (np.abs(y).max() + 1e-9) * 0.9).astype(np.float32), sr, subtype="PCM_16")


table = {}
for f in sorted(glob.glob(os.path.join(SRC, "*", "*", "*.flac"))):
    pack = os.path.basename(os.path.dirname(f))
    fac = os.path.basename(os.path.dirname(os.path.dirname(f)))
    m = re.match(r"(.+?)_(\d+)_\d+_?\.flac$", os.path.basename(f))
    if not m:
        continue
    cat, i = m.group(1), int(m.group(2))
    os.makedirs(os.path.join(DST, fac, pack), exist_ok=True)
    out = os.path.join(DST, fac, pack, f"{cat}_{i}.wav")
    if pack == "announcer":
        if fac == "katzen":
            whisper(f, TMP, dry=0.45)
            announcer(TMP, out)
        else:
            announcer(f, out)
    elif fac == "katzen":
        whisper(f, TMP)
        radio(TMP, out)
    else:
        radio(f, out)
    res = "res://" + os.path.relpath(out, GAME).replace("\\", "/")
    table.setdefault(fac, {}).setdefault(pack, {}).setdefault(cat, []).append(res)
if os.path.exists(TMP):
    os.remove(TMP)

lines = ["## Automatisch erzeugt von tools/voice_pipeline/build_voices.py - nicht von Hand bearbeiten.",
         "## Stimmen aller Voelker: LINES[volk][paket][kategorie] = [AudioStream, ...]",
         "## Pakete: all, worker, vehicle, air, beast, engineer, announcer", "extends RefCounted", "", "const LINES = {"]
for fac, packs in sorted(table.items()):
    lines.append(f'\t"{fac}": {{')
    for pack, cats in sorted(packs.items()):
        lines.append(f'\t\t"{pack}": {{')
        for cat, fs in sorted(cats.items()):
            lines.append(f'\t\t\t"{cat}": [')
            for p in sorted(set(fs)):
                lines.append(f'\t\t\t\tpreload("{p}"),')
            lines.append("\t\t\t],")
        lines.append("\t\t},")
    lines.append("\t},")
lines.append("}")
open(GD, "w", encoding="utf8", newline="\n").write("\n".join(lines) + "\n")
print({fac: {p: sum(len(v) for v in c.values()) for p, c in ps.items()} for fac, ps in table.items()})
