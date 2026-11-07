## Daten der drei Völker (Shibas, Katzen, Bären) und Hilfsfunktionen dazu.
##
## Jede Einheit und jedes Gebäude eines Volks ist eine "Variante" eines vorhandenen
## Archetyps (z. B. ist der Tesla-Panzer ein Tank mit eigenen Werten). Die Variante
## steckt in Unit.variant ("shibas/tesla") und wird beim Spawnen an Clients mitgeschickt.
##
## Spieler ohne Volk (Testszenen, alte Spielstände) spielen das Grundvolk "core",
## das aus den Tabellen in MatchConstants gebaut wird und sich wie das Original verhält.
extends RefCounted

const CORE = "core"
const SHIBAS = "shibas"
const KATZEN = "katzen"
const BAEREN = "baeren"
const CLOAK_DETECTION_M = 3.5
const PLAYABLE = [SHIBAS, KATZEN, BAEREN]

const UNITS_DIR = "res://source/match/units/"
const ARCHETYPES = {
	"hq": UNITS_DIR + "CommandCenter.tscn",
	"power": UNITS_DIR + "PowerPlant.tscn",
	"refinery": UNITS_DIR + "Refinery.tscn",
	"facility": UNITS_DIR + "Facility.tscn",
	"barracks": UNITS_DIR + "Barracks.tscn",
	"factory": UNITS_DIR + "VehicleFactory.tscn",
	"airfield": UNITS_DIR + "AircraftFactory.tscn",
	"turret_ground": UNITS_DIR + "AntiGroundTurret.tscn",
	"turret_air": UNITS_DIR + "AntiAirTurret.tscn",
	"worker": UNITS_DIR + "Worker.tscn",
	"infantry": UNITS_DIR + "Infantry.tscn",
	"tank": UNITS_DIR + "Tank.tscn",
	"drone": UNITS_DIR + "Drone.tscn",
	"heli": UNITS_DIR + "Helicopter.tscn",
}

const INFO = {
	CORE: {"name": "Classic", "title": "Open RTS", "color": Color.WHITE},
	SHIBAS: {"name": "Shibas", "title": "Rudel-Konzern KAWA", "color": Color(1.0, 0.45, 0.05)},
	KATZEN: {"name": "Katzen", "title": "Kollektiv Neun Leben", "color": Color(0.62, 0.2, 0.95)},
	BAEREN: {"name": "Bären", "title": "Ursa-Front", "color": Color(0.72, 0.2, 0.12)},
}

