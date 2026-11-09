"""Volksvariante baeren_rammbock."""
import vehicle_unique as V
from wheeled import TRACK_PITCH, place_track, animate  # noqa: F401


def build():
    return V.heavy_buggy(1.5)
