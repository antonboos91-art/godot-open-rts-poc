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
