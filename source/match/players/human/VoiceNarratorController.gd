## Ansagen der Zentrale, je Volk eigene Stimme (FactionVoices.gd, Paket "announcer"):
## Shibas "Welcome back, Mother Wolf", Katzen "Welcome back, Meowmander", Baeren "Welcome back, Bearmander".
## Angriffsmeldungen kommen nur, wenn wirklich ein Gegner in der Naehe ist, und sagen, was angegriffen
## wird: die Basis (Gebaeude), der Sammler oder die Truppen. Fehlt einem Volk eine Zeile, spricht die
## alte Standard-Sprecherin.
extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const Factions = preload("res://source/match/factions/Factions.gd")
const FactionVoices = preload("res://source/match/players/human/FactionVoices.gd")

## So nah muss ein Gegner sein, damit Schaden als Angriff gemeldet wird
const ENEMY_NEAR_M = 16.0
## Pausen je Ansage, damit die Zentrale nicht dauernd dasselbe sagt
const COOLDOWN_MS = {
	"base_under_attack": 20000,
	"harvester_under_attack": 20000,
	"unit_under_attack": 25000,
	"unit_lost": 8000,
	"building_lost": 5000,
	"insufficient_funds": 6000,
	"building": 4000,
	"low_power": 15000,
}

var _last_key_ms = {}
var _was_low_power = false
var _superweapon_was_ready = false
var _finished = false

@onready var _audio_player = find_child("AudioStreamPlayer")
@onready var _player = get_parent()


func _ready():
	var events = Constants.Match.VoiceNarrator.Events
	MatchSignals.match_started.connect(func(): _say("welcome", events.MATCH_STARTED, true))
	MatchSignals.match_aborted.connect(func(): _say("mission_failed", events.MATCH_ABORTED, true))
	MatchSignals.match_finished_with_victory.connect(_on_finished.bind(true))
	MatchSignals.match_finished_with_defeat.connect(_on_finished.bind(false))
	MatchSignals.unit_damaged.connect(_on_unit_damaged)
	MatchSignals.unit_died.connect(_on_unit_died)
	MatchSignals.unit_production_finished.connect(_on_production_finished)
	MatchSignals.not_enough_resources_for_production.connect(_on_not_enough_resources)
	MatchSignals.not_enough_resources_for_construction.connect(_on_not_enough_resources)
	MatchSignals.unit_construction_finished.connect(_on_construction_finished)
	MatchSignals.place_structure.connect(func(_variant): _say("building"))
	MatchSignals.superweapon_targeting_requested.connect(func(_s): _say("select_target", null, true))
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_power_and_superweapon)
	add_child(timer)


func _line(key):
	var announcer = FactionVoices.LINES.get(Factions.faction_of(_player), {}).get("announcer", {})
	var lines = announcer.get(key, [])
	return lines[0] if not lines.is_empty() else null


## Ansage abspielen; event = Standard-Sprecherin, falls das Volk keine eigene Zeile hat
func _say(key, event = null, interrupt = false):
	if _finished:
		return
	var now = Time.get_ticks_msec()
	if now - _last_key_ms.get(key, -999999) < COOLDOWN_MS.get(key, 1500):
		return
	if _audio_player.playing and not interrupt:
		return
	var stream = _line(key)
	if stream == null:
		if event == null:
			return
		stream = Constants.Match.VoiceNarrator.EVENT_TO_ASSET_MAPPING[event]
	_last_key_ms[key] = now
	_audio_player.stream = stream
	_audio_player.play()


func _on_finished(victory):
	var events = Constants.Match.VoiceNarrator.Events
	if victory:
		_say("mission_accomplished", events.MATCH_FINISHED_WITH_VICTORY, true)
	else:
		_say("mission_failed", events.MATCH_FINISHED_WITH_DEFEAT, true)
	_finished = true


## true, wenn eine feindliche Einheit oder ein feindliches Gebaeude in der Naehe ist
func _enemy_near(unit):
	var p = unit.global_position_yless
	for other in get_tree().get_nodes_in_group("units"):
		var owner_player = other.get("player")
		if owner_player == null or owner_player.is_ally_of(_player):
			continue
		if other.global_position_yless.distance_to(p) <= ENEMY_NEAR_M + float(other.get("radius") if other.get("radius") != null else 0.0):
			return true
	return false


func _on_unit_damaged(unit):
	if unit.player != _player or not _enemy_near(unit):
		return
	var events = Constants.Match.VoiceNarrator.Events
	if unit is Structure:
		_say("base_under_attack", events.BASE_UNDER_ATTACK)
	elif unit.type == "Worker":
		_say("harvester_under_attack", events.UNIT_UNDER_ATTACK)
	else:
		_say("unit_under_attack", events.UNIT_UNDER_ATTACK)


func _on_unit_died(unit):
	if not unit.is_in_group("controlled_units"):
		return
	var events = Constants.Match.VoiceNarrator.Events
	if unit is Structure:
		_say("building_lost", events.UNIT_LOST, true)
	else:
		_say("unit_lost", events.UNIT_LOST)


func _on_production_finished(_unit, producer_unit):
	if producer_unit.player == _player:
		_say("training_complete", Constants.Match.VoiceNarrator.Events.UNIT_PRODUCTION_FINISHED)


func _on_construction_finished(unit):
	if unit.player == _player:
		_say("construction_complete", Constants.Match.VoiceNarrator.Events.UNIT_CONSTRUCTION_FINISHED)


func _on_not_enough_resources(player):
	if player == _player:
		_say("insufficient_funds", Constants.Match.VoiceNarrator.Events.NOT_ENOUGH_RESOURCES)


## Strommangel, Strom wieder da und geladene Superwaffe ansagen (nur beim Wechsel)
func _check_power_and_superweapon():
	if Factions.faction_of(_player) == Factions.CORE:
		return
	var low = _player.is_low_power()
	if low and not _was_low_power:
		_say("low_power")
	elif not low and _was_low_power:
		_say("power_restored")
	_was_low_power = low
	var ready = get_tree().get_nodes_in_group("units").any(
		func(u):
			return (
				u.get("player") == _player
				and Factions.ability(Factions.variant_of(u)) == "superweapon"
				and u.get("charge_progress") != null
				and u.charge_progress >= 1.0
			)
	)
	if ready and not _superweapon_was_ready:
		_say("superweapon_ready", null, true)
	_superweapon_was_ready = ready
