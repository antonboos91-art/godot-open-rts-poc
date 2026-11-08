## Fahrzeug aus vorgerenderten Sprites (Factorio-Prinzip, siehe Assets-Pipeline/blender/render_vehicle.py):
## assets/sprites/vehicles/<volk>_<variante>_hull.png   Spalten = 64 Richtungen, Zeilen = Kettenframes
## assets/sprites/vehicles/<volk>_<variante>_turret.png Spalten = 64 Richtungen
## assets/sprites/vehicles/<volk>_<variante>.json        Maße (ortho, scale, target_z, muzzle)
## Wanne und Turm sind zwei Ebenen: Die Wanne zeigt in Fahrtrichtung, der Turm zielt unabhängig.
## Effekte und Sounds (Schuss, Einschlag, Motor, Ketten) kommen aus TankVisual.gd.
extends "res://source/match/units/traits/TankVisual.gd"

const SHADER = preload("res://source/shaders/3d/vehicle_sprite.gdshader")
const DIR = "res://assets/sprites/vehicles/"

var _meta = {}
var _hull_mat = null
var _turret_mat = null
var _turret_quad = null
var _turret_yaw = 0.0  # relativ zur Wanne
var _columns = 64
var _rows = 4


static func sprite_base_for(variant):
	if variant == "":
		return ""
	var base = DIR + variant.replace("/", "_")
	return base if ResourceLoader.exists(base + "_hull.png") else ""


static func try_attach(unit):
	var base = sprite_base_for(unit.variant)
	if base == "":
		return null
	var visual = new()
	visual.name = "SpriteVehicle"
	visual._setup_sprites(unit, base)
	unit.add_child(visual)
	var geometry = unit.find_child("Geometry", false, false)
	if geometry != null:
		geometry.visible = false
	return visual


func _setup_sprites(unit, base):
	_unit = unit
	var f = FileAccess.open(base + ".json", FileAccess.READ)
	_meta = JSON.parse_string(f.get_as_text()) if f != null else {}
	_parts = _meta
	_columns = int(_meta.get("columns", 64))
	_rows = int(_meta.get("rows", 4))
	var size = float(_meta.get("ortho", 3.6)) * float(_meta.get("scale", 0.8))
	var center_y = float(_meta.get("target_z", 0.45)) * float(_meta.get("scale", 0.8))
	_hull_mat = _make_quad(base + "_hull.png", size, center_y, _rows, 3.0, "Hull")
	var tq = _make_quad(base + "_turret.png", size, center_y, 1, 3.4, "Turret")
	_turret_mat = tq
	_add_team_ring()
	_engine = _loop_player("tank_engine_loop", -8.0)
	_tracks_sound = _loop_player("tank_tracks_loop", -40.0)
	unit.child_entered_tree.connect(_on_unit_child_entered)


func _make_quad(path, size, center_y, rows, bias, quad_name):
	var mi = MeshInstance3D.new()
	mi.name = quad_name
	var q = QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.position.y = center_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m = ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("sheet", load(path))
	m.set_shader_parameter("columns", _columns)
	m.set_shader_parameter("rows", rows)
	m.set_shader_parameter("depth_bias", bias)
	mi.material_override = m
	add_child(mi)
	if quad_name == "Turret":
		_turret_quad = mi
	return m


func _add_team_ring():
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.07
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.03, 1.0)
	ring.position.y = 0.02
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = _unit.color
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


## Spalte für eine Welt-Blickrichtung (Yaw, 0 = -Z) relativ zur Kamera.
func _column_for(world_yaw):
	var camera = get_viewport().get_camera_3d()
	var cam_yaw = 0.0
	if camera != null:
		var f = -camera.global_transform.basis.z
		cam_yaw = atan2(-f.x, -f.z)
	var rel = wrapf(world_yaw - cam_yaw, 0.0, TAU)
	var col = int(round(rel / TAU * _columns)) % _columns
	return (_columns - col) % _columns if bool(_meta.get("mirror", false)) else col


func _process(delta):
	if _unit == null or delta <= 0.0:
		return
	var pos = _unit.global_position
	var step = pos - _last_position
	_last_position = pos
	var forward = -_unit.global_transform.basis.z
	var v = step.dot(forward) / delta if step.length() < 5.0 else 0.0
	_speed = lerp(_speed, v, clamp(delta * 8.0, 0.0, 1.0))
	var hull_yaw = atan2(-forward.x, -forward.z)
	# Kettenframes laufen mit der Geschwindigkeit
	_track_offset += _speed * delta / float(_meta.get("track_pitch", 0.06)) / float(_meta.get("scale", 0.8))
	var row = int(floor(_track_offset * _rows)) % _rows
	if row < 0:
		row += _rows
	_hull_mat.set_shader_parameter("column", _column_for(hull_yaw))
	_hull_mat.set_shader_parameter("row", row)
	# Turm zielt unabhängig von der Wanne
	var target = _current_target()
	var desired = 0.0
	if target != null:
		var to_t = target.global_position - pos
		desired = wrapf(atan2(-to_t.x, -to_t.z) - hull_yaw, -PI, PI)
	_turret_yaw = rotate_toward(_turret_yaw, desired, TURRET_TURN_SPEED * delta)
	var turret_world = hull_yaw + _turret_yaw
	_turret_mat.set_shader_parameter("column", _column_for(turret_world))
	# Rückstoß: Turm-Ebene kurz entgegen der Schussrichtung verschieben
	_recoil = move_toward(_recoil, 0.0, delta * 1.2)
	var back = Vector3(sin(turret_world), 0, cos(turret_world)) * _recoil
	_turret_quad.global_position = global_position + Vector3(0, _turret_quad.position.y, 0) + back
	# Sound
	var moving = abs(_speed) > 0.2
	if _engine != null:
		var load_factor = clamp(abs(_speed) / 3.0, 0.0, 1.0)
		_engine.pitch_scale = 0.85 + load_factor * 0.35
		_engine.volume_db = lerp(-14.0, -4.0, load_factor)
	if _tracks_sound != null:
		_tracks_sound.volume_db = lerp(_tracks_sound.volume_db, -6.0 if moving else -40.0, delta * 5.0)
		_tracks_sound.pitch_scale = 0.8 + clamp(abs(_speed) / 4.0, 0.0, 0.5)


func _fire(target):
	if not is_inside_tree() or not is_instance_valid(target):
		return
	_recoil = float(_meta.get("recoil", 0.18))
	var turret_world = atan2(
		-(-_unit.global_transform.basis.z).x, -(-_unit.global_transform.basis.z).z
	) + _turret_yaw
	var dir = Vector3(-sin(turret_world), 0, -cos(turret_world))
	var s = float(_meta.get("scale", 0.8))
	var muzzle = (
		global_position
		+ Vector3(0, float(_meta.get("muzzle_z", 0.77)) * s, 0)
		+ dir * float(_meta.get("muzzle_dist", 1.9)) * s
	)
	var root = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	SoundEffects.play("tank_fire", muzzle)
	_spawn_flash(root, muzzle)
	_spawn_shell(root, muzzle, target.global_position + Vector3(0, 0.8, 0))
