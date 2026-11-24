extends Node
## Loads, stores and applies user settings: graphics, audio, controls, gameplay.
##
## Settings persist in user://settings.cfg, separately from save games.
## Graphics presets are data (res://data/graphics_presets.json); choosing a preset
## copies its values into the "graphics" section, after which any single value
## can still be overridden (the preset then reads as "custom").

signal changed(section: String, key: String, value: Variant)
signal graphics_applied

const SETTINGS_PATH: String = "user://settings.cfg"
const PRESETS_PATH: String = "res://data/graphics_presets.json"
const PRESET_NAMES: PackedStringArray = ["low", "medium", "high"]
const DEFAULT_PRESET: String = "medium"

const DEFAULTS: Dictionary = {
	"graphics": {
		"preset": DEFAULT_PRESET,
		"fullscreen": true,
		"vsync": true,
		"fps_limit": 60,
		"show_fps": false,
		"film_look": true,
		"auto_detected": false,
	},
	"audio": {
		"master": 1.0,
		"music": 0.8,
		"sfx": 1.0,
		"ambience": 0.9,
		"dialogue": 1.0,
		"subtitles": true,
		"subtitle_size": 1.0,
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"controller_sensitivity": 1.0,
		"invert_y": false,
		"toggle_sprint": false,
		"toggle_crouch": true,
		"double_tap_dodge": true,
		"toggle_block": false,
	},
	"gameplay": {
		"difficulty": "normal",
		"camera_shake": true,
		"objective_markers": true,
		"fov": 70.0,
		"hud_fade_seconds": 6.0,
	},
	"progress": {
		"game_complete": false,
		"ng_plus_carry": {},
	},
	"accessibility": {
		"subtitle_background": true,
		"high_contrast_cues": false,
		"reduce_flashing": false,
	},
}

var _values: Dictionary = {}
var _presets: Dictionary = {}
var _auto_detect_rules: Dictionary = {}
var _environment: Environment
var _environment_base: Dictionary = {}
var _sun: DirectionalLight3D
var _is_headless: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_headless = DisplayServer.get_name() == "headless"
	_presets = _load_presets()
	_values = DEFAULTS.duplicate(true)
	_copy_preset_into_values(DEFAULT_PRESET)
	load_settings()
	apply_all()
	get_tree().root.size_changed.connect(_on_window_resized)


# --- Access -----------------------------------------------------------------

func get_value(section: String, key: String) -> Variant:
	var section_values: Dictionary = _values.get(section, {})
	return section_values.get(key)


func get_section(section: String) -> Dictionary:
	return _values.get(section, {})


func get_float(section: String, key: String) -> float:
	return float(get_value(section, key))


func get_bool(section: String, key: String) -> bool:
	return bool(get_value(section, key))


## Sets one value, applies it, and (by default) writes settings to disk.
func set_value(section: String, key: String, value: Variant, persist: bool = true) -> void:
	if not _values.has(section):
		_values[section] = {}
	if _values[section].get(key) == value:
		return
	_values[section][key] = value
	if section == "graphics" and key != "preset" and _presets.get(DEFAULT_PRESET, {}).has(key):
		_values["graphics"]["preset"] = "custom"
	_apply_section(section)
	changed.emit(section, key, value)
	if persist:
		save_settings()


## Thresholds for the first-launch benchmark (see "_auto_detect" in the presets file).
func get_auto_detect_rules() -> Dictionary:
	return _auto_detect_rules


func get_preset_names() -> PackedStringArray:
	return PRESET_NAMES


func get_preset_values(preset: String) -> Dictionary:
	return _presets.get(preset, {})


## Applies a named graphics preset (low / medium / high).
func apply_graphics_preset(preset: String, persist: bool = true) -> void:
	if not _presets.has(preset):
		push_warning("Unknown graphics preset: %s" % preset)
		return
	_copy_preset_into_values(preset)
	apply_graphics()
	changed.emit("graphics", "preset", preset)
	if persist:
		save_settings()


## Levels call this so presets can switch environment effects and sun shadows.
## The environment's authored state is remembered: presets only ever turn
## effects off or adjust quality, never enable something the level did not use.
func register_world(environment: Environment, sun: DirectionalLight3D = null) -> void:
	_environment = environment
	_sun = sun
	_environment_base = {}
	if environment != null:
		_environment_base = {
			"volumetric_fog": environment.volumetric_fog_enabled,
			"ssao": environment.ssao_enabled,
			"ssr": environment.ssr_enabled,
			"glow": environment.glow_enabled,
			"fog_density": environment.fog_density,
		}
	_apply_environment()
	graphics_applied.emit()


