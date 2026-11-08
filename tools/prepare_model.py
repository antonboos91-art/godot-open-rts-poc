"""Bereitet ein Bild-zu-3D-Modell (GLB) fuer Godot vor:
- Polygone auf ein Ziel reduzieren (Decimate), Textur bleibt erhalten
- auf Spielgroesse skalieren (laengste Grundflaechen-Kante = --size Meter)
- Ursprung unten mittig, Blickrichtung -Z (Godot-Vorne)
Aufruf:
  blender -b -P prepare_model.py -- --in tesla_raw.glb --out shibas_tesla.glb --size 4.2 --max-tris 6000 [--yaw 0]
"""
import bpy, sys, math, argparse
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument("--in", dest="inp", required=True)
p.add_argument("--out", required=True)
p.add_argument("--size", type=float, default=4.0)
p.add_argument("--max-tris", type=int, default=6000)
p.add_argument("--yaw", type=float, default=0.0, help="Drehung um die Hochachse in Grad")
a = p.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("keine Meshes gefunden")

# Alles zu einem Objekt zusammenfuehren und Transformationen anwenden
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Polygone reduzieren
tris = sum(len(poly.vertices) - 2 for poly in obj.data.polygons)
if tris > a.max_tris:
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.ratio = a.max_tris / tris
    bpy.ops.object.modifier_apply(modifier=mod.name)
new_tris = sum(len(poly.vertices) - 2 for poly in obj.data.polygons)

# Groesse und Ursprung (Blender: Z hoch)
bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
footprint = max(hi.x - lo.x, hi.y - lo.y)
scale = a.size / max(footprint, 1e-6)
obj.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
bpy.ops.object.transform_apply(location=True)
obj.scale = (scale, scale, scale)
obj.rotation_euler = (0, 0, math.radians(a.yaw))
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.shade_smooth()

bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=False, export_yup=True)
print(f"FERTIG {a.out}: {tris} -> {new_tris} Dreiecke, Massstab {scale:.3f}")
