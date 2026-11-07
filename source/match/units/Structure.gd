extends "res://source/match/units/Unit.gd"

signal constructed

const UNDER_CONSTRUCTION_MATERIAL = preload(
	"res://source/match/resources/materials/structure_under_construction.material.tres"
)

var _construction_progress = 1.0:
	set = _set_construction_progress

@onready var production_queue = find_child("ProductionQueue"):
	set(_value):
		pass


func is_revealing():
	return super() and is_constructed()


func mark_as_under_construction():
	assert(not is_under_construction(), "structure already under construction")
	_construction_progress = 0.0
	_change_geometry_material(UNDER_CONSTRUCTION_MATERIAL)
	if hp == null:
		await ready
	hp = 1


func construct(progress):
	assert(is_under_construction(), "structure must be under construction")

	var expected_hp_before_progressing = int(_construction_progress * float(hp_max - 1))
	_construction_progress += progress
	var expected_hp_after_progressing = int(_construction_progress * float(hp_max - 1))
	if expected_hp_after_progressing > expected_hp_before_progressing:
		hp += 1
	if _construction_progress >= 1.0:
		_finish_construction()


func cancel_construction():
	if Network.is_client():
		find_parent("Match").send_command("cancel_construction", [self])
		return
	player.add_resources(Factions.cost(Factions.variant_of(self)))
	queue_free()


func is_constructed():
	return _construction_progress >= 1.0


func is_under_construction():
	return not is_constructed()


func _finish_construction():
	_change_geometry_material(null)
	if is_inside_tree():
		constructed.emit()
		MatchSignals.unit_construction_finished.emit(self)


func _change_geometry_material(material):
	for child in find_child("Geometry").find_children("*"):
		if "material_override" in child:
			child.material_override = material


## Auf Clients kommt der Baufortschritt vom Host; Material entsprechend anpassen.
func _set_construction_progress(value):
	var was_constructed = _construction_progress >= 1.0
	_construction_progress = value
	if not Network.is_client():
		return
	if was_constructed and value < 1.0:
		_change_geometry_material(UNDER_CONSTRUCTION_MATERIAL)
	elif not was_constructed and value >= 1.0:
		_finish_construction()
