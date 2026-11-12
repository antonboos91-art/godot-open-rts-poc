## Lässt KI-Partien (Team gegen Team) mehrere Runden laufen und misst, wie lange ein Team braucht.
## Jede Runde wird auf Fehler geprüft (Skriptfehler im Protokoll, Hänger ohne Fortschritt, Einheiten,
## die nie ankommen) und das Ergebnis ausgegeben.
##   godot4 --headless -s tests/automated/ai_matches_test.gd -- [karte] [runden] [max_sekunden] [zeitraffer]
## Beispiel: ... -- res://source/match/maps/Highlands4.tscn 3 2400 12
extends SceneTree

var _map_path = "res://source/match/maps/Highlands4.tscn"
var _rounds = 3
var _max_seconds = 2400.0
var _time_scale = 12.0
var _first_round = 0
var _failures = 0
var Factions = null
var Constants = null
var _faction_cycle = []


func _initialize():
	_run()


func _run():
	await process_frame
	Factions = load("res://source/match/factions/Factions.gd")
	Constants = root.get_node("/root/Constants")
	load("res://source/match/units/Facility.gd").telegraph_seconds = 1.5
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_map_path = args[0]
	if args.size() > 1:
		_rounds = int(args[1])
	if args.size() > 2:
		_max_seconds = float(args[2])
	if args.size() > 3:
		_time_scale = float(args[3])
	if args.size() > 4:
		_first_round = int(args[4])
	_faction_cycle = [
		[Factions.SHIBAS, Factions.KATZEN, Factions.BAEREN, Factions.SHIBAS],
		[Factions.KATZEN, Factions.BAEREN, Factions.SHIBAS, Factions.KATZEN],
		[Factions.BAEREN, Factions.SHIBAS, Factions.KATZEN, Factions.BAEREN],
	]
	var results = []
	for round in _rounds:
		results.append(await _play_round(round + _first_round))
	print("=== AI MATCH SUMMARY (%s, %d rounds) ===" % [_map_path, _rounds])
	var durations = []
	for r in results:
		print(
			"round %d: winner=%s after %.0f s (game time), left=%d units, problems=%d"
			% [r["round"], r["winner"], r["seconds"], r["units_left"], r["problems"].size()]
		)
		for problem in r["problems"]:
			print("   problem: ", problem)
		if r["winner"] != "none":
			durations.append(r["seconds"])
	if not durations.is_empty():
		var sum = 0.0
		for d in durations:
			sum += d
		print("average time to victory: %.0f s over %d finished rounds" % [sum / durations.size(), durations.size()])
	_failures = results.filter(func(r): return r["winner"] == "none" or not r["problems"].is_empty()).size()
	print("ai_matches_test: %s" % ("OK" if _failures == 0 else "%d ROUNDS WITH PROBLEMS" % _failures))
	quit(_failures)


func _play_round(round):
	var result = {"round": round + 1, "winner": "none", "seconds": 0.0, "units_left": 0, "problems": []}
	var match_node = await _start_match(round)
	if match_node == null:
		result["problems"].append("match did not start")
		return result
	paused = false
	Engine.time_scale = _time_scale
	var game_seconds = 0.0
	var last_progress_s = 0.0
	var last_signature = ""
	var sample_s = 0.0
	while game_seconds < _max_seconds:
		await process_frame
		var step = root.get_process_delta_time()
		game_seconds += step
		sample_s += step
		if sample_s < 5.0:
			continue
		sample_s = 0.0
		var players = get_nodes_in_group("players")
		var alive = {}
		var total = 0
		for unit in get_nodes_in_group("units"):
			alive[unit.player] = alive.get(unit.player, 0) + 1
			total += 1
		var remaining = alive.keys()
		if not remaining.is_empty() and remaining.all(func(p): return p.is_ally_of(remaining[0])):
			result["winner"] = "team %d" % remaining[0].team
			result["units_left"] = total
			break
		# Fortschritt = Summe aus Einheiten, Gebäuden, Ressourcen
		var signature = "%d/%s" % [total, players.map(func(p): return int(p.resource_a / 5)).hash()]
		if signature != last_signature:
			last_signature = signature
			last_progress_s = game_seconds
		elif game_seconds - last_progress_s > 600.0:
			result["problems"].append("no change for 600 s at %.0f s (stuck?)" % game_seconds)
			_dump_remaining()
			break
	result["seconds"] = game_seconds
	if result["winner"] == "none":
		result["units_left"] = get_nodes_in_group("units").size()
		result["problems"].append("no winner within %.0f s" % _max_seconds)
	# Teams, Einheiten mit ungewöhnlichen Werten
	for unit in get_nodes_in_group("units"):
		if unit.hp != null and (is_nan(unit.hp) or unit.hp > unit.hp_max * 1.01 + 1.0):
			result["problems"].append("unit %s has invalid hp %s/%s" % [unit.variant, unit.hp, unit.hp_max])
			break
		if not is_finite(unit.global_position.x) or abs(unit.global_position.y) > 50.0:
			result["problems"].append("unit %s left the world at %s" % [unit.variant, unit.global_position])
			break
	Engine.time_scale = 1.0
	await _cleanup()
	return result


func _start_match(round):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	settings.visibility = settings.Visibility.FULL
	var factions = _faction_cycle[round % _faction_cycle.size()]
	for i in 4:
		var player_settings = load("res://source/data-model/PlayerSettings.gd").new()
		player_settings.controller = Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		player_settings.faction = factions[i]
		player_settings.color = Constants.Player.COLORS[i]
		player_settings.team = 1 if i < 2 else 2
		player_settings.difficulty = 1
		settings.players.append(player_settings)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = _map_path
	root.add_child(loading)
	var waited = 0.0
	while waited < 180.0:
		await process_frame
		waited += root.get_process_delta_time()
		var match_node = root.get_node_or_null("Match")
		if match_node != null and match_node.is_node_ready() and get_nodes_in_group("units").size() >= 12:
			return match_node
	return null


func _cleanup():
	paused = false  # das Spielende-Menü pausiert den Baum
	var match_node = root.get_node_or_null("Match")
	if match_node != null:
		match_node.queue_free()
	var loading = root.get_node_or_null("Loading")
	if loading != null:
		loading.queue_free()
	for i in 10:
		await process_frame


## Bei einem Hänger: wer ist noch übrig, wo steht er, was tut er?
func _dump_remaining():
	for unit in get_nodes_in_group("units"):
		print(
			"   left: p%d %s at %s hp %.1f action %s visible %s"
			% [
				unit.player.get_index(),
				unit.variant,
				unit.global_position,
				unit.hp,
				str(unit.action) if unit.action != null else "none",
				unit.visible
			]
		)
