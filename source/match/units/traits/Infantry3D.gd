## 3D-Infanterist mit Skelett-Animation aus assets/models/infantry/<volk>_<variante>.glb.
## Enthält die 6 Clips: idle, walk, shoot, die, idle_a, idle_b.
## Dreht sich stufenlos in Lauf- bzw. Schussrichtung und wirft echte 3D-Schatten.
extends Node3D

const FIGURE_HEIGHT = 1.9
const MOVE_SPEED_THRESHOLD = 0.25
const SHOOT_HOLD = 0.45
const CORPSE_SECONDS = 8.0
const IDLE_SPECIAL_MIN = 4.0
const IDLE_SPECIAL_MAX = 9.0
const TURN_SPEED = 12.0
const ANIM_BLEND = 0.15

var _unit = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _last_pos := Vector3.ZERO
var _speed := 0.0
var _shoot_timer := 0.0
var _aim_target: Node3D = null
var _dying := false
var _yaw := 0.0
var _target_yaw := 0.0
var _idle_wait := 5.0
var _special_timer := 0.0
var _current_clip := ""


static func glb_for(variant: String) -> String:
	if variant == "":
		return ""
	var p = "res://assets/models/infantry/" + variant.replace("/", "_") + ".glb"
	return p if ResourceLoader.exists(p) else ""


static func try_attach(unit):
	var path = glb_for(unit.variant)
	if path == "":
		return null
	var v = new()
	v.name = "Infantry3D"
	unit.add_child(v)
	v._setup(unit, path)
	var geom = unit.find_child("Geometry", false, false)
	if geom != null:
		geom.visible = false
	return v


func _setup(unit, path: String):
	_unit = unit
	var scene = load(path)
	if scene == null:
		return
	_model = scene.instantiate()
	var s = FIGURE_HEIGHT / 1.85
	_model.scale = Vector3.ONE * s
	add_child(_model)
	_anim = _find_anim(_model)
	_configure_loops()
	_enable_shadows_and_brighten(_model, 0.45)
	_add_team_ring()
	_last_pos = unit.global_position
	var fwd = unit.global_transform.basis.z
	if fwd.length_squared() > 0.001:
		_yaw = atan2(fwd.x, fwd.z)
		_target_yaw = _yaw
	_model.global_rotation = Vector3(0.0, _yaw, 0.0)
	var h = abs(unit.get_instance_id()) % 997
	_idle_wait = IDLE_SPECIAL_MIN + fmod(h * 0.173, IDLE_SPECIAL_MAX - IDLE_SPECIAL_MIN)
	unit.child_entered_tree.connect(_on_child_entered)
	if unit.has_signal("hp_changed"):
		unit.hp_changed.connect(_on_hp_changed)
	_play("idle")


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f = _find_anim(c)
		if f != null:
			return f
	return null


func _configure_loops():
	if _anim == null:
		return
	for clip in ["idle", "walk"]:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


func _enable_shadows_and_brighten(n: Node, energy: float = 0.18):
	if DisplayServer.get_name() == "headless":
		return
	if n is MeshInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if n.mesh != null:
			for i in range(n.mesh.get_surface_count()):
				var mat = n.get_active_material(i)
				if mat is StandardMaterial3D:
					var m: StandardMaterial3D = mat.duplicate()
					m.metallic = min(m.metallic, 0.15)
					m.roughness = max(m.roughness, 0.65)
					if not m.emission_enabled:
						m.emission_enabled = true
						m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
						m.emission = Color.WHITE if m.albedo_texture != null else m.albedo_color
						m.emission_texture = m.albedo_texture
						m.emission_energy_multiplier = energy
					child_set_surface_mat(n, i, m)
	for c in n.get_children():
		_enable_shadows_and_brighten(c, energy)


func child_set_surface_mat(mesh_inst: MeshInstance3D, idx: int, mat: Material):
	mesh_inst.set_surface_override_material(idx, mat)