# Gebäude: [Rolle, Name, Archetyp, Schrott, Kristall, Strom (+ liefert, - braucht),
#           braucht (Rollen), HP, Extras]
const STRUCTURES = {
	SHIBAS:
	[
		["hq", "Rudel-Zentrale", "hq", 8, 8, 10, [], 20, {}],
		["power", "Dynamo-Zwinger", "power", 3, 0, 20, ["hq"], 8, {}],
		["refinery", "Schrottpresse", "refinery", 6, 0, -8, ["power"], 14, {}],
		["barracks", "Welpen-Kaserne", "barracks", 4, 0, -5, ["power"], 10, {}],
		["factory", "Garage Kawa-Motors", "factory", 6, 2, -10, ["refinery"], 16, {}],
		["silo", "Kristallsilo", "facility", 2, 0, -2, ["refinery"], 6, {}],
		["radar", "Kommando-Turm", "facility", 5, 1, -8, ["factory"], 10, {"ability": "radar"}],
		["power_big", "Groß-Dynamo", "power", 5, 1, 40, ["radar"], 12, {}],
		["airfield", "Drohnenhorst", "airfield", 6, 3, -10, ["radar"], 14, {}],
		["repair", "Werkstatt", "facility", 4, 1, -5, ["factory"], 10, {"ability": "repair"}],
		["lab", "Labor „Goldene Rute“", "facility", 8, 4, -12, ["radar"], 12, {}],
		[
			"turret_ground",
			"Zapper-Mast",
			"turret_ground",
			3,
			1,
			-5,
			["barracks"],
			8,
			{"stats": {"attack_damage": 2, "attack_interval": 0.8}}
		],
		["turret_air", "Flak-Kläffer", "turret_air", 3, 1, -5, ["radar"], 8, {}],
		[
			"superweapon",
			"Sturm-Satellit",
			"facility",
			12,
			8,
			-20,
			["lab"],
			14,
			{"ability": "superweapon", "strike": {"radius": 6.0, "damage": 12, "charge": 90.0}}
		],
	],
	KATZEN:
	[
		["hq", "Nest-Kern", "hq", 8, 8, 10, [], 18, {}],
		["power", "Plasma-Spule", "power", 3, 1, 20, ["hq"], 7, {}],
		["refinery", "Kristall-Mühle", "refinery", 6, 0, -8, ["power"], 12, {}],
		["barracks", "Schatten-Gasse", "barracks", 4, 1, -5, ["power"], 9, {}],
		["factory", "Krallen-Werk", "factory", 6, 3, -10, ["refinery"], 14, {}],
		["silo", "Daten-Tresor", "facility", 2, 1, -2, ["refinery"], 6, {}],
		["radar", "Datenturm", "facility", 5, 2, -8, ["factory"], 9, {"ability": "radar"}],
		["power_big", "Fusions-Kokon", "power", 5, 2, 40, ["radar"], 10, {}],
		["airfield", "Dachlandeplatz", "airfield", 6, 3, -10, ["radar"], 12, {}],
		["repair", "Nanobad", "facility", 4, 2, -5, ["factory"], 9, {"ability": "repair"}],
		["lab", "Mitternachts-Labor", "facility", 8, 5, -12, ["radar"], 10, {}],
		[
			"turret_ground",
			"Laser-Auge",
			"turret_ground",
			3,
			2,
			-5,
			["barracks"],
			7,
			{"stats": {"attack_range": 10.0, "sight_range": 10.0}}
		],
		["turret_air", "Spiegel-Flak", "turret_air", 3, 2, -5, ["radar"], 7, {}],
		[
			"superweapon",
			"Systemabsturz",
			"facility",
			10,
			10,
			-20,
			["lab"],
			12,
			{
				"ability": "superweapon",
				"strike": {"radius": 9.0, "damage": 0, "hack": 30.0, "charge": 90.0}
			}
		],
	],
	BAEREN:
	[
		["hq", "Bunkerhöhle", "hq", 8, 8, 10, [], 30, {}],
		["power", "Diesel-Brummer", "power", 3, 0, 20, ["hq"], 10, {}],
		["refinery", "Schmelzofen", "refinery", 6, 0, -8, ["power"], 16, {}],
		["barracks", "Rekrutenlager", "barracks", 4, 0, -5, ["power"], 12, {}],
		["factory", "Panzerschmiede", "factory", 7, 1, -10, ["refinery"], 20, {}],
		["silo", "Vorratsgrube", "facility", 2, 0, -2, ["refinery"], 8, {}],
		["radar", "Funkmast", "facility", 5, 1, -8, ["factory"], 12, {"ability": "radar"}],
		["power_big", "Reaktor-Kessel", "power", 6, 1, 40, ["radar"], 12, {}],
		["airfield", "Rotor-Scheune", "airfield", 7, 2, -10, ["radar"], 16, {}],
		["repair", "Schweißerei", "facility", 4, 0, -5, ["factory"], 12, {"ability": "repair"}],
		["lab", "Tatzen-Werk", "facility", 9, 3, -12, ["radar"], 14, {}],
		["turret_ground", "Bunker-Kanone", "turret_ground", 4, 0, -5, ["barracks"], 14, {}],
		["turret_air", "Flak-Grizzly", "turret_air", 4, 1, -5, ["radar"], 10, {}],
		["superweapon", "Brummbär-Rakete", "facility", 12, 6, -20, ["lab"], 16, {"later": true}],
	],
}

