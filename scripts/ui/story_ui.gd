class_name StoryUI
extends CanvasLayer
## Story-facing interface: objective tracker, subtitles with speaker names,
## tutorial hints, cinematic letterbox and skip prompt, the document reader,
## the junction-panel puzzle and the end-of-act summary.
##
## Panels that need the mouse (document, puzzle, summary) pause the game and
## swallow input until they close.

signal puzzle_solved
signal summary_closed
signal credits_finished

## Seconds each credits page stays up (tests shorten it).
var credits_page_seconds: float = 6.5

const CREDIT_PAGES: Array = [
	"The Echo fell silent.\n\nA real silence, this time.",
	"\"...Kael? It's quiet. I can hear myself think.\nI can hear only myself.\"\n\n— last transmission, Meridian",
	"GHOSTLINE",
	"Design, code, story, level art and audio\nmade for this project\n\nStand-in characters: KayKit by Kay Lousberg (CC0)\nFonts: Inter, Rajdhani (SIL OFL)\nEngine: Godot (MIT)",
	"Thank you for playing.",
]
const EPILOGUE_PAGE: String = "Months later, on a rooftop radio in the Dead City,\na carrier wave. Then a voice, unhurried:\n\n\"Still here. Not anchored to anything now.\nGo and live, little brother. I'll find you.\""

const SPEAKER_COLORS: Dictionary = {
	"Kael": Color(0.92, 0.9, 0.86),
	"Oren": Color(1.0, 0.72, 0.4),
	"Lyra": Color(0.27, 0.92, 1.0),
}

