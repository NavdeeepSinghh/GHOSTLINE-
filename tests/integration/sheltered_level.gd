extends Node3D
## Test stand-in for a level that answers is_sheltered().

var roof: bool = false


func is_sheltered(_point: Vector3) -> bool:
	return roof
