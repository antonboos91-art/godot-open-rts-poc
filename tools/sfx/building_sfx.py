"""Gebaeude-Geraeusche je Volk mit MOSS SoundEffect v2 (ComfyUI, TTS Audio Suite) erzeugen.
Ein Sound pro Gebaeudeart und Volk, gespielt wenn man ein eigenes Gebaeude anwaehlt.
  python building_sfx.py [rolle ...]   -> ComfyUI output/bsfx/<volk>_<rolle>_*.flac
Danach: <comfy-venv-python> build_building_sfx.py <comfy-output/bsfx>"""
import json, sys, urllib.request

FAC = {
    "shibas": "clean American high-tech military base, glossy electronics, crisp computer beeps, smooth servo motors, cyan energy hum",
    "katzen": "secretive dark stealth cult base, eerie low synth drones, soft purring machinery, quiet hiss, ghostly violet energy shimmer",
    "baeren": "heavy Soviet industrial base, brutal riveted steel, loud metal clanks, steam hiss, rumbling diesel machinery, old valve radio",
}
ROLE = {
    "hq": "command headquarters: radar ping, radio chatter static, keyboards and humming computers",
    "power": "power plant: deep electrical generator hum, crackling electricity, rising turbine whine",
    "power_big": "huge reactor: massive throbbing reactor core, deep bass rumble, intense electric buzz",
    "refinery": "ore refinery: grinding crusher, conveyor belt rattle, rocks falling into a hopper",
    "barracks": "barracks: heavy door opening, boots marching, weapons being loaded, soldiers shouting in the distance",
    "factory": "vehicle factory: hydraulic press slam, welding sparks, power tools, heavy machinery",
    "silo": "storage silo: heavy vault door locking, metal containers sliding, pressure release",
    "radar": "radar tower: rotating radar dish motor, sonar pings, data beeps",
    "airfield": "airfield: jet engine spool up, landing gear, helicopter rotor starting",
    "repair": "repair workshop: wrench ratchet, hammer on metal, air impact drill",
    "lab": "research laboratory: bubbling liquids, strange electronic scanner sweeps, glass clinks",
    "turret_ground": "defense gun turret: heavy turret rotating with servo, cannon breech loading clack",
    "turret_air": "anti-aircraft flak turret: fast servo rotation, autocannon belt loading, targeting beeps",
    "superweapon": "superweapon silo: ominous charging energy rising, alarm klaxon, massive hatch opening",
}
roles = sys.argv[1:] or list(ROLE)
for fac, style in FAC.items():
    for i, role in enumerate(roles):
        w = {
            "1": {"class_type": "MossSoundEffectV2EngineNode", "inputs": {"model": "MOSS-SoundEffect-v2.0", "device": "auto", "dtype": "auto",
                  "inference_steps": 60, "cfg_scale": 4.5, "sigma_shift": 5.0, "negative_prompt": "speech, talking, music, singing"}},
            "2": {"class_type": "UnifiedSoundEffectsNode", "inputs": {"TTS_engine": ["1", 0], "duration_seconds": 2.5, "seed": 100 + i,
                  "description": f"Short video game building selection sound of a {ROLE[role]}. Style: {style}. Close up, punchy, clean, no voices."}},
            "3": {"class_type": "SaveAudio", "inputs": {"audio": ["2", 0], "filename_prefix": f"bsfx/{fac}_{role}"}},
        }
        r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
        urllib.request.urlopen(r).read()
        print("queued", fac, role)
