## Prüft die Blizzard-Stil-Funktionen (Tab-Untergruppen, Mehrfachgebäude-Produktion, Arbeiter-Auto-Sammeln,
## Auslastungsanzeige, Untätige Arbeiter, Smart-Cast, Makro, Wachtürme, Warteschlangen-Linien, Telegraph ...):
##   godot4 --headless -s tests/automated/blizzard_test.gd
extends SceneTree

const MAP_PATH = "res://source/match/maps/PlainAndSimple.tscn"

var _failures = 0
var _match = null
var Factions = null
var Constants = null
var MatchSignals = null
var Hotkeys = null


func _initialize():
	_run()


func _run():
	await process_frame
	Factions = load("res://source/match/factions/Factions.gd")
	Hotkeys = load("res://source/match/players/human/Hotkeys.gd")
	Constants = root.get_node("/root/Constants")
	MatchSignals = root.get_node("/root/MatchSignals")
	load("res://source/match/units/Facility.gd").telegraph_seconds = 0.0
	_check_hotkeys()
	_match = await _start_match()
	if _match == null:
		_check(false, "match started")
		_finish()
		return
	await _wait_until(func(): return get_nodes_in_group("units").size() >= 15, 10.0)
	var players = get_nodes_in_group("players")
	var me = players[0]
	var enemy = players[1]
	me.resource_a = 200
	me.resource_b = 200
	var hotkeys = _match.hotkey_controller
	_check(hotkeys != null, "local player has a hotkey controller")
	if hotkeys == null:
		_finish()
		return

	await _check_subgroups(me, hotkeys)
	await _check_idle_workers(me, hotkeys)
	await _check_production_group(me)
	await _check_auto_harvest_and_saturation(me)
	await _check_smart_cast(me, enemy)
	await _check_macro(me, players)
	await _check_watchtowers(me)
	await _check_lines_and_telegraph(me, enemy)
	await _check_hud_overview(me, hotkeys)
	_check_rules()
	_finish()


func _check_hotkeys():
	_check(Hotkeys.keycode("idle_worker") == KEY_F1, "idle workers default to F1")
	_check(Hotkeys.keycode("subgroup") == KEY_TAB, "subgroup cycling defaults to Tab")
	var event = InputEventKey.new()
	event.keycode = KEY_F5
	event.pressed = true
	_check(Hotkeys.matches(event, "camera_1"), "F5 is the first camera bookmark")
	event.echo = true
	_check(not Hotkeys.matches(event, "camera_1"), "key repeat is ignored unless requested")
	_check(Hotkeys.matches(event, "camera_1", true), "key repeat is accepted when requested")
	_check(Hotkeys.label("macro") == "Z", "key labels are readable")


func _check_subgroups(me, hotkeys):
	var groups = hotkeys.subgroups_of(
		[
			_spawn_unit(me, "shibas/trooper", Vector3(30, 0, 40)),
			_spawn_unit(me, "shibas/ingenieur", Vector3(31, 0, 40)),
			_spawn_unit(me, "shibas/tesla", Vector3(32, 0, 40)),
			_spawn_unit(me, "shibas/trooper", Vector3(33, 0, 40)),
		]
	)
	await _frames(3)
	_check(groups.size() == 3, "selection splits into subgroups by unit type")
	_check(groups[0] == "shibas/ingenieur", "units with abilities come first")
	_check(groups[1] == "shibas/tesla", "then the higher tier")
	var picked = _own(me).filter(
		func(u): return u.variant in ["shibas/trooper", "shibas/tesla", "shibas/ingenieur"]
	)
	MatchSignals.deselect_all_units.emit()
	for unit in picked:
		unit.find_child("Selection").select()
	await _frames(2)
	var many = get_nodes_in_group("selected_units").size()
	_check(many >= 4, "no hard cap on the selection (%d units)" % many)
	Hotkeys.active_subgroup = ""
	hotkeys.cycle_subgroup()
	var first = Hotkeys.active_subgroup
	hotkeys.cycle_subgroup()
	var second = Hotkeys.active_subgroup
	_check(first != "" and second != "" and first != second, "Tab cycles through the subgroups")
	_check(get_nodes_in_group("selected_units").size() == many, "cycling keeps the master selection")
	MatchSignals.deselect_all_units.emit()
	Hotkeys.active_subgroup = ""
	for unit in picked:
		unit.hp = 0
	await _frames(3)


