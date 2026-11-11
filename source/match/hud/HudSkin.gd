## HUD im StarCraft/C&C-Stil: unten eine gemalte Konsole je Volk (assets/ui/hud/console_<volk>.png,
## erzeugt mit tools/comfyui/gen_hud_console.py + tools/make_hud_console.py). In ihren Bildschirm-Ausschnitten
## sitzen Minikarte, Auswahlfeld (Einheiten-Hologramme), Portraet und Befehlsfeld. Die Konsole skaliert mit der
## Fensterhoehe, ihr mittlerer Teil dehnt sich mit der Breite. Oben rechts die Ressourcen-Anzeige.
## Wird von Match.gd an den HUD-CanvasLayer gehaengt; die alten Knoten bleiben erhalten (Tests, Mehrspieler).
extends Node

const Factions = preload("res://source/match/factions/Factions.gd")
const PixelSprite = preload("res://source/match/units/traits/PixelSprite.gd")
const Human = preload("res://source/match/players/human/Human.gd")
const HOLO_SHADER = preload("res://source/shaders/ui/hologram.gdshader")
const PORTRAIT_SHADER = preload("res://source/shaders/ui/portrait.gdshader")

const PORTRAIT_DIR = "res://assets/ui/portraits/"
const ICON_DIR = "res://assets/ui/hud/"
const MAX_TILES = 28
const ACCENTS = {"shibas": Color(0.35, 0.85, 1.0), "katzen": Color(0.78, 0.4, 1.0), "baeren": Color(1.0, 0.62, 0.22)}
const TEXT = Color(0.86, 0.9, 0.92)

var theme = null
var _accent = Color(0.35, 0.85, 1.0)
var _hud = null
var _human = null
var _console = null
var _console_meta = {}
var _selection_panel = null
var _tiles = null
var _single = null
var _single_icon = null
var _single_name = null
var _single_hp = null
var _single_hp_bar = null
var _single_stats = null
var _portrait_frame = null
var _portrait = null
var _portrait_name = null
var _res = {}
var _icon_cache = {}
var _dirty = true


func _ready():
	_hud = get_parent()
	var match_node = _hud.get_parent()
	if not match_node.is_node_ready():
		await match_node.ready
	# Spieler entstehen erst in Match._ready
	while get_tree().get_nodes_in_group("players").is_empty():
		await get_tree().process_frame
	await get_tree().process_frame
	_human = match_node._get_human_player() if match_node.has_method("_get_human_player") else null
	var fac = Factions.faction_of(_human) if _human != null else Factions.SHIBAS
	if not fac in ACCENTS:
		fac = Factions.SHIBAS
	_accent = ACCENTS[fac]
	theme = build_theme(_accent)
	for child in _hud.get_children():
		if child is Control:
			child.theme = theme
	_build_console(fac)
	_build_bottom_bar()
	_build_resources()
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()
	MatchSignals.unit_selected.connect(func(_u): _dirty = true)
	MatchSignals.unit_deselected.connect(func(_u): _dirty = true)
	MatchSignals.unit_died.connect(func(_u): _dirty = true)
	var timer = Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)


# ---------------------------------------------------------------- Theme

static func _box(bg, border, glow_alpha = 0.28, border_w = 2, glow = Color(0.35, 0.85, 1.0)):
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(3)
	s.shadow_color = Color(glow.r, glow.g, glow.b, glow_alpha)
	s.shadow_size = 7 if glow_alpha > 0.0 else 0
	s.set_content_margin_all(5)
	s.anti_aliasing = true
	return s


static func build_theme(accent = Color(0.35, 0.85, 1.0)):
	var t = Theme.new()
	var empty = StyleBoxEmpty.new()
	t.set_stylebox("panel", "PanelContainer", empty)
	t.set_stylebox("panel", "Panel", empty)
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.02, 0.03, 0.035, 0.96), accent, 0.3, 1, accent))
	var dim = Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5)
	t.set_stylebox("normal", "Button", _box(Color(0.03, 0.04, 0.05, 0.92), dim, 0.15, 1, accent))
	t.set_stylebox("hover", "Button", _box(Color(0.06, 0.09, 0.11, 0.95), accent, 0.5, 2, accent))
	t.set_stylebox("pressed", "Button", _box(Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.97), accent.lightened(0.4), 0.7, 2, accent))
	t.set_stylebox("disabled", "Button", _box(Color(0.02, 0.02, 0.025, 0.9), Color(0.16, 0.17, 0.18), 0.0, 1, accent))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for item in ["Button", "Label"]:
		t.set_color("font_color", item, TEXT)
		t.set_color("font_outline_color", item, Color(0, 0, 0, 0.9))
		t.set_constant("outline_size", item, 4)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.42, 0.45))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t


