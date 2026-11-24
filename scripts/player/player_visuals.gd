class_name PlayerVisuals
extends Node3D
## Everything you see of Kael: the model, its animation tree, procedural
## crouch and climb poses, and small touches (lean into turns, landing dip,
## smoothing over steps). Reads the Player; never changes gameplay state.

enum PoseMode { GROUND, AIR, HANG, LADDER, MANTLE, ACTION }

const DEFAULT_SET_PATH: String = "res://data/characters/kael_standin.tres"
## All locomotion clips are stretched to this length so their strides stay in phase.
const BASE_CYCLE: float = 1.0
const STATE_NAMES: PackedStringArray = ["ground", "air", "climb", "action"]

@export var animation_set: CharacterAnimationSet

var pose_mode: PoseMode = PoseMode.GROUND

var _player: Player
var _offset: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _crouch: CrouchModifier
var _limbs: LimbIKModifier

var _blend: float = 0.0
var _crouch_amount: float = 0.0
var _step_offset: Vector3 = Vector3.ZERO
var _dip: float = 0.0
var _dip_velocity: float = 0.0
var _lean_roll: float = 0.0
var _lean_pitch: float = 0.0
var _previous_yaw: float = 0.0
var _hang_forward: float = 0.0
var _fade: float = 0.0
var _meshes: Array[GeometryInstance3D] = []
var _clip_lengths: Dictionary = {}
var _weapon_slot: Node3D
var _weapon_model: Node3D
var _flash_material: StandardMaterial3D
var _flash_time: float = 0.0

## World-space limb targets, set by climb states.
var _limb_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _limb_smoothed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _limb_goal_weight: PackedFloat32Array = [0.0, 0.0, 0.0, 0.0]
var _limb_snap: bool = true


func _ready() -> void:
	_player = get_parent() as Player
	if animation_set == null:
		animation_set = load(DEFAULT_SET_PATH)
	_offset = Node3D.new()
	_offset.name = "Offset"
	add_child(_offset)
	_model = animation_set.model.instantiate()
	# Imported models face +Z; Godot's forward is -Z.
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * animation_set.model_scale
	_offset.add_child(_model)
	for node_name: String in animation_set.hidden_nodes:
		var node: Node = _model.find_child(node_name, true, false)
		if node is Node3D:
			(node as Node3D).visible = false
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	for mesh: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(mesh as GeometryInstance3D)
	var animation_player: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: String in animation_set.looping_clips:
		if animation_player.has_animation(clip):
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip: String in animation_player.get_animation_list():
		_clip_lengths[StringName(clip)] = animation_player.get_animation(clip).length
	_build_animation_tree(animation_player)
	_weapon_slot = _model.find_child(animation_set.weapon_slot, true, false) as Node3D
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0)
	_crouch = CrouchModifier.new()
	_crouch.name = "CrouchModifier"
	_skeleton.add_child(_crouch)
	_crouch.configure(animation_set, _skeleton)
	_limbs = LimbIKModifier.new()
	_limbs.name = "LimbIKModifier"
	_skeleton.add_child(_limbs)
	_limbs.configure(animation_set, _skeleton)
	_previous_yaw = rotation.y


func _process(delta: float) -> void:
	if _player == null:
		return
	_update_locomotion(delta)
	_update_body_motion(delta)
	_update_limbs(delta)
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_material.albedo_color.a = clampf(_flash_time / 0.12, 0.0, 1.0) * 0.7
		if _flash_time <= 0.0:
			for mesh: GeometryInstance3D in _meshes:
				mesh.material_overlay = null


# --- Called by states -------------------------------------------------------

func set_pose_mode(mode: PoseMode) -> void:
	pose_mode = mode
	var state_name: String = "ground"
	match mode:
		PoseMode.AIR, PoseMode.MANTLE:
			state_name = "air"
		PoseMode.HANG, PoseMode.LADDER:
			state_name = "climb"
		PoseMode.ACTION:
			state_name = "action"
	_tree.set(&"parameters/state/transition_request", state_name)
	if mode == PoseMode.GROUND or mode == PoseMode.AIR or mode == PoseMode.ACTION:
		clear_limb_targets()


