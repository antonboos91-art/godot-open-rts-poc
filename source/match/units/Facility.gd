## Gebäude ohne eigene Produktion: Lager, Radar, Werkstatt, Labor, Superwaffe.
## Die Fähigkeit kommt aus den Volksdaten (Factions.gd, "ability").
extends "res://source/match/units/Structure.gd"

const REPAIR_INTERVAL_S = 1.0

var ability:
	get:
		return Factions.entry(Factions.variant_of(self)).get("ability", "")


func _ready():
	await super()
	if ability == "repair" and not Network.is_client():
		var timer = Timer.new()
		timer.wait_time = REPAIR_INTERVAL_S
		timer.autostart = true
		timer.timeout.connect(_repair_nearby_units)
		add_child(timer)


## Werkstatt: repariert eigene und verbündete Einheiten in der Nähe.
func _repair_nearby_units():
	if not is_constructed() or player.is_low_power():
		return
	var amount = Constants.Match.Units.REPAIR_HP_PER_S * REPAIR_INTERVAL_S
	for unit in get_tree().get_nodes_in_group("units"):
		if (
			unit.has_method("is_constructed")
			or not player.is_ally_of(unit.player)
			or unit.hp == null
			or unit.hp >= unit.hp_max
			or (
				unit.global_position_yless.distance_to(global_position_yless)
				> Constants.Match.Units.REPAIR_RADIUS_M + radius
			)
		):
			continue
		unit.set_meta("repair_progress", unit.get_meta("repair_progress", 0.0) + amount)
		if unit.get_meta("repair_progress") >= 1.0:
			unit.set_meta("repair_progress", 0.0)
			unit.hp = min(unit.hp_max, unit.hp + 1)
