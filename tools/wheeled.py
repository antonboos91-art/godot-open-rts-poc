"""Radfahrzeuge der Shibas (Buggy, Schrott-Sammler, Bau-Mobil), gleicher Stil wie tank_tesla.
Vorne = +Y. Räder heißen wheel_*, animate(t) dreht sie um eine Profil-Teilung (t = 0..1).
Nutzung in render_vehicle.py: --model wheeled_buggy | wheeled_sammler | wheeled_baumobil
"""
import bpy, math
from tank_tesla import materials, box, cyl, prism, poly_prism_z, star

TRACK_PITCH = 1.0  # wird nicht genutzt, render_vehicle ruft animate()
TREADS = 14


def _colls():
    colls = {}
    for n in ("HULL", "TRACKS", "TURRET"):
        c = bpy.data.collections.get(n) or bpy.data.collections.new(n)
        if c.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(c)
        colls[n] = c
    return colls


def wheel(name, x, y, r, w, coll, M, side):
    """Reifen mit Profilblöcken (damit die Drehung sichtbar ist) und Felge."""
    tire = cyl(f"wheel_{name}", (x, y, r), r, w, coll, M["rubber"], "X", 32)
    parts = [tire]
    for k in range(TREADS):
        a = 2 * math.pi * k / TREADS
        b = box(f"wheel_{name}_tread_{k}", (x, y + math.cos(a) * r, r + math.sin(a) * r), (w * 0.95, r * 0.18, r * 0.12),
                coll, M["rubber"], 0.004, rot=(a + math.pi / 2, 0, 0))
        parts.append(b)
    rim = cyl(f"wheel_{name}_rim", (x + side * w * 0.42, y, r), r * 0.58, 0.04, coll, M["white"], "X", 20)
    hub = cyl(f"wheel_{name}_hub", (x + side * w * 0.47, y, r), r * 0.22, 0.05, coll, M["steel"], "X", 8)
    for k in range(5):
        a = 2 * math.pi * k / 5
        bolt = cyl(f"wheel_{name}_bolt_{k}", (x + side * w * 0.48, y + math.cos(a) * r * 0.38, r + math.sin(a) * r * 0.38),
                   0.012, 0.03, coll, M["dark"], "X", 6, 0)
        parts.append(bolt)
    parts += [rim, hub]
    # Alles an einen Achs-Empty hängen, damit animate() nur ihn drehen muss
    pivot = bpy.data.objects.new(f"wheelpivot_{name}", None)
    coll.objects.link(pivot)
    pivot.location = (x, y, r)
    pivot["wheel_radius"] = r
    for p in parts:
        p.parent = pivot
        p.location = (p.location.x - x, p.location.y - y, p.location.z - r)
    return pivot


def animate(t):
    """Räder um eine Profilteilung weiterdrehen (t = 0..1) -> nahtlose Schleife."""
    for o in bpy.data.objects:
        if o.name.startswith("wheelpivot_"):
            o.rotation_euler = (-2 * math.pi / TREADS * t, 0, 0)


def place_track(offset):  # Kompatibilität mit render_vehicle (Raupen)
    animate(offset)


def _headlights(H, M, x, y, z):
    for s in (-1, 1):
        cyl(f"light_{s}_{y:.2f}", (s * x, y, z), 0.045, 0.06, H, M["steel"], "Y", 16)
        cyl(f"lens_{s}_{y:.2f}", (s * x, y + 0.03, z), 0.035, 0.01, H, M["glass"], "Y", 16, 0)


