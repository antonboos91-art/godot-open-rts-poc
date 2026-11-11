## Sprachausgabe der eigenen Einheiten je Volk (FactionVoices.gd, erzeugt von tools/voice_pipeline):
## Auswahl, Bewegung, Angriff, genervte Sprueche bei Dauerklicken und Todesschreie.
## Sammler, Fahrzeuge, Flieger, Kampftiere und Ingenieure haben eigene Pakete; fehlt dort eine
## Kategorie, spricht das allgemeine Paket "all", danach die alte Standardstimme.
extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")
const Factions = preload("res://source/match/factions/Factions.gd")
const FactionVoices = preload("res://source/match/players/human/FactionVoices.gd")
## Ab so vielen Klicks kurz hintereinander auf dieselbe Einheit kommen die "genervten" Sprueche
const ANNOYED_CLICKS = 4
const ANNOYED_WINDOW_MS = 3000
const BEASTS = ["kampfhund", "panther", "kodiak"]
const ENGINEER_ABILITIES = ["capture", "hack", "repair"]
## Todesschreie nicht bei jedem Tod, sonst wird es im grossen Gefecht zu viel
const DEATH_COOLDOWN_MS = 6000

var _last_ack_event = 0
var _last_clicked_unit = null
var _click_count = 0
var _last_click_ms = 0
var _last_line = null
var _last_death_ms = -999999
var _building_player = AudioStreamPlayer.new()

@onready var _audio_player = find_child("AudioStreamPlayer")
@onready var _player = get_parent()


func _ready() -> void:
	MatchSignals.unit_selected.connect(_on_unit_selected)
	MatchSignals.unit_targeted.connect(_on_unit_action_requsted)
	MatchSignals.terrain_targeted.connect(_on_unit_action_requsted)
	MatchSignals.unit_died.connect(_on_unit_died)
	_building_player.volume_db = -4.0
	add_child(_building_player)


func _handle_event(event):
	if _audio_player.playing:
		return
	_audio_player.stream = Constants.Match.VoiceNarrator.EVENT_TO_ASSET_MAPPING[event]
	_audio_player.play()


## Sprachpaket einer Einheit: all, worker, vehicle, air, beast, engineer
static func pack_for(unit):
	var variant = String(unit.get("variant")) if unit.get("variant") != null else ""
	if variant.get_slice("/", 1) in BEASTS:
		return "beast"
	if unit.type != "Worker" and Factions.ability(variant) in ENGINEER_ABILITIES:
		return "engineer"
	match unit.type:
		"Worker":
			return "worker"
		"Tank":
			return "vehicle"
		"Helicopter", "Drone":
			return "air"
	return "all"


func _lines(unit, category):
	var packs = FactionVoices.LINES.get(Factions.faction_of(_player), {})
	var pack = pack_for(unit)
	var lines = packs.get(pack, {}).get(category, [])
	if lines.is_empty() and pack != "all":
		lines = packs.get("all", {}).get(category, [])
	return lines


func _play(unit, category, interrupt = false):
	var lines = _lines(unit, category)
	if lines.is_empty():
		return false
	if _audio_player.playing and not interrupt:
		return true
	# nicht zweimal hintereinander dieselbe Zeile
	var pick = lines[randi() % lines.size()]
	if pick == _last_line and lines.size() > 1:
		pick = lines[(lines.find(pick) + 1) % lines.size()]
	_last_line = pick
	_audio_player.stream = pick
	_audio_player.play()
	return true


func _on_unit_selected(unit):
	if unit is ResourceUnit or unit.player != _player:
		return
	if unit is Structure:
		_play_building_sound(unit)
		return
	var now = Time.get_ticks_msec()
	if unit == _last_clicked_unit and now - _last_click_ms < ANNOYED_WINDOW_MS:
		_click_count += 1
	else:
		_click_count = 1
	_last_clicked_unit = unit
	_last_click_ms = now
	var category = "annoyed" if _click_count >= ANNOYED_CLICKS else "select"
	if _play(unit, category, category == "annoyed"):
		return
	_handle_event(Constants.Match.VoiceNarrator.Events.UNIT_HELLO)


func _on_unit_action_requsted(target):
	var mine = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return not unit is Structure and unit.player == _player
	)
	if mine.is_empty():
		return
	var unit = mine[0]
	var pack = pack_for(unit)
	var category = "move"
	if target is ResourceUnit:
		category = "harvest" if pack == "worker" else "move"
	elif target is Node and target.get("player") != null:
		if not target.player.is_ally_of(_player) and target.player != _player:
			category = "capture" if pack == "engineer" and target is Structure else "attack"
		elif pack == "engineer" and target is Structure:
			category = "repair"
	if _play(unit, category, true):
		return
	_handle_event(
		(
			Constants.Match.VoiceNarrator.Events.UNIT_ACK_1
			if _last_ack_event == 0
			else Constants.Match.VoiceNarrator.Events.UNIT_ACK_2
		)
	)
	_last_ack_event = (_last_ack_event + 1) % 2


## Eigene Einheit faellt: ab und zu ein letzter Funkspruch (nur wenn gerade niemand spricht)
func _on_unit_died(unit):
	if unit is Structure or unit.get("player") != _player or _audio_player.playing:
		return
	var now = Time.get_ticks_msec()
	if now - _last_death_ms < DEATH_COOLDOWN_MS:
		return
	_last_death_ms = now
	_play(unit, "death")


## Eigenes Gebaeude angewaehlt: Geraeusch passend zu Volk und Gebaeudeart
## (assets/sounds/buildings/<volk>_<rolle>.wav, erzeugt mit tools/sfx/building_sfx.py)
func _play_building_sound(structure):
	var variant = String(structure.get("variant")) if structure.get("variant") != null else ""
	if not "/" in variant:
		return
	var path = "res://assets/sounds/buildings/%s_%s.wav" % [variant.get_slice("/", 0), variant.get_slice("/", 1)]
	if not ResourceLoader.exists(path):
		return
	_building_player.stream = load(path)
	_building_player.play()
