class_name SettingsPanel
extends VBoxContainer
## The full settings screen, shared by the main menu and the pause menu:
## Graphics, Audio, Controls (with key rebinding) and Gameplay. Every control
## writes straight to SettingsManager, which applies and saves it.

const TABS: PackedStringArray = ["Graphics", "Audio", "Controls", "Gameplay", "Access"]

var current_tab: String = "Graphics"

var _tab_buttons: Dictionary = {}
var _content: VBoxContainer
var _listening_action: String = ""
var _listening_button: Button
## True when the action being rebound is a controller button.
var _listening_pad: bool = false


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 8)
	for tab: String in TABS:
		var tab_button: Button = UIKit.button(tab, show_tab.bind(tab), false)
		tab_button.toggle_mode = true
		tab_button.custom_minimum_size.x = 140
		tabs.add_child(tab_button)
		_tab_buttons[tab] = tab_button
	add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 9)
	scroll.add_child(_content)
	SettingsManager.changed.connect(_on_setting_changed)
	show_tab(current_tab)


func show_tab(tab: String) -> void:
	current_tab = tab
	_listening_action = ""
	for name_key: String in _tab_buttons:
		(_tab_buttons[name_key] as Button).button_pressed = name_key == tab
	UIKit.clear(_content)
	match tab:
		"Graphics":
			_build_graphics()
		"Audio":
			_build_audio()
		"Controls":
			_build_controls()
		"Access":
			_build_accessibility()
		_:
			_build_gameplay()


func focus_first() -> void:
	(_tab_buttons[current_tab] as Button).grab_focus()


func is_listening() -> bool:
	return not _listening_action.is_empty()


func _input(event: InputEvent) -> void:
	if _listening_action.is_empty() or not is_visible_in_tree():
		return
	var is_key: bool = event is InputEventKey and event.is_pressed() and not event.is_echo()
	var is_mouse: bool = event is InputEventMouseButton and event.is_pressed()
	var is_pad: bool = event is InputEventJoypadButton and event.is_pressed()
	var cancel: bool = is_key and (event as InputEventKey).physical_keycode == KEY_ESCAPE
	if _listening_pad:
		if not is_pad and not cancel:
			return
	elif not is_key and not is_mouse:
		return
	get_viewport().set_input_as_handled()
	if not cancel:
		if _listening_pad:
			InputSetup.rebind_pad(_listening_action, event)
		else:
			InputSetup.rebind(_listening_action, event)
	_listening_action = ""
	show_tab.call_deferred("Controls")


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	# Picking a preset (or leaving one by changing a value) changes what the other rows show.
	if section == "graphics" and key == "preset" and current_tab == "Graphics" and is_inside_tree():
		show_tab.call_deferred("Graphics")


# --- Tabs ---------------------------------------------------------------------------

