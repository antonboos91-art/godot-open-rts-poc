"""Untere HUD-Konsole als KI-Bild (Krea 2), je Volk: python gen_hud_console.py <volk> [seed]
-> ComfyUI output/clean/console_<volk>_*.png ; danach tools/make_hud_console.py (Bildschirme finden, freistellen)."""
import json, urllib.request, sys
fac = sys.argv[1]
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 4100
LOOK = {
    "shibas": "heavy beveled gunmetal and dark navy blue armor plating with white painted accents and cyan glowing light strips",
    "katzen": "sleek angular matte black armor plating with dark violet accents, sharp blade-like edges and purple glowing light strips",
    "baeren": "massive riveted dark red painted steel plating with brass gold trim, Soviet star emblems and warm orange glowing lamps",
}[fac]
text = (f"Sci-fi real-time strategy game bottom HUD console bar, very wide, {LOOK}, rivets, vents, cables, scratches and wear, "
        "four recessed empty pitch black screens: a square minimap screen on the far left, a long wide empty screen in the middle, "
        "a small portrait screen, and a square screen on the far right, the black screens are completely empty and flat, "
        "front orthographic view, StarCraft 2 style console, AAA game UI art, highly detailed hard surface, isolated on pure black background")
w = {
    "10": {"class_type": "UNETLoader", "inputs": {"unet_name": "krea2_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
    "11": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"}},
    "12": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
    "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["11", 0], "text": text}},
    "13": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["6", 0]}},
    "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1920, "height": 400, "batch_size": 3}},
    "3": {"class_type": "KSampler", "inputs": {"model": ["10", 0], "positive": ["6", 0], "negative": ["13", 0], "latent_image": ["5", 0],
                                             "seed": seed, "steps": 8, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1}},
    "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["12", 0]}},
    "29": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": f"clean/console_{fac}"}},
}
r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
print(fac, urllib.request.urlopen(r).read()[:40])
