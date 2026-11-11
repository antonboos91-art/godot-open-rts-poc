"""Macht die Krea-Bodenbilder kachelbar und erzeugt Normal-Maps.
  python make_ground_textures.py <quellordner> <zielordner>
Quelle: ground_<art>_<nr>_.png (siehe AUSWAHL), Ziel: <art>_albedo.jpg, <art>_normal.png"""
import sys, os
import numpy as np
from PIL import Image

AUSWAHL = {"grass": 1, "drygrass": 1, "dirt": 2, "rock": 2, "sand": 1, "mud": 2}
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)


def seamless(a):
    # Halb verschobene Kopie ueber die Kanten blenden: Mitte bleibt original, Raender kommen aus der Kopie
    h, w = a.shape[:2]
    shifted = np.roll(np.roll(a, h // 2, 0), w // 2, 1)
    y = np.abs(np.linspace(-1, 1, h))[:, None]
    x = np.abs(np.linspace(-1, 1, w))[None, :]
    m = np.clip((np.maximum(x, y) - 0.55) / 0.4, 0, 1)
    m = (m * m * (3 - 2 * m))[..., None]
    return a * (1 - m) + shifted * m


def normal_map(gray, strength=3.0):
    gx = (np.roll(gray, -1, 1) - np.roll(gray, 1, 1)) * strength
    gy = (np.roll(gray, -1, 0) - np.roll(gray, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(gray)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


for art, nr in AUSWAHL.items():
    img = Image.open(f"{src}/ground_{art}_0000{nr}_.png").convert("RGB")
    a = np.asarray(img, dtype=np.float32) / 255.0
    a = seamless(a)
    # Helligkeit ausgleichen (grosse Helligkeitsflecken stoeren beim Kacheln)
    blur = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((16, 16), Image.BILINEAR).resize(img.size, Image.BILINEAR), dtype=np.float32) / 255.0
    a = np.clip(a - blur + blur.mean(axis=(0, 1)), 0, 1)
    Image.fromarray((a * 255).astype(np.uint8)).save(f"{dst}/{art}_albedo.jpg", quality=90)
    gray = a.mean(axis=2)
    Image.fromarray(normal_map(gray)).save(f"{dst}/{art}_normal.png")
    print("ok", art)
