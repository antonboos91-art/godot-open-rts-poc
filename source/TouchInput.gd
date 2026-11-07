## Übersetzt Touch-Gesten in die Mauseingaben, die das Spiel bereits versteht,
## und steuert die Kamera direkt.
##
##   Tippen                 -> Linksklick (auswählen, UI-Buttons)
##   Ein Finger ziehen      -> Linke Maustaste gedrückt ziehen (Auswahlrahmen)
##   Lange drücken          -> Rechtsklick (Bewegen / Angreifen / Sammeln)
##   Zwei Finger ziehen     -> Kamera verschieben
##   Zwei Finger kneifen    -> Zoomen
extends Node

const TAP_MOVE_THRESHOLD_PX = 18.0
const LONG_PRESS_SEC = 0.45
const PINCH_ZOOM_STEP_PX = 60.0

var _touches = {}  # index -> Position
var _primary_index = -1
var _primary_start = Vector2.ZERO
var _primary_time = 0.0
var _primary_dragging = false
var _primary_consumed = false  # Long-Press ausgelöst oder Zweifinger-Geste gestartet
var _pinch_distance_accum = 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event):
	if event is InputEventScreenTouch:
		_on_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_on_drag(event)
		get_viewport().set_input_as_handled()


func _process(delta):
	if _primary_index == -1 or _primary_dragging or _primary_consumed:
		return
	_primary_time += delta
	if _primary_time >= LONG_PRESS_SEC:
		_primary_consumed = true
		_emit_mouse_motion(_primary_start, Vector2.ZERO)
		_emit_mouse_button(_primary_start, MOUSE_BUTTON_RIGHT, true)
		_emit_mouse_button(_primary_start, MOUSE_BUTTON_RIGHT, false)


func _on_touch(event: InputEventScreenTouch):
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_primary_index = event.index
			_primary_start = event.position
			_primary_time = 0.0
			_primary_dragging = false
			_primary_consumed = false
		elif _touches.size() == 2:
			# Zweiter Finger: laufende Ein-Finger-Geste abbrechen
			if _primary_dragging:
				_emit_mouse_button(_touches[_primary_index], MOUSE_BUTTON_LEFT, false)
			_primary_dragging = false
			_primary_consumed = true
			_pinch_distance_accum = 0.0
		return

	var was_primary = event.index == _primary_index
	_touches.erase(event.index)
	if was_primary:
		if _primary_dragging:
			_emit_mouse_button(event.position, MOUSE_BUTTON_LEFT, false)
		elif not _primary_consumed:
			_emit_mouse_motion(event.position, Vector2.ZERO)
			_emit_mouse_button(event.position, MOUSE_BUTTON_LEFT, true)
			_emit_mouse_button(event.position, MOUSE_BUTTON_LEFT, false)
		_primary_index = -1
	if _touches.is_empty():
		_primary_index = -1


func _on_drag(event: InputEventScreenDrag):
	if not _touches.has(event.index):
		return
	var previous = _touches[event.index]
	_touches[event.index] = event.position

	if _touches.size() >= 2:
		_handle_two_finger_gesture(event.index, previous, event.position)
		return

	if event.index != _primary_index or _primary_consumed:
		return
	if not _primary_dragging:
		if event.position.distance_to(_primary_start) < TAP_MOVE_THRESHOLD_PX:
			return
		_primary_dragging = true
		_emit_mouse_motion(_primary_start, Vector2.ZERO)
		_emit_mouse_button(_primary_start, MOUSE_BUTTON_LEFT, true)
	_emit_mouse_motion(event.position, event.relative, MOUSE_BUTTON_MASK_LEFT)


func _handle_two_finger_gesture(moved_index, previous_pos, new_pos):
	var keys = _touches.keys()
	var other_index = keys[0] if keys[0] != moved_index else keys[1]
	var other_pos = _touches[other_index]

	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	# Verschieben: halbe Bewegung, da beide Finger je ein Event schicken
	if camera.has_method("pan_by_screen_delta"):
		camera.pan_by_screen_delta((new_pos - previous_pos) * 0.5)
	# Zoomen über Abstandsänderung
	if camera.has_method("set_size_safely"):
		var distance_change = new_pos.distance_to(other_pos) - previous_pos.distance_to(other_pos)
		_pinch_distance_accum += distance_change
		while _pinch_distance_accum >= PINCH_ZOOM_STEP_PX:
			_pinch_distance_accum -= PINCH_ZOOM_STEP_PX
			camera.set_size_safely(camera.size - 1)
		while _pinch_distance_accum <= -PINCH_ZOOM_STEP_PX:
			_pinch_distance_accum += PINCH_ZOOM_STEP_PX
			camera.set_size_safely(camera.size + 1)


func _emit_mouse_button(pos: Vector2, button: MouseButton, pressed: bool):
	var ev = InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = button
	ev.pressed = pressed
	ev.button_mask = (
		(MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT)
		if pressed
		else 0
	)
	Input.parse_input_event(ev)


func _emit_mouse_motion(pos: Vector2, relative: Vector2, mask: int = 0):
	var ev = InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = relative
	ev.button_mask = mask
	Input.parse_input_event(ev)
