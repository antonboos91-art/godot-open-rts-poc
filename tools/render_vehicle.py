"""Rendert ein Skript-Fahrzeug Factorio-artig mit Cycles.
  blender -b -P render_vehicle.py -- --model tank_tesla --mode preview --out ../out/veh/tesla
  blender -b -P render_vehicle.py -- --model tank_tesla --mode sheet --out ../game/assets/sprites/units/shibas_tesla --dirs 64 --size 192
preview: 4 große Ansichten (PNG).  sheet: <out>_hull.png (Zeilen = Kettenframes, Spalten = Richtungen),
<out>_turret.png (eine Zeile, Spalten = Richtungen). Kamera wie im Spiel: orthografisch, 30 Grad Neigung.
Richtung 0 = Fahrzeug zeigt von der Kamera weg (Spiel -Z), dann im Uhrzeigersinn von oben gesehen.
"""
import bpy, sys, os, math, argparse, importlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument("--model", default="tank_tesla")
p.add_argument("--mode", default="preview")
p.add_argument("--out", required=True)
p.add_argument("--dirs", type=int, default=64)
p.add_argument("--size", type=int, default=192)
p.add_argument("--track-frames", type=int, default=4)
p.add_argument("--samples", type=int, default=48)
p.add_argument("--ortho", type=float, default=3.6, help="sichtbare Breite in Metern")
a = p.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
model = importlib.import_module(a.model)
colls = model.build()

sc = bpy.context.scene
sc.render.engine = "CYCLES"
prefs = bpy.context.preferences.addons["cycles"].preferences
for dev_type in ("OPTIX", "CUDA"):
    try:
        prefs.compute_device_type = dev_type
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
        break
    except Exception:
        continue
sc.cycles.samples = a.samples
sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in sc.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
sc.view_settings.look = "AgX - Medium High Contrast" if sc.view_settings.view_transform == "AgX" else "None"

# Licht: Sonne von links oben + weiches Himmelslicht
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.6, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
sc.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.data.angle = math.radians(8)
sun.rotation_euler = (math.radians(40), math.radians(-25), math.radians(35))
sc.collection.objects.link(sun)
# Schattenfänger-Boden
bpy.ops.mesh.primitive_plane_add(size=20)
ground = bpy.context.active_object
ground.is_shadow_catcher = True
if getattr(model, "NO_SHADOW", False):
    ground.hide_render = True  # Fluggeräte: kein Bodenschatten direkt darunter

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = a.ortho
sc.collection.objects.link(cam)
sc.camera = cam
PITCH = math.radians(60)  # Spielkamera blickt 60 Grad nach unten
TARGET_Z = 0.45


def set_camera(dir_index, n_dirs):
    """Kamera kreist um das Fahrzeug; Richtung 0 = Kamera hinter dem Fahrzeug (Spiel: Fahrzeug zeigt weg)."""
    yaw = 2 * math.pi * dir_index / n_dirs
    d = 20.0
    # Fahrzeug vorne = +Y. Kamera bei Richtung 0 auf -Y (dahinter), blickt nach +Y.
    cx = math.sin(yaw) * math.cos(PITCH) * d
    cy = -math.cos(yaw) * math.cos(PITCH) * d
    cz = math.sin(PITCH) * d + TARGET_Z
    cam.location = (cx, cy, cz)
    direction = (0 - cx, 0 - cy, TARGET_Z - cz)
    from mathutils import Vector
    cam.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()


def show(names):
    for c in colls.values():
        c.hide_render = c.name not in names


def render(path):
    sc.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)


os.makedirs(os.path.dirname(os.path.abspath(a.out)) or ".", exist_ok=True)
if a.mode == "preview":
    sc.render.resolution_x = sc.render.resolution_y = 768
    show(["HULL", "TRACKS", "TURRET"])
    for i, k in enumerate([0, 3, 5, 8]):  # verschiedene Ansichten
        set_camera(k, 16)
        render(f"{a.out}_view{i}.png")

if a.mode == "sheet":
    sc.render.resolution_x = sc.render.resolution_y = a.size
    tmp = os.path.abspath(a.out) + "_frames"
    os.makedirs(tmp, exist_ok=True)
    loop_len = model.TRACK_PITCH
    # Wanne + Ketten: pro Kettenframe alle Richtungen
    show(["HULL", "TRACKS"])
    for f in range(a.track_frames):
        model.place_track(loop_len * f / a.track_frames)
        for d in range(a.dirs):
            set_camera(d, a.dirs)
            render(f"{tmp}/hull_{f:02d}_{d:03d}.png")
    # Turm allein (Schatten nur von der Wanne, damit sich nichts doppelt)
    show(["TURRET"])
    ground.is_shadow_catcher = False
    ground.hide_render = True
    for d in range(a.dirs):
        set_camera(d, a.dirs)
        render(f"{tmp}/turret_{d:03d}.png")
print("FERTIG", a.mode, a.out)
