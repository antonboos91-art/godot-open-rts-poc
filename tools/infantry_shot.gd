## Prueft Infanterie-Sprites: Laufen, Schiessen, Sterben (Screenshots).
##   godot4 --path . -s tools/infantry_shot.gd -- <ausgabe-ordner>
extends SceneTree

const MAP_PATH = "res://source/match/maps/PlainAndSimple.tscn"
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
			print("FX match did not start")
			quit(1)
			return
	var match_node = root.get_node("Match")
	await _frames(30)
	var players = get_nodes_in_group("players")
	var me = players[0]
	var enemy = players[1]
	var origin = Vector3(25, 0, 25)
	var walker = _spawn(me, "shibas/trooper", origin + Vector3(-3, 0, 0))
	var shooters = []
	for i in 3:
		shooters.append(_spawn(me, "shibas/trooper", origin + Vector3(-1 + i * 1.2, 0, 2)))
	var victim = _spawn(enemy, "shibas/trooper", origin + Vector3(1, 0, 6))
	var dummy = _spawn(enemy, "shibas/barracks", origin + Vector3(6, 0, 8))
	dummy.construct(1.0)
	await _frames(5)
	dummy.hp = dummy.hp_max
	print("INF sprite: ", walker.find_child("SpriteInfantry", false, false) != null)
	var cam = match_node.find_child("IsometricCamera3D", true, false)
	cam.set_size_safely(12.0)
	cam.set_position_safely(origin + Vector3(1, 0, 3))
	match_node.send_command("terrain", [walker], [origin + Vector3(-3, 0, 10)])
	match_node.send_command("unit", shooters, [match_node.get_path_to(dummy)])
	await _frames(40)
	await _shot("walk_shoot")
	victim.hp = 0
	await _frames(30)
	await _shot("death")
	await _frames(60)
	await _shot("later")
	print("INF corpses: ", match_node.find_children("Corpse", "Node3D", false, false).size())
	quit(0)


func _spawn(player, variant, position):
	var unit = load(Factions.entry(variant)["archetype"]).instantiate()
	unit.variant = variant
	MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), position), player)
	return unit


func _shot(tag):
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/inf_" + tag + ".png")


func _frames(n):
	for i in n:
		await process_frame
