## Prüft die Touch-Gesten gegen eine echte Partie.
## Braucht ein Fenster (Physik-Picking), z. B. unter Linux ohne Monitor:
##   xvfb-run -a godot4 --rendering-driver opengl3 --resolution 1280x720 \
##     -s tests/automated/touch_input_test.gd
extends SceneTree

var _targeted = null
var _failures = 0


func _initialize():
	_run()


func _run():
	await _frames(2)
	root.add_child(load("res://tests/manual/TestPlayerVsAI.tscn").instantiate())
	await _frames(30)
	root.get_node("/root/MatchSignals").terrain_targeted.connect(func(p): _targeted = p)
	var cam = root.get_viewport().get_camera_3d()
	var unit = get_nodes_in_group("controlled_units").filter(func(u): return not u.has_method("is_constructed"))[0]
	var unit_pos = cam.unproject_position(unit.global_position)

	# Tippen auf Einheit -> ausgewählt
	_touch(0, unit_pos, true)
	await _frames(2)
	_touch(0, unit_pos, false)
	await _frames(5)
	_check(unit.is_in_group("selected_units"), "tap selects unit")

	# Lange drücken auf Boden -> Bewegungsbefehl
	var ground = Vector2(700, 320)
	_touch(0, ground, true)
	await create_timer(0.7).timeout
	_touch(0, ground, false)
	await _frames(5)
	_check(_targeted != null, "long press targets terrain")
	_check(unit.action != null, "long press gives unit an action")

	# Zwei Finger ziehen -> Kamera verschoben, Auswahl bleibt
	var before = cam.global_position
	_touch(0, Vector2(500, 500), true)
	_touch(1, Vector2(700, 500), true)
	for i in 10:
		_drag(0, Vector2(500 + i * 10, 500), Vector2(10, 0))
		_drag(1, Vector2(700 + i * 10, 500), Vector2(10, 0))
		await _frames(1)
	_touch(0, Vector2(600, 500), false)
	_touch(1, Vector2(800, 500), false)
	await _frames(2)
	_check(not cam.global_position.is_equal_approx(before), "two-finger drag pans camera")
	_check(unit.is_in_group("selected_units"), "pan keeps selection")

	# Finger auseinander -> reinzoomen
	var size_before = cam.size
	_touch(0, Vector2(800, 500), true)
	_touch(1, Vector2(900, 500), true)
	for i in 10:
		_drag(1, Vector2(900 + i * 30, 500), Vector2(30, 0))
		await _frames(1)
	_touch(0, Vector2(800, 500), false)
	_touch(1, Vector2(1200, 500), false)
	await _frames(2)
	_check(cam.size < size_before, "pinch zooms in")

	print("touch_input_test: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)


func _check(condition, label):
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_failures += 1


func _touch(index, pos, pressed):
	var e = InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index, pos, relative):
	var e = InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = relative
	Input.parse_input_event(e)


func _frames(n):
	for i in n:
		await process_frame
