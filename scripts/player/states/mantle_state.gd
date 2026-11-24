extends PlayerState
## Pulling up onto a ledge: the body rises first, then moves over the edge.
## Position is driven directly along that path (clearance was checked by the
## LedgeDetector before entering).

var _ledge: LedgeInfo
var _from: Vector3
var _to: Vector3
var _duration: float = 0.4
var _elapsed: float = 0.0


func enter(_previous: StringName, message: Dictionary) -> void:
	_ledge = message["ledge"]
	_from = player.global_position
	_to = _ledge.stand_position
	_elapsed = 0.0
	var tuning: PlayerTuning = player.tuning
	var climb_height: float = maxf(_to.y - _from.y, 0.0)
	_duration = maxf(tuning.mantle_min_duration, climb_height * tuning.mantle_seconds_per_metre)
	player.velocity = Vector3.ZERO
	player.is_sprinting = false
	player.snap_facing(-_ledge.normal)
	player.visuals.set_pose_mode(PlayerVisuals.PoseMode.MANTLE)
	var spread: Vector3 = _ledge.get_tangent() * player.visuals.animation_set.hand_spread
	var grip: Vector3 = _ledge.edge_point - _ledge.normal * 0.06 + Vector3.UP * 0.03
	player.visuals.set_hand_targets(grip - spread, grip + spread)


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var rise: float = ease(clampf(t / 0.7, 0.0, 1.0), 0.55)
	var over: float = smoothstep(0.5, 1.0, t)
	player.global_position = Vector3(
			lerpf(_from.x, _to.x, over),
			lerpf(_from.y, _to.y, rise),
			lerpf(_from.z, _to.z, over))
	if t > 0.6:
		player.visuals.release_hands()
	if t >= 1.0:
		_finish()


func _finish() -> void:
	# Touch down so the Ground state starts with valid floor contact.
	player.velocity = Vector3(0.0, -1.5, 0.0)
	player.move_and_slide()
	player.velocity = Vector3.ZERO
	player.ledge_cooldown = player.tuning.ledge_regrab_cooldown
	machine.transition_to(&"Ground" if player.is_on_floor() else &"Air")
