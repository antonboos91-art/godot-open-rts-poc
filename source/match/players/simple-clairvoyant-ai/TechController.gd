## Baut die Technik-Gebäude des Volks der Reihe nach aus (Rohstoff-Verarbeitung, Kaserne,
## Funkmast, Labor, ...) bis hin zur Superwaffe, sobald die Voraussetzungen erfüllt sind.
extends Node

signal resources_required(resources, metadata)

const Factions = preload("res://source/match/factions/Factions.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const CommandCenter = preload("res://source/match/units/CommandCenter.gd")

const REFRESH_INTERVAL_S = 5.0
const TECH_ORDER = [
	"refinery",
	"barracks",
	"factory",
	"silo",
	"radar",
	"repair",
	"power_big",
	"lab",
	"airfield",
	"superweapon",
]

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
	_pending_requests -= 1
	var variant = metadata
	if (
		not Factions.is_available(_player, variant)
		or resources != Factions.cost(variant)
		or not _player.has_resources(resources)
		or _has_structure(variant)
	):
		return
	var ccs = _own_units().filter(func(unit): return unit is CommandCenter)
	var workers = _own_units().filter(func(unit): return unit is Worker)
	if ccs.is_empty() and workers.is_empty():
		return
	var structure = load(Factions.entry(variant)["archetype"]).instantiate()
	structure.variant = variant
	var reference_position = (
		ccs[0].global_position if not ccs.is_empty() else workers[0].global_position
	)
	var placement_position = Utils.Match.Unit.Placement.find_valid_position_radially(
		reference_position,
		structure.radius + Constants.Match.Units.EMPTY_SPACE_RADIUS_SURROUNDING_STRUCTURE_M,
		find_parent("Match").navigation.get_navigation_map_rid_by_domain(structure.movement_domain),
		get_tree()
	)
	_player.subtract_resources(resources)
	MatchSignals.setup_and_spawn_unit.emit(
		structure, Transform3D(Basis(), placement_position), _player
	)


func _own_units():
	return get_tree().get_nodes_in_group("units").filter(func(unit): return unit.player == _player)


func _has_structure(variant):
	return _own_units().any(func(unit): return unit is Structure and unit.variant == variant)


func _next_variant():
	var faction = Factions.faction_of(_player)
	for role in TECH_ORDER:
		var variant = faction + "/" + role
		if Factions.entry(variant).is_empty() or Factions.entry(variant)["later"]:
			continue
		if not _has_structure(variant):
			return variant if Factions.is_available(_player, variant) else null
	return null


func _on_refresh_timer_timeout():
	if _pending_requests > 0:
		return
	if _own_units().any(func(unit): return unit is Structure and not unit.is_constructed()):
		return  # erst fertig bauen
	var variant = _next_variant()
	if variant == null:
		return
	_pending_requests += 1
	resources_required.emit(Factions.cost(variant), variant)
