"""Rigging-Prototyp: TRELLIS-Modell in T-Pose -> Humanoiden-Armature mit automatischen Gewichten,
Lauf-/Schuss-/Sterbe-Zyklen, Render in 8 Richtungen.
  blender -b -P blender/rig_trooper.py -- --model out/3d/xyz.glb --out out/rig/trooper --size 256 [--preview]
Proportionen stammen aus dem T-Pose-Bild (Anteile von Koerperhoehe/Halbbreite).
"""
import bpy, sys, math, os
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"--model": "", "--out": "out/rig/trooper", "--size": "256", "--dirs": "8", "--weapon": "", "--weapon-len": "0.8"}
for i, v in enumerate(argv):
    if v in opt and i + 1 < len(argv):
        opt[v] = argv[i + 1]
PREVIEW = "--preview" in argv
WEAPON_FLIP = "--weapon-flip" in argv
SIZE = int(opt["--size"])
DIRS = int(opt["--dirs"])
OUT = opt["--out"]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["--model"])
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(False)
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def bbox(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


lo, hi = bbox(body)
dim = hi - lo
print("BBOX", tuple(round(v, 3) for v in dim))
# Hoehe auf 1.8 m skalieren, Fuesse auf z=0, Mitte auf x=y=0
scale = 1.8 / dim.z
body.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
lo, hi = bbox(body)
body.location = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
lo, hi = bbox(body)
H = hi.z
HALF = (hi.x - lo.x) / 2
print("HEIGHT", H, "HALFWIDTH", HALF)

# ---------- Skelett ----------
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm_obj = bpy.context.active_object
arm_obj.name = "Rig"
arm = arm_obj.data
arm.edit_bones.remove(arm.edit_bones[0])


def bone(name, head, tail, parent=None):
    b = arm.edit_bones.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    if parent:
        b.parent = arm.edit_bones[parent]
    return b


def P(x_frac, z_frac):
    # x_frac: Anteil der Halbbreite (rechts positiv), z_frac: Anteil der Hoehe
    return (x_frac * HALF, 0.0, z_frac * H)


hip = 0.52
bone("hips", P(0, hip), P(0, hip + 0.08))
bone("spine", P(0, hip + 0.08), P(0, 0.70), "hips")
bone("neck", P(0, 0.76), P(0, 0.83), "spine")
bone("head", P(0, 0.83), P(0, 1.0), "neck")
for s, sign in (("R", 1), ("L", -1)):
    bone(f"shoulder.{s}", P(sign * 0.06, 0.74), P(sign * 0.29, 0.74), "spine")
    bone(f"upper_arm.{s}", P(sign * 0.29, 0.74), P(sign * 0.58, 0.74), f"shoulder.{s}")
    bone(f"forearm.{s}", P(sign * 0.58, 0.74), P(sign * 0.82, 0.74), f"upper_arm.{s}")
    bone(f"hand.{s}", P(sign * 0.82, 0.74), P(sign * 0.97, 0.74), f"forearm.{s}")
    bone(f"thigh.{s}", P(sign * 0.15, hip), P(sign * 0.25, 0.28), "hips")
    bone(f"shin.{s}", P(sign * 0.25, 0.28), P(sign * 0.33, 0.065), f"thigh.{s}")
    bone(f"foot.{s}", P(sign * 0.33, 0.065), P(sign * 0.33, 0.01), f"shin.{s}")
    arm.edit_bones[f"foot.{s}"].tail = Vector((sign * 0.33 * HALF, -0.25, 0.02))
bpy.ops.object.mode_set(mode="OBJECT")

# ---------- Skinning ----------
for o in bpy.context.scene.objects:
    o.select_set(False)
body.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.parent_set(type="ARMATURE_NAME")  # leere Gruppen je Knochen


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


# Eigene Gewichte: jeder Vertex an die zwei naechsten Knochen, weich ueberblendet.
# (Bone-Heat scheitert bei TRELLIS-Meshes oft still, weil sie nicht wasserdicht sind.)
segments = [(b.name, arm_obj.matrix_world @ b.head_local, arm_obj.matrix_world @ b.tail_local) for b in arm.bones]
groups = {n: body.vertex_groups.get(n) or body.vertex_groups.new(name=n) for n, _, _ in segments}
for v in body.data.vertices:
    p = body.matrix_world @ v.co
    ds = sorted(((seg_dist(p, a, b), n) for n, a, b in segments))
    # Kopf: alles ueber der Schulterlinie nahe der Koerpermitte gehoert zum Kopf (nicht zu den Armen)
    if p.z > 0.74 * H and abs(p.x) < 0.27 * HALF:
        groups["head" if p.z > 0.79 * H else "neck"].add([v.index], 1.0, "REPLACE")
        continue
    (d0, n0), (d1, n1) = ds[0], ds[1]
    # Arme/Beine: nur innerhalb derselben Kette mischen, sonst harte Zuordnung
    same_chain = n0.split(".")[-1] == n1.split(".")[-1] or "." not in n0 or "." not in n1
    if same_chain and d1 < d0 * 1.6:
        w0 = d1 / (d0 + d1)
        groups[n0].add([v.index], w0, "REPLACE")
        groups[n1].add([v.index], 1.0 - w0, "REPLACE")
    else:
        groups[n0].add([v.index], 1.0, "REPLACE")
print("SKIN custom weights", len(body.data.vertices), "verts")

# ---------- Waffe an die rechte Hand ----------
if opt["--weapon"]:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=opt["--weapon"])
    wmeshes = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in wmeshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = wmeshes[0]
    if len(wmeshes) > 1:
        bpy.ops.object.join()
    gun = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    glo, ghi = bbox(gun)
    gdim = ghi - glo
    # Hauptachse (PCA der Vertices) = Lauf -> auf +X legen (Richtung des rechten Arms in der T-Pose)
    import numpy as np
    co = np.array([tuple(gun.matrix_world @ v.co) for v in gun.data.vertices])
    co -= co.mean(axis=0)
    w, vecs = np.linalg.eigh(np.cov(co.T))
    main = Vector(tuple(vecs[:, int(np.argmax(w))]))
    gun.rotation_mode = "QUATERNION"
    gun.rotation_quaternion = main.rotation_difference(Vector((1, 0, 0)))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    gun.rotation_mode = "XYZ"
    gun.rotation_euler = Euler((0, 0, 0), "XYZ")
    if WEAPON_FLIP:
        gun.rotation_euler.z += math.pi
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    glo, ghi = bbox(gun)
    s = float(opt["--weapon-len"]) / max(ghi.x - glo.x, 1e-6)
    gun.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    glo, ghi = bbox(gun)
    hand = arm.bones["hand.R"]
    grip = arm_obj.matrix_world @ hand.head_local
    # Griff etwa bei 40 % der Laenge in die Hand
    gun.location = Vector((grip.x - (glo.x + (ghi.x - glo.x) * 0.4), grip.y - (glo.y + ghi.y) / 2, grip.z - (glo.z + ghi.z) / 2 - 0.04))
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    gun.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    arm.bones.active = hand
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)
    print("WEAPON attached", tuple(round(v, 2) for v in gdim))

