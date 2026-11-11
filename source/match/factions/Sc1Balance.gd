## StarCraft: Brood War als Balancing-Vorlage fuer die drei Voelker.
##
## Shibas ~ Terraner, Katzen ~ Protoss, Baeren ~ Zerg. Jede Einheit ("volk/kuerzel") bekommt die
## Werte der passenden SC1-Einheit, umgerechnet mit den festen Faktoren unten. So bleibt das
## Verhaeltnis der Einheiten zueinander wie im Original, nur die Skala passt zu unserem Spiel.
##
## Quelle der Rohwerte: StarCraft: Brood War (Standardwerte, Spielgeschwindigkeit "Fastest").
## Nicht uebernommen: Rüstungsklassen/Schadenstypen (Explosion/Konkussion), Flaechenschaden,
## Upgrades. Die Ruestung selbst ist drin (Unit.armor).
##
## Skala:  HP_ENGINE = (Leben + Schild) / HP_DIV      (Factions.HP_FACTOR wird danach drauf multipliziert)
##         Schaden   = SC-Schaden / DMG_DIV           (Ruestung ebenso)
##         Intervall = SC-Cooldown in Frames / 24     (Sekunden)
##         Reichweite/Sicht = SC-Felder (Factions.RANGE_SCALE greift danach wie bisher)
##         Tempo     = SC-Pixel pro Frame * SPEED_SCALE
##         Kosten    = SC-Kosten / COST_DIV (mind. 1, wenn SC-Kosten > 0)
##         Bauzeit   = SC-Bauzeit (normale Sekunden) / TIME_DIV
extends RefCounted

const HP_DIV = 10.0
const DMG_DIV = 6.0
const COST_DIV = 50.0
const TIME_DIV = 8.0
const FRAMES_PER_S = 24.0
const SPEED_SCALE = 0.525
const MELEE_RANGE = 1.6  # SC "Reichweite 1" (Nahkampf) = Treffer an der Kante des Ziels

# Rohwerte: [Leben+Schild, Ruestung, Schaden, Cooldown (Frames), Reichweite, Sicht, Tempo (px/Frame),
#            Mineralien, Gas, Bauzeit s, Angriffsziele ("ground"|"air"|"both"|"none")]
const SC = {
	# Terraner
	"SCV": [60, 0, 5, 15, 1, 7, 5.0, 50, 0, 20, "none"],
	"Marine": [40, 0, 6, 15, 4, 7, 4.0, 50, 0, 24, "ground"],
	"Firebat": [50, 1, 16, 22, 1, 7, 4.0, 50, 25, 24, "ground"],
	"Medic": [60, 1, 0, 0, 0, 9, 4.0, 50, 25, 30, "none"],
	"Ghost": [45, 0, 10, 22, 7, 9, 4.0, 25, 75, 50, "ground"],
	"Vulture": [80, 0, 20, 30, 5, 8, 6.4, 75, 0, 30, "ground"],
	"Siege Tank": [150, 1, 30, 37, 7, 10, 4.0, 150, 100, 45, "ground"],
	"Goliath": [125, 1, 12, 22, 6, 8, 4.57, 100, 50, 40, "both"],
	"Wraith": [120, 0, 8, 30, 4, 7, 6.67, 150, 100, 60, "both"],
	"Dropship": [150, 1, 0, 0, 0, 8, 5.55, 100, 100, 50, "none"],
	"Science Vessel": [200, 1, 0, 0, 0, 10, 5.0, 100, 225, 50, "none"],
	"Battlecruiser": [500, 3, 25, 30, 6, 11, 2.5, 400, 300, 100, "both"],
	"Valkyrie": [200, 2, 6, 64, 6, 8, 6.67, 250, 125, 50, "air"],
	# Protoss
	"Probe": [40, 0, 5, 22, 1, 8, 4.0, 50, 0, 20, "none"],
	"Zealot": [160, 1, 16, 22, 1, 7, 4.0, 100, 0, 40, "ground"],
	"Dragoon": [180, 1, 20, 30, 4, 8, 5.0, 125, 50, 50, "both"],
	"High Templar": [80, 0, 0, 0, 0, 7, 3.0, 50, 150, 50, "none"],
	"Dark Templar": [120, 1, 40, 30, 1, 7, 4.0, 125, 100, 50, "ground"],
	"Archon": [360, 0, 30, 20, 3, 8, 5.0, 100, 300, 12, "both"],
	"Dark Archon": [225, 1, 0, 0, 0, 10, 4.0, 250, 200, 12, "none"],
	"Reaver": [180, 0, 100, 60, 8, 10, 1.1, 200, 100, 70, "ground"],
	"Observer": [60, 0, 0, 0, 0, 9, 3.3, 25, 75, 40, "none"],
	"Shuttle": [120, 1, 0, 0, 0, 8, 4.0, 200, 0, 60, "none"],
	"Scout": [250, 0, 28, 30, 4, 8, 5.0, 275, 125, 80, "both"],
	"Corsair": [200, 1, 5, 8, 5, 9, 6.67, 150, 100, 40, "air"],
	"Carrier": [450, 4, 48, 60, 8, 11, 2.5, 350, 250, 140, "both"],
	"Arbiter": [350, 1, 10, 45, 5, 9, 5.0, 100, 350, 100, "both"],
	# Zerg
	"Drone": [40, 0, 5, 22, 1, 7, 4.0, 50, 0, 20, "none"],
	"Zergling": [35, 0, 5, 8, 1, 5, 4.0, 25, 0, 28, "ground"],
	"Hydralisk": [80, 0, 10, 15, 4, 6, 3.0, 75, 25, 28, "both"],
	"Lurker": [125, 1, 20, 37, 6, 8, 3.0, 125, 125, 50, "ground"],
	"Ultralisk": [400, 1, 20, 15, 1, 7, 5.0, 200, 200, 60, "ground"],
	"Defiler": [80, 1, 0, 0, 0, 10, 4.0, 50, 150, 50, "none"],
	"Mutalisk": [120, 0, 9, 30, 3, 7, 6.67, 100, 100, 40, "both"],
	"Guardian": [150, 2, 20, 30, 8, 11, 2.5, 150, 200, 40, "ground"],
	"Devourer": [250, 2, 25, 100, 6, 10, 3.0, 150, 200, 40, "air"],
	"Queen": [120, 0, 0, 0, 0, 10, 6.7, 100, 100, 50, "none"],
	"Scourge": [25, 0, 110, 24, 1, 5, 6.7, 25, 75, 30, "air"],
	"Overlord": [200, 0, 0, 0, 0, 11, 0.9, 100, 0, 25, "none"],
}

