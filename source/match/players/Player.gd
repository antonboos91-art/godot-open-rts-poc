extends Node3D

signal changed

@export var resource_a = 0:
	set(value):
		resource_a = value
		emit_changed()
@export var resource_b = 0:
	set(value):
		resource_b = value
		emit_changed()
@export var color = Color.WHITE

## Multiplayer-Peer, der diesen Spieler steuert (0 = KI bzw. lokal im Einzelspieler).
var peer_id = 0

var _color_material = null


## Ressourcen vom Host an Clients spiegeln. Wird von Match aufgerufen, auf dem Host
## erst wenn alle Clients ihre Match-Szene geladen haben.
func add_synchronizer():
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "ResourcesSynchronizer"
	synchronizer.replication_config = Utils.Net.replication_config([":resource_a", ":resource_b"])
	add_child(synchronizer)


## true, wenn dieser Spieler auf diesem Rechner gesteuert wird.
func is_local():
	if not Network.is_online():
		return true
	return peer_id == multiplayer.get_unique_id()


func add_resources(resources):
	for resource in resources:
		set(resource, get(resource) + resources[resource])


func has_resources(resources):
	if FeatureFlags.allow_resources_deficit_spending:
		return true
	for resource in resources:
		if get(resource) < resources[resource]:
			return false
	return true


func subtract_resources(resources):
	for resource in resources:
		set(resource, get(resource) - resources[resource])


func get_color_material():
	if _color_material == null:
		_color_material = StandardMaterial3D.new()
		_color_material.vertex_color_use_as_albedo = true
		_color_material.albedo_color = color
		_color_material.metallic = 1
	return _color_material


func emit_changed():
	changed.emit()
