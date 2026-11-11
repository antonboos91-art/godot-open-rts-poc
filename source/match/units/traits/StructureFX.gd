## Rein optische Effekte fuer Gebaeude: Baustaub, Fertigstellungs-Funken, Rauch und Feuer bei
## Schaden, Explosion mit Brandfleck bei der Zerstoerung. Wird von PixelSprite angehaengt.
extends Node3D

const SMOKE_BELOW = 0.6
const FIRE_BELOW = 0.3

static var _soft_texture = null

var _unit = null
var _radius = 2.0
var _dust = null
var _smoke = null
var _fire = null
var _exploded = false


static func attach(unit, radius):
	var fx = load("res://source/match/units/traits/StructureFX.gd").new()
	fx.name = "StructureFX"
	fx._unit = unit
	fx._radius = radius
	unit.add_child(fx)
	return fx


func _ready():
	_dust = _make_emitter(Color(0.62, 0.52, 0.38, 0.55), Color(0.62, 0.52, 0.38, 0.0), 1.6, 0.9, 0.5, 0.9, 1.4, 0.5, Vector3(0, 0.25, 0))
	_smoke = _make_emitter(Color(0.3, 0.3, 0.3, 0.45), Color(0.45, 0.45, 0.45, 0.0), 2.6, 1.0, 0.7, 1.4, 1.8, 0.7, Vector3(0, 1.0, 0))
	_fire = _make_emitter(Color(1.0, 0.65, 0.15, 0.95), Color(0.9, 0.15, 0.05, 0.0), 0.7, 0.8, 0.5, 1.0, 1.0, 0.25, Vector3(0, 1.6, 0))
	_fire.mesh.material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_smoke.position.y = 1.2
	_fire.position.y = 0.8
	if _unit.has_signal("hp_changed"):
		_unit.hp_changed.connect(_on_hp_changed)
	if _unit.has_signal("constructed"):
		_unit.constructed.connect(_on_constructed)
	_on_hp_changed()


func _process(_delta):
	var under_construction = (
		_unit.has_method("is_under_construction") and _unit.is_under_construction()
	)
	_dust.emitting = under_construction


func _on_constructed():
	var burst = _make_emitter(Color(0.6, 0.9, 1.0, 0.9), Color(0.2, 0.6, 1.0, 0.0), 0.9, 0.5, 0.3, 0.6, 2.5, 0.2, Vector3(0, 0.2, 0))
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 28
	burst.mesh.material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	burst.emitting = true
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)


func _on_hp_changed():
	if _unit.hp == null or _unit.hp_max == null or _unit.hp_max <= 0:
		return
	if _unit.hp == 0 and not _exploded:
		_exploded = true
		_spawn_destruction()
		return
	if _unit.has_method("is_under_construction") and _unit.is_under_construction():
		_smoke.emitting = false
		_fire.emitting = false
		return
	var ratio = float(_unit.hp) / float(_unit.hp_max)
	_smoke.emitting = ratio < SMOKE_BELOW
	_smoke.amount = 10 if ratio >= FIRE_BELOW else 22
	_fire.emitting = ratio < FIRE_BELOW


func _spawn_destruction():
	var world = _unit.find_parent("Match")
	if world == null or not is_inside_tree():
		return
	var spot = Node3D.new()
	spot.name = "Ruins"
	world.add_child(spot)
	spot.global_position = _unit.global_position
	# Brandfleck am Boden
	var scorch = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(_radius * 2.4, _radius * 2.4)
	quad.orientation = PlaneMesh.FACE_Y
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _soft()
	material.albedo_color = Color(0.03, 0.02, 0.02, 0.85)
	scorch.mesh = quad
	scorch.material_override = material
	scorch.position.y = 0.04
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spot.add_child(scorch)
	# Explosion
	var boom = _make_emitter(Color(1.0, 0.8, 0.3, 1.0), Color(0.9, 0.2, 0.05, 0.0), 0.9, 1.0, 0.6, 1.2, 4.0, 0.9, Vector3(0, 0.4, 0), spot)
	boom.one_shot = true
	boom.explosiveness = 1.0
	boom.amount = 48
	boom.mesh.material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	boom.emitting = true
	var smoke = _make_emitter(Color(0.1, 0.1, 0.1, 0.8), Color(0.3, 0.3, 0.3, 0.0), 3.5, 1.4, 0.8, 1.6, 1.4, 1.2, Vector3(0, 1.0, 0), spot)
	smoke.amount = 20
	smoke.emitting = true
	var fire = _make_emitter(Color(1.0, 0.6, 0.15, 0.9), Color(0.9, 0.15, 0.05, 0.0), 0.8, 0.8, 0.5, 1.0, 0.8, 0.3, Vector3(0, 1.6, 0), spot)
	fire.mesh.material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire.amount = 14
	fire.emitting = true
	var timer = _unit.get_tree().create_timer(7.0)
	timer.timeout.connect(
		func():
			if is_instance_valid(smoke):
				smoke.emitting = false
			if is_instance_valid(fire):
				fire.emitting = false
	)
	# Brandfleck bleibt, Rest verschwindet
	var cleanup = _unit.get_tree().create_timer(30.0)
	cleanup.timeout.connect(func(): if is_instance_valid(spot): spot.queue_free())


func _make_emitter(c_start, c_end, lifetime, size_min, size_max, speed_min, speed_max, spread_radius, gravity, parent = null):
	var p = CPUParticles3D.new()
	p.amount = 12
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = gravity
	p.initial_velocity_min = speed_min * 0.5
	p.initial_velocity_max = speed_max
	p.scale_amount_min = size_min * 2.0
	p.scale_amount_max = size_max * 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = _radius * spread_radius
	var ramp = Gradient.new()
	ramp.set_color(0, c_start)
	ramp.set_color(1, c_end)
	p.color_ramp = ramp
	var quad = QuadMesh.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft()
	material.no_depth_test = true
	material.render_priority = 5
	quad.material = material
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(p)
	return p


static func _soft():
	if _soft_texture == null:
		var gradient = Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_soft_texture = texture
	return _soft_texture
