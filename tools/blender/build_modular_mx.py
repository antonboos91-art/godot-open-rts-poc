"""Modularer Soldat auf Mixamo-Skelett (X Bot) mit echten Gewehr-Animationen (Basic Shooter Pack + Mixamo-Ordner).
Gleiche Teile wie build_modular.py (KI-Kopf, Rüstungsteile aus Krea/TRELLIS), aber Waffe aus den props-GLBs und
Zweihand-Animationen ohne IK/Armpose-Tricks.
  blender -b -P build_modular_mx.py -- --parts out/mod/parts_katzen.json --pal katzen --weapon AK --out out/mod/mx_x --size 192 [--preview]
Clips (Sheet-Format wie bisher): idle, walk, shoot, die, idle_a (nachladen), idle_b (salutieren)."""
import bpy, sys, math, os, json
import bmesh
from mathutils import Vector, Matrix, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"--parts": "", "--out": "out/mod/mx", "--size": "192", "--pal": "shibas", "--weapon": "AK", "--weapon-len": "0.95",
       "--head-size": "0.42", "--head-rot": "0", "--chest-h": "0.62", "--chest-z": "1.42", "--chest-w": "0.66",
       "--shoulder-size": "0.40", "--shoulder-lift": "0.02", "--wgrip": "0.25", "--wflip": "0", "--wrot": "0,0,0", "--wup": "0.0",
       "--root": "C:/Users/anton/Desktop/RTS/assets/animations", "--build": "1.0", "--yaw": "45", "--bw": "1.0", "--bh": "1.0", "--notint": "0", "--core-k": "1.0", "--glow": "", "--plate": "", "--gain": "1.0"}
for i, v in enumerate(argv):
    if v in opt and i + 1 < len(argv):
        opt[v] = argv[i + 1]
PREVIEW = "--preview" in argv
SIZE = int(opt["--size"])
OUT = opt["--out"]
ROOT = opt["--root"]
PARTS = json.load(open(opt["--parts"])) if opt["--parts"] else {}
PAL = {"shibas": ((0.02, 0.04, 0.11, 1), (0.75, 0.78, 0.82, 1), (0.15, 0.75, 1.0, 1), (0.42, 0.44, 0.48, 1)),
       "katzen": ((0.015, 0.01, 0.035, 1), (0.20, 0.12, 0.32, 1), (0.75, 0.2, 1.0, 1), (0.24, 0.17, 0.33, 1)),
       "baeren": ((0.13, 0.02, 0.015, 1), (0.80, 0.58, 0.14, 1), (1.0, 0.65, 0.12, 1), (0.58, 0.42, 0.16, 1))}[opt["--pal"]]

def _rgba(s):
    v = [float(x) for x in s.split(",")]
    return (v[0], v[1], v[2], 1)


if opt["--glow"]:
    PAL = (PAL[0], PAL[1], _rgba(opt["--glow"]), PAL[3])
if opt["--plate"]:
    PAL = (PAL[0], _rgba(opt["--plate"]), PAL[2], PAL[3])

# Clip -> (Datei relativ zu --root, Frames im Sheet, Schleife)
CLIPS = {"idle": ("basic_shooter_pack/rifle aiming idle.fbx", 1, True),
         "walk": ("basic_shooter_pack/rifle run.fbx", 8, True),
         "shoot": ("basic_shooter_pack/firing rifle.fbx", 5, False),
         "die": ("mixamo/death_rifle_back.fbx", 8, False),
         "idle_a": ("basic_shooter_pack/reloading.fbx", 10, False),
         "idle_b": ("mixamo/idle_military_salute.fbx", 10, False)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=f"{ROOT}/basic_shooter_pack/X Bot.fbx")
rig = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
joints = bpy.data.objects["Beta_Joints"]
body = bpy.data.objects["Beta_Surface"]
rig.animation_data_create()
bones = rig.data.bones
# X-Bot ist Z-hoch, schaut nach -Y (wie der Quaternius-Koerper)

