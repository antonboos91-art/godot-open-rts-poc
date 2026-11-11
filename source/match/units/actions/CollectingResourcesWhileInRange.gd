extends "res://source/match/units/actions/Action.gd"

const Worker = preload("res://source/match/units/Worker.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")

const OPTIMAL_COLLECTORS = 2
const SATURATION_PENALTY = 0.5

var _resource_unit = null
var _timer = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _unit_movement_trait = _unit.get_node_or_null("Movement")


static func is_applicable(source_unit, target_unit):
	return (
		source_unit is Worker
		and target_unit is ResourceUnit
		and not source_unit.is_full()
		and Utils.Match.Unit.Movement.units_adhere(source_unit, target_unit)
	)


func _init(resource_unit):
	_resource_unit = resource_unit


func _ready():
	_resource_unit.tree_exited.connect(queue_free)
	_resource_unit.set_meta("collectors", _resource_unit.get_meta("collectors", 0) + 1)
	_unit_movement_trait.passive_movement_started.connect(_on_passive_movement_started)
	_unit_movement_trait.passive_movement_finished.connect(_on_passive_movement_finished)
	_setup_timer()
	_unit.get_node("Sparkling").enable()


func _exit_tree():
	if is_instance_valid(_resource_unit):
		_resource_unit.set_meta("collectors", max(0, _resource_unit.get_meta("collectors", 0) - 1))
	_unit.get_node("Sparkling").disable()


func _setup_timer():
	_timer = Timer.new()
	_timer.timeout.connect(_transfer_single_resource_unit_from_resource_to_worker)
	add_child(_timer)
	if "resource_a" in _resource_unit:
		_timer.start(Constants.Match.Resources.A.COLLECTING_TIME_S)
	elif "resource_b" in _resource_unit:
		_timer.start(Constants.Match.Resources.B.COLLECTING_TIME_S)


func _transfer_single_resource_unit_from_resource_to_worker():
	if not Utils.Match.Unit.Movement.units_adhere(_unit, _resource_unit):
		queue_free()
		return
	if "resource_a" in _resource_unit:
		_resource_unit.resource_a -= 1
		_unit.resource_a += 1
	if "resource_b" in _resource_unit:
		_resource_unit.resource_b -= 1
		_unit.resource_b += 1
	if _unit.is_full():
		queue_free()
	else:
		_timer.wait_time = _collecting_time() * _saturation_slowdown()


func _rotate_unit_towards_resource_unit():
	_unit.global_transform = _unit.global_transform.looking_at(
		Vector3(
			_resource_unit.global_position.x,
			_unit.global_position.y,
			_resource_unit.global_position.z
		),
		Vector3(0, 1, 0)
	)


func _on_passive_movement_started():
	_timer.paused = true


func _on_passive_movement_finished():
	_timer.paused = false
	_rotate_unit_towards_resource_unit()


## Ab dem dritten Sammler an einem Knoten wird es zäher (sinkender Ertrag wie in SC2):
## je zusätzlichem Sammler 50 % mehr Zeit pro Einheit.
func _saturation_slowdown():
	var collectors = _resource_unit.get_meta("collectors", 1)
	return 1.0 + SATURATION_PENALTY * max(0, collectors - OPTIMAL_COLLECTORS)


func _collecting_time():
	if "resource_a" in _resource_unit:
		return Constants.Match.Resources.A.COLLECTING_TIME_S
	return Constants.Match.Resources.B.COLLECTING_TIME_S
