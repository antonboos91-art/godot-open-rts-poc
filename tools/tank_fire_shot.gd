## Panzer-Schuesse aus der Naehe ansehen (Rohr, Turm, Mündung).
##   godot4 --path . -s tools/tank_fire_shot.gd -- <ausgabe-ordner>
extends SceneTree

var Factions = null
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
	var Constants = root.get_node("/root/Constants")
	MatchSignals = root.get_node("/root/MatchSignals")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	settings.visibility = settings.Visibility.FULL
	var facs = ["shibas", "katzen", "baeren"]
	for i in range(3):
		var ps = load("res://source/data-model/PlayerSettings.gd").new()
		ps.controller = Constants.PlayerType.HUMAN if i == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		ps.faction = facs[i]
		ps.color = Constants.Player.COLORS[i]
		settings.players.append(ps)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	root.add_child(loading)
	while root.get_node_or_null("Match") == null or not root.get_node("Match").is_node_ready():
		await process_frame
	var match_node = root.get_node("Match")
	for i in 30:
		await process_frame
	var players = get_nodes_in_group("players")
	var c = Vector3(55, 0, 55)
	var groups = [
		[players[0], ["shibas/tesla"], c + Vector3(-2.5, 0, 1.5)],
		[players[2], ["baeren/grizzly"], c + Vector3(3.5, 0, -2.0)],
		[players[1], ["katzen/prisma"], c + Vector3(1.0, 0, 4.0)],
	]
	for g in groups:
		var i = 0
		for v in g[1]:
			if Factions.entry(v).is_empty():
				print("BATTLE unknown ", v)
				continue
			var u = load(Factions.entry(v)["archetype"]).instantiate()
			u.variant = v
			MatchSignals.setup_and_spawn_unit.emit(u, Transform3D(Basis(), g[2] + Vector3((i % 3) * 1.6 - 1.6, 0, int(i / 3) * 1.8)), g[0])
			i += 1
	var cam = match_node.find_child("IsometricCamera3D", true, false)
	cam.set_size_safely(7.0)
	cam.set_position_safely(c)
	var t = 0.0
	var shots = [1.2, 1.5, 1.8, 2.1, 2.4, 2.7, 3.0, 3.3]
	for s in shots:
		while t < s:
			await process_frame
			t += root.get_process_delta_time()
		await process_frame
		root.get_viewport().get_texture().get_image().save_png(_out + "/battle_%.1f.png" % s)
	quit(0)