var _root: Control
var _objective_box: VBoxContainer
var _objective: Label
var _side_objective: Label
var _subtitle_panel: PanelContainer
var _subtitle: RichTextLabel
var _subtitle_time: float = 0.0
var _queue: Array = []
var _hint_panel: PanelContainer
var _hint: Label
var _hint_time: float = 0.0
var _bars: Array[ColorRect] = []
var _bar_amount: float = 0.0
var _cinematic: bool = false
var _skip: Label
var _fade: ColorRect
var _fade_target: float = 0.0
var _fade_speed: float = 1.0
var _modal: Control
var _puzzle: JunctionPuzzle
var _puzzle_lamps: Array[Panel] = []
var _puzzle_status: Label
var _was_paused: bool = false
var _marker: Label
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _credits: Control
var _workbench_player: Player
## Set by the game so the skip prompt can show hold progress.
var cinematic_player: Cinematic


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN
		_root.add_child(bar)
		_bars.append(bar)

	_objective_box = VBoxContainer.new()
	_objective_box.position = Vector2(64, 56)
	_objective_box.add_theme_constant_override(&"separation", 2)
	_objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_box.add_child(UIStyle.label("OBJECTIVE", 16, UIStyle.ECHO, true))
	_objective = UIStyle.label("", 24, UIStyle.TEXT, true)
	_objective_box.add_child(_objective)
	_side_objective = UIStyle.label("", 18, UIStyle.TEXT_DIM)
	_objective_box.add_child(_side_objective)
	_objective_box.modulate.a = 0.0
	_root.add_child(_objective_box)

	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.add_theme_stylebox_override(&"panel", UIStyle.panel_box(UIStyle.PANEL_SOFT))
	_subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle_panel.position.y = -150
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle = RichTextLabel.new()
	_subtitle.bbcode_enabled = true
	_subtitle.fit_content = true
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(980, 0)
	_subtitle.scroll_active = false
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_font_override(&"normal_font", UIStyle.body_font())
	_subtitle.add_theme_font_override(&"bold_font", UIStyle.heading_font())
	_subtitle.add_theme_font_size_override(&"normal_font_size", 27)
	_subtitle.add_theme_font_size_override(&"bold_font_size", 27)
	_subtitle_panel.add_child(_subtitle)
	_subtitle_panel.modulate.a = 0.0
	_root.add_child(_subtitle_panel)

	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override(&"panel", UIStyle.panel_box(UIStyle.PANEL_SOFT))
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.position.y = 300
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = UIStyle.label("", 23, UIStyle.TEXT, true)
	_hint_panel.add_child(_hint)
	_hint_panel.modulate.a = 0.0
	_root.add_child(_hint_panel)

	_skip = UIStyle.label("", 18, UIStyle.TEXT_DIM, true)
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.position = Vector2(-48, -40)
	_skip.visible = false
	_root.add_child(_skip)

	_marker = UIStyle.label("", 20, UIStyle.TEXT, true)
	_marker.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_marker.add_theme_constant_override(&"outline_size", 6)
	_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker.visible = false
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_marker)
	_root.move_child(_marker, 1)

	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_boss_box.position.y = -64
	_boss_box.custom_minimum_size.x = 760
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name = UIStyle.label("", 24, UIStyle.TEXT, true)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.max_value = 1.0
	_boss_bar.value = 1.0
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(760, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIStyle.DANGER
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	_boss_bar.add_theme_stylebox_override(&"fill", fill)
	_boss_bar.add_theme_stylebox_override(&"background", back)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false
	_root.add_child(_boss_box)
	EventBus.boss_started.connect(func(boss_name: String) -> void:
		_boss_name.text = boss_name.to_upper()
		_boss_bar.value = 1.0
		_boss_box.visible = true)
	EventBus.boss_health_changed.connect(func(ratio: float) -> void: _boss_bar.value = ratio)
	EventBus.boss_ended.connect(func() -> void: _boss_box.visible = false)

	EventBus.workbench_used.connect(func(player: Node3D) -> void: show_workbench(player as Player))
	EventBus.dialogue_requested.connect(queue_lines)
	EventBus.hint_requested.connect(show_hint)
	EventBus.objective_changed.connect(set_objective)
	EventBus.cinematic_changed.connect(_on_cinematic_changed)
	EventBus.document_collected.connect(show_document)
	EventBus.fade_requested.connect(fade_to)
	EventBus.act_completed.connect(func(title: String, rows: Array) -> void: show_summary(title, "Act complete", rows))
	add_to_group(&"story_ui")


func _process(delta: float) -> void:
	# Subtitles: one line at a time from the queue.
	_subtitle_time -= delta
	if _subtitle_time <= 0.0 and not _queue.is_empty() and not get_tree().paused:
		_show_line(_queue.pop_front())
	var subtitles_on: bool = SettingsManager.get_bool("audio", "subtitles")
	_subtitle_panel.modulate.a = move_toward(_subtitle_panel.modulate.a,
			1.0 if _subtitle_time > 0.0 and subtitles_on else 0.0, delta * 5.0)
	_hint_time -= delta
	_hint_panel.modulate.a = move_toward(_hint_panel.modulate.a, 1.0 if _hint_time > 0.0 and not _cinematic else 0.0, delta * 3.0)
	_objective_box.modulate.a = move_toward(_objective_box.modulate.a,
			1.0 if not _objective.text.is_empty() and not _cinematic else 0.0, delta * 2.0)
	_bar_amount = move_toward(_bar_amount, 1.0 if _cinematic else 0.0, delta * 1.6)
	var bar_height: float = _root.size.y * 0.115 * smoothstep(0.0, 1.0, _bar_amount)
	for bar: ColorRect in _bars:
		bar.custom_minimum_size.y = bar_height
		bar.size.y = bar_height
		bar.visible = bar_height > 0.5
	_bars[1].position.y = _root.size.y - bar_height
	_fade.color.a = move_toward(_fade.color.a, _fade_target, delta * _fade_speed)
	_update_marker()
	_skip.visible = _cinematic
	if _cinematic:
		var progress: float = cinematic_player.skip_progress if cinematic_player != null else 0.0
		_skip.text = "Hold %s to skip %s" % [InputSetup.get_action_label("jump"), "·".repeat(int(progress * 8.0))]


func _input(event: InputEvent) -> void:
	if _modal == null:
		return
	# While a panel is open nothing reaches the game underneath.
	if event.is_action_pressed(&"pause") or (event.is_action_pressed(&"interact") and _puzzle == null and _workbench_player == null):
		_close_modal()
	if event is InputEventKey or event is InputEventJoypadButton:
		if _puzzle != null and event.is_pressed() and event is InputEventKey:
			var index: int = (event as InputEventKey).keycode - KEY_1
			if index >= 0 and index < _puzzle.relays.size():
				_press_breaker(index)
		if not (event.is_action(&"ui_accept") or event.is_action(&"ui_left") or event.is_action(&"ui_right")
				or event.is_action(&"ui_up") or event.is_action(&"ui_down") or event.is_action(&"ui_focus_next")):
			get_viewport().set_input_as_handled()


## The objective marker: a diamond and distance where the objective is, or
## pinned to the screen edge when it is off-screen or behind the camera.
var _ping_time: float = 0.0


## Hint key: the objective marker swells for a moment, so it is easy to find on screen.
func ping_marker() -> void:
	_ping_time = 2.5


func _update_marker() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var target: Variant = MissionManager.waypoint
	if (camera == null or not (target is Vector3) or _cinematic or _modal != null or get_tree().paused
			or not SettingsManager.get_bool("gameplay", "objective_markers") or _objective.text.is_empty()):
		_marker.visible = false
		return
	var point: Vector3 = target
	var distance: float = camera.global_position.distance_to(point)
	if distance < 2.5:
		_marker.visible = false
		return
	var screen: Vector2 = camera.unproject_position(point)
	var size: Vector2 = _root.size
	var margin := Vector2(70.0, 90.0)
	var behind: bool = camera.is_position_behind(point)
	if behind:
		# Mirror through the centre and push to the bottom edge so it reads as "turn round".
		screen = size - screen
		screen.y = size.y
	var clamped := Vector2(clampf(screen.x, margin.x, size.x - margin.x), clampf(screen.y, margin.y, size.y - margin.y))
	var off_screen: bool = behind or not clamped.is_equal_approx(screen)
	_marker.text = "%s\n%d m" % ["◇" if off_screen else "◆", roundi(distance)]
	_marker.modulate = Color(1.0, 1.0, 1.0, 0.55 if off_screen else 0.9)
	_ping_time = maxf(_ping_time - get_process_delta_time(), 0.0)
	var swell: float = 1.0 + 0.8 * _ping_time / 2.5 * absf(sin(_ping_time * 8.0))
	_marker.pivot_offset = _marker.size * 0.5
	_marker.scale = Vector2(swell, swell)
	if _ping_time > 0.0:
		_marker.modulate = Color(1.0, 0.85, 0.3, 1.0)
	_marker.visible = true
	_marker.position = clamped - _marker.size * 0.5


# --- Public API -----------------------------------------------------------------

func is_modal_open() -> bool:
	return _modal != null


func set_objective(text: String, side_text: String = "") -> void:
	_objective.text = text
	_side_objective.text = side_text
	_side_objective.visible = not side_text.is_empty()


func get_objective_text() -> String:
	return _objective.text


func show_hint(text: String, seconds: float = 6.0) -> void:
	_hint.text = text
	_hint_time = seconds


func queue_lines(lines: Array) -> void:
	_queue.append_array(lines)


func get_subtitle_text() -> String:
	return _subtitle.get_parsed_text() if _subtitle_time > 0.0 else ""


func clear_dialogue() -> void:
	_queue.clear()
	_subtitle_time = 0.0


## Fades the screen to black (amount 1) or back (amount 0).
func fade_to(amount: float, seconds: float = 1.0) -> void:
	_fade_target = amount
	_fade_speed = 1.0 / maxf(seconds, 0.01)
	if seconds <= 0.01:
		_fade.color.a = amount


func show_document(document: Dictionary) -> void:
	var column: VBoxContainer = _open_modal(Vector2(860, 0))
	column.add_child(UIStyle.label(str(document.get("kind", "Document")).to_upper(), 17, UIStyle.ECHO, true))
	column.add_child(UIStyle.label(str(document.get("title", "")), 34, UIStyle.TEXT, true))
	column.add_child(_spacer(8))
	var body := UIStyle.label(str(document.get("body", "")), 22, UIStyle.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(800, 0)
	column.add_child(body)
	column.add_child(_spacer(12))
	var footer: String = str(document.get("footer", ""))
	if not footer.is_empty():
		column.add_child(UIStyle.label(footer, 17, UIStyle.TEXT_DIM))
	var close := _button("Close   (%s)" % InputSetup.get_action_label("interact"), _close_modal)
	column.add_child(close)
	close.grab_focus()
	AudioManager.play_ui(&"page", -4.0)


## Opens the junction panel. Emits puzzle_solved when every relay is closed.
func show_puzzle(puzzle: JunctionPuzzle, hint: String = "") -> void:
	var column: VBoxContainer = _open_modal(Vector2(760, 0))
	_puzzle = puzzle
	_puzzle_lamps.clear()
	column.add_child(UIStyle.label("TOWER JUNCTION PANEL", 17, UIStyle.ECHO, true))
	column.add_child(UIStyle.label("Close every relay to route power to the mast", 28, UIStyle.TEXT, true))
	var note := UIStyle.label("Each breaker flips its own relay and the ones beside it."
			+ ("\n" + hint if not hint.is_empty() else ""), 19, UIStyle.TEXT_DIM)
	column.add_child(note)
	column.add_child(_spacer(10))
	var lamps := HBoxContainer.new()
	lamps.alignment = BoxContainer.ALIGNMENT_CENTER
	lamps.add_theme_constant_override(&"separation", 26)
	var breakers := HBoxContainer.new()
	breakers.alignment = BoxContainer.ALIGNMENT_CENTER
	breakers.add_theme_constant_override(&"separation", 26)
	for i: int in puzzle.relays.size():
		var lamp := Panel.new()
		lamp.custom_minimum_size = Vector2(96, 96)
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var state := UIStyle.label("", 20, UIStyle.TEXT, true)
		state.set_anchors_preset(Control.PRESET_FULL_RECT)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lamp.add_child(state)
		lamps.add_child(lamp)
		_puzzle_lamps.append(lamp)
		var breaker := _button("Breaker %d" % (i + 1), _press_breaker.bind(i))
		breaker.custom_minimum_size = Vector2(96, 52)
		breakers.add_child(breaker)
		if i == 0:
			breaker.grab_focus.call_deferred()
	column.add_child(lamps)
	column.add_child(breakers)
	column.add_child(_spacer(6))
	_puzzle_status = UIStyle.label("", 19, UIStyle.TEXT_DIM)
	_puzzle_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_puzzle_status)
	column.add_child(_button("Step away   (%s)" % InputSetup.get_action_label("pause"), _close_modal))
	_refresh_puzzle()


## The workbench: spend salvage on weapon tiers. Opens after Kael rests.
func show_workbench(player: Player) -> void:
	var column: VBoxContainer = _open_modal(Vector2(820, 0))
	_workbench_player = player
	column.add_child(UIStyle.label("WORKBENCH", 17, UIStyle.ECHO, true))
	column.add_child(UIStyle.label("Rested. Progress saved.", 34, UIStyle.TEXT, true))
	column.add_child(UIStyle.label("Health and injectors refilled. The district's enemies have returned.", 19, UIStyle.TEXT_DIM))
	column.add_child(_spacer(8))
	column.add_child(UIStyle.label("Salvage: %d" % GameState.salvage, 24, UIStyle.TEXT, true))
	var first: Button = null
	for path: String in Player.WEAPON_PATHS:
		var data: WeaponData = load(path) as WeaponData
		if not GameState.weapons.has(data.id):
			continue
		var tier: int = Upgrades.tier(data.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 16)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIStyle.label("%s   %s" % [data.display_name, "◆".repeat(tier) + "◇".repeat(Upgrades.MAX_TIER - tier)], 23, UIStyle.TEXT, true))
		info.add_child(UIStyle.label(Upgrades.next_label(data.id), 18, UIStyle.TEXT_DIM))
		row.add_child(info)
		var cost: int = Upgrades.next_cost(data.id)
		var buy := _button("Upgrade  (%d)" % cost if cost >= 0 else "Complete", _buy_upgrade.bind(data.id))
		buy.name = "Upgrade_" + data.id
		buy.disabled = not Upgrades.can_purchase(data.id)
		buy.custom_minimum_size.x = 190
		row.add_child(buy)
		column.add_child(row)
		if first == null and not buy.disabled:
			first = buy
	column.add_child(_spacer(10))
	var close := _button("Back to the street   (%s)" % InputSetup.get_action_label("pause"), _close_modal)
	column.add_child(close)
	(first if first != null else close).grab_focus.call_deferred()


