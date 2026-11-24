class_name FollowPlayer
extends Node
## Keeps its parent effect centred on Kael (falling leaves, drifting ash).

var offset: Vector3 = Vector3.ZERO


func _process(_delta: float) -> void:
	var effect: Node3D = get_parent() as Node3D
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if effect != null and player != null:
		effect.global_position = player.global_position + offset