func _check_idle_workers(me, hotkeys):
	var worker = _spawn_unit(me, "shibas/sammler", Vector3(40, 0, 45))
	await _frames(4)
	worker.action = null
	await _frames(2)
	_check(worker in hotkeys.idle_workers(), "a worker without orders counts as idle")
	var picked = hotkeys.cycle_idle_worker()
	await _frames(2)
	_check(picked != null and picked.is_in_group("selected_units"), "F1 selects an idle worker")
	hotkeys.select_idle_workers()
	await _frames(2)
	var selected_idle = get_nodes_in_group("selected_units").filter(func(u): return u in hotkeys.idle_workers())
	_check(selected_idle.size() == hotkeys.idle_workers().size(), "Ctrl+F1 selects all idle workers")
	MatchSignals.deselect_all_units.emit()
	_match.send_command("terrain", [worker], [Vector3(40, 0, 50)])
	await _frames(2)
	_check(not worker in hotkeys.idle_workers(), "a busy worker is not idle")
	worker.hp = 0
	await _frames(2)


func _check_production_group(me):
	var power = _spawn_structure(me, "shibas/power", Vector3(70, 0, 20))
	var barracks_a = _spawn_structure(me, "shibas/barracks", Vector3(75, 0, 20))
	var barracks_b = _spawn_structure(me, "shibas/barracks", Vector3(80, 0, 20))
	await _frames(3)
	var menu = load("res://source/match/hud/unit-menus/FactionMenu.gd").new()
	root.add_child(menu)
	_check(menu.show_production_group([barracks_a, barracks_b]), "several barracks share one production menu")
	barracks_a.production_queue.produce("shibas/trooper")
	barracks_a.production_queue.produce("shibas/trooper")
	await _frames(2)
	menu._on_button_pressed("shibas/trooper")
	await _frames(2)
	_check(
		barracks_b.production_queue.size() == 1 and barracks_a.production_queue.size() == 2,
		"orders go to the least-burdened building"
	)
	menu._on_button_pressed("shibas/trooper")
	menu._on_button_pressed("shibas/trooper")
	await _frames(2)
	_check(
		abs(barracks_a.production_queue.size() - barracks_b.production_queue.size()) <= 1,
		"queues stay balanced across the group"
	)
	menu.queue_free()
	for structure in [barracks_a, barracks_b, power]:
		structure.hp = 0
	await _frames(3)


func _check_auto_harvest_and_saturation(me):
	var hq = _own(me).filter(func(u): return u.variant == "shibas/hq")[0]
	var before = _own(me).filter(func(u): return u.variant == "shibas/sammler").size()
	hq.production_queue.produce("shibas/sammler", true)
	Engine.time_scale = 10.0
	var spawned = await _wait_until(
		func(): return _own(me).filter(func(u): return u.variant == "shibas/sammler").size() > before, 20.0
	)
	Engine.time_scale = 1.0
	_check(spawned, "the headquarters produces a worker")
	await _frames(5)
	var newest = _own(me).filter(func(u): return u.variant == "shibas/sammler").back()
	_check(
		newest.action != null
		and newest.action.get_script().resource_path.ends_with("CollectingResourcesSequentially.gd"),
		"a new worker starts harvesting by itself"
	)
	var saturation = _match.get_node("Saturation")
	var value = saturation.saturation_of(hq)
	_check(value[1] >= 20 and value[0] >= 1, "saturation counts workers and places (%d/%d)" % value)
	saturation.refresh()
	# Last wird auf mehrere Knoten verteilt: zwei neue Arbeiter nehmen nicht denselben Knoten
	var claims = {}
	for node in get_nodes_in_group("resource_units"):
		var c = node.get_meta("claims", 0)
		if c > 0:
			claims[node] = c
	_check(claims.values().all(func(c): return c <= 2), "workers spread over the nodes (max claims %d)" % (claims.values().max() if not claims.is_empty() else 0))
	var script = load("res://source/match/units/actions/CollectingResourcesWhileInRange.gd")
	var dummy_node = get_nodes_in_group("resource_units")[0]
	var action = script.new(dummy_node)
	dummy_node.set_meta("collectors", 2)
	_check(is_equal_approx(action._saturation_slowdown(), 1.0), "two workers per node mine at full speed")
	dummy_node.set_meta("collectors", 4)
	_check(is_equal_approx(action._saturation_slowdown(), 2.0), "more workers per node give diminishing returns")
	dummy_node.set_meta("collectors", 0)
	action.free()


