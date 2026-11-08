## Mechaniker repariert ein beschädigtes eigenes oder verbündetes Fahrzeug / Gebäude.
extends "res://source/match/units/actions/Action.gd"

const Factions = preload("res://source/match/factions/Factions.gd")
const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")

const TICK_S = 0.5

var _target_unit = null
var _sub_action = null
var _timer = null
var _progress = 0.0

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(source_unit, target_unit):
	return (
		Factions.ability(Factions.variant_of(source_unit)) == "repair"
		and source_unit != target_unit
		and "player" in target_unit
		and source_unit.player.is_ally_of(target_unit.player)
		and target_unit.hp != null
		and target_unit.hp < target_unit.hp_max
		and target_unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
		and not (target_unit.has_method("is_constructed") and not target_unit.is_constructed())
	)


func _init(target_unit):
	_target_unit = target_unit


func _ready():
	_target_unit.tree_exited.connect(_on_target_unit_removed)
	_repair_or_move_closer()


func _to_string():
	return "{0}({1})".format([super(), str(_sub_action) if _sub_action != null else ""])


func _repair_or_move_closer():
	if Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit):
		_timer = Timer.new()
		_timer.wait_time = TICK_S
		_timer.timeout.connect(_on_tick)
		add_child(_timer)
		_timer.start()
		return
	_sub_action = MovingToUnit.new(_target_unit)
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()


func _on_sub_action_finished():
	if not is_inside_tree():
		return
	if not is_instance_valid(_target_unit) or not _target_unit.is_inside_tree():
		queue_free()
		return
	_sub_action = null
	_repair_or_move_closer()


func _on_tick():
	if Network.is_client():
		return
	if not is_instance_valid(_target_unit) or _target_unit.hp >= _target_unit.hp_max:
		queue_free()
		return
	if not Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit):
		_timer.queue_free()
		_repair_or_move_closer()
		return
	_progress += Constants.Match.Units.REPAIR_HP_PER_S * 2.0 * TICK_S
	while _progress >= 1.0:
		_progress -= 1.0
		_target_unit.hp = min(_target_unit.hp_max, _target_unit.hp + 1)


func _on_target_unit_removed():
	if is_inside_tree():
		queue_free()
