class_name Blinker
extends Node3D
## Shows its children for `duty` of every `period` seconds (warning beacons,
## a traffic signal still blinking amber).

@export var period: float = 1.6
@export var duty: float = 0.35
@export var phase: float = 0.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	var on: bool = fposmod(_time + phase, period) < period * duty
	for child: Node in get_children():
		if child is Node3D:
			(child as Node3D).visible = on
