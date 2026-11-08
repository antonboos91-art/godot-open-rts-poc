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

	# Shibas haben eigene Sprites je Variante
	var sprite_path = load("res://source/match/units/traits/PixelSprite.gd").sprite_path_for(
		"shibas/tesla", "Tank"
	)
	_check(sprite_path.ends_with("shibas_tesla.png"), "Tesla-Panzer has its own sprite")
	_check(
		(
			load("res://source/match/units/traits/PixelSprite.gd")
			. sprite_path_for("katzen/prisma", "Tank")
			. ends_with("Tank.png")
		),
		"factions without own sprites fall back to the archetype sprite"
	)
	_check(trooper.find_child("PixelSprite", false, false) != null, "units show a pixel sprite")

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

	# Ingenieur übernimmt ein Feindgebäude
	var enemy = players[1]
	var enemy_hq = _own(enemy).filter(func(u): return u.variant == "katzen/hq")[0]
	var enemy_power = _spawn_structure(
		enemy, "katzen/power", enemy_hq.global_position + Vector3(0, 0, -6)
	)
	await _frames(3)
	enemy_power.hp = 4
	var engineer = _spawn_unit(
		me, "shibas/ingenieur", enemy_power.global_position + Vector3(0, 0, 3)
	)
	await _frames(3)
	_check(engineer.attack_domains.is_empty(), "engineer cannot attack")
	_match.send_command("unit", [engineer], [_match.get_path_to(enemy_power)])
	var captured = await _wait_until(
		func(): return _own(me).any(func(u): return u.variant == "katzen/power"), 20.0
	)
	_check(captured, "engineer captured the enemy power plant")
	await _frames(5)
	_check(not is_instance_valid(engineer), "engineer is used up by capturing")
	_check(not is_instance_valid(enemy_power), "old structure of the enemy is gone")
	var mine = _own(me).filter(func(u): return u.variant == "katzen/power")
	_check(mine.size() == 1 and mine[0].hp < mine[0].hp_max, "captured structure keeps its damage")
	_check(mine.size() == 1 and mine[0].is_constructed(), "captured structure is finished")

	# Bau-Mobil entfaltet sich zur Zentrale
	var hqs_before = _own(me).filter(func(u): return u.variant == "shibas/hq").size()
	var mcv = _spawn_unit(me, "shibas/baumobil", hq.global_position + Vector3(14, 0, -4))
	await _frames(3)
	_match.send_command("deploy", [mcv])
	await _frames(5)
	_check(
		_own(me).filter(func(u): return u.variant == "shibas/hq").size() == hqs_before + 1,
		"Bau-Mobil unfolds into a Rudel-Zentrale"
	)
	_check(not is_instance_valid(mcv), "Bau-Mobil is gone after unfolding")
	var blocked = _spawn_unit(me, "shibas/baumobil", hq.global_position + Vector3(1, 0, 0.5))
	await _frames(3)
	_match.send_command("deploy", [blocked])
	await _frames(5)
	_check(is_instance_valid(blocked), "Bau-Mobil does not unfold on top of buildings")
	if is_instance_valid(blocked):
		blocked.queue_free()

	# Superwaffe: lädt auf, feuert, trifft nur Gegner im Zielgebiet
	var sw = _spawn_structure(me, "shibas/superweapon", hq.global_position + Vector3(-12, 0, -8))
	await _frames(3)
	_check(not sw.is_charged(), "Sturm-Satellit starts uncharged")
	var victim = _own(players[2]).filter(func(u): return u.variant == "baeren/hq")[0]
	var victim_hp = victim.hp
	var own_unit_hp = hq.hp
	_match.send_command("superweapon", [sw], [victim.global_position])
	await _frames(3)
	_check(victim.hp == victim_hp, "superweapon cannot fire before it is charged")
	sw.charge_progress = 1.0
	_match.send_command("superweapon", [sw], [victim.global_position])
	await _frames(3)
	_check(victim.hp == victim_hp - 12, "Sturm-Satellit damages enemies in the target area")
	_check(sw.charge_progress == 0.0, "firing resets the charge")
	_check(hq.hp == own_unit_hp, "superweapon spares own buildings")

	# Katzen: Hacken, Sabotage, Tarnung, Systemabsturz
	var hacker = _spawn_unit(me, "katzen/hackerin", victim.global_position + Vector3(0, 0, 7))
	await _frames(3)
	_check(hacker.attack_domains.is_empty(), "hacker cannot attack")
	_check(not victim.is_hacked(), "target is not hacked at first")
	_match.send_command("unit", [hacker], [_match.get_path_to(victim)])
	var hacked = await _wait_until(func(): return victim.is_hacked(), 20.0)
	_check(hacked, "hacker hacks the enemy structure")
	_check(Factions.entry("katzen/hackerin")["ability"] == "hack", "hacker ability is hack")

	var target_power = _spawn_structure(
		players[2], "baeren/power", victim.global_position + Vector3(0, 0, -9)
	)
	await _frames(3)
	var power_hp = target_power.hp
	var saboteur = _spawn_unit(
		me, "katzen/saboteur", target_power.global_position + Vector3(0, 0, 4)
	)
	await _frames(3)
	_match.send_command("unit", [saboteur], [_match.get_path_to(target_power)])
	var sabotaged = await _wait_until(
		func(): return not is_instance_valid(target_power) or target_power.hp < power_hp, 20.0
	)
	_check(sabotaged, "saboteur damages the enemy structure")
	await _frames(5)
	_check(not is_instance_valid(saboteur), "saboteur is used up")

	var ghost = _spawn_unit(me, "katzen/phantom", Vector3(-20, 0, 20))
	await _frames(3)
	_check(Factions.is_hidden_from(ghost, players[2]), "Phantom is hidden from far enemies")
	_check(not Factions.is_hidden_from(ghost, me), "Phantom is visible to its owner")
	var spotter = _spawn_unit(players[2], "baeren/bazooka", Vector3(-20, 0, 22))
	await _frames(3)
	_check(not Factions.is_hidden_from(ghost, players[2]), "close enemies detect the Phantom")
	ghost.queue_free()
	spotter.queue_free()

	# Strom frei machen: die Satelliten-Station abreißen, sonst ist das Netz überlastet
	sw.queue_free()
	await _frames(3)
	var crash = _spawn_structure(me, "katzen/superweapon", hq.global_position + Vector3(-12, 0, 8))
	await _frames(3)
	var crash_target = _own(enemy).filter(func(u): return u.variant == "katzen/hq")[0]
	crash.charge_progress = 1.0
	_match.send_command("superweapon", [crash], [crash_target.global_position])
	await _frames(3)
	_check(crash_target.is_hacked(), "Systemabsturz disables enemy buildings")
	_check(crash_target.hp == crash_target.hp_max, "Systemabsturz does no damage")
	crash.queue_free()
	await _frames(3)

	# Bären: Mechaniker repariert, Brummbär-Rakete
	var wounded = _spawn_unit(me, "shibas/buggy", hq.global_position + Vector3(8, 0, 12))
	await _frames(3)
	wounded.hp = 1
	var mechanic = _spawn_unit(me, "baeren/mechaniker", wounded.global_position + Vector3(0, 0, 4))
	await _frames(3)
	_check(mechanic.attack_domains.is_empty(), "mechanic cannot attack")
	_match.send_command("unit", [mechanic], [_match.get_path_to(wounded)])
	var repaired = await _wait_until(func(): return wounded.hp >= 3, 25.0)
	_check(repaired, "mechanic repairs a damaged vehicle")
	wounded.queue_free()
	mechanic.queue_free()
	sw = null
	var rocket_power = _spawn_structure(
		players[2], "baeren/power_big", enemy_hq.global_position + Vector3(0, 0, 14)
	)
	var rocket = _spawn_structure(
		players[2],
		"baeren/superweapon",
		Vector3(0, 0, 0) + enemy_hq.global_position + Vector3(10, 0, 0)
	)
	await _frames(3)
	var dummy = _spawn_unit(me, "shibas/tesla", Vector3(-20, 0, 20))
	await _frames(3)
	dummy.hp_max = 40
	dummy.hp = 40
	var rocket_hp = dummy.hp
	rocket.charge_progress = 1.0
	_match.send_command("superweapon", [rocket], [dummy.global_position])
	await _frames(3)
	_check(
		not is_instance_valid(dummy) or dummy.hp == max(0, rocket_hp - 20),
		"Brummbär-Rakete hits for 20"
	)
	rocket.queue_free()
	rocket_power.queue_free()
	if is_instance_valid(dummy):
		dummy.queue_free()
	await _frames(3)

	# Flugkessel: Infanterie steigt ein und wird wieder abgesetzt
	var kessel = _spawn_unit(me, "baeren/flugkessel", hq.global_position + Vector3(14, 0, 12))
	var soldiers = []
	for i in range(2):
		soldiers.append(
			_spawn_unit(me, "shibas/trooper", kessel.global_position + Vector3(3 + i, 0, 4))
		)
	await _frames(3)
	_check(kessel.cargo_count == 0, "transport starts empty")
	_match.send_command("unit", soldiers, [_match.get_path_to(kessel)])
	var loaded = await _wait_until(func(): return kessel.cargo_count == 2, 25.0)
	_check(loaded, "infantry boards the Flugkessel")
	await _frames(3)
	_check(not is_instance_valid(soldiers[0]), "boarded infantry leaves the field")
	var infantry_before = _own(me).filter(func(u): return u.variant == "shibas/trooper").size()
	_match.send_command("unload", [kessel])
	await _frames(5)
	_check(kessel.cargo_count == 0, "unloading empties the cargo")
	_check(
		(
			_own(me).filter(func(u): return u.variant == "shibas/trooper").size()
			== infantry_before + 2
		),
		"unloaded infantry is back on the field"
	)
	kessel.queue_free()
	await _frames(3)

	# Bären-Kraftwerke explodieren und beschädigen Nachbarn
	var boom_power = _spawn_structure(players[2], "baeren/power_big", Vector3(-20, 0, 20))
	var neighbour = _spawn_unit(me, "shibas/tesla", Vector3(-20, 0, 22))
	await _frames(3)
	var neighbour_hp = neighbour.hp
	boom_power.hp = 0
	await _frames(3)
	_check(neighbour.hp == neighbour_hp - 8, "destroyed Reaktor-Kessel damages units nearby")
	neighbour.queue_free()
	await _frames(3)

	# KI-Mechaniker repariert selbstständig
	var ai_player = players[2]
	var ai_hq = _own(ai_player).filter(func(u): return u.variant == "baeren/hq")
	if not ai_hq.is_empty():
		var ai_tank = _spawn_unit(ai_player, "baeren/moerser", Vector3(-20, 0, 20))
		await _frames(3)
		ai_tank.hp = 1
		_spawn_unit(ai_player, "baeren/mechaniker", Vector3(-20, 0, 23))
		var ai_repaired = await _wait_until(
			func(): return is_instance_valid(ai_tank) and ai_tank.hp >= 3, 40.0
		)
		_check(ai_repaired, "AI mechanic repairs damaged units by itself")
		if is_instance_valid(ai_tank):
			ai_tank.queue_free()

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
		150.0
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


func _spawn_unit(player, variant, position):
	var unit = load(Factions.entry(variant)["archetype"]).instantiate()
	unit.variant = variant
	MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), position), player)
	return unit


## Gebäude sofort fertig gestellt.
func _spawn_structure(player, variant, position):
	var structure = _spawn_unit(player, variant, position)
	structure.construct(1.0)
	return structure


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