def build_buggy():
    M = materials()
    c = _colls()
    H, R = c["HULL"], c["TURRET"]
    L, W = 1.8, 1.05
    # Chassis mit schräger Motorhaube
    prof = [(-L / 2, 0.28), (L / 2 - 0.1, 0.28), (L / 2, 0.42), (L / 2 - 0.45, 0.58), (-L / 2 + 0.05, 0.55), (-L / 2, 0.45)]
    prism("chassis", prof, -W / 2 + 0.12, W / 2 - 0.12, H, M["paint"], 0.025)
    # Kotflügel
    for s in (-1, 1):
        for yy in (L / 2 - 0.38, -L / 2 + 0.38):
            box(f"fender_{s}_{yy:.2f}", (s * (W / 2 - 0.06), yy, 0.5), (0.22, 0.5, 0.05), H, M["paint"], 0.015)
        prism(f"stripe_{s}", [(-L / 2 + 0.1, 0.4), (L / 2 - 0.15, 0.4), (L / 2 - 0.15, 0.45), (-L / 2 + 0.1, 0.45)],
              s * (W / 2 - 0.12) - 0.005 * s, s * (W / 2 - 0.12) + 0.008 * s, H, M["white"], 0)
    # Sitze, Lenkrad
    for s in (-1, 1):
        box(f"seat_{s}", (s * 0.2, -0.15, 0.62), (0.26, 0.26, 0.1), H, M["dark"], 0.02)
        box(f"seatback_{s}", (s * 0.2, -0.3, 0.75), (0.26, 0.06, 0.28), H, M["dark"], 0.02)
    cyl("steering", (-0.2, 0.15, 0.78), 0.09, 0.02, H, M["dark"], "Y", 16, 0)
    # Windschutzscheibe-Rahmen
    box("windshield", (0, 0.32, 0.78), (W - 0.3, 0.03, 0.3), H, M["glass"], 0.01, rot=(math.radians(-20), 0, 0))
    # Überrollbügel
    for s in (-1, 1):
        cyl(f"rollbar_up_{s}", (s * 0.38, -0.42, 0.9), 0.025, 0.65, H, M["white"], "Z", 10, 0)
    cyl("rollbar_top", (0, -0.42, 1.22), 0.025, 0.8, H, M["white"], "X", 10, 0)
    # Rammschutz, Ersatzrad, Scheinwerfer, Stern
    box("bullbar", (0, L / 2 + 0.04, 0.38), (W - 0.35, 0.05, 0.16), H, M["steel"], 0.02)
    cyl("spare", (0, -L / 2 - 0.05, 0.6), 0.2, 0.12, H, M["rubber"], "Y", 24)
    cyl("spare_rim", (0, -L / 2 - 0.12, 0.6), 0.12, 0.03, H, M["white"], "Y", 16)
    _headlights(H, M, 0.3, L / 2 - 0.05, 0.47)
    star("hood_star", (0, L / 2 - 0.3, 0.53), 0.11, H, M["white"], (math.radians(-18), 0, 0))
    # Räder
    for s in (-1, 1):
        for yy in (L / 2 - 0.38, -L / 2 + 0.38):
            wheel(f"{s}_{yy:.2f}", s * (W / 2 - 0.08), yy, 0.22, 0.2, H, M, s)
    # Turm: MG auf Drehkranz in der Mitte (Drehpunkt 0,0)
    cyl("mg_ring", (0, 0, 1.0), 0.12, 0.06, R, M["dark"], "Z", 20)
    box("mg_body", (0, 0.12, 1.1), (0.1, 0.4, 0.1), R, M["dark"], 0.01)
    cyl("mg_barrel", (0, 0.5, 1.1), 0.018, 0.5, R, M["dark"], "Y", 10, 0)
    box("mg_shield", (0, 0.05, 1.12), (0.34, 0.03, 0.2), R, M["paint"], 0.01)
    for s in (-1, 1):
        o = prism(f"ear_{s}", [(-0.06, 0.0), (0.06, 0.0), (0.01, 0.14)], -0.015, 0.015, R, M["paint"], 0.006)
        o.location = (s * 0.11, 0.05, 1.22)
        o.rotation_euler = (0, math.radians(s * 15), math.radians(90))
    return c