# Volks-Einheit -> SC1-Einheit
const MAP = {
	"shibas/trooper": "Marine",
	"shibas/zapper": "Firebat",
	"shibas/schnueffler": "Medic",
	"shibas/ingenieur": "SCV",
	"shibas/kampfhund": "Ghost",
	"shibas/sammler": "SCV",
	"shibas/buggy": "Vulture",
	"shibas/tesla": "Siege Tank",
	"shibas/raketen": "Goliath",
	"shibas/wespe": "Wraith",
	"shibas/gewitter": "Battlecruiser",
	"shibas/transporter": "Dropship",
	"shibas/walkuere": "Valkyrie",
	"shibas/wissenschaft": "Science Vessel",
	"katzen/streuner": "Zealot",
	"katzen/scharfschuetzin": "Dragoon",
	"katzen/hackerin": "High Templar",
	"katzen/saboteur": "Dark Templar",
	"katzen/panther": "Archon",
	"katzen/sammler": "Probe",
	"katzen/phantom": "Observer",
	"katzen/prisma": "Dragoon",
	"katzen/nebelwerfer": "Reaver",
	"katzen/nachtfalter": "Corsair",
	"katzen/kreischer": "Scout",
	"katzen/schatten_shuttle": "Shuttle",
	"katzen/dunkel_archon": "Dark Archon",
	"katzen/mutterschiff": "Carrier",
	"baeren/grunzer": "Zergling",
	"baeren/feuertatze": "Hydralisk",
	"baeren/bazooka": "Lurker",
	"baeren/mechaniker": "Defiler",
	"baeren/kodiak": "Ultralisk",
	"baeren/kipper": "Drone",
	"baeren/rammbock": "Zergling",
	"baeren/grizzly": "Hydralisk",
	"baeren/moerser": "Lurker",
	"baeren/brummkopter": "Mutalisk",
	"baeren/flugkessel": "Overlord",
	"baeren/waechter": "Guardian",
	"baeren/kamikaze": "Scourge",
	"baeren/koenigin": "Queen",
}


static func has(variant):
	return variant in MAP


static func sc_name(variant):
	return MAP.get(variant, "")


## Gibt {"cost": {...}, "time": s, "stats": {...}} fuer die Variante zurueck (leer ohne Eintrag).
static func for_variant(variant):
	if not variant in MAP:
		return {}
	var v = SC[MAP[variant]]
	var stats = {
		"hp": (v[0] / HP_DIV),
		"armor": v[1] / DMG_DIV,
		"sight_range": float(v[5]),
		"speed": v[6] * SPEED_SCALE,
		"attack_domains": v[10],
	}
	if v[10] != "none":
		var reach = float(v[4])
		stats["attack_damage"] = v[2] / DMG_DIV
		stats["attack_interval"] = v[3] / FRAMES_PER_S
		stats["attack_range"] = MELEE_RANGE if reach <= 1.0 else reach
	return {
		"cost": {"resource_a": _cost(v[7]), "resource_b": _cost(v[8])},
		"time": max(2.0, snappedf(v[9] / TIME_DIV, 0.5)),
		"stats": stats,
	}


static func _cost(sc_cost):
	return 0 if sc_cost <= 0 else max(1, int(round(sc_cost / COST_DIV)))
