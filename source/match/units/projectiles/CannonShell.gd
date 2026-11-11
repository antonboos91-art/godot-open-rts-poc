## Direkttreffer-Waffe (Infanterie, Panzer ohne eigenes Fahrzeug-Visual, Abwehrtuerme).
## Schaden sofort; Optik ueber CombatFX im Stil des Volks (Laser / Phaser / Plasma).
extends Node3D

const CombatFX = preload("res://source/match/units/traits/CombatFX.gd")

var target_unit = null

@onready var _unit = get_parent()
@onready var _unit_particles = find_child("OriginParticles")
@onready var _timer = find_child("Timer")


func _ready():
	assert(target_unit != null, "target unit was not provided")
	_unit_particles.visible = false
	_setup_timer()
	_show_shot()
	target_unit.hp -= _unit.attack_damage


func _setup_timer():
	_timer.timeout.connect(queue_free)
	_timer.start(0.5)


func _show_shot():
	# Fahrzeug-Visuals zeigen ihren Schuss selbst
	if _unit.find_child("SpriteVehicle", false, false) != null or _unit.find_child("TankVisual", false, false) != null:
		return
	if not CombatFX.visible_for(_unit, target_unit):
		return
	var to_target = target_unit.global_position - _unit.global_position
	to_target.y = 0.0
	var dir = to_target.normalized() if to_target.length() > 0.01 else Vector3.FORWARD
	var is_structure = _unit.has_method("is_constructed")
	var height = 1.9 if is_structure else 1.15
	var from = _unit.global_position + Vector3(0, height, 0) + dir * (0.9 if is_structure else 0.45)
	var aim_height = 0.7 if not target_unit.has_method("is_constructed") else 1.2
	var to = target_unit.global_position + Vector3(0, aim_height, 0) - dir * min(target_unit.radius if target_unit.radius != null else 0.0, 1.5) * 0.6
	CombatFX.shot(_unit, from, to, 2.2 if is_structure else 1.0)
