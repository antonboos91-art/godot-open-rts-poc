## Maßstabs-Referenz: stellt alle Shiba-Einheiten und -Gebäude nebeneinander und speichert Screenshots.
##   godot4 --path . -s tools/scale_shot.gd -- <ausgabe-ordner>
extends SceneTree

const MAP_PATH = "res://source/match/maps/PlainAndSimple.tscn"
const UNITS = ["trooper", "zapper", "schnueffler", "ingenieur", "buggy", "tesla", "raketen", "sammler", "baumobil", "wespe", "gewitter"]
const BUILDINGS = ["hq", "power", "power_big", "barracks", "factory", "refinery", "silo", "radar", "lab", "repair", "airfield", "turret_ground", "turret_air", "superweapon"]
var Factions = null
var Constants = null
var MatchSignals = null
var _out = "."


func _initialize():
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run()


func _run():
	await process_frame
	Factions = load("res://source/match/factions/Factions.gd")
	Constants = root.get_node("/root/Constants")
	MatchSignals = root.get_node("/root/MatchSignals")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	settings.visibility = settings.Visibility.FULL
	for i in range(2):
		var ps = load("res://source/data-model/PlayerSettings.gd").new()
		ps.controller = Constants.PlayerType.HUMAN if i == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		ps.faction = Factions.SHIBAS
		ps.color = Constants.Player.COLORS[i]
		settings.players.append(ps)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = MAP_PATH
	root.add_child(loading)
	var waited = 0.0
	while root.get_node_or_null("Match") == null or not root.get_node("Match").is_node_ready():
		await process_frame
		waited += 0.016
		if waited > 30.0:
			print("SHOT match did not start")
			quit(1)
			return
	var match_node = root.get_node("Match")
	await _frames(30)
	var me = get_nodes_in_group("players")[0]
	var origin = Vector3(24, 0, 24)
	var x = 0.0
	for v in UNITS:
		_spawn(me, "shibas/" + v, origin + Vector3(x, 0, 0))
		x += 2.5
	x = 0.0
	for v in BUILDINGS:
		var b = _spawn(me, "shibas/" + v, origin + Vector3(x - 4, 0, 8))
		if b != null and b.has_method("construct"):
			b.construct(1.0)
		x += 6.0
	await _frames(20)
	var cam = match_node.find_child("IsometricCamera3D", true, false)
	if cam != null:
		cam.set_size_safely(34.0)
		cam.set_position_safely(origin + Vector3(17, 0, 5))
	await _frames(40)
	_shot("wide")
	if cam != null:
		cam.set_size_safely(9.0)
		cam.set_position_safely(origin + Vector3(8, 0, 2))
	await _frames(20)
	_shot("close")
	quit(0)


func _spawn(player, variant, position):
	var e = Factions.entry(variant)
	if e.is_empty():
		print("SHOT unknown variant ", variant)
		return null
	var unit = load(e["archetype"]).instantiate()
	unit.variant = variant
	MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), position), player)
	return unit


func _shot(tag):
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/scale_" + tag + ".png")


func _frames(n):
	for i in n:
		await process_frame
