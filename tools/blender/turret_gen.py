"""Abwehrtuerme (Boden und Luft) je Volk als 3D-Modell, gebaut mit den Bausteinen von tank_tesla.
Aufruf ueber turret_ground.py / turret_air.py (export_vehicle.py --model ...), Volk per Umgebungsvariable FACTION.
Vorne = Blender +Y. Sockel (HULL) rund, damit sich das ganze Modell beim Zielen drehen kann; der Kopf (TURRET) sitzt oben."""
import bpy, math
import tank_tesla as T
from tank_tesla import box, cyl, prism, materials, star  # noqa: F401

FAC = T._FACTION


def _colls():
    out = {}
    for n in ("HULL", "TRACKS", "TURRET"):
        c = bpy.data.collections.get(n) or bpy.data.collections.new(n)
        if c.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(c)
        out[n] = c
    return out


def _barrel(name, x, z, length, r, coll, mat, elev_deg=0.0, y0=0.3, segs=14):
    """Rohr ab (x, y0, z), um elev_deg nach oben geneigt, nach vorn (+Y) zeigend."""
    th = math.radians(-90 + elev_deg)
    d = (0.0, -math.sin(th), math.cos(th))
    c = (x + d[0] * length / 2, y0 + d[1] * length / 2, z + d[2] * length / 2)
    o = cyl(name, c, r, length, coll, mat, "Y", segs, 0.004)
    o.rotation_euler = (th, 0, 0)
    tip = (x + d[0] * length, y0 + d[1] * length, z + d[2] * length)
    return o, tip


def _base(H, M):
    """Runder, gepanzerter Sockel mit Rand in der Zweitfarbe."""
    cyl("base", (0, 0, 0.22), 0.82, 0.44, H, M["paint"], "Z", 16, 0.03)
    cyl("base_ring", (0, 0, 0.1), 0.88, 0.14, H, M["white"], "Z", 16, 0.02)
    cyl("base_top", (0, 0, 0.46), 0.66, 0.06, H, M["dark"], "Z", 16, 0.01)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        box(f"stud_{i}", (math.cos(a) * 0.76, math.sin(a) * 0.76, 0.34), (0.1, 0.1, 0.1), H, M["steel"], 0.015, (0, 0, a))


