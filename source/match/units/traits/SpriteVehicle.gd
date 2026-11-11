## Fahrzeug aus vorgerenderten Sprites (Factorio-Prinzip, siehe Assets-Pipeline/blender/render_vehicle.py):
## assets/sprites/vehicles/<volk>_<variante>_hull.png   Spalten = Richtungen, Zeilen = Animationsframes
##   (Ketten bzw. Räder laufen mit der Geschwindigkeit, Rotoren drehen immer)
## assets/sprites/vehicles/<volk>_<variante>_turret.png Spalten = Richtungen (nur bei "turret": true)
## assets/sprites/vehicles/<volk>_<variante>.json        Maße und Waffe (cannon, rockets, mg, none)
## Wanne und Turm sind zwei Ebenen: Die Wanne zeigt in Fahrtrichtung, der Turm zielt unabhängig.
extends "res://source/match/units/traits/TankVisual.gd"

const SHADER = preload("res://source/shaders/3d/vehicle_sprite.gdshader")
const WEATHER_SHADER = preload("res://source/shaders/3d/vehicle_weathered.gdshader")
## Echte 3D-Modelle (tools/blender/export_vehicle.py); fehlt eins, werden die Sprites benutzt
const MODEL_DIR = "res://assets/models/vehicles/"
static var _noise_tex = null
const DIR = "res://assets/sprites/vehicles/"
const ROTOR_FPS = 24.0
## Massstab: Fahrzeuge sollen neben Infanterie (StarCraft-Niveau) deutlich groesser wirken.
const SCALE_BOOST = 1.45

var _meta = {}


func _s():
	return float(_meta.get("scale", 0.8)) * SCALE_BOOST


var _hull_mat = null
var _turret_mat = null
var _turret_quad = null
var _turret_yaw = 0.0  # relativ zur Wanne
var _columns = 64
var _rows = 4
var _has_turret = true
var _anim_time = 0.0
var _rocket_side = 1.0
var _model = null
var _turret_node = null
var _track_phases = []
var _rotors = []


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
	_has_turret = bool(_meta.get("turret", true))
	var size = float(_meta.get("ortho", 3.6)) * _s()
	var center_y = float(_meta.get("target_z", 0.45)) * _s()
	if bool(_meta.get("air", false)):
		center_y = 0.0  # Fluggeräte: Einheitenursprung liegt schon in Flughöhe
	var model_path = MODEL_DIR + unit.variant.replace("/", "_") + ".glb"
	if ResourceLoader.exists(model_path):
		_setup_model(model_path)
	else:
		_hull_mat = _make_quad(base + "_hull.png", size, center_y, _rows, 3.0, "Hull")
		if _has_turret:
			_turret_mat = _make_quad(base + "_turret.png", size, center_y, 1, 3.4, "Turret")
	if not bool(_meta.get("air", false)):
		_add_team_ring()
	var engine = String(_meta.get("engine", "tank"))
	if engine == "rotor":
		_engine = _loop_player("rotor_loop", -10.0)
	else:
		_engine = _loop_player("tank_engine_loop", -8.0)
		if _engine != null and engine != "tank":
			_engine.pitch_scale = 1.4 if engine == "light" else 1.1
		if engine == "tank":
			_tracks_sound = _loop_player("tank_tracks_loop", -40.0)
	unit.child_entered_tree.connect(_on_unit_child_entered)


## 3D-Modell einsetzen: Massstab wie die Sprites (ein Blender-Meter = _s() Weltmeter),
## Materialien bekommen den Verwitterungs-Shader, Turm/Ketten/Rotoren werden gesucht.
func _setup_model(path):
	_model = load(path).instantiate()
	_model.name = "Model3D"
	_model.scale = Vector3.ONE * _s()
	if bool(_meta.get("air", false)):
		_model.position.y = -float(_meta.get("target_z", 0.45)) * _s()
	add_child(_model)
	_turret_node = _model.find_child("TurretPivot", true, false)
	_has_turret = _turret_node != null and bool(_meta.get("turret", true))
	for i in range(8):
		var t = _model.find_child("Tracks%d" % i, true, false)
		if t != null:
			_track_phases.append(t)
	for n in _model.find_children("rotor_*", "", true, false):
		if not n is MeshInstance3D:
			_rotors.append(n)
	_weather(_model)


static func _noise():
	if _noise_tex == null:
		var n = FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.03
		n.fractal_octaves = 4
		var t = NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.noise = n
		_noise_tex = t
	return _noise_tex


static var _weather_cache = {}


