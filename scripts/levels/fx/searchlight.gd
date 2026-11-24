class_name Searchlight
extends Node3D
## A distant searchlight beam sweeping the clouds.

var sweep_speed: float = 0.12
var tilt_degrees: float = 28.0
var tilt_wobble: float = 8.0

var _time: float = 0.0
var _pivot: Node3D


func _ready() -> void:
	_pivot = get_child(0) as Node3D
	_time = randf() * 50.0


func _process(delta: float) -> void:
	_time += delta
	rotation.y = _time * sweep_speed
	if _pivot != null:
		_pivot.rotation.x = deg_to_rad(tilt_degrees + tilt_wobble * sin(_time * 0.37))
