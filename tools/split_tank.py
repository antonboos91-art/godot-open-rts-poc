"""Zerlegt ein fertiges KI-Panzermodell (GLB, vorne = +Y, Boden = 0) in Wanne und Turm
und schneidet das Fahrwerk unten ab (wird durch make_running_gear.py ersetzt).
  blender -b -P split_tank.py -- --in tesla.glb --out-hull hull.glb --out-turret turret.glb --cut 0.30 --turret 0.58
--cut / --turret: Höhen als Anteil der Modellhöhe. Gibt Maße (Länge/Breite/Höhen) als JSON aus.
"""
import bpy, bmesh, sys, json, argparse
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument("--in", dest="inp", required=True)
p.add_argument("--out-hull", required=True)
p.add_argument("--out-turret", required=True)
p.add_argument("--cut", type=float, default=0.30)
p.add_argument("--turret", type=float, default=0.58)
a = p.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
zs = [v.co.z for v in obj.data.vertices]
zs_sorted = sorted(zs)
H = zs_sorted[int(len(zs_sorted) * 0.97)]  # ohne Antennen
xs = [v.co.x for v in obj.data.vertices]
ys = [v.co.y for v in obj.data.vertices]
cut_z, tur_z = H * a.cut, H * a.turret


def keep_between(src, z0, z1, name):
    o = src.copy()
    o.data = src.data.copy()
    o.name = name
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for z, keep_above in ((z0, True), (z1, False)):
        if z is None:
            continue
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1),
                               clear_inner=keep_above, clear_outer=not keep_above)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(o.data)
    bm.free()
    return o


hull = keep_between(obj, cut_z, tur_z, "Hull")
turret = keep_between(obj, tur_z, None, "Turret")
bpy.data.objects.remove(obj)


def drop_small_islands(o, min_share=0.03):
    """Entfernt lose Splitter (z. B. abgeschnittene Antennenreste) unter min_share der Vertices."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    seen, islands = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, isl = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            isl.append(cur)
            for e in cur.link_edges:
                w = e.other_vert(cur)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        islands.append(isl)
    total = len(bm.verts)
    kill = [v for isl in islands if len(isl) < total * min_share for v in isl]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()


drop_small_islands(turret)

# Dunkle Abdeckplatte unter dem Turm, damit man nicht in die hohle Wanne schaut
plate_mat = bpy.data.materials.new("TurretRing")
plate_mat.use_nodes = True
plate_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.07, 0.16, 1)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1)
hv = [hull.matrix_world @ v.co for v in hull.data.vertices]
hx = (max(v.x for v in hv) - min(v.x for v in hv)) * 0.86
hy = (max(v.y for v in hv) - min(v.y for v in hv)) * 0.86
bmesh.ops.scale(bm, vec=(hx, hy, 0.04), verts=bm.verts)
bmesh.ops.translate(bm, vec=((max(v.x for v in hv) + min(v.x for v in hv)) / 2,
                             (max(v.y for v in hv) + min(v.y for v in hv)) / 2, tur_z - 0.03), verts=bm.verts)
plate_me = bpy.data.meshes.new("Plate")
bm.to_mesh(plate_me)
bm.free()
hull.data.materials.append(plate_mat) if False else None
plate = bpy.data.objects.new("Plate", plate_me)
plate_me.materials.append(plate_mat)
bpy.context.scene.collection.objects.link(plate)
bpy.ops.object.select_all(action="DESELECT")
plate.select_set(True)
hull.select_set(True)
bpy.context.view_layer.objects.active = hull
bpy.ops.object.join()


def export(o, path):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True)


# Turm: Drehpunkt in die Mitte seiner Grundfläche legen
tv = [turret.matrix_world @ v.co for v in turret.data.vertices]
if tv:
    cx = (min(v.x for v in tv) + max(v.x for v in tv)) / 2
    cy_core = sorted(v.y for v in tv)
    # Mitte ohne das nach vorne ragende Rohr: Median statt Bounding-Box
    cy = cy_core[len(cy_core) // 2]
    pivot = Vector((cx, cy, tur_z))
    for v in turret.data.vertices:
        v.co -= pivot
else:
    pivot = Vector((0, 0, tur_z))
export(hull, a.out_hull)
export(turret, a.out_turret)
info = {"length": max(ys) - min(ys), "width": max(xs) - min(xs), "height": H, "cut_z": cut_z,
        "turret_z": tur_z, "turret_pivot": [pivot.x, pivot.y, pivot.z]}
print("MASSE " + json.dumps(info))
