## Multiplayer über Godots High-Level-Multiplayer-API (ENet).
##
## Der Host ist autoritativ: Er simuliert die komplette Partie (Wegfindung,
## Kampf, KI, Produktion). Clients schicken nur Befehle (siehe
## Match.send_command) und bekommen Einheiten über MultiplayerSpawner sowie
## Positionen/Leben über MultiplayerSynchronizer zurück.
extends Node

signal lobby_changed
signal connection_failed
signal disconnected
signal all_clients_ready_for_match

const DEFAULT_PORT = 7777
const MAX_CLIENTS = 7

const MatchSettings = preload("res://source/data-model/MatchSettings.gd")
const PlayerSettings = preload("res://source/data-model/PlayerSettings.gd")
const LoadingScene = preload("res://source/main-menu/Loading.tscn")

var peers = {}  # peer_id -> Spielername (inkl. Host mit id 1)

var _local_name = "Player"
var _clients_ready_for_match = []


func _ready():
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online():
	return (
		multiplayer.multiplayer_peer != null
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	)


## true auf Clients einer Online-Partie. Dort wird nichts simuliert.
func is_client():
	return is_online() and not multiplayer.is_server()


func host(player_name, port = DEFAULT_PORT):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_local_name = player_name
	peers = {1: player_name}
	lobby_changed.emit()
	return OK


func join(address, player_name, port = DEFAULT_PORT):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_local_name = player_name
	peers = {}
	return OK


func leave():
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peers = {}
	lobby_changed.emit()


func lan_addresses():
	return Array(IP.get_local_addresses()).filter(
		func(ip):
			return ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172.")
	)


## Nur Host: verteilt die Spieler auf die Slots der Karte und startet bei allen.
## Mit humans_vs_ai spielen alle Menschen in Team 1 gegen die KIs in Team 2.
func start_match(map_path, fill_free_slots_with_ai = true, humans_vs_ai = false):
	assert(multiplayer.is_server(), "only host can start a match")
	var slots = Constants.Match.MAPS[map_path]["players"]
	var peer_ids = peers.keys()
	peer_ids.sort()
	var players = []
	for slot in range(slots):
		if slot < peer_ids.size():
			(
				players
				. append(
					{
						"controller": Constants.PlayerType.HUMAN,
						"peer_id": peer_ids[slot],
						"slot": slot,
						"team": 1 if humans_vs_ai else 0,
					}
				)
			)
		elif fill_free_slots_with_ai:
			players.append(
				{
					"controller": Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI,
					"peer_id": 0,
					"slot": slot,
					"team": 2 if humans_vs_ai else 0,
				}
			)
	_clients_ready_for_match = []
	multiplayer.multiplayer_peer.refuse_new_connections = true
	_start_match.rpc(map_path, players)


## Client meldet dem Host, dass seine Match-Szene steht.
func report_match_ready():
	if is_client():
		_client_ready_for_match.rpc_id(1)


func are_all_clients_ready_for_match():
	for peer_id in multiplayer.get_peers():
		if not peer_id in _clients_ready_for_match:
			return false
	return true


@rpc("authority", "call_local", "reliable")
func _start_match(map_path, players):
	var match_settings = MatchSettings.new()
	match_settings.visible_player = 0
	for player_id in range(players.size()):
		var player_settings = PlayerSettings.new()
		player_settings.controller = players[player_id]["controller"]
		player_settings.peer_id = players[player_id]["peer_id"]
		player_settings.team = players[player_id].get("team", 0)
		player_settings.color = Constants.Player.COLORS[players[player_id]["slot"]]
		match_settings.players.append(player_settings)
		if player_settings.peer_id == multiplayer.get_unique_id():
			match_settings.visible_player = player_id

	var loading = LoadingScene.instantiate()
	loading.match_settings = match_settings
	loading.map_path = map_path
	var tree = get_tree()
	var previous_scene = tree.current_scene
	tree.root.add_child(loading)
	tree.current_scene = loading
	if previous_scene != null:
		previous_scene.queue_free()


@rpc("any_peer", "reliable")
func _client_ready_for_match():
	var sender = multiplayer.get_remote_sender_id()
	if not sender in _clients_ready_for_match:
		_clients_ready_for_match.append(sender)
	if are_all_clients_ready_for_match():
		all_clients_ready_for_match.emit()


@rpc("any_peer", "reliable")
func _register_player(player_name):
	if not multiplayer.is_server():
		return
	peers[multiplayer.get_remote_sender_id()] = player_name
	_sync_lobby.rpc(peers)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _sync_lobby(new_peers):
	peers = new_peers
	lobby_changed.emit()


func _on_connected_to_server():
	_register_player.rpc_id(1, _local_name)


func _on_connection_failed():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()


func _on_peer_disconnected(peer_id):
	if not multiplayer.is_server():
		return
	peers.erase(peer_id)
	_sync_lobby.rpc(peers)
	lobby_changed.emit()
	if are_all_clients_ready_for_match():
		all_clients_ready_for_match.emit()


func _on_server_disconnected():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peers = {}
	disconnected.emit()
	get_tree().paused = false
	if get_tree().current_scene != null and get_tree().current_scene.name == "Match":
		get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
