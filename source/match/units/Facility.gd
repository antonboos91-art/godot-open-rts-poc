## Gebäude ohne eigene Produktion: Lager, Radar, Werkstatt, Labor, Superwaffe.
## Die Fähigkeit kommt aus den Volksdaten (Factions.gd, "ability").
extends "res://source/match/units/Structure.gd"

const REPAIR_INTERVAL_S = 1.0

## Ladestand der Superwaffe [0.0..1.0]; wird vom Host an Clients gespiegelt.
var charge_progress = 0.0

var ability:
	get:
		return Factions.ability(Factions.variant_of(self))

var _charge_seconds = 0.0


func _ready():
	await super()
	if Network.is_client():
		return
	if ability == "repair":
		var timer = Timer.new()
		timer.wait_time = REPAIR_INTERVAL_S
		timer.autostart = true
		timer.timeout.connect(_repair_nearby_units)
		add_child(timer)


func _process(delta):
	if ability != "superweapon" or Network.is_client() or not is_constructed():
		return
	if player.is_low_power() or is_hacked():
		return
	var strike = Factions.entry(Factions.variant_of(self))["strike"]
	_charge_seconds = min(strike["charge"], _charge_seconds + delta)
	# in 1-%-Schritten setzen, damit nicht jedes Frame repliziert wird
	charge_progress = floor(_charge_seconds / strike["charge"] * 100.0) / 100.0


func is_charged():
	return charge_progress >= 1.0


## Superwaffe abfeuern: Schaden an allen Nicht-Verbündeten im Zielgebiet.
func fire_superweapon(target):
	if ability != "superweapon" or not is_constructed() or not is_charged():
		return
	if player.is_low_power() or is_hacked() or Network.is_client():
		return
	var strike = Factions.entry(Factions.variant_of(self))["strike"]
	_charge_seconds = 0.0
	charge_progress = 0.0
	var target_yless = target * Vector3(1, 0, 1)
	for unit in get_tree().get_nodes_in_group("units"):
		if (
			not player.is_ally_of(unit.player)
			and unit.global_position_yless.distance_to(target_yless) <= strike["radius"]
		):
			if strike["damage"] > 0:
				unit.hp = unit.hp - strike["damage"] * Factions.HP_FACTOR
			if strike.get("hack", 0.0) > 0.0 and unit.has_method("is_constructed"):
				unit.hack(strike["hack"])
	var match_node = find_parent("Match")
	if Network.is_online():
		match_node.show_strike.rpc(target, strike["radius"])
	else:
		match_node.show_strike(target, strike["radius"])


## Werkstatt: repariert eigene und verbündete Einheiten in der Nähe.
func _repair_nearby_units():
	if not is_constructed() or player.is_low_power() or is_hacked():
		return
	var amount = Constants.Match.Units.REPAIR_HP_PER_S * REPAIR_INTERVAL_S
	for unit in get_tree().get_nodes_in_group("units"):
		if (
			unit.has_method("is_constructed")
			or not player.is_ally_of(unit.player)
			or unit.hp == null
			or unit.hp >= unit.hp_max
			or (
				unit.global_position_yless.distance_to(global_position_yless)
				> Constants.Match.Units.REPAIR_RADIUS_M + radius
			)
		):
			continue
		unit.set_meta("repair_progress", unit.get_meta("repair_progress", 0.0) + amount)
		if unit.get_meta("repair_progress") >= 1.0:
			unit.set_meta("repair_progress", 0.0)
			unit.hp = min(unit.hp_max, unit.hp + 1)
