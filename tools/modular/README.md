# Modulare Infanterie (Stand 2026-11-08, Shiba-Prototyp von Anton abgenommen: "lassen wir es so")

Pipeline (alles skriptgesteuert, kein Klick-Tool – Antons Vorgabe):
1. Rüstungsteile per Krea 2 Turbo (Comfy Desktop, Port 8199): `comfyui/gen_krea.py <seed> chest shoulder forearm shin`
   -> beste Bilder wählen -> `comfyui/cut_one.py <bild> <name>` (BiRefNet-Freistellung)
2. 3D per TRELLIS 2 (Port 8200): `trellis/gen3d.py out/concepts/cut/one_<name>_00001_.png <modellname> 6000 2048` (~4 Min.)
3. Kopf: SDXL `comfyui/gen_parts.py <seed> head` (kein Wort "muzzle" verwenden -> Maulkorb!), freistellen, TRELLIS.
   Waffe: Krea/SDXL-Bild -> TRELLIS.
4. Zusammenbau + Sprite-Sheet: `blender -b -P tools/blender/build_modular.py -- <args aus sm3_args.txt> --out <ziel> --size 192`
   - Grundkörper + 46 Animationen: Quaternius Universal Animation Library Standard (CC0),
     liegt in Assets-Pipeline/downloads/ual1 (Quelle: opengameart.org, itch.io blockt Bots)
   - parts JSON: head, rifle (Waffe), a_chest, a_shoulder, a_forearm, a_shin
   - Shiba-Prototyp: Pistole (--two-hand 0), Cyber-Anzug (--suit cyber), dunkelsilberne KI-Rüstung,
     Space-Marine-Proportionen (großer Brustpanzer + Schulterplatten verdecken den Hals)
5. GIFs: `tools/make_gif.py <sheet-ohne-.png> <ordner>`, Übersicht: `tools/sheet_overview.py`
6. Ins Spiel: Sheet + JSON nach assets/sprites/infantry/<volk>_<variante>.png/.json, SpriteInfantry.gd liest es.
   NOCH NICHT GEMACHT: das modulare Shiba-Sheet ist noch nicht im Spiel (dort läuft der ältere Skript-Trooper).

Bekannte Schwächen: Spalt zwischen breitem Brustpanzer und schmalem Arm beim Armschwung; Kopf (TRELLIS-Büste,
wird hinten/unten automatisch beschnitten) wirkt bei Spielgröße wie Fellklumpen; Helm-Entwürfe (offen/geschlossen)
liegen als Bilder vor, auf Antons Wunsch vorerst gestoppt. CLAUDE.md-Regel: echte Shiba-Köpfe, keine Helme statt Köpfen.
Animationen der Gratis-Stufe: keine Gewehr-Animationen (nur Pistole); für Gewehre wäre Mixamo nötig (Antons Adobe-Konto).
