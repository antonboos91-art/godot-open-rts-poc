## Sichtbare Befehlswarteschlangen und Ziel-Markierungen (nur Anzeige, nur lokaler Spieler):
##  - grün: Bewegen/Wegpunkte, orange: Angriffs-Marsch, rot: Angriffsziel mit Zielring
##  - Sammelpunkte ausgewählter Gebäude als türkise Linie
##  - Zielring der Superwaffe beim Zielen (Wirkungsradius) und kurze Warnung vor dem Einschlag
extends Node3D

const Factions = preload("res://source/match/factions/Factions.gd")

const UPDATE_S = 0.1
const LINE_HEIGHT = 0.12
const MOVE_COLOR = Color(0.35, 1.0, 0.45)
const ATTACK_MOVE_COLOR = Color(1.0, 0.6, 0.15)
const ATTACK_COLOR = Color(1.0, 0.25, 0.2)
const RALLY_COLOR = Color(0.3, 0.9, 1.0)
const RING_SEGMENTS = 28

var _mesh = ImmediateMesh.new()
var _instance = MeshInstance3D.new()
var _timer = null
var _telegraphs = []  # [{"position", "radius", "until_s"}]
var targeting_radius = 0.0  # > 0: Superwaffe wird gerade gezielt
var _last_lines = 0


func _ready():
	name = "CommandLines"
	_instance.mesh = _mesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 10
	_instance.material_override = material
	add_child(_instance)
	if DisplayServer.get_name() == "headless":
		return
	_timer = Timer.new()
	_timer.wait_time = UPDATE_S
	_timer.timeout.connect(redraw)
	add_child(_timer)
	_timer.start()


## Warnkreis vor einem Einschlag (Superwaffe): bleibt "seconds" Sekunden sichtbar.
func add_telegraph(position, radius, seconds):
	_telegraphs.append(
		{"position": position, "radius": radius, "until_s": Time.get_ticks_msec() / 1000.0 + seconds}
	)


## Linien, die für die aktuelle Auswahl gezeichnet werden: [{"from", "to", "color"}].
func collect_lines():
	var lines = []
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not is_instance_valid(unit) or not unit.is_in_group("controlled_units"):
			continue
		var cursor = unit.global_position
		var action = unit.action
		var color = MOVE_COLOR
		if action != null:
			if action.has_method("get_target_position"):
				var target = action.get_target_position()
				if target != null and target != Vector3.INF:
					color = ATTACK_MOVE_COLOR if action.get_script().resource_path.ends_with("AttackMoving.gd") else MOVE_COLOR
					lines.append({"from": cursor, "to": target, "color": color})
					cursor = target
			elif action.has_method("get_target_unit"):
				var target_unit = action.get_target_unit()
				if is_instance_valid(target_unit):
					lines.append({"from": cursor, "to": target_unit.global_position, "color": ATTACK_COLOR})
					cursor = target_unit.global_position
		for order in unit.order_queue:
			var queued_color = ATTACK_MOVE_COLOR if order["kind"] == "attack_move" else MOVE_COLOR
			lines.append({"from": cursor, "to": order["pos"], "color": queued_color})
			cursor = order["pos"]
		var rally = unit.find_child("RallyPoint")
		if rally != null:
			var rally_target = (
				rally.target_unit.global_position if rally.target_unit != null else rally.global_position
			)
			if rally_target.distance_to(unit.global_position) > 1.0:
				lines.append({"from": unit.global_position, "to": rally_target, "color": RALLY_COLOR})
	return lines


func redraw():
	_mesh.clear_surfaces()
	var lines = collect_lines()
	var now = Time.get_ticks_msec() / 1000.0
	_telegraphs = _telegraphs.filter(func(t): return t["until_s"] > now)
	_last_lines = lines.size()
	if lines.is_empty() and _telegraphs.is_empty() and targeting_radius <= 0.0:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for line in lines:
		_segment(line["from"], line["to"], line["color"])
		_marker(line["to"], line["color"])
	for telegraph in _telegraphs:
		var pulse = 0.65 + 0.35 * sin(now * 10.0)
		_ring(telegraph["position"], telegraph["radius"], Color(1.0, 0.2, 0.15, pulse))
		_ring(telegraph["position"], telegraph["radius"] * 0.5, Color(1.0, 0.5, 0.2, pulse))
	if targeting_radius > 0.0:
		var camera = get_viewport().get_camera_3d()
		var point = camera.get_ray_intersection(get_viewport().get_mouse_position())
		if point != null:
			_ring(point, targeting_radius, Color(1.0, 0.85, 0.2))
			_marker(point, Color(1.0, 0.85, 0.2))
	_mesh.surface_end()


func _segment(from, to, color):
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(Vector3(from.x, LINE_HEIGHT, from.z))
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(Vector3(to.x, LINE_HEIGHT, to.z))


func _marker(point, color):
	var size = 0.45
	_segment(point + Vector3(-size, 0, 0), point + Vector3(size, 0, 0), color)
	_segment(point + Vector3(0, 0, -size), point + Vector3(0, 0, size), color)


func _ring(center, radius, color):
	for i in RING_SEGMENTS:
		var a = TAU * i / RING_SEGMENTS
		var b = TAU * (i + 1) / RING_SEGMENTS
		_segment(
			center + Vector3(cos(a), 0, sin(a)) * radius, center + Vector3(cos(b), 0, sin(b)) * radius, color
		)
