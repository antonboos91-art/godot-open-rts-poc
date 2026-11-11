extends Area3D

const ResourceDecayAnimation = preload("res://source/match/utils/ResourceDecayAnimation.tscn")
const CRYSTAL_SHADER = preload("res://source/shaders/3d/crystal.gdshader")

var radius:
	get:
		return get_node_or_null("MovementObstacle").radius
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)


## Siehe Player.add_synchronizer()
func add_synchronizer():
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "ResourceSynchronizer"
	synchronizer.replication_config = Utils.Net.replication_config(
		[":resource_a"] if "resource_a" in self else [":resource_b"]
	)
	add_child(synchronizer)


func _enter_tree():
	tree_exiting.connect(_animate_decay)


func _animate_decay():
	var decay_animation = ResourceDecayAnimation.instantiate()
	decay_animation.global_transform = global_transform
	get_parent().add_child.call_deferred(decay_animation)


## Ersetzt das Platzhalter-Modell durch ein gruen leuchtendes Kristallfeld (3D-Kristalle mit
## Leucht-Shader, gruenes Licht auf den Boden, aufsteigende Funken). Kristall (B) ist groesser und heller.
func _add_ore_sprite(sprite_name):
	var geometry = find_child("Geometry", false, false)
	if geometry != null:
		geometry.visible = false
	var big = sprite_name.ends_with("b")
	var rng = RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 73.0 + global_position.z * 191.0) + (7 if big else 0)
	var color = Color(0.3, 1.0, 0.55) if big else Color(0.35, 1.0, 0.3)
	var mat = ShaderMaterial.new()
	mat.shader = CRYSTAL_SHADER
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("glow", 2.8 if big else 2.0)
	mat.set_shader_parameter("phase", rng.randf() * TAU)
	var cluster = Node3D.new()
	cluster.name = "Crystals"
	add_child(cluster)
	var shards = 9 if big else 7
	for i in shards:
		var shard = MeshInstance3D.new()
		var m = CylinderMesh.new()
		var h = rng.randf_range(0.7, 1.9) * (1.25 if big else 1.0)
		m.top_radius = 0.0
		m.bottom_radius = rng.randf_range(0.14, 0.26) * (1.2 if big else 1.0)
		m.height = h
		m.radial_segments = 6
		m.rings = 1
		shard.mesh = m
		shard.material_override = mat
		var ang = rng.randf() * TAU
		var dist = 0.0 if i == 0 else rng.randf_range(0.15, 0.6)
		shard.position = Vector3(cos(ang) * dist, h * 0.42, sin(ang) * dist)
		shard.rotation = Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45)) * (0.3 if i == 0 else 1.0)
		cluster.add_child(shard)
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.2 if big else 1.6
	light.omni_range = 4.5 if big else 3.5
	light.position = Vector3(0, 0.9, 0)
	light.shadow_enabled = false
	cluster.add_child(light)
	var sparks = CPUParticles3D.new()
	sparks.amount = 10
	sparks.lifetime = 2.5
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.6
	sparks.direction = Vector3.UP
	sparks.spread = 20.0
	sparks.initial_velocity_min = 0.2
	sparks.initial_velocity_max = 0.6
	sparks.gravity = Vector3(0, 0.15, 0)
	var q = QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	sparks.mesh = q
	var sm = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.8)
	sm.albedo_texture = load("res://source/match/units/traits/CombatFX.gd").soft_dot()
	sparks.material_override = sm
	sparks.position = Vector3(0, 0.6, 0)
	cluster.add_child(sparks)
