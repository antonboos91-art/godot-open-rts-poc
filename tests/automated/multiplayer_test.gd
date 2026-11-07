## Startet Host und Client als zwei Godot-Prozesse und prüft die Synchronisation:
##   godot4 --headless -s tests/automated/multiplayer_test.gd -- --role=host &
##   godot4 --headless -s tests/automated/multiplayer_test.gd -- --role=client
## Der Client gibt Befehle und prüft, ob der Host sie ausführt und zurückspiegelt.
extends SceneTree

const MAP_PATH = "res://source/match/maps/PlainAndSimple.tscn"
const WORKER_SCENE = "res://source/match/units/Worker.tscn"

var _failures = 0


func _initialize():
	var role = "host"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.split("=")[1]
	if role == "host":
		_run_host()
	else:
		_run_client()


func _run_host():
	await process_frame
	var network = root.get_node("/root/Network")
	network.set_local_faction("shibas")
	_check(network.host("Host") == OK, "host started")
	if not await _wait_until(func(): return network.peers.size() == 2, 20.0):
		_finish(false, "no client joined")
		return
	network.start_match(MAP_PATH, true, true)
	var a_match = await _wait_for_match()
	_check(a_match != null, "host match loaded")
	var ais = get_nodes_in_group("players").filter(func(p): return p.peer_id == 0)
	var humans = get_nodes_in_group("players").filter(func(p): return p.peer_id > 0)
	_check(ais.size() == 2 and ais[0].is_ally_of(ais[1]), "AI players are allied")
	_check(not humans[0].is_ally_of(ais[0]), "humans and AI are enemies")
	# Startkapital für alle Menschen, damit der Client produzieren kann
	await _wait_until(func(): return get_nodes_in_group("units").size() >= 16, 10.0)
	for player in get_nodes_in_group("players"):
		if player.peer_id > 0:
			player.resource_a = 10
			player.resource_b = 10
	# Zusatz für Fähigkeiten: Höhlen-Mobil für den Client, geladene Superwaffe beim Host
	var Factions = load("res://source/match/factions/Factions.gd")
	var signals = root.get_node("/root/MatchSignals")
	for player in get_nodes_in_group("players"):
		if player.peer_id > 1:
			var mcv = load(Factions.entry("baeren/hoehlenmobil")["archetype"]).instantiate()
			mcv.variant = "baeren/hoehlenmobil"
			var hq = get_nodes_in_group("units").filter(func(u): return u.player == player and u.variant == "baeren/hq")[0]
			signals.setup_and_spawn_unit.emit(
				mcv, Transform3D(Basis(), hq.global_position + Vector3(-9, 0, 7)), player
			)
		elif player.peer_id == 1:
			var sw = load(Factions.entry("shibas/superweapon")["archetype"]).instantiate()
			sw.variant = "shibas/superweapon"
			var hq = get_nodes_in_group("units").filter(func(u): return u.player == player and u.variant == "shibas/hq")[0]
			signals.setup_and_spawn_unit.emit(
				sw, Transform3D(Basis(), hq.global_position + Vector3(-12, 0, -8)), player
			)
			sw.construct(1.0)
			await process_frame
			sw.charge_progress = 0.5
	# Warten bis der Client fertig ist (er trennt die Verbindung)
	await _wait_until(func(): return network.peers.size() == 1, 90.0)
	for p in get_nodes_in_group("players"):
		print(
			"  host player ",
			p.name,
			" peer ",
			p.peer_id,
			" units ",
			p.get_children().filter(func(c): return c.is_in_group("units")).size(),
			" res ",
			p.resource_a,
			"/",
			p.resource_b
		)
	var client_players = get_nodes_in_group("players").filter(func(p): return p.peer_id > 1)
	_check(client_players.size() == 1, "host has one remote human player")
	_finish(true, "host")


