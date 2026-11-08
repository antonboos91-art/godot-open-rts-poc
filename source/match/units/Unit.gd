extends Area3D

signal selected
signal deselected
signal hp_changed
signal action_changed(new_action)
signal action_updated

const PixelSprite = preload("res://source/match/units/traits/PixelSprite.gd")
const Factions = preload("res://source/match/factions/Factions.gd")

const MATERIAL_ALBEDO_TO_REPLACE = Color(0.99, 0.81, 0.48)
const MATERIAL_ALBEDO_TO_REPLACE_EPSILON = 0.05

var hp = null:
	set = _set_hp
var hp_max = null:
	set = _set_hp_max
var attack_damage = null
var attack_interval = null
var attack_range = null
var attack_domains = []
var radius:
	get = _get_radius
var movement_domain:
	get = _get_movement_domain
var movement_speed:
	get = _get_movement_speed
var sight_range = null
var player:
	get:
		return get_parent()
var color:
	get:
		return player.color
var action = null:
	set = _set_action
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)
var type:
	get = _get_type
## Volks-Variante, z. B. "shibas/tesla" (leer = Grundvolk). Siehe Factions.gd
var variant = ""
var display_name:
	get:
		return Factions.display_name(Factions.variant_of(self))

var _action_locked = false

@onready var _match = find_parent("Match")


func _init():
	var replicated_properties = [":variant", ":position", ":rotation", ":hp", ":hp_max"]
	if "_construction_progress" in self:
		replicated_properties.append(":_construction_progress")
	if "charge_progress" in self:
		replicated_properties.append(":charge_progress")
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "UnitSynchronizer"
	synchronizer.replication_config = Utils.Net.replication_config(replicated_properties)
	add_child(synchronizer)


func _ready():
	if not _match.is_node_ready():
		await _match.ready
	_setup_color()
	PixelSprite.try_attach(self)
	_setup_default_properties_from_constants()
	assert(_safety_checks())


func is_revealing():
	return is_in_group("revealed_units") and visible


func _set_hp(value):
	var old_hp = hp
	hp = max(0, value)
	if old_hp != null and hp < old_hp:
		MatchSignals.unit_damaged.emit(self)
		_play_damage_sound()
	hp_changed.emit()
	if hp == 0:
		_handle_unit_death()


func _play_damage_sound():
	if not is_inside_tree():
		return
	if hp == 0:
		SoundEffects.play(
			"explosion_big" if has_method("is_constructed") else "explosion", global_position
		)
	else:
		SoundEffects.play("hit", global_position)


func _set_hp_max(value):
	hp_max = value
	hp_changed.emit()


func _get_radius():
	if find_child("Movement") != null:
		return find_child("Movement").radius
	if find_child("MovementObstacle") != null:
		return find_child("MovementObstacle").radius
	return null


func _get_movement_domain():
	if find_child("Movement") != null:
		return find_child("Movement").domain
	if find_child("MovementObstacle") != null:
		return find_child("MovementObstacle").domain
	return null


func _get_movement_speed():
	if find_child("Movement") != null:
		return find_child("Movement").speed
	return 0.0


func _is_movable():
	return _get_movement_speed() > 0.0


func _setup_color():
	var material = player.get_color_material()
	Utils.Match.traverse_node_tree_and_replace_materials_matching_albedo(
		find_child("Geometry"),
		MATERIAL_ALBEDO_TO_REPLACE,
		MATERIAL_ALBEDO_TO_REPLACE_EPSILON,
		material
	)


func _set_action(action_node):
	# Aktionen (Bewegen, Angreifen, ...) laufen nur auf dem Host.
	if not is_inside_tree() or _action_locked or Network.is_client():
		if action_node != null:
			action_node.queue_free()
		return
	_action_locked = true
	_teardown_current_action()
	action = action_node
	if action != null:
		var action_copy = action  # bind() performs copy itself, but lets force copy just in case
		action.tree_exited.connect(_on_action_node_tree_exited.bind(action_copy))
		add_child(action_node)
	_action_locked = false
	action_changed.emit(action)


func _get_type():
	var unit_script_path = get_script().resource_path
	var unit_file_name = unit_script_path.substr(unit_script_path.rfind("/") + 1)
	var unit_name = unit_file_name.split(".")[0]
	return unit_name


func _teardown_current_action():
	if action != null and action.is_inside_tree():
		action.queue_free()
		remove_child(action)  # triggers _on_action_node_tree_exited immediately


func _safety_checks():
	if movement_domain == Constants.Match.Navigation.Domain.AIR:
		assert(
			(
				radius < Constants.Match.Air.Navmesh.MAX_AGENT_RADIUS
				or is_equal_approx(radius, Constants.Match.Air.Navmesh.MAX_AGENT_RADIUS)
			),
			"Unit radius exceeds the established limit"
		)
	elif movement_domain == Constants.Match.Navigation.Domain.TERRAIN:
		assert(
			(
				not _is_movable()
				or (
					radius < Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
					or is_equal_approx(radius, Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS)
				)
			),
			"Unit radius exceeds the established limit"
		)
	return true


func _handle_unit_death():
	tree_exited.connect(func(): MatchSignals.unit_died.emit(self))
	# Auf Clients entfernt der MultiplayerSpawner die Einheit.
	if not Network.is_client():
		queue_free()


func _setup_default_properties_from_constants():
	var default_properties = (
		Constants
		. Match
		. Units
		. DEFAULT_PROPERTIES[get_script().resource_path.replace(".gd", ".tscn")]
		. duplicate()
	)
	# Werte der Volks-Variante überschreiben die des Archetyps
	var variant_stats = Factions.stats(variant)
	if "hp" in variant_stats:
		variant_stats["hp_max"] = variant_stats["hp"]
	if "speed" in variant_stats and find_child("Movement") != null:
		find_child("Movement").speed = variant_stats["speed"]
	variant_stats.erase("speed")
	default_properties.merge(variant_stats, true)
	for property in default_properties:
		# Auf Clients kamen hp/hp_max evtl. schon vom Host
		if Network.is_client() and property in ["hp", "hp_max"] and get(property) != null:
			continue
		set(property, default_properties[property])


func _on_action_node_tree_exited(action_node):
	assert(action_node == action, "unexpected action released")
	action = null


## Gehackt: Gebäude produziert nicht, feuert nicht und lädt nicht (nur auf dem Host relevant).
func is_hacked():
	return Time.get_ticks_msec() < get_meta("hacked_until", 0)


func hack(seconds):
	set_meta("hacked_until", Time.get_ticks_msec() + int(seconds * 1000.0))
