# TODO: monitor attached units and fix their actions if necessary
extends Node

enum State { FORMING, ATTACKING }

const PLAYER_TO_ATTACK_SWITCHING_DELAY_S = 0.5


class Actions:
	const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
	const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
	const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")


var _expected_number_of_units = null
var _players_to_attack = null
var _player_to_attack = null

var _state = State.FORMING
var _attached_units = []


var _not_before_ms = 0


func _init(expected_number_of_units, players_to_attack, attack_delay_s = 0.0):
	_not_before_ms = Time.get_ticks_msec() + int(attack_delay_s * 1000.0)
	_expected_number_of_units = expected_number_of_units
	_players_to_attack = players_to_attack
	_player_to_attack = _players_to_attack.front()


func size():
	return _attached_units.size()


func attach_unit(unit):
	assert(_state == State.FORMING, "unexpected state")
	_attached_units.append(unit)
	unit.tree_exited.connect(_on_unit_died.bind(unit))
	if size() == _expected_number_of_units:
		_start_attacking()


func _start_attacking():
	_state = State.ATTACKING
	var wait_ms = _not_before_ms - Time.get_ticks_msec()
	if wait_ms > 0:
		# Gruppe wartet fertig formiert, bis die Schwierigkeit den Angriff erlaubt
		await get_tree().create_timer(wait_ms / 1000.0).timeout
		if not is_inside_tree():
			return
	_attack_next_adversary_unit()


func _attack_next_adversary_unit():
	var adversary_units = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.player == _player_to_attack
	)
	if adversary_units.is_empty():
		_attack_next_player()
		return
	var battlegroup_position = _attached_units[0].global_position
	var adversary_units_sorted_by_distance = adversary_units.map(
		func(adversary_unit):
			return {
				"distance":
				(adversary_unit.global_position * Vector3(1, 0, 1)).distance_to(
					battlegroup_position
				),
				"unit": adversary_unit
			}
	)
	adversary_units_sorted_by_distance.sort_custom(
		func(tuple_a, tuple_b): return tuple_a["distance"] < tuple_b["distance"]
	)
	for tuple in adversary_units_sorted_by_distance:
		var target_unit = tuple["unit"]
		if _attached_units.any(
			func(attached_unit):
				return Actions.AutoAttacking.is_applicable(attached_unit, target_unit)
		):
			target_unit.tree_exited.connect(_on_target_unit_died)
			for attached_unit in _attached_units:
				if Actions.AutoAttacking.is_applicable(attached_unit, target_unit):
					attached_unit.action = Actions.AutoAttacking.new(target_unit)
				else:
					attached_unit.action = Actions.MovingToUnit.new(target_unit)
			return
	# Ziele, die vom Boden aus nicht zu sehen sind (Plateau): Angriffs-Marsch zum nächsten Gegner,
	# unterwegs wird alles Sichtbare angegriffen. Danach sucht die Gruppe sich das nächste Ziel.
	if _march_towards_nearest(adversary_units_sorted_by_distance):
		return
	# if not possible to attack remaining units:
	_attack_next_player()


func _attack_next_player():
	var player_to_attack_index = _players_to_attack.find(_player_to_attack)
	var next_player_to_attack_index = (player_to_attack_index + 1) % _players_to_attack.size()
	_player_to_attack = _players_to_attack[next_player_to_attack_index]
	get_tree().create_timer(PLAYER_TO_ATTACK_SWITCHING_DELAY_S).timeout.connect(
		_attack_next_adversary_unit
	)


func _on_unit_died(unit):
	if not is_inside_tree():
		return
	_attached_units.erase(unit)
	if _state == State.ATTACKING and _attached_units.is_empty():
		queue_free()


func _on_target_unit_died():
	if not is_inside_tree():
		return
	_attack_next_adversary_unit()


const MARCH_CHECK_INTERVAL_S = 2.5
var _march_timer = null


func _march_towards_nearest(sorted_targets):
	if sorted_targets.is_empty() or _attached_units.is_empty():
		return false
	var target_position = sorted_targets[0]["unit"].global_position
	var marchers = _attached_units.filter(
		func(unit): return Actions.AttackMoving.is_applicable(unit)
	)
	if marchers.is_empty():
		return false
	for unit in marchers:
		unit.action = Actions.AttackMoving.new(target_position)
	if _march_timer == null:
		_march_timer = Timer.new()
		_march_timer.wait_time = MARCH_CHECK_INTERVAL_S
		_march_timer.timeout.connect(_on_march_timer)
		add_child(_march_timer)
		_march_timer.start()
	return true


## Beim Marsch neu bewerten: Ist die Gruppe angekommen (oder untätig), sucht sie ein neues Ziel.
func _on_march_timer():
	if not is_inside_tree() or _state != State.ATTACKING or _attached_units.is_empty():
		return
	var busy = _attached_units.any(
		func(unit):
			return (
				unit.action != null
				and (
					unit.action.get_script() == Actions.AutoAttacking
					or unit.action.get_script() == Actions.AttackMoving
				)
			)
	)
	if not busy:
		_attack_next_adversary_unit()