# ---------------------------------------------------------------- Konsole

func _build_console(fac):
	var base = ICON_DIR + "console_" + fac
	if not ResourceLoader.exists(base + ".png") or not FileAccess.file_exists(base + ".json"):
		return
	_console_meta = JSON.parse_string(FileAccess.open(base + ".json", FileAccess.READ).get_as_text())
	_console = NinePatchRect.new()
	_console.name = "Console"
	_console.texture = load(base + ".png")
	_console.mouse_filter = Control.MOUSE_FILTER_STOP
	var sel = _console_meta["rects"]["selection"]
	_console.patch_margin_left = int(sel[0]) + 80
	_console.patch_margin_right = int(_console_meta["width"]) - int(sel[2]) + 80
	_hud.add_child(_console)
	_hud.move_child(_console, 0)


## Bildschirm-Rechteck der Konsole in Fensterkoordinaten
func _screen_rect(key):
	var vp = get_viewport().get_visible_rect().size
	var cw = float(_console_meta["width"])
	var ch = float(_console_meta["height"])
	var k = _console.scale.x
	var r = _console_meta["rects"][key]
	var y0 = vp.y - (ch - r[1]) * k
	var y1 = vp.y - (ch - r[3]) * k
	var x0 = r[0] * k
	var x1 = r[2] * k
	if key in ["portrait", "command"]:
		x0 = vp.x - (cw - r[0]) * k
		x1 = vp.x - (cw - r[2]) * k
	elif key == "selection":
		x1 = vp.x - (cw - r[2]) * k
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))


func _place(node, rect, pad = 4.0):
	if node == null:
		return
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = rect.position + Vector2(pad, pad)
	node.size = rect.size - Vector2(pad, pad) * 2


func _layout():
	if _console == null:
		return
	var vp = get_viewport().get_visible_rect().size
	var ch = float(_console_meta["height"])
	var k = clamp(vp.y * 0.27, 200.0, 440.0) / ch
	_console.scale = Vector2(k, k)
	_console.size = Vector2(vp.x / k, ch)
	_console.position = Vector2(0, vp.y - ch * k)
	# Minikarte in ihren Bildschirm
	var minimap_box = _hud.get_node_or_null("MarginContainer")
	if minimap_box != null:
		var r = _screen_rect("minimap")
		var side = min(r.size.x, r.size.y) - 6
		minimap_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		minimap_box.grow_vertical = Control.GROW_DIRECTION_END
		minimap_box.add_theme_constant_override("margin_left", 0)
		minimap_box.add_theme_constant_override("margin_bottom", 0)
		minimap_box.position = r.position + (r.size - Vector2(side, side)) / 2.0
		minimap_box.size = Vector2(side, side)
		var mm = minimap_box.get_node_or_null("Minimap")
		if mm != null:
			mm.custom_minimum_size = Vector2(side, side)
	_place(_selection_panel, _screen_rect("selection"), 10)
	_place(_portrait_frame, _screen_rect("portrait"), 2)
	_portrait.custom_minimum_size = _portrait_frame.size - Vector2(0, 22)
	# Befehlsfeld: Knopfraster auf den Bildschirm skalieren, Produktionsliste ueber die Konsole
	var cmd = _hud.get_node_or_null("MarginContainer3")
	if cmd != null:
		var r = _screen_rect("command")
		var grid_w = 4 * 48 + 3 * 4 + 16
		var s = min(r.size.x / grid_w, r.size.y / grid_w) * 0.96
		var queue = cmd.find_child("ProductionQueue", true, false)
		if queue != null and queue.get_parent() != _hud:
			queue.reparent(_hud)
		cmd.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cmd.grow_horizontal = Control.GROW_DIRECTION_END
		cmd.grow_vertical = Control.GROW_DIRECTION_END
		cmd.size = Vector2(grid_w, grid_w)
		cmd.add_theme_constant_override("margin_right", 0)
		cmd.add_theme_constant_override("margin_bottom", 0)
		cmd.scale = Vector2(s, s)
		cmd.position = r.position + (r.size - Vector2(grid_w, grid_w) * s) / 2.0
		if queue != null:
			queue.set_anchors_preset(Control.PRESET_TOP_LEFT)
			queue.position = Vector2(r.position.x, _console.position.y - 64)


