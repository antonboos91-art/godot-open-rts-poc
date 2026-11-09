"""Volks-eigene Raeder- und Luftfahrzeuge.
Baeren: schwer und gross (Skalierung + Reaktivpanzerung). Katzen: Schwebe-Fahrzeuge (Gleitpads) bzw. Flossen/Leuchtringe bei Helis.
Wird von den wheeled_*/heli_* Wrapper-Modulen genutzt (render_vehicle --model ...)."""
import bpy, math
from mathutils import Matrix
import wheeled, heli
from tank_tesla import materials, box, cyl, prism


def scale_all(colls, s, pivot_z=0.0):
    e = bpy.data.objects.new("scale_root", None)
    colls["HULL"].objects.link(e)
    e.location = (0, 0, pivot_z)
    e.scale = (s, s, s)
    for coll in colls.values():
        for o in list(coll.objects):
            if o is e or o.parent is not None:
                continue
            o.parent = e
            o.matrix_parent_inverse = Matrix.Translation((0, 0, -pivot_z))


def _lift_all(colls, lift):
    for coll in colls.values():
        for o in coll.objects:
            if o.parent is None:
                o.location.z += lift


def _remove_wheels():
    for o in list(bpy.data.objects):
        if "wheel" in o.name:
            bpy.data.objects.remove(o, do_unlink=True)


def era(colls, M, length, width, z, n=6, size=0.22):
    H = colls["HULL"]
    for s in (-1, 1):
        for i in range(n):
            box(f"era_{s}_{i}", (s * (width / 2 + 0.03), -length / 2 + 0.3 + i * (length - 0.6) / max(1, n - 1), z), (0.06, size, 0.18), H, M["white"], 0.01)


def heavy_truck(kind, s):
    colls = wheeled.build_truck(kind)
    M = materials()
    era(colls, M, 2.4, 1.3, 0.62, 5)
    scale_all(colls, s)
    return colls


def heavy_buggy(s):
    colls = wheeled.build_buggy()
    M = materials()
    H = colls["HULL"]
    era(colls, M, 1.8, 1.1, 0.55, 4)
    # Rammschild vorne
    prism("plow", [(0.85, 0.2), (1.25, 0.28), (1.0, 0.7), (0.85, 0.7)], -0.6, 0.6, H, M["white"], 0.01)
    for sx in (-1, 1):
        prism(f"plow_spike_{sx}", [(1.0, 0.3), (1.35, 0.35), (1.0, 0.55)], sx * 0.45 - 0.04, sx * 0.45 + 0.04, H, M["steel"], 0.005)
    scale_all(colls, s)
    return colls


def hover_wheeled(colls, lift=0.3, pad_x=0.5, pad_y=0.7):
    M = materials()
    H = colls["HULL"]
    _remove_wheels()
    _lift_all(colls, lift)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(f"pad_{sx}_{sy}", (sx * pad_x, sy * pad_y, 0.2), 0.22, 0.08, H, M["dark"], "Z", 24, 0.01)
            cyl(f"pad_glow_{sx}_{sy}", (sx * pad_x, sy * pad_y, 0.15), 0.19, 0.03, H, M["glow"], "Z", 24, 0)
    for sx in (-1, 1):
        prism(f"fin_{sx}", [(-1.1, 0.5 + lift), (-0.5, 0.5 + lift), (-0.6, 1.0 + lift)], sx * 0.6 - 0.02, sx * 0.6 + 0.02, H, M["paint"], 0.006)
    return colls


def hover_truck(kind):
    return hover_wheeled(wheeled.build_truck(kind), 0.3, 0.5, 0.8)


def heavy_heli(kind, s):
    colls = heli.build_wespe() if kind == "wespe" else heli.build_gewitter()
    M = materials()
    H = colls["HULL"]
    for sx in (-1, 1):
        box(f"armor_{sx}", (sx * 0.28, 0.0, heli.CZ - 0.05), (0.08, 0.7, 0.2), H, M["white"], 0.01)
    scale_all(colls, s, heli.CZ)
    return colls


def cat_heli(kind):
    colls = heli.build_wespe() if kind == "wespe" else heli.build_gewitter()
    M = materials()
    H = colls["HULL"]
    for sx in (-1, 1):
        prism(f"cfin_{sx}", [(-0.7, heli.CZ), (-0.2, heli.CZ), (-0.45, heli.CZ + 0.55)], sx * 0.12 - 0.02, sx * 0.12 + 0.02, H, M["paint"], 0.006)
        prism(f"cwing_{sx}", [(0.5, heli.CZ - 0.05), (0.9, heli.CZ - 0.05), (0.2, heli.CZ + 0.05)], sx * 0.15, sx * 0.55, H, M["paint"], 0.006)
    cyl("glow_ring", (0, 0, heli.CZ - 0.12), 0.32, 0.03, H, M["glow"], "Z", 24, 0)
    return colls
