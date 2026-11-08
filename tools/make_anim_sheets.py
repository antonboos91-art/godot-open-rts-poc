"""Baut aus den freigestellten ComfyUI-Frames Animations-Spritesheets fuer Godot.
Pro Einheit: <name>_anim.png = 2 Clips x 16 Frames nebeneinander (Quadrate, RGBA)."""
import glob, os
from PIL import Image
OUT="game/assets/sprites/units"; SIZE=160; FR=16
UNITS={"shibas_trooper":("rifleman_salute","rifleman_scratch"),
       "shibas_zapper":("rocket_salute","rocket_scratch"),
       "shibas_ingenieur":("engineer_salute","engineer_scratch"),
       "shibas_schnueffler":("sniffer_sniff","sniffer_scratch")}
## Clips, die nicht zum Startbild zurueckkehren, laufen hin und zurueck (Ping-Pong)
PINGPONG={"shibas_schnueffler"}
def frames(a):
    d=f"out/concepts/cut/{a}"; fs={}
    for f in sorted(glob.glob(d+"/f*_*.png")): fs[os.path.basename(f)[:3]]=f   # letzte Version je Frame
    return [Image.open(fs[k]).convert("RGBA") for k in sorted(fs)]
for name,clips in UNITS.items():
    cl=[frames(c) for c in clips]
    boxes=[im.getchannel("A").point(lambda v:255 if v>20 else 0).getbbox() for c in cl for im in c]
    x0=min(b[0] for b in boxes);y0=min(b[1] for b in boxes);x1=max(b[2] for b in boxes);y1=max(b[3] for b in boxes)
    side=max(x1-x0,y1-y0); cx=(x0+x1)//2
    box=(cx-side//2,y1-side,cx-side//2+side,y1)     # unten buendig (Fuesse), quadratisch
    sheet=Image.new("RGBA",(SIZE*FR*2,SIZE),(0,0,0,0))
    for ci,c in enumerate(cl):
        idx=[min(i*2,len(c)-1) for i in range(FR)]
        if name in PINGPONG:
            idx=list(range(0,32,4))+list(range(28,-1,-4))
        for i,k in enumerate(idx):
            im=c[min(k,len(c)-1)].crop(box).resize((SIZE,SIZE),Image.LANCZOS)
            sheet.paste(im,((ci*FR+i)*SIZE,0))
    sheet.save(f"{OUT}/{name}_anim.png"); print(name,sheet.size,box)
