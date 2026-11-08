import json, sys
from PIL import Image
base = sys.argv[1]; out = sys.argv[2]
meta = json.load(open(base + ".json"))
sheet = Image.open(base + ".png").convert("RGBA")
F = meta["frame"]
def frame(row, col):
    im = sheet.crop((col * F, row * F, col * F + F, row * F + F))
    bg = Image.new("RGBA", im.size, (92, 110, 60, 255))
    bg.alpha_composite(im)
    return bg.resize((F * 2, F * 2), Image.LANCZOS).convert("P", palette=Image.ADAPTIVE)
for clip, fps, rows in (("walk", 11, [0, 2, 5]), ("shoot", 8, [0, 2]), ("die", 8, [0, 1])):
    s, n = meta["clips"][clip]
    frames = []
    for r in rows:
        reps = 3 if clip == "walk" else 2
        for _ in range(reps):
            frames += [frame(r, s + i) for i in range(n)]
        if clip == "die":
            frames += [frame(r, s + n - 1)] * 8
    frames[0].save(f"{out}/shiba_trooper_{clip}.gif", save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, disposal=2)
    print("ok", clip, len(frames))
# alle 8 Richtungen laufend in einem Bild
strip = []
s, n = meta["clips"]["walk"]
for i in range(n * 3):
    canvas = Image.new("RGBA", (F * 8, F), (92, 110, 60, 255))
    for r in range(8):
        im = sheet.crop(((s + i % n) * F, r * F, (s + i % n) * F + F, r * F + F))
        canvas.alpha_composite(im, (r * F, 0))
    strip.append(canvas.convert("P", palette=Image.ADAPTIVE))
strip[0].save(f"{out}/shiba_trooper_walk_8dirs.gif", save_all=True, append_images=strip[1:], duration=90, loop=0)
print("ok 8dirs")