def build_truck(kind):
    """Schrott-Sammler (6 Räder, Mulde mit Greifarm) und Bau-Mobil (8 Räder, gefaltete Module, Kran)."""
    M = materials()
    c = _colls()
    H = c["HULL"]
    big = kind == "baumobil"
    L, W = (2.6, 1.3) if big else (2.2, 1.2)
    deck = 0.42
    box("frame", (0, 0, deck), (W - 0.25, L, 0.12), H, M["dark"], 0.02)
    # Fahrerhaus vorne
    cab_y = L / 2 - 0.35
    prof = [(cab_y - 0.32, deck + 0.05), (cab_y + 0.3, deck + 0.05), (cab_y + 0.35, deck + 0.35),
            (cab_y + 0.18, deck + 0.68), (cab_y - 0.32, deck + 0.7)]
    prism("cab", prof, -W / 2 + 0.05, W / 2 - 0.05, H, M["paint"], 0.03)
    box("cab_window", (0, cab_y + 0.27, deck + 0.52), (W - 0.3, 0.03, 0.2), H, M["glass"], 0.01, rot=(math.radians(-35), 0, 0))
    box("cab_roof_stripe", (0, cab_y - 0.05, deck + 0.71), (W - 0.12, 0.12, 0.02), H, M["white"], 0)
    _headlights(H, M, W / 2 - 0.2, cab_y + 0.36, deck + 0.18)
    box("grill", (0, cab_y + 0.36, deck + 0.18), (0.4, 0.03, 0.14), H, M["dark"], 0.01)
    star("cab_star", (0, cab_y - 0.05, deck + 0.725), 0.12, H, M["white"])
    # Shiba-Ohren auf dem Fahrerhaus
    for s in (-1, 1):
        o = prism(f"ear_{s}", [(-0.1, 0.0), (0.1, 0.0), (0.02, 0.22)], -0.025, 0.025, H, M["paint"], 0.01)
        o.location = (s * 0.3, cab_y - 0.2, deck + 0.7)
        o.rotation_euler = (0, math.radians(s * 15), math.radians(90))
        inner = prism(f"ear_inner_{s}", [(-0.06, 0.02), (0.06, 0.02), (0.015, 0.15)], -0.03, 0.03, H, M["fur"], 0.004)
        inner.location = (s * 0.3, cab_y - 0.18, deck + 0.7)
        inner.rotation_euler = (0, math.radians(s * 15), math.radians(90))
    rear_len = L - 0.75
    rear_y = -L / 2 + rear_len / 2
    if not big:
        # Schrottmulde mit Rippen und Ladung, Greifarm
        box("bin", (0, rear_y, deck + 0.3), (W - 0.1, rear_len, 0.45), H, M["paint"], 0.03)
        for k in range(5):
            box(f"rib_{k}", (0, rear_y - rear_len / 2 + 0.1 + k * (rear_len - 0.2) / 4, deck + 0.3),
                (W - 0.06, 0.04, 0.47), H, M["white"] if k % 2 else M["paint"], 0.01)
        for k in range(10):
            box(f"scrap_{k}", ((k % 3 - 1) * 0.3, rear_y + (k // 3 - 1.5) * 0.25, deck + 0.55),
                (0.22, 0.18, 0.12), H, M["steel"] if k % 2 else M["dark"], 0.01,
                rot=(0.3 * k, 0.5 * k, 0.2 * k))
        cyl("arm_base", (W / 2 - 0.2, cab_y - 0.45, deck + 0.6), 0.08, 0.15, H, M["dark"], "Z", 12)
        arm = box("arm", (W / 2 - 0.2, cab_y - 0.75, deck + 0.85), (0.08, 0.7, 0.08), H, M["steel"], 0.01,
                  rot=(math.radians(-30), 0, 0))
        box("claw", (W / 2 - 0.2, cab_y - 1.05, deck + 1.05), (0.22, 0.12, 0.18), H, M["dark"], 0.01)
        n_axles = 3
    else:
        # Gefaltete Gebäudemodule, Kran, Radarschüssel
        box("module_a", (0, rear_y + 0.35, deck + 0.42), (W - 0.12, 0.75, 0.6), H, M["paint"], 0.03)
        box("module_b", (0, rear_y - 0.55, deck + 0.35), (W - 0.12, 0.8, 0.46), H, M["white"], 0.03)
        for k in range(4):
            box(f"panel_{k}", (W / 2 - 0.05, rear_y + 0.35 + (k - 1.5) * 0.17, deck + 0.42), (0.02, 0.12, 0.45), H, M["dark"], 0.005)
            box(f"panelb_{k}", (-W / 2 + 0.05, rear_y + 0.35 + (k - 1.5) * 0.17, deck + 0.42), (0.02, 0.12, 0.45), H, M["dark"], 0.005)
        cyl("crane_base", (0.3, rear_y - 0.55, deck + 0.62), 0.1, 0.1, H, M["dark"], "Z", 12)
        box("crane_arm", (0.3, rear_y - 0.2, deck + 0.9), (0.08, 0.9, 0.08), H, M["white"], 0.01, rot=(math.radians(-25), 0, 0))
        cyl("dish_post", (-0.3, rear_y - 0.55, deck + 0.7), 0.025, 0.25, H, M["steel"], "Z", 8, 0)
        dish = cyl("dish", (-0.3, rear_y - 0.5, deck + 0.85), 0.16, 0.03, H, M["white"], "Y", 20, 0.004)
        dish.rotation_euler = (math.radians(-60), 0, 0)
        star("module_star", (0, rear_y + 0.35, deck + 0.725), 0.18, H, M["white"])
        n_axles = 4
    r = 0.2 if not big else 0.21
    for s in (-1, 1):
        for k in range(n_axles):
            yy = cab_y if k == 0 else (-L / 2 + 0.3 + (k - 1) * (rear_len - 0.4) / max(1, n_axles - 2))
            wheel(f"{s}_{k}", s * (W / 2 - 0.05), yy, r, 0.2, H, M, s)
    return c