func _weather(node):
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for i in range(child.mesh.get_surface_count()):
				var src = child.get_active_material(i)
				if not src is StandardMaterial3D:
					continue
				var key = src.get_instance_id()
				if not _weather_cache.has(key):
					var m = ShaderMaterial.new()
					m.shader = WEATHER_SHADER
					m.set_shader_parameter("base_color", src.albedo_color)
					if src.albedo_texture != null:
						m.set_shader_parameter("base_tex", src.albedo_texture)
						m.set_shader_parameter("use_tex", true)
					m.set_shader_parameter("metallic", src.metallic)
					m.set_shader_parameter("roughness", src.roughness)
					if src.emission_enabled:
						m.set_shader_parameter("emission", src.emission)
						m.set_shader_parameter("emission_energy", src.emission_energy_multiplier * 2.0)
						m.set_shader_parameter("wear", 0.0)
					m.set_shader_parameter("noise", _noise())
					_weather_cache[key] = m
				child.set_surface_override_material(i, _weather_cache[key])
		_weather(child)


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


func _hull_yaw():
	var forward = -_unit.global_transform.basis.z
	return atan2(-forward.x, -forward.z)


func _process(delta):
	if _unit == null or delta <= 0.0:
		return
	var pos = _unit.global_position
	var step = pos - _last_position
	_last_position = pos
	var forward = -_unit.global_transform.basis.z
	var v = step.dot(forward) / delta if step.length() < 5.0 else 0.0
	_speed = lerp(_speed, v, clamp(delta * 8.0, 0.0, 1.0))
	var hull_yaw = _hull_yaw()
	# Animationsframes: Ketten/Räder laufen mit der Geschwindigkeit, Rotoren immer
	var row = 0
	if String(_meta.get("anim", "speed")) == "always":
		_anim_time += delta
		row = int(_anim_time * ROTOR_FPS) % _rows
	else:
		_track_offset += (
			_speed * delta / float(_meta.get("track_pitch", 0.06)) / _s()
		)
		row = int(floor(_track_offset * _rows)) % _rows
		if row < 0:
			row += _rows
	if _model != null:
		_process_model(delta, row)
	else:
		_hull_mat.set_shader_parameter("column", _column_for(hull_yaw))
		_hull_mat.set_shader_parameter("row", row)
	if _has_turret and _model == null:
		var target = _current_target()
		var desired = 0.0
		if target != null:
			var to_t = target.global_position - pos
			desired = wrapf(atan2(-to_t.x, -to_t.z) - hull_yaw, -PI, PI)
		_turret_yaw = rotate_toward(_turret_yaw, desired, TURRET_TURN_SPEED * delta)
		var turret_world = hull_yaw + _turret_yaw
		_turret_mat.set_shader_parameter("column", _column_for(turret_world))
		_recoil = move_toward(_recoil, 0.0, delta * 1.2)
		var back = Vector3(sin(turret_world), 0, cos(turret_world)) * _recoil
		_turret_quad.global_position = (
			global_position + Vector3(0, _turret_quad.position.y, 0) + back
		)
	# Sound
	var moving = abs(_speed) > 0.2
	if _engine != null and String(_meta.get("engine", "tank")) != "rotor":
		var load_factor = clamp(abs(_speed) / 3.0, 0.0, 1.0)
		var base_pitch = 1.4 if _meta.get("engine") == "light" else (1.1 if _meta.get("engine") == "truck" else 0.85)
		_engine.pitch_scale = base_pitch + load_factor * 0.35
		_engine.volume_db = lerp(-14.0, -4.0, load_factor)
	if _tracks_sound != null:
		_tracks_sound.volume_db = lerp(_tracks_sound.volume_db, -6.0 if moving else -40.0, delta * 5.0)
		_tracks_sound.pitch_scale = 0.8 + clamp(abs(_speed) / 4.0, 0.0, 0.5)


func _process_model(delta, row):
	for i in _track_phases.size():
		_track_phases[i].visible = i == row % _track_phases.size()
	for r in _rotors:
		r.rotate_object_local(Vector3.UP, delta * 28.0)
	if _has_turret:
		var target = _current_target()
		var desired = 0.0
		if target != null:
			var to_t = target.global_position - _unit.global_position
			desired = wrapf(atan2(-to_t.x, -to_t.z) - _hull_yaw(), -PI, PI)
		_turret_yaw = rotate_toward(_turret_yaw, desired, TURRET_TURN_SPEED * delta)
		_turret_node.rotation.y = _turret_yaw
		_recoil = move_toward(_recoil, 0.0, delta * 1.2)
		_turret_node.position = Vector3(sin(_turret_yaw), 0, cos(_turret_yaw)) * _recoil / max(_s(), 0.01)


