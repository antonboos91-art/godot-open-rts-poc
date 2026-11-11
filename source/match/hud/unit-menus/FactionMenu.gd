## Bau- und Produktionsmenü aus den Volksdaten (Factions.gd).
## Arbeiter: Gebäude des eigenen Volks. Fertiges Gebäude: Einheiten, die es baut.
## Gesperrte Einträge (Techbaum) sind ausgegraut; der Tooltip nennt, was fehlt.
extends GridContainer

const Factions = preload("res://source/match/factions/Factions.gd")
const PixelSprite = preload("res://source/match/units/traits/PixelSprite.gd")

const SLOTS = 16
const RESERVED_SLOT = 3  # dort liegt der Abbrechen-Knopf des GenericMenu
const BUTTON_SIZE = Vector2(48, 48)

var _player = null
var _producer = null
var _buttons = {}  # Variante -> Button
var _ability_unit = null  # Einheit/Gebäude mit Spezialknopf (Entfalten, Superwaffe)
var _ability_button = null
var _ability_label = null
var _sell_target = null
var _research_buttons = {}


func _init():
	columns = 4
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready():
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_refresh_availability)
	add_child(timer)


## Menü für ein fertiges Gebäude; false, wenn es nichts produziert.
func show_production(structure):
	var variants = Factions.producible_at(structure)
	if variants.is_empty() or structure.production_queue == null:
		return false
	_player = structure.player
	_producer = structure
	_build(variants)
	_add_sell_button(structure)
	show()
	return true


## Spezialknopf: Bau-Mobil entfalten oder Superwaffe zielen. false, wenn keiner nötig ist.
func show_ability(unit):
	var variant = Factions.variant_of(unit)
	var ability = Factions.ability(variant)
	if not ability in ["deploy", "superweapon", "transport", "garrison"]:
		return false
	if unit.has_method("is_constructed") and not unit.is_constructed():
		return false
	_player = unit.player
	_producer = null
	_ability_unit = unit
	var icon_variant = Factions.deploy_target(variant) if ability == "deploy" else variant
	_build([])
	_ability_button = _create_button(icon_variant, _on_ability_pressed)
	_ability_label = _ability_button.get_child(0)
	_ability_label.text = ""
	_buttons = {}
	var first_slot = get_child(1)  # 0 ist der Timer
	remove_child(first_slot)
	first_slot.queue_free()
	add_child(_ability_button)
	move_child(_ability_button, 1)
	if unit.has_method("is_constructed"):
		_add_sell_button(unit)
	show()
	_refresh_availability()
	return true


## Laborgebäude: Waffen- und Panzerungs-Upgrades (je 3 Stufen). false, wenn es kein Labor ist.
func show_research(structure):
	if Factions.role(Factions.variant_of(structure)) != "lab":
		return false
	_player = structure.player
	_producer = null
	_build([])
	_research_buttons = {}
	var slot = 0
	for kind in ["weapons", "armor"]:
		var button = _create_text_button("WAF" if kind == "weapons" else "RÜS", _on_research_pressed.bind(kind))
		_research_buttons[kind] = button
		_put_button(slot, button)
		slot += 1
	_add_sell_button(structure)
	show()
	_refresh_availability()
	return true


func _put_button(slot, button):
	var old = get_child(1 + slot)  # 0 ist der Timer
	remove_child(old)
	old.queue_free()
	add_child(button)
	move_child(button, 1 + slot)


func _create_text_button(text, on_pressed):
	var button = Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	button.pressed.connect(on_pressed)
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button


## Verkaufen-Knopf (letzter Platz) für ein fertiges eigenes Gebäude, Entf-Taste tut dasselbe.
func _add_sell_button(structure):
	_sell_target = structure
	var button = _create_text_button("VERK.", _on_sell_pressed)
	button.tooltip_text = "Verkaufen (Entf): halber Preis zurück"
	_put_button(SLOTS - 1, button)


func _on_sell_pressed():
	if is_instance_valid(_sell_target):
		_sell_target.find_parent("Match").send_command("sell", [_sell_target])


func _on_research_pressed(kind):
	if is_instance_valid(_player):
		_player.find_parent("Match").send_command("research", get_tree().get_nodes_in_group("selected_units").filter(func(u): return u.is_in_group("controlled_units")), [kind])


func _refresh_research_buttons():
	for kind in _research_buttons:
		var button = _research_buttons[kind]
		var info = Factions.research_info(_player, kind)
		var label = button.get_child(0)
		var name = "Waffen" if kind == "weapons" else "Panzerung"
		if info.is_empty():
			button.disabled = true
			button.modulate = Color(0.6, 0.6, 0.6)
			label.text = "MAX"
			button.tooltip_text = "%s: höchste Stufe erreicht" % name
			continue
		var affordable = _player.has_resources(info["cost"])
		button.disabled = not affordable
		button.modulate = Color.WHITE if affordable else Color(0.6, 0.6, 0.6)
		label.text = "%d/%d" % [info["cost"]["resource_a"], info["cost"]["resource_b"]]
		button.tooltip_text = (
			"%s-Upgrade Stufe %d: Schrott %d, Kristall %d, %d s\n%s"
			% [
				name,
				info["level"],
				info["cost"]["resource_a"],
				info["cost"]["resource_b"],
				int(info["time"]),
				"+15 % Schaden je Stufe" if kind == "weapons" else "-13 % erlittener Schaden je Stufe"
			]
		)


