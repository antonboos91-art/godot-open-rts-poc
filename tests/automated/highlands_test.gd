## Prüft die großen Hochland-Karten: Plateaus mit Rampen, Navigation über Rampen statt Klippen,
## Höhenvorteil bei der Sicht, Rohstoffe auf der richtigen Höhe und eine laufende Wirtschaft.
##   godot4 --headless -s tests/automated/highlands_test.gd
extends SceneTree

const MAP_PATH = "res://source/match/maps/Highlands4.tscn"

var _failures = 0
var _match = null
var Factions = null
var Constants = null
var MatchSignals = null
var Heights = null


func _initialize():
	_run()


func _run():
	await process_frame
	Factions = load("res://source/match/factions/Factions.gd")
	Heights = load("res://source/match/Heights.gd")
	Constants = root.get_node("/root/Constants")
	MatchSignals = root.get_node("/root/MatchSignals")
	var started = Time.get_ticks_msec()
	_match = await _start_match()
	print("load time ms: ", Time.get_ticks_msec() - started)
	if _match == null:
		_check(false, "match started")
		_finish()
		return
	await _wait_until(func(): return get_nodes_in_group("units").size() >= 20, 30.0)
	var players = get_nodes_in_group("players")
	var me = players[0]
	var map = _match.map

	_check(Heights.active and Heights.plateaus.size() == 4, "the map has four plateaus")
	_check(map.size == Vector2(240, 240), "the map is 240 m wide")
	var hq = _own(me).filter(func(u): return u.variant == "shibas/hq")[0]
	_check(is_equal_approx(hq.global_position.y, 3.0), "the base stands on its plateau (y=%.2f)" % hq.global_position.y)
	for plateau in Heights.plateaus:
		_check(
			is_equal_approx(Heights.at(plateau["center"].x, plateau["center"].y), 3.0),
			"plateau top is flat"
		)
	var terrain = map.find_child("Terrain", true, false)
	_check(terrain.mesh is ArrayMesh, "terrain is a height mesh")

	# Rohstoffe liegen auf der Höhe ihrer Basis bzw. im Tiefland
	var nodes = get_nodes_in_group("resource_units")
	_check(nodes.size() >= 120, "large maps have many resource nodes (%d)" % nodes.size())
	_check(
		nodes.all(func(n): return is_equal_approx(n.global_position.y, Heights.at(n.global_position.x, n.global_position.z))),
		"every resource node sits on the ground"
	)
	var on_plateau = nodes.filter(func(n): return n.global_position.y > 2.5)
	_check(on_plateau.size() >= 40, "bases have their own mineral lines on the plateau (%d)" % on_plateau.size())

	# Navigation: Rampe ja, Klippe nein
	var nav_rid = _match.navigation.get_navigation_map_rid_by_domain(Constants.Match.Navigation.Domain.TERRAIN)
	var center = Vector3(map.size.x / 2.0, 0.0, map.size.y / 2.0)
	var path = NavigationServer3D.map_get_path(nav_rid, hq.global_position, center, true)
	_check(path.size() > 2, "there is a path from the base to the map center (%d points)" % path.size())
	if path.size() > 2:
		_check(path[path.size() - 1].distance_to(center) < 4.0, "the path reaches the center")
		_check(path[path.size() - 1].y < 1.0 and path[0].y > 2.0, "the path leads down from the plateau")
	var plateau = Heights.plateaus[0]
	var behind = plateau["center"] - plateau["ramp_dir"] * (plateau["radius"] + 6.0)
	var behind3 = Vector3(behind.x, 0.0, behind.y)
	var inside = Vector3(plateau["center"].x, 3.0, plateau["center"].y)
	var around = NavigationServer3D.map_get_path(nav_rid, behind3, inside, true)
	var straight = behind3.distance_to(inside)
	var length = 0.0
	for i in range(1, around.size()):
		length += around[i - 1].distance_to(around[i])
	var end_point = around[around.size() - 1] if not around.is_empty() else behind3
	_check(
		length > straight * 1.25 or end_point.distance_to(inside) > 3.0,
		"the cliff side is not climbable (path %.0f m for %.0f m, ends %.1f m from the target)" % [length, straight, end_point.distance_to(inside)]
	)

	# Höhenvorteil
	var low = _spawn_unit(players[1], "katzen/streuner", Vector3(plateau["center"].x - plateau["ramp_dir"].x * 40.0, 0.0, plateau["center"].y - plateau["ramp_dir"].y * 40.0))
	var high = _spawn_unit(me, "shibas/trooper", Vector3(plateau["center"].x, 3.0, plateau["center"].y + 1.0))
	await _frames(4)
	_check(not Heights.can_see_node(low, high), "low ground cannot see the high ground")
	_check(Heights.can_see_node(high, low), "high ground sees the low ground")
	var flyer = _spawn_unit(players[1], "katzen/nachtfalter", low.global_position)
	await _frames(3)
	_check(Heights.can_see_node(flyer, high), "flyers see the high ground")
	low.hp = 0
	flyer.hp = 0

	# Klicks auf Hänge treffen das Gelände (Strahl statt Ebene)
	var origin = Vector3(plateau["center"].x - 30.0, 40.0, plateau["center"].y + 30.0)
	var direction = (Vector3(plateau["center"].x, 3.0, plateau["center"].y) - origin).normalized()
	var hit = Heights.ray_intersection(origin, direction)
	_check(hit != null and is_equal_approx(hit.y, 3.0) or (hit != null and absf(hit.y - Heights.at(hit.x, hit.z)) < 0.01), "ray picking hits the terrain surface")

	# Einheiten laufen die Rampe hinunter
	_match.send_command("terrain", [high], [center])
	var arrived = await _wait_until(func(): return high.global_position.distance_to(center) < 8.0, 120.0)
	_check(arrived, "a unit walks down the ramp to the center (y=%.2f)" % high.global_position.y)
	_check(high.global_position.y < 1.0, "it ends up on low ground")
	high.hp = 0

	# Wirtschaft läuft auf dem Plateau
	me.resource_a = 20
	var scrap_before = me.resource_a
	for i in 2:
		hq.production_queue.produce("shibas/sammler", true)
	Engine.time_scale = 8.0
	var earned = false
	for round in 4:
		earned = await _wait_until(func(): return me.resource_a + me.resource_b > scrap_before + 4, 30.0)
		pass
		if earned:
			break
	Engine.time_scale = 1.0
	_check(earned, "workers on the plateau collect and deliver resources")
	_finish()


func _start_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	var setup = [
		[Constants.PlayerType.HUMAN, Factions.SHIBAS],
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, Factions.KATZEN],
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, Factions.BAEREN],
		[Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI, Factions.SHIBAS],
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
		120.0
	)
	return root.get_node_or_null("Match") if ok else null


func _own(player):
	return get_nodes_in_group("units").filter(func(u): return u.player == player)


func _spawn_unit(player, variant, position):
	var unit = load(Factions.entry(variant)["archetype"]).instantiate()
	unit.variant = variant
	MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), position), player)
	return unit


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
	print("highlands_test: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)
