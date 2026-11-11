extends "res://source/match/units/Structure.gd"

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

var cargo = []  # Besatzung (nur Host): [{scene, variant, hp}], siehe Match.board_transport
var cargo_count = 0  # wird repliziert, für die Anzeige


func _ready():
	await super()
	find_child("Geometry").visible = visible
	visibility_changed.connect(func(): find_child("Geometry").visible = visible)
	if not is_constructed():
		await constructed
	action = WaitingForTargets.new()


func _set_action(action_node):
	if not _action_locked and action == null:
		super(action_node)
	elif action_node != null:
		action_node.queue_free()


## Stirbt der Turm, kommt die Besatzung heil heraus (nur Host).
func _handle_unit_death():
	if not cargo.is_empty() and _match != null:
		_match._unload_transport(self)
	super()
