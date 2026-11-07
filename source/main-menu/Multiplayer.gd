## Lobby: Hosten oder per IP beitreten, Karte wählen, Partie starten.
extends Control

const PlayMenu = preload("res://source/main-menu/Play.gd")
const Factions = preload("res://source/match/factions/Factions.gd")

var _map_paths = []

var _faction_option = PlayMenu.FactionOption.new()
var _name_edit = LineEdit.new()
var _address_edit = LineEdit.new()
var _host_button = Button.new()
var _join_button = Button.new()
var _status_label = Label.new()
var _players_label = Label.new()
var _map_option = OptionButton.new()
var _ai_check = CheckBox.new()
var _coop_check = CheckBox.new()
var _start_button = Button.new()
var _back_button = Button.new()


func _ready():
	_build_ui()
	Network.lobby_changed.connect(_refresh)
	Network.connection_failed.connect(_on_connection_failed)
	Network.disconnected.connect(_on_disconnected)
	_refresh()


func _build_ui():
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title = Label.new()
	title.text = "MULTIPLAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_name_edit.placeholder_text = "Name"
	_name_edit.text = "Player"
	box.add_child(_name_edit)

	var faction_row = HBoxContainer.new()
	var faction_label = Label.new()
	faction_label.text = "Dein Volk:"
	faction_row.add_child(faction_label)
	_faction_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_option.item_selected.connect(
		func(_index): Network.set_local_faction(_faction_option.get_choice())
	)
	Network.set_local_faction(_faction_option.get_choice())
	faction_row.add_child(_faction_option)
	box.add_child(faction_row)

	_host_button.text = "HOST"
	_host_button.pressed.connect(_on_host_pressed)
	box.add_child(_host_button)

	var join_row = HBoxContainer.new()
	_address_edit.placeholder_text = "IP des Hosts, z. B. 192.168.0.10"
	_address_edit.text = "127.0.0.1"
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address_edit)
	_join_button.text = "JOIN"
	_join_button.pressed.connect(_on_join_pressed)
	join_row.add_child(_join_button)
	box.add_child(join_row)

	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status_label)
	box.add_child(_players_label)

	var maps = Utils.Dict.items(Constants.Match.MAPS)
	maps.sort_custom(func(a, b): return a[1]["players"] < b[1]["players"])
	_map_paths = maps.map(func(map): return map[0])
	for map_path in _map_paths:
		var map = Constants.Match.MAPS[map_path]
		_map_option.add_item("%s (%d)" % [map["name"], map["players"]])
	box.add_child(_map_option)

	_ai_check.text = "Fill free slots with AI"
	_ai_check.button_pressed = true
	box.add_child(_ai_check)

	_coop_check.text = "Team up: all humans vs AI"
	_coop_check.button_pressed = true
	box.add_child(_coop_check)

	_start_button.text = "START"
	_start_button.pressed.connect(_on_start_pressed)
	box.add_child(_start_button)

	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back_pressed)
	box.add_child(_back_button)


func _refresh():
	var online = Network.is_online()
	var is_host = online and multiplayer.is_server()
	_host_button.disabled = online
	_join_button.disabled = online
	_name_edit.editable = not online
	_address_edit.editable = not online
	_map_option.visible = is_host
	_ai_check.visible = is_host
	_coop_check.visible = is_host
	_start_button.visible = is_host
	if is_host:
		var addresses = Network.lan_addresses()
		_status_label.text = (
			"Hosting. Join with IP: %s (port %d)"
			% [
				", ".join(addresses) if not addresses.is_empty() else "see ipconfig / ip addr",
				Network.DEFAULT_PORT
			]
		)
	elif online and Network.peers.is_empty():
		_status_label.text = "Connecting..."
	elif online:
		_status_label.text = "Connected. Waiting for host to start."
	var names = []
	for peer_id in Network.peers:
		var choice = Network.factions.get(peer_id, Network.RANDOM_FACTION)
		var faction_name = (
			"Zufall" if choice == Network.RANDOM_FACTION else Factions.info(choice)["name"]
		)
		names.append(
			"%s%s (%s)" % ["* " if peer_id == 1 else "- ", Network.peers[peer_id], faction_name]
		)
	_players_label.text = "\n".join(names)


func _on_host_pressed():
	var error = Network.host(_name_edit.text)
	if error != OK:
		_status_label.text = "Could not host (error %d). Port in use?" % error
	_refresh()


func _on_join_pressed():
	var error = Network.join(_address_edit.text.strip_edges(), _name_edit.text)
	if error != OK:
		_status_label.text = "Could not connect (error %d)." % error
	_refresh()


func _on_start_pressed():
	Network.start_match(
		_map_paths[_map_option.selected], _ai_check.button_pressed, _coop_check.button_pressed
	)


func _on_connection_failed():
	_refresh()
	_status_label.text = "Connection failed."


func _on_disconnected():
	_refresh()
	_status_label.text = "Host closed the connection."


func _on_back_pressed():
	Network.leave()
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
