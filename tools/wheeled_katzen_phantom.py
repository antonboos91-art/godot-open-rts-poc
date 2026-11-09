"""Phantom-Gleiter: Schwebe-Buggy der Katzen (Buggy ohne Raeder, mit Gleitpads und Flossen)."""
import bpy
import wheeled
from wheeled import TRACK_PITCH, place_track, animate  # noqa: F401
from tank_tesla import cyl, prism, materials


def build():
    colls = wheeled.build_buggy()
    M = materials()
    H = colls["HULL"]
    for o in list(bpy.data.objects):
        if o.name.startswith(("wheel_", "wheelpivot_")) or "wheel" in o.name:
            bpy.data.objects.remove(o, do_unlink=True)
    lift = 0.28
    for coll in colls.values():
        for o in coll.objects:
            if o.parent is None:
                o.location.z += lift
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(f"pad_{sx}_{sy}", (sx * 0.5, sy * 0.6, 0.2), 0.2, 0.08, H, M["dark"], "Z", 24, 0.01)
            cyl(f"pad_glow_{sx}_{sy}", (sx * 0.5, sy * 0.6, 0.15), 0.17, 0.03, H, M["glow"], "Z", 24, 0)
    for s in (-1, 1):
        prism(f"fin_{s}", [(-0.9, 0.45 + lift), (-0.4, 0.45 + lift), (-0.5, 0.95 + lift)], s * 0.55 - 0.02, s * 0.55 + 0.02, H, M["paint"], 0.006)
    return colls
