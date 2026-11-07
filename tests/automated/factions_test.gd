## Prüft Völker, Techbaum, Stromnetz und die KI mit Völkern in einer echten Partie:
##   godot4 --headless -s tests/automated/factions_test.gd
extends SceneTree

const MAP_PATH = "res://source/match/maps/PlainAndSimple.tscn"

var _failures = 0
var _match = null
# Erst zur Laufzeit laden: Autoloads (Constants, MatchSignals) gibt es beim Kompilieren
# eines -s-Skripts noch nicht.
var Factions = null
var Constants = null
var MatchSignals = null


func _initialize():
	_run()


func _run():
	await process_frame
	Factions = load("res://source/match/factions/Factions.gd")
	Constants = root.get_node("/root/Constants")
	MatchSignals = root.get_node("/root/MatchSignals")
	_match = await _start_match()
	if _match == null:
		_check(false, "match started")
		_finish()
		return
	await _wait_until(func(): return get_nodes_in_group("units").size() >= 15, 10.0)
	var players = get_nodes_in_group("players")
	var me = players[0]

	# Startaufstellung mit Volks-Varianten
	_check(me.faction == Factions.SHIBAS, "human plays Shibas")
	var my_variants = _own(me).map(func(u): return u.variant)
	_check("shibas/hq" in my_variants, "Shibas start with Rudel-Zentrale")
	_check(my_variants.count("shibas/trooper") == 2, "Shibas start with two Welpen-Trooper")
	_check(my_variants.count("shibas/sammler") == 2, "Shibas start with two Schrott-Sammler")
	var hq = _own(me).filter(func(u): return u.variant == "shibas/hq")[0]
	var trooper = _own(me).filter(func(u): return u.variant == "shibas/trooper")[0]
	_check(hq.hp_max == 20 and trooper.hp_max == 4, "variant stats applied")
	_check(
		_own(players[1]).all(func(u): return u.variant.begins_with("katzen/")),
		"AI 1 units are Katzen variants"
	)
	_check(
		_own(players[2]).all(func(u): return u.variant.begins_with("baeren/")),
		"AI 2 units are Bären variants"
	)
	_check(
		_own(players[2]).filter(func(u): return u.variant == "baeren/hq")[0].hp_max == 30,
		"Bunkerhöhle has 30 HP"
	)
	_check(me.get_power() == [10, 0], "HQ supplies 10 power")

	# Techbaum: Kaserne braucht Strom-Gebäude
	me.resource_a = 60
	me.resource_b = 60
	var workers = _own(me).filter(func(u): return u.variant == "shibas/sammler")
	_check(
		Factions.missing_requirements(me, "shibas/barracks") == ["Dynamo-Zwinger"],
		"barracks needs Dynamo-Zwinger"
	)
	var count_before = _own(me).size()
	_place(workers, "shibas/barracks", Vector3(-6, 0, 6))
	await _frames(3)
	_check(_own(me).size() == count_before, "locked structure is refused")
	_check(me.resource_a == 60, "refused structure costs nothing")

	var dynamo = await _place_and_finish(me, workers, "shibas/power", Vector3(-6, 0, 6))
	_check(dynamo != null and dynamo.hp_max == 8, "Dynamo-Zwinger built")
	_check(me.resource_a == 57, "Dynamo-Zwinger costs 3 scrap")
	_check(me.get_power() == [30, 0], "Dynamo-Zwinger adds 20 power")

	var barracks = await _place_and_finish(me, workers, "shibas/barracks", Vector3(6, 0, 6))
	_check(barracks != null, "barracks unlocked and built")
	_check(me.get_power() == [30, 5], "barracks uses 5 power")

	# Produktion: nur passende Einheiten, mit Kosten aus den Volksdaten
	if barracks != null:
		var tesla_refused = _queue_size_after_produce(barracks, "shibas/tesla")
		_check(tesla_refused == 0, "barracks cannot build tanks")
		var units_before = _own(me).size()
		var scrap_before = me.resource_a
		barracks.production_queue.produce("shibas/zapper")
		_check(me.resource_a == scrap_before - 2, "Zapper costs 2 scrap")
		var produced = await _wait_until(func(): return _own(me).size() > units_before, 8.0)
		_check(produced, "barracks produced a unit")
		var newest = _own(me).filter(func(u): return u.variant == "shibas/zapper")
		_check(newest.size() == 1 and newest[0].attack_damage == 3, "Zapper has its own stats")

	# Raffinerie: Rohstoff-Abgabe und ein Sammler gratis
	var collectors_before = _own(me).filter(func(u): return u.variant == "shibas/sammler").size()
	var refinery = await _place_and_finish(me, workers, "shibas/refinery", Vector3(0, 0, 9))
	_check(refinery != null, "Schrottpresse built")
	await _frames(5)
	_check(
		(
			_own(me).filter(func(u): return u.variant == "shibas/sammler").size()
			== collectors_before + 1
		),
		"Schrottpresse delivers a free collector"
	)

	# Strommangel: Produktion langsamer
	_check(not me.is_low_power(), "power is fine before overload")
	for i in range(3):
		var lab = load(Factions.entry("shibas/lab")["archetype"]).instantiate()
		lab.variant = "shibas/lab"
		MatchSignals.setup_and_spawn_unit.emit(
			lab, Transform3D(Basis(), hq.global_position + Vector3(-9 + i * 4, 0, -8)), me
		)
		lab.construct(1.0)
	_check(me.is_low_power(), "three labs overload the grid")
	_check(me.production_speed_factor() == 0.5, "low power halves production speed")

	# KI mit Volk baut eigene Kraftwerke
	Engine.time_scale = 4.0
	var ai_built_power = await _wait_until(
		func():
			return (
				_own(players[1]).any(func(u): return u.variant == "katzen/power")
				and _own(players[2]).any(func(u): return u.variant == "baeren/power")
			),
		60.0
	)
	Engine.time_scale = 1.0
	_check(ai_built_power, "AI players build power plants of their faction")
	_finish()