# ---------------------------------------------------------------- Auswahl + Portraet

func _build_bottom_bar():
	_selection_panel = PanelContainer.new()
	_selection_panel.name = "SelectionPanel"
	_selection_panel.theme = theme
	_selection_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_selection_panel.clip_contents = true
	_hud.add_child(_selection_panel)
	_hud.move_child(_selection_panel, 1)
	var stack = Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_panel.add_child(stack)
	_tiles = GridContainer.new()
	_tiles.columns = 14
	_tiles.add_theme_constant_override("h_separation", 4)
	_tiles.add_theme_constant_override("v_separation", 4)
	_tiles.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_tiles)
	# Einzelauswahl: grosses Hologramm + Name, Lebensbalken, Werte
	_single = HBoxContainer.new()
	_single.set_anchors_preset(Control.PRESET_FULL_RECT)
	_single.add_theme_constant_override("separation", 18)
	stack.add_child(_single)
	_single_icon = TextureRect.new()
	_single_icon.custom_minimum_size = Vector2(130, 130)
	_single_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_single_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_single_icon.material = _holo_material()
	_single.add_child(_single_icon)
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_single.add_child(info)
	_single_name = Label.new()
	_single_name.add_theme_font_size_override("font_size", 24)
	_single_name.add_theme_color_override("font_color", _accent.lightened(0.35))
	info.add_child(_single_name)
	_single_hp_bar = ProgressBar.new()
	_single_hp_bar.custom_minimum_size = Vector2(260, 12)
	_single_hp_bar.show_percentage = false
	_single_hp_bar.add_theme_stylebox_override("background", _box(Color(0.03, 0.05, 0.04), Color(0.2, 0.3, 0.25), 0.0, 1))
	_single_hp_bar.add_theme_stylebox_override("fill", _box(Color(0.3, 0.95, 0.45), Color(0.3, 0.95, 0.45), 0.35, 0, Color(0.3, 1.0, 0.45)))
	info.add_child(_single_hp_bar)
	_single_hp = Label.new()
	info.add_child(_single_hp)
	_single_stats = Label.new()
	_single_stats.add_theme_color_override("font_color", Color(0.65, 0.7, 0.72))
	info.add_child(_single_stats)
	# Portraet
	_portrait_frame = PanelContainer.new()
	_portrait_frame.name = "PortraitPanel"
	_portrait_frame.theme = theme
	_portrait_frame.clip_contents = true
	_hud.add_child(_portrait_frame)
	_hud.move_child(_portrait_frame, 1)
	var pv = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	_portrait_frame.add_child(pv)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(_portrait)
	_portrait_name = Label.new()
	_portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_name.add_theme_font_size_override("font_size", 13)
	_portrait_name.clip_text = true
	pv.add_child(_portrait_name)


func _holo_material():
	var m = ShaderMaterial.new()
	m.shader = HOLO_SHADER
	m.set_shader_parameter("tint", Color(0.3, 1.0, 0.5))
	return m


func _selected():
	return get_tree().get_nodes_in_group("selected_units").filter(func(u): return is_instance_valid(u) and u.is_inside_tree())


func _tick():
	_update_resources()
	var sel = _selected()
	if _dirty:
		_dirty = false
		_rebuild_selection(sel)
	_update_health(sel)


func _icon(variant, unit):
	if not _icon_cache.has(variant):
		var color = unit.color if unit != null and "color" in unit else Color(0.8, 0.8, 0.8)
		_icon_cache[variant] = PixelSprite.icon_for(variant, color)
	return _icon_cache[variant]


