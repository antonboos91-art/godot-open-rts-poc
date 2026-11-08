## Ersetzt das 3D-Modell einer Einheit durch ein Pixel-Art-Sprite mit 8 Blickrichtungen.
## Die Spritesheets erzeugt tools/make_sprites.py (assets/sprites/units/<Typ>.png bzw.
## <volk>_<variante>.png für eigene Sprites einer Volks-Variante).
extends MeshInstance3D

const Factions = preload("res://source/match/factions/Factions.gd")
const SHADER = preload("res://source/shaders/3d/pixel_sprite.gdshader")
const ANIM_SHADER = preload("res://source/shaders/3d/sprite_anim.gdshader")
## Animations-Sprites: <variante>_anim.png = ANIM_CLIPS Clips mit je ANIM_FRAMES Frames (Quadrate)
const ANIM_CLIPS = 2
const ANIM_FRAMES = 16
const ANIM_FPS = 14.0
## Weltgroesse (Kantenlaenge des Quads) der Animations-/HD-Sprites je Einheitentyp
const ANIM_WORLD_SIZES = {
	"Infantry": 2.4,
	"Worker": 3.2,
	"Tank": 4.2,
	"Helicopter": 4.6,
	"Drone": 4.0,
	"CommandCenter": 9.0,
	"VehicleFactory": 7.5,
	"AircraftFactory": 7.5,
	"AntiGroundTurret": 3.8,
	"AntiAirTurret": 3.8,
	"Barracks": 6.5,
	"PowerPlant": 6.5,
	"Refinery": 7.0,
	"Facility": 6.5,
}
## Gebaeude-Sprites sind kleiner als die Rohgroesse, damit sie zum Einheiten-Massstab passen
const BUILDING_SCALE = 0.68
const ANIM_BUILDING_TYPES = [
	"CommandCenter",
	"VehicleFactory",
	"AircraftFactory",
	"AntiGroundTurret",
	"AntiAirTurret",
	"Barracks",
	"PowerPlant",
	"Refinery",
	"Facility",
]
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
var _animated = false
var _anim_frames = 1
var _clip = -1
var _clip_time = 0.0
var _idle_wait = 3.0
var _last_position = Vector3.ZERO
var _flip = false


## Echtes 3D-Modell einer Volks-Variante (assets/models/factions/<volk>_<variante>.glb)
const MODEL_DIR = "res://assets/models/factions/"


static func model_path_for(variant):
	if variant == "":
		return ""
	var path = MODEL_DIR + variant.replace("/", "_") + ".glb"
	return path if ResourceLoader.exists(path) else ""


## Setzt das 3D-Modell statt des Original-Meshes ein, mit Teamfarben-Ring bei Einheiten.
static func _attach_model(unit, path):
	var model = load(path).instantiate()
	model.name = "FactionModel"
	unit.add_child(model)
	load("res://source/match/units/traits/TankVisual.gd").brighten(model)
	var geometry = unit.find_child("Geometry", false, false)
	if geometry != null:
		geometry.visible = false
	if not unit.type in ANIM_BUILDING_TYPES:
		var ring = MeshInstance3D.new()
		ring.name = "TeamRing"
		var torus = TorusMesh.new()
		var radius = ANIM_WORLD_SIZES.get(unit.type, 4.0) * 0.32
		torus.inner_radius = radius * 0.86
		torus.outer_radius = radius
		torus.rings = 24
		torus.ring_segments = 4
		ring.mesh = torus
		ring.scale = Vector3(1.0, 0.05, 1.0)
		ring.position.y = 0.03
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = unit.color
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		unit.add_child(ring)
	return model


