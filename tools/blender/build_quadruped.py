"""Vierpfoten-Einheit: mesh2motion-Tier (dog_shiba|cat|bear_panda) + mesh2motion-Animationen -> 8-Richtungs-Sprite-Sheet
(gleiches Format wie build_modular.py: idle, walk, shoot (Biss), die, idle_a, idle_b).
  blender -b -P build_quadruped.py -- --model dog_shiba --pal shibas --out out/mod/quad_shibas --size 192 [--preview]
Animationen muessen vorher mit blender/meshopt_decode.py nach tools_tmp/anim/<name>.glb entpackt sein
(die Original-GLBs nutzen EXT_meshopt_compression, das Blender 4.5 nicht lesen kann)."""
import bpy, sys, math, os, json
import bmesh
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"--model": "dog_shiba", "--pal": "shibas", "--out": "out/mod/quad", "--size": "192", "--length": "1.7", "--flip": "0",
       "--anim": "tools_tmp/anim", "--models": "C:/Users/anton/Desktop/RTS/assets/animations/quadrupeds/mesh2motion_models",
       "--props": "C:/Users/anton/Desktop/RTS/assets/animations/props",
       "--parts-dir": "out/3d",
       "--tint": "", "--armor": "1", "--export-glb": "",
       "--clip-idle": "idle-alert", "--clip-walk": "run", "--clip-shoot": "bite", "--clip-die": "death",
       "--clip-a": "bark", "--clip-b": "howl"}
for i, v in enumerate(argv):
    if v in opt and i + 1 < len(argv):
        opt[v] = argv[i + 1]
PREVIEW = "--preview" in argv
EXPORT_GLB = opt["--export-glb"]
SIZE = int(opt["--size"])
OUT = opt["--out"]
FAC = opt["--pal"]
PAL = {"shibas": ((0.02, 0.04, 0.11, 1), (0.62, 0.65, 0.7, 1), (0.15, 0.75, 1.0, 1)),
       "katzen": ((0.015, 0.01, 0.035, 1), (0.2, 0.12, 0.32, 1), (0.75, 0.2, 1.0, 1)),
       "baeren": ((0.13, 0.02, 0.015, 1), (0.8, 0.58, 0.14, 1), (1.0, 0.65, 0.12, 1))}[FAC]