# ---------- Animationen (Pose-Rotationen) ----------
pose = arm_obj.pose
for pb in pose.bones:
    pb.rotation_mode = "XYZ"


def setrot(name, x=0.0, y=0.0, z=0.0, frame=1):
    pb = pose.bones[name]
    pb.rotation_euler = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ")
    pass


def reset_all(frame):
    for pb in pose.bones:
        pb.rotation_euler = Euler((0, 0, 0), "XYZ")
        pass


ARM_DOWN = 68  # Arme aus der T-Pose nach unten


def aim(name, direction):
    """Richtet einen Knochen in Armature-Richtung `direction` aus (Vorne = -Y, Oben = +Z).
    Beruecksichtigt die bereits gesetzte Pose des Elternknochens."""
    bpy.context.view_layer.update()
    pb = pose.bones[name]
    rest = pb.bone.matrix_local
    if pb.parent is not None:
        base = pb.parent.matrix @ (pb.parent.bone.matrix_local.inverted() @ rest)
    else:
        base = rest
    local_dir = base.to_3x3().inverted() @ Vector(direction).normalized()
    q = Vector((0, 1, 0)).rotation_difference(local_dir)
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = q


def arms(r_upper, r_fore, l_upper, l_fore):
    aim("upper_arm.R", r_upper)
    aim("forearm.R", r_fore)
    aim("upper_arm.L", l_upper)
    aim("forearm.L", l_fore)


