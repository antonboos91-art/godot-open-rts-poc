# Balancing nach StarCraft: Brood War

Die Werte aller Einheiten stammen aus **StarCraft 1 (Brood War)** und liegen als Tabelle in
`source/match/factions/Sc1Balance.gd`. `Factions.gd` rechnet sie beim Start mit festen Faktoren
auf unsere Skala um. Wer das Balancing ändern will, ändert die Faktoren oder die Tabelle, nicht die
einzelnen Einheiten.

Hinweis zur Quelle: Liquipedia und Fandom lassen keine automatischen Abrufe zu (HTTP 403/402). Die
Rohwerte sind deshalb die bekannten Standardwerte von Brood War (Spielgeschwindigkeit „Fastest“,
ohne Upgrades), aus dem Gedächtnis eingetragen. Wer Abweichungen findet, korrigiert nur die Zeile in
`Sc1Balance.SC`.

## Umrechnung

| Wert | Formel |
| --- | --- |
| Lebenspunkte | (Leben + Schild) / 10, danach `Factions.HP_FACTOR` (3×) |
| Schaden, Rüstung | SC-Wert / 6 (Rüstung zieht von jedem Treffer ab, mindestens 0,5 SC-Schaden) |
| Angriffsintervall | Cooldown in Frames / 24 (Sekunden) |
| Reichweite, Sicht | SC-Felder; Fernkampf wird danach wie bisher mit `RANGE_SCALE` (1,4) skaliert; Nahkampf = 1,6 m |
| Tempo | SC-Pixel pro Frame × 0,525 |
| Kosten | SC-Kosten / 50 (mindestens 1, wenn größer 0): Mineralien = Schrott, Gas = Kristall |
| Bauzeit | SC-Bauzeit in Sekunden / 8 |

Dadurch bleiben Lebenspunkte, Schaden pro Sekunde, Kosten und Tempo im selben Verhältnis wie im
Original (der Marine ist unser Maßstab: 40 HP → 4, 6 Schaden → 1, 50 Mineralien → 1 Schrott).

## Zuordnung der Einheiten

Shibas ~ Terraner, Katzen ~ Protoss, Bären ~ Zerg. Jedes Volk hat 15 Einheiten (SC1: 13 bis 15).
Einheiten ohne eigene Grafik leihen sich die Optik einer Schwestereinheit (`"art"` in `Factions.gd`),
bis eigene Modelle da sind.

### Shibas (Terraner)

| Einheit | SC1-Vorbild |
| --- | --- |
| Welpen-Trooper | Marine |
| Zapper | Firebat |
| Schnüffler | Medic (Aufklärer, kein Angriff) |
| Ingenieur | SCV (Übernahme-Fähigkeit) |
| Kampf-Shiba (vier Pfoten) | Ghost |
| Schrott-Sammler | SCV |
| Sprinter-Buggy | Vulture |
| Tesla-Panzer | Siege Tank |
| Raketen-Rudel | Goliath |
| Wespen-Drohne | Wraith |
| Gewitter-Kopter | Battlecruiser |
| Kawa-Transporter (neu) | Dropship |
| Walküre-Drohne (neu) | Valkyrie |
| Aufklärungs-Drohne (neu) | Science Vessel |
| Bau-Mobil | Command Center (Zentrale auf Rädern) |

### Katzen (Protoss)

| Einheit | SC1-Vorbild |
| --- | --- |
| Streuner | Zealot |
| Laser-Scharfschützin | Dragoon |
| Hackerin | High Templar |
| Saboteur | Dark Templar |
| Schatten-Panther (vier Pfoten) | Archon |
| Kristall-Sammler | Probe |
| Phantom-Gleiter | Observer |
| Prisma-Panzer | Dragoon |
| Nebelwerfer | Reaver |
| Nachtfalter | Corsair |
| Kreischer-Bomber | Scout |
| Schatten-Shuttle (neu) | Shuttle |
| Dunkle Äbtissin (neu) | Dark Archon |
| Mutterschiff (neu) | Carrier |
| Nest-Mobil | Nexus (Zentrale auf Rädern) |

### Bären (Zerg)

| Einheit | SC1-Vorbild |
| --- | --- |
| Grunzer | Zergling |
| Feuertatze | Hydralisk |
| Bazooka-Bulle | Lurker |
| Mechaniker | Defiler (Unterstützer) |
| Kodiak-Brecher (vier Pfoten) | Ultralisk |
| Schrott-Kipper | Drone |
| Rammbock | Zergling |
| Grizzly-Panzer | Hydralisk |
| Honig-Mörser | Lurker |
| Brumm-Kopter | Mutalisk |
| Flugkessel | Overlord |
| Wächter-Bär (neu) | Guardian |
| Kamikaze-Hummel (neu) | Scourge |
| Bärenkönigin (neu) | Queen |
| Höhlen-Mobil | Hatchery (Zentrale auf Rädern) |

## Nicht übernommen

- Rüstungsklassen und Schadenstypen (Explosion, Konkussion), Flächenschaden, Upgrades der Originalspiele
  (dafür gibt es unsere eigenen Waffen-/Panzerungs-Upgrades, siehe `GENERALS_FEATURES.md`).
- Gebäudewerte bleiben unsere eigenen (der Gebäudebaum ist bewusst anders als in SC1).
- Einheiten mit gleichem SC1-Vorbild (z. B. Prisma-Panzer und Laser-Scharfschützin) haben im Spiel
  dieselben Basiswerte; unterscheiden sich aber durch Volk, Fähigkeiten und Optik.
