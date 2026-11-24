class_name HUD
extends CanvasLayer
## In-game overlay: health, stamina, injectors, weapon, enemy health and
## detection markers, interaction prompt, lock-on reticle, toasts, a title
## card and the controls cheat sheet. Objectives join it in Milestone 4.

const HELP_LINES: Array[Array] = [
	["WASD", "Move"],
	["Mouse", "Look"],
	["Shift", "Sprint"],
	["X", "Walk (hold)"],
	["Space", "Jump · vault · climb up"],
	["C / Ctrl", "Crouch · drop from ledge"],
	["LMB / RMB", "Light attack · heavy (hold to charge)"],
	["Q", "Block (tap just before a hit to parry)"],
	["F or Alt", "Dodge"],
	["1 2 3 / Wheel", "Switch weapon"],
	["G", "Throw bottle (distraction)"],
	["H", "Heal (injector)"],
	["E", "Interact · takedown from behind"],
	["Tab", "Lock-on"],
	["Esc", "Pause · settings · benchmark"],
	["F3 or `", "Performance overlay"],
	["F1 or /", "Show / hide this list"],
]

var _root: Control
var _stamina: StaminaBar
var _prompt: Label
var _prompt_panel: PanelContainer
var _toast: Label
var _toast_time: float = 0.0
var _death_shown: bool = false
var _help: PanelContainer
var _help_time: float = 0.0
var _title: Control
var _title_time: float = 0.0
var _title_heading: Label
var _title_sub: Label
var _reticle: LockOnReticle
var _fps_label: Label
var _vitals: Vitals
var _markers: WorldMarkers
var _death: Label
## Seconds since anything on the health panel changed or a fight was on.
var _vitals_idle: float = 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)

	_reticle = LockOnReticle.new()
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_reticle)

	_markers = WorldMarkers.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_markers)

	_vitals = Vitals.new()
	_vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_vitals.position = Vector2(64, -192)
	_vitals.custom_minimum_size = Vector2(420, 76)
	_vitals.size = Vector2(420, 76)
	_root.add_child(_vitals)

	_death = UIStyle.label("SILENCED", 96, UIStyle.DANGER, true)
	_death.set_anchors_preset(Control.PRESET_CENTER)
	_death.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.modulate.a = 0.0
	_root.add_child(_death)

	_stamina = StaminaBar.new()
	_stamina.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stamina.position = Vector2(64, -92)
	_stamina.custom_minimum_size = Vector2(360, 34)
	_stamina.size = Vector2(360, 34)
	_root.add_child(_stamina)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override(&"panel", UIStyle.panel_box(UIStyle.PANEL_SOFT))
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.position.y = -210
	_prompt_panel.visible = false
	_prompt = UIStyle.label("", 26, UIStyle.TEXT, true)
	_prompt_panel.add_child(_prompt)
	_root.add_child(_prompt_panel)

	_toast = UIStyle.label("", 26, UIStyle.ECHO, true)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position.y = 120
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	_fps_label = UIStyle.label("", 18, UIStyle.TEXT_DIM)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps_label.position = Vector2(-28, 20)
	_root.add_child(_fps_label)

	_build_help()
	_build_title()

	EventBus.stamina_changed.connect(_stamina.set_values)
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.toast_requested.connect(show_toast)
	EventBus.lock_on_changed.connect(_reticle.set_target)
	EventBus.health_changed.connect(_vitals.set_health)
	EventBus.injectors_changed.connect(_vitals.set_injectors)
	EventBus.throwables_changed.connect(_vitals.set_throwables)
	EventBus.weapon_changed.connect(_vitals.set_weapon)
	EventBus.player_died.connect(func() -> void: _death_shown = true)
	EventBus.player_respawned.connect(func() -> void: _death_shown = false)
	EventBus.area_title_requested.connect(show_title)
	EventBus.cinematic_changed.connect(func(is_playing: bool) -> void: set_hud_visible(not is_playing))
	for bus_signal: Signal in [EventBus.health_changed, EventBus.injectors_changed, EventBus.throwables_changed]:
		bus_signal.connect(func(_a: Variant, _b: Variant) -> void: wake_vitals())
	for bus_signal: Signal in [EventBus.weapon_changed, EventBus.lock_on_changed]:
		bus_signal.connect(func(_a: Variant) -> void: wake_vitals())


func _process(delta: float) -> void:
	_toast_time -= delta
	_toast.modulate.a = move_toward(_toast.modulate.a, 1.0 if _toast_time > 0.0 else 0.0, delta * 4.0)
	_death.modulate.a = move_toward(_death.modulate.a, 1.0 if _death_shown else 0.0, delta * (1.2 if _death_shown else 4.0))
	_help_time -= delta
	_help.modulate.a = move_toward(_help.modulate.a, 1.0 if _help_time > 0.0 else 0.0, delta * 3.0)
	_help.visible = _help.modulate.a > 0.01
	_title_time -= delta
	_title.modulate.a = move_toward(_title.modulate.a, 1.0 if _title_time > 0.0 else 0.0, delta * 1.2)
	_title.visible = _title.modulate.a > 0.01
	_update_vitals_fade(delta)
	_fps_label.visible = SettingsManager.get_bool("graphics", "show_fps")
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"help"):
		_help_time = 0.0 if _help_time > 0.0 else 600.0


