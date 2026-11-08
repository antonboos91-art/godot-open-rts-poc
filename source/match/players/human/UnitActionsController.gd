extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")


class Actions:
	const Moving = preload("res://source/match/units/actions/Moving.gd")
	const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
	const Following = preload("res://source/match/units/actions/Following.gd")
	const CollectingResourcesSequentially = preload(
		"res://source/match/units/actions/CollectingResourcesSequentially.gd"
	)
	const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
	const Constructing = preload("res://source/match/units/actions/Constructing.gd")
	const Capturing = preload("res://source/match/units/actions/Capturing.gd")
	const Repairing = preload("res://source/match/units/actions/Repairing.gd")


@onready var _player = get_parent()
@onready var _match = find_parent("Match")


func _ready():
	# Nur der lokale Spieler reagiert auf Eingaben. Für entfernte Spieler nutzt der
	# Host diesen Controller nur, um ihre Befehle auszuführen (execute_*).
	if not _player.is_local():
		return
	MatchSignals.terrain_targeted.connect(_on_terrain_targeted)
	MatchSignals.unit_targeted.connect(_on_unit_targeted)
	MatchSignals.navigate_unit_to_rally_point.connect(_on_navigate_unit_to_rally_point)


## Befehle, die der Host ausführt. `units` gehören garantiert dem Spieler.
func execute_terrain_targeted(units, target_point):
	_try_navigating_units_towards_position(units, target_point)
	_try_setting_rally_points(units, target_point)


func execute_unit_targeted(units, target_unit):
	_navigate_units_towards_unit(units, target_unit)


func execute_construct(units, structure):
	_try_ordering_workers_to_construct_structure(units, structure)


func _get_selected_controlled_units():
	return get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)


func _try_navigating_units_towards_position(units, target_point):
	var terrain_units_to_move = units.filter(
		func(unit):
			return (
				unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Actions.Moving.is_applicable(unit)
			)
	)
	var air_units_to_move = units.filter(
		func(unit):
			return (
				unit.movement_domain == Constants.Match.Navigation.Domain.AIR
				and Actions.Moving.is_applicable(unit)
			)
	)
	var new_unit_targets = Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
		terrain_units_to_move, target_point
	)
	new_unit_targets += Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
		air_units_to_move, target_point
	)
	for tuple in new_unit_targets:
		var unit = tuple[0]
		var new_target = tuple[1]
		unit.action = Actions.Moving.new(new_target)


func _try_setting_rally_points(units, target_point: Vector3):
	var controlled_structures = units.filter(
		func(unit): return unit.find_child("RallyPoint") != null
	)
	for structure in controlled_structures:
		var rally_point = structure.find_child("RallyPoint")
		if rally_point != null:
			rally_point.target_unit = null
			rally_point.global_position = target_point


func _try_ordering_workers_to_construct_structure(units, potential_structure):
	if not potential_structure is Structure or potential_structure.is_constructed():
		return
	var structure = potential_structure
	var selected_constructors = units.filter(
		func(unit): return Actions.Constructing.is_applicable(unit, structure)
	)
	for unit in selected_constructors:
		unit.action = Actions.Constructing.new(structure)


func _navigate_units_towards_unit(units, target_unit):
	var at_least_one_unit_navigated = false
	for unit in units:
		if _navigate_unit_towards_unit(unit, target_unit):
			at_least_one_unit_navigated = true
	return at_least_one_unit_navigated


func _navigate_unit_towards_unit(unit, target_unit):
	if Actions.CollectingResourcesSequentially.is_applicable(unit, target_unit):
		unit.action = Actions.CollectingResourcesSequentially.new(target_unit)
		return true
	if Actions.Capturing.is_applicable(unit, target_unit):
		unit.action = Actions.Capturing.new(target_unit)
		return true
	if Actions.Repairing.is_applicable(unit, target_unit):
		unit.action = Actions.Repairing.new(target_unit)
		return true
	if Actions.AutoAttacking.is_applicable(unit, target_unit):
		unit.action = Actions.AutoAttacking.new(target_unit)
		return true
	if Actions.Constructing.is_applicable(unit, target_unit):
		unit.action = Actions.Constructing.new(target_unit)
		return true
	if target_unit.is_in_group("units") and Actions.Following.is_applicable(unit):
		unit.action = Actions.Following.new(target_unit)
		return true
	if Actions.MovingToUnit.is_applicable(unit):
		unit.action = Actions.MovingToUnit.new(target_unit)
		return true
	if _try_setting_rally_point_to_unit(unit, target_unit):
		return true
	return false  # gdlint: ignore = max-returns


func _try_setting_rally_point_to_unit(unit, target_unit):
	if not unit is Structure:
		return false
	if not target_unit is ResourceUnit and unit.player != target_unit.player:
		# it's not allowed to set rally point to enemy at the moment as with current implementation
		# the position of enemy unit hidden in the fog of war could be hinted
		return false
	var rally_point = unit.find_child("RallyPoint")
	if rally_point == null:
		return false
	rally_point.target_unit = target_unit
	return true


func _on_terrain_targeted(position):
	_match.send_command("terrain", _get_selected_controlled_units(), [position])


func _on_unit_targeted(unit):
	var units = _get_selected_controlled_units()
	if units.is_empty():
		return
	_match.send_command("unit", units, [_match.get_path_to(unit)])
	var targetability = unit.find_child("Targetability")
	if targetability != null:
		targetability.animate()


func _on_navigate_unit_to_rally_point(unit, rally_point):
	if rally_point.target_unit != null:
		_navigate_unit_towards_unit(unit, rally_point.target_unit)
	elif rally_point.global_position != rally_point.get_parent().global_position:
		unit.action = Actions.Moving.new(rally_point.global_position)
