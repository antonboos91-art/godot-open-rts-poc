## Baut große Karten im StarCraft-Maßstab zur Laufzeit: Startpositionen im Ring, je ein Plateau mit
## einer Rampe zur Kartenmitte, dazu das Geländenetz mit Höhen. Rohstoffe, Wachtürme und Wälder
## setzen danach auf diesem Gelände auf (ResourceFields, MapObjectives, NatureScatter).
##
## Maßstab: ein Gebäude ist rund 5 m breit, ein SC1-Feld etwa 1,7 m. Eine 4-Spieler-Karte mit
## 128 Feldern entspricht damit etwa 220 m, eine 8-Spieler-Karte mit 256 Feldern etwa 430 m.
extends RefCounted

const Heights = preload("res://source/match/Heights.gd")

const PLATEAU_RADIUS_M = 30.0
const PLATEAU_HEIGHT_M = 3.0
const EDGE_MARGIN_M = 22.0  # Abstand Plateaurand zum Kartenrand
const GRID_STEP_M = 1.0


## Ring-Positionen für "players" Spieler auf einer Karte dieser Größe.
static func spawn_positions(size, players):
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - PLATEAU_RADIUS_M - EDGE_MARGIN_M
	var result = []
	var offset = PI / float(players)
	for i in players:
		var angle = TAU * i / players + offset
		result.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return result


static func populate(map):
	if map.generated_players <= 0:
		Heights.clear()
		return
	Heights.clear()
	var spawns = spawn_positions(map.size, map.generated_players)
	var center = map.size / 2.0
	var spawn_points = map.find_child("SpawnPoints", false, false)
	for child in spawn_points.get_children():
		spawn_points.remove_child(child)
		child.queue_free()
	for i in spawns.size():
		Heights.add_plateau(spawns[i], PLATEAU_RADIUS_M, PLATEAU_HEIGHT_M, center - spawns[i])
	for i in spawns.size():
		var marker = Marker3D.new()
		marker.name = "Marker3D%d" % (i + 1)
		marker.position = Vector3(spawns[i].x, Heights.at(spawns[i].x, spawns[i].y), spawns[i].y)
		spawn_points.add_child(marker)
	_build_terrain(map)


static func _build_terrain(map):
	var terrain = map.find_child("Terrain", true, false)
	if terrain == null:
		return
	var old_material = terrain.mesh.material if terrain.mesh != null and "material" in terrain.mesh else null
	var nx = int(ceil(map.size.x / GRID_STEP_M)) + 8
	var nz = int(ceil(map.size.y / GRID_STEP_M)) + 8
	var origin = Vector2(-4.0 * GRID_STEP_M, -4.0 * GRID_STEP_M)
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	vertices.resize((nx + 1) * (nz + 1))
	normals.resize(vertices.size())
	uvs.resize(vertices.size())
	var heights = PackedFloat32Array()
	heights.resize(vertices.size())
	var index = 0
	for iz in nz + 1:
		for ix in nx + 1:
			var x = origin.x + ix * GRID_STEP_M
			var z = origin.y + iz * GRID_STEP_M
			heights[index] = Heights.at(x, z)
			vertices[index] = Vector3(x, heights[index], z)
			uvs[index] = Vector2(x / map.size.x, z / map.size.y)
			index += 1
	for iz in nz + 1:
		for ix in nx + 1:
			var i = iz * (nx + 1) + ix
			var left = heights[iz * (nx + 1) + max(ix - 1, 0)]
			var right = heights[iz * (nx + 1) + min(ix + 1, nx)]
			var up = heights[max(iz - 1, 0) * (nx + 1) + ix]
			var down = heights[min(iz + 1, nz) * (nx + 1) + ix]
			normals[i] = Vector3(left - right, 2.0 * GRID_STEP_M, up - down).normalized()
	var indices = PackedInt32Array()
	indices.resize(nx * nz * 6)
	var k = 0
	for iz in nz:
		for ix in nx:
			var a = iz * (nx + 1) + ix
			var b = a + 1
			var c = a + (nx + 1)
			var d = c + 1
			# Reihenfolge so, dass die Oberseite nach oben zeigt
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if old_material != null:
		mesh.surface_set_material(0, old_material)
		if old_material is ShaderMaterial:
			old_material.set_shader_parameter("map_size", map.size)
	terrain.mesh = mesh
