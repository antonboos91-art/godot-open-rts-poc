"""Funk-Effekt auf alle Shiba-Zeilen anwenden, nach game/assets/voice/shibas kopieren
und source/match/players/human/ShibaVoices.gd (Preload-Tabelle) erzeugen."""
import glob, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from radio import radio
SRC="out/concepts/voice"; DST="game/assets/voice/shibas"; GD="game/source/match/players/human/ShibaVoices.gd"
table={}
for f in sorted(glob.glob(SRC+"/*/*.flac")):
    unit=os.path.basename(os.path.dirname(f)); base=os.path.basename(f)
    m=re.match(r"([a-z_]+?)_(\d+)_(.+?)_\d+_?\.flac",base)
    if not m: continue
    cat,i,slug=m.groups()
    if unit=="announcer": cat,i,slug="announcer",cat,i+"_"+slug if False else slug
    os.makedirs(f"{DST}/{unit}",exist_ok=True)
    out=f"{DST}/{unit}/{cat}_{i}.wav"; radio(f,out)
    table.setdefault(unit,{}).setdefault(cat,[]).append(out.replace("game/","res://"))
lines=['## Automatisch erzeugt von Assets-Pipeline/voice/build_pack.py - nicht von Hand bearbeiten.',
       '## Shiba-Funkstimmen: LINES[einheit][kategorie] = [AudioStream, ...]',"extends RefCounted","","const LINES = {"]
for u,cats in table.items():
    lines.append(f'\t"{u}": {{')
    for c,fs in cats.items():
        lines.append(f'\t\t"{c}": [')
        for p in fs: lines.append(f'\t\t\tpreload("{p}"),')
        lines.append("\t\t],")
    lines.append("\t},")
lines.append("}")
open(GD,"w",encoding="utf8",newline="\n").write("\n".join(lines)+"\n")
print({u:{c:len(v) for c,v in cs.items()} for u,cs in table.items()})
