# Abgleich mit dem Blizzard-Standard (StarCraft II / Stormgate)

Stand der Funktionen gegenüber der Liste „Modern Blizzard-Style Standard“. Getestet in
`tests/automated/blizzard_test.gd` (und `generals_test.gd` für die älteren Funktionen). Alle Tasten
lassen sich in `user://hotkeys.cfg` ändern (Abschnitt `[keys]`, wird beim ersten Start mit den
Standardwerten angelegt, siehe `source/match/players/human/Hotkeys.gd`).

| Funktion | Stand | Wo / Taste |
| --- | --- | --- |
| Unbegrenzte Auswahl, Untergruppen mit Tab | **fertig** | Tab schaltet die Untergruppen der Auswahl durch (Fähigkeits-Einheiten zuerst, dann höhere Stufe). Die Auswahl bleibt, das Befehlsmenü zeigt die aktive Untergruppe |
| Mehrfachgebäude-Auswahl, gesammelte Produktion | **fertig** | Mehrere gleiche Gebäude wählen (Kontrollgruppe oder Rahmen): ein Knopf/Taste bildet im am wenigsten ausgelasteten Gebäude aus. Produktions-Tasten Y U I O / H J K L (Reihenfolge der Knöpfe, Tooltip zeigt sie) |
| Arbeiter sammeln automatisch (Sammelpunkt auf Rohstoff), Auslastungsanzeige | **fertig** | Neue Arbeiter ohne Sammelpunkt fangen sofort an (am wenigsten belegter Knoten in der Nähe); Sammelpunkt auf einen Knoten funktioniert wie bisher. Über Zentrale und Raffinerie steht „Sammler/Plätze“ (zum Beispiel 8/16) |
| Untätige Arbeiter: Anzeige und Taste | **fertig** | Abzeichen oben links (Klick), F1 wählt und zentriert den nächsten, Strg+F1 wählt alle |
| Sofortige Drehung, enge Kollision | **fertig** | Keine Drehträgheit mehr (`Movement.gd`); die Einheiten schieben sich weiter über `UnitSeparation` auseinander |
| Smart-Cast: nur der nächste Zauberer wirkt | **fertig** | Übernehmen, Hacken, Sabotage und Reparatur führt nur die nächste geeignete Einheit der Auswahl aus; der Rest der Gruppe bleibt bei seinem Verhalten |
| Schnellfeuer-Taste für Fähigkeiten | **fertig** | C wirkt die passende Fähigkeit auf das Ziel unter dem Mauszeiger (Superwaffe, Reparatur, Übernehmen/Hacken) und wiederholt bei gehaltener Taste etwa achtmal pro Sekunde |
| Neutrale Wachtürme (Sicht) | **fertig** | Vier Türme zwischen den Basen. Steht eine eigene oder verbündete Bodeneinheit daneben, sieht das Team 22 m weit, auch im Nebel (`Watchtower.gd`) |
| Feste Abbaurate, sinkender Ertrag bei Überbesetzung, Angriffe auf Arbeiter | **fertig** | Knoten haben 300 Einheiten; ab dem dritten Sammler an einem Knoten dauert jede Einheit 50 % länger. Sammler verteilen sich auf freie Knoten. Arbeiter sind angreifbar |
| Globale Makro-Fähigkeit ohne Auswahlwechsel | **fertig** | Taste Z oder Leiste oben links. Shibas: Notlieferung (Schrott, wie MULE), Katzen: Chrono-Stoß (+50 % Produktion für 20 s), Bären: Brutwurf (zwei Grunzer nach 12 s). 50 Energie, Zentrale lädt 0,8/s auf |
| Kamera-Lesezeichen | **fertig** | Strg+F5 bis F8 speichert die Mitte des Bildschirms, F5 bis F8 springt dorthin |
| Tasten frei belegbar, Gruppen mit Umschalt/Alt | **fertig** | `user://hotkeys.cfg`. Strg+Zahl: neue Gruppe, Umschalt+Strg+Zahl: anhängen, Alt+Strg+Zahl: Einheiten aus anderen Gruppen entfernen. Eine Oberfläche zum Umbelegen im Spiel gibt es noch nicht, nur die Datei |
| Sichtbare Befehlswarteschlangen mit Wegpunkt-Linien | **fertig** | Shift-Befehle erscheinen als Linien am Boden: grün Bewegen, orange Angriffs-Marsch, rot Angriffsziel, türkis Sammelpunkt (`CommandLines.gd`) |
| Bodenkreise, Zielmarkierungen, Warnkreise | **fertig** | Wirkungsradius der Superwaffe beim Zielen, roter Warnkreis 1,5 s vor dem Einschlag, Zielmarkierung bei Angriffsbefehlen. Nicht dabei: Abklingzeit-Anzeige der Waffen |
| Zuschauer-Übersicht mit Produktion, Upgrades, Einkommen, Armeewert, APM | **fertig** | F10. Im Zuschauermodus (volle Sicht) für alle Spieler, sonst nur eigenes Team |
| Binärer Nebel des Krieges | vorhanden | Nebel/Schatten wie bisher |
| Höhenvorteil, Sichtblocker (Rampen, Klippen, Rauch) | **nicht umgesetzt** | Die Karten sind flach, es gibt weder Höhenstufen noch Sichtblocker in der Nebelberechnung. Das braucht Karten mit Höhen (Navigationsmesh je Ebene) und Sichtlinien-Prüfung in Nebel und Zielwahl, ein eigenes Vorhaben. Vorschlag: erst eine Höhenkarte als Testfall bauen |
| Deterministische Simulation mit hoher Tickrate (Lockstep/Rollback) | **nicht umgesetzt** | Die Simulation läuft mit Godot-Physik und Navigation in Bildzeit und ist weder deterministisch noch zeitlich fest getaktet; der Mehrspieler arbeitet mit Host-Autorität. Lockstep verlangt eine Neuentwicklung der Bewegung (Festkomma, feste Schritte) und der KI. Vorschlag: eigenes Großprojekt, vorher Replays klären |
| Replays zurückspulen, „Steuerung übernehmen“ | **nicht umgesetzt** | Hängt an der deterministischen Simulation (siehe oben). Ohne sie kann man nur Zustandsabzüge speichern (Speichern/Laden), kein verlässliches Zurückspulen |

## Aus dem ersten Abgleich (Generals), weiterhin vorhanden

Stopp (X), Angriffs-Marsch (F, dann Rechtsklick), Shift-Wegpunkte, Verkaufen (Entf), Veteranen-Ränge,
Waffen-/Panzerungs-Upgrades, Vorratskisten, Überrollen, Bunker-Besatzung und Aufgeben. Details in
`GENERALS_FEATURES.md`.
