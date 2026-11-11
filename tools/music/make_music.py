"""Spielmusik synthetisieren (numpy/scipy/soundfile, kein KI-Modell):
  intro.ogg     ca. 47 s, einmalig beim Spielstart: Katzen-Dunkel -> Baeren-Marsch -> Shiba-Elektro -> alle zusammen
  shibas.ogg    sauberes Elektro (110 BPM, Am-F-C-G, Arpeggio, Sidechain-Pad, Four-on-the-floor), ca. 70 s Schleife
  katzen.ogg    dunkle Ambience (66 BPM, d-Moll, Drohnen, Glocken, Herzschlag), ca. 87 s Schleife
  baeren.ogg    sowjetischer Marsch (96 BPM, d-Moll, Blech, Chor, Pauke, Marschtrommel), ca. 80 s Schleife
Die Schleifen sind nahtlos (Hall-Ausklang wird auf den Anfang gefaltet).
  <python> make_music.py [intro|shibas|katzen|baeren ...]   ->  assets/music/*.ogg"""
import os, sys
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "music"))
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(2026)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ---------- Grundbausteine ----------
def tt(n):
    return np.arange(n) / SR


def saw(f, n, ph0=0.0):
    return 2 * ((f * tt(n) + ph0) % 1.0) - 1


def sqr(f, n, pw=0.5):
    return np.where(((f * tt(n)) % 1.0) < pw, 1.0, -1.0)


def sine(f, n):
    return np.sin(2 * np.pi * f * tt(n))


