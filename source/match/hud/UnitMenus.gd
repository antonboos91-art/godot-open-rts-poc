extends PanelContainer

const Structure = preload("res://source/match/units/Structure.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const FactionMenu = preload("res://source/match/hud/unit-menus/FactionMenu.gd")

var _faction_menu = FactionMenu.new()

@onready var _generic_menu = find_child("GenericMenu")


func _ready():
	_faction_menu.name = "FactionMenu"
	find_child("MarginContainer").add_child(_faction_menu)
	_reset_menus()
	MatchSignals.unit_selected.connect(func(_unit): _reset_menus())
	MatchSignals.unit_deselected.connect(func(_unit): _reset_menus())
	MatchSignals.unit_died.connect(func(_unit): _reset_menus())
	MatchSignals.unit_construction_finished.connect(func(_unit): _reset_menus())


func _reset_menus():
	_hide_all_menus()
	if _try_showing_any_menu():
		show()
	else:
		hide()


func _hide_all_menus():
	_generic_menu.hide()
	_faction_menu.hide()


func _try_showing_any_menu():
	var selected_controlled_units = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)
	if (
		selected_controlled_units.size() == 1
		and selected_controlled_units[0] is Structure
		and selected_controlled_units[0].is_constructed()
		and _faction_menu.show_production(selected_controlled_units[0])
	):
		return true
	if (
		not selected_controlled_units.is_empty()
		and selected_controlled_units.all(func(unit): return unit is Worker)
	):
		_faction_menu.show_construction(selected_controlled_units[0].player)
	if selected_controlled_units.size() > 0:
		_generic_menu.units = selected_controlled_units
		_generic_menu.show()
		return true
	return false
