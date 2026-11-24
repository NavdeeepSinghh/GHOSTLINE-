class_name FireLight
extends OmniLight3D
## Firelight: a smooth, restless flicker with a little movement.

var _base_energy: float = -1.0
var _base_position: Vector3
var _time: float = 0.0
var _seed: float = 0.0


func _process(delta: float) -> void:
	if _base_energy < 0.0:
		_base_energy = light_energy
		_base_position = position
		_seed = randf() * 100.0
	_time += delta
	var t: float = _time + _seed
	var level: float = 0.78 + 0.14 * sin(t * 9.1) * sin(t * 3.7) + 0.08 * sin(t * 23.0 + 1.3)
	light_energy = _base_energy * level
	position = _base_position + Vector3(sin(t * 5.3), 0.0, cos(t * 4.1)) * 0.06
