extends GutTest
## Settings persistence, graphics presets, and the save system's atomic round trip.

const SCRATCH_DIR: String = "user://test_scratch"

var _settings_path: String = SCRATCH_DIR + "/settings.cfg"


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)


func after_each() -> void:
	SettingsManager.reset_to_defaults(false)
	SaveManager.save_dir = SaveManager.SAVE_DIR
	GameState.reset()
	var dir := DirAccess.open(SCRATCH_DIR)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)


func test_default_preset_is_medium() -> void:
	assert_eq(SettingsManager.get_value("graphics", "preset"), "medium")
	assert_almost_eq(SettingsManager.get_float("graphics", "render_scale"), 0.75, 0.001)


func test_presets_scale_from_low_to_high() -> void:
	var low: Dictionary = SettingsManager.get_preset_values("low")
	var medium: Dictionary = SettingsManager.get_preset_values("medium")
	var high: Dictionary = SettingsManager.get_preset_values("high")
	for key: String in ["render_scale", "shadow_size", "volumetric_fog", "ssao", "ssr", "view_distance"]:
		assert_true(float(low[key]) <= float(medium[key]), "%s low <= medium" % key)
		assert_true(float(medium[key]) <= float(high[key]), "%s medium <= high" % key)
	assert_eq(int(low["volumetric_fog"]), 0, "Low uses plain fog")
	assert_eq(int(low["ssr"]), 0)


func test_applying_preset_updates_viewport() -> void:
	SettingsManager.apply_graphics_preset("low", false)
	assert_eq(SettingsManager.get_value("graphics", "preset"), "low")
	assert_almost_eq(get_tree().root.scaling_3d_scale, 0.6, 0.001)
	SettingsManager.apply_graphics_preset("high", false)
	assert_almost_eq(get_tree().root.scaling_3d_scale, 1.0, 0.001)


func test_changing_one_graphics_value_marks_preset_custom() -> void:
	SettingsManager.set_value("graphics", "render_scale", 0.5, false)
	assert_eq(SettingsManager.get_value("graphics", "preset"), "custom")


func test_fps_limit_is_applied() -> void:
	SettingsManager.set_value("graphics", "fps_limit", 60, false)
	assert_eq(Engine.max_fps, 60)


func test_settings_round_trip_through_disk() -> void:
	SettingsManager.set_value("controls", "mouse_sensitivity", 1.7, false)
	SettingsManager.set_value("controls", "invert_y", true, false)
	SettingsManager.set_value("gameplay", "fov", 82.0, false)
	assert_eq(SettingsManager.save_settings(_settings_path), OK)
	SettingsManager.reset_to_defaults(false)
	assert_almost_eq(SettingsManager.get_float("controls", "mouse_sensitivity"), 1.0, 0.001)
	SettingsManager.load_settings(_settings_path)
	assert_almost_eq(SettingsManager.get_float("controls", "mouse_sensitivity"), 1.7, 0.001)
	assert_true(SettingsManager.get_bool("controls", "invert_y"))
	assert_almost_eq(SettingsManager.get_float("gameplay", "fov"), 82.0, 0.001)


func test_environment_effects_follow_preset_but_never_exceed_level() -> void:
	var environment := Environment.new()
	environment.volumetric_fog_enabled = true
	environment.ssao_enabled = true
	environment.ssr_enabled = false
	environment.glow_enabled = true
	SettingsManager.apply_graphics_preset("high", false)
	SettingsManager.register_world(environment)
	assert_true(environment.volumetric_fog_enabled)
	assert_false(environment.ssr_enabled, "preset must not enable an effect the level did not use")
	SettingsManager.apply_graphics_preset("low", false)
	assert_false(environment.volumetric_fog_enabled)
	assert_false(environment.ssao_enabled)
	SettingsManager.unregister_world(environment)


func test_save_round_trip_restores_game_state() -> void:
	SaveManager.save_dir = SCRATCH_DIR
	GameState.current_area = "dead_city"
	GameState.checkpoint_id = "pharmacy_roof"
	GameState.max_health = 120.0
	GameState.health = 77.0
	GameState.injectors = 2
	GameState.salvage = 345
	GameState.weapons = {"rebar_pipe": 2, "fire_axe": 1}
	GameState.equipped_weapon = "fire_axe"
	GameState.set_flag("tower_power_restored")
	GameState.collected_documents = ["doc_city_01", "doc_city_04"]
	var before: Dictionary = GameState.to_dict()
	assert_eq(SaveManager.save_game("slot1"), OK)
	GameState.reset()
	assert_eq(GameState.salvage, 0)
	assert_eq(SaveManager.load_game("slot1"), OK)
	assert_eq(GameState.to_dict(), before)
	assert_true(GameState.has_flag("tower_power_restored"))


func test_loading_missing_slot_fails_cleanly() -> void:
	SaveManager.save_dir = SCRATCH_DIR
	assert_eq(SaveManager.load_game("slot3"), ERR_FILE_NOT_FOUND)
	assert_false(SaveManager.has_save("slot3"))


func test_corrupt_save_falls_back_to_backup() -> void:
	SaveManager.save_dir = SCRATCH_DIR
	GameState.salvage = 10
	SaveManager.save_game("slot2")
	GameState.salvage = 20
	SaveManager.save_game("slot2")
	var file := FileAccess.open(SCRATCH_DIR + "/slot2.json", FileAccess.WRITE)
	file.store_string("{ this is not valid json")
	file.close()
	GameState.reset()
	assert_eq(SaveManager.load_game("slot2"), OK)
	assert_eq(GameState.salvage, 10, "backup holds the previous good save")
	assert_engine_error_count(0)


func test_no_temp_file_left_after_save() -> void:
	SaveManager.save_dir = SCRATCH_DIR
	SaveManager.save_game("slot1")
	assert_false(FileAccess.file_exists(SCRATCH_DIR + "/slot1.json.tmp"))
	assert_true(FileAccess.file_exists(SCRATCH_DIR + "/slot1.json"))


func test_most_recent_slot_drives_continue() -> void:
	SaveManager.save_dir = SCRATCH_DIR
	assert_eq(SaveManager.get_most_recent_slot(), "")
	SaveManager.write_slot("slot1", {"version": 1, "saved_at_unix": 100})
	SaveManager.write_slot("autosave", {"version": 1, "saved_at_unix": 300})
	SaveManager.write_slot("slot2", {"version": 1, "saved_at_unix": 200})
	assert_eq(SaveManager.get_most_recent_slot(), "autosave")


func test_old_settings_file_gets_the_current_preset_values() -> void:
	# A file written by an early build: names the High preset but has no resolution cap.
	var path: String = "user://test_old_settings.cfg"
	var config := ConfigFile.new()
	config.set_value("graphics", "preset", "high")
	config.set_value("graphics", "render_scale", 1.0)
	config.save(path)
	SettingsManager.reset_to_defaults(false)
	assert_eq(int(SettingsManager.get_value("graphics", "max_render_height")), 1080, "Medium by default")
	SettingsManager.load_settings(path)
	assert_eq(int(SettingsManager.get_value("graphics", "max_render_height")), 1600, "High's own cap, not Medium's")
	assert_eq(int(SettingsManager.get_value("graphics", "shadow_cascades")), 4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SettingsManager.reset_to_defaults(false)
