class_name CameraRig
extends Node3D
## Third-person orbit camera: over-the-shoulder framing, smooth follow with a
## little lag and lookahead, collision that snaps in and eases back out, a
## sprint FOV kick, trauma-based shake and lock-on targeting.
##
## Runs in _process and follows the player's interpolated transform, so camera
## motion stays smooth whatever the display refresh rate.

const DEFAULT_TUNING_PATH: String = "res://data/camera_tuning.tres"
const LOCK_ON_GROUP: StringName = &"lock_on_target"

@export var tuning: CameraTuning

var target: Player
## Radians. Movement input is relative to yaw.
var yaw: float = 0.0
var pitch: float = 0.0
var lock_target: Node3D
var camera: Camera3D

var _focus: Vector3 = Vector3.ZERO
var _distance: float = 3.2
var _back_fraction: float = 1.0
var _rise_fraction: float = 1.0
var _mouse_delta: Vector2 = Vector2.ZERO
var _trauma: float = 0.0
var _shake_time: float = 0.0
var _fov_boost: float = 0.0
var _flick_accumulator: float = 0.0
var _flick_timer: float = 0.0
var _stick_flick_ready: bool = true
var _lock_lost_time: float = 0.0
var _sphere := SphereShape3D.new()
var _cast := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	if tuning == null:
		tuning = load(DEFAULT_TUNING_PATH)
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.near = 0.08
	add_child(camera)
	camera.make_current()
	pitch = deg_to_rad(tuning.default_pitch_degrees)
	_distance = tuning.distance
	_sphere.radius = tuning.collision_radius
	_cast.shape = _sphere
	_cast.collision_mask = Player.LAYER_WORLD
	EventBus.camera_shake_requested.connect(add_trauma)
	EventBus.enemy_died.connect(_on_enemy_died)
	SettingsManager.changed.connect(_on_setting_changed)
	_apply_settings()


func follow(player: Player) -> void:
	target = player
	player.camera_rig = self
	yaw = player.facing_yaw
	snap_to_target()


## Jumps the camera to its resting position (after spawning or teleporting).
func snap_to_target() -> void:
	if target == null:
		return
	_focus = target.global_position + Vector3.UP * tuning.focus_height
	_back_fraction = 1.0
	_rise_fraction = 1.0
	_update_camera(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).screen_relative
	elif event.is_action_pressed(&"lock_on") and target != null and target.input_enabled:
		toggle_lock_on()


func _process(delta: float) -> void:
	if target == null:
		return
	_update_look(delta)
	_update_lock_on(delta)
	_update_camera(delta)


# --- Shake ------------------------------------------------------------------

## Adds camera shake. Trauma is 0..1; shake strength is trauma squared.
func add_trauma(amount: float) -> void:
	if SettingsManager.get_bool("gameplay", "camera_shake"):
		_trauma = clampf(_trauma + amount, 0.0, 1.0)


# --- Lock-on ----------------------------------------------------------------

## When the locked enemy dies, move the lock to the next one in view.
func _on_enemy_died(enemy: Node3D) -> void:
	if enemy == lock_target:
		lock_target = null
		set_lock_target(_find_lock_target(0.0))
		if lock_target == null:
			EventBus.lock_on_changed.emit(null)


func toggle_lock_on() -> void:
	if lock_target != null:
		set_lock_target(null)
	else:
		set_lock_target(_find_lock_target(0.0))


func set_lock_target(node: Node3D) -> void:
	if node == lock_target:
		return
	lock_target = node
	_lock_lost_time = 0.0
	EventBus.lock_on_changed.emit(lock_target)


## World point the camera and reticle aim at on a target.
static func get_lock_point(node: Node3D) -> Vector3:
	if node.has_method(&"get_lock_on_point"):
		return node.call(&"get_lock_on_point")
	return node.global_position + Vector3.UP


