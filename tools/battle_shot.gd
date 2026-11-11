## Kampf-Effekte ansehen: Shibas gegen Katzen gegen Baeren in der Kartenmitte, mehrere Screenshots.
##   godot4 --path . -s tools/battle_shot.gd -- <ausgabe-ordner>
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
		[players[0], ["shibas/trooper", "shibas/trooper", "shibas/zapper", "shibas/tesla", "shibas/buggy"], c + Vector3(-6, 0, 3)],
		[players[1], ["katzen/streuner", "katzen/streuner", "katzen/scharfschuetzin", "katzen/prisma", "katzen/nebel"], c + Vector3(6, 0, 3)],
		[players[2], ["baeren/grunzer", "baeren/grunzer", "baeren/bazooka", "baeren/grizzly", "baeren/moerser"], c + Vector3(0, 0, -6)],
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
	cam.set_size_safely(11.0)
	cam.set_position_safely(c)
	var t = 0.0
	var shots = [1.6, 2.0, 2.4, 2.8, 3.4, 4.5]
	for s in shots:
		while t < s:
			await process_frame
			t += root.get_process_delta_time()
		await process_frame
		root.get_viewport().get_texture().get_image().save_png(_out + "/battle_%.1f.png" % s)
	quit(0)
