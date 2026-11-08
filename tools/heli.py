"""Luftfahrzeuge der Shibas: Wespen-Drohne (4 Rotoren) und Gewitter-Kopter (Kampfhubschrauber).
Vorne = +Y, Mittelpunkt in 0.45 m Höhe (wie die Renderkamera). Rotoren heißen rotor_*;
animate(t) dreht sie um eine Blattteilung weiter (nahtlose Schleife). Kein Bodenschatten.
"""
import bpy, math
from tank_tesla import materials, box, cyl, prism, poly_prism_z, star

TRACK_PITCH = 1.0
NO_SHADOW = True
CZ = 0.45


def _colls():
    colls = {}
    for n in ("HULL", "TRACKS", "TURRET"):
        c = bpy.data.collections.get(n) or bpy.data.collections.new(n)
        if c.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(c)
        colls[n] = c
    return colls


def rotor(name, center, radius, blades, coll, M, chord=0.07, axis="Z"):
    pivot = bpy.data.objects.new(f"rotor_{name}", None)
    coll.objects.link(pivot)
    pivot.location = center
    pivot["blades"] = blades
    parts = [cyl(f"rotor_{name}_hub", center, radius * 0.12, 0.05, coll, M["dark"], "Z", 12)]
    for k in range(blades):
        a = 2 * math.pi * k / blades
        b = box(f"rotor_{name}_blade_{k}", (center[0] + math.cos(a) * radius / 2, center[1] + math.sin(a) * radius / 2, center[2]),
                (radius, chord, 0.012), coll, M["dark"], 0.003, rot=(0, 0, a))
        tip = box(f"rotor_{name}_tip_{k}", (center[0] + math.cos(a) * radius * 0.95, center[1] + math.sin(a) * radius * 0.95, center[2] + 0.002),
                  (radius * 0.1, chord * 1.02, 0.014), coll, M["white"], 0.002, rot=(0, 0, a))
        parts += [b, tip]
    for p in parts:
        p.parent = pivot
        p.location = (p.location.x - center[0], p.location.y - center[1], p.location.z - center[2])
    if axis == "X":
        pivot.rotation_euler = (0, math.radians(90), 0)
        pivot["axis"] = "X"
    return pivot


def animate(t):
    for o in bpy.data.objects:
        if o.name.startswith("rotor_") and o.type == "EMPTY":
            step = 2 * math.pi / o["blades"] * t
            if o.get("axis") == "X":
                o.rotation_euler = (step, math.radians(90), 0)
            else:
                o.rotation_euler = (0, 0, step)


def place_track(offset):
    animate(offset)