func _rebuild_selection(sel):
	for c in _tiles.get_children():
		c.queue_free()
	var first = sel[0] if not sel.is_empty() else null
	_single.visible = sel.size() == 1
	_tiles.visible = sel.size() > 1
	if sel.size() > 1:
		var tile = clamp(_selection_panel.size.y / 2.0 - 6.0, 40.0, 72.0)
		_tiles.columns = max(1, int(_selection_panel.size.x / (tile + 4)))
		for u in sel.slice(0, MAX_TILES):
			var b = Button.new()
			b.custom_minimum_size = Vector2(tile, tile)
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = u.display_name if "display_name" in u else ""
			var tr = TextureRect.new()
			tr.texture = _icon(Factions.variant_of(u), u)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.offset_left = 4
			tr.offset_top = 4
			tr.offset_right = -4
			tr.offset_bottom = -4
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.material = _holo_material()
			b.add_child(tr)
			b.set_meta("unit", u)
			b.pressed.connect(_select_only.bind(u))
			_tiles.add_child(b)
	if first != null:
		var variant = Factions.variant_of(first)
		_single_icon.texture = _icon(variant, first)
		_single_name.text = first.display_name if "display_name" in first else variant
		var st = Factions.stats(variant)
		var parts = []
		if "attack_damage" in st and st.get("attack_interval", 0) > 0:
			parts.append("Schaden %d  (%.1f/s)" % [st["attack_damage"], st["attack_damage"] / st["attack_interval"]])
		if "attack_range" in st:
			parts.append("Reichweite %.0f" % st["attack_range"])
		if first.get("movement_speed") != null and first.movement_speed > 0:
			parts.append("Tempo %.1f" % first.movement_speed)
		_single_stats.text = "\n".join(parts)
	_set_portrait(first)


func _set_portrait(unit):
	if unit == null:
		_portrait.texture = null
		_portrait.material = null
		_portrait_name.text = ""
		return
	var variant = Factions.variant_of(unit)
	var path = PORTRAIT_DIR + variant.replace("/", "_") + ".jpg"
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
		var m = ShaderMaterial.new()
		m.shader = PORTRAIT_SHADER
		_portrait.material = m
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		_portrait.texture = _icon(variant, unit)
		_portrait.material = _holo_material()
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_name.text = unit.display_name if "display_name" in unit else variant


func _update_health(sel):
	for b in _tiles.get_children():
		var u = b.get_meta("unit", null)
		if u == null or not is_instance_valid(u) or b.get_child_count() == 0:
			continue
		if u.hp != null and u.hp_max != null and u.hp_max > 0:
			b.get_child(0).material.set_shader_parameter("health", float(u.hp) / float(u.hp_max))
	if sel.size() == 1:
		var u = sel[0]
		if u.hp != null and u.hp_max != null and u.hp_max > 0:
			_single_hp_bar.max_value = u.hp_max
			_single_hp_bar.value = u.hp
			_single_hp.text = "%d / %d" % [u.hp, u.hp_max]
			_single_icon.material.set_shader_parameter("health", float(u.hp) / float(u.hp_max))


func _select_only(unit):
	if not is_instance_valid(unit):
		return
	MatchSignals.deselect_all_units.emit()
	var s = unit.find_child("Selection", false, false)
	if s != null:
		s.select()


# ---------------------------------------------------------------- Ressourcen oben rechts

func _build_resources():
	if _human == null:
		return
	# alte Debug-Leisten oben links ausblenden (Zuschauer-Partien behalten sie)
	var old = _hud.find_child("Resources", true, false)
	if old != null and old.get_parent() != null:
		old.get_parent().visible = false
	var panel = PanelContainer.new()
	panel.name = "ResourcePanel"
	panel.theme = theme
	var bar = _box(Color(0.0, 0.0, 0.0, 0.62), Color(_accent.r * 0.5, _accent.g * 0.5, _accent.b * 0.5, 0.8), 0.12, 1, _accent)
	bar.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", bar)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -470
	panel.offset_right = -8
	panel.offset_top = 8
	panel.offset_bottom = 54
	_hud.add_child(panel)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 22)
	panel.add_child(row)
	for key in ["scrap", "crystal", "power", "supply"]:
		var box = HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.tooltip_text = {"scrap": "Schrott", "crystal": "Kristall", "power": "Strom: erzeugt / verbraucht", "supply": "Einheiten"}[key]
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var p = ICON_DIR + key + ".png"
		if ResourceLoader.exists(p):
			icon.texture = load(p)
		box.add_child(icon)
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 20)
		box.add_child(label)
		row.add_child(box)
		_res[key] = label
	_update_resources()


func _update_resources():
	if _human == null or _res.is_empty():
		return
	_res["scrap"].text = str(_human.resource_a)
	_res["crystal"].text = str(_human.resource_b)
	if Factions.faction_of(_human) != Factions.CORE:
		var power = _human.get_power()
		_res["power"].text = "%d / %d" % [power[0], power[1]]
		_res["power"].add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if power[1] > power[0] else TEXT)
	else:
		_res["power"].get_parent().visible = false
	var count = 0
	for u in get_tree().get_nodes_in_group("controlled_units"):
		if not u.has_method("is_constructed"):
			count += 1
	_res["supply"].text = str(count)
