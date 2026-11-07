"""Erzeugt Pixel-Art-Spritesheets per "Sprite Stacking".

Jede Einheit besteht aus einfachen Grundformen (Quader, Zylinder, Polygone) mit
Höhe. Für jede der 8 Blickrichtungen werden die Formen gedreht und Schicht für
Schicht von unten nach oben gezeichnet; das ergibt einen pixeligen 3/4-Look.

Teamfarbe: Pixel in reinem Magenta (r == b, g == 0) werden im Spiel per Shader
durch die Spielerfarbe ersetzt (Helligkeit bleibt erhalten).

Aufruf: python3 tools/make_sprites.py  -> assets/sprites/units/<Typ>.png
"""

import math
import os
import random
import zlib

from PIL import Image, ImageDraw

OUT_DIR = "assets/sprites/units"
DIRECTIONS = 8
TILT = 0.62  # Stauchung der Tiefe (Kamera schaut schräg von oben)

# Düstere Palette: Asphalt, Rost, Smog; Akzente kommen über die Teamfarbe
STEEL = (78, 82, 90)
STEEL_DARK = (46, 48, 54)
CONCRETE = (92, 88, 82)
RUST = (122, 62, 38)
BLACK = (22, 20, 24)
GLASS = (70, 190, 210)
HAZARD = (190, 160, 40)
TEAM = (255, 0, 255)
TEAM_DARK = (160, 0, 160)
OUTLINE = (10, 8, 12)


def box(cx, cy, w, l, z, h, color):
    pts = [(cx - w / 2, cy - l / 2), (cx + w / 2, cy - l / 2), (cx + w / 2, cy + l / 2), (cx - w / 2, cy + l / 2)]
    return {"pts": pts, "z": z, "h": h, "color": color}


def cyl(cx, cy, r, z, h, color, segments=10):
    pts = [(cx + r * math.cos(2 * math.pi * i / segments), cy + r * math.sin(2 * math.pi * i / segments)) for i in range(segments)]
    return {"pts": pts, "z": z, "h": h, "color": color}


def poly(pts, z, h, color):
    return {"pts": pts, "z": z, "h": h, "color": color}


def shade(color, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in color)


