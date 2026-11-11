## Überrollen (wie in Generals): Fahrzeuge der Klasse "Tank" überfahren gegnerische Infanterie,
## die ihnen beim Fahren in den Weg läuft. Nur der Host rechnet; stehende Fahrzeuge überrollen nichts.
extends Node

const SCAN_INTERVAL_S = 0.15
const CRUSH_RADIUS_M = 1.0
const MIN_SPEED_MS = 0.8
const CRUSH_DAMAGE = 1000.0  # überrollt = tot (Rüstung zählt nicht)

var _last_positions = {}
var _timer = null


func _ready():
	name = "Crushing"
	if Network.is_client():
		return
	_timer = Timer.new()
	_timer.wait_time = SCAN_INTERVAL_S
	_timer.timeout.connect(crush_step)
	add_child(_timer)
	_timer.start()


func crush_step():
	var units = get_tree().get_nodes_in_group("units")
	var infantry = units.filter(func(u): return u.type == "Infantry")
	var seen = {}
	for unit in units:
		if unit.type != "Tank" or unit.movement_speed <= 0.0 or unit.attack_domains.is_empty():
			continue
		var id = unit.get_instance_id()
		seen[id] = true
		var previous = _last_positions.get(id, unit.global_position_yless)
		var speed = unit.global_position_yless.distance_to(previous) / SCAN_INTERVAL_S
		_last_positions[id] = unit.global_position_yless
		if speed < MIN_SPEED_MS:
			continue
		for victim in infantry:
			if (
				not victim.player.is_ally_of(unit.player)
				and victim.hp > 0
				and unit.global_position_yless.distance_to(victim.global_position_yless) <= CRUSH_RADIUS_M
			):
				victim.take_hit(CRUSH_DAMAGE, unit)
	for id in _last_positions.keys():
		if not id in seen:
			_last_positions.erase(id)
