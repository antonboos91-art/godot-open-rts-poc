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


# ---------- Verwitterung (Dark-Reign-Look): abgekaempft, dreckig, dunkel ----------
# Jedes Principled-Material bekommt: dunklere, entsaettigte Grundfarbe, Dreck in Ritzen (AO),
# fleckigen Staub/Russ (Rauschen), Rost-Spuren, Schlamm unten am Fahrzeug, helle Kratzer an Kanten.
# Leuchtteile (Emission) bleiben unberuehrt. Abschalten: Umgebungsvariable WEATHER=0
def weather_materials():
    if os.environ.get("WEATHER", "1") == "0":
        return
    done = set()
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        for slot in o.material_slots:
            m = slot.material
            if m is None or m.name in done or not m.use_nodes:
                continue
            done.add(m.name)
            nt = m.node_tree
            pb = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if pb is None:
                continue
            em = pb.inputs["Emission Strength"].default_value if "Emission Strength" in pb.inputs else 0.0
            if em > 0.5 and not pb.inputs["Emission Strength"].links:
                continue  # Lampen / Leuchtstreifen
            bc = pb.inputs["Base Color"]
            src = bc.links[0].from_socket if bc.links else None
            base = nt.nodes.new("ShaderNodeRGB")
            base.outputs[0].default_value = bc.default_value
            col = src if src is not None else base.outputs[0]
            # dunkler + entsaettigt
            hsv = nt.nodes.new("ShaderNodeHueSaturation")
            hsv.inputs["Saturation"].default_value = 0.7
            hsv.inputs["Value"].default_value = 0.42
            nt.links.new(col, hsv.inputs["Color"])
            tc = nt.nodes.new("ShaderNodeTexCoord")
            # fleckiger Staub/Russ
            noise = nt.nodes.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 3.5
            noise.inputs["Detail"].default_value = 8.0
            nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].position = 0.42
            ramp.color_ramp.elements[1].position = 0.72
            nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
            dirt = nt.nodes.new("ShaderNodeMix")
            dirt.data_type = "RGBA"
            dirt.inputs[7].default_value = (0.09, 0.075, 0.06, 1)
            nt.links.new(hsv.outputs[0], dirt.inputs[6])
            mulf = nt.nodes.new("ShaderNodeMath")
            mulf.operation = "MULTIPLY"
            mulf.inputs[1].default_value = 0.75
            nt.links.new(ramp.outputs[0], mulf.inputs[0])
            nt.links.new(mulf.outputs[0], dirt.inputs[0])
            # Dreck + Rost in Ritzen (Ambient Occlusion)
            ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
            ao.inputs["Distance"].default_value = 0.25
            inv = nt.nodes.new("ShaderNodeMath")
            inv.operation = "SUBTRACT"
            inv.inputs[0].default_value = 1.0
            nt.links.new(ao.outputs["AO"], inv.inputs[1])
            cav = nt.nodes.new("ShaderNodeMath")
            cav.operation = "MULTIPLY"
            cav.inputs[1].default_value = 1.6
            cav.use_clamp = True
            nt.links.new(inv.outputs[0], cav.inputs[0])
            rust = nt.nodes.new("ShaderNodeMix")
            rust.data_type = "RGBA"
            rust.inputs[7].default_value = (0.16, 0.07, 0.03, 1)
            nt.links.new(dirt.outputs[2], rust.inputs[6])
            nt.links.new(cav.outputs[0], rust.inputs[0])
            # Schlamm unten (Objekt-Hoehe)
            sep = nt.nodes.new("ShaderNodeSeparateXYZ")
            nt.links.new(tc.outputs["Generated"], sep.inputs[0])
            mud_mask = nt.nodes.new("ShaderNodeMapRange")
            mud_mask.inputs["From Min"].default_value = 0.35
            mud_mask.inputs["From Max"].default_value = 0.0
            nt.links.new(sep.outputs["Z"], mud_mask.inputs["Value"])
            mud_noise = nt.nodes.new("ShaderNodeMath")
            mud_noise.operation = "MULTIPLY"
            nt.links.new(mud_mask.outputs[0], mud_noise.inputs[0])
            nt.links.new(noise.outputs["Fac"], mud_noise.inputs[1])
            mud_k = nt.nodes.new("ShaderNodeMath")
            mud_k.operation = "MULTIPLY"
            mud_k.inputs[1].default_value = 1.6
            mud_k.use_clamp = True
            nt.links.new(mud_noise.outputs[0], mud_k.inputs[0])
            mud = nt.nodes.new("ShaderNodeMix")
            mud.data_type = "RGBA"
            mud.inputs[7].default_value = (0.11, 0.085, 0.055, 1)
            nt.links.new(rust.outputs[2], mud.inputs[6])
            nt.links.new(mud_k.outputs[0], mud.inputs[0])
            # helle Kratzer an Kanten (Bevel-Normale gegen Flaechennormale)
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            bev = nt.nodes.new("ShaderNodeBevel")
            bev.inputs["Radius"].default_value = 0.03
            dot = nt.nodes.new("ShaderNodeVectorMath")
            dot.operation = "DOT_PRODUCT"
            nt.links.new(geo.outputs["Normal"], dot.inputs[0])
            nt.links.new(bev.outputs["Normal"], dot.inputs[1])
            edge = nt.nodes.new("ShaderNodeMapRange")
            edge.inputs["From Min"].default_value = 0.97
            edge.inputs["From Max"].default_value = 0.85
            nt.links.new(dot.outputs["Value"], edge.inputs["Value"])
            scratch_n = nt.nodes.new("ShaderNodeTexNoise")
            scratch_n.inputs["Scale"].default_value = 22.0
            nt.links.new(tc.outputs["Object"], scratch_n.inputs["Vector"])
            edge_k = nt.nodes.new("ShaderNodeMath")
            edge_k.operation = "MULTIPLY"
            nt.links.new(edge.outputs[0], edge_k.inputs[0])
            nt.links.new(scratch_n.outputs["Fac"], edge_k.inputs[1])
            wear = nt.nodes.new("ShaderNodeMix")
            wear.data_type = "RGBA"
            wear.inputs[7].default_value = (0.3, 0.29, 0.27, 1)
            nt.links.new(mud.outputs[2], wear.inputs[6])
            edge_s = nt.nodes.new("ShaderNodeMath")
            edge_s.operation = "MULTIPLY"
            edge_s.inputs[1].default_value = 0.45
            nt.links.new(edge_k.outputs[0], edge_s.inputs[0])
            nt.links.new(edge_s.outputs[0], wear.inputs[0])
            nt.links.new(wear.outputs[2], bc)
            # matter, ausser an Kratzern
            if not pb.inputs["Roughness"].links:
                r = pb.inputs["Roughness"].default_value
                pb.inputs["Roughness"].default_value = max(r, 0.72)


weather_materials()

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