def render(parts, size, angle, baseline):
    """Zeichnet alle Teile, gedreht um `angle` (0 = schaut auf dem Bildschirm nach oben)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    cx = size / 2

    def project(x, y, z):
        # Modell: +y = vorne. Drehung im Uhrzeigersinn auf dem Bildschirm.
        rx = x * cos_a + y * sin_a
        ry = -x * sin_a + y * cos_a
        return (cx + rx, baseline - ry * TILT - z)

    # Schichten global nach Höhe sortiert zeichnen, damit Höheres oben liegt
    layers = []
    for part in parts:
        for dz in range(int(part["h"]) + 1):
            layers.append((part["z"] + dz, dz == int(part["h"]), part))
    layers.sort(key=lambda layer: layer[0])
    for z, is_top, part in layers:
        color = part["color"]
        fill = shade(color, 1.15) if is_top else shade(color, 0.55 + 0.03 * (z - part["z"]))
        pts = [project(x, y, z) for x, y in part["pts"]]
        draw.polygon(pts, fill=fill + (255,))
    return img


def grit(img, seed):
    """Etwas Rauschen für den schmutzigen Look (Teamfarbe bleibt rein)."""
    rnd = random.Random(seed)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0 or (r == b and g == 0):
                continue
            if rnd.random() < 0.12:
                f = rnd.choice([0.8, 0.88, 1.1])
                px[x, y] = (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)), a)
    return img


def outline(img):
    src = img.copy().load()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and src[nx, ny][3] != 0:
                    px[x, y] = OUTLINE + (255,)
                    break
    return img


def sheet(name, parts, size, baseline, directions=DIRECTIONS):
    frames = []
    for d in range(directions):
        angle = 2 * math.pi * d / directions
        frame = render(parts, size, angle, baseline)
        frames.append(outline(grit(frame, zlib.crc32(f"{name}{d}".encode()))))
    out = Image.new("RGBA", (size * directions, size), (0, 0, 0, 0))
    for d, frame in enumerate(frames):
        out.paste(frame, (d * size, 0))
    os.makedirs(OUT_DIR, exist_ok=True)
    out.save(os.path.join(OUT_DIR, name + ".png"))
    print(name, out.size)


# --- Einheiten (32 px, 8 Richtungen) ------------------------------------------------

WORKER = [
    box(-6, 0, 3, 18, 0, 3, BLACK),
    box(6, 0, 3, 18, 0, 3, BLACK),
    box(0, -1, 10, 16, 2, 3, STEEL),
    box(0, -3, 9, 9, 5, 3, RUST),  # Ladebehälter
    box(0, 6, 8, 5, 4, 4, TEAM),  # Fahrerkabine
    box(0, 7, 6, 2, 8, 0, GLASS),
    box(0, 10, 13, 2, 0, 2, HAZARD),  # Schaufel
]

TANK = [
    box(-6, 0, 4, 20, 0, 3, BLACK),
    box(6, 0, 4, 20, 0, 3, BLACK),
    box(0, 0, 9, 17, 2, 3, TEAM_DARK),
    box(0, 1, 8, 13, 5, 0, TEAM),
    cyl(0, -1, 4.5, 6, 2, STEEL),
    box(0, 7, 2, 10, 7, 1, STEEL_DARK),  # Rohr
]

DRONE = [
    cyl(-6, -6, 3, 0, 0, STEEL_DARK),
    cyl(6, -6, 3, 0, 0, STEEL_DARK),
    cyl(-6, 6, 3, 0, 0, STEEL_DARK),
    cyl(6, 6, 3, 0, 0, STEEL_DARK),
    box(0, 0, 14, 2, 1, 0, STEEL),
    box(0, 0, 2, 14, 1, 0, STEEL),
    cyl(0, 0, 3.5, 1, 3, TEAM),
    box(0, 3, 2, 2, 4, 0, GLASS),
]

HELICOPTER = [
    box(0, -9, 2, 10, 3, 1, STEEL_DARK),  # Heck
    box(0, -14, 5, 2, 3, 3, TEAM_DARK),  # Leitwerk
    poly([(-4, -4), (4, -4), (5, 4), (2, 9), (-2, 9), (-5, 4)], 0, 5, TEAM),
    box(0, 6, 4, 3, 4, 1, GLASS),
    box(-5, 1, 2, 6, 1, 1, STEEL),  # Raketenkapseln
    box(5, 1, 2, 6, 1, 1, STEEL),
    box(0, 0, 26, 1, 7, 0, STEEL_DARK),  # Rotor
    box(0, 0, 1, 26, 7, 0, STEEL_DARK),
]

# --- Gebäude (64 px; 8 Richtungen, damit sie beim Drehen der Kamera mitdrehen) -------

COMMAND_CENTER = [
    box(0, 0, 40, 40, 0, 4, CONCRETE),
    box(0, 0, 36, 36, 4, 6, STEEL),
    box(-8, -8, 14, 14, 10, 10, TEAM),
    box(10, 8, 10, 10, 10, 4, STEEL_DARK),
    box(-8, -8, 2, 2, 20, 10, STEEL_DARK),  # Antenne
    box(10, 14, 12, 2, 4, 3, HAZARD),
]

VEHICLE_FACTORY = [
    box(0, 0, 40, 34, 0, 3, CONCRETE),
    box(0, -3, 34, 26, 3, 10, STEEL),
    box(0, -3, 30, 4, 13, 1, TEAM),
    box(0, 11, 18, 3, 3, 8, BLACK),  # Tor
    box(0, 13, 20, 2, 0, 1, HAZARD),
    box(-12, -10, 4, 4, 13, 6, RUST),  # Schornstein
]

AIRCRAFT_FACTORY = [
    cyl(0, 4, 15, 0, 1, CONCRETE, segments=16),
    cyl(0, 4, 10, 1, 0, STEEL_DARK, segments=16),
    box(0, 4, 2, 12, 2, 0, HAZARD),
    box(0, 4, 12, 2, 2, 0, HAZARD),
    box(0, -14, 26, 10, 0, 11, STEEL),
    box(0, -14, 22, 2, 11, 1, TEAM),
]

AG_TURRET = [
    box(0, 0, 18, 18, 0, 6, CONCRETE),
    cyl(0, 0, 6, 6, 3, TEAM_DARK),
    box(0, 8, 3, 14, 8, 1, STEEL_DARK),
]

AA_TURRET = [
    box(0, 0, 18, 18, 0, 5, CONCRETE),
    cyl(0, 0, 5, 5, 3, TEAM),
    box(-3, 4, 2, 6, 8, 8, STEEL_DARK),
    box(3, 4, 2, 6, 8, 8, STEEL_DARK),
]

INFANTRY = [
    box(-1.5, 0, 2, 2, 0, 4, BLACK),  # Beine
    box(1.5, 0, 2, 2, 0, 4, BLACK),
    box(0, 0, 6, 3, 4, 5, TEAM_DARK),  # Rumpf mit Weste
    box(0, -1.5, 5, 2, 5, 3, STEEL_DARK),  # Rucksack
    box(3, 3, 1, 6, 6, 1, STEEL),  # Waffe
    cyl(0, 0, 2, 9, 2, CONCRETE, segments=8),  # Kopf
    box(0, 0, 5, 2, 11, 0, TEAM),  # Helm
]

BARRACKS = [
    box(0, 0, 38, 30, 0, 3, CONCRETE),
    box(-6, -2, 24, 24, 3, 7, STEEL_DARK),
    poly([(-18, -14), (6, -14), (6, 10), (-18, 10)], 10, 1, TEAM_DARK),  # Dach
    box(10, 4, 12, 18, 3, 5, STEEL),  # Anbau
    box(-6, 11, 8, 2, 3, 5, BLACK),  # Tür
    box(12, -10, 2, 2, 8, 9, STEEL_DARK),  # Funkantenne
    box(0, 14, 26, 2, 0, 1, HAZARD),
]

POWER_PLANT = [
    box(0, 0, 34, 34, 0, 3, CONCRETE),
    cyl(-7, -5, 8, 3, 12, STEEL, segments=14),  # Kühlturm
    cyl(-7, -5, 5, 15, 0, BLACK, segments=12),
    box(9, 5, 12, 14, 3, 6, STEEL_DARK),
    box(9, 5, 10, 2, 9, 1, TEAM),  # Spulen
    box(9, 9, 10, 2, 9, 1, TEAM),
    box(12, -10, 3, 3, 3, 10, RUST),  # Mast
]

REFINERY = [
    box(0, 0, 40, 36, 0, 3, CONCRETE),
    box(-8, -4, 20, 22, 3, 9, RUST),  # Presse
    box(-8, -4, 16, 4, 12, 2, TEAM),
    cyl(10, -8, 6, 3, 10, STEEL, segments=12),  # Silo
    box(10, 8, 14, 10, 0, 1, HAZARD),  # Abladeplatz
    box(10, 8, 10, 6, 1, 0, BLACK),
    box(-16, 10, 4, 4, 3, 13, STEEL_DARK),  # Schlot
]

FACILITY = [
    box(0, 0, 34, 30, 0, 3, CONCRETE),
    box(0, -2, 26, 22, 3, 8, STEEL),
    box(0, -2, 20, 16, 11, 2, STEEL_DARK),
    cyl(-6, -6, 4, 13, 2, TEAM, segments=10),  # Schüssel
    box(8, 4, 2, 2, 11, 9, STEEL_DARK),  # Antenne
    box(0, 12, 10, 2, 3, 4, GLASS),
]

if __name__ == "__main__":
    sheet("Infantry", INFANTRY, 32, 24)
    sheet("Barracks", BARRACKS, 64, 44)
    sheet("PowerPlant", POWER_PLANT, 64, 44)
    sheet("Refinery", REFINERY, 64, 44)
    sheet("Facility", FACILITY, 64, 44)
    sheet("Worker", WORKER, 32, 22)
    sheet("Tank", TANK, 32, 22)
    sheet("Drone", DRONE, 32, 20)
    sheet("Helicopter", HELICOPTER, 32, 20)
    sheet("CommandCenter", COMMAND_CENTER, 64, 46)
    sheet("VehicleFactory", VEHICLE_FACTORY, 64, 44)
    sheet("AircraftFactory", AIRCRAFT_FACTORY, 64, 44)
    sheet("AntiGroundTurret", AG_TURRET, 32, 22)
    sheet("AntiAirTurret", AA_TURRET, 32, 22)
