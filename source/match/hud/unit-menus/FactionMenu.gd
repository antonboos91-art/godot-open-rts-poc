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
	show()
	return true


func show_construction(player):
	_player = player
	_producer = null
	_build(Factions.buildable(player))
	show()
	return true


func _build(variants):
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


func _create_button(variant):
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
	button.pressed.connect(_on_button_pressed.bind(variant))
	return button


func _refresh_availability():
	if not visible or _player == null:
		return
	for variant in _buttons:
		var button = _buttons[variant]
		var missing = Factions.missing_requirements(_player, variant)
		button.disabled = not missing.is_empty()
		button.modulate = Color(0.6, 0.6, 0.6) if button.disabled else Color.WHITE
		button.tooltip_text = _describe(variant, missing)


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
