extends Node3D

const Unit = preload("res://source/match/units/Unit.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Player = preload("res://source/match/players/Player.gd")
const Human = preload("res://source/match/players/human/Human.gd")
const Factions = preload("res://source/match/factions/Factions.gd")

const HACK_SECONDS = 20.0
const SABOTAGE_FRACTION = 0.6

const CommandCenter = preload("res://source/match/units/CommandCenter.tscn")
const Drone = preload("res://source/match/units/Drone.tscn")
const Worker = preload("res://source/match/units/Worker.tscn")
const Infantry = preload("res://source/match/units/Infantry.tscn")

@export var settings: Resource = null

var map:
	set = _set_map,
	get = _get_map
var visible_player = null:
	set = _set_visible_player
var visible_players = null:
	set = _ignore,
	get = _get_visible_players

var _next_unit_id = 1

@onready var navigation = $Navigation
@onready var fog_of_war = $FogOfWar

@onready var _camera = $IsometricCamera3D
@onready var _players = $Players
@onready var _terrain = $Terrain


func _enter_tree():
	assert(settings != null, "match cannot start without settings, see examples in tests/manual/")
	assert(map != null, "match cannot start without map, see examples in tests/manual/")


func _ready():
	MatchSignals.setup_and_spawn_unit.connect(_setup_and_spawn_unit)
	# HUD im StarCraft-Stil (Paneele, Auswahlfeld, Portraet, Ressourcen)
	find_child("HUD", false, false).add_child(load("res://source/match/hud/HudSkin.gd").new())
	# Einheiten-Kollision (schieben sich gegenseitig auseinander)
	var separation = load("res://source/match/UnitSeparation.gd").new()
	separation.name = "UnitSeparation"
	add_child(separation)
	var crushing = load("res://source/match/Crushing.gd").new()
	add_child(crushing)
	var crates = load("res://source/match/Crates.gd").new()
	crates.name = "Crates"
	add_child(crates)
	_setup_subsystems_dependent_on_map()
	_setup_players()
	_setup_unit_spawners()
	visible_player = get_tree().get_nodes_in_group("players")[settings.visible_player]
	if settings.visibility == settings.Visibility.FULL:
		fog_of_war.reveal()
	if Network.is_client():
		# Einheiten kommen vom Host über die MultiplayerSpawner
		_setup_static_synchronizers()
		_move_camera_to_spawn_point_of(_get_human_player())
		Network.report_match_ready()
	else:
		if Network.is_online():
			if not Network.are_all_clients_ready_for_match():
				await Network.all_clients_ready_for_match
			# Erst jetzt, sonst kennen Clients die Knotenpfade noch nicht
			_setup_static_synchronizers()
		_setup_player_units()
		_move_camera_to_initial_position()
	MatchSignals.match_started.emit()


## Einheitlicher Weg für Spielerbefehle. Auf dem Host direkt ausgeführt,
## auf Clients per RPC an den Host geschickt.
func send_command(kind, units, args = []):
	if Network.is_client():
		var unit_paths = units.map(func(unit): return get_path_to(unit))
		_receive_command.rpc_id(1, kind, unit_paths, args)
	else:
		_execute_command(_get_human_player(), kind, units, args)


@rpc("any_peer", "reliable")
func _receive_command(kind, unit_paths, args):
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	var players = get_tree().get_nodes_in_group("players").filter(
		func(player): return player is Human and player.peer_id == sender
	)
	if players.is_empty():
		return
	var player = players[0]
	var units = []
	for unit_path in unit_paths:
		var unit = get_node_or_null(unit_path)
		if unit != null and unit is Unit and unit.player == player:
			units.append(unit)
	_execute_command(player, kind, units, args)


func _execute_command(player, kind, units, args):
	if player == null:
		return
	var controller = player.find_child("UnitActionsController")
	match kind:
		"terrain":
			controller.execute_terrain_targeted(units, args[0])
		"unit":
			var target_unit = get_node_or_null(args[0])
			if target_unit != null:
				controller.execute_unit_targeted(units, target_unit)
		"produce":
			if not args[0] is String or Factions.entry(args[0]).is_empty():
				return
			for unit in units:
				if unit is Structure and unit.production_queue != null:
					unit.production_queue.produce(args[0])
		"cancel_construction":
			for unit in units:
				if unit is Structure and unit.is_under_construction():
					unit.cancel_construction()
		"place_structure":
			_place_structure(player, controller, units, args[0], args[1])
		"deploy":
			for unit in units:
				_deploy(player, unit)
		"unload":
			for unit in units:
				_unload_transport(unit)
		"superweapon":
			if not args[0] is Vector3:
				return
			for unit in units:
				if unit.has_method("fire_superweapon"):
					unit.fire_superweapon(args[0])
		"stop":
			for unit in units:
				unit.order_queue.clear()
				unit.action = null
		"attack_move":
			if args[0] is Vector3:
				controller.execute_attack_move(units, args[0], args.size() > 1 and args[1] == true)
		"queue_move":
			if args[0] is Vector3:
				controller.execute_queue_move(units, args[0])
		"sell":
			for unit in units:
				_sell_structure(player, unit)
		"research":
			if args[0] is String:
				_research(player, args[0])
		"surrender":
			_surrender(player)


const SELL_REFUND = 0.5
const RESEARCH_KINDS = ["weapons", "armor"]
var _researching = {}  # Spieler -> {Art: true}


## Verkaufen (Generals "Sell"): fertiges eigenes Gebäude weg, halber Preis zurück.
func _sell_structure(player, structure):
	if not structure is Structure or not structure.is_constructed() or structure.player != player:
		return
	var cost = Factions.cost(Factions.variant_of(structure))
	player.add_resources(
		{
			"resource_a": int(cost["resource_a"] * SELL_REFUND),
			"resource_b": int(cost["resource_b"] * SELL_REFUND)
		}
	)
	_notify(structure.global_position, "VERKAUFT")
	structure.queue_free()


## Upgrade im Labor erforschen: "weapons" (+15 % Schaden) oder "armor" (-13 % Schaden) je Stufe.
func _research(player, kind):
	if not kind in RESEARCH_KINDS:
		return
	var researching = _researching.get(player, {})
	if kind in researching:
		return
	var has_lab = false
	for unit in player.get_children():
		if (
			unit is Structure
			and unit.is_constructed()
			and Factions.role(Factions.variant_of(unit)) == "lab"
		):
			has_lab = true
	var info = Factions.research_info(player, kind)
	if not has_lab or info.is_empty():
		return
	if not player.has_resources(info["cost"]):
		MatchSignals.not_enough_resources_for_production.emit(player)
		return
	player.subtract_resources(info["cost"])
	researching[kind] = true
	_researching[player] = researching
	await get_tree().create_timer(info["time"] / player.production_speed_factor()).timeout
	if not is_instance_valid(player):
		return
	player.set("upgrade_" + kind, player.get("upgrade_" + kind) + 1)
	researching.erase(kind)
	var hq = player.get_children().filter(func(u): return u is Structure)
	if not hq.is_empty():
		_notify(hq[0].global_position, "UPGRADE FERTIG")


## Aufgeben: alle Einheiten und Gebäude des Spielers werden zerstört (Niederlage).
func _surrender(player):
	for unit in player.get_children().duplicate():
		if unit is Unit:
			unit.hp = 0


func _place_structure(player, controller, workers, variant, a_transform):
	if not variant is String or not variant in Factions.buildable(player):
		return
	if not Factions.is_available(player, variant):
		return
	var construction_cost = Factions.cost(variant)
	if not player.has_resources(construction_cost):
		MatchSignals.not_enough_resources_for_construction.emit(player)
		return
	player.subtract_resources(construction_cost)
	var structure = load(Factions.entry(variant)["archetype"]).instantiate()
	structure.variant = variant
	_setup_and_spawn_unit(structure, a_transform, player)
	controller.execute_construct(workers, structure)


## Bau-Mobil entfaltet sich an Ort und Stelle zur fertigen Zentrale seines Volks.
func _deploy(_player, unit):
	if Factions.ability(Factions.variant_of(unit)) != "deploy":
		return
	var hq_variant = Factions.deploy_target(Factions.variant_of(unit))
	var hq_scene = load(Factions.entry(hq_variant)["archetype"])
	var prototype = hq_scene.instantiate()
	var others = (
		get_tree().get_nodes_in_group("units").filter(func(other): return other != unit)
		+ get_tree().get_nodes_in_group("resource_units")
	)
	var validity = Utils.Match.Unit.Placement.validate_agent_placement_position(
		unit.global_position,
		prototype.radius,
		others,
		navigation.get_navigation_map_rid_by_domain(prototype.movement_domain)
	)
	prototype.free()
	if validity != Utils.Match.Unit.Placement.VALID:
		_notify(unit.global_position, "Kein Platz zum Entfalten")
		return
	var hq = hq_scene.instantiate()
	hq.variant = hq_variant
	_setup_and_spawn_unit(hq, Transform3D(Basis(), unit.global_position), unit.player, false)
	unit._handle_unit_death()


## Infanterie steigt ein: Die Einheit wird entfernt und im Transporter gespeichert.
func board_transport(unit, transport):
	if Network.is_client() or transport.cargo_count >= Factions.cargo_capacity(transport):
		return
	transport.cargo.append({"scene": unit.scene_file_path, "variant": unit.variant, "hp": unit.hp})
	transport.cargo_count = transport.cargo.size()
	_refresh_garrison(transport)
	unit.queue_free()


## Besatzung im Bunker: je Infanterist +40 % Schaden und +0,75 m Reichweite (Basiswerte als Meta gemerkt).
func _refresh_garrison(structure):
	if Factions.ability(Factions.variant_of(structure)) != "garrison" or structure.attack_damage == null:
		return
	if not structure.has_meta("base_damage"):
		structure.set_meta("base_damage", structure.attack_damage)
		structure.set_meta("base_range", structure.attack_range)
	var count = structure.cargo_count
	structure.attack_damage = structure.get_meta("base_damage") * (1.0 + 0.4 * count)
	structure.attack_range = structure.get_meta("base_range") + 0.75 * count


## Der Transporter setzt alle Passagiere im Kreis um sich ab.
func _unload_transport(transport):
	if Network.is_client() or not "cargo" in transport or transport.cargo.is_empty():
		return
	var count = transport.cargo.size()
	for i in range(count):
		var entry = transport.cargo[i]
		var unit = load(entry["scene"]).instantiate()
		unit.variant = entry["variant"]
		var angle = TAU * i / count
		var offset = Vector3(cos(angle), 0, sin(angle)) * 2.5
		_setup_and_spawn_unit(
			unit,
			Transform3D(Basis(), transport.global_position * Vector3(1, 0, 1) + offset),
			transport.player,
			false
		)
		unit.hp = entry["hp"]
	transport.cargo.clear()
	transport.cargo_count = 0
	_refresh_garrison(transport)


## Ein Ingenieur übernimmt ein Gebäude: Es wird für den neuen Besitzer neu erzeugt
## (die Spawner hängen am Besitzer), der Ingenieur geht dabei auf.
func infiltrate_structure(structure, unit):
	if Network.is_client():
		return
	match Factions.ability(Factions.variant_of(unit)):
		"capture":
			capture_structure(structure, unit)
		"hack":
			structure.hack(HACK_SECONDS)
			_notify(structure.global_position, "GEHACKT")
		"sabotage":
			_notify(structure.global_position, "SABOTIERT")
			unit._handle_unit_death()
			structure.hp = max(0, structure.hp - int(ceil(structure.hp_max * SABOTAGE_FRACTION)))


func capture_structure(structure, capturer):
	if Network.is_client():
		return
	_notify(structure.global_position, "ÜBERNOMMEN")
	var hp_fraction = float(structure.hp) / float(structure.hp_max)
	var variant = Factions.variant_of(structure)
	var replacement = load(Factions.entry(variant)["archetype"]).instantiate()
	replacement.variant = structure.variant
	_setup_and_spawn_unit(replacement, structure.global_transform, capturer.player, false)
	structure._handle_unit_death()
	capturer._handle_unit_death()
	await get_tree().process_frame
	if is_instance_valid(replacement) and replacement.hp_max != null:
		replacement.hp = max(1, int(replacement.hp_max * hp_fraction))


func _notify(position, text):
	if Network.is_online():
		show_notice.rpc(position, text)
	else:
		show_notice(position, text)


## Kurzer Hinweistext über einer Stelle der Karte (z. B. "Kein Platz").
@rpc("authority", "call_local", "reliable")
func show_notice(position, text):
	match text:
		"GEHACKT":
			SoundEffects.play("hack", position)
		"SABOTIERT":
			SoundEffects.play("explosion_big", position)
		"ÜBERNOMMEN":
			SoundEffects.play("deploy", position)
	var label = Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.4, 0.3)
	label.pixel_size = 0.012
	label.position = position + Vector3(0, 3.0, 0)
	add_child(label)
	get_tree().create_timer(1.5).timeout.connect(label.queue_free)


