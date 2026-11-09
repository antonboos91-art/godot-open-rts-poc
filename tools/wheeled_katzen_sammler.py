"""Volksvariante katzen_sammler."""
import vehicle_unique as V
from wheeled import TRACK_PITCH, place_track, animate  # noqa: F401


def build():
    return V.hover_truck("sammler")
