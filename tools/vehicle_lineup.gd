## Fahrzeuge eines Volks nebeneinander (3D-Modelle bzw. Sprites) zum Vergleichen.
##   godot4 --path . -s tools/vehicle_lineup.gd -- <ausgabe-ordner> <volk>
extends SceneTree

var _out = "."
var _fac = "baeren"


func _initialize():
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_fac = args[1]
	_run()


func _run():
	await process_frame
	var Constants = root.get_node("/root/Constants")
	var MatchSignals = root.get_node("/root/MatchSignals")
	var Factions = load("res://source/match/factions/Factions.gd")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	settings.visibility = settings.Visibility.FULL
	for i in range(2):
		var ps = load("res://source/data-model/PlayerSettings.gd").new()
		ps.controller = Constants.PlayerType.HUMAN if i == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		ps.faction = _fac
		ps.color = Constants.Player.COLORS[i]
		settings.players.append(ps)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	root.add_child(loading)
	while root.get_node_or_null("Match") == null or not root.get_node("Match").is_node_ready():
		await process_frame
	var m = root.get_node("Match")
	var me = get_nodes_in_group("players")[0]
	var c = Vector3(55, 0, 55)
	var x = -12.0
	for u in Factions.UNITS[_fac]:
		if not u[2] in ["tank", "worker", "heli"]:
			continue
		var unit = load(Factions.entry(_fac + "/" + u[0])["archetype"]).instantiate()
		unit.variant = _fac + "/" + u[0]
		MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), c + Vector3(x, 0, 0)), me)
		x += 4.5
	var inf = load(Factions.entry(_fac + "/" + Factions.UNITS[_fac][0][0])["archetype"]).instantiate()
	inf.variant = _fac + "/" + Factions.UNITS[_fac][0][0]
	MatchSignals.setup_and_spawn_unit.emit(inf, Transform3D(Basis(), c + Vector3(-15, 0, 0)), me)
	var cam = m.find_child("IsometricCamera3D", true, false)
	cam.set_size_safely(16.0)
	cam.set_position_safely(c + Vector3(1, 0, 0))
	for i in 90:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/lineup_%s.png" % _fac)
	quit(0)
