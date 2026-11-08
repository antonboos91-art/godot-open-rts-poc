"""Erzeugt die Soundeffekte (kleine, harte 90er-Jahre-Sounds) als WAV-Dateien.

Alles wird aus Rauschen und einfachen Schwingungen berechnet und anschließend auf
8 Bit / 11 kHz heruntergerechnet, damit es nach alten Soundkarten klingt.
Aufruf: python3 tools/make_sounds.py  (schreibt nach assets/sounds/)
"""

import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
RNG = np.random.default_rng(1990)


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return RNG.uniform(-1, 1, int(seconds * RATE))


def env(n, attack=0.002, decay=6.0):
    x = np.arange(n) / RATE
    return np.minimum(1.0, x / attack) * np.exp(-decay * x)


def lowpass(x, k):
    """Einfacher gleitender Mittelwert; k = Fensterbreite."""
    if k <= 1:
        return x
    return np.convolve(x, np.ones(k) / k, mode="same")


def sweep(seconds, f0, f1):
    x = t(seconds)
    freq = f0 + (f1 - f0) * x / seconds
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def square(seconds, f):
    return np.sign(np.sin(2 * np.pi * f * t(seconds)))


def crush(x, bits=6, hold=2):
    """Bit-Crusher: weniger Auflösung und Abtastrate, klingt nach 90ern."""
    levels = 2 ** (bits - 1)
    x = np.round(np.clip(x, -1, 1) * levels) / levels
    return np.repeat(x[::hold], hold)[: len(x)]


def save(name, x, bits=6, hold=2):
    x = crush(x / max(1e-9, np.max(np.abs(x))) * 0.9, bits, hold)
    data = (x * 32767).astype("<i2")
    with wave.open(str(OUT / (name + ".wav")), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    print(name, len(x) / RATE)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Treffer: kurzer harter Knack
    n = noise(0.12)
    save("hit", n * env(len(n), 0.001, 38) + 0.5 * square(0.12, 180) * env(len(n), 0.001, 50))
    # kleine Explosion
    n = lowpass(noise(0.6), 6)
    save("explosion", n * env(len(n), 0.003, 7) + 0.6 * sweep(0.6, 140, 30) * env(len(n), 0.002, 6))
    # große Explosion (Gebäude)
    n = lowpass(noise(1.4), 14)
    save("explosion_big", n * env(len(n), 0.005, 3) + 0.8 * sweep(1.4, 90, 22) * env(len(n), 0.003, 3), 5, 3)
    # Superwaffe: aufsteigendes Heulen, dann Einschlag
    rise = sweep(1.0, 80, 900) * np.linspace(0.1, 1, int(1.0 * RATE))
    boom = lowpass(noise(1.6), 20) * env(int(1.6 * RATE), 0.002, 2.4)
    save("strike", np.concatenate([rise * 0.6, boom + 0.8 * sweep(1.6, 70, 18) * env(int(1.6 * RATE), 0.002, 2.4)]), 5, 3)
    # Hacken: digitales Zwitschern
    x = np.concatenate([square(0.05, f) * env(int(0.05 * RATE), 0.001, 20) for f in (880, 1320, 660, 1760, 990)])
    save("hack", x, 4, 3)
    # Reparatur: Metallklang
    x = (sweep(0.18, 2200, 1500) + 0.5 * square(0.18, 1100)) * env(int(0.18 * RATE), 0.001, 22)
    save("repair", x, 5, 2)
    # Fertig / Bereit: zwei Töne
    x = np.concatenate([square(0.1, 523) * env(int(0.1 * RATE), 0.002, 12), square(0.16, 784) * env(int(0.16 * RATE), 0.002, 9)])
    save("ready", x * 0.8, 5, 2)
    # Übernahme / Entfalten: tiefes Rumpeln mit Klack
    x = lowpass(noise(0.5), 10) * env(int(0.5 * RATE), 0.01, 5) + 0.5 * square(0.5, 70) * env(int(0.5 * RATE), 0.005, 8)
    save("deploy", x, 5, 3)


if __name__ == "__main__":
    main()
