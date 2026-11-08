extends Area3D

const ResourceDecayAnimation = preload("res://source/match/utils/ResourceDecayAnimation.tscn")

var radius:
	get:
		return find_child("MovementObstacle").radius
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)


## Siehe Player.add_synchronizer()
func add_synchronizer():
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "ResourceSynchronizer"
	synchronizer.replication_config = Utils.Net.replication_config(
		[":resource_a"] if "resource_a" in self else [":resource_b"]
	)
	add_child(synchronizer)


func _enter_tree():
	tree_exiting.connect(_animate_decay)


func _animate_decay():
	var decay_animation = ResourceDecayAnimation.instantiate()
	decay_animation.global_transform = global_transform
	get_parent().add_child.call_deferred(decay_animation)


## Ersetzt das Platzhalter-Modell durch ein Kristallfeld-Sprite.
func _add_ore_sprite(sprite_name):
	var geometry = find_child("Geometry", false, false)
	if geometry != null:
		geometry.visible = false
	var sprite = Sprite3D.new()
	sprite.texture = load("res://assets/sprites/nature/" + sprite_name + ".png")
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = 4.4 / 256.0
	sprite.offset = Vector2(0, 184.0 - 128.0)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
