## Rendert die animierten Shiba-Sprites in ein Bild (mit Fenster, nicht headless):
##   godot4 --path . -s tools/sprite_preview.gd -- out.png
extends SceneTree

var PixelSprite = null
var _t = 0.0
var _out = "sprite_preview.png"


class FakeUnit:
	extends Node3D
	var variant = ""
	var type = "Infantry"
	var color = Color(0.2, 0.6, 1.0)


func _initialize():
	PixelSprite = load("res://source/match/units/traits/PixelSprite.gd")
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var root3d = Node3D.new()
	get_root().add_child(root3d)
	var cam = Camera3D.new()
	root3d.add_child(cam)
	cam.position = Vector3(0, 34, 30)
	cam.rotation_degrees = Vector3(-50, 0, 0)
	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.3, 0.2)
	floor_mesh.material_override = mat
	root3d.add_child(floor_mesh)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	root3d.add_child(light)
	var items = [
		["shibas/trooper", "Infantry"], ["shibas/zapper", "Infantry"], ["shibas/ingenieur", "Infantry"],
		["shibas/tesla", "Tank"], ["shibas/raketen", "Tank"], ["shibas/buggy", "Tank"],
		["shibas/wespe", "Helicopter"], ["shibas/sammler", "Worker"],
		["shibas/hq", "CommandCenter"], ["shibas/barracks", "Barracks"], ["shibas/factory", "VehicleFactory"],
		["shibas/power", "PowerPlant"], ["shibas/refinery", "Refinery"], ["shibas/airfield", "AircraftFactory"],
		["shibas/turret_ground", "AntiGroundTurret"],
		["shibas/silo", "Facility"], ["shibas/radar", "Facility"], ["shibas/repair", "Facility"],
		["shibas/lab", "Facility"], ["shibas/superweapon", "Facility"],
		["shibas/schnueffler", "Infantry"], ["shibas/turret_air", "AntiAirTurret"],
		["shibas/power_big", "PowerPlant"], ["shibas/gewitter", "Helicopter"], ["shibas/baumobil", "Tank"],
	]
	var i = 0
	for it in items:
		var u = FakeUnit.new()
		u.variant = it[0]
		u.type = it[1]
		root3d.add_child(u)
		u.position = Vector3(-22 + (i % 6) * 9, 0, -14 + (i / 6) * 9)
		PixelSprite.try_attach(u)
		var s = u.get_node_or_null("PixelSprite")
		if s != null:
			s._clip = 0
			s._clip_time = 0.3 + (i % 3) * 0.25
		i += 1


func _process(delta):
	_t += delta
	if _t > 1.2:
		get_root().get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false
