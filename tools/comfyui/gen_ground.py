"""Kachelbare Boden-Texturen (Krea 2 Turbo, Comfy Desktop Port 8199).
  python gen_ground.py [seed]  -> out/concepts/clean/ground_<art>_*.png
Danach tools/make_ground_textures.py (kachelbar machen, Normal-Map, nach assets/textures/ground)."""
import json, urllib.request, sys

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1300
STYLE = ("Seamless tileable texture, straight top-down orthographic view of the ground, flat even overcast lighting, no cast shadows, dark gritty realistic, "
         "no horizon, no perspective, no objects, high detail photographic PBR albedo texture for a real-time strategy game, 4k.")
KINDS = {
    # Rollen bleiben (grass = Grundschicht usw.), Inhalt: zerstoerte Kriegserde im Stil von Dark Reign
    "grass": "dark dead withered brown grass and dry soil, war-torn wasteland ground, muted desaturated colors",
    "drygrass": "grey ash and soot covered ground with burnt grass stubble and charcoal bits",
    "dirt": "dark cracked dry mud earth with deep cracks, dusty, desaturated",
    "rock": "dark grey rubble, broken concrete chunks and gravel on dirt",
    "sand": "scorched blackened earth with burn marks and small shell craters",
    "mud": "dark wet churned mud with tank track ruts and puddles",
}
for i, (name, desc) in enumerate(KINDS.items()):
    w = {
        "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
        "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": f"{desc}. {STYLE}"}},
        "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 2}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                                 "seed": seed + i, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
        "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"clean/ground_{name}"}},
    }
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
    print(name, urllib.request.urlopen(r).read()[:50])
