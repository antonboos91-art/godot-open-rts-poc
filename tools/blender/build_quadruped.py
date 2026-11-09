"""Vierpfoten-Einheit: mesh2motion-Tier (dog_shiba|cat|bear_panda) + mesh2motion-Animationen -> 8-Richtungs-Sprite-Sheet
(gleiches Format wie build_modular.py: idle, walk, shoot (Biss), die, idle_a, idle_b).
  blender -b -P build_quadruped.py -- --model dog_shiba --pal shibas --out out/mod/quad_shibas --size 192 [--preview]
Animationen muessen vorher mit blender/meshopt_decode.py nach tools_tmp/anim/<name>.glb entpackt sein
(die Original-GLBs nutzen EXT_meshopt_compression, das Blender 4.5 nicht lesen kann)."""
import bpy, sys, math, os, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"--model": "dog_shiba", "--pal": "shibas", "--out": "out/mod/quad", "--size": "192", "--length": "1.7", "--flip": "0",
       "--anim": "tools_tmp/anim", "--models": "C:/Users/anton/Desktop/RTS/assets/animations/quadrupeds/mesh2motion_models",
       "--tint": "", "--armor": "1", "--export-glb": ""}
for i, v in enumerate(argv):
    if v in opt and i + 1 < len(argv):
        opt[v] = argv[i + 1]
PREVIEW = "--preview" in argv
EXPORT_GLB = opt["--export-glb"]
SIZE = int(opt["--size"])
OUT = opt["--out"]
PAL = {"shibas": ((0.02, 0.04, 0.11, 1), (0.62, 0.65, 0.7, 1), (0.15, 0.75, 1.0, 1)),
       "katzen": ((0.015, 0.01, 0.035, 1), (0.2, 0.12, 0.32, 1), (0.75, 0.2, 1.0, 1)),
       "baeren": ((0.13, 0.02, 0.015, 1), (0.8, 0.58, 0.14, 1), (1.0, 0.65, 0.12, 1))}[opt["--pal"]]