func _build_graphics() -> void:
	var preset := OptionButton.new()
	var names: PackedStringArray = SettingsManager.get_preset_names()
	for preset_name: String in names:
		preset.add_item(preset_name.capitalize())
	preset.add_item("Custom")
	preset.set_item_disabled(names.size(), true)
	var current: String = str(SettingsManager.get_value("graphics", "preset"))
	preset.select(names.find(current) if names.has(current) else names.size())
	preset.item_selected.connect(func(index: int) -> void:
		if index < names.size():
			SettingsManager.apply_graphics_preset(names[index]))
	_content.add_child(UIKit.row("Quality preset", preset))
	var scale: int = roundi(SettingsManager.get_effective_render_scale() * 100.0)
	var notes: Dictionary = {
		"low": "Lowest load: %d%% resolution, no volumetric fog or reflections." % scale,
		"medium": "Recommended for MacBook Air: %d%% resolution, upscaled. Measured at over 100 FPS in the Dead City." % scale,
		"high": "%d%% resolution and the heaviest effects. About 46 FPS on a MacBook Air M4: meant for short sessions or faster Macs." % scale,
	}
	_content.add_child(UIKit.note(str(notes.get(current, "Custom settings: %d%% resolution." % scale))))
	_content.add_child(UIKit.section("Resolution"))
	_content.add_child(UIKit.row("3D render scale", UIKit.slider("graphics", "render_scale", 0.5, 1.0, 0.05, true)))
	_content.add_child(UIKit.row("Maximum 3D height", UIKit.option("graphics", "max_render_height",
			[["720", 720], ["900", 900], ["1080", 1080], ["1260", 1260], ["1440", 1440], ["1600", 1600], ["2160", 2160]])))
	_content.add_child(UIKit.row("Upscaler", UIKit.option("graphics", "upscaler", [["Automatic (MetalFX / FSR)", "auto"], ["Off (bilinear)", "bilinear"]])))
	_content.add_child(UIKit.section("Effects"))
	_content.add_child(UIKit.row("Shadow resolution", UIKit.option("graphics", "shadow_size", [["1024", 1024], ["2048", 2048], ["4096", 4096]])))
	_content.add_child(UIKit.row("Volumetric fog", UIKit.option("graphics", "volumetric_fog", [["Off", 0], ["Low", 1], ["Medium", 2]])))
	_content.add_child(UIKit.row("Ambient occlusion", UIKit.option("graphics", "ssao", [["Off", 0], ["Half resolution", 1], ["Full resolution", 2]])))
	_content.add_child(UIKit.row("Reflections", UIKit.option("graphics", "ssr", [["Off", 0], ["Low", 1], ["Medium", 2]])))
	_content.add_child(UIKit.row("Foliage density (next load)", UIKit.slider("graphics", "foliage_density", 0.25, 1.0, 0.05, true)))
	_content.add_child(UIKit.row("View distance", UIKit.slider("graphics", "view_distance", 80.0, 320.0, 10.0)))
	_content.add_child(UIKit.section("Display"))
	_content.add_child(UIKit.row("Fullscreen", UIKit.toggle("graphics", "fullscreen")))
	_content.add_child(UIKit.row("VSync", UIKit.toggle("graphics", "vsync")))
	_content.add_child(UIKit.row("Frame rate limit", UIKit.option("graphics", "fps_limit", [["30", 30], ["60", 60], ["120", 120], ["Unlimited", 0]])))
	_content.add_child(UIKit.row("Film look (vignette, grain, hurt edge)", UIKit.toggle("graphics", "film_look")))
	_content.add_child(UIKit.row("Show FPS", UIKit.toggle("graphics", "show_fps")))


func _build_audio() -> void:
	for entry: Array in [["Master volume", "master"], ["Music", "music"], ["Sound effects", "sfx"], ["Ambience", "ambience"], ["Dialogue", "dialogue"]]:
		_content.add_child(UIKit.row(str(entry[0]), UIKit.slider("audio", str(entry[1]), 0.0, 1.0, 0.05, true)))
	_content.add_child(UIKit.section("Subtitles"))
	_content.add_child(UIKit.row("Subtitles", UIKit.toggle("audio", "subtitles")))
	_content.add_child(UIKit.row("Subtitle size", UIKit.slider("audio", "subtitle_size", 0.8, 1.6, 0.1, true)))