def build_gewitter():
    M = materials()
    c = _colls()
    H = c["HULL"]
    z = CZ
    # Rumpf: schmaler Kampfhubschrauber, Profil in YZ
    body = [(-0.55, z - 0.18), (0.55, z - 0.18), (0.82, z - 0.05), (0.75, z + 0.08), (0.35, z + 0.2),
            (-0.35, z + 0.22), (-0.6, z + 0.05)]
    prism("fuselage", body, -0.2, 0.2, H, M["paint"], 0.03)
    # Tandem-Cockpit
    canopy = [(0.15, z + 0.15), (0.72, z + 0.06), (0.55, z + 0.25), (0.2, z + 0.3)]
    prism("canopy", canopy, -0.14, 0.14, H, M["glass"], 0.02)
    # Heckausleger, Leitwerk, Heckrotor
    box("tailboom", (0, -1.0, z + 0.08), (0.13, 1.0, 0.12), H, M["paint"], 0.02)
    box("tail_stripe", (0, -0.85, z + 0.145), (0.135, 0.12, 0.012), H, M["white"], 0)
    prism("fin", [(-1.55, z + 0.05), (-1.4, z + 0.05), (-1.45, z + 0.42), (-1.6, z + 0.42)], -0.02, 0.02, H, M["paint"], 0.01)
    box("stab", (0, -1.42, z + 0.08), (0.6, 0.12, 0.025), H, M["paint"], 0.008)
    rotor("tail", (0.06, -1.52, z + 0.28), 0.2, 3, H, M, 0.04, axis="X")
    # Stummelflügel mit Raketenkapseln
    for s in (-1, 1):
        box(f"wing_{s}", (s * 0.42, 0.0, z - 0.02), (0.5, 0.25, 0.04), H, M["paint"], 0.01)
        pod = cyl(f"pod_{s}", (s * 0.58, 0.05, z - 0.1), 0.07, 0.45, H, M["white"], "Y", 14)
        cyl(f"pod_front_{s}", (s * 0.58, 0.29, z - 0.1), 0.065, 0.02, H, M["dark"], "Y", 14, 0)
        star(f"wing_star_{s}", (s * 0.42, 0.0, z + 0.003), 0.08, H, M["white"])
    # Bugkanone
    cyl("chin_mount", (0, 0.55, z - 0.22), 0.06, 0.08, H, M["dark"], "Z", 12)
    cyl("chin_gun", (0, 0.78, z - 0.24), 0.018, 0.4, H, M["dark"], "Y", 8, 0)
    # Kufen
    for s in (-1, 1):
        cyl(f"skid_{s}", (s * 0.26, 0.05, z - 0.36), 0.018, 1.0, H, M["dark"], "Y", 8, 0)
        for yy in (-0.2, 0.3):
            cyl(f"strut_{s}_{yy}", (s * 0.22, yy, z - 0.28), 0.014, 0.16, H, M["dark"], "Z", 6, 0)
    # Shiba-Ohren als Lufteinlässe auf dem Triebwerk
    for s in (-1, 1):
        o = prism(f"ear_{s}", [(-0.1, 0.0), (0.1, 0.0), (0.02, 0.2)], -0.025, 0.025, H, M["paint"], 0.01)
        o.location = (s * 0.14, -0.3, z + 0.2)
        o.rotation_euler = (0, math.radians(s * 15), math.radians(90))
        inner = prism(f"ear_inner_{s}", [(-0.06, 0.02), (0.06, 0.02), (0.015, 0.14)], -0.03, 0.03, H, M["fur"], 0.004)
        inner.location = (s * 0.14, -0.28, z + 0.2)
        inner.rotation_euler = (0, math.radians(s * 15), math.radians(90))
    cyl("mast", (0, -0.05, z + 0.3), 0.04, 0.16, H, M["dark"], "Z", 10)
    rotor("main", (0, -0.05, z + 0.4), 1.15, 4, H, M, 0.08)
    return c


def build_wespe():
    M = materials()
    c = _colls()
    H = c["HULL"]
    z = CZ
    # Zentralkörper (Wespe: gestreift)
    body = [(math.cos(a) * 0.22, math.sin(a) * 0.3) for a in [i * math.pi / 6 for i in range(12)]]
    poly_prism_z("core", body, z - 0.1, z + 0.08, H, M["paint"], 0.85, 0.02)
    for k in range(3):
        box(f"stripe_{k}", (0, -0.15 + k * 0.12, z + 0.08), (0.34, 0.05, 0.012), H, M["white"], 0)
    cyl("sensor", (0, 0.32, z - 0.03), 0.06, 0.06, H, M["glass"], "Y", 16)
    # Waffe unter dem Körper (Flak-Doppellauf)
    for s in (-1, 1):
        cyl(f"gun_{s}", (s * 0.06, 0.3, z - 0.14), 0.016, 0.4, H, M["dark"], "Y", 8, 0)
    # Vier Ausleger mit Rotoren
    for k, (sx, sy) in enumerate([(1, 1), (-1, 1), (1, -1), (-1, -1)]):
        box(f"arm_{k}", (sx * 0.3, sy * 0.3, z), (0.5, 0.06, 0.04), H, M["dark"], 0.01, rot=(0, 0, math.atan2(sy, sx)))
        cyl(f"motor_{k}", (sx * 0.5, sy * 0.5, z + 0.03), 0.07, 0.08, H, M["paint"], "Z", 14)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.29, minor_radius=0.018, location=(sx * 0.5, sy * 0.5, z + 0.07))
        ring = bpy.context.active_object
        ring.name = f"guard_{k}"
        for cl in list(ring.users_collection):
            cl.objects.unlink(ring)
        H.objects.link(ring)
        ring.data.materials.append(M["white"])
        rotor(f"r{k}", (sx * 0.5, sy * 0.5, z + 0.1), 0.26, 3, H, M, 0.05)
    # Shiba-Ohren
    for s in (-1, 1):
        o = prism(f"ear_{s}", [(-0.07, 0.0), (0.07, 0.0), (0.01, 0.15)], -0.02, 0.02, H, M["paint"], 0.008)
        o.location = (s * 0.1, 0.12, z + 0.06)
        o.rotation_euler = (0, math.radians(s * 15), math.radians(90))
    return c
