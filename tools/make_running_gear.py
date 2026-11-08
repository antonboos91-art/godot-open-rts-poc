"""Baut ein exaktes Panzer-Fahrwerk (Laufrollen, Antriebsrad, Leitrad, Ketten) und ein Kanonenrohr
als getrennte, benannte Objekte und exportiert sie als GLB. Vorne = Blender +Y (Godot -Z).
  blender -b -P make_running_gear.py -- --out gear.glb --length 4.0 --width 2.6 --wheels 5 --radius 0.32
Objekte: Track_L, Track_R (UV.x laeuft entlang der Kette -> Shader scrollt), Wheel_L_0.., Wheel_R_0..,
Sprocket_L/R, Idler_L/R (drehen um X), Barrel (Ursprung am Rohransatz, zeigt nach +Y).
"""
import bpy, bmesh, sys, math, argparse
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--length", type=float, default=4.0)
p.add_argument("--width", type=float, default=2.6)
p.add_argument("--wheels", type=int, default=5)
p.add_argument("--radius", type=float, default=0.32)
p.add_argument("--track-width", type=float, default=0.55)
p.add_argument("--barrel", type=float, default=2.4)
a = p.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, metal=0.6, rough=0.45):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


M_TRACK = material("Track", (0.08, 0.08, 0.09), 0.8, 0.6)
M_WHEEL = material("Wheel", (0.16, 0.17, 0.19), 0.7, 0.5)
M_HUB = material("Hub", (0.06, 0.16, 0.42), 0.4, 0.4)
M_BARREL = material("Barrel", (0.05, 0.13, 0.36), 0.5, 0.35)
M_STEEL = material("Steel", (0.55, 0.57, 0.6), 0.9, 0.3)


def obj_from_bmesh(name, bm, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = True
    return o


def wheel(name, r, w, loc, teeth=0):
    bm = bmesh.new()
    seg = 24
    # Lauffläche
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=w)
    # Nabe (etwas kleiner, steht seitlich vor)
    hub = bmesh.new()
    bmesh.ops.create_cone(hub, cap_ends=True, segments=12, radius1=r * 0.45, radius2=r * 0.45, depth=w * 1.25)
    if teeth:
        for i in range(teeth):
            ang = 2 * math.pi * i / teeth
            ret = bmesh.ops.create_cube(bm, size=1)
            bmesh.ops.scale(bm, vec=(r * 0.22, r * 0.22, w * 0.6), verts=ret["verts"])
            bmesh.ops.translate(bm, vec=(math.cos(ang) * r * 1.05, math.sin(ang) * r * 1.05, 0), verts=ret["verts"])
    o = obj_from_bmesh(name, bm, M_WHEEL)
    h = obj_from_bmesh(name + "_hub", hub, M_HUB)
    # Achse = X: Zylinder liegt entlang Z -> um Y drehen
    for ob in (o, h):
        ob.rotation_euler = (0, math.radians(90), 0)
        ob.location = loc
    bpy.ops.object.select_all(action="DESELECT")
    h.select_set(True)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def track(name, x, front, back, r, z, tw, thickness=0.07):
    """Kettenband als geschlossene Schleife um Antriebs- und Leitrad (Seitenansicht YZ)."""
    pts = []
    rr = r + thickness * 0.5
    n_arc = 14
    # oben von hinten nach vorne
    steps = 24
    for i in range(steps + 1):
        pts.append(Vector((0, back + (front - back) * i / steps, z + rr)))
    for i in range(1, n_arc):
        ang = math.pi / 2 - math.pi * i / n_arc
        pts.append(Vector((0, front + math.cos(ang) * rr, z + math.sin(ang) * rr)))
    for i in range(steps + 1):
        pts.append(Vector((0, front - (front - back) * i / steps, z - rr)))
    for i in range(1, n_arc):
        ang = -math.pi / 2 - math.pi * i / n_arc
        pts.append(Vector((0, back + math.cos(ang) * rr, z + math.sin(ang) * rr)))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    total = sum((pts[(i + 1) % len(pts)] - pts[i]).length for i in range(len(pts)))
    outer, inner = [], []
    acc = 0.0
    us = []
    for i, pnt in enumerate(pts):
        if i:
            acc += (pnt - pts[i - 1]).length
        us.append(acc / total)
        center = Vector((0, (front + back) / 2, z))
        d = (pnt - center)
        d.x = 0
        n = d.normalized()
        outer.append(pnt + n * thickness * 0.5)
        inner.append(pnt - n * thickness * 0.5)
    rings = []
    for xo in (-tw / 2, tw / 2):
        rings.append([bm.verts.new((x + xo, q.y, q.z)) for q in outer])
        rings.append([bm.verts.new((x + xo, q.y, q.z)) for q in inner])
    lo, li, ro, ri = rings
    N = len(pts)
    for i in range(N):
        j = (i + 1) % N
        u0, u1 = us[i], us[i] if j == 0 else us[j]
        if j == 0:
            u1 = 1.0
        for quad, vv in (((lo[i], ro[i], ro[j], lo[j]), (0, 1)), ((li[j], ri[j], ri[i], li[i]), (0, 1)),
                         ((lo[j], li[j], li[i], lo[i]), (0, 0.1)), ((ro[i], ri[i], ri[j], ro[j]), (0.9, 1))):
            f = bm.faces.new(quad)
            f[uv] if False else None
            cs = [(u0, vv[0]), (u0, vv[1]), (u1, vv[1]), (u1, vv[0])]
            if quad[0] in (li[j], lo[j]) and quad[0] is not lo[i]:
                cs = [(u1, vv[0]), (u1, vv[1]), (u0, vv[1]), (u0, vv[0])]
            for loop, c in zip(f.loops, cs):
                loop[uv].uv = c
    bm.normal_update()
    o = obj_from_bmesh(name, bm, M_TRACK)
    for poly in o.data.polygons:
        poly.use_smooth = False
    return o


