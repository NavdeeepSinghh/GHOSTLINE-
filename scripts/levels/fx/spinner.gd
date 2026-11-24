class_name Spinner
extends Node
## Turns its target around the vertical axis (rotating warning beacons).

var target: Node3D
var degrees_per_second: float = 220.0


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		target.rotation.y += deg_to_rad(degrees_per_second) * delta
