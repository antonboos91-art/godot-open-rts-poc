## Ersetzt das 3D-Modell einer Einheit durch ein Pixel-Art-Sprite mit 8 Blickrichtungen.
## Die Spritesheets erzeugt tools/make_sprites.py (assets/sprites/units/<Typ>.png bzw.
## <volk>_<variante>.png für eigene Sprites einer Volks-Variante).
extends MeshInstance3D

const Factions = preload("res://source/match/factions/Factions.gd")
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
	"Infantry": 24,
	"Barracks": 44,
	"PowerPlant": 44,
	"Refinery": 44,
	"Facility": 44,
}

var _unit = null
var _material = null


## Sprite der Volks-Variante (z. B. shibas_tesla.png), sonst das des Archetyps.
static func sprite_path_for(variant, type):
	if variant != "":
		var variant_path = SPRITE_DIR + variant.replace("/", "_") + ".png"
		if ResourceLoader.exists(variant_path):
			return variant_path
	var type_path = SPRITE_DIR + type + ".png"
	return type_path if ResourceLoader.exists(type_path) else ""


## Ein Bild (schräge Ansicht) einer Variante als Icon für Menüs, Magenta in Teamfarbe.
static func icon_for(variant, team_color = Color(0.85, 0.85, 0.85)):
	var e = Factions.entry(variant)
	if e.is_empty():
		return null
	var type = e["archetype"].get_file().get_basename()
	var path = sprite_path_for(variant, type)
	if path == "":
		return null
	var sheet = load(path).get_image()
	if sheet.is_compressed():
		sheet.decompress()
	var size = sheet.get_height()
	var image = sheet.get_region(Rect2i(size, 0, size, size))
	image.convert(Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var pixel = image.get_pixel(x, y)
			if pixel.a > 0.0 and is_equal_approx(pixel.r, pixel.b) and pixel.g == 0.0:
				var tinted = team_color * pixel.r
				tinted.a = pixel.a
				image.set_pixel(x, y, tinted)
	# Auf den sichtbaren Inhalt zuschneiden, damit kleine Sprites (Infanterie) groß wirken
	var used = image.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		var side = max(used.size.x, used.size.y)
		var square = Image.create(side, side, false, Image.FORMAT_RGBA8)
		square.blit_rect(image, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
		image = square
	return ImageTexture.create_from_image(image)


static func try_attach(unit):
	var path = sprite_path_for(unit.variant, unit.type)
	if path == "":
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
