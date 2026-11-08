"""Shiba-Tesla-Panzer als Hard-Surface-Modell (komplett per Skript, keine KI).
Vorne = +Y, Hochachse = Z, Ursprung = Bodenmitte. Turm-Drehpunkt liegt exakt über (0, 0).
Erzeugt Collections: HULL (Wanne + Fahrwerk), TRACKS (animierbare Kettenglieder), TURRET.
Wird von render_vehicle.py importiert:  import tank_tesla; tank_tesla.build()
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

# Hauptmaße (Meter, Spielmaßstab ~ Radius 0.8 -> 2.3 m lang)
L, W = 2.3, 1.45          # Wannenlänge / Breite über Ketten
TRACK_W = 0.32
HULL_Z0, HULL_Z1 = 0.22, 0.62
WHEEL_R = 0.13
TURRET_Z = HULL_Z1


# ---------- Materialien ----------
def _mat(name, color, metal=0.2, rough=0.5, edge_wear=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if edge_wear > 0:
        # Abgeriebene Kanten: Pointiness (Cycles) mischt helles Metall auf Kanten
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.52
        ramp.color_ramp.elements[1].position = 0.56
        mix = nt.nodes.new("ShaderNodeMixRGB")
        mix.inputs["Color1"].default_value = (*color, 1)
        mix.inputs["Color2"].default_value = (0.62, 0.64, 0.68, 1)
        nt.links.new(geo.outputs["Pointiness"], ramp.inputs["Fac"])
        r2 = nt.nodes.new("ShaderNodeMath")
        r2.operation = "MULTIPLY"
        r2.inputs[1].default_value = edge_wear
        nt.links.new(ramp.outputs["Color"], r2.inputs[0])
        nt.links.new(r2.outputs[0], mix.inputs["Fac"])
        nt.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def materials():
    return {
        "paint": _mat("Paint", (0.012, 0.045, 0.2), 0.3, 0.38),
        "white": _mat("White", (0.75, 0.77, 0.8), 0.1, 0.4),
        "dark": _mat("Dark", (0.015, 0.02, 0.03), 0.6, 0.55),
        "steel": _mat("Steel", (0.35, 0.36, 0.38), 0.9, 0.3),
        "track": _mat("Track", (0.06, 0.06, 0.065), 0.85, 0.5),
        "rubber": _mat("Rubber", (0.03, 0.03, 0.03), 0.0, 0.8),
        "glass": _mat("Glass", (0.15, 0.6, 1.0), 0.0, 0.1),
        "glow": _emit("Glow", (0.35, 0.75, 1.0), 6.0),
        "fur": _mat("Fur", (0.62, 0.3, 0.08), 0.0, 0.7),
    }


def _emit(name, color, strength):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


# ---------- Bausteine ----------
def _link(obj, coll):
    coll.objects.link(obj)
    return obj


def _finish(obj, mat, bevel=0.012, segs=2, smooth=True):
    obj.data.materials.append(mat)
    if bevel > 0:
        b = obj.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = segs
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(30)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
        obj.data.set_sharp_from_angle(angle=math.radians(35)) if hasattr(obj.data, "set_sharp_from_angle") else None
    return obj


def prism(name, profile_yz, x0, x1, coll, mat, bevel=0.012):
    """Profil in der YZ-Ebene, zwischen x0 und x1 extrudiert."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profile_yz]
    b = [bm.verts.new((x1, y, z)) for y, z in profile_yz]
    n = len(profile_yz)
    bm.faces.new(a[::-1])
    bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return _finish(_link(bpy.data.objects.new(name, me), coll), mat, bevel)


