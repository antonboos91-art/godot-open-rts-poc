"""Modularer Soldat: Quaternius-Grundkoerper + Standard-Animationen + starre KI-Teile (Kopf, Weste,
Schulterpolster, Schwanz) + Gewehr mit Zweihand-Griff (IK fuer die linke Hand).
  blender -b -P blender/build_modular.py -- --parts out/3d/parts.json --out out/mod/trooper --size 384 [--preview]
parts.json: {"head": "pfad.glb", "vest": ..., "shoulder": ..., "tail": ..., "rifle": ...}  (fehlende Teile werden ausgelassen)
"""
import bpy, sys, math, os, json
from mathutils import Vector, Matrix, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"--parts": "", "--out": "out/mod/trooper", "--size": "384", "--dirs": "8",
       "--lib": "downloads/ual1/extracted/Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb",
       "--rifle-rot": "0,0,0", "--grip": "0.35", "--fore": "0.62", "--head-rot": "0", "--head-size": "0.44", "--suit": "plain", "--weapon-len": "0.85", "--two-hand": "1", "--armor": "0", "--chest-h": "0.52", "--shoulder-size": "0.26", "--chest-z": "1.27", "--chest-w": "0.5", "--shoulder-lift": "0.03"}
for i, v in enumerate(argv):
    if v in opt and i + 1 < len(argv):
        opt[v] = argv[i + 1]
PREVIEW = "--preview" in argv
SIZE = int(opt["--size"])
DIRS = int(opt["--dirs"])
OUT = opt["--out"]
PARTS = json.load(open(opt["--parts"])) if opt["--parts"] else {}

# Clips: Name im Sheet -> (Action, Frames im Sheet, Schleife)
CLIPS = {"idle": ("Pistol_Idle_Loop", 1, True), "walk": ("Jog_Fwd_Loop", 8, True),
         "shoot": ("Pistol_Shoot", 5, False), "die": ("Death01", 8, False)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=opt["--lib"])
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.name != "Mannequin":
        bpy.data.objects.remove(o, do_unlink=True)
rig = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
body = bpy.data.objects["Mannequin"]
rig.animation_data_create()
bones = rig.data.bones


def B(name):
    return rig.matrix_world @ bones[name].head_local


# ---------- Koerper: Material, Kopf entfernen ----------
def flat_mat(name, color, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = color
    p.inputs["Roughness"].default_value = rough
    return m


suit = flat_mat("suit", (0.025, 0.045, 0.12, 1))
if opt["--suit"] == "cyber":
    # Cyber-Anzug: dunkles Metall mit weissen Panzerplatten und leuchtenden Panel-Linien
    nt = suit.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Metallic"].default_value = 0.75
    p.inputs["Roughness"].default_value = 0.32
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 4.5
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    vor2 = nt.nodes.new("ShaderNodeTexVoronoi")
    vor2.inputs["Scale"].default_value = 4.5
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
    mix.inputs[6].default_value = (0.02, 0.04, 0.11, 1)
    mix.inputs[7].default_value = (0.75, 0.78, 0.82, 1)
    nt.links.new(plates.outputs[0], mix.inputs[0])
    nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    p.inputs["Emission Color"].default_value = (0.15, 0.75, 1.0, 1)
    boost = nt.nodes.new("ShaderNodeMath")
    boost.operation = "MULTIPLY"
    boost.inputs[1].default_value = 2.5
    nt.links.new(lines.outputs[0], boost.inputs[0])
    nt.links.new(boost.outputs[0], p.inputs["Emission Strength"])
glove = flat_mat("glove", (0.8, 0.8, 0.82, 1))
boot = flat_mat("boot", (0.015, 0.02, 0.04, 1), 0.5)
body.data.materials.clear()
for m in (suit, glove, boot):
    body.data.materials.append(m)
import bmesh
bm = bmesh.new()
bm.from_mesh(body.data)
neck_z = B("DEF-head").z + 0.02
kill = []
for f in bm.faces:
    c = body.matrix_world @ f.calc_center_median()
    if c.z > neck_z:
        kill.append(f)
        continue
    if abs(c.x) > 0.70:
        f.material_index = 1
    elif c.z < 0.17:
        f.material_index = 2
    else:
        f.material_index = 0
bmesh.ops.delete(bm, geom=kill, context="FACES")
# Halsloch schliessen, sonst sieht man in den hohlen Koerper
bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
bm.to_mesh(body.data)
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
    bones.active = bones[bone_name]
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)


