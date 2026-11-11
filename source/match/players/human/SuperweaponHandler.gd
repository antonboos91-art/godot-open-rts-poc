## Zielen der Superwaffe: Knopf im Menü, dann Linksklick (oder Tippen) aufs Ziel,
## Rechtsklick bricht ab.
extends Node

const Factions = preload("res://source/match/factions/Factions.gd")

var _structure = null
var _click_started = false

@onready var _match = find_parent("Match")


func _ready():
	MatchSignals.superweapon_targeting_requested.connect(_on_targeting_requested)


func _unhandled_input(event):
	if _structure == null:
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		get_viewport().set_input_as_handled()
		_structure = null
		_set_targeting_radius(0.0)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_click_started = true
		elif _click_started:
			_fire_at(event.position)


func _fire_at(screen_position):
	_click_started = false
	var target = get_viewport().get_camera_3d().get_ray_intersection(screen_position)
	if target != null and is_instance_valid(_structure):
		_match.send_command("superweapon", [_structure], [target])
	_structure = null
	_set_targeting_radius(0.0)


func _on_targeting_requested(structure):
	_structure = structure
	var strike = Factions.entry(Factions.variant_of(structure)).get("strike", {})
	_set_targeting_radius(strike.get("radius", 0.0))
	_click_started = false


func _set_targeting_radius(radius):
	var lines = _match.get_node_or_null("CommandLines")
	if lines != null:
		lines.targeting_radius = radius
