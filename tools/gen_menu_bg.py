"""Hintergrundbild fuer den Startbildschirm (Krea 2 Turbo): die drei Voelker im Krieg.
  python gen_menu_bg.py [seed]   ->  ComfyUI output/menu/menu_bg_0000N_.png (4 Varianten)"""
import json, urllib.request, sys

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 4242
PROMPT = (
    "Epic cinematic key art of a huge battlefield at dusk, three animal armies clashing in an all-out war. "
    "On the left: anthropomorphic shiba inu dog soldiers with real shiba heads, in glossy white and navy blue power armor "
    "with white star insignia, futuristic blue-white hover tanks firing cyan lasers. "
    "On the right: anthropomorphic bear soldiers in heavy soviet-style red armor with gold trim and red stars, "
    "massive red tanks with gold stars firing heavy cannons, red banners. "
    "In the middle and background: sleek black-armored cat assassins with glowing violet eyes, black and violet stealth hover tanks "
    "firing purple plasma beams, violet neon lights. "
    "Burning ruined city, dead trees, explosions, smoke and ash in the air, glowing green crystals on the ground, "
    "dramatic orange sky with dark storm clouds, rim lighting, volumetric light, high detail. "
    "Style: Command and Conquer and StarCraft cinematic box art, AAA video game poster, painterly digital art. "
    "Dark empty sky area in the center top for a title, no text, no letters, no logo, no watermark."
)
w = {
    "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
    "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
    "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
    "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": PROMPT}},
    "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
    "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1792, "height": 1008, "batch_size": 1}},
    "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                             "seed": seed, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
    "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
    "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "menu/menu_bg"}},
}
for k in range(4):
    w["3"]["inputs"]["seed"] = seed + k
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
    urllib.request.urlopen(r).read()
    print("queued", seed + k)