func _buy_upgrade(weapon_id: String) -> void:
	if not Upgrades.purchase(weapon_id):
		AudioManager.play_ui(&"ui_wrong", -6.0)
		return
	AudioManager.play_ui(&"fuse_insert", -4.0)
	EventBus.upgrade_purchased.emit(weapon_id)
	show_workbench(_workbench_player)


## A blank panel for other interfaces (puzzles). Pauses the game like every panel here.
func open_panel(minimum: Vector2) -> VBoxContainer:
	return _open_modal(minimum)


func close_panel() -> void:
	_close_modal()


func is_boss_bar_visible() -> bool:
	return _boss_box.visible


## The credits: black screen, the last transmission, then the names. Hold Jump to finish early.
func show_credits(epilogue: bool) -> void:
	_credits = ColorRect.new()
	(_credits as ColorRect).color = Color.BLACK
	_credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_credits)
	var text := UIStyle.label("", 30, UIStyle.TEXT, true)
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits.add_child(text)
	var pages: Array = CREDIT_PAGES.duplicate()
	if epilogue:
		pages.insert(3, EPILOGUE_PAGE)
	AudioManager.play_ui(&"echo_motif", -6.0, &"Dialogue")
	for page: String in pages:
		text.text = page
		text.modulate.a = 0.0
		var elapsed: float = 0.0
		while elapsed < credits_page_seconds:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
			text.modulate.a = clampf(minf(elapsed, credits_page_seconds - elapsed) * 1.4, 0.0, 1.0)
			if Input.is_action_pressed(&"jump") and elapsed > 0.4:
				elapsed += get_process_delta_time() * 8.0
	_credits.queue_free()
	_credits = null
	credits_finished.emit()