func _fire(target):
	if not is_inside_tree() or not is_instance_valid(target):
		return
	var weapon = String(_meta.get("weapon", "cannon"))
	if weapon == "none":
		return
	# Waffe vor dem Schuss genau auf das Ziel ausrichten, damit der Schuss aus dem Rohr in Schussrichtung kommt
	var to_t = target.global_position - _unit.global_position
	to_t.y = 0.0
	if to_t.length() > 0.05:
		if _has_turret:
			_turret_yaw = wrapf(atan2(-to_t.x, -to_t.z) - _hull_yaw(), -PI, PI)
		else:
			_unit.look_at(_unit.global_position + to_t, Vector3.UP)
	var aim_yaw = _hull_yaw() + (_turret_yaw if _has_turret else 0.0)
	var dir = Vector3(-sin(aim_yaw), 0, -cos(aim_yaw))
	var side = Vector3(cos(aim_yaw), 0, -sin(aim_yaw))
	var s = _s()
	var base_y = 0.0 if bool(_meta.get("air", false)) else 0.0
	var muzzle = (
		global_position
		+ Vector3(0, base_y + (float(_meta.get("muzzle_z", 0.77)) - (0.45 if bool(_meta.get("air", false)) else 0.0)) * s, 0)
		+ dir * float(_meta.get("muzzle_dist", 1.85)) * s
	)
	var root = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var aim = target.global_position + Vector3(0, 0.8, 0)
	_recoil = float(_meta.get("recoil", 0.18))
	match weapon:
		"rockets":
			_rocket_side = -_rocket_side
			var from = muzzle + side * float(_meta.get("muzzle_side", 0.27)) * s * _rocket_side
			SoundEffects.play("rocket_launch", from)
			_spawn_smoke(root, from, Color(0.75, 0.75, 0.75, 0.6), 10, 0.7, 1.5, 0.3)
			_spawn_rocket(root, from, aim)
		"mg":
			# schnelle Salve im Stil des Volks
			for i in range(3):
				get_tree().create_timer(i * 0.09).timeout.connect(
					func():
						if is_instance_valid(_unit) and is_instance_valid(target):
							CombatFX.shot(_unit, muzzle, aim + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), 1.1)
				)
		_:
			SoundEffects.play("tank_fire", muzzle)
			CombatFX.shot(_unit, muzzle, aim, 2.2)


func _spawn_rocket(root, from, to):
	var rocket = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.05
	cap.height = 0.45
	rocket.mesh = cap
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.9, 0.92, 0.95)
	rocket.material_override = m
	root.add_child(rocket)
	rocket.global_position = from
	# Abgasstrahl und Rauchspur
	var trail = CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.6
	trail.local_coords = false
	trail.direction = Vector3.UP
	trail.spread = 25.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3(0, 0.4, 0)
	trail.scale_amount_min = 0.2
	trail.scale_amount_max = 0.4
	var q = QuadMesh.new()
	trail.mesh = q
	var tm = StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	tm.vertex_color_use_as_albedo = true
	tm.albedo_texture = _soft_dot()
	trail.material_override = tm
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.35, 1.0))
	g.add_point(0.2, Color(0.7, 0.7, 0.7, 0.6))
	g.set_color(g.get_point_count() - 1, Color(0.5, 0.5, 0.5, 0.0))
	trail.color_ramp = g
	rocket.add_child(trail)
	var dist = from.distance_to(to)
	var flight = max(dist / 22.0, 0.15)
	var apex = (from + to) / 2.0 + Vector3(0, min(dist * 0.25, 3.0), 0)
	var tw = root.create_tween()
	tw.tween_method(
		func(t):
			if not is_instance_valid(rocket):
				return
			var a = from.lerp(apex, t)
			var b = apex.lerp(to, t)
			var p = a.lerp(b, t)
			var ahead = a.lerp(b, min(t + 0.05, 1.0))
			rocket.global_position = p
			if p.distance_to(ahead) > 0.001:
				rocket.look_at(ahead, Vector3.UP)
				rocket.rotate_object_local(Vector3.RIGHT, PI / 2),
		0.0,
		1.0,
		flight
	)
	tw.tween_callback(_impact.bind(root, to))
	tw.tween_callback(func(): trail.emitting = false)
	tw.tween_interval(0.7)
	tw.tween_callback(rocket.queue_free)


func _spawn_mg(root, from, to):
	# Drei schnelle Leuchtspuren mit Funken am Ziel
	for i in range(3):
		var tracer = MeshInstance3D.new()
		var cap = CapsuleMesh.new()
		cap.radius = 0.025
		cap.height = 0.5
		tracer.mesh = cap
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.9, 0.5)
		tracer.material_override = m
		root.add_child(tracer)
		tracer.global_position = from
		var jitter = Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3))
		if from.distance_to(to + jitter) > 0.01:
			tracer.look_at(to + jitter, Vector3.UP)
			tracer.rotate_object_local(Vector3.RIGHT, PI / 2)
		var tw = root.create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(tracer, "global_position", to + jitter, max(from.distance_to(to) / 90.0, 0.04))
		tw.tween_callback(
			func(): _spawn_smoke(root, to + jitter, Color(1.0, 0.8, 0.4, 1.0), 6, 0.25, 4.0, 0.08)
		)
		tw.tween_callback(tracer.queue_free)
	_spawn_flash_small(root, from)


func _spawn_flash_small(root, at):
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 3.0
	light.omni_range = 3.0
	root.add_child(light)
	light.global_position = at
	var tw = root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.2)
	tw.tween_callback(light.queue_free)