## Best target in view. `side` -1/+1 picks the nearest one left/right of the current target.
func _find_lock_target(side: float) -> Node3D:
	var best: Node3D = null
	var best_score: float = INF
	var forward: Vector3 = -camera.global_basis.z
	var right: Vector3 = camera.global_basis.x
	var current_offset: float = 0.0
	if lock_target != null:
		current_offset = (get_lock_point(lock_target) - camera.global_position).normalized().dot(right)
	for node: Node in get_tree().get_nodes_in_group(LOCK_ON_GROUP):
		var candidate: Node3D = node as Node3D
		if candidate == null or candidate == lock_target or not candidate.is_visible_in_tree():
			continue
		var point: Vector3 = get_lock_point(candidate)
		if point.distance_to(target.global_position) > tuning.lock_on_range:
			continue
		var direction: Vector3 = (point - camera.global_position).normalized()
		var facing: float = direction.dot(forward)
		if facing < 0.35 or not _has_line_of_sight(point):
			continue
		var score: float = (1.0 - facing) * 10.0 + point.distance_to(target.global_position) * 0.05
		if side != 0.0:
			var offset: float = direction.dot(right) - current_offset
			if offset * side <= 0.01:
				continue
			score = absf(offset)
		if score < best_score:
			best_score = score
			best = candidate
	return best


