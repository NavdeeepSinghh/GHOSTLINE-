class_name CrouchModifier
extends SkeletonModifier3D
## Procedural crouch layered on top of whatever clip is playing: lowers the
## hips, leans the torso forward and re-plants both feet with IK. This turns the
## standing idle and walk into a crouched idle and crouch-walk without needing
## dedicated clips.

## 0 = standing, 1 = fully crouched.
var amount: float = 0.0

var _set: CharacterAnimationSet
var _hips: int = -1
var _spine: int = -1
var _head: int = -1
var _upper_legs: PackedInt32Array = []
var _lower_legs: PackedInt32Array = []
var _feet: PackedInt32Array = []


func configure(animation_set: CharacterAnimationSet, skeleton: Skeleton3D) -> void:
	_set = animation_set
	_hips = skeleton.find_bone(animation_set.hips_bone)
	_spine = skeleton.find_bone(animation_set.spine_bone)
	_head = skeleton.find_bone(animation_set.head_bone)
	_upper_legs = _find_all(skeleton, animation_set.upper_leg_bones)
	_lower_legs = _find_all(skeleton, animation_set.lower_leg_bones)
	_feet = _find_all(skeleton, animation_set.foot_bones)


func _process_modification() -> void:
	if amount <= 0.001 or _set == null or _hips < 0:
		return
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return

	# Remember where the animation put the feet, so they stay planted.
	var foot_poses: Array[Transform3D] = []
	for foot: int in _feet:
		foot_poses.append(skeleton.get_bone_global_pose(foot))

	var hips_pose: Transform3D = skeleton.get_bone_global_pose(_hips)
	hips_pose.origin.y -= _set.crouch_hip_drop * amount
	hips_pose.origin.z -= _set.crouch_hip_shift_back * amount
	skeleton.set_bone_global_pose(_hips, hips_pose)

	if _spine >= 0:
		var spine_pose: Transform3D = skeleton.get_bone_global_pose(_spine)
		spine_pose.basis = Basis(Vector3.RIGHT, deg_to_rad(_set.crouch_spine_lean_degrees) * amount) * spine_pose.basis
		skeleton.set_bone_global_pose(_spine, spine_pose)
	if _head >= 0:
		var head_pose: Transform3D = skeleton.get_bone_global_pose(_head)
		head_pose.basis = Basis(Vector3.RIGHT, -deg_to_rad(_set.crouch_head_counter_degrees) * amount) * head_pose.basis
		skeleton.set_bone_global_pose(_head, head_pose)

	for i: int in _feet.size():
		var side: float = -1.0 if i == 1 else 1.0
		var knee_pole := Vector3(0.25 * side, 0.0, 1.0)
		TwoBoneIK.solve(skeleton, _upper_legs[i], _lower_legs[i], _feet[i], foot_poses[i].origin, knee_pole)
		# Keep the sole flat exactly as the clip had it.
		var foot_pose: Transform3D = skeleton.get_bone_global_pose(_feet[i])
		foot_pose.basis = foot_poses[i].basis
		skeleton.set_bone_global_pose(_feet[i], foot_pose)


func _find_all(skeleton: Skeleton3D, names: PackedStringArray) -> PackedInt32Array:
	var result: PackedInt32Array = []
	for bone_name: String in names:
		result.append(skeleton.find_bone(bone_name))
	return result