func show_toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast_time = seconds


## Shows the health panel again at once (damage, healing, a weapon change...).
func wake_vitals() -> void:
	_vitals_idle = 0.0


func vitals_alpha() -> float:
	return _vitals.modulate.a


## The health panel fades out after a quiet spell (Gameplay > "Hide HUD when idle").
## It stays up during fights and while health is low.
func _update_vitals_fade(delta: float) -> void:
	_vitals_idle += delta
	if CombatDirector.engaged_count() > 0:
		_vitals_idle = 0.0
	var fade_after: float = float(SettingsManager.get_value("gameplay", "hud_fade_seconds"))
	var shown: bool = fade_after <= 0.0 or _vitals_idle < fade_after or _vitals.is_low()
	_vitals.modulate.a = move_toward(_vitals.modulate.a, 1.0 if shown else 0.0, delta * (5.0 if shown else 1.2))


## Hides everything (used while the benchmark or a screenshot tour runs).
func set_hud_visible(shown: bool) -> void:
	_root.visible = shown


## Shows the big title card for a few seconds (area name on arrival).
func show_title(heading: String, sub: String, seconds: float = 5.0) -> void:
	_title_heading.text = heading
	_title_sub.text = sub
	_title_time = seconds
	_help_time = 10.0


func hide_intro() -> void:
	_title_time = 0.0
	_help_time = 0.0
	_title.modulate.a = 0.0
	_help.modulate.a = 0.0


func _on_prompt_changed(text: String) -> void:
	_prompt.text = text
	_prompt_panel.visible = not text.is_empty()