head_c = B("DEF-head")
if "head" in PARTS:
    h = import_part(PARTS["head"])
    h.rotation_euler = Euler((0, 0, math.radians(float(opt["--head-rot"]))), "XYZ")
    bpy.ops.object.select_all(action="DESELECT")
    h.select_set(True)
    bpy.context.view_layer.objects.active = h
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    # TRELLIS ergaenzt hinter der Bueste oft einen Hunderuecken: alles hinter dem Kopf abschneiden
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
    fit(h, float(opt["--head-size"]), 2, (0, head_c.y - 0.02, head_c.z + 0.15))
    attach(h, "DEF-head")
if "vest" in PARTS:
    v = import_part(PARTS["vest"])
    fit(v, 0.50, 2, (0, -0.01, 1.27))
    lo, hi = bbox(v)
    # Breite begrenzen (Weste darf nicht ueber die Arme ragen)
    if hi.x - lo.x > 0.50:
        k = 0.50 / (hi.x - lo.x)
        v.scale = (k, 1.0, 1.0)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    attach(v, "DEF-spine.002")
if "shoulder" in PARTS:
    for side, sign in (("L", 1), ("R", -1)):
        s = import_part(PARTS["shoulder"])
        if sign < 0:
            s.scale = (-1, 1, 1)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        c = B(f"DEF-upper_arm.{side}")
        fit(s, 0.20, 0, (c.x + sign * 0.05, c.y, c.z + 0.05))
        attach(s, f"DEF-upper_arm.{side}")
if "tail" in PARTS:
    t = import_part(PARTS["tail"])
    hc = B("DEF-hips")
    fit(t, 0.34, 2, (0, hc.y + 0.17, hc.z + 0.02))
    attach(t, "DEF-hips")

# ---------- Cyber-Panzerteile mit Volumen (prozedural, starr an Knochen) ----------
def armor_mats():
    plate = bpy.data.materials.new("plate")
    plate.use_nodes = True
    pp = plate.node_tree.nodes["Principled BSDF"]
    pp.inputs["Base Color"].default_value = (0.80, 0.83, 0.88, 1)
    pp.inputs["Metallic"].default_value = 0.35
    pp.inputs["Roughness"].default_value = 0.3
    accent = bpy.data.materials.new("accent")
    accent.use_nodes = True
    ap = accent.node_tree.nodes["Principled BSDF"]
    ap.inputs["Base Color"].default_value = (0.03, 0.06, 0.16, 1)
    ap.inputs["Metallic"].default_value = 0.8
    ap.inputs["Roughness"].default_value = 0.3
    glow = bpy.data.materials.new("glow")
    glow.use_nodes = True
    gp = glow.node_tree.nodes["Principled BSDF"]
    gp.inputs["Base Color"].default_value = (0.1, 0.6, 1.0, 1)
    gp.inputs["Emission Color"].default_value = (0.15, 0.75, 1.0, 1)
    gp.inputs["Emission Strength"].default_value = 4.0
    return plate, accent, glow


def finish(o, mat, thick=0.018, bevel=0.006):
    o.data.materials.append(mat)
    sol = o.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    bev = o.modifiers.new("bev", "BEVEL")
    bev.width = bevel
    bev.segments = 2
    bev.limit_method = "ANGLE"
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in o.data.polygons:
        p.use_smooth = False


def bone_frame(name):
    b = bones[name]
    return rig.matrix_world @ b.matrix_local, b.length


