## Prüft das SC1-Balancing, die vielen Rohstoff-Felder und die aus Generals übernommenen Funktionen
## (Stopp, Angriffs-Marsch, Shift-Wegpunkte, Verkaufen, Ränge, Upgrades, Vorratskisten, Aufgeben):
##   godot4 --headless -s tests/automated/generals_test.gd
extends SceneTree

const MAP_PATH = "res://source/match/maps/PlainAndSimple.tscn"

var _failures = 0
var _match = null
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
	load("res://source/match/units/Facility.gd").telegraph_seconds = 0.0
	_check_balance_tables()
	_match = await _start_match()
	if _match == null:
		_check(false, "match started")
		_finish()
		return
	await _wait_until(func(): return get_nodes_in_group("units").size() >= 15, 10.0)
	var players = get_nodes_in_group("players")
	var me = players[0]
	var enemy = players[1]
	me.resource_a = 100
	me.resource_b = 100

	_check_resources()
	await _check_hits_and_ranks(me, enemy)
	await _check_commands(me)
	await _check_crushing(me, enemy)
	await _check_garrison(me)
	await _check_economy_commands(me)
	await _check_crates(me)
	await _check_surrender(me)
	_finish()


# --- SC1-Balancing ---------------------------------------------------------------------------


func _check_balance_tables():
	var balance = load("res://source/match/factions/Sc1Balance.gd")
	for faction in Factions.PLAYABLE:
		var units = Factions.UNITS[faction]
		_check(units.size() >= 14, "%s has at least 14 units (%d)" % [faction, units.size()])
		var unmapped = units.filter(func(row): return not balance.has(faction + "/" + row[0]))
		var unmapped_names = unmapped.map(func(row): return row[0])
		# Nur die Bau-Mobile (Zentrale auf Rädern) haben kein SC1-Vorbild
		_check(
			unmapped_names.all(func(n): return n in ["baumobil", "nestmobil", "hoehlenmobil"]),
			"%s: every unit has an SC1 counterpart (%s)" % [faction, unmapped_names]
		)
	var marine = Factions.stats("shibas/trooper")
	_check(is_equal_approx(marine["hp"], 4.0), "Marine: 40 HP -> 4")
	_check(is_equal_approx(marine["attack_damage"], 1.0), "Marine: 6 damage -> 1")
	_check(is_equal_approx(marine["attack_interval"], 15.0 / 24.0), "Marine: cooldown 15 frames")
	_check(
		is_equal_approx(marine["attack_range"], 4.0 * Factions.RANGE_SCALE),
		"Marine: range 4 scaled like all ranged units"
	)
	_check(
		Factions.cost("shibas/trooper") == {"resource_a": 1, "resource_b": 0},
		"Marine costs 50 minerals -> 1"
	)
	_check(
		Factions.cost("shibas/tesla") == {"resource_a": 3, "resource_b": 2},
		"Siege Tank costs 150/100 -> 3/2"
	)
	_check(
		is_equal_approx(Factions.stats("katzen/streuner")["hp"], 16.0),
		"Zealot: 100 HP + 60 shields -> 16"
	)
	_check(
		(
			is_equal_approx(Factions.stats("baeren/kodiak")["hp"], 40.0)
			and is_equal_approx(Factions.stats("baeren/kodiak")["armor"], 1.0 / 6.0)
		),
		"Ultralisk: 400 HP, armor 1"
	)
	_check(
		Factions.stats("shibas/sammler")["attack_domains"] == [],
		"SCV does not attack in the engine"
	)
	var zergling = Factions.stats("baeren/grunzer")
	var hydra = Factions.stats("baeren/feuertatze")
	_check(
		is_equal_approx(
			(
				(zergling["attack_damage"] / zergling["attack_interval"])
				/ (hydra["attack_damage"] / hydra["attack_interval"])
			),
			(5.0 / 8.0) / (10.0 / 15.0)
		),
		"Zergling : Hydralisk damage-per-second ratio matches SC1"
	)
	_check(Factions.HP_FACTOR == 3.0, "HP_FACTOR is applied on top (3x)")