func _build_controls() -> void:
	_content.add_child(UIKit.row("Mouse sensitivity", UIKit.slider("controls", "mouse_sensitivity", 0.2, 3.0, 0.05)))
	_content.add_child(UIKit.row("Controller sensitivity", UIKit.slider("controls", "controller_sensitivity", 0.2, 3.0, 0.05)))
	_content.add_child(UIKit.row("Invert vertical look", UIKit.toggle("controls", "invert_y")))
	_content.add_child(UIKit.row("Sprint: press once to toggle", UIKit.toggle("controls", "toggle_sprint")))
	_content.add_child(UIKit.row("Crouch: press once to toggle", UIKit.toggle("controls", "toggle_crouch")))
	_content.add_child(UIKit.row("Block: press once to toggle", UIKit.toggle("controls", "toggle_block")))
	_content.add_child(UIKit.row("Double-tap a direction to dodge", UIKit.toggle("controls", "double_tap_dodge")))
	_content.add_child(UIKit.section("Keyboard and mouse"))
	_content.add_child(UIKit.note("Select an action, then press the new key or mouse button. Esc cancels."))
	for action: String in InputSetup.REBINDABLE:
		var bind_button: Button = UIKit.button(InputSetup.get_action_label(action), Callable(), false)
		bind_button.pressed.connect(_listen.bind(action, bind_button))
		bind_button.name = "Bind_" + action
		_content.add_child(UIKit.row(str(InputSetup.REBINDABLE[action]), bind_button, 220.0))
	_content.add_child(UIKit.section("Controller"))
	_content.add_child(UIKit.note("Select an action, then press the new controller button. Esc cancels. Sticks and triggers are fixed."))
	for action: String in InputSetup.PAD_REBINDABLE:
		var pad_button: Button = UIKit.button(InputSetup.get_pad_label(action), Callable(), false)
		pad_button.pressed.connect(_listen.bind(action, pad_button, true))
		pad_button.name = "Pad_" + action
		_content.add_child(UIKit.row(str(InputSetup.PAD_REBINDABLE[action]), pad_button, 220.0))
	_content.add_child(UIKit.spacer(6))
	_content.add_child(UIKit.button("Reset all bindings to defaults", func() -> void:
		InputSetup.reset_bindings()
		show_tab.call_deferred("Controls")))


func _build_gameplay() -> void:
	_content.add_child(UIKit.row("Difficulty", UIKit.option("gameplay", "difficulty", [["Story", "story"], ["Normal", "normal"], ["Hard", "hard"]])))
	_content.add_child(UIKit.note("Story: enemies hit softer and the parry window is wider. Hard: enemies hit harder."))
	_content.add_child(UIKit.row("Objective markers", UIKit.toggle("gameplay", "objective_markers")))
	_content.add_child(UIKit.row("Camera shake", UIKit.toggle("gameplay", "camera_shake")))
	_content.add_child(UIKit.row("Field of view", UIKit.slider("gameplay", "fov", 60.0, 90.0, 1.0)))
	_content.add_child(UIKit.row("Hide health panel when idle", UIKit.option("gameplay", "hud_fade_seconds",
			[["Never", 0.0], ["After 4 s", 4.0], ["After 6 s", 6.0], ["After 10 s", 10.0]])))


func _build_accessibility() -> void:
	_content.add_child(UIKit.section("Subtitles"))
	_content.add_child(UIKit.row("Subtitles", UIKit.toggle("audio", "subtitles")))
	_content.add_child(UIKit.row("Subtitle size", UIKit.slider("audio", "subtitle_size", 0.8, 1.6, 0.1, true)))
	_content.add_child(UIKit.row("Dark panel behind subtitles", UIKit.toggle("accessibility", "subtitle_background")))
	_content.add_child(UIKit.section("Vision"))
	_content.add_child(UIKit.row("High-contrast danger cues", UIKit.toggle("accessibility", "high_contrast_cues")))
	_content.add_child(UIKit.note("Attack warnings, camera cones and the Choir's attacks turn yellow and magenta instead of orange and red."))
	_content.add_child(UIKit.row("Reduce flashing", UIKit.toggle("accessibility", "reduce_flashing")))
	_content.add_child(UIKit.note("No lightning flashes, hit flashes, flickering lights or strobing emergency lights."))
	_content.add_child(UIKit.row("Camera shake", UIKit.toggle("gameplay", "camera_shake")))
	_content.add_child(UIKit.section("Controls"))
	_content.add_child(UIKit.row("Sprint: press once to toggle", UIKit.toggle("controls", "toggle_sprint")))
	_content.add_child(UIKit.row("Crouch: press once to toggle", UIKit.toggle("controls", "toggle_crouch")))
	_content.add_child(UIKit.row("Block: press once to toggle", UIKit.toggle("controls", "toggle_block")))
	_content.add_child(UIKit.row("Difficulty", UIKit.option("gameplay", "difficulty", [["Story", "story"], ["Normal", "normal"], ["Hard", "hard"]])))


func _listen(action: String, bind_button: Button, pad: bool = false) -> void:
	_listening_action = action
	_listening_button = bind_button
	_listening_pad = pad
	bind_button.text = "Press a button…" if pad else "Press a key…"
