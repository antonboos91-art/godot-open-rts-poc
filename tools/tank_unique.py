"""Volks-eigene Panzer: Baeren = schwerer Sowjet-Panzer (groesser, Doppelrohr), Katzen = Schwebepanzer (Gleitpads, Flossen).
Baut auf tank_tesla auf. Aufruf ueber tank_baeren_*.py / tank_katzen_*.py (render_vehicle --model ...)."""
import bpy, math
from mathutils import Matrix
import tank_tesla as T
from tank_tesla import TRACK_PITCH, box, cyl, prism, materials  # noqa: F401


def place_track(offset):  # Schwebepanzer haben keine Ketten
    if hasattr(T, "place_track") and not bpy.data.collections["TRACKS"].objects:
        return
    T.place_track(offset)


def _scale_turret(R, s, z):
    e = bpy.data.objects.new("turret_scale", None)
    R.objects.link(e)
    e.location = (0, 0, z)
    e.scale = (s, s, s)
    for o in list(R.objects):
        if o is e:
            continue
        o.parent = e
        o.matrix_parent_inverse = Matrix.Translation((0, 0, -z))


def build_heavy(kind="tesla"):
    T.L, T.W, T.TRACK_W = 3.2, 2.05, 0.42
    T.HULL_Z1 = T.TURRET_Z = 0.8
    colls = T.build(kind)
    M = materials()
    H, R = colls["HULL"], colls["TURRET"]
    # Doppelrohr: Rohr, Muendungsbremse, Rauchabsauger verdoppeln
    for name in ("barrel", "fume", "fume_band", "muzzle"):
        o = bpy.data.objects.get(name)
        if o is None:
            continue
        c = o.copy()
        c.data = o.data.copy()
        R.objects.link(c)
        o.location.x -= 0.15
        c.location.x += 0.15
        c.name = name + "_2"
    # Reaktivpanzerung (Kacheln) auf Bug und Seiten, Frontplatte mit Stern
    for s in (-1, 1):
        for i in range(7):
            box(f"era_{s}_{i}", (s * (T.W / 2 + 0.03), -T.L / 2 + 0.3 + i * 0.4, T.HULL_Z1 - 0.2), (0.07, 0.3, 0.2), H, M["white"], 0.012)
    for i in range(5):
        box(f"era_front_{i}", (-0.6 + i * 0.3, T.L / 2 - 0.05, T.HULL_Z1 - 0.1), (0.24, 0.1, 0.22), H, M["white"], 0.012)
    cyl("front_hull_gun", (0.0, T.L / 2 - 0.2, T.HULL_Z1 - 0.12), 0.05, 0.5, H, M["dark"], "Y", 12, 0)
    _scale_turret(R, 1.35, T.TURRET_Z)
    return colls


def build_hover(kind="tesla"):
    colls = T.build(kind)
    M = materials()
    H, R, TR = colls["HULL"], colls["TURRET"], colls["TRACKS"]
    for o in list(TR.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for o in list(H.objects):
        if o.name.startswith(("wheel_", "hub_", "hubcap_", "sprocket_", "idler_", "track_")):
            bpy.data.objects.remove(o, do_unlink=True)
    lift = 0.32
    for coll in (H, R):
        for o in coll.objects:
            if o.parent is None:
                o.location.z += lift
    # Gleitpads: leuchtende Ringe + dunkle Unterseite
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 0.55, sy * 0.8
            cyl(f"pad_{sx}_{sy}", (x, y, 0.2), 0.24, 0.1, H, M["dark"], "Z", 24, 0.01)
            cyl(f"pad_glow_{sx}_{sy}", (x, y, 0.14), 0.2, 0.03, H, M["glow"], "Z", 24, 0)
            cyl(f"pad_ring_{sx}_{sy}", (x, y, 0.255), 0.27, 0.025, H, M["white"], "Z", 24, 0)
    cyl("belly_glow", (0, 0, 0.2), 0.5, 0.02, H, M["glow"], "Z", 24, 0)
    # spitze Heckflossen und Flügel-Spitzen am Bug
    for s in (-1, 1):
        f = prism(f"fin_{s}", [(-T.L / 2 - 0.35, 0.55 + lift), (-T.L / 2 + 0.3, 0.55 + lift), (-T.L / 2 + 0.2, 1.05 + lift)], s * 0.7 - 0.02, s * 0.7 + 0.02, H, M["paint"], 0.006)
        w = prism(f"wing_{s}", [(T.L / 2 - 0.2, 0.5 + lift), (T.L / 2 + 0.25, 0.55 + lift), (T.L / 2 - 0.5, 0.58 + lift)], s * 0.62, s * 0.84, H, M["paint"], 0.006)
    return colls