static func anim_path_for(variant):
	if variant == "":
		return ""
	var path = SPRITE_DIR + variant.replace("/", "_") + "_anim.png"
	return path if ResourceLoader.exists(path) else ""


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
	var anim_path = anim_path_for(variant)
	if anim_path != "":
		var anim_sheet = load(anim_path).get_image()
		if anim_sheet.is_compressed():
			anim_sheet.decompress()
		var side = anim_sheet.get_height()
		var first = anim_sheet.get_region(Rect2i(0, 0, side, side))
		first.convert(Image.FORMAT_RGBA8)
		var used_rect = first.get_used_rect()
		if used_rect.size.x > 0 and used_rect.size.y > 0:
			var edge = max(used_rect.size.x, used_rect.size.y)
			var squared = Image.create(edge, edge, false, Image.FORMAT_RGBA8)
			squared.blit_rect(
				first,
				used_rect,
				Vector2i((edge - used_rect.size.x) / 2, (edge - used_rect.size.y) / 2)
			)
			first = squared
		return ImageTexture.create_from_image(first)
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
	var infantry = load("res://source/match/units/traits/SpriteInfantry.gd").try_attach(unit)
	if infantry != null:
		return infantry
	var vehicle = load("res://source/match/units/traits/SpriteVehicle.gd").try_attach(unit)
	if vehicle != null:
		return vehicle
	var tank = load("res://source/match/units/traits/TankVisual.gd").try_attach(unit)
	if tank != null:
		return tank
	var model_path = model_path_for(unit.variant)
	if model_path != "":
		return _attach_model(unit, model_path)
	var anim_path = anim_path_for(unit.variant)
	if anim_path != "":
		var anim_sprite = new()
		anim_sprite.name = "PixelSprite"
		anim_sprite.setup_animated(unit, load(anim_path))
		unit.add_child(anim_sprite)
		var geo = unit.find_child("Geometry", false, false)
		if geo != null:
			geo.visible = false
		return anim_sprite
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


func setup_animated(unit, texture):
	_unit = unit
	_animated = true
	var frame_size = texture.get_height()
	_anim_frames = texture.get_width() / frame_size
	var world_size = ANIM_WORLD_SIZES.get(unit.type, 4.0)
	if unit.type in ANIM_BUILDING_TYPES:
		world_size *= BUILDING_SCALE
	var is_building = unit.type in ANIM_BUILDING_TYPES
	if is_building:
		load("res://source/match/units/traits/StructureFX.gd").attach(unit, world_size * 0.28)
	var quad = QuadMesh.new()
	quad.size = Vector2(world_size, world_size)
	quad.center_offset = Vector3(0, world_size * (0.38 if is_building else 0.5), 0)
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = ANIM_SHADER
	_material.set_shader_parameter("sheet", texture)
	_material.set_shader_parameter("frames", texture.get_width() / frame_size)
	_material.set_shader_parameter("team_color", unit.color)
	_material.set_shader_parameter("ring", not is_building)
	material_override = _material
	_idle_wait = randf_range(1.0, 8.0)


func _process_animated(delta):
	var camera = get_viewport().get_camera_3d()
	var position_now = _unit.global_position
	var moved = position_now.distance_to(_last_position) > 0.001
	if moved and camera != null:
		var step = position_now - _last_position
		var right = camera.global_transform.basis.x
		if abs(step.dot(right)) > 0.0005:
			_flip = step.dot(right) < 0.0
		_clip = -1
		_idle_wait = randf_range(2.0, 6.0)
	_last_position = position_now
	var frame = 0
	if _anim_frames < ANIM_CLIPS * ANIM_FRAMES:
		pass  # statisches Sprite: kein Clip, nur Spiegeln beim Laufen
	elif _clip >= 0:
		_clip_time += delta
		var step_index = int(_clip_time * ANIM_FPS)
		if step_index >= ANIM_FRAMES:
			_clip = -1
			_idle_wait = randf_range(4.0, 12.0)
		else:
			frame = _clip * ANIM_FRAMES + step_index
	elif not moved:
		_idle_wait -= delta
		if _idle_wait <= 0.0:
			_clip = randi() % ANIM_CLIPS
			_clip_time = 0.0
	_material.set_shader_parameter("frame", frame)
	_material.set_shader_parameter("flip", _flip)
	var progress = _unit.get("_construction_progress")
	_material.set_shader_parameter("construction", 1.0 if progress == null else progress)


func _process(delta):
	if _unit == null:
		return
	if _animated:
		_process_animated(delta)
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
