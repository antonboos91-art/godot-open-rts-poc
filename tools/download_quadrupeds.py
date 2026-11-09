"""Lädt kostenlose (CC0) Vierbeiner-Animationen, Vierbeiner-Rigs (Hund/Shiba, Katze, Bär/Panda, Wolf)
sowie passende 3D-Waffen-Props für alle 3 Völker herunter:
1. Mesh2Motion Quadruped Set (21 Einzel-Animationen inkl. scratch-ear, shake-off, sneak, bite, bark, howl, sleep, sit, play-bow + Hund/Katze/Bär-Variationen auf demselben Skelett)
2. Quaternius Ultimate Animated Animals (ShibaInu, Wolf, Husky, Fox, Bull, Stag – je 12 Animationen)
3. CC0 Militär-Waffen-Props (AK, Sniper, RocketLauncher, SMG, GrenadeLauncher, Shotgun)
"""
import json
import os
import struct
import urllib.request

QUAD_DIR = os.path.join("assets", "animations", "quadrupeds")
M2M_ANIM_DIR = os.path.join(QUAD_DIR, "mesh2motion_animations")
M2M_MODELS_DIR = os.path.join(QUAD_DIR, "mesh2motion_models")
QUAT_DIR = os.path.join(QUAD_DIR, "quaternius")
PROPS_DIR = os.path.join("assets", "animations", "props")

M2M_BASE = "https://raw.githubusercontent.com/Mesh2Motion/mesh2motion-app/main/static/assets/"
QUAT_BASE = "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/public/glb/animals_pack/"

M2M_ANIMS = [
    "bark.glb",
    "bite.glb",
    "death.glb",
    "fall.glb",
    "fetch.glb",
    "flip.glb",
    "howl.glb",
    "idle-alert.glb",
    "idle.glb",
    "jump.glb",
    "play-bow.glb",
    "rest-pose.glb",
    "run.glb",
    "scratch-ear.glb",
    "shake-off.glb",
    "sit.glb",
    "sleep.glb",
    "sneak.glb",
    "swim.glb",
    "trot.glb",
    "walk.glb",
]

M2M_MODELS = [
    ("skeleton.glb", "fox/skeleton.glb"),
    ("dog_shiba.glb", "fox/variations/dog.glb"),
    ("cat.glb", "fox/variations/cat.glb"),
    ("bear_panda.glb", "fox/variations/panda.glb"),
    ("fox_wolf.glb", "fox/variations/base.glb"),
]

QUATERNIUS_MODELS = [
    "ShibaInu.glb",
    "Wolf.glb",
    "Husky.glb",
    "Fox.glb",
    "Bull.glb",
    "Stag.glb",
]

WEAPON_PROPS = [
    "AK.glb",
    "RocketLauncher.glb",
    "GrenadeLauncher.glb",
    "Sniper.glb",
    "Sniper_2.glb",
    "SMG.glb",
    "Shotgun.glb",
    "Pistol.glb",
    "ShortCannon.glb",
]


def download_file(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if not os.path.exists(dest) or os.path.getsize(dest) < 100:
        urllib.request.urlretrieve(url, dest)
    return os.path.getsize(dest) // 1024


def main():
    # Alte flache Dateien aufräumen, falls vorhanden
    for f in QUATERNIUS_MODELS:
        old = os.path.join(QUAD_DIR, f"quaternius_{f}")
        if os.path.exists(old):
            os.makedirs(QUAT_DIR, exist_ok=True)
            new_p = os.path.join(QUAT_DIR, f)
            if not os.path.exists(new_p):
                os.replace(old, new_p)
            else:
                os.remove(old)

    print("=== 1. Mesh2Motion Vierbeiner-Animationen (21 Clips) ===")
    for anim in M2M_ANIMS:
        dest = os.path.join(M2M_ANIM_DIR, anim)
        kb = download_file(M2M_BASE + "fox/animations/" + anim, dest)
        print(f"  [OK] {anim} ({kb} KB)")

    print("\n=== 2. Mesh2Motion Vierbeiner-Modelle (Hund, Katze, Bär/Panda, Wolf) ===")
    for local_name, remote_path in M2M_MODELS:
        dest = os.path.join(M2M_MODELS_DIR, local_name)
        kb = download_file(M2M_BASE + remote_path, dest)
        print(f"  [OK] {local_name} ({kb} KB)")

    print("\n=== 3. Quaternius Ultimate Animated Animals (je 12 Animationen) ===")
    for name in QUATERNIUS_MODELS:
        dest = os.path.join(QUAT_DIR, name)
        kb = download_file(QUAT_BASE + name, dest)
        print(f"  [OK] {name} ({kb} KB)")

    print("\n=== 4. Militär-Waffen-Props (für Zweibeiner-Soldaten) ===")
    for prop in WEAPON_PROPS:
        dest = os.path.join(PROPS_DIR, prop)
        kb = download_file(M2M_BASE + "props/" + prop, dest)
        print(f"  [OK] {prop} ({kb} KB)")


if __name__ == "__main__":
    main()