# Einheiten: [Kürzel, Name, Archetyp, Schrott, Kristall, Bauzeit s, gebaut in (Rolle),
#             braucht (Rollen), Werte, Extras]
# Werte: hp, attack_damage, attack_interval, attack_range, sight_range, speed,
#        attack_domains ("ground" | "air" | "both")
# Extras: "ai" = Standard-Variante des Archetyps für die KI, "ability" = Spezialfähigkeit
#         ("capture", "deploy"), "later" = Fähigkeit folgt
const UNITS = {
	SHIBAS:
	[
		[
			"trooper",
			"Welpen-Trooper",
			"infantry",
			1,
			0,
			3.0,
			"barracks",
			[],
			{
				"hp": 4,
				"attack_damage": 1,
				"attack_interval": 0.8,
				"attack_range": 4.0,
				"speed": 2.2
			},
			{"ai": true}
		],
		[
			"zapper",
			"Zapper",
			"infantry",
			2,
			0,
			4.0,
			"barracks",
			[],
			{"hp": 4, "attack_damage": 3, "attack_interval": 1.5, "attack_range": 2.5},
			{}
		],
		[
			"schnueffler",
			"Schnüffler",
			"infantry",
			1,
			0,
			2.5,
			"barracks",
			[],
			{
				"hp": 3,
				"attack_damage": 1,
				"attack_interval": 1.5,
				"sight_range": 11.0,
				"speed": 3.2
			},
			{}
		],
		[
			"ingenieur",
			"Ingenieur",
			"infantry",
			2,
			1,
			4.0,
			"barracks",
			[],
			{"hp": 3, "attack_domains": "none"},
			{"ability": "capture"}
		],
		["sammler", "Schrott-Sammler", "worker", 3, 0, 3.0, "hq", [], {"hp": 6}, {"ai": true}],
		[
			"buggy",
			"Sprinter-Buggy",
			"tank",
			2,
			0,
			4.0,
			"factory",
			[],
			{
				"hp": 6,
				"attack_damage": 1,
				"attack_interval": 0.4,
				"attack_range": 4.5,
				"speed": 4.2
			},
			{}
		],
		[
			"tesla",
			"Tesla-Panzer",
			"tank",
			4,
			1,
			6.0,
			"factory",
			[],
			{
				"hp": 10,
				"attack_damage": 3,
				"attack_interval": 1.0,
				"attack_range": 4.5,
				"speed": 2.8
			},
			{"ai": true}
		],
		[
			"raketen",
			"Raketen-Rudel",
			"tank",
			4,
			2,
			7.0,
			"factory",
			["radar"],
			{
				"hp": 7,
				"attack_damage": 2,
				"attack_interval": 1.2,
				"attack_range": 7.0,
				"attack_domains": "both"
			},
			{}
		],
		[
			"baumobil",
			"Bau-Mobil",
			"tank",
			8,
			2,
			10.0,
			"factory",
			[],
			{"hp": 12, "speed": 2.0, "attack_domains": "none"},
			{"ability": "deploy"}
		],
		[
			"wespe",
			"Wespen-Drohne",
			"heli",
			3,
			2,
			5.0,
			"airfield",
			[],
			{
				"hp": 6,
				"attack_damage": 2,
				"attack_interval": 0.6,
				"attack_domains": "air",
				"speed": 5.0
			},
			{}
		],
		[
			"gewitter",
			"Gewitter-Kopter",
			"heli",
			5,
			3,
			8.0,
			"airfield",
			["lab"],
			{"hp": 10, "attack_damage": 3, "attack_interval": 1.0, "attack_domains": "ground"},
			{"ai": true}
		],
	],
	KATZEN:
	[
		[
			"streuner",
			"Streuner",
			"infantry",
			1,
			1,
			3.0,
			"barracks",
			[],
			{
				"hp": 4,
				"attack_damage": 1,
				"attack_interval": 0.6,
				"attack_range": 4.0,
				"speed": 2.8
			},
			{"ai": true}
		],
		[
			"scharfschuetzin",
			"Laser-Scharfschützin",
			"infantry",
			3,
			1,
			5.0,
			"barracks",
			[],
			{
				"hp": 3,
				"attack_damage": 3,
				"attack_interval": 2.0,
				"attack_range": 8.0,
				"sight_range": 10.0
			},
			{}
		],
		[
			"hackerin",
			"Hackerin",
			"infantry",
			3,
			2,
			5.0,
			"barracks",
			[],
			{"attack_domains": "none"},
			{"ability": "hack"}
		],
		[
			"saboteur",
			"Saboteur",
			"infantry",
			2,
			2,
			5.0,
			"barracks",
			[],
			{"attack_domains": "none"},
			{"ability": "sabotage", "cloak": true}
		],
		["sammler", "Kristall-Sammler", "worker", 3, 1, 3.0, "hq", [], {"hp": 5}, {"ai": true}],
		[
			"phantom",
			"Phantom-Gleiter",
			"tank",
			3,
			2,
			5.0,
			"factory",
			[],
			{
				"hp": 5,
				"attack_damage": 1,
				"attack_interval": 1.0,
				"attack_range": 4.0,
				"sight_range": 11.0,
				"speed": 3.6
			},
			{"cloak": true}
		],
		[
			"prisma",
			"Prisma-Panzer",
			"tank",
			5,
			3,
			7.0,
			"factory",
			[],
			{
				"hp": 9,
				"attack_damage": 4,
				"attack_interval": 1.2,
				"attack_range": 6.0,
				"speed": 2.6
			},
			{"ai": true}
		],
		[
			"nebelwerfer",
			"Nebelwerfer",
			"tank",
			5,
			3,
			8.0,
			"factory",
			["lab"],
			{
				"hp": 6,
				"attack_damage": 4,
				"attack_interval": 2.5,
				"attack_range": 9.0,
				"speed": 2.0
			},
			{}
		],
		[
			"nestmobil",
			"Nest-Mobil",
			"tank",
			8,
			3,
			10.0,
			"factory",
			[],
			{"hp": 10, "speed": 2.4, "attack_domains": "none"},
			{"ability": "deploy"}
		],
		[
			"nachtfalter",
			"Nachtfalter",
			"heli",
			4,
			2,
			5.0,
			"airfield",
			[],
			{
				"hp": 6,
				"attack_damage": 2,
				"attack_interval": 0.6,
				"attack_domains": "air",
				"sight_range": 12.0
			},
			{"cloak": true}
		],
		[
			"kreischer",
			"Kreischer-Bomber",
			"heli",
			6,
			4,
			9.0,
			"airfield",
			["lab"],
			{
				"hp": 9,
				"attack_damage": 4,
				"attack_interval": 1.5,
				"attack_range": 4.0,
				"attack_domains": "ground"
			},
			{"ai": true}
		],
	],
	BAEREN:
	[
		[
			"grunzer",
			"Grunzer",
			"infantry",
			1,
			0,
			3.0,
			"barracks",
			[],
			{
				"hp": 6,
				"attack_damage": 1,
				"attack_interval": 0.9,
				"attack_range": 3.5,
				"speed": 1.8
			},
			{"ai": true}
		],
		[
			"feuertatze",
			"Feuertatze",
			"infantry",
			2,
			0,
			4.0,
			"barracks",
			[],
			{
				"hp": 6,
				"attack_damage": 2,
				"attack_interval": 0.6,
				"attack_range": 2.5,
				"speed": 1.8
			},
			{}
		],
		[
			"bazooka",
			"Bazooka-Bulle",
			"infantry",
			2,
			0,
			4.0,
			"barracks",
			[],
			{
				"hp": 5,
				"attack_damage": 3,
				"attack_interval": 1.6,
				"attack_range": 5.0,
				"speed": 1.7
			},
			{}
		],
		["mechaniker", "Mechaniker", "infantry", 2, 0, 4.0, "barracks", [], {}, {"later": true}],
		["kipper", "Schrott-Kipper", "worker", 4, 0, 4.0, "hq", [], {"hp": 10}, {"ai": true}],
		[
			"rammbock",
			"Rammbock",
			"tank",
			3,
			0,
			5.0,
			"factory",
			[],
			{
				"hp": 9,
				"attack_damage": 2,
				"attack_interval": 0.7,
				"attack_range": 2.5,
				"speed": 3.4
			},
			{}
		],
		[
			"grizzly",
			"Grizzly-Panzer",
			"tank",
			6,
			1,
			8.0,
			"factory",
			[],
			{
				"hp": 16,
				"attack_damage": 4,
				"attack_interval": 1.1,
				"attack_range": 5.0,
				"speed": 2.0
			},
			{"ai": true}
		],
		[
			"moerser",
			"Honig-Mörser",
			"tank",
			5,
			1,
			8.0,
			"factory",
			["lab"],
			{
				"hp": 8,
				"attack_damage": 5,
				"attack_interval": 3.0,
				"attack_range": 10.0,
				"speed": 1.8
			},
			{}
		],
		[
			"hoehlenmobil",
			"Höhlen-Mobil",
			"tank",
			9,
			1,
			11.0,
			"factory",
			[],
			{"hp": 22, "speed": 1.6, "attack_domains": "none"},
			{"ability": "deploy"}
		],
		[
			"brummkopter",
			"Brumm-Kopter",
			"heli",
			6,
			2,
			8.0,
			"airfield",
			[],
			{
				"hp": 14,
				"attack_damage": 3,
				"attack_interval": 1.1,
				"attack_domains": "both",
				"speed": 3.0
			},
			{"ai": true}
		],
		["flugkessel", "Flugkessel", "heli", 4, 1, 6.0, "airfield", [], {}, {"later": true}],
	],
}

