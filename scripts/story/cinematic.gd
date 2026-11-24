class_name Cinematic
extends Node
## Plays an in-engine cutscene: a list of camera shots and timed subtitle
## lines, with letterbox bars. Hold Jump or Interact to skip.
##
## Shots are dictionaries: {"from": Vector3, "look": Vector3, "seconds": float,
## optional "to": Vector3, "look_to": Vector3, "fov": float}. The camera eases
## from `from` to `to` over the shot. Lines are {"at", "speaker", "text",
## "seconds", optional "sound"} with `at` measured from the start.

signal finished(skipped: bool)

const SKIP_HOLD_SECONDS: float = 0.9

var is_playing: bool = false
## 0..1 while the skip button is held.
var skip_progress: float = 0.0

var _camera: Camera3D
var _previous_camera: Camera3D
var _shots: Array = []
var _lines: Array = []
var _time: float = 0.0
var _duration: float = 0.0
var _next_line: int = 0
var _player: Player
var _events: Array = []
var _player_was_invulnerable: bool = false


func _ready() -> void:
	set_process(false)


## `events`: optional [{"at": seconds, "call": Callable}] fired during playback.
func play(shots: Array, lines: Array, player: Player = null, events: Array = []) -> void:
	if is_playing or shots.is_empty():
		return
	is_playing = true
	_shots = shots
	_lines = lines.duplicate()
	_events = events.duplicate()
	_time = 0.0
	_next_line = 0
	skip_progress = 0.0
	_duration = 0.0
	for shot: Dictionary in shots:
		_duration += float(shot["seconds"])
	_player = player
	if player != null:
		_player_was_invulnerable = player.god_mode
		player.input_enabled = false
		player.god_mode = true
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.far = 400.0
	add_child(_camera)
	_camera.make_current()
	_place_camera()
	EventBus.cinematic_changed.emit(true)
	set_process(true)


func get_duration() -> float:
	return _duration


func skip() -> void:
	if is_playing:
		_finish(true)


func _process(delta: float) -> void:
	_time += delta
	var held: bool = Input.is_action_pressed(&"jump") or Input.is_action_pressed(&"interact")
	skip_progress = clampf(skip_progress + (delta if held else -delta * 2.0) / SKIP_HOLD_SECONDS, 0.0, 1.0)
	if skip_progress >= 1.0:
		_finish(true)
		return
	while _next_line < _lines.size() and float(_lines[_next_line]["at"]) <= _time:
		var line: Dictionary = _lines[_next_line]
		EventBus.dialogue_requested.emit([line])
		_next_line += 1
	for i: int in range(_events.size() - 1, -1, -1):
		if float(_events[i]["at"]) <= _time:
			(_events[i]["call"] as Callable).call()
			_events.remove_at(i)
	if _time >= _duration:
		_finish(false)
		return
	_place_camera()


func _place_camera() -> void:
	var start: float = 0.0
	for shot: Dictionary in _shots:
		var seconds: float = float(shot["seconds"])
		if _time < start + seconds or shot == _shots[_shots.size() - 1]:
			var t: float = smoothstep(0.0, 1.0, clampf((_time - start) / seconds, 0.0, 1.0))
			var from: Vector3 = shot["from"]
			var look: Vector3 = shot["look"]
			var position: Vector3 = from.lerp(shot.get("to", from), t)
			var target: Vector3 = look.lerp(shot.get("look_to", look), t)
			_camera.fov = float(shot.get("fov", 55.0))
			if position.distance_squared_to(target) > 0.01:
				_camera.look_at_from_position(position, target, Vector3.UP)
			return
		start += seconds


func _finish(skipped: bool) -> void:
	is_playing = false
	set_process(false)
	# Anything scripted that has not happened yet still happens when skipping.
	for event: Dictionary in _events:
		(event["call"] as Callable).call()
	_events.clear()
	if _camera != null:
		_camera.queue_free()
		_camera = null
	if _previous_camera != null and is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	if _player != null and is_instance_valid(_player):
		_player.input_enabled = true
		_player.god_mode = _player_was_invulnerable
	EventBus.cinematic_changed.emit(false)
	finished.emit(skipped)