def ring(bone_name, r_side, r_front, t0, t1, mat, verts=12, front_only=False):
    """Hohler Ring/Schale um einen Knochen (Achse = Knochen-Y), von t0 bis t1 der Knochenlaenge."""
    m, length = bone_frame(bone_name)
    depth = (t1 - t0) * length
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=1.0, depth=depth, end_fill_type="NOTHING")
    o = bpy.context.active_object
    if front_only:
        import bmesh as _bm
        bmx = _bm.new()
        bmx.from_mesh(o.data)
        _bm.ops.delete(bmx, geom=[f for f in bmx.faces if f.calc_center_median().y > 0.2], context="FACES")
        bmx.to_mesh(o.data)
        bmx.free()
    o.scale = (r_side, r_front, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    local = Matrix.Translation((0, length * (t0 + t1) / 2, 0)) @ Euler((math.radians(-90), 0, 0), "XYZ").to_matrix().to_4x4()
    o.matrix_world = m @ local
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    finish(o, mat)
    attach(o, bone_name)
    return o


def shoulder(side, sign, plate, accent, glow):
    c = B(f"DEF-upper_arm.{side}")
    # Kuppel: obere Halbkugel, flach und breit, nach aussen geneigt
    for k, (mat, sc, lift) in enumerate(((plate, (0.15, 0.13, 0.10), 0.0), (accent, (0.155, 0.06, 0.104), 0.004))):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0)
        o = bpy.context.active_object
        import bmesh as _bm
        bmx = _bm.new()
        bmx.from_mesh(o.data)
        _bm.ops.delete(bmx, geom=[f for f in bmx.faces if f.calc_center_median().z < 0.05], context="FACES")
        bmx.to_mesh(o.data)
        bmx.free()
        o.scale = sc
        o.rotation_euler = (0, math.radians(-sign * 28), 0)
        o.location = (c.x + sign * 0.03, c.y, c.z + 0.02 + lift)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        finish(o, mat, thick=0.022 if k == 0 else 0.01)
        attach(o, f"DEF-upper_arm.{side}")
    # leuchtende Kante unten am Rand
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.03, major_segments=24, minor_segments=4)
    t = bpy.context.active_object
    t.scale = (0.15, 0.13, 0.13)
    t.rotation_euler = (0, math.radians(-sign * 28), 0)
    t.location = (c.x + sign * 0.03, c.y, c.z + 0.025)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    t.data.materials.append(glow)
    attach(t, f"DEF-upper_arm.{side}")


if opt["--armor"] == "1":
    plate, accent, glow = armor_mats()
    for side, sign in (("L", 1), ("R", -1)):
        shoulder(side, sign, plate, accent, glow)
        ring(f"DEF-forearm.{side}", 0.058, 0.058, 0.15, 0.85, plate)
        ring(f"DEF-shin.{side}", 0.07, 0.075, 0.1, 0.75, plate, front_only=True)
        ring(f"DEF-thigh.{side}", 0.085, 0.09, 0.15, 0.6, accent, front_only=True)
    # Brust- und Rueckenpanzer als ovaler Ring um den Oberkoerper
    ring("DEF-spine.002", 0.17, 0.125, 0.0, 1.0, accent, verts=16)
    ring("DEF-spine.003", 0.19, 0.14, 0.0, 0.95, plate, verts=16)
    ring("DEF-hips", 0.165, 0.12, 0.2, 1.0, accent, verts=16)
    print("ARMOR built")

# ---------- KI-Ruestungsteile (Krea 2 -> TRELLIS), starr an Knochen ----------
def tint_dark_silver(o):
    """Ruestungsfarbe auf Dunkelsilber abdunkeln (Textur x Faktor), metallischer."""
    for slot in o.material_slots:
        m = slot.material
        if m is None or not m.use_nodes:
            continue
        nt = m.node_tree
        p = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if p is None:
            continue
        p.inputs["Metallic"].default_value = 0.65
        p.inputs["Roughness"].default_value = 0.35
        src = p.inputs["Base Color"].links[0].from_socket if p.inputs["Base Color"].links else None
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[7].default_value = (0.42, 0.44, 0.48, 1)
        if src is not None:
            nt.links.new(src, mix.inputs[6])
        else:
            mix.inputs[6].default_value = p.inputs["Base Color"].default_value
        nt.links.new(mix.outputs[2], p.inputs["Base Color"])


def close_holes(o):
    bmx = bmesh.new()
    bmx.from_mesh(o.data)
    bmesh.ops.holes_fill(bmx, edges=[e for e in bmx.edges if e.is_boundary], sides=0)
    bmx.to_mesh(o.data)
    bmx.free()


def align_to_bone(o, bone_name, length, t, flip=False):
    """Hauptachse des Teils entlang des Knochens legen, auf Laenge skalieren, bei t (0..1) zentrieren."""
    import numpy as np
    co = np.array([tuple(o.matrix_world @ vv.co) for vv in o.data.vertices])
    co -= co.mean(axis=0)
    w, vecs = np.linalg.eigh(np.cov(co.T))
    main = Vector(tuple(vecs[:, int(np.argmax(w))]))
    b = bones[bone_name]
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
    proj = [p.dot(d) for p in pts]
    s = length / max(max(proj) - min(proj), 1e-6)
    o.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lo, hi = bbox(o)
    o.location += head.lerp(tail, t) - (lo + hi) / 2
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    attach(o, bone_name)


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
    # Fuellkoerper: der KI-Brustpanzer ist eine hohle Schale, innen sonst sichtbar
    lo, hi = bbox(c)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=1.0)
    core = bpy.context.active_object
    core.scale = ((hi.x - lo.x) * 0.47, (hi.y - lo.y) * 0.47, (hi.z - lo.z) * 0.48)
    core.location = (lo + hi) / 2
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    core.data.materials.append(suit)
    attach(core, "DEF-spine.002")
    attach(c, "DEF-spine.002")