static var _entries = {}
static var _order = {}  # Volk -> Varianten in Menü-Reihenfolge


## Alle Einträge: Varianten-Id -> Dictionary (siehe _add)
static func entries():
	if _entries.is_empty():
		_build()
	return _entries


static func entry(variant):
	return entries().get(variant, {})


static func info(faction):
	return INFO.get(faction if faction != "" else CORE, INFO[CORE])


static func faction_of(player):
	if player == null or not "faction" in player or player.faction == "":
		return CORE
	return player.faction


static func random_faction():
	return PLAYABLE[randi() % PLAYABLE.size()]


## Variante einer Einheit; Einheiten ohne Variante gehören zum Grundvolk.
static func variant_of(unit):
	if unit.variant != "":
		return unit.variant
	return CORE + "/" + unit.type


## Standard-Variante eines Archetyps (Szenenpfad) für ein Volk, z. B. für die KI.
static func variant_for(faction, archetype_path):
	if faction == "":
		faction = CORE
	var fallback = ""
	for variant in _variants_of(faction):
		var e = _entries[variant]
		if e["archetype"] != archetype_path or e["later"]:
			continue
		if e["ai"]:
			return variant
		if fallback == "":
			fallback = variant
	if fallback == "" and faction != CORE:
		return variant_for(CORE, archetype_path)
	return fallback


