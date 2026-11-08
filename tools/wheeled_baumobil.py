"""baumobil"""
import wheeled
from wheeled import TRACK_PITCH, place_track, animate  # noqa: F401


def build():
    return wheeled.build_truck("baumobil")
