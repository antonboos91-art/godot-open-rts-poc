"""Voelkerspezifische Ruestungsteile (Krea 2 Turbo, Comfy Desktop Port 8199) fuer die modulare Infanterie.
  python gen_faction_armor.py <katzen|baeren> [seed]  -> out/concepts/clean/fa_<volk>_<teil>_<variante>_*.png
Varianten: a = Standard, b = zweite Silhouette (damit nicht jede Einheit dasselbe Teil traegt)."""
import json, urllib.request, sys

fac = sys.argv[1]
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 500
BASE = ("Isolated single object floating on a pure white background, nothing else in the image, no person, no mannequin, no stand. "
        "High-end sci-fi video game asset, Command and Conquer style, studio product render, soft lighting, sharp details. ")
STYLE = {
    "katzen": BASE + "Color scheme: matte black armor plates with deep violet glowing light strips and purple trim, sleek stealth design, Brotherhood of Nod inspired, small cat-ear emblem.",
    "baeren": BASE + "Color scheme: heavy riveted dark red painted steel with gold brass trim and gold stripes, Soviet Red Army brutalist industrial design, small gold star and hammer emblem.",
}[fac]
SHAPE = {
    "katzen": {
        "chest_a": "A slim sleek stealth sci-fi chest armor breastplate with narrow waist, angular blade-like panels and a high collar, seen from the front at a slight three-quarter angle, empty inside.",
        "chest_b": "A lightweight sci-fi tactical vest chest armor with a rounded hood-like high collar, cloth sash and small plates, seen from the front at a slight three-quarter angle, empty inside.",
        "shoulder_a": "A single slim angular futuristic shoulder pauldron with sharp blade-like edges, seen from the side at three-quarter angle.",
        "shoulder_b": "A single small rounded sci-fi shoulder guard with a short flowing cloth cape piece attached, seen from the side at three-quarter angle.",
        "forearm_a": "A single slim sleek sci-fi forearm bracer with a small glowing violet display and blade fin, seen from the side.",
        "shin_a": "A single slim sleek sci-fi shin guard with integrated knee pad and swept back fin, seen from the front at three-quarter angle.",
    },
    "baeren": {
        "chest_a": "A massive heavy Soviet sci-fi chest armor breastplate, thick riveted steel plates, wide barrel chest, big star emblem, seen from the front at a slight three-quarter angle, empty inside.",
        "chest_b": "A heavy Soviet military greatcoat style chest armor with thick fur collar, double row of gold buttons and steel plates, seen from the front at a slight three-quarter angle, empty inside.",
        "shoulder_a": "A single huge heavy riveted steel shoulder pauldron with gold trim and a red star, seen from the side at three-quarter angle.",
        "shoulder_b": "A single round fur trimmed military shoulder epaulette with gold fringe and steel plate, seen from the side at three-quarter angle.",
        "forearm_a": "A single thick heavy riveted steel forearm gauntlet with gold bands, seen from the side.",
        "shin_a": "A single thick heavy riveted steel shin guard with big knee plate and gold trim, seen from the front at three-quarter angle.",
    },
}[fac]
for i, (name, shape) in enumerate(SHAPE.items()):
    w = {
        "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
        "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": f"{shape} {STYLE}"}},
        "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 4}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                                 "seed": seed + i, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"clean/fa_{fac}_{name}"}},
    }
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
    try:
        print(name, urllib.request.urlopen(r).read()[:60])
    except urllib.error.HTTPError as e:
        print(name, e.read()[:800])
