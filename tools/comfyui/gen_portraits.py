"""Einheiten-Portraets im StarCraft-Stil (Kopf/Schulter, dunkler Hintergrund, Monitor-Licht), je Einheit ein Bild.
  python gen_portraits.py [seed] -> ComfyUI output/clean/portrait_<volk>_<einheit>_00001_.png
Danach tools/make_portraits.py (zuschneiden, nach assets/ui/portraits)."""
import json, urllib.request, sys

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 2200
STYLE = ("Video game unit portrait in the style of StarCraft 2 and Command and Conquer, head and shoulders close-up, "
         "looking at the viewer, dramatic rim light, dark gritty sci-fi atmosphere, dark background with faint monitor scanlines, "
         "highly detailed realistic 3D render, cinematic, centered composition.")
SPECIES = {
    "shibas": "an anthropomorphic shiba inu dog soldier with real shiba fur face, navy blue and white futuristic armor with cyan lights",
    "katzen": "an anthropomorphic black cat soldier with real cat fur face and glowing eyes, sleek black and violet stealth armor with purple lights",
    "baeren": "an anthropomorphic brown bear soldier with real bear fur face, heavy dark red and gold Soviet style armor with a red star",
}
ROLE = {
    "trooper": "rifleman with a combat helmet visor pushed up", "zapper": "heavy shock trooper with electric arc gun on shoulder",
    "schnueffler": "scout with sensor goggles and antenna", "ingenieur": "engineer with welding goggles and tools",
    "kampfhund": "fierce war dog without armor helmet, bared teeth, armored collar", "sammler": "salvage truck driver with headset in a cockpit",
    "buggy": "fast buggy driver with goggles in a cockpit", "tesla": "tank commander with headset in a tank hatch, electric sparks",
    "raketen": "rocket artillery operator with targeting monocle", "baumobil": "construction vehicle operator with hard hat",
    "wespe": "drone pilot with VR visor", "gewitter": "gunship pilot with flight helmet",
    "streuner": "street soldier with hood and scar", "scharfschuetzin": "female sniper with laser scope eyepiece",
    "hackerin": "female hacker with holographic visor and cables", "saboteur": "saboteur with balaclava and night vision",
    "panther": "black panther war beast with glowing violet cybernetic eye", "phantom": "hover glider pilot with sleek helmet",
    "prisma": "tank commander with violet crystal-lit cockpit", "nebelwerfer": "artillery operator with gas mask",
    "nestmobil": "mobile base operator with headset", "nachtfalter": "stealth pilot with moth-wing helmet",
    "kreischer": "bomber pilot with screaming war paint", "grunzer": "grizzled infantry grunt with ushanka helmet",
    "feuertatze": "flamethrower trooper with soot covered face and gas tank", "bazooka": "rocket launcher heavy with scarred muzzle",
    "mechaniker": "mechanic with wrench and oil stained face", "kodiak": "huge armored kodiak war bear roaring",
    "kipper": "dump truck driver with cigar and headset", "rammbock": "ram vehicle driver with battle scars",
    "grizzly": "heavy tank commander with fur hat and headset", "moerser": "mortar crew chief with binoculars",
    "hoehlenmobil": "mobile base foreman with hard hat", "brummkopter": "helicopter pilot with aviator goggles",
    "flugkessel": "airship captain with brass goggles",
}
UNITS = {"shibas": ["trooper", "zapper", "schnueffler", "ingenieur", "kampfhund", "sammler", "buggy", "tesla", "raketen", "baumobil", "wespe", "gewitter"],
         "katzen": ["streuner", "scharfschuetzin", "hackerin", "saboteur", "panther", "sammler", "phantom", "prisma", "nebelwerfer", "nestmobil", "nachtfalter", "kreischer"],
         "baeren": ["grunzer", "feuertatze", "bazooka", "mechaniker", "kodiak", "kipper", "rammbock", "grizzly", "moerser", "hoehlenmobil", "brummkopter", "flugkessel"]}
only = sys.argv[2:]
i = 0
for fac, units in UNITS.items():
    for u in units:
        i += 1
        if only and f"{fac}_{u}" not in only:
            continue
        text = f"Portrait of {SPECIES[fac]}, {ROLE[u]}. {STYLE}"
        if u in ("kampfhund", "panther", "kodiak"):
            text = f"Portrait of {ROLE[u]}, {fac} faction colors. {STYLE}"
        w = {
            "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
            "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
            "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
            "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": text}},
            "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
            "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 768, "height": 896, "batch_size": 1}},
            "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                                     "seed": seed + i, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
            "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
            "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"clean/portrait_{fac}_{u}"}},
        }
        r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
        print(fac, u, urllib.request.urlopen(r).read()[:40])
