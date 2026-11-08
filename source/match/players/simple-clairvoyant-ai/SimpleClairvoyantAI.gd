extends "res://source/match/players/Player.gd"

enum ResourceRequestPriority { LOW, MEDIUM, HIGH }
enum OffensiveStructure { VEHICLE_FACTORY, AIRCRAFT_FACTORY }

const PowerController = preload(
	"res://source/match/players/simple-clairvoyant-ai/PowerController.gd"
)
const TechController = preload("res://source/match/players/simple-clairvoyant-ai/TechController.gd")
const AbilityController = preload(
	"res://source/match/players/simple-clairvoyant-ai/AbilityController.gd"
)

@export var expected_number_of_workers = 3
@export var expected_number_of_ccs = 1
@export var expected_number_of_ag_turrets = 1
@export var expected_number_of_aa_turrets = 1
@export var primary_offensive_structure = OffensiveStructure.VEHICLE_FACTORY
@export var secondary_offensive_structure = OffensiveStructure.AIRCRAFT_FACTORY
@export var expected_number_of_battlegroups = 2
@export var expected_number_of_units_in_battlegroup = 4

## Je Schwierigkeit (0 Leicht, 1 Normal, 2 Schwer): fruehester Angriff in Sekunden,
## Anzahl Kampfgruppen und Einheiten je Gruppe.
const DIFFICULTY_SETTINGS = [
	{"attack_delay_s": 720.0, "battlegroups": 1, "units": 3},
	{"attack_delay_s": 480.0, "battlegroups": 2, "units": 4},
	{"attack_delay_s": 300.0, "battlegroups": 3, "units": 5},
]

var attack_delay_s = 480.0

var _provisioning_ongoing = false
var _resource_requests = {
	ResourceRequestPriority.LOW: [],
	ResourceRequestPriority.MEDIUM: [],
	ResourceRequestPriority.HIGH: [],
}
var _call_to_perform_during_process = null
var _power_controller = PowerController.new()
var _ability_controller = AbilityController.new()
var _tech_controller = TechController.new()

@onready var _match = find_parent("Match")

@onready var _economy_controller = find_child("EconomyController")
@onready var _defense_controller = find_child("DefenseController")
@onready var _offense_controller = find_child("OffenseController")
@onready var _intelligence_controller = find_child("IntelligenceController")
@onready var _construction_works_controller = find_child("ConstructionWorksController")


func _ready():
	var difficulty_settings = DIFFICULTY_SETTINGS[clampi(difficulty, 0, 2)]
	attack_delay_s = difficulty_settings["attack_delay_s"]
	expected_number_of_battlegroups = difficulty_settings["battlegroups"]
	expected_number_of_units_in_battlegroup = difficulty_settings["units"]
	# wait for match to be ready
	if not _match.is_node_ready():
		await _match.ready
	# wait additional frame to make sure other players are in place
	await get_tree().physics_frame

	changed.connect(_on_player_data_changed)
	_power_controller.name = "PowerController"
	add_child(_power_controller)
	_power_controller.resources_required.connect(
		_on_resource_request.bind(_power_controller, ResourceRequestPriority.HIGH)
	)
	_power_controller.setup(self)
	_tech_controller.name = "TechController"
	add_child(_tech_controller)
	_tech_controller.resources_required.connect(
		_on_resource_request.bind(_tech_controller, ResourceRequestPriority.LOW)
	)
	_tech_controller.setup(self)
	_ability_controller.name = "AbilityController"
	add_child(_ability_controller)
	_ability_controller.setup(self)
	_economy_controller.resources_required.connect(
		_on_resource_request.bind(_economy_controller, ResourceRequestPriority.HIGH)
	)
	_economy_controller.setup(self)
	_defense_controller.resources_required.connect(
		_on_resource_request.bind(_defense_controller, ResourceRequestPriority.MEDIUM)
	)
	_defense_controller.setup(self)
	_offense_controller.resources_required.connect(
		_on_resource_request.bind(_offense_controller, ResourceRequestPriority.LOW)
	)
	_offense_controller.setup(self)
	_intelligence_controller.setup(self)
	_construction_works_controller.setup(self)


func _process(_delta):
	if _call_to_perform_during_process != null:
		var call_to_perform = _call_to_perform_during_process
		_call_to_perform_during_process = null
		call_to_perform.call()


func _provision(controller, resources, metadata):
	_provisioning_ongoing = true
	controller.provision(resources, metadata)
	_provisioning_ongoing = false


func _try_fulfilling_resource_requests_according_to_priorities_next_frame():
	"""This function defers call so that:
	1. 'add_child() from tree_exited signal handler' bug is avoided
	2. high level loop of signals triggering each other is avoided"""
	_call_to_perform_during_process = _try_fulfilling_resource_requests_according_to_priorities


func _try_fulfilling_resource_requests_according_to_priorities():
	if _provisioning_ongoing:
		return
	for priority in [
		ResourceRequestPriority.HIGH, ResourceRequestPriority.MEDIUM, ResourceRequestPriority.LOW
	]:
		while (
			not _resource_requests[priority].is_empty()
			and has_resources(_resource_requests[priority].front()["resources"])
		):
			var resource_request = _resource_requests[priority].pop_front()
			_provision(
				resource_request["controller"],
				resource_request["resources"],
				resource_request["metadata"]
			)
		if (
			not _resource_requests[priority].is_empty()
			and not has_resources(_resource_requests[priority].front()["resources"])
		):
			break


func _on_player_data_changed():
	_try_fulfilling_resource_requests_according_to_priorities_next_frame()


func _on_resource_request(resources, metadata, controller, priority):
	assert(not _provisioning_ongoing, "resource request received during provisioning")
	_resource_requests[priority].append(
		{"controller": controller, "resources": resources, "metadata": metadata}
	)
	_try_fulfilling_resource_requests_according_to_priorities_next_frame()
