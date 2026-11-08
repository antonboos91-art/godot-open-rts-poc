"""Erzeugt Natur-Sprites (Baeume, Felsen, Busch, Stumpf, Kristalle) als transparente PNGs.
  blender -b -P blender/make_nature.py -- --out game/assets/sprites/nature --size 256
Kamera-Neigung 35 Grad wie die Spielkamera. Fusspunkt der Objekte liegt immer in der gleichen Bildzeile.
"""
import bpy, sys, math, os, random
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = "out/nature"
SIZE = 256
for i, v in enumerate(argv):
    if v == "--out":
        OUT = argv[i + 1]
    if v == "--size":
        SIZE = int(argv[i + 1])


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, c1, c2, scale=6.0, rough=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = rough
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 6
    coord = nt.nodes.new("ShaderNodeTexCoord")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = c1
    ramp.color_ramp.elements[1].color = c2
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def add(obj, m):
    obj.data.materials.append(m)
    return obj


def cone(r, h, z, m, seg=9, jitter=0.0, rng=None):
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r, radius2=0.02, depth=h, location=(0, 0, z + h / 2))
    o = bpy.context.active_object
    if jitter and rng:
        for v in o.data.vertices:
            v.co.x += rng.uniform(-jitter, jitter)
            v.co.y += rng.uniform(-jitter, jitter)
    return add(o, m)


def pine(seed, tall=1.0, c=((0.03, 0.12, 0.04, 1), (0.10, 0.28, 0.09, 1))):
    rng = random.Random(seed)
    trunk = mat("bark", (0.12, 0.07, 0.04, 1), (0.25, 0.15, 0.08, 1), 12)
    bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=0.13, depth=0.9, location=(0, 0, 0.45))
    add(bpy.context.active_object, trunk)
    leaf = mat("pine", c[0], c[1], 5)
    z = 0.5
    for i in range(rng.randint(6, 7)):
        r = (1.0 - i * 0.13) * (0.85 + rng.random() * 0.3)
        h = (0.75 - i * 0.04) * tall
        cone(r, h, z, leaf, 10, 0.07, rng)
        z += h * 0.62


def oak(seed, c=((0.05, 0.18, 0.04, 1), (0.22, 0.42, 0.10, 1))):
    rng = random.Random(seed)
    trunk = mat("bark", (0.12, 0.07, 0.04, 1), (0.28, 0.17, 0.09, 1), 10)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.17, depth=1.2, location=(0, 0, 0.6))
    add(bpy.context.active_object, trunk)
    leaf = mat("oak", c[0], c[1], 4)
    for (dx, dy, dz, r) in [(0, 0, 1.7, 0.95), (0.55, 0.1, 1.45, 0.65), (-0.5, -0.15, 1.5, 0.7), (0.1, 0.5, 1.4, 0.6), (-0.1, -0.5, 1.75, 0.6)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r * (0.9 + rng.random() * 0.2), location=(dx, dy, dz))
        o = bpy.context.active_object
        for v in o.data.vertices:
            v.co += Vector((rng.uniform(-.08, .08), rng.uniform(-.08, .08), rng.uniform(-.08, .08)))
        add(o, leaf)


def dead(seed):
    rng = random.Random(seed)
    m = mat("dead", (0.10, 0.08, 0.06, 1), (0.30, 0.24, 0.17, 1), 10)
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.2, radius2=0.07, depth=1.8, location=(0, 0, 0.9))
    add(bpy.context.active_object, m)
    for i in range(3):
        a = rng.uniform(0, 6.28)
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.07, radius2=0.015, depth=0.9,
                                        location=(math.cos(a) * 0.3, math.sin(a) * 0.3, 1.1 + i * 0.2),
                                        rotation=(math.sin(a) * 0.9, -math.cos(a) * 0.9, 0))
        add(bpy.context.active_object, m)


