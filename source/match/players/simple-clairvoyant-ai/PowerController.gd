## Hält das Stromnetz der KI im Plus: baut rechtzeitig Kraftwerke ihres Volks.
extends Node

signal resources_required(resources, metadata)

const Factions = preload("res://source/match/factions/Factions.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const CommandCenter = preload("res://source/match/units/CommandCenter.gd")

const POWER_PLANT_PATH = "res://source/match/units/PowerPlant.tscn"
const REFRESH_INTERVAL_S = 1.0
const POWER_RESERVE = 5

var _player = null
var _pending_requests = 0


func setup(player):
	_player = player
	if Factions.faction_of(_player) == Factions.CORE:
		return
	var timer = Timer.new()
	timer.wait_time = REFRESH_INTERVAL_S
	timer.autostart = true
	timer.timeout.connect(_on_refresh_timer_timeout)
	add_child(timer)


func provision(resources, metadata):
	assert(metadata == "power", "unexpected flow")
	_pending_requests -= 1
	if resources != _power_plant_cost() or not _player.has_resources(resources):
		return
	var ccs = _own_units().filter(func(unit): return unit is CommandCenter)
	var workers = _own_units().filter(func(unit): return unit is Worker)
	if ccs.is_empty() and workers.is_empty():
		return
	var power_plant = load(POWER_PLANT_PATH).instantiate()
	var reference_position = (
		ccs[0].global_position if not ccs.is_empty() else workers[0].global_position
	)
	var placement_position = Utils.Match.Unit.Placement.find_valid_position_radially(
		reference_position,
		power_plant.radius + Constants.Match.Units.EMPTY_SPACE_RADIUS_SURROUNDING_STRUCTURE_M,
		find_parent("Match").navigation.get_navigation_map_rid_by_domain(
			power_plant.movement_domain
		),
		get_tree()
	)
	_player.subtract_resources(resources)
	MatchSignals.setup_and_spawn_unit.emit(
		power_plant, Transform3D(Basis(), placement_position), _player
	)


func _power_plant_cost():
	return Factions.cost_for(_player, POWER_PLANT_PATH)


func _own_units():
	return get_tree().get_nodes_in_group("units").filter(func(unit): return unit.player == _player)


## Plant auch Gebäude im Bau mit ein, damit Strom vor dem Bedarf da ist.
## Wie in C&C baut die KI früh ein erstes eigenes Kraftwerk, auch wenn die Zentrale
## anfangs genug Strom liefert. Sonst entsteht nie eins, solange die KI noch wenig baut.
func _on_refresh_timer_timeout():
	if _pending_requests > 0:
		return
	var produced = 0
	var used = 0
	var plants = 0
	for unit in _own_units():
		if not unit.has_method("is_constructed"):
			continue
		var power = Factions.power(Factions.variant_of(unit))
		if power > 0:
			produced += power
			if not unit is CommandCenter:
				plants += 1
		else:
			used -= power
	if plants == 0 or used + POWER_RESERVE > produced:
		_pending_requests += 1
		resources_required.emit(_power_plant_cost(), "power")
