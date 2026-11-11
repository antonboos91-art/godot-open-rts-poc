## Legt zusaetzliche Rohstoff-Felder an (deterministisch, fester Seed), damit sich Sammler
## nicht gegenseitig im Weg stehen: um jede Startposition ein grosser Ring, dazu Expansions-
## Felder zwischen den Spielern und ein reiches Zentrumsfeld. Gleiches Ergebnis auf allen Rechnern.
extends RefCounted

const RESOURCE_A = preload("res://source/match/units/non-player/ResourceA.tscn")
const RESOURCE_B = preload("res://source/match/units/non-player/ResourceB.tscn")

## Mindestabstand zwischen zwei Knoten (Hindernisradius 0,6 + Platz zum Abbauen)
const MIN_SPACING = 3.0
const BASE_A = 10
const BASE_B = 3
const BASE_RADIUS_MIN = 10.5
const BASE_RADIUS_MAX = 16.0
const EXPANSION_A = 8
const EXPANSION_B = 2
const EXPANSION_DISTANCE = 30.0
const CENTER_A = 12
const CENTER_B = 4
const MAP_MARGIN = 7.0
const SPAWN_CLEARANCE = 20.0  # Expansionen nicht in fremde Basen setzen


static func populate(map):
	var holder = map.find_child("Resources", false, false)
	var spawn_points = map.find_child("SpawnPoints", false, false)
	if holder == null or spawn_points == null:
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = int(map.size.x) * 6007 + int(map.size.y) * 7919 + 5
	var spawns = []
	for marker in spawn_points.get_children():
		spawns.append(Vector2(marker.position.x, marker.position.z))
	var taken = []
	_collect_existing(holder, taken)
	var center = map.size / 2.0
	var counter = [0]
	for spawn in spawns:
		var inward = (center - spawn).normalized()
		_scatter(holder, rng, taken, counter, spawn, BASE_RADIUS_MIN, BASE_RADIUS_MAX, BASE_A, BASE_B, map, inward)
	for spawn in spawns:
		var field = spawn + (center - spawn).normalized() * EXPANSION_DISTANCE
		field = _clamped(field, map)
		if _near_spawn(field, spawns, SPAWN_CLEARANCE):
			continue
		_scatter(holder, rng, taken, counter, field, 0.0, 6.5, EXPANSION_A, EXPANSION_B, map, Vector2.ZERO)
	_scatter(holder, rng, taken, counter, center, 0.0, 8.0, CENTER_A, CENTER_B, map, Vector2.ZERO)


static func _collect_existing(node, taken):
	for child in node.get_children():
		if child is Node3D and child.is_in_group("resource_units"):
			taken.append(Vector2(child.global_position.x, child.global_position.z))
		_collect_existing(child, taken)


static func _clamped(point, map):
	return Vector2(
		clampf(point.x, MAP_MARGIN, map.size.x - MAP_MARGIN),
		clampf(point.y, MAP_MARGIN, map.size.y - MAP_MARGIN)
	)


static func _near_spawn(point, spawns, distance):
	for spawn in spawns:
		if point.distance_to(spawn) < distance:
			return true
	return false


static func _free(point, taken, map):
	if (
		point.x < MAP_MARGIN
		or point.y < MAP_MARGIN
		or point.x > map.size.x - MAP_MARGIN
		or point.y > map.size.y - MAP_MARGIN
	):
		return false
	for other in taken:
		if point.distance_to(other) < MIN_SPACING:
			return false
	return true


## Verteilt count_a Kristall-A- und count_b Kristall-B-Knoten im Ring um "origin".
## "prefer" (Richtung) bevorzugt die Seite zur Kartenmitte, damit die Zentrale nicht zugestellt wird.
static func _scatter(holder, rng, taken, counter, origin, r_min, r_max, count_a, count_b, map, prefer):
	var wanted = []
	for i in count_a:
		wanted.append("a")
	for i in count_b:
		wanted.append("b")
	for kind in wanted:
		for attempt in 60:
			var angle = rng.randf() * TAU
			if prefer != Vector2.ZERO and attempt < 40:
				angle = prefer.angle() + rng.randf_range(-1.7, 1.7)
			var radius = rng.randf_range(r_min, r_max)
			var point = origin + Vector2(cos(angle), sin(angle)) * radius
			if not _free(point, taken, map):
				continue
			taken.append(point)
			var node = (RESOURCE_A if kind == "a" else RESOURCE_B).instantiate()
			counter[0] += 1
			node.name = "Field%s%d" % [kind.to_upper(), counter[0]]
			node.position = Vector3(point.x, 0.0, point.y)
			node.rotation.y = rng.randf() * TAU
			holder.add_child(node)
			break
