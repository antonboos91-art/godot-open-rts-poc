extends PanelContainer

const Factions = preload("res://source/match/factions/Factions.gd")

const POWER_OK_COLOR = Color(0.55, 0.95, 0.45)
const POWER_LOW_COLOR = Color(1.0, 0.25, 0.2)

var player = null

var _power_label = Label.new()

@onready var _resource_a_label = find_child("ResourceALabel")
@onready var _resource_b_label = find_child("ResourceBLabel")
@onready var _resource_a_color_rect = find_child("ResourceAColorRect")
@onready var _resource_b_color_rect = find_child("ResourceBColorRect")


func _ready():
	_resource_a_color_rect.color = Constants.Match.Resources.A.COLOR
	_resource_b_color_rect.color = Constants.Match.Resources.B.COLOR
	_power_label.name = "PowerLabel"
	_power_label.tooltip_text = "Strom: erzeugt / verbraucht"
	_power_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_power_label.hide()
	find_child("ResourceBLabel").get_parent().get_parent().add_child(_power_label)
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_power)
	add_child(timer)


func setup(a_player):
	assert(player == null, "player cannot be null")
	player = a_player
	_on_player_resource_changed()
	player.changed.connect(_on_player_resource_changed)
	_update_power()


func _on_player_resource_changed():
	_resource_a_label.text = str(player.resource_a)
	_resource_b_label.text = str(player.resource_b)


## Stromanzeige nur für Völker (das Grundvolk hat kein Stromnetz).
func _update_power():
	if player == null or Factions.faction_of(player) == Factions.CORE:
		return
	var power = player.get_power()
	_power_label.show()
	_power_label.text = "Strom %d/%d" % [power[0], power[1]]
	_power_label.add_theme_color_override(
		"font_color", POWER_LOW_COLOR if power[1] > power[0] else POWER_OK_COLOR
	)