def box(name, center, size, coll, mat, bevel=0.01, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = _link(bpy.data.objects.new(name, me), coll)
    o.location = center
    o.rotation_euler = rot
    return _finish(o, mat, bevel)


def cyl(name, center, r, depth, coll, mat, axis="X", segs=24, bevel=0.006, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = _link(bpy.data.objects.new(name, me), coll)
    o.location = center
    o.rotation_euler = {"X": (0, math.radians(90), 0), "Y": (math.radians(-90), 0, 0), "Z": (0, 0, 0)}[axis]
    return _finish(o, mat, bevel)


def poly_prism_z(name, pts_xy, z0, z1, coll, mat, top_scale=1.0, bevel=0.012):
    """Polygon in XY, von z0 nach z1 extrudiert, oben skaliert (Schrägen)."""
    bm = bmesh.new()
    a = [bm.verts.new((x, y, z0)) for x, y in pts_xy]
    b = [bm.verts.new((x * top_scale, y * top_scale, z1)) for x, y in pts_xy]
    n = len(pts_xy)
    bm.faces.new(a[::-1])
    bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return _finish(_link(bpy.data.objects.new(name, me), coll), mat, bevel)


def star(name, center, r, coll, mat, normal_rot=(0, 0, 0), thickness=0.004):
    pts = []
    for i in range(10):
        ang = math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.4
        pts.append((math.cos(ang) * rr, math.sin(ang) * rr))
    o = poly_prism_z(name, pts, 0, thickness, coll, mat, bevel=0)
    o.location = center
    o.rotation_euler = normal_rot
    return o


# ---------- Panzer ----------
def build(turret_kind="tesla"):
    M = materials()
    colls = {}
    for n in ("HULL", "TRACKS", "TURRET"):
        c = bpy.data.collections.get(n) or bpy.data.collections.new(n)
        if c.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(c)
        colls[n] = c
    H, T, R = colls["HULL"], colls["TRACKS"], colls["TURRET"]

    hw = W / 2 - TRACK_W  # halbe Wannenbreite innen
    # Wanne: Seitenprofil mit schrägem Bug und Heck
    prof = [(-L / 2 + 0.05, HULL_Z0), (L / 2 - 0.18, HULL_Z0), (L / 2, HULL_Z0 + 0.16),
            (L / 2 - 0.36, HULL_Z1), (-L / 2 + 0.12, HULL_Z1), (-L / 2, HULL_Z1 - 0.12)]
    prism("hull_core", prof, -hw - 0.02, hw + 0.02, H, M["paint"], 0.02)
    # Kettenabdeckungen (Fender) mit weißer Kante
    for s in (-1, 1):
        x0, x1 = s * (hw), s * (W / 2 + 0.01)
        xa, xb = min(x0, x1), max(x0, x1)
        fender = [(-L / 2 - 0.02, HULL_Z1 - 0.15), (L / 2 + 0.02, HULL_Z1 - 0.15), (L / 2 + 0.05, HULL_Z1 - 0.1),
                  (L / 2 - 0.05, HULL_Z1 - 0.02), (-L / 2, HULL_Z1 - 0.02)]
        prism(f"fender_{s}", fender, xa, xb, H, M["paint"], 0.012)
        prism(f"fender_trim_{s}", [(-L / 2 + 0.1, HULL_Z1 - 0.06), (L / 2 - 0.12, HULL_Z1 - 0.06),
                                    (L / 2 - 0.12, HULL_Z1 - 0.03), (-L / 2 + 0.1, HULL_Z1 - 0.03)],
              s * (W / 2 + 0.012) - 0.004, s * (W / 2 + 0.012) + 0.004, H, M["white"], 0)
        # Seitenschürzen mit Nieten
        prism(f"skirt_{s}", [(-L / 2 + 0.12, HULL_Z1 - 0.3), (L / 2 - 0.22, HULL_Z1 - 0.3),
                             (L / 2 - 0.16, HULL_Z1 - 0.15), (-L / 2 + 0.1, HULL_Z1 - 0.15)],
              s * (W / 2 + 0.005) - 0.012, s * (W / 2 + 0.005) + 0.012, H, M["paint"], 0.006)
        for i in range(9):
            y = -L / 2 + 0.2 + i * (L - 0.45) / 8
            cyl(f"rivet_{s}_{i}", (s * (W / 2 + 0.02), y, HULL_Z1 - 0.22), 0.012, 0.01, H, M["steel"], "X", 8, 0)
        # Stauboxen auf dem Fender
        box(f"stowage_{s}", (s * (W / 2 - 0.12), -L / 2 + 0.45, HULL_Z1 + 0.04), (0.16, 0.42, 0.12), H, M["paint"], 0.015)
        box(f"stowage_lid_{s}", (s * (W / 2 - 0.12), -L / 2 + 0.45, HULL_Z1 + 0.105), (0.17, 0.43, 0.012), H, M["dark"], 0.004)
        # Scheinwerfer
        cyl(f"light_{s}", (s * (hw - 0.08), L / 2 - 0.2, HULL_Z1 + 0.02), 0.035, 0.05, H, M["steel"], "Y", 16)
        cyl(f"lens_{s}", (s * (hw - 0.08), L / 2 - 0.17, HULL_Z1 + 0.02), 0.026, 0.01, H, M["glass"], "Y", 16, 0)
        # Abschlepphaken
        box(f"hook_{s}", (s * 0.32, L / 2 + 0.01, HULL_Z0 + 0.1), (0.05, 0.06, 0.08), H, M["steel"], 0.01)
        # Auspuff hinten
        cyl(f"exhaust_{s}", (s * 0.35, -L / 2 - 0.02, HULL_Z1 - 0.17), 0.045, 0.12, H, M["dark"], "Y", 16)
    # Motordeck mit Lüftungsgittern
    box("engine_deck", (0, -L / 2 + 0.38, HULL_Z1 + 0.012), (2 * hw - 0.1, 0.55, 0.03), H, M["paint"], 0.01)
    for i in range(7):
        box(f"grille_{i}", (0, -L / 2 + 0.16 + i * 0.07, HULL_Z1 + 0.032), (2 * hw - 0.25, 0.025, 0.012), H, M["dark"], 0.004)
    # Fahrerluke + Winkelspiegel
    cyl("driver_hatch", (-0.2, L / 2 - 0.5, HULL_Z1 + 0.01), 0.1, 0.03, H, M["paint"], "Z", 24)
    for i in range(3):
        box(f"periscope_{i}", (-0.2 + (i - 1) * 0.06, L / 2 - 0.38, HULL_Z1 + 0.03), (0.04, 0.03, 0.03), H, M["glass"], 0.004)
    # Weiße Streifen + Stern auf dem Bug (Shiba-Konzern-Abzeichen)
    star("hull_star", (0.38, L / 2 - 0.2, HULL_Z1 - 0.03), 0.09, H, M["white"], (math.radians(-31), 0, 0))
    star("hull_star2", (-0.38, L / 2 - 0.2, HULL_Z1 - 0.03), 0.09, H, M["white"], (math.radians(-31), 0, 0))

    # Fahrwerk: Laufrollen, Antriebs-, Leitrad (gehören zur Wanne), Kettenglieder (eigene Collection)
    wheel_x = W / 2 - TRACK_W / 2
    n_wheels = 6
    y_front, y_back = L / 2 - 0.2, -L / 2 + 0.2
    for s in (-1, 1):
        for i in range(n_wheels):
            y = y_back + 0.14 + (y_front - y_back - 0.28) * i / (n_wheels - 1)
            cyl(f"wheel_{s}_{i}", (s * wheel_x, y, 0.20), WHEEL_R, TRACK_W * 0.75, H, M["rubber"], "X", 28)
            cyl(f"hub_{s}_{i}", (s * (wheel_x + TRACK_W * 0.38), y, 0.20), WHEEL_R * 0.55, 0.03, H, M["paint"], "X", 16)
            cyl(f"hubcap_{s}_{i}", (s * (wheel_x + TRACK_W * 0.41), y, 0.20), WHEEL_R * 0.2, 0.03, H, M["steel"], "X", 12)
        cyl(f"sprocket_{s}", (s * wheel_x, y_back - 0.05, 0.22), 0.13, TRACK_W * 0.6, H, M["steel"], "X", 12)
        cyl(f"idler_{s}", (s * wheel_x, y_front + 0.05, 0.22), 0.12, TRACK_W * 0.6, H, M["dark"], "X", 24)
    track_links(T, M, wheel_x, y_back - 0.05, y_front + 0.05)
    if turret_kind == "rockets":
        _turret_rockets(R, M)
        return colls

    # Turm: achteckig, geneigte Seiten, Drehpunkt bei (0, 0)
    tw, tl = 0.5, 0.62
    oct_pts = [(tw * 0.6, tl), (tw, tl * 0.55), (tw, -tl * 0.6), (tw * 0.7, -tl), (-tw * 0.7, -tl), (-tw, -tl * 0.6),
               (-tw, tl * 0.55), (-tw * 0.6, tl)]
    oct_pts = [(x, y + 0.02) for x, y in oct_pts]
    poly_prism_z("turret_body", oct_pts, TURRET_Z, TURRET_Z + 0.3, R, M["paint"], 0.86, 0.025)
    poly_prism_z("turret_ring", [(math.cos(a) * 0.45, math.sin(a) * 0.45) for a in [i * math.pi / 12 for i in range(24)]],
                 TURRET_Z - 0.03, TURRET_Z + 0.01, R, M["dark"], 1.0, 0)
    # Shiba-Ohren als große, nach außen geneigte Panzerplatten oben
    for s in (-1, 1):
        o = prism(f"ear_{s}", [(-0.15, 0.0), (0.15, 0.0), (0.03, 0.32)], -0.03, 0.03, R, M["paint"], 0.012)
        o.location = (s * 0.24, -0.08, TURRET_Z + 0.27)
        o.rotation_euler = (0, math.radians(s * 18), math.radians(90))
        inner = prism(f"ear_inner_{s}", [(-0.09, 0.03), (0.09, 0.03), (0.02, 0.22)], -0.035, 0.035, R, M["fur"], 0.004)
        inner.location = (s * 0.24, -0.06, TURRET_Z + 0.27)
        inner.rotation_euler = (0, math.radians(s * 18), math.radians(90))
    # Weißer Streifen rund um den Turm
    band = [(x * 1.005, y * 1.005) for x, y in oct_pts]
    poly_prism_z("turret_band", band, TURRET_Z + 0.07, TURRET_Z + 0.12, R, M["white"], 0.98, 0)
    # Blende (Mantlet) + Rohr mit Rauchabsauger und Mündungsbremse
    box("mantlet", (0, tl * 0.98, TURRET_Z + 0.15), (0.36, 0.14, 0.2), R, M["paint"], 0.03)
    cyl("barrel", (0, tl + 0.62, TURRET_Z + 0.15), 0.045, 1.1, R, M["paint"], "Y", 20, 0.004, r2=0.04)
    cyl("fume", (0, tl + 0.55, TURRET_Z + 0.15), 0.07, 0.22, R, M["paint"], "Y", 20)
    cyl("fume_band", (0, tl + 0.55, TURRET_Z + 0.15), 0.073, 0.03, R, M["white"], "Y", 20, 0)
    cyl("muzzle", (0, tl + 1.17, TURRET_Z + 0.15), 0.075, 0.12, R, M["steel"], "Y", 8)
    # Kommandantenkuppel, Luke, MG, Antenne
    cyl("cupola", (-0.18, -0.18, TURRET_Z + 0.34), 0.11, 0.09, R, M["paint"], "Z", 20)
    cyl("cupola_lid", (-0.18, -0.18, TURRET_Z + 0.395), 0.1, 0.025, R, M["dark"], "Z", 20)
    for i in range(6):
        a = i * math.pi / 3
        box(f"vision_{i}", (-0.18 + math.cos(a) * 0.1, -0.18 + math.sin(a) * 0.1, TURRET_Z + 0.34), (0.03, 0.03, 0.025), R, M["glass"], 0.003)
    box("mg_mount", (0.17, 0.05, TURRET_Z + 0.34), (0.05, 0.05, 0.08), R, M["dark"], 0.008)
    cyl("mg", (0.17, 0.22, TURRET_Z + 0.37), 0.012, 0.36, R, M["dark"], "Y", 8, 0)
    cyl("antenna", (-0.32, -0.45, TURRET_Z + 0.55), 0.006, 0.55, R, M["dark"], "Z", 6, 0)
    # Tesla-Spule hinten am Turm (Namensgeber), leuchtend
    cyl("coil_base", (0.2, -0.48, TURRET_Z + 0.36), 0.07, 0.08, R, M["dark"], "Z", 16)
    for i in range(4):
        cyl(f"coil_ring_{i}", (0.2, -0.48, TURRET_Z + 0.42 + i * 0.035), 0.055 - i * 0.008, 0.018, R, M["steel"], "Z", 16, 0)
    cyl("coil_orb", (0.2, -0.48, TURRET_Z + 0.58), 0.035, 0.05, R, M["glow"], "Z", 16, 0)
    # Turm-Abzeichen
    star("turret_star_l", (-0.47, 0.1, TURRET_Z + 0.15), 0.08, R, M["white"], (0, math.radians(-82), 0))
    star("turret_star_r", (0.47, 0.1, TURRET_Z + 0.15), 0.08, R, M["white"], (0, math.radians(82), 0))
    return colls


TRACK_PITCH = 0.06


def track_links(coll, M, x, y_back, y_front):
    """Kettenglieder als Einzelteile entlang einer Schleife. Objekt 'track_path_<s>' trägt
    die Glieder; render_vehicle.py verschiebt die Glieder pro Animationsframe um TRACK_PITCH/N."""
    r = 0.16
    zc = 0.22
    for s in (-1, 1):
        pts = _loop_points(y_back, y_front, zc, r)
        total = pts[0][4]
        bpy.context.scene["track_loop_length"] = total
        for k in range(int(total / TRACK_PITCH)):
            o = box(f"link_{s}_{k}", (0, 0, 0), (TRACK_W, TRACK_PITCH * 0.82, 0.025), coll, M["track"], 0.006)
            o["track_s"] = k * TRACK_PITCH
            o["track_x"] = s * x
            grouser = box(f"grouser_{s}_{k}", (0, 0, 0), (TRACK_W * 0.9, 0.012, 0.018), coll, M["track"], 0.003)
            grouser["track_s"] = k * TRACK_PITCH
            grouser["track_x"] = s * x
            grouser["track_out"] = 0.02
    place_track(0.0)


def _loop_points(y_back, y_front, zc, r):
    """Kettenschleife als Liste (Bogenlänge, y, z, Winkel)."""
    pts = []
    s = 0.0
    straight = y_front - y_back
    seg = []
    # unten von hinten nach vorne, Bogen vorne, oben zurück, Bogen hinten
    seg.append(("line", (y_back, zc - r), (y_front, zc - r)))
    seg.append(("arc", y_front, -math.pi / 2, math.pi / 2))
    seg.append(("line", (y_front, zc + r), (y_back, zc + r)))
    seg.append(("arc", y_back, math.pi / 2, 3 * math.pi / 2))
    out = []
    for kind, *a in seg:
        if kind == "line":
            (y0, z0), (y1, z1) = a
            n = 40
            for i in range(n):
                t = i / n
                out.append([0, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t, 0.0 if y1 > y0 else math.pi])
        else:
            yc, a0, a1 = a
            n = 20
            for i in range(n):
                ang = a0 + (a1 - a0) * i / n
                out.append([0, yc + math.cos(ang) * r, zc + math.sin(ang) * r, ang + math.pi / 2])
    for i in range(len(out)):
        if i:
            out[i][0] = out[i - 1][0] + math.dist(out[i][1:3], out[i - 1][1:3])
    total = out[-1][0] + math.dist(out[-1][1:3], out[0][1:3])
    return [(o[0], o[1], o[2], o[3], total) for o in out]


_LOOP = None


def place_track(offset):
    """Setzt alle Kettenglieder auf die Schleife, verschoben um offset (Meter)."""
    global _LOOP
    if _LOOP is None:
        _LOOP = _loop_points(-L / 2 + 0.2 - 0.05, L / 2 - 0.2 + 0.05, 0.22, 0.16)
    total = _LOOP[0][4]
    for o in bpy.data.objects:
        if "track_s" not in o:
            continue
        s = (o["track_s"] + offset) % total
        # Nachbarpunkte finden
        lo = max(i for i in range(len(_LOOP)) if _LOOP[i][0] <= s)
        hi = (lo + 1) % len(_LOOP)
        a, b = _LOOP[lo], _LOOP[hi]
        span = (b[0] if hi else total) - a[0]
        t = (s - a[0]) / span if span > 1e-6 else 0
        y = a[1] + (b[1] - a[1]) * t
        z = a[2] + (b[2] - a[2]) * t
        dy, dz = (b[1] - a[1]), (b[2] - a[2])
        ang = math.atan2(dz, dy)
        nrm = Vector((0, -math.sin(ang), math.cos(ang)))
        # Außenseite der Schleife: Normale zeigt vom Mittelpunkt weg
        center = Vector((0, 0, 0.22))
        if (Vector((0, y, z)) - center).dot(nrm) < 0:
            nrm = -nrm
        pos = Vector((o["track_x"], y, z)) + nrm * o.get("track_out", 0.0)
        o.location = pos
        o.rotation_euler = (ang, 0, 0)


def _turret_rockets(R, M):
    """Raketen-Rudel: drehbarer Werfer mit zwei 2x3-Raketenkästen, Drehpunkt (0, 0)."""
    poly_prism_z("turret_ring", [(math.cos(a) * 0.42, math.sin(a) * 0.42) for a in [i * math.pi / 12 for i in range(24)]],
                 TURRET_Z - 0.03, TURRET_Z + 0.06, R, M["dark"], 1.0, 0)
    # Sockel mit Schräge
    base = [(0.32, 0.36), (0.38, 0.1), (0.38, -0.4), (-0.38, -0.4), (-0.38, 0.1), (-0.32, 0.36)]
    poly_prism_z("launcher_base", base, TURRET_Z + 0.04, TURRET_Z + 0.2, R, M["paint"], 0.92, 0.02)
    band = [(x * 1.01, y * 1.01) for x, y in base]
    poly_prism_z("launcher_band", band, TURRET_Z + 0.08, TURRET_Z + 0.12, R, M["white"], 0.98, 0)
    # Zwei Raketenkästen, leicht nach oben geneigt
    for s in (-1, 1):
        pod = box(f"pod_{s}", (s * 0.27, 0.05, TURRET_Z + 0.36), (0.3, 0.75, 0.26), R, M["paint"], 0.025,
                  rot=(math.radians(12), 0, 0))
        for row in range(2):
            for col in range(3):
                x = s * 0.27 + (col - 1) * 0.085
                z = TURRET_Z + 0.31 + row * 0.1
                y = 0.05 + 0.375 * math.cos(math.radians(12)) + 0.01
                zz = z + 0.375 * math.sin(math.radians(12))
                tube = cyl(f"tube_{s}_{row}_{col}", (x, y, zz), 0.035, 0.03, R, M["dark"], "Y", 12, 0)
                tube.rotation_euler = (math.radians(-90 + 12), 0, 0)
                tip = cyl(f"tip_{s}_{row}_{col}", (x, y + 0.012, zz + 0.003), 0.024, 0.04, R, M["white"], "Y", 12, 0,
                          r2=0.004)
                tip.rotation_euler = (math.radians(-90 + 12), 0, 0)
        star(f"pod_star_{s}", (s * 0.425, 0.0, TURRET_Z + 0.38), 0.07, R, M["white"], (0, math.radians(s * 90), 0))
    # Shiba-Ohren als Visier-Abdeckungen hinten
    for s in (-1, 1):
        o = prism(f"ear_{s}", [(-0.11, 0.0), (0.11, 0.0), (0.02, 0.24)], -0.025, 0.025, R, M["paint"], 0.01)
        o.location = (s * 0.14, -0.3, TURRET_Z + 0.2)
        o.rotation_euler = (0, math.radians(s * 18), math.radians(90))
        inner = prism(f"ear_inner_{s}", [(-0.065, 0.02), (0.065, 0.02), (0.015, 0.16)], -0.03, 0.03, R, M["fur"], 0.004)
        inner.location = (s * 0.14, -0.28, TURRET_Z + 0.2)
        inner.rotation_euler = (0, math.radians(s * 18), math.radians(90))
    # Zielradar
    cyl("radar_post", (0, -0.25, TURRET_Z + 0.3), 0.02, 0.2, R, M["steel"], "Z", 8, 0)
    dish = cyl("radar_dish", (0, -0.2, TURRET_Z + 0.42), 0.11, 0.03, R, M["white"], "Y", 20, 0.004)
    dish.rotation_euler = (math.radians(-70), 0, 0)
    cyl("antenna", (-0.3, -0.36, TURRET_Z + 0.5), 0.006, 0.5, R, M["dark"], "Z", 6, 0)
