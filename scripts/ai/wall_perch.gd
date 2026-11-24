class_name WallPerch
extends Node
## Puts a Skitter on a wall: it clings head-down, crawling slowly from side to
## side, until it sees Kael within `notice_range`, hears a noise or is hit.
## Then it leaps down to its landing spot and joins the fight. While it clings
## the Enemy's own AI is held (see Enemy._physics_process).

signal dropped

var wall_point: Vector3
var wall_normal: Vector3 = Vector3.BACK
var landing: Vector3

## True from the moment it lets go; `finished` once it has landed.
var letting_go: bool = false
var finished: bool = false

var _enemy: Enemy
var _time: float = 0.0
var _check: float = 0.0


func _ready() -> void:
	_enemy = get_parent() as Enemy
	_time = randf() * 10.0
	EventBus.noise_emitted.connect(_on_noise)
	_cling.call_deferred()


func holds_enemy() -> bool:
	return not finished


func _cling() -> void:
	if _enemy == null or letting_go:
		return
	_enemy.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, wall_normal), _perch_position())


func _perch_position() -> Vector3:
	var tangent: Vector3 = wall_normal.cross(Vector3.UP).normalized()
	return wall_point + wall_normal * 0.35 + tangent * sin(_time * 0.55) * 1.3 + Vector3.UP * sin(_time * 0.8) * 0.3


func _physics_process(delta: float) -> void:
	if letting_go or _enemy == null:
		return
	_time += delta
	_cling()
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.2
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.is_dead():
		return
	var chest: Vector3 = player.global_position + Vector3.UP
	if chest.distance_to(_enemy.global_position) > _enemy.data.perch_notice_range:
		return
	var query := PhysicsRayQueryParameters3D.create(_enemy.global_position + wall_normal * 0.3, chest, Player.LAYER_WORLD)
	if _enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		drop()


func _on_noise(at: Vector3, radius: float, _source: Variant) -> void:
	if not letting_go and _enemy != null and at.distance_to(_enemy.global_position) <= radius:
		drop()


## Lets go of the wall: an arcing leap to the landing spot, then the fight.
func drop() -> void:
	if letting_go or _enemy == null:
		return
	letting_go = true
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	var start: Transform3D = _enemy.global_transform
	var facing: Vector3 = (player.global_position if player != null else landing + wall_normal) - landing
	facing.y = 0.0
	if facing.length() < 0.1:
		facing = wall_normal
	var end := Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), landing)
	AudioManager.play_sfx(&"enemy_alert", start.origin, 2.0)
	var tween: Tween = _enemy.create_tween()
	tween.tween_method(func(t: float) -> void:
		var origin: Vector3 = start.origin.lerp(end.origin, t) + Vector3.UP * sin(t * PI) * 1.1
		_enemy.global_transform = Transform3D(start.basis.slerp(end.basis, minf(t * 1.6, 1.0)), origin),
		0.0, 1.0, _enemy.data.perch_drop_seconds)
	await tween.finished
	finished = true
	if is_instance_valid(_enemy):
		_enemy.global_transform = end
		_enemy.velocity = Vector3.ZERO
		if player != null:
			_enemy.alert(player.global_position)
	dropped.emit()
	queue_free()
