## Baukasten-Panzer: Wanne + Turm (KI-Modelle) + Fahrwerk (Blender-Skript) aus
## assets/models/factions/<volk>_<variante>/ (hull.glb, turret.glb, gear.glb, parts.json).
## Räder drehen sich, Ketten laufen, der Turm zielt auf das Ziel, beim Schuss gibt es
## Rückstoß, Mündungsfeuer, Leuchtspur-Granate, Einschlag, Motor- und Kettensound.
extends Node3D

const TRACK_SHADER = preload("res://source/shaders/3d/tank_track.gdshader")
const CombatFX = preload("res://source/match/units/traits/CombatFX.gd")
const TURRET_TURN_SPEED = 2.6  # rad/s
const SHELL_SPEED = 60.0

var _unit = null
var _parts = {}
var _turret_pivot = null
var _turret = null
var _wheels = []
var _track_materials = []
var _track_offset = 0.0
var _last_position = Vector3.ZERO
var _speed = 0.0
var _recoil = 0.0
var _engine = null
var _tracks_sound = null
var _aim_target = null
var _aim_until = 0


static func dir_for(variant):
	if variant == "":
		return ""
	var d = "res://assets/models/factions/" + variant.replace("/", "_") + "/"
	return d if ResourceLoader.exists(d + "hull.glb") else ""


static func try_attach(unit):
	var d = dir_for(unit.variant)
	if d == "":
		return null
	var visual = new()
	visual.name = "TankVisual"
	visual._setup(unit, d)
	unit.add_child(visual)
	var geometry = unit.find_child("Geometry", false, false)
	if geometry != null:
		geometry.visible = false
	return visual


func _setup(unit, d):
	_unit = unit
	var f = FileAccess.open(d + "parts.json", FileAccess.READ)
	_parts = JSON.parse_string(f.get_as_text()) if f != null else {}
	scale = Vector3.ONE * float(_parts.get("scale", 0.5))
	var hull = load(d + "hull.glb").instantiate()
	add_child(hull)
	brighten(hull)
	var gear = load(d + "gear.glb").instantiate()
	add_child(gear)
	_turret_pivot = Node3D.new()
	_turret_pivot.name = "TurretPivot"
	var p = _parts.get("turret_pivot", [0, 1.4, 0])
	_turret_pivot.position = Vector3(p[0], p[1], p[2])
	add_child(_turret_pivot)
	_turret = Node3D.new()
	var turret_model = load(d + "turret.glb").instantiate()
	_turret.add_child(turret_model)
	brighten(turret_model)
	_turret_pivot.add_child(_turret)
	_collect_gear(gear)
	_add_team_ring()
	_engine = _loop_player("tank_engine_loop", -8.0)
	_tracks_sound = _loop_player("tank_tracks_loop", -40.0)
	unit.child_entered_tree.connect(_on_unit_child_entered)


## Das Spiel ist absichtlich düster beleuchtet; KI-Texturen leuchten leicht selbst,
## damit Modelle so gut lesbar sind wie die Sprites.
static func brighten(node, energy = 0.22):
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			for i in range(child.mesh.get_surface_count()):
				var mat = child.get_active_material(i)
				if mat is StandardMaterial3D:
					var m = mat.duplicate()
					m.emission_enabled = true
					m.emission = Color.WHITE if m.albedo_texture != null else m.albedo_color
					m.emission_texture = m.albedo_texture
					m.emission_energy_multiplier = energy
					child.set_surface_override_material(i, m)
		brighten(child, energy)


