class_name Deer
extends Node3D
## A deer grazing in a clearing. It lifts its head now and then, and bolts
## away from Kael when he comes close, disappearing into the trees.

signal fled

var flee_distance: float = 14.0
var run_speed: float = 9.0

var fleeing: bool = false
var _neck: Node3D
var _legs: Array[Node3D] = []
var _time: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _run_time: float = 0.0


func _ready() -> void:
	_time = randf() * 10.0
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color(0.36, 0.24, 0.14)
	coat.roughness = 0.95
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.62, 0.55, 0.45)
	_part(self, Vector3(0.0, 1.0, 0.0), Vector3(0.42, 0.45, 1.15), coat)
	_part(self, Vector3(0.0, 1.05, 0.62), Vector3(0.26, 0.22, 0.12), pale)
	_neck = Node3D.new()
	_neck.position = Vector3(0.0, 1.15, -0.5)
	add_child(_neck)
	_part(_neck, Vector3(0.0, 0.3, -0.08), Vector3(0.18, 0.55, 0.2), coat, Vector3(-25.0, 0.0, 0.0))
	_part(_neck, Vector3(0.0, 0.6, -0.28), Vector3(0.16, 0.18, 0.36), coat)
	for side: float in [-1.0, 1.0]:
		_part(_neck, Vector3(side * 0.1, 0.74, -0.16), Vector3(0.06, 0.14, 0.04), coat, Vector3(0.0, 0.0, side * -25.0))
	for leg: Vector2 in [Vector2(-0.14, -0.42), Vector2(0.14, -0.42), Vector2(-0.14, 0.42), Vector2(0.14, 0.42)]:
		var hip := Node3D.new()
		hip.position = Vector3(leg.x, 0.85, leg.y)
		add_child(hip)
		_part(hip, Vector3(0.0, -0.42, 0.0), Vector3(0.07, 0.85, 0.07), coat)
		_legs.append(hip)


func _part(parent: Node3D, at: Vector3, size: Vector3, material: Material, degrees: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = degrees
	parent.add_child(instance)


func _process(delta: float) -> void:
	_time += delta
	if fleeing:
		_run(delta)
		return
	# Grazing: head down most of the time, up to look around.
	var look_up: bool = fmod(_time, 7.0) > 5.2
	_neck.rotation.x = lerp_angle(_neck.rotation.x, 0.0 if look_up else -1.0, delta * 2.5)
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null and player.global_position.distance_to(global_position) < flee_distance:
		startle(player.global_position)


func startle(from: Vector3) -> void:
	if fleeing:
		return
	fleeing = true
	_direction = global_position - from
	_direction.y = 0.0
	_direction = _direction.normalized() if _direction.length() > 0.01 else Vector3.FORWARD
	look_at(global_position - _direction, Vector3.UP)


func _run(delta: float) -> void:
	_run_time += delta
	global_position += _direction * run_speed * delta
	# Bounding: the body rises and the legs scissor.
	position.y = absf(sin(_run_time * 9.0)) * 0.35
	_neck.rotation.x = 0.25
	for i: int in _legs.size():
		_legs[i].rotation.x = sin(_run_time * 18.0 + (PI if i < 2 else 0.0)) * 0.7
	if _run_time > 3.0:
		scale = scale.move_toward(Vector3.ZERO, delta * 2.0)
		if scale.x <= 0.01:
			fled.emit()
			queue_free()
