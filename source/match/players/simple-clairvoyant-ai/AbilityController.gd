## Lässt die KI die Spezialfähigkeiten ihres Volks nutzen: Spezialeinheiten ab und zu
## bauen, Gebäude übernehmen/hacken/sprengen, reparieren, entfalten und Superwaffen abfeuern.
extends Node

const Factions = preload("res://source/match/factions/Factions.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Capturing = preload("res://source/match/units/actions/Capturing.gd")
const Repairing = preload("res://source/match/units/actions/Repairing.gd")

const REFRESH_INTERVAL_S = 3.0
const SPECIAL_UNIT_INTERVAL_S = 75.0
const SPECIAL_ABILITIES = ["capture", "hack", "sabotage", "repair"]

var _player = null
var _since_special_unit_s = 0.0
var _next_special_index = 0


func setup(player):
	_player = player
	if Factions.faction_of(_player) == Factions.CORE:
		return
	var timer = Timer.new()
	timer.wait_time = REFRESH_INTERVAL_S
	timer.autostart = true
	timer.timeout.connect(_on_refresh)
	add_child(timer)


func _own_units():
	return get_tree().get_nodes_in_group("units").filter(func(unit): return unit.player == _player)


func _enemy_structures():
	return get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit is Structure and unit.is_constructed() and not unit.player.is_ally_of(_player)
			)
	)


func _is_idle(unit):
	return unit.action == null or (unit.action.has_method("is_idle") and unit.action.is_idle())


func _closest(unit, candidates):
	var best = null
	for candidate in candidates:
		if (
			best == null
			or (
				candidate.global_position_yless.distance_to(unit.global_position_yless)
				< best.global_position_yless.distance_to(unit.global_position_yless)
			)
		):
			best = candidate
	return best


func _on_refresh():
	_since_special_unit_s += REFRESH_INTERVAL_S
	var own = _own_units()
	for unit in own:
		var ability = Factions.ability(Factions.variant_of(unit))
		if ability == "superweapon" and unit.has_method("is_charged") and unit.is_charged():
			_fire_superweapon(unit)
		elif ability == "deploy":
			_deploy_if_no_hq(unit, own)
		elif ability in ["capture", "hack", "sabotage"] and _is_idle(unit):
			_infiltrate(unit)
		elif ability == "repair" and not unit is Structure and _is_idle(unit):
			_repair(unit, own)
	if _since_special_unit_s >= SPECIAL_UNIT_INTERVAL_S:
		_since_special_unit_s = 0.0
		_produce_special_unit(own)


func _fire_superweapon(weapon):
	var enemies = get_tree().get_nodes_in_group("units").filter(
		func(unit): return not unit.player.is_ally_of(_player)
	)
	var strike = Factions.entry(Factions.variant_of(weapon)).get("strike", {})
	var best = null
	var best_score = 0
	for candidate in enemies:
		var score = 0
		for other in enemies:
			if (
				other.global_position_yless.distance_to(candidate.global_position_yless)
				<= strike.get("radius", 6.0)
			):
				score += 3 if other is Structure else 1
		if score > best_score:
			best_score = score
			best = candidate
	if best != null and best_score >= 4:
		weapon.fire_superweapon(best.global_position)


func _deploy_if_no_hq(mcv, own):
	var hqs = own.filter(
		func(unit): return Factions.role(Factions.variant_of(unit)) == "hq" and unit is Structure
	)
	if hqs.is_empty():
		find_parent("Match")._deploy(_player, mcv)


func _infiltrate(unit):
	var target = _closest(unit, _enemy_structures())
	if target != null and Capturing.is_applicable(unit, target):
		unit.action = Capturing.new(target)


func _repair(mechanic, own):
	var target = _closest(
		mechanic, own.filter(func(t): return Repairing.is_applicable(mechanic, t))
	)
	if target != null:
		mechanic.action = Repairing.new(target)


## Alle paar Minuten eine Spezialeinheit des Volks in Auftrag geben.
func _produce_special_unit(own):
	var variants = Factions.entries().keys().filter(
		func(v):
			return (
				v.begins_with(Factions.faction_of(_player) + "/")
				and Factions.ability(v) in SPECIAL_ABILITIES
				and not Factions.entry(v)["later"]
			)
	)
	if variants.is_empty():
		return
	variants.sort()
	var variant = variants[_next_special_index % variants.size()]
	_next_special_index += 1
	for structure in own:
		if (
			structure is Structure
			and structure.production_queue != null
			and variant in Factions.producible_at(structure)
		):
			structure.production_queue.produce(variant)
			return