func _run_client():
	await process_frame
	var network = root.get_node("/root/Network")
	network.set_local_faction("baeren")
	_check(network.join("127.0.0.1", "Client") == OK, "client connecting")
	var a_match = await _wait_for_match()
	if a_match == null:
		_finish(false, "client match not loaded")
		return
	var got_units = await _wait_until(
		func(): return get_nodes_in_group("controlled_units").size() >= 4, 20.0
	)
	_check(got_units, "client received own units from host")
	await create_timer(1.0).timeout
	print("units on client: ", get_nodes_in_group("units").size())
	for p in get_nodes_in_group("players"):
		print(
			"  client player ",
			p.name,
			" peer ",
			p.peer_id,
			" units ",
			p.get_children().filter(func(c): return c.is_in_group("units")).size(),
			" res ",
			p.resource_a,
			"/",
			p.resource_b
		)
	_check(get_nodes_in_group("adversary_units").size() >= 8, "client sees both AI players' units")
	_check(get_nodes_in_group("allied_units").size() >= 4, "host's units are allied on client")
	var auto_attacking = load("res://source/match/units/actions/AutoAttacking.gd")
	var my_unit = get_nodes_in_group("controlled_units")[0]
	_check(
		get_nodes_in_group("allied_units").all(
			func(u): return not auto_attacking.is_applicable(my_unit, u)
		),
		"allies cannot be attacked"
	)

	var me = get_nodes_in_group("players").filter(func(p): return p.is_local())[0]
	_check(me.peer_id == root.multiplayer.get_unique_id(), "local player has own peer id")
	_check(me.faction == "baeren", "client plays the faction chosen in the lobby")
	_check(
		get_nodes_in_group("controlled_units").all(
			func(u): return u.variant.begins_with("baeren/")
		),
		"faction variants of own units replicated to client"
	)
	var hq = get_nodes_in_group("controlled_units").filter(func(u): return u.variant == "baeren/hq")
	_check(not hq.is_empty() and hq[0].hp_max == 30, "variant stats applied on client")

	# Bewegungsbefehl
	var worker = get_nodes_in_group("controlled_units").filter(func(u): return u.get_script().resource_path.ends_with("Worker.gd"))[0]
	var start = worker.global_position
	a_match.send_command("terrain", [worker], [start + Vector3(6, 0, 0)])
	var moved = await _wait_until(
		func(): return worker.global_position.distance_to(start) > 3.0, 8.0
	)
	_check(moved, "move command executed by host and synced back")
	print("worker moved ", start, " -> ", worker.global_position)

	# Fähigkeiten: Superwaffen-Ladestand des Verbündeten kommt an, Bau-Mobil entfalten
	var sw_on_client = await _wait_until(
		func():
			return get_nodes_in_group("allied_units").any(
				func(u): return u.variant == "shibas/superweapon" and u.charge_progress == 0.5
			),
		8.0
	)
	_check(sw_on_client, "superweapon charge is replicated to the client")
	var mcvs = get_nodes_in_group("controlled_units").filter(
		func(u): return u.variant == "baeren/hoehlenmobil"
	)
	_check(not mcv_list_empty(mcvs), "client received its Höhlen-Mobil")
	var hqs_before = (
		get_nodes_in_group("controlled_units")
		. filter(func(u): return u.variant == "baeren/hq")
		. size()
	)
	if not mcvs.is_empty():
		a_match.send_command("deploy", [mcvs[0]])
		var unfolded = await _wait_until(
			func():
				return (
					(
						get_nodes_in_group("controlled_units")
						. filter(func(u): return u.variant == "baeren/hq")
						. size()
					)
					== hqs_before + 1
				),
			8.0
		)
		_check(unfolded, "client unfolds Höhlen-Mobil into a Bunkerhöhle")
		_check(
			not is_instance_valid(mcvs[0]) or mcvs[0].is_queued_for_deletion(),
			"Höhlen-Mobil is gone"
		)

	# Produktion
	var command_center = get_nodes_in_group("controlled_units").filter(func(u): return u.get_script().resource_path.ends_with("CommandCenter.gd"))[0]
	var got_resources = await _wait_until(func(): return me.resource_a == 10, 5.0)
	_check(got_resources, "resources set on host are synced to client")
	var resources_before = me.resource_a + me.resource_b
	var units_before = get_nodes_in_group("controlled_units").size()
	command_center.production_queue.produce(load(WORKER_SCENE))
	var produced = await _wait_until(
		func(): return get_nodes_in_group("controlled_units").size() > units_before, 10.0
	)
	print("resources ", resources_before, " -> ", me.resource_a + me.resource_b)
	_check(produced, "production command spawned a worker on the client")
	_check(me.resource_a + me.resource_b < resources_before, "resources synced after production")

	# Gebäude platzieren: Arbeiter sollen es bauen, Fortschritt kommt zum Client
	var structures_before = _own_structures().size()
	var build_spot = Transform3D(Basis(), command_center.global_position + Vector3(-7, 0, 6))
	a_match.send_command("place_structure", [worker], ["baeren/power", build_spot])
	var placed = await _wait_until(func(): return _own_structures().size() > structures_before, 5.0)
	_check(placed, "structure placed by client appears")
	if placed:
		var factory = _own_structures().filter(func(u): return u.is_under_construction())
		_check(not factory.is_empty(), "new structure is under construction on client")
		_check(
			not factory.is_empty() and factory[0].variant == "baeren/power",
			"placed structure is the Diesel-Brummer"
		)
		if not factory.is_empty():
			var progressed = await _wait_until(
				func(): return not is_instance_valid(factory[0]) or factory[0].hp > 1, 15.0
			)
			_check(progressed, "construction progress synced (hp rising)")
	_finish(true, "client")


func mcv_list_empty(list):
	return list.is_empty()


func _own_structures():
	return get_nodes_in_group("controlled_units").filter(
		func(u): return u.has_method("is_constructed")
	)


func _wait_for_match():
	var ok = await _wait_until(
		func():
			return root.get_node_or_null("Match") != null and root.get_node("Match").is_node_ready(),
		20.0
	)
	return root.get_node_or_null("Match") if ok else null


func _wait_until(condition, timeout_sec):
	var waited = 0.0
	while waited < timeout_sec:
		if condition.call():
			return true
		await process_frame
		waited += root.get_process_delta_time()
	return condition.call()


func _check(condition, label):
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_failures += 1


func _finish(ok, label):
	if not ok:
		_failures += 1
	print("multiplayer_test %s: %s" % [label, "OK" if _failures == 0 else "%d FAILED" % _failures])
	root.get_node("/root/Network").leave()
	await process_frame
	quit(_failures)
