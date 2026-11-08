import json, sys
from PIL import Image
base = sys.argv[1]; meta = json.load(open(base + ".json")); sh = Image.open(base + ".png").convert("RGBA"); F = meta["frame"]
cl = meta["clips"]; cols = [cl["idle"][0], cl["walk"][0] + 2, cl["shoot"][0] + 2, cl["die"][0] + cl["die"][1] - 1]
s = 150
out = Image.new("RGBA", (8 * s, len(cols) * s), (92, 110, 60, 255))
for r in range(8):
    for j, c in enumerate(cols):
        im = sh.crop((c * F, r * F, c * F + F, r * F + F)).resize((s, s))
        out.alpha_composite(im, (r * s, j * s))
out.save(sys.argv[2])