func _check_resources():
	var nodes = get_nodes_in_group("resource_units")
	_check(nodes.size() >= 60, "map has many resource nodes (%d)" % nodes.size())
	var min_distance = INF
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			var a = nodes[i].global_position * Vector3(1, 0, 1)
			var b = nodes[j].global_position * Vector3(1, 0, 1)
			min_distance = min(min_distance, a.distance_to(b))
	_check(min_distance > 1.0, "no two resource nodes overlap (closest %.1f m)" % min_distance)
	var field_nodes = nodes.filter(func(n): return n.name.begins_with("Field"))
	_check(field_nodes.size() >= 40, "extra generated fields exist (%d)" % field_nodes.size())


# --- Treffer, Ränge, Upgrades -------------------------------------------------------------------


func _check_hits_and_ranks(me, enemy):
	var attacker = _spawn_unit(me, "shibas/trooper", Vector3(40, 0, 60))
	var target = _spawn_unit(enemy, "baeren/kodiak", Vector3(44, 0, 60))
	await _frames(3)
	var hp_before = target.hp
	target.take_hit(1.0, attacker)
	_check(is_equal_approx(hp_before - target.hp, 1.0 - 1.0 / 6.0), "armor reduces every hit")
	hp_before = target.hp
	target.take_hit(0.0, attacker)
	_check(is_equal_approx(hp_before - target.hp, 0.083), "a hit always does minimum damage")
	me.upgrade_weapons = 2
	hp_before = target.hp
	target.take_hit(1.0, attacker)
	_check(
		is_equal_approx(hp_before - target.hp, 1.3 - 1.0 / 6.0),
		"weapon upgrade raises damage by 15 percent per level"
	)
	me.upgrade_weapons = 0
	enemy.upgrade_armor = 1
	hp_before = target.hp
	target.take_hit(1.0, attacker)
	_check(
		is_equal_approx(hp_before - target.hp, (1.0 - 1.0 / 6.0) / 1.15),
		"armor upgrade reduces damage taken"
	)
	enemy.upgrade_armor = 0
	_check(attacker.rank == 0, "new units are recruits")
	var max_before = attacker.hp_max
	var victim = _spawn_unit(enemy, "baeren/grunzer", Vector3(46, 0, 64))
	await _frames(2)
	victim.take_hit(victim.hp + 1.0, attacker)
	_check(attacker.kills >= 1.0, "a kill is credited to the attacker")
	for i in 2:
		var more = _spawn_unit(enemy, "shibas/tesla", Vector3(46 + 3 * i, 0, 68))
		await _frames(2)
		more.take_hit(more.hp + 1.0, attacker)
	_check(attacker.rank >= 1, "enough kills promote to Veteran")
	_check(
		is_equal_approx(attacker.hp_max, max_before * 1.25), "Veteran has 25 percent more health"
	)
	var boosted = target.hp
	target.take_hit(1.0, attacker)
	_check(
		is_equal_approx(boosted - target.hp, 1.25 - 1.0 / 6.0), "Veteran deals 25 percent more damage"
	)
	attacker.grant_promotion()
	_check(attacker.rank == 2, "promotion adds exactly one rank")
	attacker.hp = 0
	target.hp = 0
	await _frames(2)


# --- Befehle -----------------------------------------------------------------------------------