## Blitz, Rakete usw. einer Superwaffe: kurzer Lichteffekt auf allen Rechnern.
@rpc("authority", "call_local", "unreliable")
func show_strike(position, radius):
	SoundEffects.play("strike", position)
	var flash = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.15
	mesh.bottom_radius = radius * 0.15
	mesh.height = 60.0
	flash.mesh = mesh
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.85, 0.95, 1.0, 1.0)
	flash.material_override = material
	flash.position = position + Vector3(0, 30, 0)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	var ring = MeshInstance3D.new()
	var ring_mesh = CylinderMesh.new()
	ring_mesh.top_radius = radius
	ring_mesh.bottom_radius = radius
	ring_mesh.height = 0.1
	ring.mesh = ring_mesh
	var ring_material = material.duplicate()
	ring_material.albedo_color = Color(0.6, 0.85, 1.0, 0.6)
	ring.material_override = ring_material
	ring.position = position + Vector3(0, 0.15, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.7)
	tween.tween_property(ring_material, "albedo_color:a", 0.0, 1.2)
	tween.chain().tween_callback(
		func():
			flash.queue_free()
			ring.queue_free()
	)


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.is_action_pressed("shift_selecting"):
			return
		MatchSignals.deselect_all_units.emit()


func _set_map(a_map):
	assert(get_node_or_null("Map") == null, "map already set")
	a_map.name = "Map"
	add_child(a_map)
	a_map.owner = self