L, W, R = a.length, a.width, a.radius
xs = {"L": -W / 2 + a.track_width / 2, "R": W / 2 - a.track_width / 2}
z = R
front, back = L / 2 - R, -L / 2 + R
for side, x in xs.items():
    track(f"Track_{side}", x, front + R * 0.15, back - R * 0.1, R * 0.95, z + R * 0.12, a.track_width)
    for i in range(a.wheels):
        y = back + (front - back) * (i + 0.5) / a.wheels
        wheel(f"Wheel_{side}_{i}", R * 0.82, a.track_width * 0.7, (x, y, z * 0.88))
    wheel(f"Sprocket_{side}", R * 0.8, a.track_width * 0.6, (x, back - R * 0.1, z + R * 0.12), teeth=10)
    wheel(f"Idler_{side}", R * 0.72, a.track_width * 0.6, (x, front + R * 0.15, z + R * 0.12))

# Kanonenrohr: Ursprung am Ansatz, zeigt nach +Y
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.09, radius2=0.075, depth=a.barrel)
bmesh.ops.translate(bm, vec=(0, 0, a.barrel / 2), verts=bm.verts)
ext = bmesh.new()
bmesh.ops.create_cone(ext, cap_ends=True, segments=16, radius1=0.13, radius2=0.13, depth=0.35)
bmesh.ops.translate(ext, vec=(0, 0, a.barrel * 0.55), verts=ext.verts)
brake = bmesh.new()
bmesh.ops.create_cone(brake, cap_ends=True, segments=8, radius1=0.15, radius2=0.15, depth=0.22)
bmesh.ops.translate(brake, vec=(0, 0, a.barrel - 0.11), verts=brake.verts)
barrel = obj_from_bmesh("Barrel", bm, M_BARREL)
e = obj_from_bmesh("Barrel_ext", ext, M_BARREL)
b2 = obj_from_bmesh("Barrel_brake", brake, M_STEEL)
bpy.ops.object.select_all(action="DESELECT")
for ob in (e, b2, barrel):
    ob.select_set(True)
bpy.context.view_layer.objects.active = barrel
bpy.ops.object.join()
barrel.rotation_euler = (math.radians(-90), 0, 0)
bpy.ops.object.transform_apply(rotation=True)

bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", export_yup=True)
print("FERTIG", a.out, [o.name for o in bpy.context.scene.objects])
