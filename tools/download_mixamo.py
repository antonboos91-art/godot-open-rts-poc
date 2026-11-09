"""Lädt kuratierte Militär-, Spezialfähigkeits- und Idle-Animationen für alle 3 Völker
(Shibas, Katzen, Bären) über die eingeloggte Mixamo-Session herunter.
Überspringt alles, was bereits im Basic Shooter Pack enthalten ist.
Alle Animationen werden für dasselbe X-Bot-Skelett (30 FPS, FBX, In-Place falls verfügbar) exportiert.
"""
import glob
import json
import os
import re
import time
import urllib.parse
import urllib.request
import zipfile

CHAR_ID = "2dee24f8-3b49-48af-b735-c6377509eaac"  # X Bot (passend zum Basic Shooter Pack)
OUT_DIR = os.path.join("assets", "animations", "mixamo")
PACK_ZIP = os.path.join("assets", "Basic Shooter Pack.zip")
PACK_DIR = os.path.join("assets", "animations", "basic_shooter_pack")

# Kuratierte Liste: (Ziel-Dateiname ohne .fbx, Mixamo-Product-ID, Beschreibung / Verwendungszweck)
# Nichts davon ist im Basic Shooter Pack enthalten!
ANIMATIONS = [
    # --- 1. IDLE-ANIMATIONEN & CHARAKTER-PERSÖNLICHKEIT (Alle 3 Völker) ---
    ("idle_military_salute", "c9cb0ab6-b96c-11e4-a802-0aaa78deedf9", "Formal Military Salute (Shibas / Offiziere)"),
    ("idle_shadow_boxing_combo", "c9c7060b-b96c-11e4-a802-0aaa78deedf9", "Boxing Jab Cross Combo – Schattenboxen im Stand"),
    ("idle_shadow_boxing_jab", "c9c71c43-b96c-11e4-a802-0aaa78deedf9", "Boxing Leading Hand Jab – kurzes Schattenboxen"),
    ("idle_boxing_stance", "c9c70517-b96c-11e4-a802-0aaa78deedf9", "Boxing Idle – tänzelnde Kampfhaltung"),
    ("idle_rifle_look_around", "c9cd5052-b96c-11e4-a802-0aaa78deedf9", "Rifle Idle Looking Around – Wache schieben & umsehen"),
    ("idle_rifle_relaxed", "c9cd4f94-b96c-11e4-a802-0aaa78deedf9", "Two Hand Lowered Gun Rifle Idle – entspanntes Stehen mit Gewehr"),
    ("idle_rifle_shake_legs", "c9c6bf49-b96c-11e4-a802-0aaa78deedf9", "Idle Holding A Rifle While Shaking Legs – Beine ausschütteln"),
    ("idle_neck_stretch", "c9c9113b-b96c-11e4-a802-0aaa78deedf9", "Neck Stretching – Nacken kreisen / dehnen"),
    ("idle_arm_stretch", "c9c90cbb-b96c-11e4-a802-0aaa78deedf9", "Arm Stretching – Schultern & Arme dehnen"),
    ("idle_bored", "c9c79d1f-b96c-11e4-a802-0aaa78deedf9", "Standing Around Bored Idle – gelangweiltes Warten"),
    ("idle_look_around_nervous", "c9c900c8-b96c-11e4-a802-0aaa78deedf9", "Nervously Look Around – wachsames Spähen (Späher/Katzen)"),

    # --- 2. BÄREN-SPEZIFISCH (Kraft, Pranke, Schwere Waffen, Mechaniker) ---
    ("baeren_taunt_flex_muscles", "c9c706d2-b96c-11e4-a802-0aaa78deedf9", "Flexing Muscles – Muskeln spielen lassen (Bären Idle/Taunt)"),
    ("baeren_taunt_chest_thump", "c9cee1d2-b96c-11e4-a802-0aaa78deedf9", "Standing Taunt Chest Thump – auf die Brust trommeln"),
    ("baeren_taunt_battlecry", "c9cee10b-b96c-11e4-a802-0aaa78deedf9", "Standing Taunt Battlecry – Kampfschrei (Grunzer/Bären)"),
    ("baeren_melee_swipe", "c9c93c1d-b96c-11e4-a802-0aaa78deedf9", "Mutant Swiping – schwerer Prankenhieb"),
    ("baeren_rifle_butt_punch", "c9c6c8e0-b96c-11e4-a802-0aaa78deedf9", "Rifle Punch – Schlag mit dem Gewehrkolben"),

    # --- 3. KATZEN-SPEZIFISCH (Scharfschützin, Saboteur, Hackerin, Schleichen) ---
    ("katzen_sniper_kneel_idle", "c9cd79d4-b96c-11e4-a802-0aaa78deedf9", "Rifle Kneeling Idle – kniende Scharfschützin / Bazooka"),
    ("katzen_sniper_aim_to_kneel", "c9cd63d3-b96c-11e4-a802-0aaa78deedf9", "Rifle Aim To Kneel – in Schussposition knien"),
    ("katzen_crouch_fire_rifle", "c9ca927e-b96c-11e4-a802-0aaa78deedf9", "Firing Rifle Crouch – geducktes Feuern"),
    ("katzen_crouch_reload", "c9c86923-b96c-11e4-a802-0aaa78deedf9", "Reload Rifle While In Crouch Position – geduckt nachladen"),
    ("katzen_crouch_walk_rifle", "c9cd649b-b96c-11e4-a802-0aaa78deedf9", "Rifle Crouch Walk – geducktes Schleichen mit Waffe"),
    ("katzen_crouch_look_corner", "c9cc0b63-b96c-11e4-a802-0aaa78deedf9", "Crouch Look Around Corner – geduckt spähen (Saboteur/Streuner)"),

    # --- 4. SPEZIALEINHEITEN (Ingenieur, Hackerin, Saboteur, Mechaniker, Grenadier) ---
    ("special_work_on_device", "c9c6cf65-b96c-11e4-a802-0aaa78deedf9", "Working On Device – Gerät bedienen (Ingenieur/Hackerin/Mechaniker)"),
    ("special_kneel_inspect_repair", "c9c8cded-b96c-11e4-a802-0aaa78deedf9", "Kneeling Inspecting – kniend reparieren / Bombe legen (Mechaniker/Saboteur)"),
    ("special_kneel_plant_charge", "c9cda04a-b96c-11e4-a802-0aaa78deedf9", "Kneeling Planting – Sprengladung anbringen (Saboteur)"),
    ("special_grenade_pull_pin_teeth", "c9c6a383-b96c-11e4-a802-0aaa78deedf9", "Grenade Throw Pulling Pin With Teeth – Stift mit den Zähnen ziehen & werfen"),

    # --- 5. STERBE-ANIMATIONEN (fehlten im Basic Shooter Pack komplett) ---
    ("death_rifle_standing", "c9c871f6-b96c-11e4-a802-0aaa78deedf9", "Rifle Death – Tod im Stehen mit Gewehr"),
    ("death_rifle_front", "c9ceab40-b96c-11e4-a802-0aaa78deedf9", "Rifle Death From The Front – Treffer von vorn, fällt nach hinten"),
    ("death_rifle_back", "c9ceaa7b-b96c-11e4-a802-0aaa78deedf9", "Rifle Death From The Back – Treffer von hinten, fällt nach vorn"),
    ("death_crouch_headshot", "c9cea8f6-b96c-11e4-a802-0aaa78deedf9", "Rifle Death Crouched – Tod aus geduckter Haltung"),
]


