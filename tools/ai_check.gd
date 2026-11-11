## KI pruefen: Partie mit KI-Voelkern im Zeitraffer, gibt alle 30 s Spielzeit Rohstoffe, Gebaeude und Einheiten aus.
##   godot4 --headless -s tools/ai_check.gd -- [spielsekunden] [karte]
extends SceneTree

var Factions = null
var Constants = null
var _seconds = 360.0
var _map = "PlainAndSimple"


func _initialize():
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_seconds = float(args[0])
	if args.size() > 1:
		_map = args[1]
	_run()


func _run():
	await process_frame
	Factions = load("res://source/match/factions/Factions.gd")
	Constants = root.get_node("/root/Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	settings.visibility = settings.Visibility.FULL
	var plan = [
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, "shibas"],
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, "katzen"],
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, "baeren"],
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, "shibas"],
	]
	for i in range(plan.size()):
		var ps = load("res://source/data-model/PlayerSettings.gd").new()
		ps.controller = plan[i][0]
		ps.faction = plan[i][1]
		ps.color = Constants.Player.COLORS[i]
		settings.players.append(ps)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = "res://source/match/maps/%s.tscn" % _map
	root.add_child(loading)
	while root.get_node_or_null("Match") == null or not root.get_node("Match").is_node_ready():
		await process_frame
	Engine.max_physics_steps_per_frame = 80
	Engine.time_scale = 8.0
	var frames0 = Engine.get_physics_frames()
	var t = 0.0
	var next_report = 0.0
	while t < _seconds:
		await process_frame
		t = (Engine.get_physics_frames() - frames0) / float(Engine.physics_ticks_per_second)  # echte Simulationszeit
		if t >= next_report:
			next_report += 30.0
			_report(t)
	Engine.time_scale = 1.0
	quit(0)


func _report(t):
	print("== t=%d s ==" % int(t))
	for p in get_nodes_in_group("players"):
		var units = []
		var structs = []
		var workers = 0
		for u in get_nodes_in_group("units"):
			if u.get("player") != p:
				continue
			if u.has_method("is_constructed"):
				structs.append(u.variant.get_slice("/", 1) + ("" if u.is_constructed() else "*"))
			else:
				units.append(u.variant.get_slice("/", 1))
				if u.type == "Worker":
					workers += 1
		print(" ", p.faction, " res=", [p.resource_a, p.resource_b], " power=", p.get_power(), " workers=", workers, " units=", units.size(), " structs=", structs)
