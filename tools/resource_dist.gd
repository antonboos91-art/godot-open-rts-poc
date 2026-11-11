## Abstand jeder Zentrale zum naechsten Rohstoff (A und B) pro Karte, zeigt, ob die KI Rohstoffe findet.
##   godot4 --headless -s tools/resource_dist.gd -- <Karte> [spieler]
extends SceneTree


func _initialize():
	_run()


func _run():
	await process_frame
	var Constants = root.get_node("/root/Constants")
	var args = OS.get_cmdline_user_args()
	var map = args[0] if args.size() > 0 else "PlainAndSimple"
	var count = int(args[1]) if args.size() > 1 else 4
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	for i in range(count):
		var ps = load("res://source/data-model/PlayerSettings.gd").new()
		ps.controller = Constants.PlayerType.HUMAN if i == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		ps.faction = ["shibas", "katzen", "baeren"][i % 3]
		ps.color = Constants.Player.COLORS[i]
		settings.players.append(ps)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = "res://source/match/maps/%s.tscn" % map
	root.add_child(loading)
	while root.get_node_or_null("Match") == null or not root.get_node("Match").is_node_ready():
		await process_frame
	for i in 30:
		await process_frame
	var a = []
	var b = []
	for u in get_nodes_in_group("resource_units"):
		if "resource_a" in u:
			a.append(u.global_position)
		elif "resource_b" in u:
			b.append(u.global_position)
	print("RES map=", map, " size=", root.get_node("Match").map.size, " A=", a.size(), " B=", b.size())
	for u in get_nodes_in_group("units"):
		if u.get("type") == "CommandCenter":
			var da = 999.0
			var db = 999.0
			for p in a:
				da = min(da, u.global_position.distance_to(p))
			for p in b:
				db = min(db, u.global_position.distance_to(p))
			print("RES hq ", u.variant, " nearest A=%.1f B=%.1f" % [da, db])
	quit(0)
