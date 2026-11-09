# Übergabe: Infanterie von 2D-Sprites auf echte 3D-Figuren umbauen

Stand: 2026-11-09. Repo: `C:\Users\anton\Desktop\Assets-Pipeline\game` (Godot 4.3, `origin/main`, Commit 977a9d4 ist der letzte).
Antworten an Anton auf Deutsch. Regeln stehen in `CLAUDE.md` ("mach alles fertig" heißt wirklich alles, nur Desktop, selbst nach main mergen/pushen, keine manuellen Klick-Schritte für Anton).

## Ziel

Alle Infanterie-Einheiten (12 Zweibeiner: je 4 pro Volk Shibas/Katzen/Bären, dazu die 3 Vierbeiner) laufen im Spiel als echte 3D-Figuren mit Skelett-Animation statt als vorgerenderte 8-Richtungs-Sprites.
Warum: Anton will echte Beleuchtung (Tag/Nacht, Mündungsfeuer, Lampen, Schatten) und freie Kameradrehung. Vorgerenderte Sprites reagieren nicht auf Licht.
Reihenfolge des Gesamtumbaus (von Anton bestätigt): 1. Infanterie + Vierbeiner, 2. Fahrzeuge/Helikopter, 3. Gebäude. Die Sprites bleiben als Rückfall, bis alles 3D ist. **Diese Übergabe betrifft nur Schritt 1.**

## Wie die Infanterie heute entsteht (nicht ändern, nur wiederverwenden)

- Blender-Skript `tools/blender/build_modular_mx.py` baut aus dem Mixamo-"X Bot" (`C:/Users/anton/Desktop/RTS/assets/animations/basic_shooter_pack/X Bot.fbx`) eine Figur:
  Cyber-Anzug (prozedurales Material), Kopf (Katze/Bär/Shiba aus TRELLIS-GLB), Rüstungsteile `a_chest, a_shoulder, a_forearm, a_shin` (TRELLIS-GLBs in `out/3d/`), Waffe aus `C:/Users/anton/Desktop/RTS/assets/animations/props/*.glb`.
- Animationen (Mixamo-FBX, Pfade stehen in `CLIPS` im Skript): `idle` (rifle aiming idle), `walk` (rifle run, 8 Frames), `shoot` (firing rifle), `die` (mixamo/death_rifle_back), `idle_a` (reloading), `idle_b` (salute).
- Pro Einheit eine Zeile in `tools/modular/unit_queue.sh` (Teile, Körperbau `--bw/--bh`, Waffe, Leuchtfarbe `--glow/--plate`, `--gain`). Das Skript rendert bisher `assets/sprites/infantry/<volk>_<einheit>.png/.json`.
- Vierbeiner: `tools/blender/build_quadruped.py` (mesh2motion-Modelle in `RTS/assets/animations/quadrupeds`, Animations-GLBs sind meshopt-komprimiert, Decoder `tools/blender/meshopt_decode.py`).
- Blender: `C:/Program Files/Blender Foundation/Blender 4.5/blender.exe`. Python mit PIL: `Assets-Pipeline/trellis/venv/Scripts/python.exe`. Godot: `Assets-Pipeline/godot_bin/Godot_v4.3-stable_win64_console.exe` (für neue Dateien erst `--headless --path . --import`).
- Im Spiel: `source/match/units/traits/SpriteInfantry.gd` (liest Sheet+JSON, wählt Zeile nach Blickrichtung, Clips idle/walk/shoot/die/idle_a/idle_b, Leiche bleibt 8 s). Angehängt von `PixelSprite.try_attach`. Es gibt auch schon einen Pfad für echte 3D-Modelle: `PixelSprite._attach_model` mit `assets/models/factions/<volk>_<variante>.glb`.

## Aufgaben

### 1. Export-Modus im Blender-Skript

In `build_modular_mx.py` einen Modus `--export-glb <pfad.glb>` ergänzen (statt Sprite-Sheet zu rendern):

- Nach dem Zusammenbau (nach `rig.scale = ...`, vor "Kamera / Licht") die Figur als GLB exportieren, **mit allen 6 Animationen** unter den Namen `idle, walk, shoot, die, idle_a, idle_b` (die Actions in `ACT` umbenennen, Fake-User beibehalten, Export mit `export_animation_mode='ACTIONS'`).
- **Root-Motion entfernen:** Die Hüfte (`mixamorig:Hips`) bewegt sich in den Mixamo-Clips (z. B. beim Laufen Verschiebung in X/Y). Location-Kurven X und Y der Hüfte pro Clip auf den Wert des ersten Frames setzen, Z (Höhe) behalten. Die Figur soll auf der Stelle laufen, das Spiel bewegt sie.
- **Prozedurales Anzug-Material backen:** Das Voronoi-Material `suit` (Platten + leuchtende Linien) exportiert der glTF-Exporter nicht. Entweder auf Textur backen (Cycles-Bake Base Color + Emission über die vorhandene UV `map1` der Meshes `Beta_Surface`/`Beta_Joints`) und dann ein einfaches Principled-Material mit Basis-Textur + Emission-Textur zuweisen, oder das Muster in Godot per Shader nachbauen. Backen ist der einfachere Weg.
- **Texturen verkleinern:** Die TRELLIS-Teile haben 2048er-Texturen. Alle Bilder vor dem Export auf 512×512 skalieren (`image.scale`), Export als JPEG (Qualität ~80), damit eine Einheit unter ~2 MB bleibt.
- Ausrichtung: Figur blickt in Blender nach -Y. Nach dem Export prüfen, in welche Richtung sie in Godot schaut, und die Drehung (`rotation_y`) in der Godot-Szene so setzen, dass "vorwärts" der Laufrichtung entspricht.
- `tools/modular/unit_queue.sh` um den Export erweitern (zusätzlich zum Sheet oder per Schalter), Ausgabe nach `assets/models/infantry/<volk>_<einheit>.glb`. Alle 12 Einheiten exportieren.
- Vierbeiner (`kampfhund`, `panther`, `kodiak`): gleiches Vorgehen in `build_quadruped.py`, Animationen aus den mesh2motion-GLBs (Idle, Walk, Attack, Death), Ausgabe `assets/models/infantry/<volk>_<kampfhund|panther|kodiak>.glb`.

