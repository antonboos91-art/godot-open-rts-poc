## Kurze Soundeffekte an einer Stelle der Karte (3D-Sound, Kamera ist der Hörer).
## Wird von Treffern, Explosionen, Superwaffen usw. aufgerufen; läuft auf jedem Rechner
## selbst, damit auch Clients alles hören.
extends Node

const DIR = "res://assets/sounds/"
const MIN_GAP_MS = 70
const MAX_PLAYERS = 20

var _streams = {}
var _last_played = {}
var _active = 0


func play(sound_name, position = null):
	if DisplayServer.get_name() == "headless" or _active >= MAX_PLAYERS:
		return
	var now = Time.get_ticks_msec()
	if now - _last_played.get(sound_name, -MIN_GAP_MS) < MIN_GAP_MS:
		return
	var stream = _get_stream(sound_name)
	if stream == null:
		return
	_last_played[sound_name] = now
	var player = AudioStreamPlayer3D.new() if position != null else AudioStreamPlayer.new()
	player.stream = stream
	if position != null:
		player.unit_size = 12.0
		player.max_distance = 90.0
		player.position = position
	add_child(player)
	_active += 1
	player.finished.connect(_on_finished.bind(player))
	player.play()


func _get_stream(sound_name):
	if not _streams.has(sound_name):
		var path = DIR + sound_name + ".wav"
		_streams[sound_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound_name]


func _on_finished(player):
	_active -= 1
	player.queue_free()
