## Ersetzt das 3D-Modell einer Einheit durch ein Pixel-Art-Sprite mit 8 Blickrichtungen.
## Die Spritesheets erzeugt tools/make_sprites.py (assets/sprites/units/<Typ>.png).
extends MeshInstance3D

const SHADER = preload("res://source/shaders/3d/pixel_sprite.gdshader")
const SPRITE_DIR = "res://assets/sprites/units/"
const DIRECTIONS = 8
const WORLD_UNITS_PER_PIXEL = 0.055
## Zeile im Sprite (von oben), die auf dem Einheiten-Ursprung steht
const BASELINES = {
	"Worker": 22,
	"Tank": 22,
	"Drone": 20,
	"Helicopter": 20,
	"CommandCenter": 46,
	"VehicleFactory": 44,
	"AircraftFactory": 44,
	"AntiGroundTurret": 22,
	"AntiAirTurret": 22,
}

var _unit = null
var _material = null


static func try_attach(unit):
	var path = SPRITE_DIR + unit.type + ".png"
	if not ResourceLoader.exists(path):
		return null
	var sprite = new()
	sprite.name = "PixelSprite"
	sprite.setup(unit, load(path))
	unit.add_child(sprite)
	var geometry = unit.find_child("Geometry", false, false)
	if geometry != null:
		geometry.visible = false
	return sprite


func setup(unit, texture):
	_unit = unit
	var frame_size = texture.get_height()
	var world_size = frame_size * WORLD_UNITS_PER_PIXEL
	var baseline = BASELINES.get(unit.type, int(frame_size * 0.69))
	var quad = QuadMesh.new()
	quad.size = Vector2(world_size, world_size)
	quad.center_offset = Vector3(0, (baseline - frame_size / 2.0) * WORLD_UNITS_PER_PIXEL, 0)
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("sheet", texture)
	_material.set_shader_parameter("frames", texture.get_width() / frame_size)
	_material.set_shader_parameter("team_color", unit.color)
	material_override = _material


func _process(_delta):
	if _unit == null:
		return
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var unit_forward = -_unit.global_transform.basis.z
	var camera_forward = -camera.global_transform.basis.z
	var relative_angle = wrapf(
		atan2(camera_forward.x, camera_forward.z) - atan2(unit_forward.x, unit_forward.z), 0.0, TAU
	)
	var direction = int(round(relative_angle / (TAU / DIRECTIONS))) % DIRECTIONS
	_material.set_shader_parameter("frame", direction)
	var progress = _unit.get("_construction_progress")
	_material.set_shader_parameter("construction", 1.0 if progress == null else progress)