## Gebäude ohne eigenes Menü (Kraftwerk, Radar ...): nur der Verkaufen-Knopf.
func show_sell_only(structure):
	_player = structure.player
	_producer = null
	_build([])
	_add_sell_button(structure)
	show()
	return true


func show_construction(player):
	_player = player
	_producer = null
	_build(Factions.buildable(player))
	show()
	return true


func _build(variants):
	_ability_unit = null
	_sell_target = null
	_research_buttons = {}
	_ability_button = null
	for child in get_children():
		if not child is Timer:
			remove_child(child)
			child.queue_free()
	_buttons = {}
	var index = 0
	for slot in range(SLOTS):
		if slot == RESERVED_SLOT or index >= variants.size():
			var padding = Control.new()
			padding.custom_minimum_size = BUTTON_SIZE
			padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(padding)
			continue
		var variant = variants[index]
		index += 1
		var button = _create_button(variant)
		_buttons[variant] = button
		add_child(button)
	_refresh_availability()


func _create_button(variant, on_pressed = null):
	var button = Button.new()
	button.name = variant.replace("/", "_")
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	var icon_texture = PixelSprite.icon_for(variant, _player.color)
	if icon_texture != null:
		button.icon = icon_texture
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.text = Factions.display_name(variant).left(3)
	var cost = Factions.cost(variant)
	var cost_label = Label.new()
	cost_label.text = "%d/%d" % [cost["resource_a"], cost["resource_b"]]
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost_label)
	button.pressed.connect(on_pressed if on_pressed != null else _on_button_pressed.bind(variant))
	return button


func _refresh_availability():
	if not visible or _player == null:
		return
	if _ability_unit != null:
		_refresh_ability_button()
		return
	_refresh_research_buttons()
	for variant in _buttons:
		var button = _buttons[variant]
		var missing = Factions.missing_requirements(_player, variant)
		button.disabled = not missing.is_empty()
		button.modulate = Color(0.6, 0.6, 0.6) if button.disabled else Color.WHITE
		button.tooltip_text = _describe(variant, missing)


func _refresh_ability_button():
	if not is_instance_valid(_ability_unit) or _ability_button == null:
		return
	var variant = Factions.variant_of(_ability_unit)
	if Factions.ability(variant) in ["transport", "garrison"]:
		var cargo = _ability_unit.cargo_count
		_ability_button.disabled = cargo == 0
		_ability_button.modulate = Color.WHITE if cargo > 0 else Color(0.6, 0.6, 0.6)
		_ability_label.text = "%d/%d" % [cargo, Factions.cargo_capacity(_ability_unit)]
		_ability_button.tooltip_text = "Absetzen (Infanterie anklicken zum Einsteigen)" if Factions.ability(variant) == "transport" else "Besatzung aussteigen lassen (Infanterie anklicken zum Einsteigen: +40 % Schaden je Soldat)"
		return
	if Factions.ability(variant) == "deploy":
		_ability_button.tooltip_text = (
			"Entfalten zu: %s" % Factions.display_name(Factions.deploy_target(variant))
		)
		return
	var charge = _ability_unit.charge_progress
	var ready = charge >= 1.0 and not _player.is_low_power()
	_ability_button.disabled = not ready
	_ability_button.modulate = Color.WHITE if ready else Color(0.6, 0.6, 0.6)
	_ability_label.text = "FEUER" if ready else "%d%%" % int(charge * 100.0)
	_ability_button.tooltip_text = (
		"%s\n%s"
		% [Factions.display_name(variant), "Bereit: Ziel anklicken" if ready else "Lädt auf"]
	)


func _on_ability_pressed():
	if not is_instance_valid(_ability_unit):
		return
	var ability = Factions.ability(Factions.variant_of(_ability_unit))
	if ability in ["transport", "garrison"]:
		_ability_unit.find_parent("Match").send_command("unload", [_ability_unit])
	elif ability == "deploy":
		_ability_unit.find_parent("Match").send_command("deploy", [_ability_unit])
	elif _ability_unit.charge_progress >= 1.0:
		MatchSignals.superweapon_targeting_requested.emit(_ability_unit)


func _describe(variant, missing):
	var e = Factions.entry(variant)
	var stats = Factions.stats(variant)
	var lines = [Factions.display_name(variant)]
	var cost = e["cost"]
	lines.append("Schrott %d, Kristall %d" % [cost["resource_a"], cost["resource_b"]])
	var details = []
	if "hp" in stats:
		details.append("%d HP" % stats["hp"])
	if "attack_damage" in stats and stats.get("attack_interval", 0) > 0:
		details.append("%.1f DPS" % (stats["attack_damage"] / stats["attack_interval"]))
	if "attack_range" in stats:
		details.append("Reichweite %.0f" % stats["attack_range"])
	if e["power"] != 0:
		details.append("Strom %+d" % e["power"])
	if not details.is_empty():
		lines.append(", ".join(details))
	if not missing.is_empty():
		lines.append("Braucht: " + ", ".join(missing))
	return "\n".join(lines)


func _on_button_pressed(variant):
	if not Factions.missing_requirements(_player, variant).is_empty():
		return
	if _producer != null:
		if is_instance_valid(_producer):
			_producer.production_queue.produce(variant)
	else:
		MatchSignals.place_structure.emit(variant)
