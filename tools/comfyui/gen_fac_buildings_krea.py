"""Gebaeude-Konzeptbilder fuer Katzen/Baeren (SDXL, wie Shibas). python gen_fac_buildings.py katzen|baeren [seed]
Ausgabe: out/concepts/fbld/<volk>_<rolle>_0000N_.png (4 Stueck je Rolle)"""
import json, urllib.request, sys
fac = sys.argv[1]; seed = int(sys.argv[2]) if len(sys.argv) > 2 else 9100
FX = {
 "shibas": dict(style="american military faction like GDI, clean high-tech architecture, glossy white and navy blue panels, thin glowing cyan light strips, white star insignia, polished steel",
                emb="two pointed shiba-inu-ear shaped armor fins on the roof and a white star emblem"),
 "katzen": dict(style="secretive cult-like militant faction like Nod, sleek angular stealth architecture, matte black panels with glowing violet neon lights, sharp spikes, ",
                emb="two pointed cat-ear shaped armor fins on the roof and a glowing violet cat-eye emblem"),
 "baeren": dict(style="soviet-style heavy industrial faction, brutal massive concrete and riveted steel, red paint with gold trim, red star emblem, ",
                emb="round bear-ear shaped dome ornaments and a gold star emblem"),
}[fac]
ROLES = {
 "hq": "military command headquarters building, {e}, radar dish, helipad, no people",
 "power": "military power plant building, cooling towers, {e}, glowing energy core, no people",
 "refinery": "ore refinery industrial building, silos, conveyor, pipes, {e}, no people",
 "barracks": "military barracks building, entrance gate, {e} above door, sandbags, flag pole, no people",
 "factory": "vehicle factory building, big garage door with {e} relief, crane, no people",
 "silo": "storage silo complex, round tanks, {e} emblem, no people",
 "radar": "tall command tower with large radar dish, {e} on top, no people",
 "power_big": "huge reactor power plant with big cooling towers, {e}, glowing core, no people",
 "airfield": "military airfield helipad building, control tower topped with {e}, landing pad markings, no people",
 "repair": "vehicle repair workshop building with crane arm and open bay, {e} emblem, no people",
 "lab": "high tech research laboratory building with dome, antennas, {e}, no people",
 "turret_ground": "defensive gun turret emplacement with twin guns, armored base, {e} emblem",
 "turret_air": "anti-aircraft flak turret emplacement with rotating quad cannons, armored base, {e} emblem",
 "superweapon": "giant superweapon silo building with huge missile or energy cannon, {e} emblem, ominous glow, no people",
}

BASE = ("Isolated single building seen from an isometric three-quarter top-down angle, standing on a small flat base, pure white background, nothing else in the image, no people, no animals. "
        "High-end sci-fi RTS video game asset, Command and Conquer and StarCraft style, studio render, soft lighting, sharp details, highly detailed architecture.")
names = sys.argv[3:] or list(ROLES)
for i, name in enumerate(names):
    p = ROLES[name].format(e=FX["emb"])
    w = {
        "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
        "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": f"A {p}. Style: {FX['style']}. {BASE}"}},
        "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 4}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                                 "seed": seed + i, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"kbld/{fac}_{name}"}},
    }
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
    urllib.request.urlopen(r).read(); print("queued", fac, name)
