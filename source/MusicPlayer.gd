## Spielmusik (Autoload "Music"): Intro beim Spielstart, in der Partie die Schleife des eigenen Volkes
## (Shibas sauberes Elektro, Katzen dunkle Ambience, Baeren sowjetischer Marsch).
## Die Stuecke stammen aus tools/music/make_music.py (assets/music/*.ogg).
extends Node

const Factions = preload("res://source/match/factions/Factions.gd")
const MUSIC_DIR = "res://assets/music/"
const INTRO_DB = -4.0
const MATCH_DB = -11.0
const FADE_S = 1.6

var _player = AudioStreamPlayer.new()
var _mode = ""  # "", "intro" oder Volk
var _tween = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Tests und Werkzeug-Skripte (-s) laufen ohne Musik
	if DisplayServer.get_name() == "headless" or "-s" in OS.get_cmdline_args():
		return
	add_child(_player)
	MatchSignals.match_started.connect(_on_match_started)
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_watch)
	add_child(timer)
	_play("intro", false, INTRO_DB)
	_mode = "intro"


func _play(track, loop, volume_db):
	var path = MUSIC_DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	_kill_tween()
	_player.stream = stream
	_player.volume_db = -45.0
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", volume_db, FADE_S)


func _fade_out():
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", -45.0, FADE_S)
	_tween.tween_callback(_player.stop)
	_mode = ""


func _kill_tween():
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _on_match_started():
	await get_tree().process_frame
	var match_node = get_tree().current_scene
	var human = match_node._get_human_player() if match_node != null and match_node.has_method("_get_human_player") else null
	var faction = Factions.faction_of(human)
	if not faction in [Factions.SHIBAS, Factions.KATZEN, Factions.BAEREN]:
		faction = Factions.SHIBAS
	_mode = faction
	_play(faction, true, MATCH_DB)


func _watch():
	if _mode == "intro" and not _player.playing:
		_mode = ""
	elif _mode in [Factions.SHIBAS, Factions.KATZEN, Factions.BAEREN]:
		var scene = get_tree().current_scene
		# Partie verlassen (zurueck im Menue): Musik ausblenden
		if scene != null and not scene.has_method("_get_human_player"):
			_fade_out()