# Clip -> (Animationsdatei, Frames, Schleife)
CLIPS = {"idle": (opt["--clip-idle"], 1, True), "walk": (opt["--clip-walk"], 8, True),
         "shoot": (opt["--clip-shoot"], 5, False), "die": (opt["--clip-die"], 8, False),
         "idle_a": (opt["--clip-a"], 10, False), "idle_b": (opt["--clip-b"], 10, False)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{opt['--models']}/{opt['--model']}.glb")
for o in list(bpy.context.scene.objects):
    if o.name.startswith("Icosphere") or (o.type == "MESH" and len(o.vertex_groups) == 0):
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
                            if FAC == "baeren":
                                # Weisses Panda-Fell komplett durch sattes dunkles Grizzly-Braun ersetzen
                                lum = px[..., 0] * 0.3 + px[..., 1] * 0.59 + px[..., 2] * 0.11
                                px[..., 0] = np.where(lum > 0.35, t[0], t[0] * 0.42)
                                px[..., 1] = np.where(lum > 0.35, t[1], t[1] * 0.40)
                                px[..., 2] = np.where(lum > 0.35, t[2], t[2] * 0.38)
                            else:
                                fac = np.array(t[:3], dtype=np.float32)
                                px[..., :3] = np.clip(px[..., :3] * fac, 0.0, 1.0)
                            img.pixels = px.ravel().tolist()
                            img.name = f"quad_coat_{FAC}"
                            img.pack()
                            img["_tinted"] = True
                        # Direkt an Base Color haengen, damit kein VERTEX_COLOR-Mix aufhellt
                        mt.node_tree.links.new(tex_n.outputs["Color"], p.inputs["Base Color"])
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


_QPART_MAT_CACHE = {}


def _import_qpart(path, tint_shiba=False):
    before = set(bpy.context.scene.objects)
    before_imgs = set(bpy.data.images)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    if len(new) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for e in [x for x in bpy.context.scene.objects if x not in before and x.type == "EMPTY"]:
        bpy.data.objects.remove(e, do_unlink=True)
    if path in _QPART_MAT_CACHE:
        for idx_s, slot in enumerate(o.material_slots):
            if idx_s < len(_QPART_MAT_CACHE[path]):
                slot.material = _QPART_MAT_CACHE[path][idx_s]
        for img in [im for im in bpy.data.images if im not in before_imgs]:
            bpy.data.images.remove(img)
    else:
        for slot in o.material_slots:
            mt = slot.material
            if mt and mt.use_nodes:
                nt_m = mt.node_tree
                pb_m = next((n for n in nt_m.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if pb_m:
                    for inp_n in ("Normal", "Metallic", "Roughness"):
                        for lk in list(pb_m.inputs[inp_n].links):
                            nt_m.links.remove(lk)
                    pb_m.inputs["Metallic"].default_value = 0.22
                    pb_m.inputs["Roughness"].default_value = 0.52
                    if tint_shiba:
                        tex_n = next((lk.from_node for lk in pb_m.inputs["Base Color"].links if lk.from_node.type == "TEX_IMAGE"), None)
                        if tex_n and tex_n.image and not tex_n.image.get("_tinted"):
                            import numpy as np
                            im = tex_n.image
                            wi, hi_i = im.size
                            px = np.array(im.pixels[:], dtype=np.float32).reshape(hi_i, wi, 4)
                            px[..., :3] = np.clip(px[..., :3] * 0.65, 0.0, 1.0)
                            im.pixels = px.ravel().tolist()
                            im.pack()
                            im["_tinted"] = True
        _QPART_MAT_CACHE[path] = [s.material for s in o.material_slots]
    if len(o.data.polygons) > 1000:
        dm = o.modifiers.new("Dec", "DECIMATE")
        dm.ratio = 0.25
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=dm.name)
    return o


def _bbox(o):
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def _fit_and_parent(o, target_size, pos_world, bone_name, rot_deg=(0, 0, 0), mirror_x=False):
    if mirror_x:
        o.scale = (-1, 1, 1)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bm_s = bmesh.new()
        bm_s.from_mesh(o.data)
        bmesh.ops.reverse_faces(bm_s, faces=bm_s.faces)
        bm_s.to_mesh(o.data)
        bm_s.free()
    if rot_deg != (0, 0, 0):
        o.rotation_euler = Euler([math.radians(a) for a in rot_deg], "XYZ")
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    lo, hi = _bbox(o)
    s = target_size / max(max(hi - lo), 1e-6)
    o.scale = (s, s, s)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lo, hi = _bbox(o)
    o.location += Vector(pos_world) - (lo + hi) * 0.5
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    parent_to_bone(o, rig.data.bones[bone_name])


def _qbox(pos, scl, mat, bone_name, rot_deg=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    o = bpy.context.active_object
    o.scale = scl
    o.rotation_euler = Euler([math.radians(a) for a in rot_deg], "XYZ")
    o.data.materials.append(mat)
    parent_to_bone(o, rig.data.bones[bone_name])


def _qcyl(pos, rad, dep, mat, bone_name, rot_deg=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=rad, depth=dep, location=pos)
    o = bpy.context.active_object
    o.rotation_euler = Euler([math.radians(a) for a in rot_deg], "XYZ")
    o.data.materials.append(mat)
    parent_to_bone(o, rig.data.bones[bone_name])


def _bmid(bname):
    b = rig.data.bones[bname]
    return (rig.matrix_world @ b.head_local + rig.matrix_world @ b.tail_local) * 0.5


# ---------- Volle Cyber-Kampfmaschinen-Ausrüstung (Exoskelett, Schulterpanzer, 4 Beinschienen, Visier, Zwillings-Geschütze) ----------
if opt["--armor"] == "1":
    plate = mat_flat("plate", PAL[1], 0.25 if EXPORT_GLB else 0.7, 0.45 if EXPORT_GLB else 0.35)
    dark_m = mat_flat("dark_m", (0.08, 0.09, 0.11, 1), 0.30, 0.48)
    glow = mat_flat("glowp", PAL[2], 0.0, 0.25, PAL[2])
    pdir = opt["--parts-dir"]
    is_shiba = (FAC == "shibas")
    ch_path = f"{pdir}/armor_chest_LowPoly_Textured_00001_.glb" if is_shiba else f"{pdir}/fa_{FAC}_chest_a_LowPoly_Textured_00001_.glb"
    sh_path = f"{pdir}/armor_shoulder_LowPoly_Textured_00001_.glb" if is_shiba else f"{pdir}/fa_{FAC}_shoulder_LowPoly_Textured_00001_.glb"
    sn_path = f"{pdir}/armor_shin_LowPoly_Textured_00001_.glb" if is_shiba else f"{pdir}/fa_{FAC}_shin_LowPoly_Textured_00001_.glb"
    w_name = {"shibas": "SMG", "katzen": "Sniper", "baeren": "ShortCannon"}[FAC]
    w_path = f"{opt['--props']}/{w_name}.glb"

    u = k * 2.0  # Skalierungsfaktor der Tiergroesse

    # 1. Schwerer Torso-Exopanzer auf spine_2 und chest
    sp_mid = _bmid("spine_2")
    ch_mid = _bmid("chest")
    if os.path.exists(ch_path):
        c_obj = _import_qpart(ch_path, is_shiba)
        _fit_and_parent(c_obj, 0.50 * u, sp_mid + Vector((0, -0.04 * u, 0.08 * u)), "spine_2", rot_deg=(80, 0, 0))

    # Gepanzerter Reaktor-Rueckenkamm + Leuchtstreifen
    _qbox(sp_mid + Vector((0, 0.02 * u, 0.20 * u)), (0.26 * u, 0.46 * u, 0.08 * u), dark_m, "spine_2")
    _qbox(sp_mid + Vector((0, 0.02 * u, 0.245 * u)), (0.12 * u, 0.42 * u, 0.04 * u), glow, "spine_2")

    # 2. Schulter-Pauldrons vorne links/rechts + Flankenpanzer hinten links/rechts
    if os.path.exists(sh_path):
        for sign, bname in ((1, "front_leg_shoulder_l"), (-1, "front_leg_shoulder_r")):
            s_obj = _import_qpart(sh_path, is_shiba)
            _fit_and_parent(s_obj, 0.34 * u, _bmid(bname) + Vector((sign * 0.09 * u, -0.02 * u, 0.02 * u)), bname, mirror_x=(sign < 0))
        for sign, bname in ((1, "back_leg_upper_l"), (-1, "back_leg_upper_r")):
            h_obj = _import_qpart(sh_path, is_shiba)
            _fit_and_parent(h_obj, 0.30 * u, _bmid(bname) + Vector((sign * 0.07 * u, 0.02 * u, 0.04 * u)), bname, mirror_x=(sign < 0))

    # 3. Kybernetische Beinschienen an allen 4 Unterschenkeln + Leuchtgelenke
    if os.path.exists(sn_path):
        for bname in ("front_leg_lower_l", "front_leg_lower_r", "back_leg_lower_l", "back_leg_lower_r"):
            sn_obj = _import_qpart(sn_path, is_shiba)
            _fit_and_parent(sn_obj, 0.24 * u, _bmid(bname), bname)
            _qcyl(_bmid(bname), 0.055 * u, 0.03 * u, glow, bname)

    # 4. Zwillings-Schultergeschuetze (echte 3D-Waffen aus props/ + glühende Mündungs-/Energieringe)
    if os.path.exists(w_path):
        import numpy as np
        for sign in (1, -1):
            w_obj = _import_qpart(w_path, False)
            co = np.array([tuple(w_obj.matrix_world @ vv.co) for vv in w_obj.data.vertices])
            cen = co.mean(axis=0)
            w_eig, vecs = np.linalg.eigh(np.cov((co - cen).T))
            main = Vector(tuple(vecs[:, int(np.argmax(w_eig))]))
            if main.y > 0:
                main = -main
            w_obj.rotation_mode = "QUATERNION"
            w_obj.rotation_quaternion = main.rotation_difference(Vector((0, -1, 0)))
            bpy.ops.object.select_all(action="DESELECT")
            w_obj.select_set(True)
            bpy.context.view_layer.objects.active = w_obj
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            w_len = 0.56 * u if FAC != "katzen" else 0.68 * u
            mount_pos = sp_mid + Vector((sign * 0.22 * u, -0.08 * u, 0.19 * u))
            _fit_and_parent(w_obj, w_len, mount_pos, "spine_2")
            # Waffenhalterung + leuchtender Energiekern am Geschütz
            _qbox(mount_pos + Vector((-sign * 0.05 * u, 0.04 * u, -0.02 * u)), (0.08 * u, 0.14 * u, 0.08 * u), plate, "spine_2")
            _qcyl(mount_pos + Vector((0, -0.14 * u, 0)), 0.042 * u, 0.08 * u, glow, "spine_2", rot_deg=(90, 0, 0))

    # 5. Gepanzerter Cyber-Kopfhelm, Leucht-Visier über den Augen & Kybernetik-Unterkiefer
    hd_b = rig.data.bones["head"]
    hd_head = rig.matrix_world @ hd_b.head_local
    hd_tail = rig.matrix_world @ hd_b.tail_local
    hd_mid = (hd_head + hd_tail) * 0.5
    # Schädel-Panzerplatte
    _qbox(hd_mid + Vector((0, 0.02 * u, 0.14 * u)), (0.24 * u, 0.24 * u, 0.055 * u), plate, "head", rot_deg=(12, 0, 0))
    # Glühendes Cyber-Visier quer über die Augenpartie
    _qbox(hd_mid + Vector((0, -0.04 * u, 0.08 * u)), (0.28 * u, 0.12 * u, 0.065 * u), glow, "head", rot_deg=(15, 0, 0))
    _qbox(hd_mid + Vector((0, -0.03 * u, 0.085 * u)), (0.30 * u, 0.09 * u, 0.04 * u), dark_m, "head", rot_deg=(15, 0, 0))
    # Gepanzerter Cyber-Unterkiefer
    if "mouth" in rig.data.bones:
        m_mid = _bmid("mouth")
        _qbox(m_mid + Vector((0, -0.02 * u, -0.02 * u)), (0.18 * u, 0.20 * u, 0.05 * u), dark_m, "mouth")
        _qbox(m_mid + Vector((0, -0.06 * u, -0.02 * u)), (0.20 * u, 0.06 * u, 0.055 * u), glow, "mouth")

if EXPORT_GLB:
    for o in list(bpy.context.scene.objects):
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "MESH":
            o.data.validate()
    for img in bpy.data.images:
        if img.size[0] > 256 or img.size[1] > 256:
            img.scale(256, 256)
    rig.location = (0, 0, 0)
    used_acts = {}
    for clip, (name, _, _) in CLIPS.items():
        act = ACT[name].copy()
        act.name = clip
        act.use_fake_user = True
        used_acts[clip] = act
        rig.animation_data.action = act
        if hasattr(rig.animation_data, "action_slot") and len(act.slots) > 0:
            rig.animation_data.action_slot = act.slots[0]
        tr = rig.animation_data.nla_tracks.new()
        tr.name = clip
        st = tr.strips.new(clip, int(act.frame_range[0]), act)
        st.name = clip
        tr.mute = True
    rig.animation_data.action = used_acts["idle"]
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
