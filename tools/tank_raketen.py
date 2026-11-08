"""Raketen-Rudel: Panzerfahrwerk vom Tesla-Panzer mit Raketenwerfer statt Kanone."""
import tank_tesla
from tank_tesla import TRACK_PITCH, place_track  # noqa: F401


def build():
    return tank_tesla.build("rockets")
