## Zielen der Superwaffe: Knopf im Menü, dann Linksklick (oder Tippen) aufs Ziel,
## Rechtsklick bricht ab.
extends Node

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


func _on_targeting_requested(structure):
	_structure = structure
	_click_started = false
