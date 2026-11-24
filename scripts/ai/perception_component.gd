class_name PerceptionComponent
extends Node
## An enemy's eyes and ears. Sight fills a detection meter (0..1) based on
## distance, light and movement; noises are remembered until the AI reads them.

## Global multiplier on hearing distance (rain lowers it to about 0.7).
static var hearing_scale: float = 1.0

var enemy: Enemy
var target: Player
## 0 = unaware, 1 = spotted.
var detection: float = 0.0
## True on frames where the target is actually in view.
var sees_target: bool = false
var heard_position: Vector3

var _has_heard: bool = false


func _ready() -> void:
	enemy = get_parent() as Enemy
	EventBus.noise_emitted.connect(_on_noise)


func is_spotted() -> bool:
	return detection >= 1.0


## Returns true once per noise heard since the last call.
func consume_heard() -> bool:
	if _has_heard:
		_has_heard = false
		return true
	return false


func reset() -> void:
	detection = 0.0
	sees_target = false
	_has_heard = false


## `alerted` enemies (already fighting or searching) look all around and notice faster.
func update(delta: float, alerted: bool) -> void:
	sees_target = false
	if target == null or not is_instance_valid(target) or target.is_dead():
		detection = maxf(detection - delta, 0.0)
		return
	var data: EnemyData = enemy.data
	var visibility: float = get_visibility(alerted)
	if visibility > 0.0:
		sees_target = true
		var moving: float = 1.0 if target.get_horizontal_speed() > 0.5 else 0.6
		var rate: float = visibility * moving / maxf(data.detect_time, 0.05)
		detection = minf(detection + rate * (3.0 if alerted else 1.0) * delta, 1.0)
	else:
		detection = maxf(detection - 0.3 * delta, 0.0)


## 0 when the target cannot be seen; otherwise how obvious it is (about 0.6 far away, 2.2 up close).
func get_visibility(alerted: bool) -> float:
	var data: EnemyData = enemy.data
	var eye: Vector3 = enemy.global_position + Vector3.UP * data.eye_height
	var aim: Vector3 = target.global_position + Vector3.UP * (0.65 if target.is_crouching else 1.0)
	var offset: Vector3 = aim - eye
	var distance: float = offset.length()
	var sight_range: float = data.vision_range_dark if target.is_in_shadow() else data.vision_range
	if target.is_crouching:
		sight_range *= 0.75
	if target.is_hidden():
		sight_range = minf(sight_range, data.hidden_detect_range)
	if distance > sight_range:
		return 0.0
	var flat := Vector3(offset.x, 0.0, offset.z).normalized()
	var in_cone: bool = enemy.get_facing_direction().dot(flat) >= cos(deg_to_rad(data.vision_fov_degrees * 0.5))
	# Standing right next to an enemy gives Kael away; creeping up behind does not.
	var bumped: bool = distance < 1.2 and not target.is_crouching
	if not in_cone and not alerted and not bumped:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(eye, aim, Player.LAYER_WORLD)
	if not enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0
	return lerpf(2.2, 0.6, clampf(distance / sight_range, 0.0, 1.0))


func _on_noise(position: Vector3, radius: float, source: Node) -> void:
	if source == enemy or enemy.is_dead():
		return
	var reach: float = radius * hearing_scale * enemy.data.hearing
	if enemy.global_position.distance_to(position) > reach:
		return
	heard_position = position
	_has_heard = true
	detection = maxf(detection, 0.4)