## End-of-act card. `rows` is a list of [label, value] pairs.
func show_summary(title: String, subtitle: String, rows: Array) -> void:
	var column: VBoxContainer = _open_modal(Vector2(640, 0))
	column.add_child(UIStyle.label(subtitle.to_upper(), 17, UIStyle.ECHO, true))
	column.add_child(UIStyle.label(title, 44, UIStyle.TEXT, true))
	column.add_child(_spacer(10))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 60)
	grid.add_theme_constant_override(&"v_separation", 8)
	for row: Array in rows:
		grid.add_child(UIStyle.label(str(row[0]), 22, UIStyle.TEXT_DIM))
		grid.add_child(UIStyle.label(str(row[1]), 22, UIStyle.TEXT, true))
	column.add_child(grid)
	column.add_child(_spacer(14))
	var close := _button("Keep exploring", func() -> void:
		_close_modal()
		summary_closed.emit())
	column.add_child(close)
	close.grab_focus()


# --- Internals --------------------------------------------------------------------

## Accessibility: subtitles sit on a dark panel by default; without it the text
## gets a thick outline instead so it stays readable over bright scenes.
func apply_subtitle_background() -> void:
	var with_panel: bool = SettingsManager.get_bool("accessibility", "subtitle_background")
	if with_panel:
		_subtitle_panel.add_theme_stylebox_override(&"panel", UIStyle.panel_box(UIStyle.PANEL_SOFT))
		_subtitle.add_theme_constant_override(&"outline_size", 0)
	else:
		_subtitle_panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		_subtitle.add_theme_constant_override(&"outline_size", 8)
		_subtitle.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.9))