# ---------- Animationen laden ----------
ACT = {}
for clip, (path, _, _) in CLIPS.items():
    if path in ACT:
        continue
    before_o = set(bpy.context.scene.objects)
    before_a = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=f"{ROOT}/{path}")
    act = [a for a in bpy.data.actions if a not in before_a][0]
    act.use_fake_user = True
    act.name = path
    ACT[path] = act
    for o in [o for o in bpy.context.scene.objects if o not in before_o]:
        bpy.data.objects.remove(o, do_unlink=True)


def B(name):
    return rig.matrix_world @ bones["mixamorig:" + name].head_local


def Bt(name):
    return rig.matrix_world @ bones["mixamorig:" + name].tail_local


def flat_mat(name, color, rough=0.85, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = color
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m


# ---------- Cyber-Anzug (wie build_modular) ----------
suit = flat_mat("suit", PAL[0], 0.32, 0.75)
nt = suit.node_tree
p = nt.nodes["Principled BSDF"]
tc = nt.nodes.new("ShaderNodeTexCoord")
vor = nt.nodes.new("ShaderNodeTexVoronoi")
vor.feature = "DISTANCE_TO_EDGE"
vor.inputs["Scale"].default_value = 0.045
nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
vor2 = nt.nodes.new("ShaderNodeTexVoronoi")
vor2.inputs["Scale"].default_value = 0.045
nt.links.new(tc.outputs["Object"], vor2.inputs["Vector"])
lines = nt.nodes.new("ShaderNodeMath")
lines.operation = "LESS_THAN"
lines.inputs[1].default_value = 0.012
nt.links.new(vor.outputs["Distance"], lines.inputs[0])
plates = nt.nodes.new("ShaderNodeMath")
plates.operation = "GREATER_THAN"
plates.inputs[1].default_value = 0.8
sep = nt.nodes.new("ShaderNodeSeparateColor")
nt.links.new(vor2.outputs["Color"], sep.inputs["Color"])
nt.links.new(sep.outputs[0], plates.inputs[0])
mix = nt.nodes.new("ShaderNodeMix")
mix.data_type = "RGBA"
mix.inputs[6].default_value = PAL[0]
mix.inputs[7].default_value = PAL[1]
nt.links.new(plates.outputs[0], mix.inputs[0])
nt.links.new(mix.outputs[2], p.inputs["Base Color"])
p.inputs["Emission Color"].default_value = PAL[2]
boost = nt.nodes.new("ShaderNodeMath")
boost.operation = "MULTIPLY"
boost.inputs[1].default_value = 2.5
nt.links.new(lines.outputs[0], boost.inputs[0])
nt.links.new(boost.outputs[0], p.inputs["Emission Strength"])
glove = flat_mat("glove", (0.8, 0.8, 0.82, 1))
boot = flat_mat("boot", (0.015, 0.02, 0.04, 1), 0.5)

# Koerper bearbeiten: Kopf entfernen, Materialzonen
neck_z = B("Head").z + 0.02
for obj in (body, joints):
    obj.data.materials.clear()
    for m in (suit, glove, boot):
        obj.data.materials.append(m)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    kill = []
    for f in bm.faces:
        c = obj.matrix_world @ f.calc_center_median()
        if c.z > neck_z:
            kill.append(f)
            continue
        if abs(c.x) > 0.72:
            f.material_index = 1
        elif c.z < 0.12:
            f.material_index = 2
        else:
            f.material_index = 0
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bm.to_mesh(obj.data)
    bm.free()


# ---------- Teile laden und an Knochen haengen ----------
def import_part(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    if len(new) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for e in [x for x in bpy.context.scene.objects if x not in before and x.type == "EMPTY"]:
        bpy.data.objects.remove(e, do_unlink=True)
    return o


def bbox(o):
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def fit(o, size, axis, center):
    lo, hi = bbox(o)
    s = size / max((hi - lo)[axis], 1e-6)
    o.scale = (s, s, s)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lo, hi = bbox(o)
    o.location += Vector(center) - (lo + hi) / 2
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)


def attach(o, bone_name):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bones.active = bones["mixamorig:" + bone_name]
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)


