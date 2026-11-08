"""Einzelbild freistellen (BiRefNet). python cut_one.py <bild.png> <name> -> out/concepts/cut/one_<name>_*.png"""
import json, os, shutil, sys, urllib.request
INP = "C:/Users/anton/AppData/Local/Comfy-Desktop/ComfyUI-Installs/EU Magna/ComfyUI/input/bg"
os.makedirs(INP, exist_ok=True)
src, name = sys.argv[1], sys.argv[2]
shutil.copy(src, f"{INP}/{name}.png")
g = {"1": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": "birefnet.safetensors"}},
     "2": {"class_type": "LoadImage", "inputs": {"image": f"bg/{name}.png"}},
     "3": {"class_type": "RemoveBackground", "inputs": {"bg_removal_model": ["1", 0], "image": ["2", 0]}},
     "6": {"class_type": "InvertMask", "inputs": {"mask": ["3", 0]}},
     "4": {"class_type": "JoinImageWithAlpha", "inputs": {"image": ["2", 0], "alpha": ["6", 0]}},
     "5": {"class_type": "SaveImage", "inputs": {"images": ["4", 0], "filename_prefix": f"cut/one_{name}"}}}
r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": g}).encode(), {"Content-Type": "application/json"})
print(urllib.request.urlopen(r).read()[:150])
