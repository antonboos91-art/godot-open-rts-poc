"""Einzelne Ruestungsteile mit Krea-2 Turbo (besser fuer isolierte Objekte als die Anime-SDXL-Modelle).
  python gen_krea.py [seed] [teil ...]  -> ComfyUI-Output clean/krea_<teil>_*.png (Comfy Desktop, Port 8199)"""
import json, urllib.request, sys

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 100
STYLE = ("Isolated single object floating on a pure white background, nothing else in the image, no person, no mannequin, no stand. "
         "High-end sci-fi video game asset, Command and Conquer style, studio product render, soft lighting, sharp details. "
         "Color scheme: glossy white ceramic armor plates, matte dark navy blue under-layer, thin glowing cyan light strips, small white star emblem.")
PARTS = {
    "shoulder": "A single futuristic armored shoulder pauldron for a sci-fi soldier, layered overlapping curved plates, beveled edges, bolts and panel lines, seen from the side at three-quarter angle.",
    "chest": "A futuristic sci-fi soldier chest armor breastplate with integrated abdomen plates, sculpted segmented panels, collar ring, seen from the front at a slight three-quarter angle, empty inside.",
    "forearm": "A single futuristic sci-fi armored forearm gauntlet bracer, segmented plates, small glowing display, seen from the side.",
    "shin": "A single futuristic sci-fi armored shin guard with integrated knee pad, segmented plates, seen from the front at three-quarter angle.",
    "helmet": "A single futuristic sci-fi combat helmet shaped like a shiba inu dog head, armored snout with visor eyes glowing cyan, two pointed armored dog ears on top, helmet seen from the front at three-quarter angle, sculpted plates.",
    "helmet_open": "A single sci-fi armored helmet worn by a shiba inu dog, the realistic furry shiba inu face with cream cheeks and black nose is visible in the open front, pointed fur ears come out through slots on top, short fur, no neck, head only, front three-quarter angle.",
    "helmetless_collar": "A futuristic sci-fi armored neck collar ring, thick segmented plates, seen from the front at three-quarter angle.",
}
names = sys.argv[2:] or ["shoulder", "chest", "forearm", "shin"]
for i, name in enumerate(names):
    w = {
        "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
        "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": f"{PARTS[name]} {STYLE}"}},
        "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 4}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                                 "seed": seed + i, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"clean/krea_{name}"}},
    }
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
    try:
        print(name, urllib.request.urlopen(r).read()[:80])
    except urllib.error.HTTPError as e:
        print(name, e.read()[:800])