def rock(seed, size=1.0, c=((0.10, 0.09, 0.09, 1), (0.42, 0.38, 0.34, 1))):
    rng = random.Random(seed)
    m = mat("rock", c[0], c[1], 3, 0.8)
    for k in range(rng.randint(1, 3)):
        off = 0.6 if k > 0 else 0.0
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=size * (0.9 if k == 0 else 0.5),
                                              location=(rng.uniform(-1, 1) * off, rng.uniform(-1, 1) * off, 0.35 * size))
        o = bpy.context.active_object
        o.scale = (1.0 + rng.random() * .4, 1.0 + rng.random() * .4, 0.7)
        for v in o.data.vertices:
            v.co *= 1 + rng.uniform(-.22, .22)
        add(o, m)


def bush(seed):
    rng = random.Random(seed)
    m = mat("bush", (0.06, 0.16, 0.05, 1), (0.25, 0.40, 0.12, 1), 6)
    for k in range(4):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.4 + rng.random() * .15,
                                              location=(rng.uniform(-.4, .4), rng.uniform(-.4, .4), 0.28))
        add(bpy.context.active_object, m)


def crystals(seed, base=(0.1, 0.5, 0.9, 1), emit=(0.2, 0.7, 1.0, 1)):
    """Erz-/Schrottfeld: Kristallgruppe in leuchtendem Tuerkis auf dunklem Boden."""
    rng = random.Random(seed)
    m = bpy.data.materials.new("crystal")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = base
    b.inputs["Emission Color"].default_value = emit
    b.inputs["Emission Strength"].default_value = 0.9
    b.inputs["Roughness"].default_value = 0.25
    for k in range(7):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(0.1, 0.8)
        h = rng.uniform(0.5, 1.3)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.17 + rng.random() * .1, radius2=0.01, depth=h,
                                        location=(math.cos(a) * d, math.sin(a) * d, h / 2),
                                        rotation=(rng.uniform(-.3, .3), rng.uniform(-.3, .3), a))
        add(bpy.context.active_object, m)
    rm = mat("ground", (0.12, 0.09, 0.07, 1), (0.28, 0.2, 0.15, 1), 4)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=1.1, depth=0.06, location=(0, 0, 0.03))
    add(bpy.context.active_object, rm)


def render(name):
    scn = bpy.context.scene
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 5.2
    cam = bpy.data.objects.new("cam", cam_d)
    scn.collection.objects.link(cam)
    pitch = math.radians(35)
    d = 12
    tgt = Vector((0, 0, 1.4))
    cam.location = tgt + Vector((0, -math.cos(pitch) * d, math.sin(pitch) * d))
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    sd = bpy.data.lights.new("sun", "SUN")
    sd.energy = 4.5
    s = bpy.data.objects.new("sun", sd)
    s.rotation_euler = (math.radians(50), 0, math.radians(35))
    scn.collection.objects.link(s)
    scn.world = bpy.data.worlds.new("w")
    scn.world.color = (0.30, 0.34, 0.40)
    scn.view_settings.view_transform = "Standard"
    scn.render.engine = "BLENDER_EEVEE_NEXT" if bpy.app.version >= (4, 2) else "BLENDER_EEVEE"
    scn.render.film_transparent = True
    scn.render.resolution_x = scn.render.resolution_y = SIZE
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    os.makedirs(OUT, exist_ok=True)
    scn.render.filepath = os.path.abspath(os.path.join(OUT, name + ".png"))
    bpy.ops.render.render(write_still=True)
    print("OK", name)


JOBS = [
    ("pine_a", lambda: pine(1)),
    ("pine_b", lambda: pine(2, 1.15)),
    ("pine_c", lambda: pine(3, 0.9)),
    ("oak_a", lambda: oak(4)),
    ("oak_b", lambda: oak(5, ((0.10, 0.2, 0.03, 1), (0.35, 0.45, 0.08, 1)))),
    ("dead_a", lambda: dead(6)),
    ("rock_a", lambda: rock(7)),
    ("rock_b", lambda: rock(8, 0.7)),
    ("rock_c", lambda: rock(9, 1.3)),
    ("bush_a", lambda: bush(10)),
    ("crystals_a", lambda: crystals(11)),
    ("crystals_b", lambda: crystals(12, (0.9, 0.25, 0.1, 1), (1.0, 0.4, 0.15, 1))),
]
for name, fn in JOBS:
    clear()
    fn()
    render(name)