func _ignore(_value):
	pass


func _get_map():
	return get_node_or_null("Map")


func _set_visible_player(player):
	_conceal_player_units(visible_player)
	_reveal_player_units(player)
	visible_player = player


func _get_visible_players():
	if settings.visibility == settings.Visibility.PER_PLAYER:
		# Verbündete teilen ihre Sicht
		return get_tree().get_nodes_in_group("players").filter(
			func(player): return player.is_ally_of(visible_player)
		)
	return get_tree().get_nodes_in_group("players")


func _setup_subsystems_dependent_on_map():
	_terrain.update_shape(map.find_child("Terrain").mesh)
	fog_of_war.resize(map.size)
	_recalculate_camera_bounding_planes(map.size)
	navigation.setup(map)


func _recalculate_camera_bounding_planes(map_size: Vector2):
	_camera.bounding_planes[1] = Plane(-1, 0, 0, -map_size.x)
	_camera.bounding_planes[3] = Plane(0, 0, -1, -map_size.y)


func _setup_players():
	assert(
		_players.get_children().is_empty() or settings.players.is_empty(),
		"players can be defined either in settings or in scene tree, not in both"
	)
	if _players.get_children().is_empty():
		_create_players_from_settings()
	for node in _players.get_children():
		if node is Player:
			node.add_to_group("players")


