## Rohstoff-Abgabe eines Volks (Schrottpresse, Kristall-Mühle, Schmelzofen).
## Sammler liefern hier wie an der Zentrale ab; nach dem Bau gibt es einen Sammler gratis.
extends "res://source/match/units/Structure.gd"

const COLLECTING_ACTION_PATH = "res://source/match/units/actions/CollectingResourcesSequentially.gd"
const WORKER_PATH = "res://source/match/units/Worker.tscn"


func _ready():
	await super()
	constructed.connect(_spawn_free_collector)


func _spawn_free_collector():
	if Network.is_client():
		return
	var collector_variant = Factions.variant_for_player(player, WORKER_PATH)
	var collector = load(Factions.entry(collector_variant)["archetype"]).instantiate()
	collector.variant = collector_variant
	var match_node = find_parent("Match")
	var placement_position = (
		Utils
		. Match
		. Unit
		. Placement
		. find_valid_position_radially_yet_skip_starting_radius(
			global_position,
			radius,
			collector.radius,
			0.1,
			Vector3(0, 0, 1),
			false,
			match_node.navigation.get_navigation_map_rid_by_domain(collector.movement_domain),
			get_tree()
		)
	)
	MatchSignals.setup_and_spawn_unit.emit(
		collector, Transform3D(Basis(), placement_position), player
	)
	var resource_unit = (
		Utils
		. Match
		. Resources
		. find_resource_unit_closest_to_unit_yet_no_further_than(
			collector, Constants.Match.Units.NEW_RESOURCE_SEARCH_RADIUS_M
		)
	)
	if resource_unit != null:
		collector.action = load(COLLECTING_ACTION_PATH).new(resource_unit)