func _check_smart_cast(me, enemy):
	var target = _spawn_structure(enemy, "katzen/power", Vector3(95, 0, 60))
	var close = _spawn_unit(me, "shibas/ingenieur", Vector3(90, 0, 60))
	var far = _spawn_unit(me, "shibas/ingenieur", Vector3(60, 0, 60))
	var trooper = _spawn_unit(me, "shibas/trooper", Vector3(60, 0, 62))
	await _frames(4)
	_match.send_command("unit", [close, far, trooper], [_match.get_path_to(target)])
	await _frames(3)
	var close_acts = close.action != null and close.action.get_script().resource_path.ends_with("Capturing.gd")
	var far_acts = far.action != null and far.action.get_script().resource_path.ends_with("Capturing.gd")
	_check(close_acts and not far_acts, "only the closest eligible caster uses its ability")
	_check(
		trooper.action != null and not trooper.action.get_script().resource_path.ends_with("Capturing.gd"),
		"the rest of the group keeps its normal behavior"
	)
	for unit in [close, far, trooper, target]:
		if is_instance_valid(unit):
			unit.hp = 0
	await _frames(3)


func _check_macro(me, players):
	var macro = _match.get_node("Macro")
	me.energy = 100.0
	var before = me.energy
	_match.send_command("macro", [])
	await _frames(2)
	_check(abs(me.energy - (before - 50.0)) < 2.0, "the macro ability costs 50 energy")
	me.energy = 10.0
	var energy_before = me.energy
	_match.send_command("macro", [])
	await _frames(2)
	_check(abs(me.energy - energy_before) < 2.0, "no macro without enough energy")
	var katzen = players[1]
	katzen.energy = 100.0
	_check(macro.cast(katzen), "Katzen can cast their macro")
	_check(is_equal_approx(katzen.production_speed_factor(), 1.5) or katzen.is_low_power(), "chrono boost speeds up production")
	var baeren = players[2]
	baeren.energy = 100.0
	var grunzer_before = _own(baeren).filter(func(u): return u.variant == "baeren/grunzer").size()
	_check(macro.cast(baeren), "Bären can cast their macro")
	Engine.time_scale = 20.0
	var hatched = await _wait_until(
		func(): return _own(baeren).filter(func(u): return u.variant == "baeren/grunzer").size() >= grunzer_before + 2, 30.0
	)
	Engine.time_scale = 1.0
	_check(hatched, "the brood throw hatches two units")
	var before_scrap = me.resource_a
	me.energy = 100.0
	macro.cast(me)
	Engine.time_scale = 30.0
	await _wait_until(func(): return me.resource_a >= before_scrap + 5, 30.0)
	Engine.time_scale = 1.0
	_check(me.resource_a >= before_scrap + 5, "the supply drop delivers extra scrap over time")


func _check_watchtowers(me):
	var towers = get_nodes_in_group("vision_sources")
	_check(towers.size() >= 4, "the map has neutral watchtowers (%d)" % towers.size())
	var tower = towers[0]
	tower.scan()
	_check(not tower.is_revealing(), "an empty watchtower gives no vision")
	var scout = _spawn_unit(me, "shibas/trooper", tower.global_position + Vector3(1.0, 0, 0))
	await _frames(3)
	tower.scan()
	_check(tower.is_revealing() and tower.sight_range > 10.0, "a unit next to the tower activates its vision")
	scout.global_position = tower.global_position + Vector3(15, 0, 0)
	tower.scan()
	_check(not tower.is_revealing(), "vision ends when the unit leaves")
	scout.hp = 0
	await _frames(2)


