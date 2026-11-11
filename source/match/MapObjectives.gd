## Neutrale Kartenziele: vier Wachtürme zwischen den Startpositionen (Kartenmitte bleibt für das
## Zentrumsfeld frei). Feste Positionen aus der Kartengröße, daher überall gleich.
extends RefCounted

const Watchtower = preload("res://source/match/Watchtower.gd")

const OFFSET_FRACTION = 0.27


static func populate(map):
	var existing = map.find_child("Objectives", false, false)
	if existing != null:
		return
	var holder = Node3D.new()
	holder.name = "Objectives"
	map.add_child(holder)
	var center = map.size / 2.0
	var offsets = [
		Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)
	]
	var index = 0
	for direction in offsets:
		var tower = Watchtower.new()
		tower.name = "Watchtower%d" % index
		index += 1
		var point = center + direction * map.size * OFFSET_FRACTION
		tower.position = Vector3(point.x, 0.0, point.y)
		holder.add_child(tower)