func _collect_gear(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			if child.name.begins_with("Track"):
				var m = ShaderMaterial.new()
				m.shader = TRACK_SHADER
				child.material_override = m
				_track_materials.append(m)
			elif child.name.begins_with("Barrel"):
				child.visible = false  # das KI-Rohr am Turm wird verwendet
			elif (
				child.name.begins_with("Wheel")
				or child.name.begins_with("Sprocket")
				or child.name.begins_with("Idler")
			):
				_wheels.append(child)
		_collect_gear(child)


func _add_team_ring():
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.25
	torus.outer_radius = 2.5
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.04, 1.0)
	ring.position.y = 0.03
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = _unit.color
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _loop_player(sound_name, volume_db):
	if DisplayServer.get_name() == "headless":
		return null
	var path = "res://assets/sounds/" + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var stream = load(path).duplicate()
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		var frame_bytes = (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (
			2 if stream.stereo else 1
		)
		stream.loop_end = stream.data.size() / frame_bytes
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 10.0
	player.max_distance = 70.0
	player.autoplay = true
	add_child(player)
	return player


func _process(delta):
	if _unit == null or delta <= 0.0:
		return
	var pos = _unit.global_position
	var step = pos - _last_position
	_last_position = pos
	var forward = -_unit.global_transform.basis.z
	var v = step.dot(forward) / delta if step.length() < 5.0 else 0.0
	_speed = lerp(_speed, v, clamp(delta * 8.0, 0.0, 1.0))
	# Räder und Ketten
	var radius = float(_parts.get("wheel_radius", 0.25))
	for w in _wheels:
		w.rotate_object_local(Vector3.RIGHT, -_speed * delta / radius)
	_track_offset += _speed * delta / float(_parts.get("track_length", 9.0))
	for m in _track_materials:
		m.set_shader_parameter("offset", _track_offset)
	# Wippen beim Fahren
	var moving = abs(_speed) > 0.2
	rotation.x = sin(Time.get_ticks_msec() * 0.012) * 0.006 if moving else 0.0
	# Sound
	if _engine != null:
		var load_factor = clamp(abs(_speed) / 3.0, 0.0, 1.0)
		_engine.pitch_scale = 0.85 + load_factor * 0.35
		_engine.volume_db = lerp(-14.0, -4.0, load_factor)
	if _tracks_sound != null:
		_tracks_sound.volume_db = lerp(_tracks_sound.volume_db, -6.0 if moving else -40.0, delta * 5.0)
		_tracks_sound.pitch_scale = 0.8 + clamp(abs(_speed) / 4.0, 0.0, 0.5)
	# Turm zielt
	var target = _current_target()
	var desired = 0.0
	if target != null:
		var local = to_local(target.global_position)
		desired = atan2(-local.x, -local.z)
	_turret_pivot.rotation.y = rotate_toward(
		_turret_pivot.rotation.y, desired, TURRET_TURN_SPEED * delta
	)
	# Rückstoß abklingen lassen
	_recoil = move_toward(_recoil, 0.0, delta * 1.6)
	_turret.position.z = _recoil
	rotation.x += -_recoil * 0.05


## Aktuelles Ziel: zuletzt beschossene Einheit, sonst Ziel der Aktion (auch verschachtelt,
## z. B. WaitingForTargets -> AutoAttacking -> AttackingWhileInRange).
func _current_target():
	if _aim_target != null and is_instance_valid(_aim_target) and Time.get_ticks_msec() < _aim_until:
		return _aim_target
	var action = _unit.get("action")
	var depth = 0
	while action != null and is_instance_valid(action) and depth < 6:
		var t = action.get("_target_unit")
		if t != null and is_instance_valid(t):
			return t
		action = action.get("_sub_action")
		depth += 1
	return null


func _on_unit_child_entered(node):
	var target = node.get("target_unit")
	if target == null or not is_instance_valid(target):
		return
	_aim_target = target
	_aim_until = Time.get_ticks_msec() + 2500
	_fire.call_deferred(target)


func _fire(target):
	if not is_inside_tree() or not is_instance_valid(target):
		return
	_recoil = float(_parts.get("recoil", 0.35))
	var m = _parts.get("muzzle", [0, 0, -2.3])
	var muzzle = _turret.to_global(Vector3(m[0], m[1], m[2]))
	var get_tree_root = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	SoundEffects.play("tank_fire", muzzle)
	CombatFX.shot(_unit, muzzle, target.global_position + Vector3(0, 0.8, 0), 2.2)


func _spawn_flash(root, at):
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 6.0
	light.omni_range = 7.0
	root.add_child(light)
	light.global_position = at
	var flash = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	flash.mesh = q
	var fm = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_color = Color(1.0, 0.8, 0.4, 1.0)
	fm.albedo_texture = _soft_dot()
	flash.material_override = fm
	root.add_child(flash)
	flash.global_position = at
	_spawn_smoke(root, at, Color(0.6, 0.6, 0.6, 0.55), 12, 0.8, 2.0, 0.35)
	var tw = root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.12)
	tw.parallel().tween_property(fm, "albedo_color:a", 0.0, 0.1)
	tw.tween_callback(light.queue_free)
	tw.tween_callback(flash.queue_free)


func _spawn_shell(root, from, to):
	var shell = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.06
	cap.height = 0.9
	shell.mesh = cap
	var sm = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.85, 0.5)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.7, 0.3)
	shell.material_override = sm
	root.add_child(shell)
	shell.global_position = from
	if from.distance_to(to) > 0.01:
		shell.look_at(to, Vector3.UP)
		shell.rotate_object_local(Vector3.RIGHT, PI / 2)
	var flight = max(from.distance_to(to) / SHELL_SPEED, 0.05)
	var tw = root.create_tween()
	tw.tween_property(shell, "global_position", to, flight)
	tw.tween_callback(_impact.bind(root, to))
	tw.tween_callback(shell.queue_free)


func _impact(root, at):
	CombatFX.explosion(self, at, 0.7)
	return
	SoundEffects.play("shell_impact", at)
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 8.0
	light.omni_range = 9.0
	root.add_child(light)
	light.global_position = at
	_spawn_smoke(root, at, Color(1.0, 0.6, 0.2, 1.0), 26, 0.45, 6.0, 0.45)  # Feuerball
	_spawn_smoke(root, at, Color(0.18, 0.16, 0.14, 0.7), 18, 1.6, 2.5, 0.7)  # Rauch
	_spawn_smoke(root, at, Color(0.35, 0.25, 0.15, 1.0), 16, 1.2, 12.0, 0.12)  # Erdbrocken
	var tw = root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	tw.tween_callback(light.queue_free)


static var _dot_texture = null


## Weicher, runder Partikel statt eckiger Quadrate
static func _soft_dot():
	if _dot_texture == null:
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_dot_texture = t
	return _dot_texture


func _spawn_smoke(root, at, color, amount, lifetime, velocity = 3.0, size = 0.6):
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = velocity * 0.5
	p.initial_velocity_max = velocity
	p.gravity = Vector3(0, -6.0 if size < 0.2 else 0.6, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	p.mesh = q
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	p.material_override = m
	var g = Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	var t = root.get_tree().create_timer(lifetime + 0.2)
	t.timeout.connect(p.queue_free)