func _create_players_from_settings():
	for player_id in range(settings.players.size()):
		var player_settings = settings.players[player_id]
		var player = null
		if Network.is_client() and player_settings.controller != Constants.PlayerType.HUMAN:
			# KI läuft nur auf dem Host; Clients brauchen nur den Spieler-Knoten.
			player = Player.new()
		else:
			var player_scene = Constants.Match.Player.CONTROLLER_SCENES[player_settings.controller]
			player = player_scene.instantiate()
			if (
				Network.is_online()
				and player is Human
				and player_settings.peer_id != multiplayer.get_unique_id()
			):
				_strip_local_input_from_remote_human(player)
		player.color = player_settings.color
		player.peer_id = player_settings.peer_id
		player.team = player_settings.team
		player.faction = player_settings.faction
		player.difficulty = player_settings.difficulty
		# Gleiche Namen auf allen Rechnern, damit RPCs und Sync die Knoten finden
		player.name = "Player%d" % player_id
		if player_settings.spawn_index_offset > 0:
			for i in range(player_settings.spawn_index_offset):
				var gap = Node.new()
				gap.name = "Gap%d_%d" % [player_id, i]
				_players.add_child(gap)
		_players.add_child(player)


## Synchronizer für Knoten, die es auf allen Rechnern schon gibt (Spieler, Rohstoffe).
func _setup_static_synchronizers():
	for player in get_tree().get_nodes_in_group("players"):
		player.add_synchronizer()
	for resource_unit in get_tree().get_nodes_in_group("resource_units"):
		resource_unit.add_synchronizer()