func _check_commands(me):
	var origin = _free_point(Vector3(30, 0, 40))
	var unit = _spawn_unit(me, "shibas/trooper", origin)
	await _frames(4)
	_match.send_command("attack_move", [unit], [_pt(origin, 0, 12), false])
	await _frames(2)
	_check(
		unit.action != null and unit.action.get_script().resource_path.ends_with("AttackMoving.gd"),
		"attack-move starts the attack-march action"
	)
	var arrived = await _wait_until(
		func(): return unit.global_position.distance_to(_pt(origin, 0, 12)) < 2.0, 25.0
	)
	_check(arrived, "attack-moving unit reaches the target when nothing is in the way")
	await _frames(3)
	_match.send_command("terrain", [unit], [_pt(origin, 6, 12)])
	await _frames(2)
	_match.send_command("queue_move", [unit], [_pt(origin, 6, 4)])
	_match.send_command("queue_move", [unit], [_pt(origin, 0, 4)])
	_check(unit.order_queue.size() == 2, "shift-orders are queued behind the current move")
	var finished = await _wait_until(
		func(): return unit.global_position.distance_to(_pt(origin, 0, 4)) < 2.0, 40.0
	)
	_check(finished and unit.order_queue.is_empty(), "queued waypoints are visited in order")
	_match.send_command("terrain", [unit], [_pt(origin, 0, 20)])
	_match.send_command("queue_move", [unit], [_pt(origin, -10, 20)])
	await _frames(3)
	_match.send_command("stop", [unit])
	await _frames(3)
	var stopped_at = unit.global_position
	await _frames(20)
	_check(unit.order_queue.is_empty(), "stop clears the order queue")
	_check(unit.global_position.distance_to(stopped_at) < 0.5, "stopped unit stays put")
	unit.hp = 0
	await _frames(2)


func _check_crushing(me, enemy):
	var crushing = _match.get_node_or_null("Crushing")
	_check(crushing != null, "match has the crush system")
	if crushing == null:
		return
	var tank = _spawn_unit(me, "shibas/tesla", Vector3(60, 0, 20))
	var victim = _spawn_unit(enemy, "baeren/grunzer", Vector3(62.5, 0, 20))
	var bystander = _spawn_unit(me, "shibas/trooper", Vector3(62.7, 0, 20.5))
	await _frames(3)
	crushing.crush_step()
	tank.global_position = Vector3(61.8, 0, 20)
	crushing.crush_step()
	await _frames(3)
	_check(not is_instance_valid(victim) or victim.hp <= 0, "a moving tank crushes enemy infantry")
	_check(is_instance_valid(bystander) and bystander.hp > 0, "own infantry is not crushed")
	var standing_victim = _spawn_unit(enemy, "baeren/grunzer", Vector3(61.9, 0, 21))
	await _frames(3)
	crushing.crush_step()
	crushing.crush_step()
	_check(standing_victim.hp > 0, "a standing tank crushes nothing")
	tank.hp = 0
	standing_victim.hp = 0
	bystander.hp = 0
	await _frames(2)


func _check_garrison(me):
	var bunker = _spawn_structure(me, "shibas/turret_ground", Vector3(75, 0, 30))
	var soldier = _spawn_unit(me, "shibas/trooper", Vector3(75, 0, 33))
	await _frames(4)
	var base_damage = bunker.attack_damage
	var base_range = bunker.attack_range
	soldier.action = load("res://source/match/units/actions/Loading.gd").new(bunker)
	var boarded = await _wait_until(func(): return bunker.cargo_count == 1, 15.0)
	_check(boarded, "infantry can garrison an own bunker")
	_check(is_equal_approx(bunker.attack_damage, base_damage * 1.4), "garrison adds 40 percent damage per soldier")
	_check(is_equal_approx(bunker.attack_range, base_range + 0.75), "garrison adds range")
	_match.send_command("unload", [bunker])
	await _frames(3)
	_check(bunker.cargo_count == 0 and is_equal_approx(bunker.attack_damage, base_damage), "unloading restores the bunker")
	_check(_own(me).any(func(u): return u.variant == "shibas/trooper" and u.global_position.distance_to(bunker.global_position) < 4.0), "the soldier is back on the field")
	for u in _own(me).filter(func(u): return u.global_position.distance_to(bunker.global_position) < 5.0):
		u.hp = 0
	await _frames(2)


