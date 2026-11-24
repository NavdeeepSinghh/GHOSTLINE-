class_name ChoirTarget
extends StaticBody3D
## Something on the Choir that Kael's weapon can strike: its heart or a
## resonance pillar. Forwards the hit to the Choir.

var choir: Node
var index: int = -1


func setup(owner_choir: Node, target_index: int, radius: float) -> void:
	choir = owner_choir
	index = target_index
	collision_layer = Player.LAYER_ENEMY
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func receive_hit(hit: HitInfo) -> HitInfo.Result:
	return choir.call(&"on_target_hit", index, hit)


func get_lock_on_point() -> Vector3:
	return global_position


func is_dead() -> bool:
	return false
