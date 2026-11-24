class_name Ballistic
extends Node3D
## Base for anything thrown or spat: flies on an arc and reports the first
## thing it touches. Subclasses decide what happens on impact.

@export var gravity: float = 16.0
@export var lifetime: float = 6.0

var velocity: Vector3 = Vector3.ZERO
var source: Node3D
## Physics layers this object collides with.
var collision_mask: int = Player.LAYER_WORLD

var _age: float = 0.0
var _done: bool = false


func launch(from_source: Node3D, start: Vector3, initial_velocity: Vector3) -> void:
	add_to_group(&"transient")
	source = from_source
	global_position = start
	velocity = initial_velocity
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age > lifetime:
		queue_free()
		return
	velocity.y -= gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	if source is CollisionObject3D:
		query.exclude = [(source as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	_done = true
	global_position = hit["position"]
	_on_impact(hit["collider"] as Node, hit["position"], hit["normal"])


func _on_impact(_collider: Node, _point: Vector3, _normal: Vector3) -> void:
	queue_free()


## Launch velocity that lands on `target` from `start` after `flight_time` seconds.
static func solve_arc(start: Vector3, target: Vector3, flight_time: float, arc_gravity: float) -> Vector3:
	var offset: Vector3 = target - start
	var time: float = maxf(flight_time, 0.1)
	return Vector3(offset.x / time, offset.y / time + 0.5 * arc_gravity * time, offset.z / time)