func _check_economy_commands(me):
	me.resource_a = 100
	me.resource_b = 100
	var power = _spawn_structure(me, "shibas/power", Vector3(70, 0, 80))
	await _frames(3)
	var before_a = me.resource_a
	_match.send_command("sell", [power])
	await _frames(3)
	_check(
		not is_instance_valid(power) or power.is_queued_for_deletion(), "sold structure disappears"
	)
	_check(me.resource_a == before_a + 1, "selling refunds half of the price (3 -> 1)")
	me.resource_a = 100
	me.resource_b = 100
	_match.send_command("research", [], ["weapons"])
	await _frames(2)
	_check(me.resource_a == 100, "research is refused without a lab")
	var lab = _spawn_structure(me, "shibas/lab", Vector3(80, 0, 80))
	await _frames(3)
	_match.send_command("research", [], ["weapons"])
	await _frames(2)
	_check(me.resource_a == 97 and me.resource_b == 98, "weapons research level 1 costs 3/2")
	_match.send_command("research", [], ["weapons"])
	await _frames(2)
	_check(me.resource_a == 97, "the same upgrade cannot be started twice")
	Engine.time_scale = 20.0
	var done = await _wait_until(func(): return me.upgrade_weapons == 1, 40.0)
	Engine.time_scale = 1.0
	_check(done, "research finishes and raises the level")
	_check(
		Factions.research_info(me, "weapons")["level"] == 2,
		"next level is offered after the first one finished"
	)
	me.upgrade_weapons = 3
	_check(Factions.research_info(me, "weapons").is_empty(), "no research beyond the maximum level")
	me.upgrade_weapons = 0
	lab.hp = 0


func _check_crates(me):
	var crates = _match.get_node_or_null("Crates")
	_check(crates != null, "match has a crate manager")
	if crates == null:
		return
	var collector = _spawn_unit(me, "shibas/trooper", Vector3(20, 0, 70))
	await _frames(3)
	var id = crates.spawn_random("scrap")
	_check(id > 0 and crates.crate_count() == 1, "a crate can appear on the map")
	var a_before = me.resource_a
	crates.pickup(id, collector)
	_check(crates.crate_count() == 0, "picked-up crate is removed")
	_check(me.resource_a == a_before + 8, "scrap crate gives resources")
	id = crates.spawn_random("veteran")
	crates.pickup(id, collector)
	_check(collector.rank == 1, "veteran crate promotes the collector")
	var neighbour = _spawn_unit(me, "shibas/zapper", Vector3(22, 0, 70))
	await _frames(3)
	collector.hp = collector.hp_max * 0.2
	neighbour.hp = 1.0
	id = crates.spawn_random("heal")
	crates.pickup(id, collector)
	_check(
		(
			is_equal_approx(neighbour.hp, neighbour.hp_max)
			and is_equal_approx(collector.hp, collector.hp_max)
		),
		"heal crate heals nearby own units"
	)
	collector.hp = 0
	neighbour.hp = 0


func _check_surrender(me):
	await _frames(3)
	var mine = _own(me)
	_check(mine.size() > 0, "player has units before surrendering")
	_match.send_command("surrender", mine)
	await _frames(5)
	_check(_own(me).is_empty(), "surrender destroys all own units and structures")


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


## Gebäude sofort fertig gestellt.
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
	print("generals_test: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)


## Ein freier Punkt in der Nähe (keine Rohstoffknoten, Gebäude oder Einheiten ringsum), damit Tests
## nicht von zufällig platzierten Feldern behindert werden.
func _free_point(near):
	for radius in range(0, 40, 3):
		for step in 12:
			var angle = TAU * step / 12.0
			var candidate = near + Vector3(cos(angle), 0, sin(angle)) * radius
			if candidate.x < 8 or candidate.z < 8 or candidate.x > 100 or candidate.z > 100:
				continue
			var blocked = false
			for node in get_nodes_in_group("resource_units"):
				if node.global_position.distance_to(candidate) < 6.0:
					blocked = true
					break
			if blocked:
				continue
			for unit in get_nodes_in_group("units"):
				if unit.global_position.distance_to(candidate) < 5.0:
					blocked = true
					break
			if not blocked:
				return candidate
	return near


var _point_cache = {}


## Freier Punkt relativ zu "origin", für gleiche Offsets immer derselbe.
func _pt(origin, dx, dz):
	var key = Vector3(dx, 0, dz)
	if not key in _point_cache:
		_point_cache[key] = _free_point(origin + key)
	return _point_cache[key]
