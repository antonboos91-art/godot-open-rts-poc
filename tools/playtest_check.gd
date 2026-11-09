## Prueft die Playtest-Punkte automatisch: Startabstand, 8-Richtungs-Laufen (Screenshot), Gebaeude-Kollision, Fernkampf-Reichweite.
##   godot4 --path . -s tools/playtest_check.gd -- <ausgabe-ordner> [karte] [volk]
extends SceneTree


var MAP_PATH = "res://source/match/maps/PlainAndSimple.tscn"
var FAC = "shibas"
var Factions = null
var Constants = null
var MatchSignals = null
var _out = "."


func _initialize():
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		MAP_PATH = "res://source/match/maps/%s.tscn" % args[1]
	if args.size() > 2:
		FAC = args[2]
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
		ps.faction = FAC
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
		if waited > 60.0:
			print("CHECK match did not start")
			quit(1)
			return
	var match_node = root.get_node("Match")
	await _frames(60)
	# 1) Startabstand
	var hqs = []
	for u in get_nodes_in_group("units"):
		if u.get("type") == "CommandCenter":
			hqs.append(u)
	if hqs.size() >= 2:
		print("CHECK map size ", match_node.map.size, " HQ distance ", hqs[0].global_position.distance_to(hqs[1].global_position))
	var me = get_nodes_in_group("players")[0]
	var enemy = get_nodes_in_group("players")[1]
	# 2) 8-Richtungs-Laufen: acht Einheiten laufen in Kompassrichtungen vom Mittelpunkt weg
	var cam = match_node.find_child("IsometricCamera3D", true, false)
	var center = Vector3(match_node.map.size.x * 0.5, 0, match_node.map.size.y * 0.5)
	var walkers = []
	for i in range(8):
		var dir = Vector3(sin(TAU * i / 8.0), 0, cos(TAU * i / 8.0))
		var w = _spawn(me, FAC + "/" + _first_infantry(), center + dir * 1.5)
		walkers.append([w, dir])
	await _frames(20)
	for p in walkers:
		var mv = p[0].find_child("Movement")
		mv.move(p[0].global_position + p[1] * 12.0)
	if cam != null:
		cam.set_size_safely(12.0)
		cam.set_position_safely(center)
	await _frames(90)
	await _shot("walk")
	# 3) Fernkampf-Reichweite gegen ein Gebaeude
	var target = _spawn(enemy, FAC + "/barracks", center + Vector3(0, 0, -40))
	if target != null and target.has_method("construct"):
		target.construct(1.0)
	await _frames(10)
	var shooter = _spawn(me, FAC + "/raketen", center + Vector3(0, 0, -20))
	await _frames(10)
	if shooter != null and target != null:
		shooter.action = load("res://source/match/units/actions/AutoAttacking.gd").new(target)
		for i in range(12):
			await _seconds(1.0)
			if not is_instance_valid(shooter) or not is_instance_valid(target):
				break
			var d = shooter.global_position_yless.distance_to(target.global_position_yless)
			print("CHECK shooter dist center ", snapped(d, 0.01), " target radius ", target.radius, " reach ", snapped(shooter.attack_reach_to(target), 0.01), " range ", shooter.attack_range)
	await _shot("range")
	# 4) Kollision: Einheit soll durch ein Gebaeude laufen wollen -> muss drumherum
	var block = _spawn(me, FAC + "/barracks", center + Vector3(-22, 0, 0))
	if block != null and block.has_method("construct"):
		block.construct(1.0)
	await _seconds(2.0)
	print("CHECK block valid ", is_instance_valid(block))
	var runner = _spawn(me, FAC + "/" + _first_infantry(), block.global_position + Vector3(-8, 0, 0))
	await _frames(20)
	runner.find_child("Movement").move(block.global_position + Vector3(8, 0, 0))
	var min_d = 999.0
	for i in range(120):
		await _seconds(0.1)
		if is_instance_valid(runner):
			min_d = min(min_d, runner.global_position_yless.distance_to(block.global_position_yless))
	print("CHECK runner min distance to building center ", snapped(min_d, 0.01), " building radius ", block.radius)
	if cam != null:
		cam.set_size_safely(12.0)
		cam.set_position_safely(block.global_position)
	await _frames(10)
	await _shot("block")
	quit(0)


func _first_infantry():
	for u in Factions.UNITS[FAC]:
		if u[2] == "infantry" and u[8].get("attack_range", 0) > 0 and u[0] != "kampfhund":
			return u[0]
	return "trooper"


func _spawn(player, variant, position):
	var e = Factions.entry(variant)
	if e.is_empty():
		print("CHECK unknown variant ", variant)
		return null
	var unit = load(e["archetype"]).instantiate()
	unit.variant = variant
	MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), position), player)
	return unit


func _shot(tag):
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/check_" + tag + ".png")


func _frames(n):
	for i in n:
		await process_frame


func _seconds(s):
	await create_timer(s).timeout