func _start_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	var setup = [
		[Constants.PlayerType.HUMAN, Factions.SHIBAS],
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, Factions.KATZEN],
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, Factions.BAEREN],
	]
	for i in range(setup.size()):
		var player_settings = load("res://source/data-model/PlayerSettings.gd").new()
		player_settings.controller = setup[i][0]
		player_settings.faction = setup[i][1]
		player_settings.color = Constants.Player.COLORS[i]
		settings.players.append(player_settings)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = MAP_PATH
	root.add_child(loading)
	var ok = await _wait_until(
		func():
			return root.get_node_or_null("Match") != null and root.get_node("Match").is_node_ready(),
		20.0
	)
	return root.get_node_or_null("Match") if ok else null


func _own(player):
	return get_nodes_in_group("units").filter(func(u): return u.player == player)


func _place(workers, variant, offset):
	var hq = _own(workers[0].player).filter(func(u): return u.variant.ends_with("/hq"))[0]
	var spot = Transform3D(Basis(), hq.global_position + offset)
	_match.send_command("place_structure", workers, [variant, spot])


## Platziert ein Gebäude und stellt es sofort fertig.
func _place_and_finish(player, workers, variant, offset):
	_place(workers, variant, offset)
	await _frames(2)
	var placed = _own(player).filter(
		func(u): return u.variant == variant and u.is_under_construction()
	)
	if placed.is_empty():
		return null
	placed[0].construct(1.0)
	await _frames(2)
	return placed[0]


func _queue_size_after_produce(structure, variant):
	var before = structure.production_queue.size()
	structure.production_queue.produce(variant)
	return structure.production_queue.size() - before


func _wait_until(condition, timeout_sec):
	var waited = 0.0
	while waited < timeout_sec:
		if condition.call():
			return true
		await process_frame
		waited += root.get_process_delta_time() / max(Engine.time_scale, 1.0)
	return condition.call()


func _frames(n):
	for i in n:
		await process_frame


func _check(condition, label):
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_failures += 1


func _finish():
	print("factions_test: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)