def base_pose(frame, bob=0.0):
    # Arme nach unten, Ellbogen leicht gebeugt
    arms((0.15, 0, -1), (0.1, -0.25, -1), (-0.15, 0, -1), (-0.1, -0.25, -1))


def walk_frame(t, frame):
    """t in 0..1 Laufzyklus. Beine schwingen um die X-Achse (vor/zurueck), Arme gegenlaeufig."""
    s = math.sin(t * 2 * math.pi)
    c = math.cos(t * 2 * math.pi)
    for sname, sign, ph in (("R", 1, 1), ("L", -1, -1)):
        setrot(f"thigh.{sname}", -28 * s * ph, 0, 0, frame)
        knee = max(0.0, c * ph * 55) if True else 0
        setrot(f"shin.{sname}", 8 + (35 * max(0.0, math.sin(t * 2 * math.pi + (0 if ph > 0 else math.pi) + 1.6))), 0, 0, frame)
        setrot(f"foot.{sname}", -6 * s * ph, 0, 0, frame)
    sw = 0.45 * s
    arms((0.15, sw, -1), (0.1, sw - 0.35, -1), (-0.15, -sw, -1), (-0.1, -sw - 0.35, -1))
    setrot("hips", 0, 0, 4 * s, frame)
    setrot("spine", 0, 0, -4 * s, frame)
    setrot("head", 0, 0, 0, frame)


def shoot_frame(t, frame):
    """Schuss: Arme heben nach vorne (-Y), kurzer Rueckstoss bei t~0.3."""
    recoil = max(0.0, 1.0 - abs(t - 0.3) * 8) * 8
    kick = recoil / 40.0
    arms((0.35, -1, -0.25 + kick), (-0.05, -1, 0.0 + kick), (-0.2, -1, -0.45), (0.5, -1, -0.05))
    setrot("spine", -recoil * 0.8, 0, 6, frame)
    setrot("head", 0, 0, -6, frame)
    setrot("thigh.R", 10, 0, 0, frame)
    setrot("thigh.L", -14, 0, 0, frame)


def die_frame(t, frame):
    """Sterben: nach hinten kippen und liegen bleiben."""
    k = min(1.0, t * 1.4)
    ease = k * k
    arm_obj.rotation_euler = Euler((math.radians(-82 * ease), 0, 0), "XYZ")
    arm_obj.location = Vector((0, -0.85 * ease, 0.0))
    arms((0.3 + ease, 0, -1 + ease), (0.3 + ease, 0, -1 + ease), (-0.3 - ease, 0, -1 + ease), (-0.3 - ease, 0, -1 + ease))
    setrot("head", -18 * ease, 0, 0, frame)
    setrot("thigh.R", -12 * ease, 0, 0, frame)
    setrot("thigh.L", 20 * ease, 0, 0, frame)


# ---------- Rendern ----------
scn = bpy.context.scene
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 3.3
cam = bpy.data.objects.new("cam", cam_d)
scn.collection.objects.link(cam)
pitch = math.radians(35)
target = Vector((0, 0, 0.85))
d = 10
sd = bpy.data.lights.new("sun", "SUN")
sd.energy = 4.0
sun = bpy.data.objects.new("sun", sd)
sun.rotation_euler = (math.radians(50), 0, math.radians(35))
scn.collection.objects.link(sun)
scn.world = bpy.data.worlds.new("w")
scn.world.color = (0.55, 0.58, 0.62)
scn.view_settings.view_transform = "Standard"
scn.render.engine = "BLENDER_EEVEE_NEXT" if bpy.app.version >= (4, 2) else "BLENDER_EEVEE"
scn.render.film_transparent = True
scn.render.resolution_x = scn.render.resolution_y = SIZE
scn.render.image_settings.file_format = "PNG"
scn.render.image_settings.color_mode = "RGBA"
scn.camera = cam
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)


