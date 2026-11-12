# KI-Partien: Messungen

Messaufbau: `tests/automated/ai_matches_test.gd`, 2 KIs gegen 2 KIs (Normal-Schwierigkeit, Völker
wechseln reihum), Zeitraffer 12, Karte Hochland. Gemessen wird die **Spielzeit** bis ein Team als Einziges
übrig ist. Jede Runde wird auf Skriptfehler, Hänger (10 Minuten Spielzeit ohne Änderung), ungültige
Lebenspunkte und Einheiten außerhalb der Welt geprüft.

Aufruf (Karte, Runden, maximale Spielzeit in s, Zeitraffer, erste Runde):

    godot4 --headless -s tests/automated/ai_matches_test.gd -- res://source/match/maps/Highlands4.tscn 3 3600 12 0

## Ergebnisse (nach den KI-Korrekturen)

| Karte | Runden | Spielzeit bis zum Sieg (je Runde) | Durchschnitt |
| --- | --- | --- | --- |
| Hochland 4 Spieler, 240 m | 7 | 775, 1360, 900, 1092, 914, 1338, 933 s | 1045 s (rund 17 Minuten) |
| Hochland 8 Spieler, 400 m (4 KIs) | 3 | 1944, 946, 1021 s | 1304 s (rund 22 Minuten) |

Alle 10 Runden endeten mit einem Sieger, ohne Skriptfehler und ohne Hänger.

## Was die Messungen gefunden haben

- Die KI zählte ihre Wartezeit bis zum ersten Angriff nach Rechner-Uhrzeit statt nach Spielzeit. Im Zeitraffer
  stimmte das nicht, jetzt zählt die Spielzeit (`AutoAttackingBattlegroup.game_seconds()`).
- Ohne Nachschub blieb eine Partie stehen, wenn alle Kampfgruppen gefallen waren: Jetzt formiert sich bei
  Bedarf sofort eine neue Gruppe (`OffenseController`).
- Ziele auf Plateaus sind vom Boden aus nicht zu sehen: Die Kampfgruppen gehen dann im Angriffs-Marsch
  über die Rampe zum nächsten Gegner (`AutoAttackingBattlegroup._march_towards_nearest`).
- Zwei Abstürze behoben: `AutoAttacking._on_sub_action_finished` bei gelöschtem Ziel und
  `AutoAttackingBattlegroup._attack_next_adversary_unit` bei leerer Gruppe.

## Grenzen

Die KI ist weiterhin die einfache Kampfgruppen-KI (eine Zentrale, wenige Arbeiter, feste Gruppen). Sie spielt
die Hochland-Karten bis zum Ende, baut aber keine Expansionen und kontert nichts gezielt. Eine neue KI ist
ein eigenes Vorhaben.