## Plays a one-off action clip. With `duration` > 0 the clip is sped up or
## slowed so it lasts exactly that long (keeps animation in step with attack timing).
func play_action(clip: StringName, duration: float = 0.0) -> void:
	if not _clip_lengths.has(clip) or not animation_set.action_clips.has(String(clip)):
		push_warning("PlayerVisuals: no action clip '%s'" % clip)
		return
	set_pose_mode(PoseMode.ACTION)
	var length: float = _clip_lengths[clip]
	set_action_speed(length / duration if duration > 0.0 else 1.0)
	_tree.set(&"parameters/action_pick/transition_request", String(clip))


func set_action_speed(speed: float) -> void:
	_tree.set(&"parameters/action_scale/scale", speed)


func get_clip_length(clip: StringName) -> float:
	return _clip_lengths.get(clip, 1.0)


## Shows the model for a weapon in Kael's hand.
func show_weapon(weapon: WeaponData) -> void:
	if _weapon_model != null:
		_weapon_model.queue_free()
		_weapon_model = null
	if weapon == null or _weapon_slot == null:
		return
	_weapon_model = WeaponModels.build(weapon.look)
	_weapon_slot.add_child(_weapon_model)


## A brief white flash over the whole body (taking a hit, a successful parry).
func flash(color: Color = Color.WHITE) -> void:
	_flash_material.albedo_color = Color(color, 0.7)
	_flash_time = 0.12
	for mesh: GeometryInstance3D in _meshes:
		mesh.material_overlay = _flash_material


func play_jump() -> void:
	_dip_velocity = -1.2


