## Streut Baeume, Waelder, Felsen und Buesche deterministisch (fester Seed) auf eine Karte.
## Auf allen Rechnern kommt dasselbe heraus, daher keine Synchronisierung noetig.
## Baeume innerhalb der Karte blockieren die Wegfindung (StaticBody3D in der Gruppe
## "terrain_navigation_input"); der Randwald ausserhalb ist nur Optik.
extends RefCounted

const DIR = "res://assets/sprites/nature/"
const TREES = ["pine_a", "pine_b", "pine_c", "pine_a", "pine_b", "oak_a", "oak_b", "dead_a"]
const ROCKS = ["rock_a", "rock_b", "rock_c"]
## Bildgroesse in Weltmetern und Bildzeile des Fusspunkts (von oben, 256 px Bild)
const TREE_WORLD_SIZE = 5.2 * 0.62
const FOOT_ROW = 184.0
const SPAWN_CLEARANCE = 15.0
const RESOURCE_CLEARANCE = 3.0

static var _textures = {}


static func populate(map):
	var decorations = map.find_child("Decorations", false, false)
	if decorations == null:
		return
	for child in decorations.get_children():
		if child.has_meta("nature"):
			child.queue_free()
	var rng = RandomNumberGenerator.new()
	rng.seed = int(map.size.x) * 7919 + int(map.size.y) * 104729 + 17
	var keep_out = _keep_out_points(map)
	var holder = Node3D.new()
	holder.name = "Nature"
	holder.set_meta("nature", true)
	decorations.add_child(holder)
	var placed = []
	# Randwald: dicht, nur Optik, ausserhalb der Karte
	var step = 1.7
	var x = -4.0
	while x < map.size.x + 4.0:
		for side in [Vector2(x, -rng.randf_range(0.3, 3.2)), Vector2(x, map.size.y + rng.randf_range(0.3, 3.2))]:
			_add_tree(holder, side, rng, false)
		x += step * rng.randf_range(0.7, 1.2)
	var z = -4.0
	while z < map.size.y + 4.0:
		for side in [Vector2(-rng.randf_range(0.3, 3.2), z), Vector2(map.size.x + rng.randf_range(0.3, 3.2), z)]:
			_add_tree(holder, side, rng, false)
		z += step * rng.randf_range(0.7, 1.2)
	# Randstreifen innen: lockere Baeume mit Kollision
	var area = map.size.x * map.size.y
	for i in int(area / 90.0):
		var edge_pos = _random_edge_position(map, rng, 3.5)
		if _clear(edge_pos, keep_out, placed, 1.4):
			placed.append(edge_pos)
			_add_tree(holder, edge_pos, rng, true)
	# Waldstuecke im Inneren
	var forests = max(2, int(area / 450.0))
	var attempts = 0
	var made = 0
	while made < forests and attempts < 200:
		attempts += 1
		var center = Vector2(rng.randf_range(6, map.size.x - 6), rng.randf_range(6, map.size.y - 6))
		if not _clear(center, keep_out, [], SPAWN_CLEARANCE * 0.8):
			continue
		made += 1
		var radius = rng.randf_range(3.0, 5.5)
		for i in int(radius * radius * 1.1):
			var angle = rng.randf() * TAU
			var dist = radius * sqrt(rng.randf())
			var pos = center + Vector2(cos(angle), sin(angle)) * dist
			if pos.x < 1 or pos.y < 1 or pos.x > map.size.x - 1 or pos.y > map.size.y - 1:
				continue
			if _clear(pos, keep_out, placed, 1.5):
				placed.append(pos)
				_add_tree(holder, pos, rng, true)
	# Einzelne Felsen und Buesche
	for i in int(area / 120.0):
		var pos = Vector2(rng.randf_range(1, map.size.x - 1), rng.randf_range(1, map.size.y - 1))
		var rock = rng.randf() < 0.55
		if _clear(pos, keep_out, placed, 2.0 if rock else 1.0):
			placed.append(pos)
			_add_sprite(holder, pos, "rock_" + ["a", "b", "c"][rng.randi() % 3] if rock else "bush_a", 2.2 if rock else 1.8, rng, rock)


static func _keep_out_points(map):
	var points = []
	var spawn_points = map.find_child("SpawnPoints", false, false)
	if spawn_points != null:
		for marker in spawn_points.get_children():
			points.append([Vector2(marker.position.x, marker.position.z), SPAWN_CLEARANCE])
	var resources = map.find_child("Resources", false, false)
	if resources != null:
		for res in resources.get_children():
			points.append([Vector2(res.position.x, res.position.z), RESOURCE_CLEARANCE])
	return points


static func _clear(pos, keep_out, placed, spacing):
	for entry in keep_out:
		if pos.distance_to(entry[0]) < entry[1]:
			return false
	for other in placed:
		if pos.distance_squared_to(other) < spacing * spacing:
			return false
	return true


static func _random_edge_position(map, rng, depth):
	var d = rng.randf_range(0.8, depth)
	match rng.randi() % 4:
		0:
			return Vector2(rng.randf_range(0, map.size.x), d)
		1:
			return Vector2(rng.randf_range(0, map.size.x), map.size.y - d)
		2:
			return Vector2(d, rng.randf_range(0, map.size.y))
		_:
			return Vector2(map.size.x - d, rng.randf_range(0, map.size.y))


static func _add_tree(holder, pos, rng, solid):
	var variant = TREES[rng.randi() % TREES.size()]
	var size = TREE_WORLD_SIZE * rng.randf_range(0.85, 1.25)
	var sprite = _add_sprite(holder, pos, variant, size, rng, false)
	if solid:
		var body = StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.input_ray_pickable = false
		var shape = CollisionShape3D.new()
		var cyl = CylinderShape3D.new()
		cyl.radius = 0.55
		cyl.height = 2.0
		shape.shape = cyl
		shape.position.y = 1.0
		body.add_child(shape)
		body.position = Vector3(pos.x, 0, pos.y)
		body.add_to_group("terrain_navigation_input")
		holder.add_child(body)
	return sprite


static func _add_sprite(holder, pos, name, size, rng, solid):
	var sprite = Sprite3D.new()
	sprite.texture = _texture(name)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = size / 256.0
	# Fusspunkt des Bildes auf den Boden setzen
	sprite.offset = Vector2(0, FOOT_ROW - 128.0)
	sprite.position = Vector3(pos.x, 0, pos.y)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if rng.randf() < 0.5:
		sprite.flip_h = true
	holder.add_child(sprite)
	if solid:
		var body = StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.input_ray_pickable = false
		var shape = CollisionShape3D.new()
		var cyl = CylinderShape3D.new()
		cyl.radius = size * 0.28
		cyl.height = 1.5
		shape.shape = cyl
		shape.position.y = 0.75
		body.add_child(shape)
		body.position = Vector3(pos.x, 0, pos.y)
		body.add_to_group("terrain_navigation_input")
		holder.add_child(body)
	return sprite


static func _texture(name):
	if not _textures.has(name):
		_textures[name] = load(DIR + name + ".png")
	return _textures[name]
