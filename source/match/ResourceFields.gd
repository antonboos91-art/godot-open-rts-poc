## Legt zusaetzliche Rohstoff-Felder an (deterministisch, fester Seed), damit sich Sammler
## nicht gegenseitig im Weg stehen: um jede Startposition ein grosser Ring, dazu Expansions-
## Felder zwischen den Spielern und ein reiches Zentrumsfeld. Gleiches Ergebnis auf allen Rechnern.
extends RefCounted

const Heights = preload("res://source/match/Heights.gd")

const RESOURCE_A = preload("res://source/match/units/non-player/ResourceA.tscn")
const RESOURCE_B = preload("res://source/match/units/non-player/ResourceB.tscn")

## Mindestabstand zwischen zwei Knoten (Hindernisradius 0,6 + Platz zum Abbauen)
const MIN_SPACING = 3.6
const BASE_A = 10
const BASE_B = 3
const BASE_ARC_RADIUS = 13.0
const EXPANSION_ARC_RADIUS = 7.5
const CENTER_ARC_RADIUS = 10.5
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
		# Mineralienlinie hinter der Zentrale (von der Kartenmitte weg), Kristalle am Ende des Bogens
		var outward = (spawn - center).normalized()
		_arc(holder, rng, taken, counter, spawn, BASE_ARC_RADIUS, outward.angle(), BASE_A, BASE_B, map)
	for field in _expansion_points(map, spawns, center):
		# Bogen um den Zentralen-Platz, offen zur Kartenmitte
		_arc(holder, rng, taken, counter, field, EXPANSION_ARC_RADIUS, (field - center).normalized().angle(), EXPANSION_A, EXPANSION_B, map)
	_arc(holder, rng, taken, counter, center, CENTER_ARC_RADIUS, 0.0, CENTER_A, CENTER_B, map)


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


## Legt Knoten entlang eines Bogens um "origin" (wie die Mineralienlinien in SC1): jeder Knoten ist
## von außen erreichbar, keiner liegt eingekesselt. center_angle ist die Mitte des Bogens.
static func _arc(holder, rng, taken, counter, origin, radius, center_angle, count_a, count_b, map):
	var origin_height = Heights.at(origin.x, origin.y)
	var total = count_a + count_b
	var step = 2.0 * asin(min(1.0, MIN_SPACING * 1.03 / (2.0 * radius)))
	var full_circle = step * total >= TAU
	if full_circle:
		step = TAU / total
	var first = center_angle - step * (total - 1) / 2.0
	for i in total:
		var kind = "a" if i < count_a else "b"
		var angle = first + step * i
		var point = origin + Vector2(cos(angle), sin(angle)) * radius
		if not _free(point, taken, map):
			continue
		if Heights.active and abs(Heights.at(point.x, point.y) - origin_height) > 0.25:
			continue
		taken.append(point)
		var node = (RESOURCE_A if kind == "a" else RESOURCE_B).instantiate()
		counter[0] += 1
		node.name = "Field%s%d" % [kind.to_upper(), counter[0]]
		node.position = Vector3(point.x, Heights.at(point.x, point.y), point.y)
		node.rotation.y = rng.randf() * TAU
		holder.add_child(node)


## Orte der Expansionsfelder. Kleine Karten: eines je Spieler zur Mitte hin. Große Karten
## mit Plateaus: drei je Spieler (nah, links, rechts) plus eines zwischen je zwei Nachbarn, alle im
## Tiefland außerhalb der Plateaus und der Rampenausläufe.
static func _expansion_points(map, spawns, center):
	var points = []
	var big = Heights.active
	var distance = EXPANSION_DISTANCE if not big else max(EXPANSION_DISTANCE, min(map.size.x, map.size.y) * 0.2)
	for spawn in spawns:
		var inward = (center - spawn).normalized()
		var angles = [0.0] if not big else [0.0, 0.9, -0.9]
		for angle in angles:
			var field = _clamped(spawn + inward.rotated(angle) * distance, map)
			if _acceptable_field(field, spawns, points):
				points.append(field)
	if big:
		for i in spawns.size():
			var mid = (spawns[i] + spawns[(i + 1) % spawns.size()]) / 2.0
			var outward = (mid - center).normalized()
			var field = _clamped(mid + outward * 8.0, map)
			if _acceptable_field(field, spawns, points):
				points.append(field)
	return points


static func _acceptable_field(field, spawns, points):
	var clearance = SPAWN_CLEARANCE if not Heights.active else 46.0
	if _near_spawn(field, spawns, clearance):
		return false
	if Heights.active and Heights.at(field.x, field.y) > 0.2:
		return false
	for other in points:
		if field.distance_to(other) < 22.0:
			return false
	return true
