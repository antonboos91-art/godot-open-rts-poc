## Menue-Effekte fuer alle Buttons der Menue-Szenen (source/main-menu/*):
## Beim Ueberfahren leuchtet der Button auf (orange Glut, heller Rand, leises Ticken),
## beim Klicken kommt ein harter Metall-Klick wie in Dark Reign. Laeuft als Autoload,
## damit der Klick auch beim Szenenwechsel zu Ende klingt.
extends Node

const MENU_DIR = "res://source/main-menu/"
const CLICK = preload("res://assets/sounds/ui_click.wav")
const HOVER = preload("res://assets/sounds/ui_hover.wav")
const GLOW = Color(1.0, 0.45, 0.12)

var _click_player = AudioStreamPlayer.new()
var _hover_player = AudioStreamPlayer.new()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click_player.stream = CLICK
	_hover_player.stream = HOVER
	_hover_player.volume_db = -8.0
	add_child(_click_player)
	add_child(_hover_player)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node):
	if not node is BaseButton or node.has_meta("menu_fx"):
		return
	var scene = node.owner.scene_file_path if node.owner != null else ""
	if not scene.begins_with(MENU_DIR):
		return
	node.set_meta("menu_fx", true)
	if node is Button:
		_style(node)
	node.mouse_entered.connect(_on_hover.bind(node, true))
	node.mouse_exited.connect(_on_hover.bind(node, false))
	node.focus_entered.connect(_on_hover.bind(node, true))
	node.focus_exited.connect(_on_hover.bind(node, false))
	node.button_down.connect(_on_pressed.bind(node))


func _box(bg, border, glow_size):
	var box = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(GLOW, 0.55 if glow_size > 0 else 0.0)
	box.shadow_size = glow_size
	return box


## Dunkle Metallplatte, beim Ueberfahren gluehend
func _style(button):
	button.add_theme_stylebox_override("normal", _box(Color(0.07, 0.06, 0.06, 0.88), Color(0.42, 0.3, 0.2), 0))
	button.add_theme_stylebox_override("hover", _box(Color(0.24, 0.1, 0.03, 0.95), Color(1.0, 0.62, 0.25), 14))
	button.add_theme_stylebox_override("focus", _box(Color(0.24, 0.1, 0.03, 0.0), Color(1.0, 0.62, 0.25), 10))
	button.add_theme_stylebox_override("pressed", _box(Color(0.45, 0.16, 0.03, 1.0), Color(1.0, 0.85, 0.5), 20))
	button.add_theme_stylebox_override("disabled", _box(Color(0.05, 0.05, 0.05, 0.7), Color(0.2, 0.2, 0.2), 0))
	button.add_theme_color_override("font_color", Color(0.86, 0.8, 0.72))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.6))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	button.add_theme_constant_override("outline_size", 4)


func _on_hover(button, on):
	if button.disabled and on:
		return
	var tween = button.create_tween()
	tween.tween_property(button, "modulate", Color(1.25, 1.12, 1.0) if on else Color.WHITE, 0.12)
	if on and button.is_hovered():
		_hover_player.play()


func _on_pressed(button):
	if button.disabled:
		return
	_click_player.play()
	button.pivot_offset = button.size / 2.0
	var tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.05)
	tween.tween_property(button, "scale", Vector2.ONE, 0.08)
