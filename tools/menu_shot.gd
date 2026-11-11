## Startbildschirm ansehen: Hauptmenue laden, ersten Button "ueberfahren", Screenshot.
##   godot4 --path . -s tools/menu_shot.gd -- <ausgabe.png>
extends SceneTree


func _initialize():
	_run()


func _run():
	var out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "menu.png"
	root.size = Vector2i(1600, 900)
	await process_frame
	var menu = load("res://source/main-menu/Main.tscn").instantiate()
	root.add_child(menu)
	for i in range(20):
		await process_frame
	var b0 = menu.find_child("MultiplayerButton", true, false)
	print("FX ", b0.owner, " ", b0.has_meta("menu_fx"), " ", b0.get_signal_connection_list("button_down").size())
	var button = menu.find_child("MultiplayerButton", true, false)
	button.mouse_entered.emit()
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover"))
	for i in range(30):
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