def build(kind="ground"):
    colls = _colls()
    H, R = colls["HULL"], colls["TURRET"]
    M = materials()
    _base(H, M)
    z0 = 0.49
    if kind == "ground":
        if FAC == "shibas":
            box("head", (0, 0, z0 + 0.25), (0.95, 0.9, 0.5), R, M["paint"], 0.05)
            box("head_top", (0, -0.05, z0 + 0.53), (0.75, 0.6, 0.08), R, M["white"], 0.02)
            for s in (-1, 1):
                o, tip = _barrel(f"barrel_{s}", s * 0.24, z0 + 0.3, 1.05, 0.075, R, M["white"])
                cyl(f"muzzle_{s}", (tip[0], tip[1] - 0.05, tip[2]), 0.1, 0.16, R, M["steel"], "Y", 12, 0.004)
                cyl(f"glow_{s}", (tip[0], tip[1] + 0.02, tip[2]), 0.055, 0.04, R, M["glow"], "Y", 12, 0)
                box(f"strip_{s}", (s * 0.48, 0.0, z0 + 0.26), (0.03, 0.7, 0.05), R, M["glow"], 0)
                prism(f"ear_{s}", [(-0.15, z0 + 0.5), (0.1, z0 + 0.5), (-0.1, z0 + 0.95)], s * 0.3 - 0.05, s * 0.3 + 0.05, R, M["paint"], 0.006)
            star("star", (0, 0.1, z0 + 0.58), 0.14, R, M["white"], (0, 0, 0), 0.01)
        elif FAC == "katzen":
            prism("head", [(-0.55, z0), (0.45, z0), (0.6, z0 + 0.25), (0.2, z0 + 0.48), (-0.45, z0 + 0.42)], -0.5, 0.5, R, M["paint"], 0.015)
            box("slit", (0, 0.5, z0 + 0.27), (0.62, 0.06, 0.05), R, M["glow"], 0)
            for s in (-1, 1):
                o, tip = _barrel(f"barrel_{s}", s * 0.2, z0 + 0.26, 1.2, 0.045, R, M["dark"], 0.0, 0.4, 4)
                cyl(f"glow_{s}", (tip[0], tip[1] + 0.02, tip[2]), 0.04, 0.12, R, M["glow"], "Y", 8, 0)
                prism(f"ear_{s}", [(-0.35, z0 + 0.4), (-0.05, z0 + 0.4), (-0.2, z0 + 0.95)], s * 0.28 - 0.03, s * 0.28 + 0.03, R, M["paint"], 0.004)
                box(f"fang_{s}", (s * 0.3, 0.62, z0 + 0.1), (0.03, 0.18, 0.12), R, M["white"], 0.004, (math.radians(25), 0, 0))
        else:  # baeren
            box("head", (0, -0.05, z0 + 0.3), (1.15, 1.05, 0.6), R, M["paint"], 0.06)
            box("head_band", (0, -0.05, z0 + 0.12), (1.2, 1.1, 0.08), R, M["white"], 0.02)
            box("hatch", (0, -0.25, z0 + 0.64), (0.5, 0.4, 0.08), R, M["steel"], 0.02)
            o, tip = _barrel("barrel", 0, z0 + 0.34, 1.45, 0.13, R, M["steel"], 0.0, 0.35, 16)
            box("muzzle_brake", (0, tip[1] - 0.1, tip[2]), (0.3, 0.26, 0.3), R, M["dark"], 0.02)
            cyl("recoil", (0, 0.4, z0 + 0.34), 0.2, 0.3, R, M["paint"], "Y", 14, 0.01)
            for s in (-1, 1):
                star(f"star_{s}", (s * 0.6, -0.05, z0 + 0.34), 0.17, R, M["white"], (0, math.radians(90 * s), 0), 0.01)
    else:  # Flak
        cyl("mount", (0, 0, z0 + 0.2), 0.5, 0.4, R, M["paint"], "Z", 14, 0.03)
        cyl("mount_ring", (0, 0, z0 + 0.42), 0.55, 0.06, R, M["white"], "Z", 14, 0.01)
        box("cradle", (0, 0.1, z0 + 0.62), (0.9, 0.5, 0.28), R, M["paint"], 0.04)
        if FAC == "katzen":
            for s in (-1, 1):
                for j in (0, 1):
                    o, tip = _barrel(f"barrel_{s}_{j}", s * (0.18 + 0.2 * j), z0 + 0.7, 1.15, 0.04, R, M["dark"], 55, 0.25, 4)
                    cyl(f"glow_{s}_{j}", (tip[0], tip[1], tip[2]), 0.04, 0.08, R, M["glow"], "Y", 8, 0).rotation_euler = (math.radians(-35), 0, 0)
            cyl("dish", (0, -0.2, z0 + 0.95), 0.32, 0.05, R, M["white"], "Y", 16, 0.01).rotation_euler = (math.radians(-60), 0, 0)
        else:
            gold = M["white"] if FAC == "baeren" else M["steel"]
            for s in (-1, 1):
                for j in (0, 1):
                    o, tip = _barrel(f"barrel_{s}_{j}", s * (0.2 + 0.22 * j), z0 + 0.7, 1.1, 0.075 if FAC == "baeren" else 0.06, R, M["steel"], 52, 0.25, 12)
                    cyl(f"cap_{s}_{j}", (tip[0], tip[1], tip[2]), 0.09 if FAC == "baeren" else 0.07, 0.12, R, gold, "Y", 10, 0.004).rotation_euler = (math.radians(-38), 0, 0)
            if FAC == "shibas":
                box("radar_strip", (0, 0.1, z0 + 0.8), (0.8, 0.04, 0.04), R, M["glow"], 0)
            else:
                star("star", (0, 0.36, z0 + 0.62), 0.14, R, M["white"], (math.radians(-90), 0, 0), 0.01)
    return colls
