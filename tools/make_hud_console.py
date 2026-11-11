"""KI-Konsole (gen_hud_console.py) ins Spiel: Hintergrund freistellen, Bildschirm-Ausschnitte finden.
  python tools/make_hud_console.py <bild.png> <volk>
-> assets/ui/hud/console_<volk>.png (Aussenbereich transparent) + console_<volk>.json mit den Rechtecken
   minimap, selection, portrait, command (x0, y0, x1, y1 in Bildpixeln, Ursprung oben links)."""
import sys, json
import numpy as np
from PIL import Image
from scipy import ndimage

src, fac = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
a = np.asarray(im, dtype=np.float32) / 255.0
lum = a.max(axis=2)
dark = lum < 0.07
h, w = dark.shape
# kleine Luecken im Rahmen schliessen: dunkle Flaeche schrumpfen, dann Bildschirme suchen
er = ndimage.binary_erosion(dark, iterations=7, border_value=1)
lab, n = ndimage.label(er)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
screens = []
screen_mask = np.zeros_like(dark)
for i in range(1, n + 1):
    if i in border:
        continue
    comp = lab == i
    if comp.sum() < 3000:
        continue
    grown = ndimage.binary_dilation(comp, iterations=8) & dark
    screen_mask |= grown
    ys, xs = np.where(grown)
    screens.append((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
outside = dark & ~screen_mask
lab2, _ = ndimage.label(outside)
edge_ids = set(np.unique(np.concatenate([lab2[0], lab2[-1], lab2[:, 0], lab2[:, -1]]))) - {0}
outside = np.isin(lab2, list(edge_ids))
alpha = 1.0 - ndimage.uniform_filter(outside.astype(np.float32), size=3)
screens.sort(key=lambda r: r[0])
assert len(screens) >= 4, f"nur {len(screens)} Bildschirme gefunden: {screens}"
# die vier groessten in x-Reihenfolge
screens = sorted(sorted(screens, key=lambda r: -(r[2] - r[0]) * (r[3] - r[1]))[:4], key=lambda r: r[0])
names = ["minimap", "selection", "portrait", "command"]
rgba = np.dstack([a, alpha])
Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA").save(f"assets/ui/hud/console_{fac}.png")
json.dump({"width": w, "height": h, "rects": dict(zip(names, screens))}, open(f"assets/ui/hud/console_{fac}.json", "w"), indent=1)
print(fac, dict(zip(names, screens)))
