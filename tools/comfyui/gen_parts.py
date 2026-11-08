"""Erzeugt Einzelteile fuer modulare Shiba-Soldaten (Kopf, Weste, Schulterpolster, Stiefel, Schwanz).
  python gen_parts.py [seed] [teil ...]   -> ComfyUI-Output clean/part_<teil>_*.png (Comfy Desktop, Port 8199)"""
import json, urllib.request, sys

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
PARTS = {
    "head": "(shiba inu dog head only:1.4), realistic shiba inu head, red-tan fur, cream cheeks, short snout, black nose, mouth closed, pointed triangular ears standing up, "
            "wearing a small (dark navy blue beret:1.2) tilted to one side between the ears, serious soldier expression, bust ends at the neck, front three-quarter view",
    "vest": "(empty military tactical plate carrier vest only:1.5), (no person, no mannequin, no arms, no sleeves:1.4), floating, matte navy blue plate carrier with white trim, pouches, white star emblem on chest, "
            "front three-quarter view, standing upright as if worn",
    "pistol": "(single futuristic sci-fi pistol handgun only:1.4), matte navy blue and white paint, glowing cyan energy cell, side view, horizontal, barrel pointing right, isolated",
    "shoulder": "(single military shoulder armor pad only:1.4), matte navy blue curved armor plate with white stripe, white star decal, isolated, three-quarter view",
    "boot": "(single military combat boot only:1.4), dark navy blue leather combat boot with white laces, side three-quarter view, isolated",
    "tail": "(fluffy curled shiba inu dog tail only:1.4), red-tan and cream fur, tightly curled upward tail, isolated, side view",
}
STYLE = "isolated object, pure white background, 3d game asset, AAA quality, Command and Conquer style, clean render, soft studio lighting, masterpiece, best quality"
NEG = "muzzle cage, muzzle guard, mask, collar, chest, shoulders, torso, sleeves, mannequin, body, full body, person, human, character, hands, multiple objects, text, watermark, blurry, lowres, cropped, background scenery, shadow"
names = sys.argv[2:] or list(PARTS)
for i, name in enumerate(names):
    w = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "waiIllustriousSDXL_v170.safetensors"}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": f"{PARTS[name]}, {STYLE}"}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": NEG}},
        "4": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 4}},
        "5": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0],
                                                     "seed": seed + i, "steps": 30, "cfg": 6, "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": 1}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": f"clean/part_{name}"}},
    }
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
    print(name, urllib.request.urlopen(r).read()[:80])