for side, sign in (("L", 1), ("R", -1)):
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
        big = max(hi - lo)
        k = float(opt["--shoulder-size"]) / big
        s.scale = (k, k, k)
        bpy.ops.object.select_all(action="DESELECT")
        s.select_set(True)
        bpy.context.view_layer.objects.active = s
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        cc = B(f"DEF-upper_arm.{side}")
        lo, hi = bbox(s)
        s.location += Vector((cc.x + sign * 0.07, cc.y, cc.z + float(opt["--shoulder-lift"]))) - (lo + hi) / 2
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        attach(s, f"DEF-upper_arm.{side}")
    if "a_forearm" in PARTS:
        fa = import_part(PARTS["a_forearm"])
        tint_dark_silver(fa)
        align_to_bone(fa, f"DEF-forearm.{side}", 0.25, 0.5)
    if "a_shin" in PARTS:
        sh = import_part(PARTS["a_shin"])
        tint_dark_silver(sh)
        align_to_bone(sh, f"DEF-shin.{side}", 0.42, 0.42)

# ---------- Gewehr: rechte Hand, linke Hand per IK am Vorderschaft ----------
if "rifle" in PARTS:
    import numpy as np
    g = import_part(PARTS["rifle"])
    co = np.array([tuple(g.matrix_world @ vv.co) for vv in g.data.vertices])
    co -= co.mean(axis=0)
    w, vecs = np.linalg.eigh(np.cov(co.T))
    main = Vector(tuple(vecs[:, int(np.argmax(w))]))
    g.rotation_mode = "QUATERNION"
    g.rotation_quaternion = main.rotation_difference(Vector((0, -1, 0)))  # Lauf nach vorne (-Y)
    bpy.ops.object.select_all(action="DESELECT")
    g.select_set(True)
    bpy.context.view_layer.objects.active = g
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    rr = [math.radians(float(x)) for x in opt["--rifle-rot"].split(",")]
    g.rotation_mode = "XYZ"
    g.rotation_euler = Euler(rr, "XYZ")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    lo, hi = bbox(g)
    k = float(opt["--weapon-len"]) / max(hi.y - lo.y, 1e-6)
    g.scale = (k, k, k)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # Pose fuer die Ausrichtung: erster Frame der Schuss-Animation
    rig.animation_data.action = bpy.data.actions[CLIPS["shoot"][0]]
    bpy.context.scene.frame_set(int(rig.animation_data.action.frame_range[0]))
    bpy.context.view_layer.update()
    pb = rig.pose.bones["DEF-hand.R"]
    hand_m = rig.matrix_world @ pb.matrix
    # Gewehr in Hand-Raum ausrichten: Lauf entlang der Zielrichtung des Unterarms
    fore = rig.pose.bones["DEF-forearm.R"]
    aim_dir = ((rig.matrix_world @ fore.tail) - (rig.matrix_world @ fore.head)).normalized()
    q = Vector((0, -1, 0)).rotation_difference(aim_dir)
    g.matrix_world = Matrix.Translation(Vector((0, 0, 0))) @ q.to_matrix().to_4x4()
    bpy.context.view_layer.update()
    lo, hi = bbox(g)
    grip_frac = float(opt["--grip"])
    # Griffpunkt entlang der Laufachse in die Hand legen
    pts = [g.matrix_world @ vv.co for vv in g.data.vertices]
    proj = [p.dot(aim_dir) for p in pts]
    pmin, pmax = min(proj), max(proj)
    grip_point = aim_dir * (pmax - (pmax - pmin) * (1 - grip_frac))  # vom Kolben gemessen
    center_off = sum((p for p in pts), Vector()) / len(pts)
    center_off -= aim_dir * center_off.dot(aim_dir)
    hand_pos = hand_m.translation
    g.location = hand_pos - grip_point - center_off + Vector((0, 0, -0.03))
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    g.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bones.active = bones["DEF-hand.R"]
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)
    # Ziel fuer die linke Hand: Vorderschaft
    fore_frac = float(opt["--fore"])
    tgt = bpy.data.objects.new("LeftGrip", None)
    bpy.context.scene.collection.objects.link(tgt)
    tgt.location = hand_pos + aim_dir * (pmax - pmin) * (fore_frac - grip_frac) + Vector((0, 0, -0.02))
    tgt.parent = g
    tgt.matrix_parent_inverse = g.matrix_world.inverted()
    if opt["--two-hand"] == "1":
        ik = rig.pose.bones["DEF-forearm.L"].constraints.new("IK")
        ik.target = tgt
        ik.chain_count = 2
        ik.influence = 1.0
    print("RIFLE attached, aim", tuple(round(x, 2) for x in aim_dir))

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
    action_name, _, loop = CLIPS[clip]
    act = bpy.data.actions[action_name]
    rig.animation_data.action = act
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
    if clip == "die":
        # Sterbe-Animation wandert: Huefte zu 70 % zur Bildmitte zurueckziehen
        hp = rig.matrix_world @ rig.pose.bones["DEF-hips"].head
        rig.location = (-hp.x * 0.7, -hp.y * 0.7, 0)
        bpy.context.view_layer.update()
    if clip == "walk" and ARM_POSE:
        # Oberkoerper in Gewehr-Bereitschaftshaltung, Beine aus der Laufanimation
        for name, q in ARM_POSE.items():
            pb = rig.pose.bones[name]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q
        bpy.context.view_layer.update()
    # Root-Bewegung herausrechnen, damit die Figur im Bild bleibt
    root = rig.pose.bones.get("root")
    if root is not None and clip != "die":
        root.location = (0, 0, 0)


