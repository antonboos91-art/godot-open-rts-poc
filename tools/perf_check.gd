## Bildrate messen: echte Partie (Spieler + 2 KI) auf einer Karte, misst FPS und Frame-Zeiten,
## optional mit abgeschalteten Teilen. godot4 --path . -s tools/perf_check.gd -- <karte> <aus: mist,lights,ash,ssao,shadows,glow,nature>
extends SceneTree

var _off = []
var _map = "PlainAndSimple"


func _initialize():
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_map = args[0]
	if args.size() > 1:
		_off = args[1].split(",")
	_run()


func _run():
	await process_frame
	var Constants = root.get_node("/root/Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.visible_player = 0
	var facs = ["shibas", "katzen", "baeren"]
	for i in range(3):
		var ps = load("res://source/data-model/PlayerSettings.gd").new()
		ps.controller = Constants.PlayerType.HUMAN if i == 0 else Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		ps.faction = facs[i]
		ps.color = Constants.Player.COLORS[i]
		settings.players.append(ps)
	var loading = load("res://source/main-menu/Loading.tscn").instantiate()
	loading.match_settings = settings
	loading.map_path = "res://source/match/maps/%s.tscn" % _map
	root.add_child(loading)
	while root.get_node_or_null("Match") == null or not root.get_node("Match").is_node_ready():
		await process_frame
	var m = root.get_node("Match")
	Engine.time_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in 120:
		await process_frame
	_apply_off(m)
	if "battle" in _off or "battlefx" in _off:
		_spawn_battle(m)
	if "battlefx" in _off:
		Engine.set_meta("combatfx_off", true)
	for i in 60:
		await process_frame
	var times = []
	var t0 = Time.get_ticks_usec()
	var last = t0
	while Time.get_ticks_usec() - t0 < 8000000:
		await process_frame
		for key in ["Infantry3D", "SpriteVehicle", "HealthBar", "UnitVisibilityHandler", "FogOfWar", "Minimap", "Selection"]:
			if Engine.has_meta("perf_kill_" + key):
				for n in m.find_children(key + "*", "", true, false):
					n.set_process(false)
					n.set_physics_process(false)
		var now = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var spikes = []
	for i in times.size():
		if times[i] > 25.0:
			spikes.append("%d:%.0f" % [i, times[i]])
	print("PERF spikes ", spikes.size(), " ", spikes)
	times.sort()
	var avg = 0.0
	for x in times:
		avg += x
	avg /= times.size()
	var lights = 0
	for n in m.find_children("*", "Light3D", true, false):
		lights += 1
	print("PERF map=%s off=%s frames=%d avg_ms=%.2f fps=%.1f p95_ms=%.2f max_ms=%.2f lights=%d units=%d objects=%d" % [
		_map, ",".join(_off), times.size(), avg, 1000.0 / avg, times[int(times.size() * 0.95)], times[-1], lights,
		get_nodes_in_group("units").size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	print("PERF render_draw_calls=%d render_objects=%d process_ms=%.2f physics_ms=%.2f nav_ms=%.2f" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0])
	quit(0)


func _spawn_battle(m):
	var Factions = load("res://source/match/factions/Factions.gd")
	var MatchSignals = root.get_node("/root/MatchSignals")
	var players = get_nodes_in_group("players")
	var c = m.map.size / 2.0
	var sets = [["shibas/trooper", "shibas/tesla"], ["katzen/streuner", "katzen/prisma"], ["baeren/grunzer", "baeren/grizzly"]]
	var offs = [Vector3(-7, 0, 0), Vector3(7, 0, 0), Vector3(0, 0, -7)]
	for p in 3:
		for i in 20:
			var v = sets[p][0] if i % 4 != 0 else sets[p][1]
			var u = load(Factions.entry(v)["archetype"]).instantiate()
			u.variant = v
			MatchSignals.setup_and_spawn_unit.emit(u, Transform3D(Basis(), Vector3(c.x, 0, c.y) + offs[p] + Vector3((i % 5) * 1.3, 0, int(i / 5) * 1.3)), players[p])
	var cam = m.find_child("IsometricCamera3D", true, false)
	cam.set_position_safely(Vector3(c.x, 0, c.y))


func _apply_off(m):
	var env = m.find_child("WorldEnvironment", true, false).environment
	for n in m.find_children("*", "", true, false):
		if "mist" in _off and n.name.begins_with("Mist"):
			n.visible = false
		if "ash" in _off and n.name == "Ash":
			n.emitting = false
			n.visible = false
		if "lights" in _off and n.name == "UnitLights":
			n.queue_free()
		if "nature" in _off and n.name == "Nature":
			n.visible = false
	if "ssao" in _off:
		env.ssao_enabled = false
	if "glow" in _off:
		env.glow_enabled = false
	for key in ["Infantry3D", "SpriteVehicle", "HealthBar", "UnitVisibilityHandler", "FogOfWar", "Minimap", "Selection", "Movement"]:
		if key.to_lower() in _off:
			Engine.set_meta("perf_kill_" + key, true)
	if "shadows" in _off:
		m.find_child("DirectionalLight3D", true, false).shadow_enabled = false
