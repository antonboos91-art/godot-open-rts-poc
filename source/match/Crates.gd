## Vorratskisten (wie in Generals): tauchen ab und zu irgendwo auf der Karte auf. Wer sie als Erster
## erreicht, bekommt Rohstoffe, volle Heilung für die Truppe in der Nähe oder einen Rang höher.
## Der Host würfelt und prüft das Einsammeln; alle Rechner zeigen die Kisten per RPC.
extends Node3D

const Heights = preload("res://source/match/Heights.gd")

const FIRST_DELAY_S = 40.0
const INTERVAL_MIN_S = 45.0
const INTERVAL_MAX_S = 75.0
const MAX_CRATES = 4
const PICKUP_RADIUS_M = 1.8
const MAP_MARGIN_M = 12.0
const BASE_CLEARANCE_M = 14.0
const SCAN_INTERVAL_S = 0.3
const HEAL_RADIUS_M = 9.0
const SCRAP_REWARD = {"resource_a": 8, "resource_b": 5}

var enabled = true
var _crates = {}  # id -> {"node", "kind", "position"}
var _next_id = 1
var _rng = RandomNumberGenerator.new()
var _spawn_timer = null


func _ready():
	name = "Crates"
	_rng.randomize()
	if DisplayServer.get_name() == "headless" or Network.is_client():
		return
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(_spawn_timer)
	_spawn_timer.start(FIRST_DELAY_S)
	var scan_timer = Timer.new()
	scan_timer.wait_time = SCAN_INTERVAL_S
	scan_timer.timeout.connect(_scan)
	add_child(scan_timer)
	scan_timer.start()


func crate_count():
	return _crates.size()


func _on_spawn_timer():
	if enabled and _crates.size() < MAX_CRATES:
		spawn_random()
	_spawn_timer.start(_rng.randf_range(INTERVAL_MIN_S, INTERVAL_MAX_S))


## Würfelt Ort und Art (Host). Gibt die Kisten-Id zurück, -1 ohne freien Platz.
func spawn_random(forced_kind = ""):
	var map = get_parent().map
	for attempt in 40:
		var point = Vector3(
			_rng.randf_range(MAP_MARGIN_M, map.size.x - MAP_MARGIN_M),
			0.0,
			_rng.randf_range(MAP_MARGIN_M, map.size.y - MAP_MARGIN_M)
		)
		if not _is_free(point):
			continue
		var kind = forced_kind
		if kind == "":
			var roll = _rng.randf()
			kind = "scrap" if roll < 0.5 else ("heal" if roll < 0.75 else "veteran")
		var id = _next_id
		_next_id += 1
		if Network.is_online():
			_create.rpc(id, point, kind)
		else:
			_create(id, point, kind)
		return id
	return -1


func _is_free(point):
	for structure in get_tree().get_nodes_in_group("units"):
		if (
			structure.has_method("is_constructed")
			and structure.global_position_yless.distance_to(point) < BASE_CLEARANCE_M
		):
			return false
	for crate in _crates.values():
		if crate["position"].distance_to(point) < 6.0:
			return false
	return true


@rpc("authority", "call_local", "reliable")
func _create(id, point, kind):
	var holder = Node3D.new()
	holder.name = "Crate%d" % id
	holder.position = Vector3(point.x, Heights.at(point.x, point.z), point.z)
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.9, 0.7, 0.9)
	mesh.mesh = box
	mesh.position.y = 0.45
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.75, 0.2)
	material.emission_enabled = true
	material.emission = Color(0.9, 0.6, 0.1)
	material.emission_energy_multiplier = 1.4
	mesh.material_override = material
	holder.add_child(mesh)
	var label = Label3D.new()
	label.text = "?"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.014
	label.font_size = 48
	label.position.y = 1.5
	holder.add_child(label)
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.3)
	light.omni_range = 4.0
	light.light_energy = 1.2
	light.position.y = 1.0
	holder.add_child(light)
	add_child(holder)
	_crates[id] = {"node": holder, "kind": kind, "position": point}


@rpc("authority", "call_local", "reliable")
func _remove(id):
	if id in _crates:
		_crates[id]["node"].queue_free()
		_crates.erase(id)


func _scan():
	for id in _crates.keys():
		var crate = _crates[id]
		for unit in get_tree().get_nodes_in_group("units"):
			if (
				unit.has_method("is_constructed")
				or unit.movement_speed <= 0.0
				or unit.global_position_yless.distance_to(crate["position"]) > PICKUP_RADIUS_M
			):
				continue
			pickup(id, unit)
			break


## Host: Einheit sammelt Kiste ein und bekommt die Belohnung.
func pickup(id, unit):
	if not id in _crates:
		return
	var kind = _crates[id]["kind"]
	var point = _crates[id]["position"]
	if Network.is_online():
		_remove.rpc(id)
	else:
		_remove(id)
	var player = unit.player
	var match_node = get_parent()
	match kind:
		"scrap":
			player.add_resources(SCRAP_REWARD)
			match_node._notify(point, "KISTE: ROHSTOFFE")
		"heal":
			for other in player.get_children():
				if (
					other.has_method("take_hit")
					and not other.has_method("is_constructed")
					and other.global_position_yless.distance_to(unit.global_position_yless) <= HEAL_RADIUS_M
				):
					other.hp = other.hp_max
			match_node._notify(point, "KISTE: HEILUNG")
		"veteran":
			unit.grant_promotion()
			match_node._notify(point, "KISTE: BEFÖRDERUNG")

