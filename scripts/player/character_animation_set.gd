class_name CharacterAnimationSet
extends Resource
## Describes one character model: which clips play for which logical action,
## how locomotion blends, and the bone names procedural poses need.
##
## Swapping Kael's model later means authoring a new one of these resources;
## the movement and animation code does not change.

@export var model: PackedScene
## Uniform scale applied to the model so the character is the right height.
@export var model_scale: float = 0.8
## Child nodes of the model to hide (spare weapons and props).
@export var hidden_nodes: PackedStringArray = []

@export_group("Clips")
@export var air_clip: StringName = &"Jump_Idle"
@export var land_clip: StringName = &"Jump_Land"
## Base pose under the procedural arms while hanging and climbing.
@export var climb_clip: StringName = &"Idle"
## Clips that must loop (imported clips do not carry loop flags).
@export var looping_clips: PackedStringArray = []

## One-off action clips (attacks, dodge, block, hit reactions) the animation tree can play.
@export var action_clips: PackedStringArray = [
	"1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop",
	"1H_Melee_Attack_Stab", "2H_Melee_Attack_Chop", "Dodge_Forward", "Blocking", "Block_Hit",
	"Hit_A", "Hit_B", "Death_A", "Throw", "Use_Item", "Dodge_Backward"]
## Fraction of a light attack clip at which the weapon connects.
@export var light_impact_fraction: float = 0.36
## Fraction of the heavy attack clip at which the weapon connects.
@export var heavy_impact_fraction: float = 0.42
## Bone attachment node the weapon is parented to.
@export var weapon_slot: String = "handslot_r"

@export_group("Locomotion blend")
## Clips blended by ground speed, slowest first. The first is the idle.
@export var locomotion_clips: PackedStringArray = []
## Ground speed in m/s at which each clip is fully blended in.
@export var locomotion_speeds: PackedFloat32Array = []
## Seconds one full stride cycle should take at each of those speeds.
@export var locomotion_cycle_seconds: PackedFloat32Array = []
## Stride cycle at full sprint.
@export var sprint_cycle_seconds: float = 0.5
## Stride cycle while crouch-walking (uses the second clip in the blend).
@export var crouch_cycle_seconds: float = 0.62

@export_group("Bones")
@export var hips_bone: StringName = &"hips"
@export var spine_bone: StringName = &"spine"
@export var chest_bone: StringName = &"chest"
@export var head_bone: StringName = &"head"
@export var upper_arm_bones: PackedStringArray = ["upperarm.l", "upperarm.r"]
@export var lower_arm_bones: PackedStringArray = ["lowerarm.l", "lowerarm.r"]
@export var hand_bones: PackedStringArray = ["wrist.l", "wrist.r"]
@export var upper_leg_bones: PackedStringArray = ["upperleg.l", "upperleg.r"]
@export var lower_leg_bones: PackedStringArray = ["lowerleg.l", "lowerleg.r"]
@export var foot_bones: PackedStringArray = ["foot.l", "foot.r"]

@export_group("Crouch pose (model units)")
@export var crouch_hip_drop: float = 0.17
@export var crouch_hip_shift_back: float = 0.06
@export var crouch_spine_lean_degrees: float = 34.0
@export var crouch_head_counter_degrees: float = 26.0

@export_group("Climb pose (metres)")
## Half the distance between the hands on a ledge.
@export var hand_spread: float = 0.2
## How far the visible body sits toward the wall while hanging.
@export var hang_forward_offset: float = 0.08
## Height of the hands above the feet on a ladder.
@export var ladder_hand_height: float = 1.0
@export var ladder_foot_height: float = 0.12
@export var ladder_rung_spacing: float = 0.3
