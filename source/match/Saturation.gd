## Auslastungsanzeige (wie "16/16" in SC2): Über jeder eigenen Zentrale und Raffinerie steht
## "Sammler / Platz": Sammler, die Knoten im Umkreis anlaufen, geteilt durch zwei je Knoten.
extends Node

const Factions = preload("res://source/match/factions/Factions.gd")

const UPDATE_S = 0.5
const RADIUS_M = 22.0
const WORKERS_PER_NODE = 2

var _human = null
var _timer = null


func setup(human):
	_human = human
	name = "Saturation"
	if DisplayServer.get_name() == "headless":
		return
	_timer = Timer.new()
	_timer.wait_time = UPDATE_S
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()


## [Sammler, Plätze] für eine Annahmestelle (Zentrale / Raffinerie).
func saturation_of(structure):
	var nodes = get_tree().get_nodes_in_group("resource_units").filter(
		func(n): return n.global_position_yless.distance_to(structure.global_position_yless) <= RADIUS_M
	)
	var workers = 0
	for node in nodes:
		workers += node.get_meta("claims", 0)
	return [workers, nodes.size() * WORKERS_PER_NODE]


func refresh():
	if _human == null or not is_instance_valid(_human):
		return
	for structure in _human.get_children():
		if not structure.has_method("is_constructed") or not structure.is_constructed():
			continue
		var role = Factions.role(Factions.variant_of(structure))
		if role != "hq" and role != "refinery":
			continue
		var label = structure.get_node_or_null("SaturationLabel")
		if label == null:
			label = Label3D.new()
			label.name = "SaturationLabel"
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.pixel_size = 0.012
			label.font_size = 44
			label.outline_size = 10
			label.position = Vector3(0, 6.2, 0)
			structure.add_child(label)
		var value = saturation_of(structure)
		label.text = "%d/%d" % value
		label.modulate = (
			Color(0.5, 1.0, 0.5)
			if value[0] == value[1]
			else (Color(1.0, 0.8, 0.3) if value[0] < value[1] else Color(1.0, 0.45, 0.35))
		)
