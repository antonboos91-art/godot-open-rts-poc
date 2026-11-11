"""Voice-Lines fuer alle Voelker per F5-TTS (ComfyUI TTS Audio Suite), Stimme je Volk ueber eine Referenzstimme.
  python tts_design.py voice_lines.json [volk|-] [test]
Ausgabe: ComfyUI output/voice2/<volk>/<paket>/<kategorie>_<i>_*.flac ; danach build_voices.py (Funk, Fluestern, Pack).
Baeren: russischer Akzent ueber Lautschrift (accent_ru). Katzen: Fluestern entsteht in build_voices.py."""
import json, sys, urllib.request, re

VOICE = {
    "shibas": ("voices_examples/male/male_01.wav", 1.12),
    "katzen": ("voices_examples/higgs_audio/vex.wav", 0.95),
    "baeren": ("voices_examples/male/male_02.wav", 0.98),
    "shibas_announcer": ("voices_examples/female/female_01.wav", 1.0),
    "katzen_announcer": ("voices_examples/female/female_02.wav", 0.92),
    "baeren_announcer": ("voices_examples/higgs_audio/en_man.wav", 0.95),
}


def accent_ru(t):
    rules = [(r"\bthe\b", "ze"), (r"\bThe\b", "Ze"), (r"\bthis\b", "zis"), (r"\bthat\b", "zat"), (r"\bthey\b", "zey"),
             (r"\bthem\b", "zem"), (r"\bthere\b", "zere"), (r"\bwe\b", "ve"), (r"\bWe\b", "Ve"), (r"\bwill\b", "vill"),
             (r"\bwhat\b", "vat"), (r"\bWhat\b", "Vat"), (r"\bwhere\b", "vere"), (r"\bWhere\b", "Vere"), (r"\bwith\b", "vith"),
             (r"\bwork\b", "vork"), (r"\bwisely\b", "vise-ly"), (r"ing\b", "eeng")]
    for a, b in rules:
        t = re.sub(a, b, t)
    return t


def graph(voice_key, text, prefix, seed):
    ref, speed = VOICE[voice_key]
    return {
        "1": {"class_type": "F5TTSEngineNode", "inputs": {"language": "F5TTS_v1_Base", "device": "auto", "temperature": 0.65, "speed": speed,
                                                         "target_rms": 0.1, "cross_fade_duration": 0.15, "nfe_step": 32, "cfg_strength": 2.0}},
        "3": {"class_type": "UnifiedTTSTextNode", "inputs": {"TTS_engine": ["1", 0], "text": text, "narrator_voice": ref, "seed": seed}},
        "4": {"class_type": "SaveAudio", "inputs": {"audio": ["3", 0], "filename_prefix": prefix}},
    }


def submit(g):
    r = urllib.request.Request("http://127.0.0.1:8199/prompt", json.dumps({"prompt": g}).encode(), {"Content-Type": "application/json"})
    try:
        return urllib.request.urlopen(r).read()[:60]
    except urllib.error.HTTPError as e:
        return e.read()[:800]


data = json.load(open(sys.argv[1], encoding="utf8"))
only = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "-" else None
test = len(sys.argv) > 3
for fac, block in data.items():
    if only and fac != only:
        continue
    fix = accent_ru if fac == "baeren" else (lambda s: s)
    done = False
    for pack, cats in block["units"].items():
        for cat, lines in cats.items():
            for i, t in enumerate(lines):
                print(fac, pack, cat, i, submit(graph(fac, fix(t), f"voice2/{fac}/{pack}/{cat}_{i}", 100 + i)))
                if test:
                    done = True
                    break
            if done:
                break
        if done:
            break
    for key, t in block["announcer"].items():
        print(fac, "announcer", key, submit(graph(fac + "_announcer", fix(t), f"voice2/{fac}/announcer/{key}_0", 7)))
        if test:
            break
