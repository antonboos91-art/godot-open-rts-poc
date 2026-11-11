## Lichtquellen an Einheiten und Gebaeuden fuer die dunkle Stimmung:
## Infanterie: kleine Helmlampe in Volksfarbe. Fahrzeuge: zwei Scheinwerfer nach vorn + Volkslicht.
## Flieger: Suchscheinwerfer schraeg nach unten. Gebaeude: warme Aussenlampen + Volkslicht.
## Keine Schatten (Leistung), Lichter haengen an der Einheit und drehen mit ihr.
extends RefCounted

const Factions = preload("res://source/match/factions/Factions.gd")

const FACTION_LIGHT = {
	"shibas": Color(0.45, 0.8, 1.0),
	"katzen": Color(0.8, 0.4, 1.0),
	"baeren": Color(1.0, 0.6, 0.25),
}


static func attach(unit):
	if DisplayServer.get_name() == "headless" or unit.get_node_or_null("UnitLights") != null:
		return
	var holder = Node3D.new()
	holder.name = "UnitLights"
	unit.add_child(holder)
	var color = FACTION_LIGHT.get(Factions.faction_of(unit.player), Color(1.0, 0.85, 0.6))
	match unit.type:
		"Infantry":
			_omni(holder, Vector3(0, 1.5, -0.2), color, 0.9, 2.6)
		"Tank", "Worker":
			for side in [-0.45, 0.45]:
				_spot(holder, Vector3(side, 0.9, -1.2), Vector3(0, -0.18, -1), Color(1.0, 0.93, 0.8), 4.0, 12.0, 28.0)
			_omni(holder, Vector3(0, 1.6, 0.4), color, 1.2, 3.5)
		"Helicopter", "Drone":
			_spot(holder, Vector3(0, 0.0, -0.6), Vector3(0, -1.0, -0.8), Color(1.0, 0.95, 0.85), 5.0, 16.0, 22.0)
			_omni(holder, Vector3(0, 0.3, 0), color, 1.0, 3.0)
		_:
			var r = unit.radius if unit.radius != null else 2.0
			_omni(holder, Vector3(0, 2.6, 0), color, 1.6, r * 2.6)
			for corner in [Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
				_omni(holder, corner * r * 0.9 + Vector3(0, 1.2, 0), Color(1.0, 0.75, 0.45), 1.4, 4.5)


static func _omni(holder, at, color, energy, light_range):
	var l = OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 1.5
	l.position = at
	holder.add_child(l)
	return l


static func _spot(holder, at, direction, color, energy, light_range, angle):
	var l = SpotLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.spot_range = light_range
	l.spot_angle = angle
	l.spot_attenuation = 1.2
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 2.0
	l.position = at
	holder.add_child(l)
	l.look_at_from_position(at, at + direction, Vector3.UP)
	return l
