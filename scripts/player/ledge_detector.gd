class_name LedgeDetector
extends Node
## Finds grabbable ledges with raycasts against the "climbable" physics layer.
##
## Only surfaces a level designer marked climbable count (yellow-edged in the
## world), so climbing is predictable for the player. Must be called from the
## physics step.

const WALL_PROBE_HEIGHTS: PackedFloat32Array = [0.25, 0.6, 0.95, 1.3, 1.65]
const MIN_TOP_NORMAL_Y: float = 0.7
const MAX_WALL_NORMAL_Y: float = 0.35

var _player: Player


func _ready() -> void:
	_player = get_parent() as Player


## Looks for a ledge whose top is between min_height and max_height above
## `origin` (the feet), on a wall within reach along `facing`.
func find_ledge(origin: Vector3, facing: Vector3, min_height: float, max_height: float) -> LedgeInfo:
	var tuning: PlayerTuning = _player.tuning
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var reach: float = tuning.body_radius + tuning.ledge_reach

	# 1. Find the wall face in front of the body.
	var wall: Dictionary = {}
	for probe_height: float in WALL_PROBE_HEIGHTS:
		if probe_height > max_height:
			break
		var from: Vector3 = origin + Vector3.UP * probe_height
		var hit: Dictionary = _ray(space, from, from + facing * reach, Player.LAYER_CLIMBABLE)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < MAX_WALL_NORMAL_Y:
			wall = hit
			break
	if wall.is_empty():
		return null
	var wall_normal: Vector3 = wall["normal"]
	wall_normal.y = 0.0
	wall_normal = wall_normal.normalized()
	if facing.dot(wall_normal) > -0.45:
		return null
	var wall_point: Vector3 = wall["position"]

	# 2. Drop a ray just inside the wall to find its top surface.
	var inside: Vector3 = wall_point - wall_normal * 0.12
	var top_from := Vector3(inside.x, origin.y + max_height + 0.05, inside.z)
	var top_to := Vector3(inside.x, origin.y + min_height - 0.05, inside.z)
	var top: Dictionary = _ray(space, top_from, top_to, Player.LAYER_CLIMBABLE)
	if top.is_empty() or (top["normal"] as Vector3).y < MIN_TOP_NORMAL_Y:
		return null
	var top_y: float = (top["position"] as Vector3).y

	# 3. Nothing may sit on the edge itself (the gap above the lip must be open).
	var wall_distance: float = maxf((wall_point - origin).dot(-wall_normal), 0.0)
	var lip_from := Vector3(origin.x, top_y + 0.12, origin.z)
	var lip_to: Vector3 = lip_from - wall_normal * (wall_distance + 0.3)
	if not _ray(space, lip_from, lip_to, Player.LAYER_WORLD).is_empty():
		return null

	var ledge := LedgeInfo.new()
	ledge.normal = wall_normal
	ledge.top_y = top_y
	ledge.edge_point = Vector3(wall_point.x, top_y, wall_point.z)
	ledge.stand_position = ledge.edge_point - wall_normal * (tuning.body_radius + 0.08) + Vector3.UP * 0.02
	ledge.hang_position = (ledge.edge_point + wall_normal * (tuning.body_radius + 0.04)
			- Vector3.UP * tuning.hang_feet_offset)
	ledge.can_stand = _capsule_fits(space, ledge.stand_position, tuning.stand_height)
	ledge.can_hang = _capsule_fits(space, ledge.hang_position, tuning.stand_height)
	return ledge


## Re-checks a ledge at a sideways offset (used while shimmying).
func find_ledge_along(ledge: LedgeInfo, sideways: float) -> LedgeInfo:
	var tuning: PlayerTuning = _player.tuning
	var origin: Vector3 = ledge.hang_position + ledge.get_tangent() * sideways
	var facing: Vector3 = -ledge.normal
	return find_ledge(origin, facing, tuning.hang_feet_offset - 0.15, tuning.hang_feet_offset + 0.15)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, [_player.get_rid()])
	return space.intersect_ray(query)


func _capsule_fits(space: PhysicsDirectSpaceState3D, feet: Vector3, height: float) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = _player.tuning.body_radius - 0.03
	shape.height = height - 0.06
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5 + 0.04))
	query.collision_mask = Player.LAYER_WORLD
	query.exclude = [_player.get_rid()]
	return space.intersect_shape(query, 1).is_empty()
