import json, os, shutil, urllib.request, glob
INP="C:/Users/anton/AppData/Local/Comfy-Desktop/ComfyUI-Installs/EU Magna/ComfyUI/input/bg"
os.makedirs(INP,exist_ok=True)
for src in sorted(glob.glob("../out/concepts/kbld/*_00001_.png")):
    v=os.path.basename(src).rsplit("_0000",1)[0]
    n=f"fb_{v}.png"; shutil.copy(src,f"{INP}/{n}")
    g={"1":{"class_type":"LoadBackgroundRemovalModel","inputs":{"bg_removal_name":"birefnet.safetensors"}},
       "2":{"class_type":"LoadImage","inputs":{"image":"bg/"+n}},
       "3":{"class_type":"RemoveBackground","inputs":{"bg_removal_model":["1",0],"image":["2",0]}},
       "6":{"class_type":"InvertMask","inputs":{"mask":["3",0]}},
       "4":{"class_type":"JoinImageWithAlpha","inputs":{"image":["2",0],"alpha":["6",0]}},
       "5":{"class_type":"SaveImage","inputs":{"images":["4",0],"filename_prefix":f"cut_fb/{v}"}}}
    r=urllib.request.Request("http://127.0.0.1:8199/prompt",json.dumps({"prompt":g}).encode(),{"Content-Type":"application/json"})
    urllib.request.urlopen(r).read()
print("queued")
