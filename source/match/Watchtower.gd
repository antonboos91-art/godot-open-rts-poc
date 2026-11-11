## Neutraler Wachturm (wie der Xel'Naga-Turm in SC2): Steht eine eigene (oder verbündete) Bodeneinheit
## daneben, sieht das Team die Umgebung, auch im Nebel. Zieht die Einheit ab, ist der Turm wieder blind.
## Die Sicht wird nur auf dem eigenen Rechner berechnet (wie der Nebel des Krieges selbst).
extends Node3D

const OCCUPY_RADIUS_M = 3.0
const SCAN_INTERVAL_S = 0.3

var sight_range = 22.0
var _active = false
var _label = null
var _lamp_material = null
var _timer = null


func _ready():
	add_to_group("vision_sources")
	_build_visual()
	_timer = Timer.new()
	_timer.wait_time = SCAN_INTERVAL_S
	_timer.timeout.connect(scan)
	add_child(_timer)
	_timer.start()


## Wird vom Nebel des Krieges und der Sichtbarkeitsprüfung wie eine Einheit behandelt.
func is_revealing():
	return _active


func is_active():
	return _active


## Prüft, ob eine Bodeneinheit des sichtbaren Spielers (oder Verbündeter) am Turm steht.
func scan():
	var match_node = find_parent("Match")
	var viewer = match_node.visible_player if match_node != null else null
	var occupied = false
	if viewer != null:
		for unit in get_tree().get_nodes_in_group("units"):
			if (
				unit.has_method("is_constructed")
				or unit.movement_speed <= 0.0
				or unit.movement_domain != Constants.Match.Navigation.Domain.TERRAIN
			):
				continue
			if (
				unit.player.is_ally_of(viewer)
				and unit.global_position_yless.distance_to(global_position * Vector3(1, 0, 1))
				<= OCCUPY_RADIUS_M
			):
				occupied = true
				break
	_set_active(occupied)


func _set_active(active):
	if active == _active:
		return
	_active = active
	if _lamp_material != null:
		_lamp_material.emission = Color(1.0, 0.85, 0.2) if active else Color(0.25, 0.25, 0.3)
		_lamp_material.albedo_color = Color(1.0, 0.85, 0.2) if active else Color(0.35, 0.35, 0.4)
	if _label != null:
		_label.text = "WACHTURM: BESETZT" if active else "WACHTURM"


func _build_visual():
	if DisplayServer.get_name() == "headless":
		return
	var pole = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.45
	cylinder.bottom_radius = 0.8
	cylinder.height = 4.0
	pole.mesh = cylinder
	pole.position.y = 2.0
	var stone = StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.4, 0.38)
	pole.material_override = stone
	add_child(pole)
	var lamp = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	lamp.mesh = sphere
	lamp.position.y = 4.4
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.emission_enabled = true
	_lamp_material.emission = Color(0.25, 0.25, 0.3)
	_lamp_material.albedo_color = Color(0.35, 0.35, 0.4)
	lamp.material_override = _lamp_material
	add_child(lamp)
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = OCCUPY_RADIUS_M - 0.15
	torus.outer_radius = OCCUPY_RADIUS_M
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.03, 1.0)
	ring.position.y = 0.04
	var ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(1.0, 0.85, 0.2, 0.7)
	ring.material_override = ring_material
	add_child(ring)
	_label = Label3D.new()
	_label.text = "WACHTURM"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.012
	_label.font_size = 40
	_label.outline_size = 8
	_label.position.y = 5.6
	add_child(_label)
