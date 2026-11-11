## Blizzard-Stil-Tastenkürzel des lokalen Spielers: Untätige Arbeiter (F1 / Strg+F1), ganze Armee (F2),
## Untergruppen durchschalten (Tab), Kamera-Lesezeichen (F5-F8, Strg+F5-F8 speichert), Makro (Z),
## Fähigkeit auf den Mauszeiger (C, bei gehaltener Taste mit Tastenwiederholung).
extends Node

const Hotkeys = preload("res://source/match/players/human/Hotkeys.gd")
const Factions = preload("res://source/match/factions/Factions.gd")
const Worker = preload("res://source/match/units/Worker.gd")
const Structure = preload("res://source/match/units/Structure.gd")

const CAST_REPEAT_S = 0.12
const CAST_PICK_RADIUS_M = 3.0

var _player = null
var _match = null
var _idle_index = 0
var _bookmarks = {}
var _last_cast_s = 0.0


func setup(match_node, player):
	_match = match_node
	_player = player
	name = "HotkeyController"


func _unhandled_input(event):
	if _player == null or not event is InputEventKey:
		return
	if Hotkeys.matches(event, "idle_worker"):
		if event.ctrl_pressed:
			select_idle_workers()
		else:
			cycle_idle_worker()
	elif Hotkeys.matches(event, "select_army"):
		select_army()
	elif Hotkeys.matches(event, "subgroup"):
		cycle_subgroup()
		get_viewport().set_input_as_handled()
	elif Hotkeys.matches(event, "macro"):
		_match.send_command("macro", [])
	elif Hotkeys.matches(event, "cast", true):
		cast_at_cursor()
	else:
		for i in range(1, 5):
			if Hotkeys.matches(event, "camera_%d" % i):
				if event.ctrl_pressed:
					store_camera(i)
				else:
					jump_camera(i)


# --- Arbeiter und Armee ------------------------------------------------------------------------


func idle_workers():
	return _own_units().filter(func(u): return u is Worker and u.action == null)


func cycle_idle_worker():
	var workers = idle_workers()
	if workers.is_empty():
		return null
	_idle_index = (_idle_index + 1) % workers.size()
	var worker = workers[_idle_index]
	_select([worker])
	_camera().set_position_safely(worker.global_position)
	return worker


func select_idle_workers():
	_select(idle_workers())


func select_army():
	_select(_own_units().filter(func(u): return not u is Structure and not u is Worker))


# --- Untergruppen --------------------------------------------------------------------------------


## Rangfolge: Fähigkeits-Einheiten (Zauberer) zuerst, dann nach Kosten (hohe Stufe zuerst).
static func subgroups_of(units):
	var by_variant = {}
	for unit in units:
		var variant = Factions.variant_of(unit)
		by_variant[variant] = by_variant.get(variant, 0) + 1
	var variants = by_variant.keys()
	variants.sort_custom(
		func(a, b):
			var score_a = _priority(a)
			var score_b = _priority(b)
			return score_a > score_b if score_a != score_b else a < b
	)
	return variants


static func _priority(variant):
	var cost = Factions.cost(variant)
	var score = cost["resource_a"] + 1.5 * cost["resource_b"]
	if Factions.ability(variant) != "":
		score += 1000.0
	return score


## Tab: schaltet die aktive Untergruppe der Auswahl weiter; Befehle gehen weiter an alle,
## das Befehlsmenü zeigt die Fähigkeiten der aktiven Untergruppe.
func cycle_subgroup():
	var selected = _selected_controlled()
	var variants = subgroups_of(selected)
	if variants.size() < 2:
		Hotkeys.active_subgroup = ""
		return
	var index = variants.find(Hotkeys.active_subgroup)
	Hotkeys.active_subgroup = variants[(index + 1) % variants.size()]
	var menus = _match.find_child("UnitMenus", true, false)
	if menus != null and menus.has_method("_reset_menus"):
		menus._reset_menus()
	_match.show_notice(
		selected[0].global_position, "UNTERGRUPPE: %s" % Factions.display_name(Hotkeys.active_subgroup)
	)


# --- Kamera-Lesezeichen --------------------------------------------------------------------------


func store_camera(slot):
	var view = get_viewport()
	var point = _camera().get_ray_intersection(view.get_visible_rect().size / 2.0)
	if point != null:
		_bookmarks[slot] = point
		_match.show_notice(point, "KAMERA %d GESPEICHERT" % slot)


func jump_camera(slot):
	if slot in _bookmarks:
		_camera().set_position_safely(_bookmarks[slot])


func has_bookmark(slot):
	return slot in _bookmarks


# --- Fähigkeit auf den Mauszeiger ----------------------------------------------------------------


func cast_at_cursor():
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_cast_s < CAST_REPEAT_S:
		return
	_last_cast_s = now
	var point = _camera().get_ray_intersection(get_viewport().get_mouse_position())
	if point != null:
		cast_at(point)


## Superwaffe aufs Ziel, sonst die passende Fähigkeit auf das nächste Ziel am Punkt.
func cast_at(point):
	var selected = _selected_controlled()
	for unit in selected:
		if unit.has_method("fire_superweapon") and unit.is_charged():
			_match.send_command("superweapon", [unit], [point])
			return true
	var abilities = selected.map(func(u): return Factions.ability(Factions.variant_of(u)))
	var wants_ally = "repair" in abilities
	var wants_enemy_structure = (
		"capture" in abilities or "hack" in abilities or "sabotage" in abilities
	)
	var best = null
	var best_distance = CAST_PICK_RADIUS_M
	for candidate in get_tree().get_nodes_in_group("units"):
		if not candidate.visible:
			continue
		var is_ally = candidate.player.is_ally_of(_player)
		var fits = (
			(wants_ally and is_ally and candidate.hp < candidate.hp_max)
			or (wants_enemy_structure and not is_ally and candidate is Structure)
		)
		if not fits:
			continue
		var distance = candidate.global_position_yless.distance_to(point * Vector3(1, 0, 1))
		if distance < best_distance:
			best = candidate
			best_distance = distance
	if best == null:
		return false
	_match.send_command("unit", selected, [_match.get_path_to(best)])
	return true


# --- Hilfen --------------------------------------------------------------------------------------


func _camera():
	return _match.find_child("IsometricCamera3D", false, false)


func _own_units():
	return get_tree().get_nodes_in_group("controlled_units")


func _selected_controlled():
	return get_tree().get_nodes_in_group("selected_units").filter(
		func(u): return u.is_in_group("controlled_units")
	)


func _select(units):
	if units.is_empty():
		return
	MatchSignals.deselect_all_units.emit()
	for unit in units:
		var selection = unit.find_child("Selection")
		if selection != null:
			selection.select()