func _build_help() -> void:
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override(&"panel", UIStyle.panel_box(UIStyle.PANEL_SOFT))
	_help.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.position = Vector2(-48, -56)
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.add_child(UIStyle.label("CONTROLS", 22, UIStyle.ECHO, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 26)
	grid.add_theme_constant_override(&"v_separation", 4)
	for line: Array in HELP_LINES:
		grid.add_child(UIStyle.label(line[0], 19, UIStyle.TEXT, true))
		grid.add_child(UIStyle.label(line[1], 19, UIStyle.TEXT_DIM))
	column.add_child(grid)
	column.add_child(UIStyle.label("A mouse or controller is recommended over the trackpad.", 15, UIStyle.TEXT_DIM))
	_help.add_child(column)
	_root.add_child(_help)


func _build_title() -> void:
	_title = VBoxContainer.new()
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.position.y = 150
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := UIStyle.label("GHOSTLINE", 84, UIStyle.TEXT, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UIStyle.label("", 26, UIStyle.ECHO, true)
	_title_heading = heading
	_title_sub = sub
	_title.modulate.a = 0.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_child(heading)
	_title.add_child(sub)
	_root.add_child(_title)


class Vitals:
	extends Control
	## Health bar with injector pips, plus the current weapon and bottle count.

	var _health: float = 1.0
	var _health_lag: float = 1.0
	var _injectors: int = 3
	var _injectors_max: int = 3
	var _throwables: int = 3
	var _weapon_name: String = ""

	func set_health(current: float, maximum: float) -> void:
		_health = current / maxf(maximum, 0.001)
		queue_redraw()

	func is_low() -> bool:
		return _health < 0.35

	func set_injectors(count: int, maximum: int) -> void:
		_injectors = count
		_injectors_max = maximum
		queue_redraw()

	func set_throwables(count: int, _maximum: int) -> void:
		_throwables = count
		queue_redraw()

	func set_weapon(weapon: Resource) -> void:
		var data: WeaponData = weapon as WeaponData
		_weapon_name = data.display_name.to_upper() if data != null else ""
		queue_redraw()

	func _process(delta: float) -> void:
		if absf(_health_lag - _health) > 0.001:
			_health_lag = move_toward(_health_lag, _health, delta * 0.45) if _health_lag > _health else _health
			queue_redraw()

	func _draw() -> void:
		var font: Font = UIStyle.heading_font()
		draw_string(font, Vector2(0, 16), _weapon_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.TEXT)
		draw_string(font, Vector2(size.x - 130, 16), "BOTTLES  %d" % _throwables, HORIZONTAL_ALIGNMENT_RIGHT, 130, 16,
				UIStyle.TEXT_DIM if _throwables > 0 else UIStyle.DANGER)
		var bar := Rect2(0, 30, size.x, 12)
		draw_rect(bar, Color(0, 0, 0, 0.5))
		# The pale trail shows health just lost.
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _health_lag, bar.size.y)), Color(UIStyle.TEXT, 0.45))
		var color: Color = UIStyle.DANGER if _health > 0.3 else UIStyle.WARNING
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _health, bar.size.y)), color)
		draw_rect(bar, UIStyle.LINE, false, 1.0)
		for i: int in _injectors_max:
			var pip := Rect2(i * 26.0, 52, 18, 18)
			if i < _injectors:
				draw_rect(pip, UIStyle.ECHO)
			else:
				draw_rect(pip, UIStyle.LINE, false, 1.5)
		draw_string(font, Vector2(_injectors_max * 26.0 + 8, 67), "INJECTORS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.TEXT_DIM)


class WorldMarkers:
	extends Control
	## Small markers above enemies: a detection meter while they are growing
	## suspicious, and a health bar once they are hurt or fighting.

	const MAX_DISTANCE: float = 32.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			return
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			var enemy: Enemy = node as Enemy
			if enemy == null or enemy.is_dead():
				continue
			var point: Vector3 = enemy.get_marker_point()
			if camera.is_position_behind(point) or camera.global_position.distance_to(point) > MAX_DISTANCE:
				continue
			var center: Vector2 = camera.unproject_position(point)
			var detection: float = enemy.perception.detection
			if enemy.is_aware() or enemy.health.get_ratio() < 0.999:
				_draw_health(center, enemy)
			elif detection > 0.02 or enemy.state == Enemy.AIState.SUSPICIOUS or enemy.state == Enemy.AIState.INVESTIGATE:
				_draw_detection(center, detection)

	func _draw_health(center: Vector2, enemy: Enemy) -> void:
		var width: float = 74.0 if enemy.data.max_health < 100.0 else 110.0
		var bar := Rect2(center.x - width * 0.5, center.y - 4.0, width, 6.0)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(width * enemy.health.get_ratio(), bar.size.y)), UIStyle.DANGER)
		if enemy.has_armor():
			var armor_ratio: float = clampf(enemy.armor_points / maxf(enemy.data.armor, 0.001), 0.0, 1.0)
			draw_rect(Rect2(bar.position + Vector2(0, -6), Vector2(width * armor_ratio, 4.0)), UIStyle.TEXT)
		draw_rect(bar, UIStyle.LINE, false, 1.0)

	## An eye-shaped meter: fills as the enemy notices Kael, with "?" then "!".
	func _draw_detection(center: Vector2, detection: float) -> void:
		var color: Color = UIStyle.TEXT.lerp(UIStyle.WARNING, clampf(detection * 1.4, 0.0, 1.0))
		var half := Vector2(20.0, 9.0)
		var outline: PackedVector2Array = [
			center + Vector2(-half.x, 0), center + Vector2(0, -half.y),
			center + Vector2(half.x, 0), center + Vector2(0, half.y), center + Vector2(-half.x, 0)]
		draw_polyline(outline, color, 2.0, true)
		var fill_half: Vector2 = half * clampf(detection, 0.0, 1.0)
		draw_colored_polygon([
			center + Vector2(-fill_half.x, 0), center + Vector2(0, -fill_half.y),
			center + Vector2(fill_half.x, 0), center + Vector2(0, fill_half.y)], color)
		draw_string(UIStyle.heading_font(), center + Vector2(-5, -16), "!" if detection > 0.7 else "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)


class StaminaBar:
	extends Control
	## A slim bar that appears while stamina is being spent or refilled.

	var _ratio: float = 1.0
	var _shown: float = 0.0
	var _idle: float = 10.0

	func set_values(current: float, maximum: float) -> void:
		var ratio: float = current / maxf(maximum, 0.001)
		if absf(ratio - _ratio) > 0.0005:
			_idle = 0.0
		_ratio = ratio

	func _process(delta: float) -> void:
		_idle += delta
		var target: float = 0.0 if (_ratio >= 0.999 and _idle > 1.2) else 1.0
		_shown = move_toward(_shown, target, delta * 3.0)
		modulate.a = _shown
		queue_redraw()

	func _draw() -> void:
		var bar := Rect2(0, 20, size.x, 8)
		draw_string(UIStyle.heading_font(), Vector2(0, 13), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIStyle.TEXT_DIM)
		draw_rect(bar, Color(0, 0, 0, 0.45))
		var color: Color = UIStyle.TEXT if _ratio > 0.22 else UIStyle.WARNING
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _ratio, bar.size.y)), color)
		draw_rect(bar, UIStyle.LINE, false, 1.0)


class LockOnReticle:
	extends Control
	## A small diamond drawn over the locked target.

	var _target: Node3D
	var _spin: float = 0.0

	func set_target(target: Node3D) -> void:
		_target = target
		queue_redraw()

	func _process(delta: float) -> void:
		if _target != null:
			_spin += delta
			queue_redraw()

	func _draw() -> void:
		if _target == null or not is_instance_valid(_target):
			return
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			return
		var point: Vector3 = CameraRig.get_lock_point(_target)
		if camera.is_position_behind(point):
			return
		var center: Vector2 = camera.unproject_position(point)
		var radius: float = 15.0 + sin(_spin * 4.0) * 1.5
		var corners: PackedVector2Array = [
			center + Vector2(0, -radius), center + Vector2(radius, 0),
			center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)]
		draw_polyline(corners, UIStyle.ECHO, 2.0, true)
		draw_circle(center, 2.5, UIStyle.ECHO)
