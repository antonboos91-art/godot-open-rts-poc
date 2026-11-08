## Demo: Ein Shiba-Tesla-Panzer fährt auf eine feindliche Kaserne zu und zerstört sie.
## Speichert Screenshots nach <ausgabe>/tank_demo_XX.png und prüft, dass das Gebäude zerstört wird.
##   godot4 --path . -s tools/tank_demo.gd -- <ausgabe-ordner>
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
	for i in range(2):
		var ps = load("res://source/data-model/PlayerSettings.gd").new()
		ps.controller = Constants.PlayerType.HUMAN if i == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		ps.faction = Factions.SHIBAS if i == 0 else Factions.KATZEN
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
			print("DEMO match did not start")
			quit(1)
			return
	var match_node = root.get_node("Match")
	await _frames(30)
	var players = get_nodes_in_group("players")
	var me = players[0]
	var enemy = players[1]
	var hq = get_nodes_in_group("units").filter(
		func(u): return u.player == me and u.variant.ends_with("/hq")
	)[0]
	var base = hq.global_position + Vector3(10, 0, 10)
	var tank = _spawn(me, "shibas/tesla", base)
	var target = _spawn(enemy, "katzen/barracks", base + Vector3(9, 0, -2))
	target.construct(1.0)
	await _frames(10)
	target.hp = target.hp_max
	var cam = match_node.find_child("IsometricCamera3D", true, false)
	if cam != null:
		cam.set_size_safely(9.0)
		cam.set_position_safely(base + Vector3(4.5, 0, -1))
	print("DEMO tank visual: ", tank.find_child("SpriteVehicle", false, false) != null)
	print("DEMO target hp: ", target.hp, "/", target.hp_max)
	await _frames(20)
	_shot("00_start")
	match_node.send_command("unit", [tank], [match_node.get_path_to(target)])
	var t0 = Time.get_ticks_msec()
	var shots = 1
	var next_shot = 600
	while is_instance_valid(target) and target.hp > 0 and Time.get_ticks_msec() - t0 < 45000:
		await process_frame
		if Time.get_ticks_msec() - t0 > next_shot and shots < 30:
			_shot("%02d" % shots)
			shots += 1
			next_shot += 250
	var destroyed = not is_instance_valid(target) or target.hp <= 0
	await _frames(25)
	_shot("99_end")
	print("DEMO destroyed: ", destroyed, " after ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	quit(0 if destroyed else 1)


func _spawn(player, variant, position):
	var unit = load(Factions.entry(variant)["archetype"]).instantiate()
	unit.variant = variant
	MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), position), player)
	return unit


func _shot(tag):
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/tank_demo_" + tag + ".png")


func _frames(n):
	for i in n:
		await process_frame