def tint_dark_silver(o):
    if opt["--notint"] == "1":
        gain = float(opt["--gain"])
        for slot in o.material_slots:
            m = slot.material
            if m is None or not m.use_nodes:
                continue
            pb = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if pb is None or gain == 1.0:
                continue
            src = pb.inputs["Base Color"].links[0].from_socket if pb.inputs["Base Color"].links else None
            mx = m.node_tree.nodes.new("ShaderNodeMix")
            mx.data_type = "RGBA"
            mx.blend_type = "MULTIPLY"
            mx.inputs[0].default_value = 1.0
            mx.inputs[7].default_value = (gain, gain, gain, 1)
            if src is not None:
                m.node_tree.links.new(src, mx.inputs[6])
            else:
                mx.inputs[6].default_value = pb.inputs["Base Color"].default_value
            m.node_tree.links.new(mx.outputs[2], pb.inputs["Base Color"])
        return
    for slot in o.material_slots:
        m = slot.material
        if m is None or not m.use_nodes:
            continue
        nt2 = m.node_tree
        pb = next((n for n in nt2.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if pb is None:
            continue
        pb.inputs["Metallic"].default_value = 0.65
        pb.inputs["Roughness"].default_value = 0.35
        src = pb.inputs["Base Color"].links[0].from_socket if pb.inputs["Base Color"].links else None
        mx = nt2.nodes.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        mx.blend_type = "MULTIPLY"
        mx.inputs[0].default_value = 1.0
        mx.inputs[7].default_value = PAL[3]
        if src is not None:
            nt2.links.new(src, mx.inputs[6])
        else:
            mx.inputs[6].default_value = pb.inputs["Base Color"].default_value
        nt2.links.new(mx.outputs[2], pb.inputs["Base Color"])


def close_holes(o):
    bmx = bmesh.new()
    bmx.from_mesh(o.data)
    bmesh.ops.holes_fill(bmx, edges=[e for e in bmx.edges if e.is_boundary], sides=0)
    bmx.to_mesh(o.data)
    bmx.free()


def align_to_bone(o, bone_name, length, t, flip=False):
    import numpy as np
    co = np.array([tuple(o.matrix_world @ vv.co) for vv in o.data.vertices])
    co -= co.mean(axis=0)
    w, vecs = np.linalg.eigh(np.cov(co.T))
    main = Vector(tuple(vecs[:, int(np.argmax(w))]))
    b = bones["mixamorig:" + bone_name]
    head = rig.matrix_world @ b.head_local
    tail = rig.matrix_world @ b.tail_local
    d = (tail - head).normalized()
    if flip:
        d = -d
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = main.rotation_difference(d)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    pts = [o.matrix_world @ vv.co for vv in o.data.vertices]
    proj = [pp.dot(d) for pp in pts]
    s = length / max(max(proj) - min(proj), 1e-6)
    o.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lo, hi = bbox(o)
    o.location += head.lerp(tail, t) - (lo + hi) / 2
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    attach(o, bone_name)


head_c = B("Head")
if "head" in PARTS:
    h = import_part(PARTS["head"])
    h.rotation_euler = Euler((0, 0, math.radians(float(opt["--head-rot"]))), "XYZ")
    bpy.ops.object.select_all(action="DESELECT")
    h.select_set(True)
    bpy.context.view_layer.objects.active = h
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    lo, hi = bbox(h)
    hgt = hi.z - lo.z
    bmh = bmesh.new()
    bmh.from_mesh(h.data)
    cut = [f for f in bmh.faces if (h.matrix_world @ f.calc_center_median()).y > lo.y + hgt * 0.62
           or (h.matrix_world @ f.calc_center_median()).z < lo.z + hgt * 0.27]
    bmesh.ops.delete(bmh, geom=cut, context="FACES")
    bmesh.ops.holes_fill(bmh, edges=[e for e in bmh.edges if e.is_boundary], sides=0)
    bmh.to_mesh(h.data)
    bmh.free()
    fit(h, float(opt["--head-size"]), 2, (0, head_c.y - 0.02, head_c.z + 0.12))
    attach(h, "Head")

if "a_chest" in PARTS:
    c = import_part(PARTS["a_chest"])
    tint_dark_silver(c)
    close_holes(c)
    for slot in c.material_slots:
        if slot.material:
            slot.material.use_backface_culling = True
    fit(c, float(opt["--chest-h"]), 2, (0, -0.005, float(opt["--chest-z"])))
    lo, hi = bbox(c)
    cw = float(opt["--chest-w"])
    if hi.x - lo.x > cw:
        k = cw / (hi.x - lo.x)
        c.scale = (k, k, 1.0)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lo, hi = bbox(c)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=1.0)
    core = bpy.context.active_object
    ck = float(opt["--core-k"])
    core.scale = ((hi.x - lo.x) * 0.47 * ck, (hi.y - lo.y) * 0.47 * ck, (hi.z - lo.z) * 0.48 * ck)
    core.location = (lo + hi) / 2
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    core.data.materials.append(suit)
    attach(core, "Spine2")
    attach(c, "Spine2")
for side, sign, mxs in (("L", 1, "Left"), ("R", -1, "Right")):
    # Mixamo: Right liegt bei -X, Left bei +X
    if "a_shoulder" in PARTS:
        s = import_part(PARTS["a_shoulder"])
        tint_dark_silver(s)
        if sign < 0:
            s.scale = (-1, 1, 1)
            bpy.ops.object.select_all(action="DESELECT")
            s.select_set(True)
            bpy.context.view_layer.objects.active = s
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        lo, hi = bbox(s)
        k = float(opt["--shoulder-size"]) / max(hi - lo)
        s.scale = (k, k, k)
        bpy.ops.object.select_all(action="DESELECT")
        s.select_set(True)
        bpy.context.view_layer.objects.active = s
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        cc = B(mxs + "Arm")
        lo, hi = bbox(s)
        s.location += Vector((cc.x + sign * 0.03, cc.y, cc.z + float(opt["--shoulder-lift"]))) - (lo + hi) / 2
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        attach(s, mxs + "Arm")
    if "a_forearm" in PARTS:
        fa = import_part(PARTS["a_forearm"])
        tint_dark_silver(fa)
        align_to_bone(fa, mxs + "ForeArm", 0.25, 0.5)
    if "a_shin" in PARTS:
        sh = import_part(PARTS["a_shin"])
        tint_dark_silver(sh)
        align_to_bone(sh, mxs + "Leg", 0.42, 0.42)

# ---------- Waffe aus props: rechte Hand, Lauf entlang Rechte->Linke Hand (Referenzpose: Ziel-Idle) ----------
act_idle = ACT[CLIPS["idle"][0]]
rig.animation_data.action = act_idle
if hasattr(rig.animation_data, "action_slot") and len(act_idle.slots) > 0:
    rig.animation_data.action_slot = act_idle.slots[0]
bpy.context.scene.frame_set(int(act_idle.frame_range[0]))
bpy.context.view_layer.update()
if opt["--weapon"] != "none":
    import numpy as np
    g = import_part(f"{ROOT}/props/{opt['--weapon']}.glb")
    co = np.array([tuple(g.matrix_world @ vv.co) for vv in g.data.vertices])
    cen = co.mean(axis=0)
    w, vecs = np.linalg.eigh(np.cov((co - cen).T))
    main = Vector(tuple(vecs[:, int(np.argmax(w))]))
    rh = rig.matrix_world @ rig.pose.bones["mixamorig:RightHand"].head
    lh = rig.matrix_world @ rig.pose.bones["mixamorig:LeftHand"].head
    aim = (lh - rh).normalized()
    if opt["--wflip"] == "1":
        main = -main
    g.rotation_mode = "QUATERNION"
    g.rotation_quaternion = main.rotation_difference(aim)
    bpy.ops.object.select_all(action="DESELECT")
    g.select_set(True)
    bpy.context.view_layer.objects.active = g
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    rr = [math.radians(float(x)) for x in opt["--wrot"].split(",")]
    g.rotation_mode = "XYZ"
    g.rotation_euler = Euler(rr, "XYZ")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    lo, hi = bbox(g)
    kk = float(opt["--weapon-len"]) / max(max(hi - lo), 1e-6)
    g.scale = (kk, kk, kk)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    pts = [g.matrix_world @ vv.co for vv in g.data.vertices]
    proj = [pp.dot(aim) for pp in pts]
    pmin, pmax = min(proj), max(proj)
    gp = aim * (pmin + (pmax - pmin) * float(opt["--wgrip"]))
    cen2 = sum((pp for pp in pts), Vector()) / len(pts)
    cen2 -= aim * cen2.dot(aim)
    g.location = rh - gp - cen2 + Vector((0, 0, float(opt["--wup"])))
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    g.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bones.active = bones["mixamorig:RightHand"]
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)
    print("WEAPON attached", opt["--weapon"])

