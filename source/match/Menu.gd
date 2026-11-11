extends CanvasLayer


func _ready():
	_add_surrender_button()
	hide()


func _unhandled_input(event):
	if event.is_action_pressed("toggle_match_menu") and (visible or not get_tree().paused):
		_toggle()


func _toggle():
	visible = not visible
	# Online kann ein Spieler die Partie nicht für alle anhalten
	get_tree().paused = visible and not Network.is_online()


func _on_resume_button_pressed():
	_toggle()


func _on_exit_button_pressed():
	MatchSignals.match_aborted.emit()
	await get_tree().create_timer(1.74).timeout  # Give voice narrator some time to finish.
	get_tree().paused = false
	Network.leave()
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")


## "Aufgeben": alle eigenen Einheiten und Gebäude werden zerstört (Niederlage), wie in Generals/SC1.
func _add_surrender_button():
	var box = find_child("VBoxContainer")
	var exit_button = find_child("ExitButton")
	if box == null or exit_button == null:
		return
	var button = Button.new()
	button.name = "SurrenderButton"
	button.text = "Aufgeben"
	button.pressed.connect(_on_surrender_button_pressed)
	box.add_child(button)
	box.move_child(button, exit_button.get_index())


func _on_surrender_button_pressed():
	var match_node = find_parent("Match")
	if match_node == null:
		return
	var locals = get_tree().get_nodes_in_group("players").filter(func(p): return p.has_method("is_local") and p.is_local() and p.find_child("UnitActionsController") != null)
	var player = locals[0] if not locals.is_empty() else null
	if player == null:
		return
	visible = false
	get_tree().paused = false
	match_node.send_command("surrender", player.get_children().filter(func(u): return u.has_method("take_hit")))