func _play(clip: String):
	if _anim == null or _current_clip == clip:
		return
	if not _anim.has_animation(clip):
		if _anim.has_animation("idle"):
			clip = "idle"
		else:
			return
	_current_clip = clip
	_anim.play(clip, ANIM_BLEND)


func _process(delta: float):
	if _unit == null or _dying or delta <= 0.0:
		return
	var pos: Vector3 = _unit.global_position
	var step: Vector3 = pos - _last_pos
	_last_pos = pos
	step.y = 0.0
	var inst_speed = step.length() / delta if step.length() < 5.0 else 0.0
	_speed = lerp(_speed, inst_speed, clamp(delta * 10.0, 0.0, 1.0))
	if step.length() > 0.002 and _shoot_timer <= 0.0:
		_target_yaw = atan2(step.x, step.z)
	if _shoot_timer > 0.0:
		_shoot_timer = max(0.0, _shoot_timer - delta)
		if _aim_target != null and is_instance_valid(_aim_target):
			var d: Vector3 = _aim_target.global_position - pos
			d.y = 0.0
			if d.length() > 0.01:
				_target_yaw = atan2(d.x, d.z)
	_yaw = lerp_angle(_yaw, _target_yaw, min(1.0, delta * TURN_SPEED))
	if _model != null and _model.is_inside_tree():
		_model.global_rotation = Vector3(0.0, _yaw, 0.0)

	var want := "idle"
	if _shoot_timer > 0.0:
		want = "shoot"
		_special_timer = 0.0
	elif _speed > MOVE_SPEED_THRESHOLD:
		want = "walk"
		_special_timer = 0.0
	else:
		if _special_timer > 0.0:
			_special_timer -= delta
			want = _current_clip
			if _special_timer <= 0.0:
				_idle_wait = randf_range(IDLE_SPECIAL_MIN, IDLE_SPECIAL_MAX)
				want = "idle"
		else:
			_idle_wait -= delta
			if _idle_wait <= 0.0:
				var choices := []
				for k in ["idle_a", "idle_b"]:
					if _anim != null and _anim.has_animation(k):
						choices.append(k)
				if choices.size() > 0:
					want = choices[randi() % choices.size()]
					_special_timer = _anim.get_animation(want).length
				else:
					_idle_wait = randf_range(IDLE_SPECIAL_MIN, IDLE_SPECIAL_MAX)
	if want == "shoot" and _current_clip == "shoot" and _anim != null and not _anim.is_playing():
		_anim.play("shoot", 0.05)
	else:
		_play(want)


func _on_child_entered(node: Node):
	var target = node.get("target_unit")
	if target == null or not is_instance_valid(target):
		return
	_aim_target = target
	_shoot_timer = SHOOT_HOLD
	_current_clip = ""


func _on_hp_changed():
	if _dying or _unit == null or _unit.hp == null or _unit.hp > 0:
		return
	_dying = true
	_spawn_corpse()


func _spawn_corpse():
	if _model == null or not is_inside_tree():
		return
	var match_node = _unit.find_parent("Match")
	if match_node == null:
		return
	var holder = Node3D.new()
	holder.name = "Corpse"
	match_node.add_child(holder)
	holder.global_position = _unit.global_position
	var saved_scale = _model.scale
	remove_child(_model)
	holder.add_child(_model)
	_model.scale = saved_scale
	_model.rotation = Vector3(0.0, _yaw, 0.0)
	if _anim != null and _anim.has_animation("die"):
		_anim.get_animation("die").loop_mode = Animation.LOOP_NONE
		_anim.play("die", 0.1)
	var tw = holder.create_tween()
	tw.tween_interval(CORPSE_SECONDS)
	tw.tween_callback(holder.queue_free)


func _add_team_ring():
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.76
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.04, 1.0)
	ring.position.y = 0.02
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = _unit.color
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
