"""Freigestellte Natur-Bilder (BiRefNet, comfyui/cut_one.py) -> 512er Sprites fuer NatureScatter.
  python make_nature_sprites.py <cut-ordner> <zielordner>
Erwartet <cut-ordner>/one_nat_<sprite>_00001_.png fuer jeden Eintrag in SPRITES.
Fusspunkt (unterster sichtbarer Pixel) liegt bei FOOT_FRAC der Bildhoehe, Objekt mittig."""
import sys, os
import numpy as np
from PIL import Image, ImageEnhance

SPRITES = ["dead_a", "dead_b", "burnt_a", "burnt_b", "pine_a", "pine_b", "oak_a", "bush_a", "bush_b", "rock_a", "rock_b", "rock_c", "wreck_a"]
SIZE = 512
FOOT_FRAC = 0.93
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for name in SPRITES:
    im = Image.open(f"{src}/one_nat_{name}_00001_.png").convert("RGBA")
    a = np.asarray(im)[..., 3]
    # harte Alphamaske gegen Halo, leichte Kante
    ys, xs = np.where(a > 40)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    obj = im.crop(box)
    w, h = obj.size
    k = min(SIZE * 0.92 / w, SIZE * FOOT_FRAC * 0.97 / h)
    obj = obj.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
    # etwas entsaettigen und abdunkeln (Dark-Reign-Stimmung)
    rgb = ImageEnhance.Color(obj.convert("RGB")).enhance(0.75)
    rgb = ImageEnhance.Brightness(rgb).enhance(0.85)
    obj = Image.merge("RGBA", (*rgb.split(), obj.split()[3]))
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(obj, ((SIZE - obj.width) // 2, int(SIZE * FOOT_FRAC) - obj.height))
    canvas.save(f"{dst}/{name}.png")
    print("ok", name)