## Ein entfernter Mensch auf dem Host: keine lokale Eingabe/Sprachausgabe, nur
## UnitActionsController bleibt, um seine Befehle auszuführen.
func _strip_local_input_from_remote_human(player):
	for child_name in [
		"StructurePlacementHandler",
		"SuperweaponHandler",
		"VoiceNarratorController",
		"UnitVoicesController"
	]:
		var child = player.get_node_or_null(child_name)
		if child != null:
			player.remove_child(child)
			child.queue_free()


func _setup_unit_spawners():
	if not Network.is_online():
		return
	for player in _players.get_children():
		if not player is Player:
			continue
		var spawner = MultiplayerSpawner.new()
		spawner.name = "UnitSpawner"
		spawner.spawn_path = NodePath("..")
		for scene_path in Constants.Match.Units.DEFAULT_PROPERTIES:
			spawner.add_spawnable_scene(scene_path)
		spawner.spawned.connect(_on_unit_replicated)
		player.add_child(spawner)


## Client: eine vom Host gespawnte Einheit ist angekommen.
func _on_unit_replicated(unit):
	_setup_unit_groups(unit, unit.player)
	MatchSignals.unit_spawned.emit(unit)


func _setup_player_units():
	for player in _players.get_children():
		if not player is Player:
			continue
		var player_index = player.get_index()
		var predefined_units = player.get_children().filter(func(child): return child is Unit)
		if not predefined_units.is_empty():
			predefined_units.map(func(unit): _setup_unit_groups(unit, unit.player))
		else:
			_spawn_player_units(
				player,
				map.find_child("SpawnPoints").get_child(_spawn_index_of(player)).global_transform
			)


