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
	const Loading = preload("res://source/match/units/actions/Loading.gd")
	const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")


var _attack_move_armed = false

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
	for unit in units:
		unit.order_queue.clear()
	_try_navigating_units_towards_position(units, target_point)
	_try_setting_rally_points(units, target_point)


## Angriffs-Marsch: zum Punkt gehen und unterwegs alles angreifen (Taste F, danach Rechtsklick).
## Mit queued = true wird der Marsch an die wartenden Befehle angehängt.
func execute_attack_move(units, target_point, queued = false):
	var movers = units.filter(func(unit): return Actions.AttackMoving.is_applicable(unit))
	var targets = []
	for domain in [Constants.Match.Navigation.Domain.TERRAIN, Constants.Match.Navigation.Domain.AIR]:
		targets += Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
			movers.filter(func(unit): return unit.movement_domain == domain), target_point
		)
	for tuple in targets:
		if queued:
			tuple[0].queue_order({"kind": "attack_move", "pos": tuple[1]})
		else:
			tuple[0].order_queue.clear()
			tuple[0].action = Actions.AttackMoving.new(tuple[1])


## Shift + Rechtsklick: Wegpunkt an die Befehlsliste anhängen.
func execute_queue_move(units, target_point):
	var movers = units.filter(func(unit): return Actions.Moving.is_applicable(unit))
	var targets = []
	for domain in [Constants.Match.Navigation.Domain.TERRAIN, Constants.Match.Navigation.Domain.AIR]:
		targets += Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
			movers.filter(func(unit): return unit.movement_domain == domain), target_point
		)
	for tuple in targets:
		tuple[0].queue_order({"kind": "move", "pos": tuple[1]})


func _unhandled_input(event):
	if not _player.is_local() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	match event.physical_keycode:
		KEY_X:  # Stopp
			_match.send_command("stop", _get_selected_controlled_units())
		KEY_F:  # Angriffs-Marsch: nächster Rechtsklick auf das Gelände
			_attack_move_armed = not _attack_move_armed
			var armed_units = _get_selected_controlled_units()
			if _attack_move_armed and not armed_units.is_empty():
				_match.show_notice(armed_units[0].global_position, "ANGRIFFS-MARSCH: ZIEL WÄHLEN")
		KEY_DELETE:  # Verkaufen
			var structures = _get_selected_controlled_units().filter(func(u): return u is Structure)
			if not structures.is_empty():
				_match.send_command("sell", structures)


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
	if Actions.Loading.is_applicable(unit, target_unit):
		unit.action = Actions.Loading.new(target_unit)
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
	var units = _get_selected_controlled_units()
	var queued = Input.is_action_pressed("shift_selecting")
	if _attack_move_armed:
		_attack_move_armed = false
		_match.send_command("attack_move", units, [position, queued])
	elif queued:
		_match.send_command("queue_move", units, [position])
	else:
		_match.send_command("terrain", units, [position])


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
