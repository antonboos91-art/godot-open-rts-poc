## HUD ansehen: Partie starten, mehrere bzw. eine Einheit auswaehlen, Screenshots.
##   godot4 --path . -s tools/hud_shot.gd -- <ausgabe-ordner> [volk]
extends SceneTree

var _out = "."
var _fac = "shibas"


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
	var me = get_nodes_in_group("players")[0]
	var hq = null
	for u in get_nodes_in_group("units"):
		if u.player == me and u.has_method("is_constructed"):
			hq = u
	var pos = hq.global_position
	var i = 0
	for u in Factions.UNITS[_fac]:
		var unit = load(Factions.entry(_fac + "/" + u[0])["archetype"]).instantiate()
		unit.variant = _fac + "/" + u[0]
		MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), pos + Vector3(-6 + (i % 6) * 1.8, 0, 5 + int(i / 6) * 2.0)), me)
		i += 1
	for f in 60:
		await process_frame
	var mine = get_nodes_in_group("controlled_units").filter(func(u): return not u.has_method("is_constructed"))
	for u in mine:
		u.find_child("Selection", false, false).select()
	for f in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/hud_multi.png")
	MatchSignals.deselect_all_units.emit()
	mine[mine.size() - 5].find_child("Selection", false, false).select()
	for f in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/hud_single.png")
	MatchSignals.deselect_all_units.emit()
	hq.find_child("Selection", false, false).select()
	for f in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/hud_building.png")
	quit(0)