# Koerperbau je Einheit (breit/schmal, gross/klein), Teile und Waffe hängen an Knochen und skalieren mit
sx0, sy0, sz0 = rig.scale
rig.scale = (sx0 * float(opt["--bw"]), sy0 * float(opt["--bw"]), sz0 * float(opt["--bh"]))
bpy.context.view_layer.update()
# ---------- Kamera / Licht ----------
scn = bpy.context.scene
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 3.3
cam = bpy.data.objects.new("cam", cam_d)
scn.collection.objects.link(cam)
pitch = math.radians(35)
target = Vector((0, 0, 0.95))
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


def pose_clip(clip, i, n):
    path, _, loop = CLIPS[clip]
    act = ACT[path]
    rig.animation_data.action = act
    if hasattr(rig.animation_data, "action_slot") and len(act.slots) > 0:
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    if n <= 1:
        f = f0
    elif loop:
        f = f0 + (f1 - f0) * i / n
    else:
        f = f0 + (f1 - f0) * i / (n - 1)
    rig.location = (0, 0, 0)
    scn.frame_set(int(round(f)))
    bpy.context.view_layer.update()
    # Root-Bewegung herausrechnen: Huefte in Bildmitte halten (Tod: 70 %)
    hp = rig.matrix_world @ rig.pose.bones["mixamorig:Hips"].head
    fac = 0.7 if clip == "die" else 1.0
    rig.location = (-hp.x * fac, -hp.y * fac, 0)
    bpy.context.view_layer.update()