def lp(x, fc, order=2):
    return sosfilt(butter(order, min(fc, SR * 0.45), btype="low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return sosfilt(butter(order, fc, btype="high", fs=SR, output="sos"), x)


def bp(x, lo, hi):
    return sosfilt(butter(2, [lo, min(hi, SR * 0.45)], btype="band", fs=SR, output="sos"), x)


def lp_sweep(x, fc_curve, block=1024):
    """Tiefpass mit zeitlich veraenderlicher Grenzfrequenz (fc_curve: Funktion t[s] -> Hz), blockweise."""
    out = np.zeros_like(x)
    zi = None
    for i in range(0, len(x), block):
        fc = float(np.clip(fc_curve(i / SR), 40, SR * 0.45))
        sos = butter(2, fc, btype="low", fs=SR, output="sos")
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[i:i + block], zi = sosfilt(sos, x[i:i + block], zi=zi)
    return out


def adsr(dur, a, d, s, r):
    n = int((dur + r) * SR)
    t = tt(n)
    e = np.where(t < a, t / max(a, 1e-4), np.where(t < a + d, 1 - (1 - s) * (t - a) / max(d, 1e-4), s))
    off = np.clip(1 - (t - dur) / r, 0, 1) ** 2
    return e * np.where(t > dur, off, 1.0)


def expdec(n_s, tau, attack=0.002):
    t = tt(int(n_s * SR))
    return np.minimum(t / attack, 1) * np.exp(-t / tau)


def noise(n_s):
    return rng.normal(size=int(n_s * SR))


def put(buf, sig, t_s, gain=1.0, pan=0.0):
    """Mono-Signal ab t_s in den Stereo-Puffer mischen, pan -1 (links) .. 1 (rechts)."""
    i = int(t_s * SR)
    if i >= len(buf) or i < 0:
        return
    n = min(len(sig), len(buf) - i)
    gl = np.cos((pan + 1) * np.pi / 4) * gain
    gr = np.sin((pan + 1) * np.pi / 4) * gain
    buf[i:i + n, 0] += sig[:n] * gl
    buf[i:i + n, 1] += sig[:n] * gr


def reverb(x, t60=2.5, wet=0.3, pre=0.02, damp=5000):
    n = int(t60 * 1.15 * SR)
    t = tt(n)
    out = np.zeros((len(x) + n, 2))
    out[:len(x)] = x * (1 - wet)
    for c in range(2):
        ir = rng.normal(size=n) * np.exp(-6.9 * t / t60)
        ir = lp(ir, damp)
        ir[:int(pre * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        y = fftconvolve(x[:, c], ir) * wet * 1.6
        out[: len(y), c] += y
    return out


def fold(x, L):
    y = x[:L].copy()
    rest = x[L:]
    k = 0
    while k * L < len(rest):
        seg = rest[k * L:(k + 1) * L]
        y[:len(seg)] += seg
        k += 1
    return y


def master(y, peak=0.89):
    y = y - y.mean(0)
    for c in range(2):
        y[:, c] = hp(y[:, c], 28)
    y = np.tanh(y / (np.abs(y).max() + 1e-9) * 1.25) / np.tanh(1.25)
    return y / (np.abs(y).max() + 1e-9) * peak


def write(name, y):
    path = os.path.join(OUT, name)
    y = y.astype(np.float32)
    # in Bloecken schreiben (ein grosser Schreibvorgang laesst libsndfile bei Vorbis abstuerzen)
    with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(y), 16384):
            f.write(y[i:i + 16384])
    print("wrote", name, round(len(y) / SR, 1), "s", round(os.path.getsize(path) / 1e6, 2), "MB")


# ---------- Schlagwerk ----------
def kick(dec=0.16, f0=140, f1=44):
    n = int(0.55 * SR)
    t = tt(n)
    f = f1 + (f0 - f1) * np.exp(-t / 0.028)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / dec)
    y[:200] += hp(rng.normal(size=200), 2000) * 0.25
    return y


def snare(dec=0.11, tone=190, g=1.0):
    n = int(0.4 * SR)
    t = tt(n)
    return (bp(rng.normal(size=n), 1400, 8000) * np.exp(-t / dec) * 0.9 + np.sin(2 * np.pi * tone * t) * np.exp(-t / 0.055) * 0.5) * g


def hat(dec=0.03, g=1.0):
    n = int(0.4 * SR)
    return hp(rng.normal(size=n), 7500) * np.exp(-tt(n) / dec) * g * 0.5


def clap():
    n = int(0.35 * SR)
    t = tt(n)
    y = np.zeros(n)
    for off in (0, 0.011, 0.022):
        i = int(off * SR)
        y[i:] += bp(rng.normal(size=n - i), 1100, 3200) * np.exp(-t[: n - i] / 0.012)
    y += bp(rng.normal(size=n), 1100, 3000) * np.exp(-np.maximum(t - 0.03, 0) / 0.1) * (t > 0.03) * 0.6
    return y * 0.8


def timpani(f=80):
    n = int(1.2 * SR)
    t = tt(n)
    fs = f + 18 * np.exp(-t / 0.05)
    y = np.sin(2 * np.pi * np.cumsum(fs) / SR) * np.exp(-t / 0.45) + np.sin(2 * np.pi * np.cumsum(fs * 1.5) / SR) * np.exp(-t / 0.15) * 0.2
    y += lp(rng.normal(size=n), 500) * np.exp(-t / 0.02) * 0.8
    return y


def boom(dur=3.0):
    n = int(dur * SR)
    t = tt(n)
    y = np.sin(2 * np.pi * np.cumsum(38 + 60 * np.exp(-t / 0.12)) / SR) * np.exp(-t / 1.1)
    y += lp(rng.normal(size=n), 260) * np.exp(-t / 0.5) * 0.8
    y += hp(rng.normal(size=n), 3500) * np.exp(-t / 1.1) * 0.3  # Becken
    return y


# ---------- Stimmen ----------
def brass(m, dur, g=1.0, bright=3200, octave_double=False):
    f = hz(m)
    n = int((dur + 0.2) * SR)
    x = (saw(f * 0.9965, n) + saw(f, n) + saw(f * 1.0035, n)) / 3
    if octave_double:
        x = x + 0.5 * saw(f / 2, n)
    x = lp_sweep(x, lambda t: 500 + (bright - 500) * (1 - np.exp(-t / 0.07)))
    return x * adsr(dur, 0.04, 0.1, 0.85, 0.2)[:n] * g * (1 + 0.04 * np.sin(2 * np.pi * 5.2 * tt(n)))


def choir(m, dur, g=1.0, att=0.5, rel=0.8):
    f = hz(m)
    n = int((dur + rel) * SR)
    t = tt(n)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.6 * t)
    src = sum(2 * ((f * d * vib * t) % 1.0) - 1 for d in (0.996, 1.0, 1.004, 2.0)) / 4
    y = bp(src, 600, 800) * 1.0 + bp(src, 1000, 1250) * 0.7 + bp(src, 2400, 2800) * 0.35
    return y * adsr(dur, att, 0.2, 0.9, rel)[:n] * g * 2.2


def pad(m, dur, g=1.0, att=1.2, rel=1.5, fc=1400, detune=0.006, wave="saw"):
    f = hz(m)
    n = int((dur + rel) * SR)
    w = saw if wave == "saw" else sqr
    x = sum(w(f * (1 + d), n, rng.uniform()) for d in (-detune, -detune / 3, detune / 3, detune)) / 4
    return lp(x, fc) * adsr(dur, att, 0.3, 0.85, rel)[:n] * g


def pluck(m, g=1.0, fc=3600, dec=0.14, wave="saw"):
    f = hz(m)
    n = int(0.6 * SR)
    x = saw(f, n) if wave == "saw" else sqr(f, n, 0.35)
    x = lp(x, fc)
    return x * expdec(0.6, dec) * g


def bassnote(m, dur, g=1.0, fc=700):
    f = hz(m)
    n = int((dur + 0.08) * SR)
    x = lp(saw(f, n), fc) * 0.6 + sine(f, n) * 0.7
    return x * adsr(dur, 0.005, 0.1, 0.8, 0.08)[:n] * g


def bell(m, g=1.0, dec=2.2):
    f = hz(m)
    n = int(4.5 * SR)
    t = tt(n)
    idx = 3.0 * np.exp(-t / 0.9)
    return np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 3.5 * t)) * np.exp(-t / dec) * g * np.minimum(t / 0.002, 1)