def place_cam(yaw_deg):
    yaw = math.radians(yaw_deg)
    cam.location = target + Vector((math.sin(yaw) * math.cos(pitch) * -d, math.cos(yaw) * math.cos(pitch) * -d, math.sin(pitch) * d))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def render(path):
    scn.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)


CLIPS = {"walk": (walk_frame, 8, True), "shoot": (shoot_frame, 4, False), "die": (die_frame, 6, False)}


def apply_clip(clip, i, n, loop):
    # Pose zuruecksetzen, dann Basis + Clip
    arm_obj.rotation_euler = Euler((0, 0, 0), "XYZ")
    arm_obj.location = Vector((0, 0, 0))
    for pb in pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = Euler((0, 0, 0), "XYZ")
        pb.rotation_quaternion = (1, 0, 0, 0)
    bpy.context.view_layer.update()
    base_pose(1)
    t = i / n if loop else (i / (n - 1) if n > 1 else 0.0)
    CLIPS[clip][0](t, 1)
    bpy.context.view_layer.update()


if PREVIEW:
    # eine Vorschau: T-Pose + 4 Laufframes aus Richtung 0 und Seitenansicht
    place_cam(0)
    for pb in pose.bones:
        pb.rotation_euler = Euler((0, 0, 0), "XYZ")
    bpy.context.view_layer.update()
    render(OUT + "_tpose.png")
    for clip, (fn, n, loop) in CLIPS.items():
        for i in range(0, n, max(1, n // 4)):
            apply_clip(clip, i, n, loop)
            place_cam(45)
            render(f"{OUT}_{clip}_{i:02d}.png")
else:
    # Sprite-Sheet: Zeilen = Richtungen, Spalten = idle(1) + walk + shoot + die
    import json
    import numpy as np
    order = [("idle", None, 1, False)] + [(c, v[0], v[1], v[2]) for c, v in CLIPS.items()]
    total = sum(n for _, _, n, _ in order)
    sheet = np.zeros((DIRS * SIZE, total * SIZE, 4), dtype=np.float32)
    tmp = os.path.abspath(OUT + "_tmp.png")
    meta = {"dirs": DIRS, "frame": SIZE, "columns": total, "clips": {}, "ortho": cam_d.ortho_scale,
            "target_z": target.z, "pitch": 35}
    col = 0
    for clip, fn, n, loop in order:
        meta["clips"][clip] = [col, n]
        for dir_i in range(DIRS):
            place_cam(360.0 * dir_i / DIRS)
            for i in range(n):
                if clip == "idle":
                    apply_clip("walk", 0, 1, True)
                    for pb in pose.bones:
                        if not pb.name.startswith(("upper_arm", "forearm")):
                            pb.rotation_mode = "XYZ"
                            pb.rotation_euler = Euler((0, 0, 0), "XYZ")
                    bpy.context.view_layer.update()
                else:
                    apply_clip(clip, i, n, loop)
                render(tmp)
                img = bpy.data.images.load(tmp, check_existing=False)
                px = np.array(img.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)[::-1]
                bpy.data.images.remove(img)
                r0 = dir_i * SIZE
                c0 = (col + i) * SIZE
                sheet[r0:r0 + SIZE, c0:c0 + SIZE] = px
        col += n
    out_img = bpy.data.images.new("sheet", width=total * SIZE, height=DIRS * SIZE, alpha=True)
    out_img.pixels = sheet[::-1].ravel()
    out_img.filepath_raw = os.path.abspath(OUT + ".png")
    out_img.file_format = "PNG"
    out_img.save()
    with open(OUT + ".json", "w", encoding="utf8") as fh:
        json.dump(meta, fh, indent=1)
    os.remove(tmp)
    print("SHEET", OUT + ".png", total, "x", DIRS)
print("FERTIG")