func _check_lines_and_telegraph(me, enemy):
	var lines = _match.get_node("CommandLines")
	var unit = _spawn_unit(me, "shibas/trooper", Vector3(20, 0, 80))
	await _frames(3)
	MatchSignals.deselect_all_units.emit()
	unit.find_child("Selection").select()
	_match.send_command("terrain", [unit], [Vector3(30, 0, 80)])
	_match.send_command("queue_move", [unit], [Vector3(30, 0, 90)])
	_match.send_command("attack_move", [unit], [Vector3(20, 0, 90), true])
	await _frames(3)
	var drawn = lines.collect_lines()
	_check(drawn.size() >= 3, "queued orders are drawn as path lines (%d)" % drawn.size())
	_check(
		drawn.any(func(l): return l["color"] == lines.ATTACK_MOVE_COLOR)
		and drawn.any(func(l): return l["color"] == lines.MOVE_COLOR),
		"attack-moves and moves have different colors"
	)
	lines.redraw()
	MatchSignals.deselect_all_units.emit()
	unit.hp = 0
	# Telegraph: Einschlag erst nach der Warnzeit
	var facility_script = load("res://source/match/units/Facility.gd")
	facility_script.telegraph_seconds = 0.4
	var grid = _spawn_structure(me, "shibas/power_big", Vector3(10, 0, 45))
	var sw = _spawn_structure(me, "shibas/superweapon", Vector3(15, 0, 40))
	var victim = _spawn_unit(enemy, "baeren/kodiak", Vector3(60, 0, 100))
	await _frames(3)
	sw.charge_progress = 1.0
	sw._charge_seconds = 999.0
	var hp_before = victim.hp
	_match.send_command("superweapon", [sw], [victim.global_position])
	await _frames(3)
	_check(is_equal_approx(victim.hp, hp_before), "the strike waits for its warning time")
	_check(lines._telegraphs.size() == 1, "a warning circle is shown before the strike")
	await _wait_until(func(): return victim.hp < hp_before, 5.0)
	_check(victim.hp < hp_before, "the strike lands after the warning")
	facility_script.telegraph_seconds = 0.0
	victim.hp = 0
	grid.hp = 0
	sw.hp = 0
	await _frames(3)


func _check_hud_overview(me, hotkeys):
	var hud = load("res://source/match/hud/BlizzardHud.gd").new()
	root.add_child(hud)
	hud.setup(_match, me, hotkeys)
	me.resource_a += 7
	hud._sample_income()
	me.resource_a += 5
	hud._sample_income()
	_check(hud.income_per_minute(me)[0] >= 5, "income per minute is tracked")
	_check(hud.army_value(me) >= 0.0, "army value is computed")
	var text = hud.overview_text()
	_check(text.contains("Shibas") and text.contains("Einkommen"), "the overview shows player stats")
	_check(_match.actions_per_minute(me) > 0, "actions per minute are counted")
	hud._refresh()
	hud.queue_free()


func _check_rules():
	var movement = load("res://source/match/units/traits/Movement.gd")
	_check(not movement.ROTATION_LOW_PASS_FILTER_ENABLED, "units turn instantly (no rotation inertia)")


# --- Hilfsfunktionen -----------------------------------------------------------------------------


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
		player_settings.team = 1 if i > 0 else 0
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


func _spawn_unit(player, variant, position):
	var unit = load(Factions.entry(variant)["archetype"]).instantiate()
	unit.variant = variant
	MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), position), player)
	return unit


func _spawn_structure(player, variant, position):
	var structure = _spawn_unit(player, variant, position)
	structure.construct(1.0)
	return structure


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
	print("blizzard_test: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)
