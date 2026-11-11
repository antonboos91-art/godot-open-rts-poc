"""Portraets und Ressourcen-Symbole aus den Krea-Ausgaben ins Spiel uebernehmen.
  python tools/make_hud_art.py <comfy-output/clean>
Portraets -> assets/ui/portraits/<volk>_<einheit>.jpg (320x376), Symbole -> assets/ui/hud/<name>.png (64x64, Alpha aus Helligkeit)."""
import sys, os, glob, re
import numpy as np
from PIL import Image, ImageEnhance

src = sys.argv[1]
os.makedirs("assets/ui/portraits", exist_ok=True)
os.makedirs("assets/ui/hud", exist_ok=True)
for f in glob.glob(f"{src}/portrait_*_00001_.png"):
    name = re.sub(r"^portrait_|_00001_\.png$", "", os.path.basename(f))
    im = Image.open(f).convert("RGB")
    im = ImageEnhance.Contrast(im).enhance(1.08)
    im.resize((320, 376), Image.LANCZOS).save(f"assets/ui/portraits/{name}.jpg", quality=88)
    print("portrait", name)
for key in ["scrap", "crystal", "power", "supply"]:
    fs = sorted(glob.glob(f"{src}/hudicon_{key}_*.png"))
    if not fs:
        continue
    im = Image.open(fs[0]).convert("RGB")
    a = np.asarray(im, dtype=np.float32) / 255.0
    lum = a.max(axis=2)
    alpha = np.clip((lum - 0.06) / 0.5, 0, 1)
    ys, xs = np.where(alpha > 0.1)
    if len(xs):
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        side = max(x1 - x0, y1 - y0) + 8
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        box = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    else:
        box = (0, 0, im.width, im.height)
    rgba = np.dstack([a / np.maximum(lum[..., None], 1e-3) * np.minimum(lum[..., None] * 1.6, 1.0), alpha])
    out = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").crop(box).resize((64, 64), Image.LANCZOS)
    out.save(f"assets/ui/hud/{key}.png")
    print("icon", key)