func _has_line_of_sight(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, Player.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_lock_on(delta: float) -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not lock_target.is_inside_tree():
		set_lock_target(null)
		return
	var point: Vector3 = get_lock_point(lock_target)
	if point.distance_to(target.global_position) > tuning.lock_on_range * 1.25:
		set_lock_target(null)
		return
	_lock_lost_time = 0.0 if _has_line_of_sight(point) else _lock_lost_time + delta
	if _lock_lost_time > tuning.lock_on_lost_seconds:
		set_lock_target(null)
		return

	# A quick mouse flick or stick push switches target.
	_flick_timer -= delta
	if _flick_timer <= 0.0:
		_flick_accumulator = 0.0
	var switch_side: float = 0.0
	if absf(_flick_accumulator) > tuning.lock_on_flick_pixels:
		switch_side = signf(_flick_accumulator)
		_flick_accumulator = 0.0
	var stick: float = Input.get_axis(&"look_left", &"look_right")
	if absf(stick) > 0.75 and _stick_flick_ready:
		switch_side = signf(stick)
		_stick_flick_ready = false
	elif absf(stick) < 0.3:
		_stick_flick_ready = true
	if switch_side != 0.0:
		var next: Node3D = _find_lock_target(switch_side)
		if next != null:
			set_lock_target(next)
			point = get_lock_point(next)

	# Turn to keep the player and the target framed together.
	var to_target: Vector3 = point - _focus
	var flat: float = Vector2(to_target.x, to_target.z).length()
	if flat > 0.4:
		var ease: float = 1.0 - exp(-tuning.lock_on_turn_speed * delta)
		yaw = lerp_angle(yaw, atan2(-to_target.x, -to_target.z), ease)
		var wanted_pitch: float = clampf(atan2(to_target.y, flat) * 0.6 - 0.2,
				deg_to_rad(tuning.min_pitch_degrees), deg_to_rad(tuning.max_pitch_degrees))
		pitch = lerpf(pitch, wanted_pitch, ease)


# --- Core -------------------------------------------------------------------

func _update_look(delta: float) -> void:
	var mouse: Vector2 = _mouse_delta
	_mouse_delta = Vector2.ZERO
	var stick: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if target == null or not target.input_enabled:
		return
	if lock_target != null:
		_flick_accumulator += mouse.x
		if absf(mouse.x) > 0.0:
			_flick_timer = 0.18
		return
	var invert: float = -1.0 if SettingsManager.get_bool("controls", "invert_y") else 1.0
	var mouse_scale: float = tuning.mouse_radians_per_pixel * SettingsManager.get_float("controls", "mouse_sensitivity")
	yaw -= mouse.x * mouse_scale
	pitch -= mouse.y * mouse_scale * invert
	# Squared response gives fine aim near the centre of the stick.
	var stick_scale: float = stick.length() * SettingsManager.get_float("controls", "controller_sensitivity")
	yaw -= stick.x * stick_scale * tuning.stick_yaw_speed * delta
	pitch -= stick.y * stick_scale * tuning.stick_pitch_speed * delta * invert
	yaw = wrapf(yaw, -PI, PI)
	pitch = clampf(pitch, deg_to_rad(tuning.min_pitch_degrees), deg_to_rad(tuning.max_pitch_degrees))


func _update_camera(delta: float) -> void:
	# Follow point: above the feet, a little ahead of the movement.
	var crouch: float = target.visuals.get_crouch_amount()
	var height: float = lerpf(tuning.focus_height, tuning.crouch_focus_height, crouch)
	var body: Vector3 = target.get_global_transform_interpolated().origin if delta > 0.0 else target.global_position
	var lookahead: Vector3 = (target.get_horizontal_velocity() * tuning.lookahead_seconds).limit_length(tuning.max_lookahead)
	var desired: Vector3 = body + Vector3.UP * height + lookahead
	if delta <= 0.0:
		_focus = desired
	else:
		var horizontal: float = 1.0 - exp(-tuning.follow_speed_horizontal * delta)
		var vertical: float = 1.0 - exp(-tuning.follow_speed_vertical * delta)
		_focus.x = lerpf(_focus.x, desired.x, horizontal)
		_focus.z = lerpf(_focus.z, desired.z, horizontal)
		_focus.y = lerpf(_focus.y, desired.y, vertical)

	var orbit := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	# Shoulder offset, pulled in when a wall is beside the character.
	var shoulder: Vector3 = orbit.x * tuning.shoulder_offset
	var pivot: Vector3 = _focus + shoulder * _cast_fraction(space, _focus, shoulder)

	# Arm, cast in two legs: back first, then up. Under a low ceiling the camera
	# stays low behind the character instead of collapsing onto him. Each leg
	# snaps in when blocked and eases back out when clear.
	var back: Vector3 = Vector3(orbit.z.x, 0.0, orbit.z.z) * tuning.distance
	var rise: Vector3 = Vector3(0.0, orbit.z.y * tuning.distance, 0.0)
	var back_allowed: float = _cast_fraction(space, pivot, back)
	if back_allowed < _back_fraction or delta <= 0.0:
		_back_fraction = back_allowed
	else:
		_back_fraction = move_toward(_back_fraction, back_allowed, tuning.recover_speed / tuning.distance * delta)
	var behind: Vector3 = pivot + back * _back_fraction
	var rise_allowed: float = _cast_fraction(space, behind, rise * _back_fraction)
	if rise_allowed < _rise_fraction or delta <= 0.0:
		_rise_fraction = rise_allowed
	else:
		_rise_fraction = move_toward(_rise_fraction, rise_allowed, tuning.recover_speed / tuning.distance * delta)
	var camera_position: Vector3 = behind + rise * _back_fraction * _rise_fraction
	_distance = camera_position.distance_to(pivot)

	# Shake.
	var shake := Vector3.ZERO
	if _trauma > 0.0:
		_shake_time += delta * 38.0
		var strength: float = _trauma * _trauma * deg_to_rad(tuning.max_shake_degrees)
		shake = Vector3(sin(_shake_time * 1.13) * strength, sin(_shake_time * 0.87 + 1.7) * strength,
				sin(_shake_time * 1.31 + 0.6) * strength * 0.6)
		_trauma = maxf(_trauma - tuning.shake_decay * delta, 0.0)

	camera.global_transform = Transform3D(orbit * Basis.from_euler(shake), camera_position)

	# Sprint widens the view a touch.
	var boost_target: float = tuning.sprint_fov_boost if target.is_sprinting else 0.0
	_fov_boost = lerpf(_fov_boost, boost_target, 1.0 - exp(-6.0 * delta)) if delta > 0.0 else 0.0
	camera.fov = SettingsManager.get_float("gameplay", "fov") + _fov_boost

	# Fade the character rather than clip through him when the camera is pushed close.
	target.visuals.set_fade(1.0 - smoothstep(tuning.fade_end_distance, tuning.fade_start_distance, _distance))


## Fraction of `motion` a camera-sized sphere can travel from `from` before hitting the world.
func _cast_fraction(space: PhysicsDirectSpaceState3D, from: Vector3, motion: Vector3) -> float:
	if motion.length_squared() < 0.0001:
		return 1.0
	_cast.transform = Transform3D(Basis.IDENTITY, from)
	_cast.motion = motion
	var result: PackedFloat32Array = space.cast_motion(_cast)
	return result[0] if result.size() > 0 else 1.0


func _apply_settings() -> void:
	if camera != null:
		camera.far = SettingsManager.get_float("graphics", "view_distance")


func _on_setting_changed(_section: String, _key: String, _value: Variant) -> void:
	_apply_settings()
