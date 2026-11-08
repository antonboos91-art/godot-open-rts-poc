## Prueft Gebaeude-Effekte: Bau (Staub, Scanlinie), Schaden (Rauch, Feuer), Zerstoerung.
##   godot4 --path . -s tools/building_fx_shot.gd -- <ausgabe-ordner>
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
	var me = get_nodes_in_group("players")[0]
	var origin = Vector3(25, 0, 25)
	var building = _spawn(me, "shibas/barracks", origin)
	var damaged = _spawn(me, "shibas/factory", origin + Vector3(8, 0, 0))
	var doomed = _spawn(me, "shibas/radar", origin + Vector3(-8, 0, 0))
	for b in [damaged, doomed]:
		b.construct(1.0)
	await _frames(10)
	building.construct(0.45)
	damaged.hp = int(damaged.hp_max * 0.25)
	doomed.hp = int(doomed.hp_max * 0.5)
	var cam = match_node.find_child("IsometricCamera3D", true, false)
	cam.set_size_safely(20.0)
	cam.set_position_safely(origin)
	await _frames(70)
	await _shot("construction_damage")
	doomed.hp = 0
	await _frames(25)
	await _shot("destruction")
	building.construct(0.6)
	await _frames(25)
	await _shot("finished")
	print("FX done; ruins nodes: ", match_node.find_children("Ruins", "Node3D", false, false).size())
	quit(0)


func _spawn(player, variant, position):
	var unit = load(Factions.entry(variant)["archetype"]).instantiate()
	unit.variant = variant
	MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), position), player)
	return unit


func _shot(tag):
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(_out + "/fx_" + tag + ".png")


func _frames(n):
	for i in n:
		await process_frame