def swell(dur, lo, hi, g=1.0):
    n = int(dur * SR)
    x = noise(dur)
    x = lp_sweep(x, lambda t: lo + (hi - lo) * (t / dur) ** 2)
    return x * (np.arange(n) / n) ** 2 * g


def duck_env(n, spb, depth, start=0.0):
    t = tt(n)
    ph = np.where(t >= start, (t - start) % spb, 1e9)
    return 1 - depth * np.exp(-ph / 0.16)


NOTES = {"C": 0, "C#": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}


def nm(name, octave):
    return 12 * (octave + 1) + NOTES[name]


# ---------- Shibas: sauberes Elektro ----------
def shibas():
    bpm = 110
    spb = 60 / bpm
    bars = 32
    L = int(bars * 4 * spb * SR)
    N = L + int(6 * SR)
    pad_b, arp_b, dr_b, bass_b, lead_b = (np.zeros((N, 2)) for _ in range(5))
    A = [(57, (60, 64, 67)), (53, (57, 60, 65)), (48, (55, 60, 64)), (55, (59, 62, 67))]  # Am F C G: Bass, Akkord
    B = [(53, (57, 60, 65)), (55, (59, 62, 67)), (57, (60, 64, 69)), (52, (59, 64, 67))]
    prog = [A, A, B, A]
    for sec in range(4):
        for k in range(8):
            bar = sec * 8 + k
            root, ch = prog[sec][k % 4]
            t0 = bar * 4 * spb
            for m in ch:
                put(pad_b, pad(m, 4 * spb, 0.16, 0.6, 0.8, 1800, 0.007), t0, 1.0, rng.uniform(-0.6, 0.6))
            put(pad_b, pad(root - 12, 4 * spb, 0.25, 0.3, 0.6, 600, 0.004), t0)
            # Arpeggio in 16teln, ab Takt 0 leise, mit Pingpong-Delay
            pat = [0, 1, 2, 3, 2, 1, 2, 3]
            ar = list(ch) + [ch[0] + 12]
            for i in range(16):
                m = ar[pat[i % 8]] + (12 if (i // 8) % 2 else 0) + 12
                put(arp_b, pluck(m, 0.2 if sec else 0.14, 3800, 0.13, "sqr"), t0 + i * spb / 4, 1.0, -0.4 if i % 2 else 0.4)
            if sec >= 1:
                for beat in range(4):
                    tb = t0 + beat * spb
                    put(dr_b, kick(), tb, 0.9)
                    if beat in (1, 3):
                        put(dr_b, clap(), tb, 0.5)
                        put(dr_b, snare(0.1, 200, 0.5), tb, 0.35)
                    put(dr_b, hat(0.03, 0.8), tb + spb / 2, 0.35, 0.3)
                    if k % 4 == 3 and beat == 3:
                        put(dr_b, hat(0.2, 1.0), tb + spb * 0.75, 0.3, -0.3)
                for i in range(8):
                    m = root - 12 if i % 4 != 3 else root - 12 + 7
                    put(bass_b, bassnote(m, spb * 0.45, 0.55), t0 + i * spb / 2 + (spb / 2 if False else 0))
            if sec in (2, 3):
                mel = [(0, 1.5, 76), (1.5, 0.5, 74), (2, 1, 72), (3, 1, 74)] if k % 2 == 0 else [(0, 2, 76), (2, 1, 72), (3, 1, 69)]
                for b0, d, m in mel:
                    put(lead_b, pad(m, d * spb, 0.2, 0.01, 0.15, 3500, 0.003, "sqr"), t0 + b0 * spb, 1.0, 0.1)
    d = int(0.75 * spb * SR)
    for bus in (arp_b,):
        for rep, gain in ((1, 0.38), (2, 0.2)):
            sh = d * rep
            bus[sh:, 0] += bus[:-sh, 1] * gain
            bus[sh:, 1] += bus[:-sh, 0] * gain
    duck = duck_env(N, spb, 0.55, 8 * 4 * spb)[:, None]
    mix = pad_b * duck + arp_b * (0.6 + 0.4 * duck) + lead_b + dr_b + bass_b
    mix = reverb(mix, 1.8, 0.22)
    write("shibas.ogg", master(fold(mix, L)))


# ---------- Katzen: dunkle Ambience ----------
def katzen():
    bpm = 66
    spb = 60 / bpm
    bars = 24
    L = int(bars * 4 * spb * SR)
    N = L + int(8 * SR)
    dr, pd, bl, hb, sw = (np.zeros((N, 2)) for _ in range(5))
    dur_total = N / SR
    # Drohne (D1/A1/D2): nur ueber die Schleifenlaenge, Frequenzen auf ganze Perioden gerundet -> nahtlos
    Ls = L / SR
    for m, g in ((26, 0.4), (33, 0.2), (38, 0.14)):
        f0 = max(1, round(hz(m) * Ls)) / Ls
        x = saw(f0, 2 * L) + sine(f0, 2 * L)
        x = lp_sweep(x, lambda t: 150 + 220 * (0.5 + 0.5 * np.sin(2 * np.pi * t / Ls * 2)), block=2048)[L:]  # zweiter Durchlauf: eingeschwungen
        dr[:L, 0] += x * g
        dr[:L, 1] += x * g
    chords = [(50, (50, 53, 57, 62)), (46, (46, 50, 53, 58)), (43, (43, 46, 50, 55)), (45, (45, 49, 52, 57))]  # Dm Bb Gm A
    for ci, (root, ch) in enumerate(chords):
        t0 = ci * 6 * 4 * spb
        d_ = 6 * 4 * spb
        for m in ch:
            put(pd, pad(m, d_ - 1.0, 0.2, 3.0, 3.5, 700 + 200 * ci % 3, 0.01), t0 - 1.0 if t0 > 0 else 0, 1.0, rng.uniform(-0.8, 0.8))
        put(sw, swell(5.0, 300, 3000, 0.25), t0 + d_ - 5.0 if ci < 3 else t0 + d_ - 5.0)
    # Glocken: spaerlich, d-Moll-Skala
    scale = [74, 77, 81, 84, 76, 72, 69]
    t = 3.0
    r2 = np.random.default_rng(9)
    while t < L / SR - 4:
        m = int(r2.choice(scale))
        put(bl, bell(m, 0.18), t, 1.0, r2.uniform(-0.9, 0.9))
        if r2.random() < 0.35:
            put(bl, bell(m - 12, 0.12, 3.0), t + spb * 0.5, 1.0, r2.uniform(-0.5, 0.5))
        t += spb * r2.choice([2, 3, 4, 5, 6])
    # Herzschlag (lub-dub) ab Takt 6, leise
    for bar in range(6, bars):
        t0 = bar * 4 * spb
        g = 0.5 if bar < 12 else 0.75
        put(hb, kick(0.12, 90, 38), t0, g)
        put(hb, kick(0.1, 80, 36), t0 + spb * 0.55, g * 0.6)
    # Fluesternder Hauch (gefiltertes Rauschen, atmend)
    for bar in range(4, bars, 2):
        t0 = bar * 4 * spb
        d_ = 3.2
        x = bp(noise(d_), 3500, 7500) * (np.sin(np.pi * np.arange(int(d_ * SR)) / (d_ * SR)) ** 2) * 0.12
        put(sw, x, t0 + 0.5, 1.0, -0.7 if (bar // 2) % 2 else 0.7)
    mix = dr * 0.9 + pd + bl + hb * 0.8 + sw
    mix = reverb(mix, 4.0, 0.42, 0.03, 4500)
    write("katzen.ogg", master(fold(mix, L)))


# ---------- Baeren: sowjetischer Marsch ----------
def baeren():
    bpm = 96
    spb = 60 / bpm
    bars = 32
    L = int(bars * 4 * spb * SR)
    N = L + int(5 * SR)
    dm, bs, ch_b, br, st = (np.zeros((N, 2)) for _ in range(5))
    # Akkorde je Takt: (Bass, Akkordtoene)
    Dm = (38, (50, 53, 57)); Gm = (43, (55, 58, 62)); A = (45, (57, 61, 64)); Bb = (46, (58, 62, 65))
    prog = [Dm, Gm, Dm, A, Bb, Gm, A, Dm]
    melody = [
        [(0, 1, 62), (1, 1, 65), (2, 1, 69), (3, 1, 74)],
        [(0, 1.5, 74), (1.5, .5, 72), (2, 1, 70), (3, 1, 67)],
        [(0, 1, 69), (1, 1, 65), (2, 1, 69), (3, 1, 74)],
        [(0, 1, 73), (1, 1, 76), (2, 2, 69)],
        [(0, 1, 74), (1, 1, 77), (2, 1, 74), (3, 1, 70)],
        [(0, 1, 67), (1, 1, 70), (2, 1, 74), (3, 1, 79)],
        [(0, 1, 76), (1, 1, 73), (2, 1, 76), (3, 1, 69)],
        [(0, 2, 74), (2, 1, 69), (3, 1, 62)],
    ]
    for bar in range(bars):
        sec = bar // 8
        k = bar % 8
        root, ch = prog[k]
        t0 = bar * 4 * spb
        # Pauke/Pauken auf 1 und 3, Marschtrommel
        put(dm, timpani(hz(root)), t0, 0.9)
        put(dm, timpani(hz(root)), t0 + 2 * spb, 0.75)
        for b in (1, 3):
            put(dm, snare(0.09, 210, 0.9), t0 + b * spb, 0.5)
        put(dm, snare(0.07, 210, 0.7), t0 + 3.5 * spb, 0.3)
        put(dm, snare(0.07, 210, 0.7), t0 + 3.75 * spb, 0.35)
        if k == 7:  # Wirbel am Ende der Phrase
            for i in range(8):
                put(dm, snare(0.06, 210, 0.7), t0 + (3 + i / 8) * spb, 0.15 + 0.03 * i)
        # Tuba: Grundton auf 1 und 3, Quinte auf 2 und 4 (oom-pah)
        for b, m in ((0, root), (1, root + 7), (2, root), (3, root + 7)):
            put(bs, bassnote(m, spb * 0.8, 0.8, 500), t0 + b * spb)
        # tiefes Blech auf den Nachschlaegen
        if sec >= 0:
            for b in (1, 3):
                for m in ch:
                    put(ch_b, brass(m - 12, spb * 0.55, 0.12, 1600), t0 + b * spb, 1.0, rng.uniform(-0.4, 0.4))
        if sec >= 1:
            for m in ch:
                put(ch_b, choir(m, 4 * spb - 0.2, 0.17 if sec < 3 else 0.22), t0, 1.0, rng.uniform(-0.7, 0.7))
            put(ch_b, choir(root + 12, 4 * spb - 0.2, 0.16), t0)
        if sec >= 1:
            for b0, d, m in melody[k]:
                put(br, brass(m, d * spb * 0.95, 0.26, 3400, octave_double=(sec == 3)), t0 + b0 * spb, 1.0, 0.0)
                if sec == 3:
                    put(br, brass(m + 12, d * spb * 0.95, 0.13, 3800), t0 + b0 * spb, 1.0, 0.2)
        if sec == 0 and k in (6, 7):  # Auftakt-Fanfare kuendigt das Thema an
            for b0, d, m in melody[k]:
                put(br, brass(m, d * spb * 0.9, 0.2, 3000), t0 + b0 * spb, 1.0, 0.0)
        if sec == 3 and k == 0:
            put(dm, boom(2.5), t0, 0.35)
    mix = dm * 0.9 + bs + ch_b + br
    mix = reverb(mix, 2.4, 0.26, 0.025, 5500)
    write("baeren.ogg", master(fold(mix, L)))


# ---------- Intro ----------
def intro():
    bpm = 96
    spb = 60 / bpm
    bars = 17
    T = bars * 4 * spb
    N = int((T + 6) * SR)
    dr, pd, ar, br, fx = (np.zeros((N, 2)) for _ in range(5))
    bar_t = lambda b: b * 4 * spb
    # Takt 0-3: Katzen-Dunkel: Drohne, Anschwellen, Glocken
    drone = (saw(hz(26) * 0.998, N) + saw(hz(26) * 1.002, N)) / 2 + sine(hz(26), N)
    drone = lp_sweep(drone, lambda t: 120 + 500 * min(t / bar_t(4), 1), block=2048) * 0.5
    drone *= np.minimum(tt(N) / 3.0, 1) * np.clip(1 - np.maximum(tt(N) - (T + 1), 0) / 4, 0, 1)
    pd[:, 0] += drone
    pd[:, 1] += drone
    put(fx, swell(bar_t(4) - 0.2, 200, 5000, 0.8), 0.0)
    for tb, m in ((1.0, 74), (4.5, 77), (6.2, 81), (8.0, 69)):
        put(fx, bell(m, 0.22), tb, 1.0, -0.6 if m > 75 else 0.5)
    for m in (50, 53, 57):
        put(pd, pad(m, bar_t(4) - 1, 0.18, 4.0, 1.0, 900), 0.0, 1.0, rng.uniform(-0.6, 0.6))
    # Takt 4: Einschlag
    put(fx, boom(3.5), bar_t(4), 0.95)
    # Takt 4-7: Baeren-Marsch + Thema (Blech, Chor)
    prog = [(38, (50, 53, 57)), (43, (55, 58, 62)), (38, (50, 53, 57)), (45, (57, 61, 64))] * 4
    mel = [
        [(0, 1, 62), (1, 1, 65), (2, 1, 69), (3, 1, 74)],
        [(0, 1.5, 74), (1.5, .5, 72), (2, 1, 70), (3, 1, 67)],
        [(0, 1, 69), (1, 1, 65), (2, 1, 69), (3, 1, 74)],
        [(0, 1, 73), (1, 1, 76), (2, 2, 69)],
    ]
    for bar in range(4, 16):
        root, ch = prog[bar - 4]
        t0 = bar_t(bar)
        last = bar == 15
        put(dr, timpani(hz(root)), t0, 0.9)
        put(dr, timpani(hz(root)), t0 + 2 * spb, 0.7)
        for b in (1, 3):
            put(dr, snare(0.09, 210, 0.9), t0 + b * spb, 0.5)
        for m in ch:
            put(pd, choir(m, 4 * spb - 0.2, 0.18 if bar < 12 else 0.26), t0, 1.0, rng.uniform(-0.7, 0.7))
        for b, m in ((0, root), (2, root)):
            put(pd, bassnote(m, spb * 1.6, 0.8, 500), t0 + b * spb)
        for b0, d, m in mel[(bar - 4) % 4]:
            put(br, brass(m, d * spb * 0.95, 0.3 if bar < 12 else 0.38, 3400, octave_double=bar >= 12), t0 + b0 * spb, 1.0, 0.0)
            if bar >= 12:
                put(br, brass(m + 12, d * spb * 0.95, 0.17, 3800), t0 + b0 * spb, 1.0, 0.2)
        # Takt 8-15: Shiba-Elektro mit Arpeggio und Four-on-the-floor
        if bar >= 8:
            ar_notes = list(ch) + [ch[0] + 12]
            pat = [0, 1, 2, 3, 2, 1, 2, 3]
            for i in range(16):
                m = ar_notes[pat[i % 8]] + 12 + (12 if (i // 8) % 2 else 0)
                put(ar, pluck(m, 0.16, 3800, 0.12, "sqr"), t0 + i * spb / 4, 1.0, -0.5 if i % 2 else 0.5)
            for beat in range(4):
                put(dr, kick(), t0 + beat * spb, 0.85)
                put(dr, hat(0.03, 0.8), t0 + (beat + 0.5) * spb, 0.3, 0.3)
        if bar == 15:
            for i in range(16):
                put(dr, snare(0.06, 210, 0.7), t0 + (3 + i / 16) * spb * 1.0, 0.1 + 0.03 * i)
    # Takt 16: Finale: grosser Akkord D-Dur/d-Moll (leer: D, A, D) mit Einschlag und langem Ausklang
    t0 = bar_t(16)
    put(fx, boom(4.5), t0, 1.0)
    put(dr, timpani(hz(38)), t0, 1.0)
    for m in (38, 45, 50, 57, 62):
        put(br, brass(m, 3.6, 0.28, 3000, octave_double=True), t0, 1.0, rng.uniform(-0.4, 0.4))
    for m in (50, 57, 62, 66, 69):
        put(pd, choir(m, 3.4, 0.24, 0.2, 2.0), t0, 1.0, rng.uniform(-0.7, 0.7))
    put(fx, bell(86, 0.2, 3.5), t0 + 0.2, 1.0, 0.5)
    put(fx, bell(81, 0.18, 3.5), t0 + 0.35, 1.0, -0.5)
    mix = dr * 0.9 + pd + ar * 0.8 + br + fx
    # Ausblenden
    fade = np.clip((T + 5.5 - tt(len(mix) + 0)[: len(mix)] if False else 1), 0, 1)
    mix = reverb(mix, 3.2, 0.34, 0.03, 5000)
    end = int((T + 5.2) * SR)
    mix = mix[:end]
    mix[-int(1.6 * SR):] *= np.linspace(1, 0, int(1.6 * SR))[:, None] ** 1.5
    write("intro.ogg", master(mix))


if __name__ == "__main__":
    which = sys.argv[1:] or ["intro", "shibas", "katzen", "baeren"]
    for w in which:
        {"intro": intro, "shibas": shibas, "katzen": katzen, "baeren": baeren}[w]()
