"""Volksvariante baeren_kipper."""
import vehicle_unique as V
from wheeled import TRACK_PITCH, place_track, animate  # noqa: F401


def build():
    return V.heavy_truck("sammler", 1.35)
