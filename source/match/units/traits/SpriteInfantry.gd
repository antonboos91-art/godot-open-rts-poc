## Infanterie aus vorgerenderten 3D-Sprites (Assets-Pipeline/blender/rig_trooper.py):
## assets/sprites/infantry/<volk>_<variante>.png   Zeilen = Blickrichtungen, Spalten = Frames aller Clips
## assets/sprites/infantry/<volk>_<variante>.json  {"dirs", "frame", "columns", "clips": {name: [start, n]}, ...}
## Clips: idle, walk (Schleife), shoot (beim Feuern), die (Leiche bleibt kurz liegen).
extends Node3D

const SHADER = preload("res://source/shaders/3d/vehicle_sprite.gdshader")
const DIR = "res://assets/sprites/infantry/"
const WALK_FPS = 11.0
const SHOOT_FPS = 14.0
const DIE_FPS = 9.0
const CORPSE_SECONDS = 8.0
## Bildhoehe der Figur im Spiel (Weltmeter, Kopf bis Fuss)
const FIGURE_HEIGHT = 1.9

var _unit = null
var _meta = {}
var _mat = null
var _quad = null
var _size = 3.0
var _last_position = Vector3.ZERO
var _move_dir = Vector3.FORWARD
var _walk_time = 0.0
var _shoot_time = -1.0
var _aim_target = null
var _moving_for = 0.0


static func sheet_base_for(variant):
	if variant == "":
		return ""
	var base = DIR + variant.replace("/", "_")
	return base if ResourceLoader.exists(base + ".png") and FileAccess.file_exists(base + ".json") else ""


static func try_attach(unit):
	var base = sheet_base_for(unit.variant)
	if base == "":
		return null
	var sprite = load("res://source/match/units/traits/SpriteInfantry.gd").new()
	sprite.name = "SpriteInfantry"
	sprite._setup(unit, base)
	unit.add_child(sprite)
	var geometry = unit.find_child("Geometry", false, false)
	if geometry != null:
		geometry.visible = false
	return sprite


func _setup(unit, base):
	_unit = unit
	var f = FileAccess.open(base + ".json", FileAccess.READ)
	_meta = JSON.parse_string(f.get_as_text())
	# Figur ist im Render 1.8 m hoch, Bild zeigt ortho Meter -> auf FIGURE_HEIGHT skalieren
	var ortho = float(_meta.get("ortho", 3.3))
	_size = ortho * FIGURE_HEIGHT / 1.8
	var target_z = float(_meta.get("target_z", 0.85)) * FIGURE_HEIGHT / 1.8
	_quad = MeshInstance3D.new()
	_quad.name = "Body"
	var q = QuadMesh.new()
	q.size = Vector2(_size, _size)
	_quad.mesh = q
	# Bildmitte zeigt den Punkt target_z ueber den Fuessen
	_quad.position.y = target_z
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("sheet", load(base + ".png"))
	_mat.set_shader_parameter("columns", int(_meta["columns"]))
	_mat.set_shader_parameter("rows", int(_meta["dirs"]))
	_mat.set_shader_parameter("depth_bias", 2.0)
	_mat.set_shader_parameter("brightness", 1.05)
	_quad.material_override = _mat
	add_child(_quad)
	_add_team_ring()
	unit.child_entered_tree.connect(_on_unit_child_entered)
	if unit.has_signal("hp_changed"):
		unit.hp_changed.connect(_on_hp_changed)
	_last_position = unit.global_position


func _add_team_ring():
	var ring = MeshInstance3D.new()
	ring.name = "TeamRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position.y = 0.03
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _unit.color
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


## Zeile (Richtung) fuer eine Welt-Blickrichtung relativ zur Kamera.
## Render-Konvention: Richtung 0 = Figur schaut zur Kamera, weitere Richtungen = Kamera dreht im Uhrzeigersinn.
func _row_for(world_dir):
	var camera = get_viewport().get_camera_3d()
	if camera == null or world_dir.length() < 0.001:
		return 0
	var to_cam = camera.global_transform.basis.z
	to_cam.y = 0.0
	var a_face = atan2(world_dir.x, world_dir.z)
	var a_cam = atan2(to_cam.x, to_cam.z)
	var rel = wrapf(a_cam - a_face, 0.0, TAU)
	var dirs = int(_meta["dirs"])
	return int(round(rel / TAU * dirs)) % dirs


func _clip_column(clip_name, frame_index):
	var clip = _meta["clips"].get(clip_name, _meta["clips"]["idle"])
	return int(clip[0]) + clamp(frame_index, 0, int(clip[1]) - 1)


func _process(delta):
	if _unit == null or delta <= 0.0:
		return
	var pos = _unit.global_position
	var step = pos - _last_position
	step.y = 0.0
	_last_position = pos
	var moving = step.length() > 0.002 and step.length() < 3.0
	if moving:
		_move_dir = step.normalized()
		_moving_for = 0.15
	else:
		_moving_for = max(0.0, _moving_for - delta)
	var facing = _move_dir
	var column = _clip_column("idle", 0)
	if _shoot_time >= 0.0:
		_shoot_time += delta
		var shoot_frames = int(_meta["clips"]["shoot"][1])
		var i = int(_shoot_time * SHOOT_FPS)
		if i >= shoot_frames:
			_shoot_time = -1.0
		else:
			column = _clip_column("shoot", i)
		if is_instance_valid(_aim_target):
			var to_t = _aim_target.global_position - pos
			to_t.y = 0.0
			if to_t.length() > 0.01:
				facing = to_t.normalized()
				_move_dir = facing
	if _shoot_time < 0.0 and _moving_for > 0.0:
		_walk_time += delta
		var walk_frames = int(_meta["clips"]["walk"][1])
		column = _clip_column("walk", int(_walk_time * WALK_FPS) % walk_frames)
	_mat.set_shader_parameter("row", _row_for(facing))
	_mat.set_shader_parameter("column", column)


func _on_unit_child_entered(node):
	var target = node.get("target_unit")
	if target == null or not is_instance_valid(target):
		return
	_aim_target = target
	_shoot_time = 0.0


## Beim Tod: Leiche als eigener Knoten, spielt den Sterbe-Clip und bleibt kurz liegen.
func _on_hp_changed():
	if _unit.hp == null or _unit.hp > 0:
		return
	var world = _unit.find_parent("Match")
	if world == null or not is_inside_tree():
		return
	var corpse = Node3D.new()
	corpse.name = "Corpse"
	world.add_child(corpse)
	corpse.global_position = _unit.global_position
	var body = MeshInstance3D.new()
	body.mesh = _quad.mesh
	body.position = _quad.position
	var mat = _mat.duplicate()
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corpse.add_child(body)
	var start = int(_meta["clips"]["die"][0])
	var frames = int(_meta["clips"]["die"][1])
	var tween = corpse.create_tween()
	tween.tween_method(
		func(v): mat.set_shader_parameter("column", start + int(v)), 0.0, float(frames - 1), frames / DIE_FPS
	)
	tween.tween_interval(CORPSE_SECONDS)
	tween.tween_callback(corpse.queue_free)
