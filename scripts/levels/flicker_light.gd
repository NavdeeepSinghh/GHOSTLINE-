extends OmniLight3D
## A failing lamp or neon tube: mostly on, with irregular dips and short blackouts.

var linked_label: Label3D

var _base_energy: float = 1.0
var _label_color: Color
var _time: float = 0.0
var _blackout: float = 0.0
var _seed: float = 0.0


var _started: bool = false


func _process(delta: float) -> void:
	if not _started:
		_started = true
		_base_energy = light_energy
		_seed = randf() * 100.0
		if linked_label != null:
			_label_color = linked_label.modulate
	_time += delta
	_blackout -= delta
	if _blackout < -randf_range(2.0, 9.0):
		_blackout = randf_range(0.05, 0.35)
	var level: float = 0.82 + 0.18 * sin(_time * 31.0 + _seed) * sin(_time * 7.3 + _seed * 2.0)
	if _blackout > 0.0:
		level = 0.08
	if Accessibility.reduce_flashing():
		level = 0.9
	light_energy = _base_energy * level
	if linked_label != null:
		linked_label.modulate = _label_color * (0.25 + 0.75 * level)
