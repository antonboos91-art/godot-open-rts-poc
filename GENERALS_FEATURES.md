# Abgleich mit C&C Generals

Stand der Funktionen gegenüber Command & Conquer: Generals (Skirmish). „Neu“ = in diesem Abgleich
umgesetzt und in `tests/automated/generals_test.gd` getestet.

## Wirtschaft und Basis

| Generals | Hier |
| --- | --- |
| Rohstoffe sammeln mit Arbeitern, Raffinerie | vorhanden; große Ringe, Expansions- und Zentrumsfelder (neu, `ResourceFields.gd`) |
| Strom, Strommangel verlangsamt Produktion/Abwehr | vorhanden |
| Gebäude bauen, Produktionswarteschlange | vorhanden |
| Verkaufen (halber Preis) | **neu**: Knopf „VERK.“ oder Entf |
| Vorratskisten (Geld, Heilung, Beförderung) | **neu**: `Crates.gd`, alle 45 bis 75 s |
| Upgrades (Waffen, Panzerung) | **neu**: im Labor, je 3 Stufen (+15 % Schaden / −13 % erlittener Schaden) |
| Techbaum | vorhanden |
| Gebäude übernehmen (Eroberer) | vorhanden (Ingenieur) |
| Reparatur | vorhanden (Werkstatt, Mechaniker) |
| Superwaffen | vorhanden (je Volk eine) |
| Zentrale umsetzen / aufbauen | vorhanden (Bau-Mobil) |

## Einheiten und Gefecht

| Generals | Hier |
| --- | --- |
| Veteranen-Ränge (Veteran, Elite, Held) | **neu**: Kill-Punkte nach Kosten des Gegners, Sterne über der Einheit, +25/50/100 % Schaden und Leben, Heilung bei Beförderung |
| Rüstung | **neu**: `Unit.armor` aus den SC1-Werten |
| Überrollen von Infanterie durch Panzer | **neu**: `Crushing.gd` |
| Gebäude besetzen (Garnison) | **neu** für Bunker/Abwehrtürme am Boden: bis zu 4 Infanteristen, je +40 % Schaden und +0,75 m Reichweite, Besatzung überlebt die Zerstörung |
| Transporter | vorhanden |
| Tarnung und Entdeckung | vorhanden |
| Hacken, Sabotage | vorhanden |
| Stopp | **neu**: Taste X |
| Angriffs-Marsch (A-Move) | **neu**: Taste F, danach Rechtsklick auf das Gelände (die Tasten W/A/S/D bewegen schon die Kamera) |
| Wegpunkte (Shift-Befehle) | **neu**: Shift + Rechtsklick hängt Wegpunkte an; Shift + F + Rechtsklick hängt einen Angriffs-Marsch an |
| Kontrollgruppen, Doppelklick-Auswahl, Rahmen-Auswahl | vorhanden |
| Sammelpunkte | vorhanden |
| Wachposten (Einheiten greifen im Stand selbst an) | vorhanden (automatisch) |

## Oberfläche, Spiel, Netz

| Generals | Hier |
| --- | --- |
| Minikarte, Nebel des Krieges | vorhanden |
| Sprachansagen (Basis angegriffen, Einheit verloren ...) | vorhanden |
| KI-Schwierigkeitsgrade | vorhanden (Leicht, Normal, Schwer) |
| Teams, Bündnisse, gemeinsame Sicht | vorhanden |
| Mehrspieler | vorhanden |
| Pause / Menü | vorhanden |
| Aufgeben | **neu**: Knopf im Spielmenü (Esc) |

## Bewusst nicht umgesetzt

- **Speichern und Laden mitten im Spiel, Wiederholungen (Replays), Kampagne:** Das ist jeweils ein eigenes
  Großprojekt (vollständiger Spielzustand serialisieren bzw. Eingabe-Aufzeichnung mit deterministischem
  Spielablauf). Der Spielablauf ist nicht deterministisch (Zufall in KI und Navigation), deshalb bräuchte
  ein Replay erst eine Umstellung der Simulation. Vorschlag: Zuerst Speichern/Laden als eigenes Vorhaben.
- **General-Fähigkeiten (Generals-Punkte und -Mächte):** Sie hängen stark an den Generals-Fraktionen und
  ihren Spezialkräften. Die Rang-Mechanik dafür (Kill-Punkte) ist da; die Fähigkeiten selbst wären ein
  eigenes Designthema pro Volk.
- **Gelände mit Brücken und Wasser:** Die Karten sind bewusst flach.
