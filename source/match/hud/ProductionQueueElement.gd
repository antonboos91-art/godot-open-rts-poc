extends Button

const Factions = preload("res://source/match/factions/Factions.gd")
const PixelSprite = preload("res://source/match/units/traits/PixelSprite.gd")

var queue = null
var queue_element = null


func _ready():
	if queue == null or queue_element == null:
		return
	queue_element.changed.connect(_on_queue_element_changed)
	pressed.connect(func(): queue.cancel(queue_element))
	var icon_texture = PixelSprite.icon_for(queue_element.variant, queue.get_parent().player.color)
	if icon_texture != null:
		icon = icon_texture
		expand_icon = true
		text = ""
	else:
		text = Factions.display_name(queue_element.variant).left(3)
	tooltip_text = Factions.display_name(queue_element.variant)
	find_child("Label").text = "{0}%".format([int(queue_element.progress() * 100.0)])


func _on_queue_element_changed():
	find_child("Label").text = "{0}%".format([int(queue_element.progress() * 100.0)])
