## Zusätzliche Anzeigen im Blizzard-Stil (nur Oberfläche, keine Spielregeln):
##  - Abzeichen "Untätige Arbeiter" (Klick oder F1 wählt/zentriert, Strg+F1 wählt alle)
##  - Makro-Leiste (Energie + Fähigkeit der Zentrale, Taste Z)
##  - Zuschauer-Übersicht (F10): Produktion, Upgrades, Einkommen, Armeewert, Aktionen pro Minute
extends Control

const Factions = preload("res://source/match/factions/Factions.gd")
const Hotkeys = preload("res://source/match/players/human/Hotkeys.gd")
const MacroScript = preload("res://source/match/Macro.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Worker = preload("res://source/match/units/Worker.gd")

const UPDATE_S = 0.25
const INCOME_WINDOW_S = 60.0

var _match = null
var _human = null
var _hotkeys = null
var _idle_button = null
var _macro_button = null
var _energy_bar = null
var _overlay = null
var _overlay_label = null
var _timer = null
var _income_samples = {}  # Spieler -> [[Zeit, Schrott, Kristall], ...]
var _last_resources = {}


func setup(match_node, human, hotkeys):
	_match = match_node
	_human = human
	_hotkeys = hotkeys
	name = "BlizzardHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_timer = Timer.new()
	_timer.wait_time = UPDATE_S
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	_timer.start()


func _unhandled_input(event):
	if Hotkeys.matches(event, "observer_overlay"):
		_overlay.visible = not _overlay.visible
		_refresh()


func _build():
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.position = Vector2(10, 10)
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_idle_button = Button.new()
	_idle_button.focus_mode = Control.FOCUS_NONE
	_idle_button.pressed.connect(func(): _hotkeys.cycle_idle_worker())
	_idle_button.visible = false
	column.add_child(_idle_button)
	var macro_row = HBoxContainer.new()
	macro_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(macro_row)
	_macro_button = Button.new()
	_macro_button.focus_mode = Control.FOCUS_NONE
	_macro_button.pressed.connect(func(): _match.send_command("macro", []))
	macro_row.add_child(_macro_button)
	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(110, 22)
	_energy_bar.max_value = MacroScript.ENERGY_MAX
	_energy_bar.show_percentage = false
	macro_row.add_child(_energy_bar)
	_overlay = PanelContainer.new()
	_overlay.visible = false
	_overlay.position = Vector2(10, 110)
	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 14)
	_overlay.add_child(_overlay_label)
	add_child(_overlay)


func _refresh():
	if _human == null or not is_instance_valid(_human):
		return
	_sample_income()
	var idle = _hotkeys.idle_workers().size()
	_idle_button.visible = idle > 0
	_idle_button.text = "Untätige Arbeiter: %d  (%s)" % [idle, Hotkeys.label("idle_worker")]
	_idle_button.tooltip_text = (
		"Klick/%s: nächsten wählen und zentrieren, Strg+%s: alle wählen"
		% [Hotkeys.label("idle_worker"), Hotkeys.label("idle_worker")]
	)
	var faction = Factions.faction_of(_human)
	var ability_name = MacroScript.ability_name(faction)
	_macro_button.visible = ability_name != ""
	_energy_bar.visible = ability_name != ""
	if ability_name != "":
		var ready = _human.energy >= MacroScript.ENERGY_COST
		_macro_button.text = "%s (%s)" % [ability_name, Hotkeys.label("macro")]
		_macro_button.disabled = not ready
		_macro_button.tooltip_text = MacroScript.ability_text(faction)
		_energy_bar.value = _human.energy
	if _overlay.visible:
		_overlay_label.text = overview_text()


# --- Zuschauer-Übersicht ------------------------------------------------------------------------


func _sample_income():
	var now = Time.get_ticks_msec() / 1000.0
	for player in get_tree().get_nodes_in_group("players"):
		var last = _last_resources.get(player, [player.resource_a, player.resource_b])
		var gained_a = max(0, player.resource_a - last[0])
		var gained_b = max(0, player.resource_b - last[1])
		_last_resources[player] = [player.resource_a, player.resource_b]
		var samples = _income_samples.get(player, [])
		if gained_a > 0 or gained_b > 0:
			samples.append([now, gained_a, gained_b])
		while not samples.is_empty() and now - samples[0][0] > INCOME_WINDOW_S:
			samples.pop_front()
		_income_samples[player] = samples


## Einkommen der letzten Minute [Schrott, Kristall] (Ausgaben zählen nicht, nur Zuwachs).
func income_per_minute(player):
	var total = [0, 0]
	for sample in _income_samples.get(player, []):
		total[0] += sample[1]
		total[1] += sample[2]
	return total


func army_value(player):
	var value = 0.0
	for unit in player.get_children():
		if unit.has_method("take_hit") and not unit is Structure and not unit is Worker:
			var cost = Factions.cost(Factions.variant_of(unit))
			value += cost["resource_a"] + cost["resource_b"]
	return value


## Welche Spieler die Übersicht zeigen darf: im Zuschauermodus (volle Sicht) alle, sonst nur das eigene Team.
func visible_players():
	var all = get_tree().get_nodes_in_group("players")
	if _match.settings.visibility == _match.settings.Visibility.FULL:
		return all
	return all.filter(func(p): return p.is_ally_of(_human))


func overview_text():
	var lines = ["Übersicht (%s zum Ausblenden)" % Hotkeys.label("observer_overlay")]
	for player in visible_players():
		var income = income_per_minute(player)
		var structures = player.get_children().filter(func(u): return u is Structure)
		var queue_texts = []
		for structure in structures:
			if structure.production_queue == null:
				continue
			for element in structure.production_queue.get_elements():
				queue_texts.append(
					(
						"%s %d%%"
						% [Factions.display_name(element.variant), int(element.progress() * 100.0)]
					)
				)
		lines.append(
			(
				"%s: Schrott %d, Kristall %d, Einkommen/min %d / %d, Armeewert %d, Gebäude %d"
				% [
					Factions.info(Factions.faction_of(player))["name"],
					player.resource_a,
					player.resource_b,
					income[0],
					income[1],
					army_value(player),
					structures.size()
				]
			)
		)
		lines.append(
			(
				"   Upgrades Waffen %d / Panzerung %d, Energie %d, Aktionen/min %d"
				% [
					player.upgrade_weapons,
					player.upgrade_armor,
					player.energy,
					_match.actions_per_minute(player)
				]
			)
		)
		if not queue_texts.is_empty():
			lines.append("   Produktion: " + ", ".join(queue_texts))
	return "\n".join(lines)