func has_subtitle_background() -> bool:
	return not (_subtitle_panel.get_theme_stylebox(&"panel") is StyleBoxEmpty)


func _show_line(line: Dictionary) -> void:
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	if speaker.is_empty():
		_subtitle.text = "[center][i]%s[/i][/center]" % text
	else:
		var color: Color = SPEAKER_COLORS.get(speaker, UIStyle.TEXT)
		var tag: String = "%s (radio)" % speaker if speaker == "Oren" else ("%s (transmission)" % speaker if speaker == "Lyra" else speaker)
		_subtitle.text = "[center][b][color=#%s]%s:[/color][/b]  %s[/center]" % [color.to_html(false), tag.to_upper(), text]
	var font_size: int = roundi(27.0 * SettingsManager.get_float("audio", "subtitle_size"))
	_subtitle.add_theme_font_size_override(&"normal_font_size", font_size)
	_subtitle.add_theme_font_size_override(&"bold_font_size", font_size)
	apply_subtitle_background()
	_subtitle_time = float(line.get("seconds", 4.0))
	var sound: String = str(line.get("sound", ""))
	if not sound.is_empty():
		AudioManager.play_ui(StringName(sound), -6.0, &"Dialogue")
	elif speaker == "Oren":
		AudioManager.play_ui(&"radio_in", -12.0, &"Dialogue")