# Clip -> (Animationsdatei, Frames, Schleife)
CLIPS = {"idle": ("idle", 1, True), "walk": ("trot", 8, True), "shoot": ("bite", 5, False), "die": ("death", 8, False),
         "idle_a": ("scratch-ear", 10, False), "idle_b": ("bark", 10, False)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{opt['--models']}/{opt['--model']}.glb")
for o in list(bpy.context.scene.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
rig = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
rig.animation_data_create()

# Animationen laden (nur die Actions behalten)
ACT = {}
for name in {c[0] for c in CLIPS.values()}:
    before_o = set(bpy.context.scene.objects)
    before_a = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=f"{opt['--anim']}/{name}.glb")
    new_a = [a for a in bpy.data.actions if a not in before_a]
    ACT[name] = new_a[0]
    ACT[name].use_fake_user = True
    for o in [o for o in bpy.context.scene.objects if o not in before_o]:
        bpy.data.objects.remove(o, do_unlink=True)

# Groesse: Koerperlaenge (Y) auf --length Meter
bb = [rig.matrix_world @ v.co for m in meshes for v in m.data.vertices]
ylen = max(p.y for p in bb) - min(p.y for p in bb)
k = float(opt["--length"]) / ylen
rig.scale = (k, k, k)
if opt["--flip"] == "1":
    rig.rotation_euler = (0, 0, math.pi)
bpy.context.view_layer.update()


def mat_flat(name, color, metal=0.7, rough=0.35, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = color
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = emit
        p.inputs["Emission Strength"].default_value = 3.0
    return m


def parent_to_bone(o, b):
    if EXPORT_GLB:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        vg = o.vertex_groups.new(name=b.name)
        vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
        o.parent = rig
        o.matrix_parent_inverse = rig.matrix_world.inverted()
        mod = o.modifiers.new(name="Armature", type="ARMATURE")
        mod.object = rig
        return
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    rig.data.bones.active = b
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)


# Fell optional einfaerben
if opt["--tint"]:
    t = [float(x) for x in opt["--tint"].split(",")]
    for m in meshes:
        for slot in m.material_slots:
            mt = slot.material
            if mt and mt.use_nodes:
                p = next((n for n in mt.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if p is None:
                    continue
                if EXPORT_GLB:
                    for tex_n in [n for n in mt.node_tree.nodes if n.type == "TEX_IMAGE"]:
                        if tex_n.image and not tex_n.image.get("_tinted"):
                            import numpy as np
                            img = tex_n.image
                            w_i, h_i = img.size
                            px = np.array(img.pixels[:], dtype=np.float32).reshape(h_i, w_i, 4)
                            fac = np.array([max(c, 0.0) ** (1.0 / 2.2) for c in t[:3]], dtype=np.float32)
                            px[..., :3] = np.clip(px[..., :3] * fac, 0.0, 1.0)
                            img.pixels = px.ravel().tolist()
                            img.pack()
                            img["_tinted"] = True
                    continue
                nt = mt.node_tree
                mix = nt.nodes.new("ShaderNodeMix")
                mix.data_type = "RGBA"
                mix.blend_type = "MULTIPLY"
                mix.inputs[0].default_value = 1.0
                mix.inputs[7].default_value = (t[0], t[1], t[2], 1)
                if p.inputs["Base Color"].links:
                    nt.links.new(p.inputs["Base Color"].links[0].from_socket, mix.inputs[6])
                else:
                    mix.inputs[6].default_value = p.inputs["Base Color"].default_value
                nt.links.new(mix.outputs[2], p.inputs["Base Color"])

# Panzerplatten auf dem Ruecken (starr an Knochen) + leuchtender Streifen
if opt["--armor"] == "1":
    plate = mat_flat("plate", PAL[1], 0.25 if EXPORT_GLB else 0.7, 0.45 if EXPORT_GLB else 0.35)
    glow = mat_flat("glowp", PAL[2], 0.0, 0.3, PAL[2])
    for bone, wid, ln, up in (("spine_2", 0.16, 0.3, 0.2), ("chest", 0.18, 0.28, 0.22)):
        b = rig.data.bones[bone]
        mid = (rig.matrix_world @ b.head_local + rig.matrix_world @ b.tail_local) / 2
        pos = mid + Vector((0, 0, up * k * 2.0))
        sx, sy, sz = wid * k * 2.0, ln * k * 2.0, 0.05 * k * 2.0
        bpy.ops.mesh.primitive_cube_add()
        o = bpy.context.active_object
        o.scale = (sx, sy, sz)
        o.location = pos
        o.data.materials.append(plate)
        parent_to_bone(o, b)
        bpy.ops.mesh.primitive_cube_add()
        g = bpy.context.active_object
        g.scale = (sx * 0.22, sy * 1.03, sz * 0.6)
        g.location = pos + Vector((0, 0, sz * 0.9))
        g.data.materials.append(glow)
        parent_to_bone(g, b)

if EXPORT_GLB:
    for o in list(bpy.context.scene.objects):
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
    for img in bpy.data.images:
        if img.size[0] > 512 or img.size[1] > 512:
            img.scale(512, 512)
    rig.location = (0, 0, 0)
    for clip, (name, _, _) in CLIPS.items():
        act = ACT[name]
        act.name = clip
        act.use_fake_user = True
        rig.animation_data.action = act
        if hasattr(rig.animation_data, "action_slot") and len(act.slots) > 0:
            rig.animation_data.action_slot = act.slots[0]
        tr = rig.animation_data.nla_tracks.new()
        tr.name = clip
        st = tr.strips.new(clip, int(act.frame_range[0]), act)
        st.name = clip
        tr.mute = True
    rig.animation_data.action = ACT[CLIPS["idle"][0]]
    if hasattr(rig.animation_data, "action_slot") and len(rig.animation_data.action.slots) > 0:
        rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    bpy.context.scene.frame_set(int(rig.animation_data.action.frame_range[0]))
    bpy.context.view_layer.update()
    os.makedirs(os.path.dirname(os.path.abspath(EXPORT_GLB)), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(EXPORT_GLB),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_optimize_animation_size=True,
        export_anim_slide_to_zero=True,
        export_image_format="JPEG",
        export_jpeg_quality=85,
    )
    print("GLB", EXPORT_GLB, os.path.getsize(EXPORT_GLB))
    sys.exit(0)

# ---------- Kamera / Licht (wie build_modular) ----------
scn = bpy.context.scene
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 3.3
cam = bpy.data.objects.new("cam", cam_d)
scn.collection.objects.link(cam)
pitch = math.radians(35)
target = Vector((0, 0, 0.45))
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
    name, _, loop = CLIPS[clip]
    act = ACT[name]
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
    root = rig.pose.bones.get("root")
    if root is not None and clip != "die":
        root.location = (0, 0, 0)
    # Tier in Bildmitte halten (Huefte)
    hp = (rig.matrix_world @ rig.pose.bones["hips"].head + rig.matrix_world @ rig.pose.bones["head"].head) / 2
    f = 1.0 if clip != "die" else 0.7
    rig.location = (-hp.x * f, -hp.y * f, 0)
    bpy.context.view_layer.update()


if PREVIEW:
    for clip, (a, n, loop) in CLIPS.items():
        for i in range(0, n, max(1, n // 2)):
            pose_clip(clip, i, n)
            place_cam(45)
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
