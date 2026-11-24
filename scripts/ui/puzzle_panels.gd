class_name PuzzlePanels
extends RefCounted
## Interfaces for the Forest and Facility puzzles, opened as StoryUI panels.
## Each calls `on_solved` once and closes itself.


static func waveform(ui: StoryUI, puzzle: Puzzles.Waveform, on_solved: Callable) -> void:
	var column: VBoxContainer = ui.open_panel(Vector2(820, 0))
	column.add_child(UIStyle.label("MILITARY RADIO TOWER", 17, UIStyle.ECHO, true))
	column.add_child(UIStyle.label("Match your signal to the carrier wave", 28, UIStyle.TEXT, true))
	column.add_child(UIKit.note("The pale line is the carrier. Turn both dials until your line lies on top of it."))
	var scope := Control.new()
	scope.custom_minimum_size = Vector2(760, 220)
	var target_line := Line2D.new()
	target_line.width = 3.0
	target_line.default_color = Color(UIStyle.TEXT, 0.35)
	var own_line := Line2D.new()
	own_line.width = 4.0
	own_line.default_color = UIStyle.WARNING
	scope.add_child(target_line)
	scope.add_child(own_line)
	column.add_child(scope)
	var readout := UIStyle.label("", 20, UIStyle.TEXT_DIM)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(readout)
	var refresh: Callable = func() -> void:
		target_line.clear_points()
		own_line.clear_points()
		for i: int in 121:
			var x: float = float(i) / 120.0
			target_line.add_point(Vector2(x * 760.0, 110.0 - 95.0 * Puzzles.Waveform.sample(x, puzzle.target_frequency, puzzle.target_amplitude)))
			own_line.add_point(Vector2(x * 760.0, 110.0 - 95.0 * Puzzles.Waveform.sample(x, puzzle.frequency, puzzle.amplitude)))
		readout.text = "Frequency %d (carrier %d)      Strength %d (carrier %d)" % [
				puzzle.frequency, puzzle.target_frequency, puzzle.amplitude, puzzle.target_amplitude]
	var dials := HBoxContainer.new()
	dials.alignment = BoxContainer.ALIGNMENT_CENTER
	dials.add_theme_constant_override(&"separation", 12)
	var first: Button = null
	for entry: Array in [["Frequency −", "frequency", -1], ["Frequency +", "frequency", 1], ["Strength −", "amplitude", -1], ["Strength +", "amplitude", 1]]:
		var dial: Button = UIKit.button(str(entry[0]), Callable(), false)
		dial.custom_minimum_size.x = 170
		dial.pressed.connect(func() -> void:
			if puzzle.is_solved():
				return
			if str(entry[1]) == "frequency":
				puzzle.turn_frequency(int(entry[2]))
			else:
				puzzle.turn_amplitude(int(entry[2]))
			AudioManager.play_ui(&"switch", -6.0)
			refresh.call()
			if puzzle.is_solved():
				_finish(ui, readout, "Locked on. The tower is carrying your signal.", on_solved))
		dials.add_child(dial)
		if first == null:
			first = dial
	column.add_child(dials)
	column.add_child(UIKit.button("Step away   (%s)" % InputSetup.get_action_label("pause"), ui.close_panel, false))
	refresh.call()
	first.grab_focus.call_deferred()


static func load_balance(ui: StoryUI, puzzle: Puzzles.LoadBalance, on_solved: Callable) -> void:
	var column: VBoxContainer = ui.open_panel(Vector2(820, 0))
	column.add_child(UIStyle.label("FACILITY POWER", 17, UIStyle.ECHO, true))
	column.add_child(UIStyle.label("Spread the load across three generators", 28, UIStyle.TEXT, true))
	column.add_child(UIKit.note("No generator may carry more than %d. Select a load to move it to the next generator." % puzzle.capacity))
	var totals := UIStyle.label("", 22, UIStyle.TEXT, true)
	var buttons: Array[Button] = []
	var names: PackedStringArray = ["A", "B", "C"]
	var refresh: Callable = func() -> void:
		var parts: PackedStringArray = []
		for generator: int in puzzle.generators:
			var sum: int = puzzle.total(generator)
			parts.append("Generator %s: %d / %d%s" % [names[generator], sum, puzzle.capacity, "  OVERLOAD" if sum > puzzle.capacity else ""])
		totals.text = "      ".join(parts)
		for i: int in buttons.size():
			buttons[i].text = "Load %d  (%d)   on generator %s" % [i + 1, puzzle.loads[i], names[puzzle.assignment[i]]]
	for i: int in puzzle.loads.size():
		var load_button: Button = UIKit.button("", Callable())
		load_button.pressed.connect(func() -> void:
			if puzzle.is_solved():
				return
			puzzle.cycle(i)
			AudioManager.play_ui(&"switch", -6.0)
			refresh.call()
			if puzzle.is_solved():
				_finish(ui, totals, "Balanced. Power restored.", on_solved))
		buttons.append(load_button)
		column.add_child(load_button)
	column.add_child(totals)
	column.add_child(UIKit.button("Step away   (%s)" % InputSetup.get_action_label("pause"), ui.close_panel, false))
	refresh.call()
	buttons[0].grab_focus.call_deferred()


static func tone_lock(ui: StoryUI, puzzle: Puzzles.ToneLock, on_solved: Callable) -> void:
	var column: VBoxContainer = ui.open_panel(Vector2(700, 0))
	column.add_child(UIStyle.label("RESONANCE LOCK", 17, UIStyle.ECHO, true))
	column.add_child(UIStyle.label("Repeat the four tones", 28, UIStyle.TEXT, true))
	column.add_child(UIKit.note("Each tone has its own shape. The sequence is written where Lyra used to practise it."))
	var entered := UIStyle.label("—  —  —  —", 40, UIStyle.TEXT, true)
	entered.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(entered)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	var first: Button = null
	for tone: int in Puzzles.ToneLock.SYMBOLS.size():
		var key: Button = UIKit.button(Puzzles.ToneLock.SYMBOLS[tone], Callable(), false)
		key.custom_minimum_size = Vector2(110, 90)
		key.add_theme_font_size_override(&"font_size", 40)
		key.pressed.connect(func() -> void:
			if puzzle.is_solved():
				return
			AudioManager.play_ui(StringName("tone_%d" % tone), -4.0)
			var correct: bool = puzzle.press(tone)
			var shown: PackedStringArray = []
			for i: int in puzzle.sequence.size():
				shown.append(Puzzles.ToneLock.SYMBOLS[puzzle.entered[i]] if i < puzzle.entered.size() else "—")
			entered.text = "  ".join(shown)
			if not correct:
				AudioManager.play_ui(&"ui_wrong", -6.0)
			elif puzzle.is_solved():
				_finish(ui, entered, entered.text, on_solved))
		row.add_child(key)
		if first == null:
			first = key
	column.add_child(row)
	column.add_child(UIKit.button("Step away   (%s)" % InputSetup.get_action_label("pause"), ui.close_panel, false))
	first.grab_focus.call_deferred()


static func _finish(ui: StoryUI, status: Label, text: String, on_solved: Callable) -> void:
	status.text = text
	AudioManager.play_ui(&"fuse_insert", -2.0)
	await ui.get_tree().create_timer(0.9, true).timeout
	ui.close_panel()
	on_solved.call()