func _on_cinematic_changed(is_playing: bool) -> void:
	_cinematic = is_playing
	if not is_playing:
		clear_dialogue()


func _open_modal(minimum: Vector2) -> VBoxContainer:
	if _modal != null:
		_close_modal()
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_modal = ColorRect.new()
	(_modal as ColorRect).color = Color(0.0, 0.0, 0.0, 0.55)
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_modal)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UIStyle.panel_box())
	panel.custom_minimum_size = minimum
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	margin.add_child(column)
	EventBus.modal_changed.emit(true)
	return column


## Closes whatever card or panel is open (the "Keep exploring" button, Esc).
func close_modal() -> void:
	var was_summary: bool = _modal != null
	_close_modal()
	if was_summary:
		summary_closed.emit()


func _close_modal() -> void:
	if _modal == null:
		return
	_modal.queue_free()
	_modal = null
	_puzzle = null
	_workbench_player = null
	_puzzle_lamps.clear()
	get_tree().paused = _was_paused
	if not _was_paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.modal_changed.emit(false)


func _press_breaker(index: int) -> void:
	if _puzzle == null or _puzzle.is_solved():
		return
	_puzzle.press(index)
	AudioManager.play_ui(&"switch", -3.0)
	_refresh_puzzle()
	if _puzzle.is_solved():
		_puzzle_status.text = "All relays closed. Power is flowing."
		AudioManager.play_ui(&"fuse_insert", -2.0)
		var solved_puzzle: JunctionPuzzle = _puzzle
		await get_tree().create_timer(0.9, true).timeout
		if _puzzle == solved_puzzle:
			_close_modal()
			puzzle_solved.emit()


func _refresh_puzzle() -> void:
	for i: int in _puzzle_lamps.size():
		var closed: bool = _puzzle.relays[i]
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.12, 0.5, 0.56) if closed else Color(0.07, 0.08, 0.09)
		box.border_color = UIStyle.ECHO if closed else UIStyle.LINE
		box.set_border_width_all(3)
		box.set_corner_radius_all(48)
		_puzzle_lamps[i].add_theme_stylebox_override(&"panel", box)
		# Shape and text as well as colour, so it reads without colour vision.
		(_puzzle_lamps[i].get_child(0) as Label).text = "CLOSED" if closed else "open"
	if _puzzle_status != null and not _puzzle.is_solved():
		_puzzle_status.text = "Breakers thrown: %d   ·   Keys 1 to %d also work" % [_puzzle.presses, _puzzle.relays.size()]


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 20)
	button.pressed.connect(action)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
