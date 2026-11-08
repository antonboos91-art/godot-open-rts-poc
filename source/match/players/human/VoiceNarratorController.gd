extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const Factions = preload("res://source/match/factions/Factions.gd")
const ShibaVoices = preload("res://source/match/players/human/ShibaVoices.gd")


const UNDER_ATTACK_NOTIFICATION_THRESHOLD_MS = 10 * 1000

var _last_event_handled = null
var _last_under_attack_notification_timestamp = 0
var _was_low_power = false
var _superweapon_was_ready = false

@onready var _audio_player = find_child("AudioStreamPlayer")
@onready var _player = get_parent()


func _ready():
	MatchSignals.match_started.connect(
		_handle_event.bind(Constants.Match.VoiceNarrator.Events.MATCH_STARTED)
	)
	MatchSignals.match_aborted.connect(
		_handle_event.bind(Constants.Match.VoiceNarrator.Events.MATCH_ABORTED)
	)
	MatchSignals.match_finished_with_victory.connect(
		_handle_event.bind(Constants.Match.VoiceNarrator.Events.MATCH_FINISHED_WITH_VICTORY)
	)
	MatchSignals.match_finished_with_defeat.connect(
		_handle_event.bind(Constants.Match.VoiceNarrator.Events.MATCH_FINISHED_WITH_DEFEAT)
	)
	MatchSignals.unit_damaged.connect(_on_unit_damaged)
	MatchSignals.unit_died.connect(_on_unit_died)
	MatchSignals.unit_production_started.connect(_on_production_started)
	MatchSignals.unit_production_finished.connect(_on_production_finished)
	MatchSignals.not_enough_resources_for_production.connect(_on_not_enough_resources)
	MatchSignals.not_enough_resources_for_construction.connect(_on_not_enough_resources)
	MatchSignals.unit_construction_finished.connect(_on_construction_finished)
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_power_and_superweapon)
	add_child(timer)


## Ansagen der Shibas (Funkstimme) statt der Standard-Sprecherin
func _shiba_announcer_key(event):
	var events = Constants.Match.VoiceNarrator.Events
	return {
		events.BASE_UNDER_ATTACK: "base_under_attack",
		events.UNIT_LOST: "unit_lost",
		events.UNIT_CONSTRUCTION_FINISHED: "construction_complete",
		events.UNIT_PRODUCTION_FINISHED: "training_complete",
		events.NOT_ENOUGH_RESOURCES: "treat_supplies_low_please_resupply",
	}.get(event, "")


func _is_shibas():
	return Factions.faction_of(_player) == Factions.SHIBAS


func _play_shiba(key):
	var lines = ShibaVoices.LINES.get("announcer", {}).get(key, [])
	if lines.is_empty():
		return false
	_audio_player.stream = lines[0]
	_audio_player.play()
	return true


## Strommangel und geladene Superwaffe ansagen (nur beim Wechsel)
func _check_power_and_superweapon():
	if not _is_shibas():
		return
	var low = _player.is_low_power()
	if low and not _was_low_power and not _audio_player.playing:
		_play_shiba("power_low")
	_was_low_power = low
	var ready = get_tree().get_nodes_in_group("units").any(
		func(u):
			return (
				u.player == _player
				and Factions.ability(Factions.variant_of(u)) == "superweapon"
				and u.get("charge_progress") != null
				and u.charge_progress >= 1.0
			)
	)
	if ready and not _superweapon_was_ready:
		_play_shiba("superweapon_ready")
	_superweapon_was_ready = ready


func _handle_event(event):
	if (
		_audio_player.playing
		and (
			_last_event_handled
			in [
				Constants.Match.VoiceNarrator.Events.MATCH_FINISHED_WITH_VICTORY,
				Constants.Match.VoiceNarrator.Events.MATCH_FINISHED_WITH_DEFEAT
			]
		)
	):
		return
	_last_event_handled = event
	if _is_shibas() and _play_shiba(_shiba_announcer_key(event)):
		return
	_audio_player.stream = Constants.Match.VoiceNarrator.EVENT_TO_ASSET_MAPPING[event]
	_audio_player.play()


func _on_unit_damaged(unit):
	if unit.player != _player:
		return
	var current_timestamp = Time.get_ticks_msec()
	if (
		current_timestamp - _last_under_attack_notification_timestamp
		> UNDER_ATTACK_NOTIFICATION_THRESHOLD_MS
	):
		_handle_event(
			(
				Constants.Match.VoiceNarrator.Events.BASE_UNDER_ATTACK
				if unit is Structure
				else Constants.Match.VoiceNarrator.Events.UNIT_UNDER_ATTACK
			)
		)
	_last_under_attack_notification_timestamp = current_timestamp


func _on_unit_died(unit):
	if unit.is_in_group("controlled_units"):
		_handle_event(Constants.Match.VoiceNarrator.Events.UNIT_LOST)


func _on_production_started(_unit_prototype, producer_unit):
	if producer_unit.player == _player:
		_handle_event(Constants.Match.VoiceNarrator.Events.UNIT_PRODUCTION_STARTED)


func _on_production_finished(_unit, producer_unit):
	if producer_unit.player == _player:
		_handle_event(Constants.Match.VoiceNarrator.Events.UNIT_PRODUCTION_FINISHED)


func _on_construction_finished(unit):
	if unit.player == _player:
		_handle_event(Constants.Match.VoiceNarrator.Events.UNIT_CONSTRUCTION_FINISHED)


func _on_not_enough_resources(player):
	if player == get_parent():
		_handle_event(Constants.Match.VoiceNarrator.Events.NOT_ENOUGH_RESOURCES)