# Armhaltung aus der Ziel-Idle-Animation merken (fuer das Laufen mit Gewehr)
ARM_POSE = {}
rig.animation_data.action = bpy.data.actions[CLIPS["idle"][0]]
scn.frame_set(int(bpy.data.actions[CLIPS["idle"][0]].frame_range[0]))
bpy.context.view_layer.update()
for pb in rig.pose.bones:
    if any(k in pb.name for k in ("shoulder", "upper_arm", "forearm", "hand", "f_", "thumb")):
        pb.rotation_mode = "QUATERNION"
        ARM_POSE[pb.name] = pb.rotation_quaternion.copy()

# Lauf-Action mit Gewehr: Kopie von Jog, Arm-Kurven durch feste Idle-Armhaltung ersetzen
walk_src = bpy.data.actions[CLIPS["walk"][0]]
walk_act = walk_src.copy()
walk_act.name = "Walk_Rifle"
fcurves = walk_act.fcurves
for fc in list(fcurves):
    if any(f'"{n}"' in fc.data_path for n in ARM_POSE):
        fcurves.remove(fc)
f0 = int(walk_act.frame_range[0])
for name, q in ARM_POSE.items():
    for k in range(4):
        fc = fcurves.new(f'pose.bones["{name}"].rotation_quaternion', index=k, action_group=name)
        fc.keyframe_points.insert(f0, q[k])
CLIPS["walk"] = ("Walk_Rifle", CLIPS["walk"][1], True)
ARM_POSE = {}
print("WALK_RIFLE curves", len(fcurves))

if PREVIEW:
    for clip, (a, n, loop) in CLIPS.items():
        for i in range(n):
            pose_clip(clip, i, n)
            place_cam(45)
            render(f"{OUT}_{clip}_{i:02d}.png")
else:
    import numpy as np
    total = sum(n for _, n, _ in CLIPS.values())
    sheet = np.zeros((DIRS * SIZE, total * SIZE, 4), dtype=np.float32)
    tmp = os.path.abspath(OUT + "_tmp.png")
    meta = {"dirs": DIRS, "frame": SIZE, "columns": total, "clips": {}, "ortho": cam_d.ortho_scale,
            "target_z": target.z, "pitch": 35, "figure_height": 1.85}
    col = 0
    for clip, (a, n, loop) in CLIPS.items():
        meta["clips"][clip] = [col, n]
        for dir_i in range(DIRS):
            place_cam(360.0 * dir_i / DIRS)
            for i in range(n):
                pose_clip(clip, i, n)
                render(tmp)
                img = bpy.data.images.load(tmp, check_existing=False)
                px = np.array(img.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)[::-1]
                bpy.data.images.remove(img)
                sheet[dir_i * SIZE:(dir_i + 1) * SIZE, (col + i) * SIZE:(col + i + 1) * SIZE] = px
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
