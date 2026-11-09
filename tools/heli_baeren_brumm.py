"""Volksvariante baeren_brumm."""
import vehicle_unique as V
from heli import TRACK_PITCH, place_track, animate, NO_SHADOW  # noqa: F401


def build():
    return V.heavy_heli("wespe", 1.35)
