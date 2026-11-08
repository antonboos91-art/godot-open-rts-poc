extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")
const ShibaVoices = preload("res://source/match/players/human/ShibaVoices.gd")
## Ab so vielen Klicks kurz hintereinander auf dieselbe Einheit kommen die "genervten" Sprüche
const ANNOYED_CLICKS = 4
const ANNOYED_WINDOW_MS = 3000

var _last_ack_event = 0
var _last_clicked_unit = null
var _click_count = 0
var _last_click_ms = 0

@onready var _audio_player = find_child("AudioStreamPlayer")
@onready var _player = get_parent()


func _ready() -> void:
	MatchSignals.unit_selected.connect(_on_unit_selected)
	MatchSignals.unit_targeted.connect(_on_unit_action_requsted)
	MatchSignals.terrain_targeted.connect(_on_unit_action_requsted)


func _handle_event(event):
	if _audio_player.playing:
		return
	_audio_player.stream = Constants.Match.VoiceNarrator.EVENT_TO_ASSET_MAPPING[event]
	_audio_player.play()


## Shiba-Sprachpaket der Einheit ("engineer", "attack_hound" oder "all"), leer = Standardstimmen
static func _shiba_pack_for(unit):
	var variant = unit.get("variant")
	if variant == null or not String(variant).begins_with("shibas"):
		return ""
	if "ingenieur" in variant:
		return "engineer"
	if "schnueffler" in variant or "hund" in variant:
		return "attack_hound"
	return "all"


func _play_shiba(pack, category, interrupt = false):
	var lines = ShibaVoices.LINES.get(pack, {}).get(category, [])
	if lines.is_empty() and pack != "all":
		lines = ShibaVoices.LINES["all"].get(category, [])
	if lines.is_empty():
		return false
	if _audio_player.playing and not interrupt:
		return true
	_audio_player.stream = lines[randi() % lines.size()]
	_audio_player.play()
	return true


func _on_unit_selected(unit):
	if not unit is Structure and not unit is ResourceUnit and unit.player == _player:
		var now = Time.get_ticks_msec()
		if unit == _last_clicked_unit and now - _last_click_ms < ANNOYED_WINDOW_MS:
			_click_count += 1
		else:
			_click_count = 1
		_last_clicked_unit = unit
		_last_click_ms = now
		var pack = _shiba_pack_for(unit)
		if pack != "":
			var category = "annoyed" if _click_count >= ANNOYED_CLICKS else "select"
			if _play_shiba(pack, category, category == "annoyed"):
				return
		_handle_event(Constants.Match.VoiceNarrator.Events.UNIT_HELLO)
	# TODO: handle building - perhaps with some sound instead of voice


func _on_unit_action_requsted(target):
	var mine = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return not unit is Structure and unit.player == _player
	)
	if not mine.is_empty():
		var pack = _shiba_pack_for(mine[0])
		if pack != "":
			var is_enemy = (
				target is Node
				and target.get("player") != null
				and target.player != _player
				and not target is ResourceUnit
			)
			if _play_shiba(pack, "attack" if is_enemy else "move"):
				return
		_handle_event(
			(
				Constants.Match.VoiceNarrator.Events.UNIT_ACK_1
				if _last_ack_event == 0
				else Constants.Match.VoiceNarrator.Events.UNIT_ACK_2
			)
		)
		_last_ack_event = (_last_ack_event + 1) % 2
