class_name TwoBoneIK
extends RefCounted
## Analytic two-bone IK (shoulder-elbow-hand, hip-knee-foot) on a Skeleton3D.
## Positions are in skeleton space. Used by the procedural crouch and climb poses.


## Bends the chain root->mid->tip so the tip reaches `target`.
## `pole` is the direction the middle joint (elbow or knee) should point.
static func solve(skeleton: Skeleton3D, root_bone: int, mid_bone: int, tip_bone: int,
		target: Vector3, pole: Vector3) -> void:
	var root_pose: Transform3D = skeleton.get_bone_global_pose(root_bone)
	var mid_pose: Transform3D = skeleton.get_bone_global_pose(mid_bone)
	var tip_pose: Transform3D = skeleton.get_bone_global_pose(tip_bone)

	var upper_length: float = root_pose.origin.distance_to(mid_pose.origin)
	var lower_length: float = mid_pose.origin.distance_to(tip_pose.origin)
	if upper_length < 0.0001 or lower_length < 0.0001:
		return

	var to_target: Vector3 = target - root_pose.origin
	var reach: float = clampf(to_target.length(),
			absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	var direction: Vector3 = to_target.normalized() if to_target.length_squared() > 0.000001 else Vector3.DOWN

	# Law of cosines gives where the middle joint sits along and off the reach line.
	var along: float = (upper_length * upper_length + reach * reach - lower_length * lower_length) / (2.0 * reach)
	var off: float = sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var bend_axis: Vector3 = pole - direction * pole.dot(direction)
	if bend_axis.length_squared() < 0.000001:
		bend_axis = direction.cross(Vector3.RIGHT)
	bend_axis = bend_axis.normalized()
	var mid_target: Vector3 = root_pose.origin + direction * along + bend_axis * off
	var tip_target: Vector3 = root_pose.origin + direction * reach

	_aim(skeleton, root_bone, mid_pose.origin, mid_target)
	var new_tip: Vector3 = skeleton.get_bone_global_pose(tip_bone).origin
	_aim(skeleton, mid_bone, new_tip, tip_target)


## Rotates `bone` with the smallest rotation that swings `from_point` onto `to_point`.
static func _aim(skeleton: Skeleton3D, bone: int, from_point: Vector3, to_point: Vector3) -> void:
	var pose: Transform3D = skeleton.get_bone_global_pose(bone)
	var from_direction: Vector3 = (from_point - pose.origin).normalized()
	var to_direction: Vector3 = (to_point - pose.origin).normalized()
	if from_direction.is_zero_approx() or to_direction.is_zero_approx():
		return
	if from_direction.dot(to_direction) > 0.999999:
		return
	var swing := Quaternion(from_direction, to_direction)
	pose.basis = Basis(swing) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)
