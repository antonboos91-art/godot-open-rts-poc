# Anweisungen für Claude – No Paw Back Comrade

## Feste Regeln von Anton

- **"Mach alles fertig" heißt wirklich alles.** Wenn Anton sagt, ein Volk (oder ein anderer Bereich)
  soll fertig gemacht werden, werden *alle* Einheiten, Gebäude, Animationen, Stimmen und Mechaniken
  dieses Bereichs umgesetzt, eingebaut und getestet. Nichts wird als "noch offen" liegen gelassen.
  Nur was technisch wirklich nicht geht, wird klar benannt, mit Grund und Lösungsvorschlag.
- **Desktop zuerst.** Handy/Android/Touch wird nicht weiterentwickelt, solange Anton es nicht
  ausdrücklich wieder anfordert. Vorhandenen Touch-Code nicht entfernen, aber nicht weiter pflegen.
- **Selbst mergen.** PRs bzw. Branches führt Claude in der richtigen Reihenfolge selbst in `main` zusammen.
- Antworten an Anton auf Deutsch.

## Kunststil

- Look: Command & Conquer / StarCraft, Detailgrad auf AAA-Niveau (They Are Billions nur als Qualitätsmaßstab).
- Shibas: an die USA angelehnt, Blau und Weiß, echte Shiba-Köpfe (keine Helme statt Köpfen).
- Katzen: an Nod angelehnt, Schwarz und Violett.
- Bären: an die Sowjets angelehnt, Gold und Rot.
- Jedes Volk hat eine Angriffseinheit, die auf vier Pfoten kämpft.
- Einheiten haben Idle-Animationen im Stand (z. B. salutieren, am Ohr kratzen).
- Stimmen: harter 90er-Militärfunk (Rauschen, Knistern, Squelch), dazu ernst gesprochene Spaßzeilen
  ("Where are my treats?", "Time for my nap").

## Asset-Pipeline (auf Antons PC)

- `C:\Users\anton\Desktop\Assets-Pipeline` – ComfyUI-Skripte (Bilder, Wan-2.2-Animationen,
  BiRefNet-Freistellung, TTS) und Blender-Render-Skript.
- `tools/make_anim_sheets.py`, `tools/make_static_sprites.py` – erzeugen `assets/sprites/units/<volk>_<variante>_anim.png`.
- `tools/voice_pipeline/` – Stimmen erzeugen (`tts.py`), Funk-Effekt (`radio.py`), Paket bauen (`build_pack.py`).
- Tests: `godot --headless --path . -s tests/automated/factions_test.gd`.
