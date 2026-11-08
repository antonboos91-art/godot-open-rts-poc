"""Setzt die Einzelbilder aus render_vehicle.py zu Spritesheets zusammen.
  python tools/make_vehicle_sheets.py <frames-ordner> <ziel-basis> [scale]
Ergebnis: <ziel>_hull.png (Zeilen = Kettenframes), <ziel>_turret.png, <ziel>.json"""
import glob, json, os, sys
from PIL import Image


def _overrides(dst):
    p = os.path.join(os.path.dirname(__file__), "vehicle_overrides.json")
    return json.load(open(p)).get(os.path.basename(dst), {}) if os.path.exists(p) else {}

src, dst = sys.argv[1], sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.8
hull = sorted(glob.glob(src + "/hull_*.png"))
tur = sorted(glob.glob(src + "/turret_*.png"))
frames = sorted({os.path.basename(f).split("_")[1] for f in hull})
dirs = len(tur)
size = Image.open(tur[0]).size[0]
sheet = Image.new("RGBA", (size * dirs, size * len(frames)))
for f in hull:
    _, fr, d = os.path.basename(f)[:-4].split("_")
    sheet.paste(Image.open(f), (int(d) * size, frames.index(fr) * size))
sheet.save(dst + "_hull.png")
ts = Image.new("RGBA", (size * dirs, size))
for f in tur:
    d = int(os.path.basename(f)[:-4].split("_")[1])
    ts.paste(Image.open(f), (d * size, 0))
ts.save(dst + "_turret.png")
json.dump({"columns": dirs, "rows": len(frames), "ortho": 3.6, "scale": scale, "target_z": 0.45,
           "track_pitch": 0.06, "muzzle_z": 0.77, "muzzle_dist": 1.85, "recoil": 0.18,
           "mirror": True, **_overrides(dst)}, open(dst + ".json", "w"), indent=1)
print("ok", sheet.size, ts.size)
