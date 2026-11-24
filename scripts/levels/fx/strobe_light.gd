class_name StrobeLight
extends OmniLight3D
## Emergency lights: alternates between two colours, flashing each one twice.
## `lamps` are two meshes (one per colour) shown with their own flashes.

var colors: Array[Color] = [Color(1.0, 0.1, 0.08), Color(0.15, 0.3, 1.0)]
var lamps: Array[Node3D] = []
var period: float = 1.1

var _base_energy: float = -1.0
var _time: float = 0.0


func _process(delta: float) -> void:
	if _base_energy < 0.0:
		_base_energy = light_energy
	_time += delta
	var half: float = period * 0.5
	var side: int = int(fposmod(_time, period) / half)
	var local: float = fposmod(_time, half) / half
	# Two short flashes per side.
	var on: bool = local < 0.18 or (local > 0.3 and local < 0.48)
	if Accessibility.reduce_flashing():
		# Steady, slowly alternating colours instead of flashes.
		on = true
	light_color = colors[side]
	light_energy = _base_energy if on else 0.0
	for i: int in lamps.size():
		lamps[i].visible = on and i == side