func _spawn_player_units(player, spawn_transform):
	_setup_and_spawn_unit(CommandCenter.instantiate(), spawn_transform, player, false)
	if Factions.faction_of(player) == Factions.CORE:
		_setup_and_spawn_unit(
			Drone.instantiate(), spawn_transform.translated(Vector3(-2, 0, -2)), player
		)
	else:
		# Völker starten mit zwei Infanteristen statt der Aufklärungsdrohne
		for offset in [Vector3(-2, 0, -2), Vector3(2, 0, -2)]:
			_setup_and_spawn_unit(
				Infantry.instantiate(), spawn_transform.translated(offset), player
			)
	_setup_and_spawn_unit(
		Worker.instantiate(), spawn_transform.translated(Vector3(-3, 0, 3)), player
	)
	_setup_and_spawn_unit(
		Worker.instantiate(), spawn_transform.translated(Vector3(3, 0, 3)), player
	)


func _setup_and_spawn_unit(unit, a_transform, player, mark_structure_under_construction = true):
	if Network.is_client():
		unit.queue_free()
		return
	unit.name = "Unit%d" % _next_unit_id
	_next_unit_id += 1
	if unit.variant == "" and Factions.faction_of(player) != Factions.CORE:
		# Szenen von KI und Startaufstellung: Standard-Variante des Volks
		unit.variant = Factions.variant_for_player(player, unit.scene_file_path)
	unit.global_transform = a_transform
	if unit is Structure and mark_structure_under_construction:
		unit.mark_as_under_construction()
	_setup_unit_groups(unit, player)
	player.add_child(unit)
	MatchSignals.unit_spawned.emit(unit)


func _setup_unit_groups(unit, player):
	unit.add_to_group("units")
	var human_player = _get_human_player()
	if player == human_player:
		unit.add_to_group("controlled_units")
	elif human_player != null and player.is_ally_of(human_player):
		unit.add_to_group("allied_units")
	else:
		unit.add_to_group("adversary_units")
	if player in visible_players:
		unit.add_to_group("revealed_units")


func _get_human_player():
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(player): return player is Human and player.is_local()
	)
	assert(human_players.size() <= 1, "more than one local human player is not allowed")
	if not human_players.is_empty():
		return human_players[0]
	return null


func _move_camera_to_initial_position():
	var human_player = _get_human_player()
	if human_player != null:
		_move_camera_to_player_units_crowd_pivot(human_player)
	else:
		_move_camera_to_player_units_crowd_pivot(get_tree().get_nodes_in_group("players")[0])


## Startpunkt gleichmaessig ueber die vorhandenen Startpunkte verteilt, damit Gegner weit auseinander starten.
func _spawn_index_of(player):
	var real_players = _players.get_children().filter(func(child): return child is Player)
	var spawn_count = map.find_child("SpawnPoints").get_child_count()
	var ordinal = real_players.find(player)
	if ordinal < 0 or real_players.size() >= spawn_count:
		return player.get_index() % spawn_count
	return int(round(float(ordinal) * spawn_count / real_players.size())) % spawn_count


func _move_camera_to_spawn_point_of(player):
	if player == null:
		return
	var spawn_point = map.find_child("SpawnPoints").get_child(_spawn_index_of(player))
	_camera.set_position_safely(spawn_point.global_position)


func _move_camera_to_player_units_crowd_pivot(player):
	var player_units = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.player == player
	)
	assert(not player_units.is_empty(), "player must have at least one initial unit")
	var crowd_pivot = Utils.Match.Unit.Movement.calculate_aabb_crowd_pivot_yless(player_units)
	_camera.set_position_safely(crowd_pivot)


func _reveal_player_units(player):
	if player == null:
		return
	for unit in get_tree().get_nodes_in_group("units").filter(
		func(a_unit): return a_unit.player == player
	):
		unit.add_to_group("revealed_units")


func _conceal_player_units(player):
	if player == null:
		return
	for unit in get_tree().get_nodes_in_group("units").filter(
		func(a_unit): return a_unit.player == player
	):
		unit.remove_from_group("revealed_units")
