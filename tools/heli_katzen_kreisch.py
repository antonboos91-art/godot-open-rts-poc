"""Volksvariante katzen_kreisch."""
import vehicle_unique as V
from heli import TRACK_PITCH, place_track, animate, NO_SHADOW  # noqa: F401


def build():
    return V.cat_heli("gewitter")
