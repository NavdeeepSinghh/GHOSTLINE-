extends GutTest
## Tuning data loads, the jump maths holds, and every input action exists.

const REQUIRED_ACTIONS: PackedStringArray = [
	"move_forward", "move_back", "move_left", "move_right",
	"look_up", "look_down", "look_left", "look_right",
	"sprint", "walk", "jump", "crouch", "interact", "lock_on", "pause", "debug_overlay", "help",
]


func test_player_tuning_loads_with_brief_values() -> void:
	var tuning: PlayerTuning = load("res://data/player_tuning.tres")
	assert_not_null(tuning)
	assert_almost_eq(tuning.walk_speed, 2.0, 0.001)
	assert_almost_eq(tuning.jog_speed, 4.5, 0.001)
	assert_almost_eq(tuning.sprint_speed, 7.0, 0.001)
	assert_almost_eq(tuning.crouch_speed, 1.8, 0.001)
	assert_almost_eq(tuning.coyote_time, 0.12, 0.001)
	assert_almost_eq(tuning.jump_buffer_time, 0.1, 0.001)


func test_jump_velocity_reaches_apex_height() -> void:
	var tuning := PlayerTuning.new()
	var velocity: float = tuning.get_jump_velocity()
	var apex: float = velocity * velocity / (2.0 * tuning.gravity)
	assert_almost_eq(apex, tuning.jump_apex_height, 0.0001)


func test_camera_tuning_loads() -> void:
	var tuning: CameraTuning = load("res://data/camera_tuning.tres")
	assert_not_null(tuning)
	assert_almost_eq(tuning.distance, 3.2, 0.001)
	assert_gt(tuning.max_pitch_degrees, tuning.min_pitch_degrees)


func test_animation_set_is_consistent() -> void:
	var animation_set: CharacterAnimationSet = load("res://data/characters/kael_standin.tres")
	assert_not_null(animation_set.model)
	assert_eq(animation_set.locomotion_clips.size(), animation_set.locomotion_speeds.size())
	assert_eq(animation_set.locomotion_clips.size(), animation_set.locomotion_cycle_seconds.size())
	var model: Node = animation_set.model.instantiate()
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for clip: String in animation_set.locomotion_clips:
		assert_true(player.has_animation(clip), "missing clip %s" % clip)
	for clip: StringName in [animation_set.air_clip, animation_set.land_clip, animation_set.climb_clip]:
		assert_true(player.has_animation(clip), "missing clip %s" % clip)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	for bone: String in [animation_set.hips_bone, animation_set.spine_bone, animation_set.head_bone]:
		assert_ne(skeleton.find_bone(bone), -1, "missing bone %s" % bone)
	for bones: PackedStringArray in [animation_set.upper_arm_bones, animation_set.lower_arm_bones,
			animation_set.hand_bones, animation_set.upper_leg_bones, animation_set.lower_leg_bones, animation_set.foot_bones]:
		for bone: String in bones:
			assert_ne(skeleton.find_bone(bone), -1, "missing bone %s" % bone)
	model.free()


func test_all_input_actions_are_registered() -> void:
	for action: String in REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "missing action %s" % action)
		assert_gt(InputMap.action_get_events(action).size(), 0, "no bindings for %s" % action)


func test_movement_has_keyboard_and_controller_bindings() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint"]:
		var has_key: bool = false
		var has_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		assert_true(has_key, "%s has no keyboard binding" % action)
		assert_true(has_pad, "%s has no controller binding" % action)
