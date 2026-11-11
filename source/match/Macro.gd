## Makro-Fähigkeit der Zentrale (Taste Z, wie Chrono-Boost / MULE / Brutlarven in SC2): Die Zentrale lädt
## Energie auf (bis 100); 50 Energie lösen die Fähigkeit des Volks aus, ohne die Auswahl zu ändern.
##   Shibas: Notlieferung  - 25 s lang kommt zusätzlicher Schrott dazu (wie ein MULE)
##   Katzen: Chrono-Stoß   - 20 s lang läuft jede Produktion 50 % schneller
##   Bären:  Brutwurf      - nach 12 s schlüpfen zwei Grunzer an der Zentrale
## Der Host rechnet; Energie wird mit dem Spieler repliziert.
extends Node

const Factions = preload("res://source/match/factions/Factions.gd")

const ENERGY_MAX = 100.0
const ENERGY_COST = 50.0
const ENERGY_PER_S = 0.8
const SUPPLY_DROP_PULSES = 5
const SUPPLY_DROP_INTERVAL_S = 5.0
const CHRONO_SECONDS = 20.0
const BROOD_DELAY_S = 12.0
const BROOD_UNITS = 2

var _match = null


func setup(match_node):
	_match = match_node
	name = "Macro"


func _process(delta):
	if Network.is_client():
		return
	for player in get_tree().get_nodes_in_group("players"):
		if Factions.faction_of(player) != Factions.CORE and _headquarters(player) != null:
			player.energy = min(ENERGY_MAX, player.energy + ENERGY_PER_S * delta)


static func ability_name(faction):
	return {
		Factions.SHIBAS: "Notlieferung",
		Factions.KATZEN: "Chrono-Stoß",
		Factions.BAEREN: "Brutwurf",
	}.get(faction, "")


static func ability_text(faction):
	return {
		Factions.SHIBAS: "Notlieferung: 25 s lang kommt zusätzlicher Schrott dazu (50 Energie)",
		Factions.KATZEN: "Chrono-Stoß: 20 s lang 50 % schnellere Produktion (50 Energie)",
		Factions.BAEREN: "Brutwurf: nach 12 s schlüpfen zwei Grunzer an der Zentrale (50 Energie)",
	}.get(faction, "")


func can_cast(player):
	return (
		ability_name(Factions.faction_of(player)) != ""
		and player.energy >= ENERGY_COST
		and _headquarters(player) != null
	)


## Löst die Makro-Fähigkeit aus (nur Host). Gibt true zurück, wenn sie gewirkt hat.
func cast(player):
	if Network.is_client() or not can_cast(player):
		return false
	var hq = _headquarters(player)
	player.energy -= ENERGY_COST
	match Factions.faction_of(player):
		Factions.SHIBAS:
			_match._notify(hq.global_position, "NOTLIEFERUNG")
			_supply_drop(player)
		Factions.KATZEN:
			_match._notify(hq.global_position, "CHRONO-STOSS")
			player.chrono_until_ms = Time.get_ticks_msec() + int(CHRONO_SECONDS * 1000.0)
		Factions.BAEREN:
			_match._notify(hq.global_position, "BRUTWURF")
			_brood(player, hq)
	return true


func _supply_drop(player):
	for i in SUPPLY_DROP_PULSES:
		await get_tree().create_timer(SUPPLY_DROP_INTERVAL_S).timeout
		if not is_instance_valid(player):
			return
		player.add_resources({"resource_a": 1, "resource_b": 0})


func _brood(player, hq):
	await get_tree().create_timer(BROOD_DELAY_S).timeout
	if not is_instance_valid(player) or not is_instance_valid(hq):
		return
	for i in BROOD_UNITS:
		var unit = load(Factions.entry("baeren/grunzer")["archetype"]).instantiate()
		unit.variant = "baeren/grunzer"
		var angle = TAU * i / BROOD_UNITS
		var offset = Vector3(cos(angle), 0, sin(angle)) * (hq.radius + 1.5)
		_match._setup_and_spawn_unit(
			unit, Transform3D(Basis(), hq.global_position * Vector3(1, 0, 1) + offset), player, false
		)


func _headquarters(player):
	for unit in player.get_children():
		if (
			unit.has_method("is_constructed")
			and unit.is_constructed()
			and Factions.role(Factions.variant_of(unit)) == "hq"
		):
			return unit
	return null
