## Infanterie steigt in einen eigenen Transporter (Flugkessel) ein.
extends "res://source/match/units/actions/Action.gd"

const Factions = preload("res://source/match/factions/Factions.gd")
const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")

var _target_unit = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(source_unit, target_unit):
	return (
		"cargo_count" in target_unit
		and Factions.ability(Factions.variant_of(target_unit)) == "transport"
		and source_unit.player == target_unit.player
		and source_unit.type == "Infantry"
		and target_unit.cargo_count < Constants.Match.Units.CARGO_CAPACITY
	)


func _init(target_unit):
	_target_unit = target_unit


func _ready():
	_target_unit.tree_exited.connect(_on_target_unit_removed)
	_board_or_move_closer()


func _to_string():
	return "{0}({1})".format([super(), str(_sub_action) if _sub_action != null else ""])


func _board_or_move_closer():
	if Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit):
		find_parent("Match").board_transport(_unit, _target_unit)
		if is_inside_tree():
			queue_free()
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
	_board_or_move_closer()


func _on_target_unit_removed():
	if is_inside_tree():
		queue_free()
