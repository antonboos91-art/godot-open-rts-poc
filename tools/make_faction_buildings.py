"""Freigestellte Krea-Gebaeudebilder (out/concepts/cut_fb/<volk>_<rolle>_00001_.png) -> assets/sprites/units/<volk>_<rolle>_anim.png (384 px, unten buendig)."""
import glob, os, sys
from PIL import Image
SRC = sys.argv[1] if len(sys.argv) > 1 else "out/concepts/cut_fb"
OUT = "game/assets/sprites/units"; SIZE = 384
for d in sorted(glob.glob(SRC + "/*_00001_.png")):
    v = os.path.basename(d).rsplit("_0000", 1)[0]
    im = Image.open(d).convert("RGBA")
    box = im.getchannel("A").point(lambda x: 255 if x > 20 else 0).getbbox()
    im = im.crop(box); w, h = im.size; s = max(w, h)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0)); sq.paste(im, ((s - w) // 2, s - h))
    sq.resize((SIZE, SIZE), Image.LANCZOS).save(f"{OUT}/{v}_anim.png"); print(v, (w, h))
