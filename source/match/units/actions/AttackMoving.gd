## Angriffs-Marsch (wie "A-Move" in SC1 / Angriffsbewegung in Generals): Die Einheit geht zum
## Zielpunkt, greift unterwegs jeden sichtbaren Gegner in Sichtweite an und marschiert danach weiter.
extends "res://source/match/units/actions/Action.gd"

const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
const Factions = preload("res://source/match/factions/Factions.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")

const SCAN_INTERVAL = 0.25

var _target_position = null
var _sub_action = null
var _attacking = false

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(unit):
	return Moving.is_applicable(unit)


func _init(target_position):
	_target_position = target_position


func _ready():
	var timer = Timer.new()
	timer.wait_time = SCAN_INTERVAL
	timer.timeout.connect(_scan)
	add_child(timer)
	timer.start()
	_march()


func _to_string():
	return "{0}({1})".format([super(), str(_sub_action) if _sub_action != null else ""])


func _march():
	_set_sub_action(Moving.new(_target_position), false)


func _set_sub_action(action, attacking):
	if _sub_action != null and is_instance_valid(_sub_action):
		_sub_action.tree_exited.disconnect(_on_sub_action_finished)
		remove_child(_sub_action)  # sofort, damit Moving._exit_tree die Bewegung vor dem Neustart stoppt
		_sub_action.queue_free()
	_sub_action = action
	_attacking = attacking
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()


func _scan():
	if _attacking or _unit.attack_range == null or _unit.attack_domains.is_empty():
		return
	var best = null
	var best_distance = INF
	for other in get_tree().get_nodes_in_group("units"):
		if (
			other.player.is_ally_of(_unit.player)
			or Factions.is_hidden_from(other, _unit.player)
			or not other.movement_domain in _unit.attack_domains
		):
			continue
		var distance = _unit.global_position_yless.distance_to(other.global_position_yless)
		if distance <= _unit.sight_range and distance < best_distance:
			best = other
			best_distance = distance
	if best != null:
		_set_sub_action(AutoAttacking.new(best), true)


func _on_sub_action_finished():
	if not is_inside_tree():
		return
	_sub_action = null
	if _attacking:
		_march()  # Gegner erledigt: weiter zum Ziel
	else:
		queue_free()  # Ziel erreicht