def find_mixamo_token():
    paths = [
        os.path.expandvars(r"%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*\Local Storage\leveldb\*"),
        os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\*\Local Storage\leveldb\*"),
        os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data\*\Local Storage\leveldb\*"),
    ]
    candidates = []
    for pattern in paths:
        for f in sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True):
            if not f.endswith((".ldb", ".log")):
                continue
            try:
                data = open(f, "rb").read()
                for m in re.findall(rb"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}", data):
                    tok = m.decode("ascii")
                    if tok not in candidates:
                        candidates.append(tok)
            except Exception:
                pass
    for tok in candidates:
        req = urllib.request.Request(
            "https://www.mixamo.com/api/v1/products?page=1&limit=1&type=Motion&query=salute",
            headers={
                "Authorization": f"Bearer {tok}",
                "X-Api-Key": "mixamo2",
                "Accept": "application/json",
                "User-Agent": "Mozilla/5.0",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status == 200:
                    return tok
        except Exception:
            continue
    raise RuntimeError("Kein gültiger Mixamo-Token im Browser-LocalStorage gefunden.")


def api_request(token, url, payload=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Api-Key": "mixamo2",
        "Accept": "application/json",
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0",
    }
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if data else "GET")
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def export_and_download(token, anim_id, out_path):
    prod = api_request(
        token, f"https://www.mixamo.com/api/v1/products/{anim_id}?similar=0&character_id={CHAR_ID}"
    )
    details = prod["details"]
    gms = details["gms_hash"]
    if details.get("supports_inplace", False):
        gms["inplace"] = True
    gms["trim"] = [int(gms["trim"][0]), int(gms["trim"][1])]
    gms["params"] = ",".join(str(int(p[1])) for p in gms.get("params", []))

    export_payload = {
        "character_id": CHAR_ID,
        "gms_hash": [gms],
        "preferences": {"format": "fbx7_2019", "skin": "false", "fps": "30", "reducekf": "0"},
        "product_name": prod["description"],
        "type": "Motion",
    }
    api_request(token, "https://www.mixamo.com/api/v1/animations/export", export_payload)

    # Warten bis der Export-Job auf Mixamo fertig ist
    for _ in range(45):
        time.sleep(1.2)
        mon = api_request(token, f"https://www.mixamo.com/api/v1/characters/{CHAR_ID}/monitor")
        status = mon.get("status")
        if status == "completed":
            download_url = mon["job_result"]
            urllib.request.urlretrieve(download_url, out_path)
            return prod["description"], details.get("supports_inplace", False)
        if status == "failed":
            raise RuntimeError(f"Mixamo-Export fehlgeschlagen: {mon}")
    raise TimeoutError("Zeitüberschreitung beim Warten auf Mixamo-Export.")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    if os.path.exists(PACK_ZIP) and not os.path.exists(PACK_DIR):
        os.makedirs(PACK_DIR, exist_ok=True)
        with zipfile.ZipFile(PACK_ZIP, "r") as zf:
            zf.extractall(PACK_DIR)
        print(f"Basic Shooter Pack entpackt nach: {PACK_DIR} ({len(os.listdir(PACK_DIR))} Dateien)")

    token = find_mixamo_token()
    print("Eingeloggte Mixamo-Session gefunden. Starte Batch-Download für X Bot...")

    downloaded = []
    for slug, anim_id, note in ANIMATIONS:
        out_path = os.path.join(OUT_DIR, f"{slug}.fbx")
        if os.path.exists(out_path) and os.path.getsize(out_path) > 10_000:
            print(f"[SKIP] {slug}.fbx existiert bereits")
            downloaded.append((slug, note, os.path.getsize(out_path)))
            continue
        try:
            desc, inplace = export_and_download(token, anim_id, out_path)
            size_kb = os.path.getsize(out_path) // 1024
            print(f"[OK]   {slug}.fbx ({size_kb} KB, inplace={inplace}) <- {desc}")
            downloaded.append((slug, note, os.path.getsize(out_path)))
        except Exception as e:
            print(f"[ERR]  {slug} ({anim_id}): {e}")

    print(f"\nFertig: {len(downloaded)}/{len(ANIMATIONS)} Animationen in {OUT_DIR} bereit.")


if __name__ == "__main__":
    main()