func unregister_world(environment: Environment) -> void:
	if _environment == environment:
		_environment = null
		_sun = null


## True when the current preset keeps volumetric fog on (levels thicken plain fog otherwise).
func is_volumetric_fog_active() -> bool:
	return int(get_value("graphics", "volumetric_fog")) > 0 and bool(_environment_base.get("volumetric_fog", false))


# --- Persistence ------------------------------------------------------------

func load_settings(path: String = SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for section: String in config.get_sections():
		if not _values.has(section):
			_values[section] = {}
		for key: String in config.get_section_keys(section):
			_values[section][key] = config.get_value(section, key)
	# A named preset always means that preset's current values. A settings file
	# saved by an older build can lack newer keys (or hold old numbers), which
	# would otherwise leave, say, High running at Medium's resolution cap.
	var saved_preset: String = str(_values["graphics"].get("preset", DEFAULT_PRESET))
	if _presets.has(saved_preset):
		_copy_preset_into_values(saved_preset)


func save_settings(path: String = SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	for section: String in _values:
		for key: String in _values[section]:
			config.set_value(section, key, _values[section][key])
	return config.save(path)


func reset_to_defaults(persist: bool = true) -> void:
	_values = DEFAULTS.duplicate(true)
	_copy_preset_into_values(DEFAULT_PRESET)
	apply_all()
	if persist:
		save_settings()


# --- Applying ---------------------------------------------------------------

func apply_all() -> void:
	apply_graphics()
	_apply_audio()


func _apply_section(section: String) -> void:
	match section:
		"graphics":
			apply_graphics()
		"audio":
			_apply_audio()


func apply_graphics() -> void:
	var viewport: Viewport = get_tree().root
	Engine.max_fps = int(get_value("graphics", "fps_limit"))

	if not _is_headless:
		var wants_fullscreen: bool = get_bool("graphics", "fullscreen")
		var mode: DisplayServer.WindowMode = (
				DisplayServer.WINDOW_MODE_FULLSCREEN if wants_fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)
		var current: DisplayServer.WindowMode = DisplayServer.window_get_mode()
		var is_fullscreen_now: bool = (
				current == DisplayServer.WINDOW_MODE_FULLSCREEN
				or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		if wants_fullscreen != is_fullscreen_now:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if get_bool("graphics", "vsync")
				else DisplayServer.VSYNC_DISABLED)

	var scale: float = get_effective_render_scale()
	viewport.scaling_3d_scale = scale
	viewport.scaling_3d_mode = _resolve_upscaler(str(get_value("graphics", "upscaler")), scale)
	viewport.fsr_sharpness = 0.35
	match str(get_value("graphics", "antialiasing")):
		"smaa":
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		"fxaa":
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		_:
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = int(get_value("graphics", "positional_shadow_atlas"))

	RenderingServer.directional_shadow_atlas_set_size(int(get_value("graphics", "shadow_size")), true)
	var soft: int = int(get_value("graphics", "soft_shadows"))
	RenderingServer.directional_soft_shadow_filter_set_quality(soft as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft as RenderingServer.ShadowQuality)

	_apply_environment()
	graphics_applied.emit()


## The 3D render scale actually used: the preset's scale, lowered if needed so
## the 3D image is never taller than max_render_height pixels. Retina displays
## have far more pixels than the GPU can shade at 60 FPS with these effects.
func get_effective_render_scale() -> float:
	var scale: float = clampf(get_float("graphics", "render_scale"), 0.4, 1.0)
	var cap: Variant = get_value("graphics", "max_render_height")
	var window_height: int = get_tree().root.size.y
	if cap != null and float(cap) > 0.0 and window_height > 0:
		scale = minf(scale, float(cap) / float(window_height))
	return clampf(scale, 0.35, 1.0)


func _on_window_resized() -> void:
	var viewport: Viewport = get_tree().root
	var scale: float = get_effective_render_scale()
	if not is_equal_approx(scale, viewport.scaling_3d_scale):
		viewport.scaling_3d_scale = scale
		viewport.scaling_3d_mode = _resolve_upscaler(str(get_value("graphics", "upscaler")), scale)


func _resolve_upscaler(choice: String, scale: float) -> Viewport.Scaling3DMode:
	if scale >= 0.99:
		return Viewport.SCALING_3D_MODE_BILINEAR
	match choice:
		"bilinear":
			return Viewport.SCALING_3D_MODE_BILINEAR
		"fsr1":
			return Viewport.SCALING_3D_MODE_FSR
		"fsr2":
			return Viewport.SCALING_3D_MODE_FSR2
		"metalfx_spatial":
			return Viewport.SCALING_3D_MODE_METALFX_SPATIAL
		_:
			# "auto": MetalFX Spatial is the cheap, sharp option on Apple GPUs.
			if RenderingServer.get_current_rendering_driver_name() == "metal":
				return Viewport.SCALING_3D_MODE_METALFX_SPATIAL
			return Viewport.SCALING_3D_MODE_FSR


func _apply_environment() -> void:
	if _sun != null:
		var cascades: int = int(get_value("graphics", "shadow_cascades"))
		_sun.directional_shadow_mode = (
				DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if cascades >= 4
				else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
		_sun.directional_shadow_max_distance = get_float("graphics", "shadow_distance")
	if _environment == null:
		return

	var fog_level: int = int(get_value("graphics", "volumetric_fog"))
	var fog_on: bool = fog_level > 0 and bool(_environment_base.get("volumetric_fog", false))
	_environment.volumetric_fog_enabled = fog_on
	if fog_on:
		var size: int = 64 if fog_level == 1 else 96
		RenderingServer.environment_set_volumetric_fog_volume_size(size, size)
		RenderingServer.environment_set_volumetric_fog_filter_active(true)
	# Without volumetrics, plain depth fog carries the atmosphere instead.
	var base_density: float = float(_environment_base.get("fog_density", _environment.fog_density))
	_environment.fog_density = base_density if fog_on else base_density * 2.5

	var ssao_level: int = int(get_value("graphics", "ssao"))
	_environment.ssao_enabled = ssao_level > 0 and bool(_environment_base.get("ssao", false))
	if _environment.ssao_enabled:
		RenderingServer.environment_set_ssao_quality(
				RenderingServer.ENV_SSAO_QUALITY_LOW if ssao_level == 1 else RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
				ssao_level == 1, 0.5, 2, 50.0, 300.0)

	var ssr_level: int = int(get_value("graphics", "ssr"))
	_environment.ssr_enabled = ssr_level > 0 and bool(_environment_base.get("ssr", false))
	if _environment.ssr_enabled:
		RenderingServer.environment_set_ssr_half_size(ssr_level == 1)
		_environment.ssr_max_steps = 32 if ssr_level == 1 else 64

	var glow_level: int = int(get_value("graphics", "glow"))
	_environment.glow_enabled = glow_level > 0 and bool(_environment_base.get("glow", false))
	RenderingServer.environment_glow_set_use_bicubic_upscale(glow_level >= 2)


## Extra dB per bus on top of the player's volume (ambience ducks under cinematics).
var bus_offsets: Dictionary = {}


func set_bus_offset(bus_name: String, db: float) -> void:
	bus_offsets[bus_name] = db
	_apply_audio()


func _apply_audio() -> void:
	for bus_name: String in ["master", "music", "sfx", "ambience", "dialogue"]:
		var index: int = AudioServer.get_bus_index(bus_name.capitalize())
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(get_float("audio", bus_name), 0.0001)) + float(bus_offsets.get(bus_name, 0.0)))


# --- Helpers ----------------------------------------------------------------

func _copy_preset_into_values(preset: String) -> void:
	var preset_values: Dictionary = _presets.get(preset, {})
	for key: String in preset_values:
		if key.begins_with("_"):
			continue
		_values["graphics"][key] = preset_values[key]
	_values["graphics"]["preset"] = preset


func _load_presets() -> Dictionary:
	var file := FileAccess.open(PRESETS_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing graphics presets at %s" % PRESETS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var result: Dictionary = parsed
		result.erase("_comment")
		_auto_detect_rules = result.get("_auto_detect", {})
		result.erase("_auto_detect")
		return result
	push_error("Graphics presets JSON is malformed")
	return {}
