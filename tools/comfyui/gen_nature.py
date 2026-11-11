"""Realistische Natur-Sprites (tote Baeume, verkohlte Kiefern, Felsen, Buesche, Wracks) im Dark-Reign-Stil.
  python gen_nature.py [seed] -> ComfyUI output/clean/nat_<art>_*.png, dann tools/make_nature_sprites.py"""
import json, urllib.request, sys

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1400
STYLE = ("Single isolated object on a pure white background, nothing else, seen from above at a 35 degree isometric "
         "real-time-strategy camera angle, realistic photographic detail, dark gritty war-torn atmosphere, muted desaturated "
         "colors, soft overcast light, sharp focus, full object visible, no ground, no shadow.")
KINDS = {
    "dead": "a dead leafless tree with twisted bare black branches",
    "burnt": "a charred half-burnt pine tree with a few dark green needles left",
    "pine": "a tall dark gloomy pine tree, realistic",
    "oak": "a gnarled old tree with sparse dark withered leaves",
    "bush": "a small dry thorny dead bush",
    "rock": "a large dark weathered boulder with moss stains",
    "wreck": "a small burnt-out rusted wreck of a military vehicle, debris",
}
for i, (name, desc) in enumerate(KINDS.items()):
    w = {
        "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
        "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": f"{desc}. {STYLE}"}},
        "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 4}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                                 "seed": seed + i, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"clean/nat_{name}"}},
    }
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
    print(name, urllib.request.urlopen(r).read()[:50])
