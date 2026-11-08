"""Erzeugt T-Pose-Bilder eines Shiba-Soldaten (Vorlage fuer TRELLIS -> Rigging).
  python gen_tpose.py [seed] [name]
Ergebnis: ComfyUI-Output clean/tpose_<name>_*.png  (Comfy Desktop, Port 8199)"""
import json, urllib.request, sys

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 777
name = sys.argv[2] if len(sys.argv) > 2 else "trooper"
PROMPTS = {
    "trooper": "shiba inu dog soldier, realistic shiba inu dog head, short snout, thick cream cheeks, black nose, friendly but serious look, small triangular ears, red-tan fur with white markings, wearing (matte navy blue:1.3) tactical body armor plates with white trim and pouches, blue armored legs, combat boots, dark blue beret, standing upright on two legs",
    "zapper": "shiba inu dog heavy shock trooper, realistic shiba inu dog head, short snout, cream cheeks, black nose, red-tan fur, wearing bulky (matte white:1.2) power armor with navy blue plates, electric coil backpack, combat boots, standing upright on two legs",
    "ingenieur": "shiba inu dog combat engineer, realistic shiba inu dog head, short snout, cream cheeks, black nose, red-tan fur, white hard hat with ear holes, (matte navy blue:1.3) work overalls, tool belt, utility vest, work boots, standing upright on two legs",
    "rifle": "single futuristic military assault rifle, matte navy blue and white paint, white star decal, side view, horizontal, isolated object",
}
ANCHOR = "(shiba inu:1.4), (red-tan and cream fur, pointed triangular ears, curled tail, short dog snout, not a fox:1.3), "
STYLE = ("(T-pose:1.5), (arms stretched out horizontally to the sides:1.4), legs straight and slightly apart, facing the camera, "
         "front view, full body from head to feet, neutral stance, no weapon, hands open, "
         "solo, single character, pure white background, 3d character model sheet, AAA quality, matte painted armor, navy blue and white paint, realistic military gear, gritty Command and Conquer style, white star insignia, "
         "clean render, soft studio lighting, masterpiece, best quality")
NEG = ("multiple views, turnaround, human, woman, girl, human face, pet, text, watermark, blurry, lowres, cropped, background scenery, "
       "weapon, rifle, gun, sitting, crouching, running, action pose, arms down, arms crossed, side view, back view, dynamic angle, muzzle cage, mask, face mask, all white clothes, lab coat")
if name == "rifle":
    STYLE = "isolated object, pure white background, 3d game asset, AAA quality, clean render, masterpiece, best quality"
    ANCHOR = ""
    NEG = "person, dog, hand, character, text, watermark, blurry, multiple objects, cropped"
w = {
    "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "waiIllustriousSDXL_v170.safetensors"}},
    "2": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": f"{ANCHOR}{PROMPTS[name]}, {STYLE}"}},
    "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": NEG}},
    "4": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 4}},
    "5": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0],
                                                 "seed": seed, "steps": 30, "cfg": 6, "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": 1}},
    "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
    "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": f"clean/tpose_{name}"}},
}
r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": w}).encode(), {"Content-Type": "application/json"})
print(urllib.request.urlopen(r).read()[:200])
