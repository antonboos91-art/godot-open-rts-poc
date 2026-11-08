"""Erzeugt Voice-Lines per ComfyUI (TTS Audio Suite, Qwen3-TTS VoiceDesign).
python tts.py test           -> nur 'Shiba reporting.'
python tts.py all            -> alle Zeilen aus shiba_voice_lines.json
"""
import json, sys, urllib.request, re
VOICE = ("A gruff, deep adult male soldier voice, calm and dead serious, clipped military radio delivery, "
         "like a 1990s real-time strategy game unit, slightly raspy, no emotion, no humor.")
REF = "Shiba reporting. Yes, commander. Awaiting orders."
def graph(text, prefix, seed=7):
    return {
     "1":{"class_type":"F5TTSEngineNode","inputs":{"language":"F5TTS_v1_Base","device":"auto","temperature":0.8,"speed":0.95,"target_rms":0.1,"cross_fade_duration":0.15,"nfe_step":32,"cfg_strength":2.0}},
     "3":{"class_type":"UnifiedTTSTextNode","inputs":{"TTS_engine":["1",0],"text":text,"narrator_voice":"voices_examples/male/male_01.wav","seed":seed}},
     "4":{"class_type":"SaveAudio","inputs":{"audio":["3",0],"filename_prefix":"voice/"+prefix}}}
def submit(g):
    r=urllib.request.Request("http://127.0.0.1:8199/prompt",json.dumps({"prompt":g}).encode(),{"Content-Type":"application/json"})
    try: return urllib.request.urlopen(r).read()[:80]
    except urllib.error.HTTPError as e: return e.read()[:1200]
mode=sys.argv[1] if len(sys.argv)>1 else "test"
if mode=="test": print(submit(graph("Shiba reporting.","test_reporting")))
else:
    data=json.load(open("shiba_voice_lines.json",encoding="utf8"))
    def slug(s): return re.sub(r"[^a-z0-9]+","_",s.lower()).strip("_")[:40]
    for unit,cats in data["units"].items():
        for cat,lines in cats.items():
            for i,t in enumerate(lines): print(unit,cat,i,submit(graph(t,f"{unit}/{cat}_{i}_{slug(t)}")))
    for i,t in enumerate(data["announcer"]): print("announcer",i,submit(graph(t,f"announcer/{i}_{slug(t)}")))