if PREVIEW:
    for clip, (a, n, loop) in CLIPS.items():
        for i in range(0, n, max(1, n // 2)):
            pose_clip(clip, i, n)
            place_cam(float(opt["--yaw"]))
            render(f"{OUT}_{clip}_{i:02d}.png")
else:
    import numpy as np
    total = sum(n for _, n, _ in CLIPS.values())
    sheet = np.zeros((8 * SIZE, total * SIZE, 4), dtype=np.float32)
    tmp = os.path.abspath(OUT + "_tmp.png")
    meta = {"dirs": 8, "frame": SIZE, "columns": total, "clips": {}, "ortho": cam_d.ortho_scale,
            "target_z": target.z, "pitch": 35, "figure_height": 1.85}
    col = 0
    for clip, (a, n, loop) in CLIPS.items():
        meta["clips"][clip] = [col, n]
        for dir_i in range(8):
            place_cam(360.0 * dir_i / 8)
            for i in range(n):
                pose_clip(clip, i, n)
                render(tmp)
                img = bpy.data.images.load(tmp, check_existing=False)
                px = np.array(img.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)[::-1]
                bpy.data.images.remove(img)
                sheet[dir_i * SIZE:(dir_i + 1) * SIZE, (col + i) * SIZE:(col + i + 1) * SIZE] = px
        col += n
    out_img = bpy.data.images.new("sheet", width=total * SIZE, height=8 * SIZE, alpha=True)
    out_img.pixels = sheet[::-1].ravel()
    out_img.filepath_raw = os.path.abspath(OUT + ".png")
    out_img.file_format = "PNG"
    out_img.save()
    with open(OUT + ".json", "w", encoding="utf8") as fh:
        json.dump(meta, fh, indent=1)
    os.remove(tmp)
    print("SHEET", OUT + ".png", total, "x 8")
print("FERTIG")