static func variant_for_player(player, archetype_path):
	return variant_for(faction_of(player), archetype_path)


static func display_name(variant):
	var e = entry(variant)
	return str(TranslationServer.translate(e["name"])) if not e.is_empty() else variant


static func cost(variant):
	var e = entry(variant)
	return e["cost"].duplicate() if not e.is_empty() else {"resource_a": 0, "resource_b": 0}


static func cost_for(player, archetype_path):
	return cost(variant_for_player(player, archetype_path))


static func production_time(variant):
	return entry(variant).get("time", 1.0)


static func power(variant):
	return entry(variant).get("power", 0)


static func role(variant):
	return entry(variant).get("role", "")


## Gebäude, die Arbeiter dieses Spielers bauen können (inkl. noch gesperrter).
static func buildable(player):
	return _variants_of(faction_of(player)).filter(
		func(v): return _entries[v]["kind"] == "structure" and not _entries[v]["later"]
	)


## Einheiten, die dieses Gebäude produzieren kann (inkl. noch gesperrter).
static func producible_at(structure):
	var structure_role = role(variant_of(structure))
	return _variants_of(faction_of(structure.player)).filter(
		func(v):
			return (
				_entries[v]["kind"] == "unit"
				and not _entries[v]["later"]
				and _entries[v]["at"] == structure_role
			)
	)


## Namen der fehlenden Voraussetzungen (fertige eigene Gebäude mit passender Rolle).
static func missing_requirements(player, variant):
	var e = entry(variant)
	if e.is_empty():
		return []
	var owned_roles = {}
	for unit in player.get_children():
		if unit.has_method("is_constructed") and unit.is_constructed() and "variant" in unit:
			owned_roles[role(variant_of(unit))] = true
	var missing = []
	for required_role in e["requires"]:
		if not required_role in owned_roles:
			missing.append(display_name(e["faction"] + "/" + required_role))
	return missing


static func is_available(player, variant):
	var e = entry(variant)
	return (
		not e.is_empty()
		and not e["later"]
		and e["faction"] == faction_of(player)
		and missing_requirements(player, variant).is_empty()
	)


## Fähigkeit einer Variante: "capture", "deploy", "superweapon", "radar", "repair" oder "".
static func ability(variant):
	return entry(variant).get("ability", "")


