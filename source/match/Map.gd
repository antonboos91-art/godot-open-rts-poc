@tool
extends Node3D

# TODO: add editor-only 2nd pass shader to 'Terrain' mesh highlighting map boundries

const EXTRA_MARGIN = 14
const NatureScatter = preload("res://source/match/NatureScatter.gd")

@export var size = Vector2(50, 50):
	set(a_size):
		size = a_size
		var terrain = find_child("Terrain")
		terrain.mesh.size = size + Vector2(EXTRA_MARGIN, EXTRA_MARGIN) * 2
		terrain.mesh.center_offset = Vector3(size.x, 0.0, size.y) / 2.0
		# Eigene Materialkopie je Karte, damit map_size nicht zwischen Karten geteilt wird
		if terrain.mesh.material is ShaderMaterial:
			if not terrain.mesh.material.has_meta("per_map"):
				terrain.mesh.material = terrain.mesh.material.duplicate()
				terrain.mesh.material.set_meta("per_map", true)
			terrain.mesh.material.set_shader_parameter("map_size", size)


func _ready():
	if not Engine.is_editor_hint():
		NatureScatter.populate(self)


func get_topdown_polygon_2d():
	return [Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]
