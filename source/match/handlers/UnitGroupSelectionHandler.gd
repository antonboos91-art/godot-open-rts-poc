extends Node3D

var _set_action_names = [null]
var _get_action_names = [null]
var _unit_group_names = [null]


func _ready():
	for group_id in range(1, 10):
		_set_action_names.append("unit_groups_set_{0}".format([group_id]))
		_get_action_names.append("unit_groups_access_{0}".format([group_id]))
		_unit_group_names.append("unit_group_{0}".format([group_id]))


func _input(event):
	for group_id in range(1, 10):
		if event.is_action_pressed(_set_action_names[group_id]):
			set_group(group_id)
			return
		if event.is_action_pressed(_get_action_names[group_id]):
			access_group(group_id)
			return


func access_group(group_id: int):
	var units_in_group = Utils.Set.from_array(
		get_tree().get_nodes_in_group(_unit_group_names[group_id])
	)
	Utils.Match.select_units(units_in_group)


## Strg+Zahl: neue Gruppe (ersetzt die alte). Umschalt+Strg+Zahl: Auswahl an die Gruppe anhängen.
## Alt+Strg+Zahl: neue Gruppe und die Einheiten aus allen anderen Gruppen entfernen.
func set_group(group_id: int):
	var selected = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)
	if Input.is_key_pressed(KEY_ALT):
		for other_id in range(1, 10):
			if other_id != group_id:
				for unit in selected:
					unit.remove_from_group(_unit_group_names[other_id])
	if not Input.is_key_pressed(KEY_SHIFT):
		for unit in get_tree().get_nodes_in_group(_unit_group_names[group_id]):
			unit.remove_from_group(_unit_group_names[group_id])
	for unit in selected:
		unit.add_to_group(_unit_group_names[group_id])