### 2. Godot: 3D-Figur statt Sprite

- Neues Skript `source/match/units/traits/Infantry3D.gd` (Vorbild: `SpriteInfantry.gd`, gleiche Zustände):
  - GLB aus `assets/models/infantry/` laden, Figur auf `FIGURE_HEIGHT = 1.9` skalieren (Blender-Figur ist ~1.85 m).
  - `AnimationPlayer` finden und je Zustand abspielen: Bewegung (Positionsänderung wie in `SpriteInfantry._process`) → `walk` (Schleife), Feuern (`child_entered_tree` mit `target_unit`, siehe `_on_unit_child_entered`) → `shoot`, Stillstand → `idle`, nach mehreren Sekunden Stillstand zufällig `idle_a`/`idle_b` (Zeiten wie im Sprite-Skript), Tod (`hp_changed`, `hp == 0`) → Leiche als eigener Knoten im `Match`, spielt `die`, bleibt 8 s liegen (wie `_on_hp_changed` im Sprite-Skript).
  - Figur dreht sich zur Laufrichtung bzw. beim Schießen zum Ziel (sanft drehen, kein Springen).
  - Teamring (`_add_team_ring`) und Team-Farbe wie bisher.
  - Schatten **an** (die Sprites hatten sie aus), Material-Helligkeit wie bei den Fahrzeug-Modellen (`TankVisual.brighten`).
- `PixelSprite.try_attach` (`source/match/units/traits/PixelSprite.gd`): zuerst `Infantry3D.try_attach`, wenn das GLB existiert, sonst wie bisher `SpriteInfantry` (Rückfall).
- **Sichtbarkeit/Auswahl bleiben gleich:** Selection/Targetability/HealthBar sitzen an der `Unit`, nicht am Sprite. Fog of War und `UnitVisibilityHandler` blenden das Unit-Objekt aus, das muss weiter funktionieren (3D-Figur ist Kind der Unit).
- Bei großen Armeen auf Leistung achten: nur ein Mesh-Satz pro Figur, keine Einzel-Lichter pro Einheit, Animationen ohne Verdoppelung der Player.

### 3. Tests und Abnahme

- `tools/playtest_check.gd` und `tools/faction_shot.gd` (liefern Screenshots, Aufruf siehe Kopfzeile) laufen lassen, Bilder ansehen: alle 12 Zweibeiner + 3 Vierbeiner sichtbar, laufen in 8 Richtungen korrekt, schießen, sterben.
- `godot --headless --path . -s tests/automated/factions_test.gd` muss weiter komplett durchlaufen (65 PASS, 0 FAIL; dauert mehrere Minuten, mit Ausgabe in eine Datei umleiten). Der Test "units show a pixel sprite" prüft Sprites: ggf. so anpassen, dass 3D-Figuren ebenfalls zählen.
- Danach committen und nach `origin/main` pushen (Commit-Identität: `git -c user.name=Anton -c user.email=antonboos91@gmail.com commit ...`). Gebäude, Fahrzeuge und Helikopter bleiben unverändert (Sprites bzw. vorhandene 3D-Pfade).

## Nicht Teil dieser Aufgabe (später)

Fahrzeuge/Helikopter als 3D (Blender-Skripte `tools/tank_*.py`, `wheeled_*.py`, `heli_*.py` → GLB; der Kettenlauf muss neu angebunden werden), Gebäude als 3D (TRELLIS, ca. 4 Min pro Gebäude, 42 Gebäude), Tag/Nacht, Wetter, Mündungsfeuer-Lichter, Lampen, Bloom/Nebel.

## Bereits erledigt in dieser Sitzung (zur Orientierung)

- 8-Richtungs-Zeilen der Infanterie korrigiert (`SpriteInfantry._row_for`).
- Gebäude-Grundfläche an Sprite-Größe angepasst (`MovementObstacle._fit_footprint_to_sprite`), Fernkampf-Reichweite bis Gebäudekante, Reichweite ×1.4 (`Factions.RANGE_SCALE`).
- Karten vergrößert (Plain & Simple 110×110, Big Arena 170×170), Startpunkte gleichmäßig verteilt (`Match._spawn_index_of`).
- Eigene Katzen-/Bären-Rüstung (`tools/comfyui/gen_faction_armor.py`, `out/3d/fa_*`), jede Einheit eigene Teile/Körperbau/Leuchtfarbe (`tools/modular/unit_queue.sh`).
- Schwarze Schatten der Fahrzeug-Sprites behoben (`source/shaders/3d/vehicle_sprite.gdshader`).
