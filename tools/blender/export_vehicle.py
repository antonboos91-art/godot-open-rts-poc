"""Exportiert ein Skript-Fahrzeug (tank_*.py, wheeled_*.py, heli_*.py) als 3D-Modell (GLB) fuers Spiel.
  FACTION=baeren blender -b -P export_vehicle.py -- --model tank_baeren_grizzly --out ../game/assets/models/vehicles/baeren_grizzly.glb
Aufbau im GLB (Godot-Knoten):
  Hull         Wanne/Rumpf (+ Rotoren rotor_* als eigene Knoten, drehen im Spiel um ihre Hochachse)
  TurretPivot  Turm, dreht im Spiel um Y (Drehpunkt liegt bei allen Modellen ueber dem Ursprung)
  Tracks0..3   Ketten in vier Laufphasen (das Spiel blendet je nach Fahrt eine davon ein)
Vorne = Blender +Y = Godot -Z. Materialien werden fuer den Export vereinfacht (Grundfarbe statt Kanten-Knoten);
die Verwitterung (Dreck, Rost, Schlamm) macht im Spiel source/shaders/3d/vehicle_weathered.gdshader."""
import bpy, sys, os, importlib, argparse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "blender"))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument("--model", required=True)
p.add_argument("--out", required=True)
p.add_argument("--track-frames", type=int, default=4)
a = p.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
model = importlib.import_module(a.model)
colls = model.build()


def flatten_materials():
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        nt = m.node_tree
        pb = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if pb is None:
            continue
        bc = pb.inputs["Base Color"]
        if bc.links:
            src = bc.links[0].from_node
            col = None
            for key in ("Color1", "A"):
                if key in src.inputs and not src.inputs[key].is_linked:
                    v = src.inputs[key].default_value
                    if len(v) >= 3:
                        col = v
                        break
            if col is None and src.type == "MIX":
                col = src.inputs[6].default_value
            nt.links.remove(bc.links[0])
            if col is not None:
                bc.default_value = (col[0], col[1], col[2], 1)


flatten_materials()
bpy.context.view_layer.update()  # matrix_world der frisch gebauten Objekte berechnen
scene = bpy.context.scene


def objects_of(name):
    c = colls.get(name) if isinstance(colls, dict) else bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.get(name)
    return list(c.all_objects) if c is not None else []


def make_root(name):
    e = bpy.data.objects.new(name, None)
    scene.collection.objects.link(e)
    return e


def reparent(objs, parent):
    ids = set(objs)
    for o in objs:
        if o.parent is None or o.parent not in ids:
            mw = o.matrix_world.copy()
            o.parent = parent
            o.matrix_world = mw


hull_root = make_root("Hull")
reparent(objects_of("HULL"), hull_root)
turret_objs = objects_of("TURRET")
if turret_objs:
    pivot = make_root("TurretPivot")
    reparent(turret_objs, pivot)
# Ketten: vier Laufphasen als eigene, zusammengefuegte Meshes
track_objs = [o for o in objects_of("TRACKS") if o.type == "MESH"]
if track_objs and hasattr(model, "place_track") and getattr(model, "TRACK_PITCH", 0) < 0.5:
    for f in range(a.track_frames):
        model.place_track(model.TRACK_PITCH * f / a.track_frames)
        bpy.context.view_layer.update()
        copies = []
        for o in track_objs:
            c = o.copy()
            c.data = o.data.copy()
            scene.collection.objects.link(c)
            c.matrix_world = o.matrix_world.copy()
            c.parent = None
            copies.append(c)
        bpy.ops.object.select_all(action="DESELECT")
        for c in copies:
            c.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.convert(target="MESH")
        if len(copies) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = f"Tracks{f}"
    for o in track_objs:
        bpy.data.objects.remove(o, do_unlink=True)
elif track_objs:
    reparent(track_objs, hull_root)

os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.out), export_format="GLB", export_apply=True,
                          export_extras=True, export_yup=True, use_visible=False)
print("EXPORT", a.out)