## Tarnung: Eine getarnte Einheit ist für Gegner nur sichtbar (und angreifbar),
## wenn eine gegnerische Einheit näher als CLOAK_DETECTION_M steht.
static func is_hidden_from(target, viewer_player):
	if (
		not "variant" in target
		or target.variant == ""
		or not entry(target.variant).get("cloak", false)
	):
		return false
	if viewer_player.is_ally_of(target.player):
		return false
	for unit in target.get_tree().get_nodes_in_group("units"):
		if (
			not unit.player.is_ally_of(target.player)
			and (
				unit.global_position_yless.distance_to(target.global_position_yless)
				<= CLOAK_DETECTION_M
			)
		):
			return false
	return true


## Variante der Zentrale, zu der sich ein Bau-Mobil dieses Volks entfaltet.
static func deploy_target(variant):
	return entry(variant).get("faction", CORE) + "/hq"


## Werte als Eigenschaften für Unit.set() (Domänen in Navigation-Enum übersetzt).
static func stats(variant):
	var result = entry(variant).get("stats", {}).duplicate()
	if "attack_domains" in result and result["attack_domains"] is String:
		var domain = Constants.Match.Navigation.Domain
		result["attack_domains"] = {
			"none": [],
			"ground": [domain.TERRAIN],
			"air": [domain.AIR],
			"both": [domain.TERRAIN, domain.AIR]
		}[result["attack_domains"]]
	return result


static func _variants_of(faction):
	entries()
	return _order.get(faction, [])


static func _build():
	_build_core()
	for faction in PLAYABLE:
		for row in STRUCTURES[faction]:
			var extras = row[8]
			var structure_stats = extras.get("stats", {}).duplicate()
			structure_stats["hp"] = row[7]
			_add(
				faction,
				row[0],
				{
					"kind": "structure",
					"name": row[1],
					"archetype": ARCHETYPES[row[2]],
					"cost": {"resource_a": row[3], "resource_b": row[4]},
					"power": row[5],
					"requires": row[6],
					"stats": structure_stats,
					"ability": extras.get("ability", ""),
					"strike": extras.get("strike", {}),
					"later": extras.get("later", false),
				}
			)
		for row in UNITS[faction]:
			var extras = row[9]
			_add(
				faction,
				row[0],
				{
					"kind": "unit",
					"name": row[1],
					"archetype": ARCHETYPES[row[2]],
					"cost": {"resource_a": row[3], "resource_b": row[4]},
					"time": row[5],
					"at": row[6],
					"requires": row[7],
					"stats": row[8],
					"ai": extras.get("ai", false),
					"ability": extras.get("ability", ""),
					"cloak": extras.get("cloak", false),
					"later": extras.get("later", false),
				}
			)


## Grundvolk aus MatchConstants: verhält sich exakt wie das ursprüngliche Spiel.
static func _build_core():
	var units = Constants.Match.Units
	var structures = [
		["CommandCenter", "hq", "CC"],
		["VehicleFactory", "factory", "VEHICLE_FACTORY"],
		["AircraftFactory", "airfield", "AIRCRAFT_FACTORY"],
		["AntiGroundTurret", "turret_ground", "AG_TURRET"],
		["AntiAirTurret", "turret_air", "AA_TURRET"],
	]
	for row in structures:
		var path = UNITS_DIR + row[0] + ".tscn"
		_add(
			CORE,
			row[0],
			{
				"kind": "structure",
				"name": row[2],
				"archetype": path,
				"role": row[1],
				"cost": units.CONSTRUCTION_COSTS[path],
			}
		)
	var mobile = [
		["Worker", "hq", "WORKER"],
		["Tank", "factory", "TANK"],
		["Drone", "airfield", "DRONE"],
		["Helicopter", "airfield", "HELICOPTER"],
	]
	for row in mobile:
		var path = UNITS_DIR + row[0] + ".tscn"
		_add(
			CORE,
			row[0],
			{
				"kind": "unit",
				"name": row[2],
				"archetype": path,
				"at": row[1],
				"cost": units.PRODUCTION_COSTS[path],
				"time": units.PRODUCTION_TIMES[path],
			}
		)


static func _add(faction, key, data):
	var variant = faction + "/" + key
	var e = {
		"id": variant,
		"faction": faction,
		"role": key,
		"time": 1.0,
		"power": 0,
		"requires": [],
		"at": "",
		"stats": {},
		"ability": "",
		"cloak": false,
		"strike": {},
		"ai": false,
		"later": false,
	}
	e.merge(data, true)
	_entries[variant] = e
	if not faction in _order:
		_order[faction] = []
	_order[faction].append(variant)
