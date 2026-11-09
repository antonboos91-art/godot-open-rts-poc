"""Volks-Panzer baeren_moerser."""
import tank_unique as U
from tank_unique import TRACK_PITCH, place_track  # noqa: F401


def build():
    return U.build_heavy("rockets")
