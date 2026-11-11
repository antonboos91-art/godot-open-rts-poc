@tool
extends Node3D

# TODO: add editor-only 2nd pass shader to 'Terrain' mesh highlighting map boundries

const EXTRA_MARGIN = 14
const NatureScatter = preload("res://source/match/NatureScatter.gd")

@export var size = Vector2(50, 50):
	set(a_size):
		size = a_size
		var terrain = find_child("Terrain")
		terrain.mesh.size = size + Vector2(EXTRA_MARGIN, EXTRA_MARGIN) * 2
		terrain.mesh.center_offset = Vector3(size.x, 0.0, size.y) / 2.0
		# Eigene Materialkopie je Karte, damit map_size nicht zwischen Karten geteilt wird
		if terrain.mesh.material is ShaderMaterial:
			if not terrain.mesh.material.has_meta("per_map"):
				terrain.mesh.material = terrain.mesh.material.duplicate()
				terrain.mesh.material.set_meta("per_map", true)
			terrain.mesh.material.set_shader_parameter("map_size", size)


func _ready():
	if not Engine.is_editor_hint():
		NatureScatter.populate(self)
		_add_atmosphere()


## Ziehender Nebel (zwei Schichten) und vom Wind getragene Asche ueber der ganzen Karte.
func _add_atmosphere():
	if DisplayServer.get_name() == "headless":
		return
	var mist_shader = load("res://source/shaders/3d/mist.gdshader")
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var noise_tex = NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise
	for layer in [[0.55, 0.26, 0.012], [3.2, 0.12, 0.008]]:
		var mist = MeshInstance3D.new()
		mist.name = "Mist"
		var plane = PlaneMesh.new()
		plane.size = size + Vector2(60, 60)
		plane.center_offset = Vector3(size.x / 2.0, 0, size.y / 2.0)
		mist.mesh = plane
		var m = ShaderMaterial.new()
		m.shader = mist_shader
		m.set_shader_parameter("density", layer[1])
		m.set_shader_parameter("scale", layer[2])
		m.set_shader_parameter("noise_tex", noise_tex)
		mist.material_override = m
		mist.position.y = layer[0]
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mist)
	var ash = CPUParticles3D.new()
	ash.name = "Ash"
	ash.amount = int(clamp(size.x * size.y / 12.0, 300, 2400))
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.local_coords = false
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(size.x / 2.0 + 10, 3.0, size.y / 2.0 + 10)
	ash.position = Vector3(size.x / 2.0, 3.5, size.y / 2.0)
	ash.direction = Vector3(0.9, -0.15, 0.35)
	ash.spread = 20.0
	ash.initial_velocity_min = 0.6
	ash.initial_velocity_max = 1.6
	ash.gravity = Vector3(0.25, -0.12, 0.1)
	ash.scale_amount_min = 0.5
	ash.scale_amount_max = 1.0
	var q = QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	ash.mesh = q
	var am = StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	am.albedo_color = Color(0.5, 0.48, 0.46, 0.35)
	am.albedo_texture = load("res://source/match/units/traits/CombatFX.gd").soft_dot()
	ash.material_override = am
	ash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ash)


func get_topdown_polygon_2d():
	return [Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]
