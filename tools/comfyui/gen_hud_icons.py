"""Ressourcen-Symbole fuers HUD (Schrott, Kristall, Strom), Krea 2 -> ComfyUI output/clean/hudicon_<name>_*.png"""
import json, urllib.request, sys
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 3100
STYLE = ("single game UI resource icon, centered, isolated on pure black background, glowing neon green emissive light, "
         "StarCraft 2 style hologram icon, crisp, high contrast, no text")
ICONS = {"scrap": "a small pile of scrap metal gears and bolts", "crystal": "a cluster of glowing crystal shards",
         "power": "a lightning bolt energy symbol", "supply": "a military helmet symbol"}
for i, (n, d) in enumerate(ICONS.items()):
    w = {
        "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
        "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": f"{d}, {STYLE}"}},
        "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 512, "height": 512, "batch_size": 2}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                                 "seed": seed + i, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"clean/hudicon_{n}"}},
    }
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
    print(n, urllib.request.urlopen(r).read()[:40])
