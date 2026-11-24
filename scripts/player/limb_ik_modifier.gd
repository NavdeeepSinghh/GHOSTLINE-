class_name LimbIKModifier
extends SkeletonModifier3D
## Pulls hands and feet onto world targets (ledge edges, ladder rungs) with
## two-bone IK. Each limb has its own weight so poses fade in and out smoothly.

enum Limb { HAND_LEFT, HAND_RIGHT, FOOT_LEFT, FOOT_RIGHT }

const LIMB_COUNT: int = 4

## Skeleton-space targets and blend weights, indexed by Limb.
var targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var weights: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0]

var _roots: PackedInt32Array = [-1, -1, -1, -1]
var _mids: PackedInt32Array = [-1, -1, -1, -1]
var _tips: PackedInt32Array = [-1, -1, -1, -1]
## Elbows point down and back; knees point forward and slightly out.
var _poles: Array[Vector3] = [
	Vector3(0.5, -1.0, -0.45), Vector3(-0.5, -1.0, -0.45),
	Vector3(0.3, 0.15, 1.0), Vector3(-0.3, 0.15, 1.0),
]


func configure(animation_set: CharacterAnimationSet, skeleton: Skeleton3D) -> void:
	for side: int in 2:
		_roots[side] = skeleton.find_bone(animation_set.upper_arm_bones[side])
		_mids[side] = skeleton.find_bone(animation_set.lower_arm_bones[side])
		_tips[side] = skeleton.find_bone(animation_set.hand_bones[side])
		_roots[2 + side] = skeleton.find_bone(animation_set.upper_leg_bones[side])
		_mids[2 + side] = skeleton.find_bone(animation_set.lower_leg_bones[side])
		_tips[2 + side] = skeleton.find_bone(animation_set.foot_bones[side])


func is_idle() -> bool:
	for weight: float in weights:
		if weight > 0.001:
			return false
	return true


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	for limb: int in LIMB_COUNT:
		var weight: float = weights[limb]
		if weight <= 0.001 or _tips[limb] < 0:
			continue
		var animated_tip: Vector3 = skeleton.get_bone_global_pose(_tips[limb]).origin
		var goal: Vector3 = animated_tip.lerp(targets[limb], weight)
		TwoBoneIK.solve(skeleton, _roots[limb], _mids[limb], _tips[limb], goal, _poles[limb])
