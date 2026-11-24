class_name LedgeInfo
extends RefCounted
## Describes a climbable ledge found in front of the player.

## Point on the wall face at the height of the ledge's top edge.
var edge_point: Vector3
## Horizontal wall normal, pointing away from the wall toward the player.
var normal: Vector3
## World Y of the top surface.
var top_y: float
## Where the feet go while hanging.
var hang_position: Vector3
## Where the feet go after climbing up.
var stand_position: Vector3
## True when there is room to stand on top.
var can_stand: bool = false
## True when the body fits hanging below the edge.
var can_hang: bool = false


## Direction along the ledge, to the player's right when facing the wall.
func get_tangent() -> Vector3:
	return Vector3.UP.cross(normal).normalized()
