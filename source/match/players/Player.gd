extends Node3D

signal changed

const Factions = preload("res://source/match/factions/Factions.gd")

@export var resource_a = 0:
	set(value):
		resource_a = value
		emit_changed()
@export var resource_b = 0:
	set(value):
		resource_b = value
		emit_changed()
@export var color = Color.WHITE

## Spieler mit gleichem Team (> 0) sind verbündet: kein gegenseitiger Angriff,
## gemeinsame Sicht, gemeinsamer Sieg. 0 = jeder gegen jeden.
var team = 0

## Volk, z. B. "shibas" (leer = Grundvolk ohne Stromnetz). Siehe Factions.gd
var faction = ""

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


func is_ally_of(other_player):
	return (
		other_player == self or (team != 0 and other_player != null and team == other_player.team)
	)


## true, wenn dieser Spieler auf diesem Rechner gesteuert wird.
func is_local():
	if not Network.is_online():
		return true
	return peer_id == multiplayer.get_unique_id()


## Strom: [erzeugt, verbraucht] aller fertigen Gebäude dieses Spielers.
func get_power():
	var produced = 0
	var used = 0
	for unit in get_children():
		if not unit.has_method("is_constructed") or not unit.is_constructed():
			continue
		var power = Factions.power(Factions.variant_of(unit))
		if power > 0:
			produced += power
		else:
			used -= power
	return [produced, used]


## Zu wenig Strom: Produktion langsamer, Abwehrtürme und Werkstatt aus.
func is_low_power():
	if Factions.faction_of(self) == Factions.CORE:
		return false
	var power = get_power()
	return power[1] > power[0]


func production_speed_factor():
	return Constants.Match.Units.LOW_POWER_PRODUCTION_FACTOR if is_low_power() else 1.0


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