## Landing: a springy dip scaled by impact, plus the landing clip when nearly still.
func play_land(impact_speed: float) -> void:
	_dip_velocity = clampf(impact_speed * 0.22, 0.6, 3.2)
	if _player.get_horizontal_speed() < 2.5:
		_tree.set(&"parameters/land/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Hides a sudden body move (a stair step, a ledge snap) by letting the model catch up.
func absorb_step(world_offset: Vector3) -> void:
	_step_offset += world_offset


func reset_offsets() -> void:
	_step_offset = Vector3.ZERO
	_dip = 0.0
	_dip_velocity = 0.0
	_lean_roll = 0.0
	_lean_pitch = 0.0


## Hands on a ledge. Points are in world space.
func set_hand_targets(left: Vector3, right: Vector3) -> void:
	_set_limb(LimbIKModifier.Limb.HAND_LEFT, left)
	_set_limb(LimbIKModifier.Limb.HAND_RIGHT, right)


func set_foot_targets(left: Vector3, right: Vector3) -> void:
	_set_limb(LimbIKModifier.Limb.FOOT_LEFT, left)
	_set_limb(LimbIKModifier.Limb.FOOT_RIGHT, right)


func release_hands() -> void:
	_limb_goal_weight[LimbIKModifier.Limb.HAND_LEFT] = 0.0
	_limb_goal_weight[LimbIKModifier.Limb.HAND_RIGHT] = 0.0


func clear_limb_targets() -> void:
	for limb: int in LimbIKModifier.LIMB_COUNT:
		_limb_goal_weight[limb] = 0.0


func get_skeleton() -> Skeleton3D:
	return _skeleton


## 0 = solid, 1 = invisible. The camera fades Kael out when it is pushed up against him.
func set_fade(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if absf(amount - _fade) < 0.01:
		return
	_fade = amount
	for mesh: GeometryInstance3D in _meshes:
		mesh.transparency = amount


func get_crouch_amount() -> float:
	return _crouch_amount


# --- Internals --------------------------------------------------------------

func _set_limb(limb: int, world_point: Vector3) -> void:
	if _limb_goal_weight[limb] <= 0.0 and _limbs.weights[limb] <= 0.01:
		_limb_smoothed[limb] = world_point
	_limb_world[limb] = world_point
	_limb_goal_weight[limb] = 1.0


func _update_locomotion(delta: float) -> void:
	var tuning: PlayerTuning = _player.tuning
	var speed: float = _player.get_horizontal_speed()
	var speeds: PackedFloat32Array = animation_set.locomotion_speeds
	var top_speed: float = speeds[speeds.size() - 1]
	var blend_target: float = minf(speed, top_speed)
	var cycle: float = _cycle_for_speed(speed)
	if _player.is_crouching:
		var crouch_ratio: float = clampf(speed / tuning.crouch_speed, 0.0, 1.0)
		blend_target = crouch_ratio * speeds[1]
		cycle = lerpf(animation_set.locomotion_cycle_seconds[0], animation_set.crouch_cycle_seconds, crouch_ratio)
	_blend = lerpf(_blend, blend_target, 1.0 - exp(-14.0 * delta))
	_tree.set(&"parameters/loco/blend_position", _blend)
	_tree.set(&"parameters/loco_scale/scale", BASE_CYCLE / maxf(cycle, 0.05))

	var crouch_target: float = 1.0 if (_player.is_crouching and pose_mode == PoseMode.GROUND) else 0.0
	_crouch_amount = move_toward(_crouch_amount, crouch_target, delta * 5.5)
	_crouch.amount = smoothstep(0.0, 1.0, _crouch_amount)


func _update_body_motion(delta: float) -> void:
	var tuning: PlayerTuning = _player.tuning
	var speed_ratio: float = clampf(_player.get_horizontal_speed() / tuning.sprint_speed, 0.0, 1.0)
	var grounded: bool = pose_mode == PoseMode.GROUND

	# Lean into turns and forward with speed.
	var yaw_rate: float = angle_difference(_previous_yaw, rotation.y) / maxf(delta, 0.0001)
	_previous_yaw = rotation.y
	var roll_target: float = clampf(yaw_rate * 0.035 * speed_ratio, -0.22, 0.22) if grounded else 0.0
	var pitch_target: float = -0.13 * speed_ratio if grounded else 0.0
	var ease: float = 1.0 - exp(-9.0 * delta)
	_lean_roll = lerpf(_lean_roll, roll_target, ease)
	_lean_pitch = lerpf(_lean_pitch, pitch_target, ease)

	# Landing dip: a critically damped spring.
	var stiffness: float = 190.0
	var damping: float = 24.0
	_dip_velocity += (-stiffness * _dip - damping * _dip_velocity) * delta
	_dip += _dip_velocity * delta
	_dip = clampf(_dip, -0.12, 0.3)

	_step_offset = _step_offset.lerp(Vector3.ZERO, 1.0 - exp(-13.0 * delta))
	var hang_target: float = animation_set.hang_forward_offset if pose_mode == PoseMode.HANG else 0.0
	_hang_forward = lerpf(_hang_forward, hang_target, ease)

	var local_step: Vector3 = _step_offset.rotated(Vector3.UP, -rotation.y)
	_offset.position = local_step + Vector3(0.0, -_dip, -_hang_forward)
	_offset.rotation = Vector3(_lean_pitch, 0.0, _lean_roll)


func _update_limbs(delta: float) -> void:
	var to_skeleton: Transform3D = _skeleton.get_global_transform_interpolated().affine_inverse()
	var follow: float = 1.0 - exp(-22.0 * delta)
	for limb: int in LimbIKModifier.LIMB_COUNT:
		_limbs.weights[limb] = move_toward(_limbs.weights[limb], _limb_goal_weight[limb], delta * 7.0)
		if _limbs.weights[limb] <= 0.001:
			continue
		_limb_smoothed[limb] = _limb_smoothed[limb].lerp(_limb_world[limb], follow)
		_limbs.targets[limb] = to_skeleton * _limb_smoothed[limb]


func _cycle_for_speed(speed: float) -> float:
	var speeds: PackedFloat32Array = animation_set.locomotion_speeds
	var cycles: PackedFloat32Array = animation_set.locomotion_cycle_seconds
	var last: int = speeds.size() - 1
	if speed >= speeds[last]:
		var sprint_speed: float = maxf(_player.tuning.sprint_speed, speeds[last] + 0.01)
		var over: float = clampf((speed - speeds[last]) / (sprint_speed - speeds[last]), 0.0, 1.0)
		return lerpf(cycles[last], animation_set.sprint_cycle_seconds, over)
	for i: int in range(1, speeds.size()):
		if speed <= speeds[i]:
			var t: float = (speed - speeds[i - 1]) / maxf(speeds[i] - speeds[i - 1], 0.0001)
			return lerpf(cycles[i - 1], cycles[i], t)
	return cycles[last]


func _build_animation_tree(animation_player: AnimationPlayer) -> void:
	var root := AnimationNodeBlendTree.new()

	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = animation_set.locomotion_speeds[animation_set.locomotion_speeds.size() - 1]
	loco.sync = true
	for i: int in animation_set.locomotion_clips.size():
		loco.add_blend_point(_clip_node(animation_set.locomotion_clips[i], true),
				animation_set.locomotion_speeds[i], -1, StringName(animation_set.locomotion_clips[i]))
	root.add_node(&"loco", loco, Vector2(0, 0))
	root.add_node(&"loco_scale", AnimationNodeTimeScale.new(), Vector2(220, 0))
	root.connect_node(&"loco_scale", 0, &"loco")

	root.add_node(&"air", _clip_node(animation_set.air_clip, false), Vector2(220, 160))
	root.add_node(&"climb", _clip_node(animation_set.climb_clip, false), Vector2(220, 320))

	var state := AnimationNodeTransition.new()
	state.xfade_time = 0.14
	state.input_count = STATE_NAMES.size()
	for i: int in STATE_NAMES.size():
		state.set_input_name(i, STATE_NAMES[i])
	root.add_node(&"state", state, Vector2(460, 120))
	root.connect_node(&"state", 0, &"loco_scale")
	root.connect_node(&"state", 1, &"air")
	root.connect_node(&"state", 2, &"climb")

	# One-off actions: a picker with one input per clip, played at a set speed.
	var action_pick := AnimationNodeTransition.new()
	action_pick.xfade_time = 0.07
	action_pick.allow_transition_to_self = true
	action_pick.input_count = animation_set.action_clips.size()
	root.add_node(&"action_pick", action_pick, Vector2(40, 480))
	for i: int in animation_set.action_clips.size():
		var clip_name: String = animation_set.action_clips[i]
		action_pick.set_input_name(i, clip_name)
		var node_name := StringName("action_%d" % i)
		root.add_node(node_name, _clip_node(StringName(clip_name), false), Vector2(-200, 480 + i * 40))
		root.connect_node(&"action_pick", i, node_name)
	root.add_node(&"action_scale", AnimationNodeTimeScale.new(), Vector2(240, 480))
	root.connect_node(&"action_scale", 0, &"action_pick")
	root.connect_node(&"state", 3, &"action_scale")

	var land_clip := _clip_node(animation_set.land_clip, false)
	root.add_node(&"land_clip", land_clip, Vector2(460, 340))
	var land_speed := AnimationNodeTimeScale.new()
	root.add_node(&"land_speed", land_speed, Vector2(640, 340))
	root.connect_node(&"land_speed", 0, &"land_clip")
	var land := AnimationNodeOneShot.new()
	land.fadein_time = 0.04
	land.fadeout_time = 0.2
	root.add_node(&"land", land, Vector2(820, 160))
	root.connect_node(&"land", 0, &"state")
	root.connect_node(&"land", 1, &"land_speed")
	root.connect_node(&"output", 0, &"land")

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = root
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(animation_player)
	_tree.active = true
	_tree.set(&"parameters/land_speed/scale", 1.6)
	_tree.set(&"parameters/loco_scale/scale", 1.0)
	_tree.set(&"parameters/action_scale/scale", 1.0)


func _clip_node(clip: StringName, stretch_to_base_cycle: bool) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip
	if stretch_to_base_cycle:
		node.use_custom_timeline = true
		node.timeline_length = BASE_CYCLE
		node.stretch_time_scale = true
		node.loop_mode = Animation.LOOP_LINEAR
	return node
