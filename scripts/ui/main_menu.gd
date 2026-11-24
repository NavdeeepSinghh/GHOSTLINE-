class_name MainMenu
extends CanvasLayer
## The title screen, drawn over the live Dead City while a camera drifts
## through the rain: New Game, Continue, Load, Settings, Credits, Quit.

signal new_game_requested
signal new_game_plus_requested
signal continue_requested
signal load_requested(slot: String)
signal chapter_requested(area: String)
signal mission_requested(id: String)
signal quit_requested

const CREDITS: String = """GHOSTLINE

Design, code, story, level art, shaders and synthesized audio were made for this project.

Stand-in characters: KayKit Adventurers and Skeletons packs by Kay Lousberg (CC0).
Fonts: Inter and Rajdhani (SIL Open Font License).
Engine: Godot 4 (MIT).

Full list and licences: docs/CREDITS.md"""

var _buttons: VBoxContainer
var _continue: Button
var _side: PanelContainer
var _side_content: VBoxContainer
var _status: Label
var _root: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)

	# A soft dark band on the left keeps the text readable over the city.
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.005, 0.01, 0.5)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size.x = 620
	_root.add_child(shade)

	var column := VBoxContainer.new()
	column.position = Vector2(96, 150)
	column.add_theme_constant_override(&"separation", 4)
	_root.add_child(column)
	column.add_child(UIStyle.label("GHOSTLINE", 96, UIStyle.TEXT, true))
	column.add_child(UIStyle.label("2097  ·  TWENTY YEARS AFTER THE SILENCE", 22, UIStyle.ECHO, true))
	column.add_child(UIKit.spacer(46))

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 10)
	_buttons.custom_minimum_size.x = 380
	column.add_child(_buttons)
	_continue = _menu_button("Continue", func() -> void: continue_requested.emit())
	_menu_button("New Game", func() -> void: new_game_requested.emit())
	var plus: Button = _menu_button("New Game+", func() -> void: new_game_plus_requested.emit())
	plus.visible = NewGamePlus.is_available()
	plus.tooltip_text = "Start again with your weapons, upgrades and salvage. Enemies are tougher."
	_menu_button("Load", _show_load)
	_menu_button("Missions", _show_missions)
	var chapters: Button = _menu_button("Chapters", _show_chapters)
	chapters.visible = Chapters.is_unlocked()
	_menu_button("Settings", _show_settings)
	_menu_button("Credits", _show_credits)
	_menu_button("Quit", func() -> void: quit_requested.emit())
	column.add_child(UIKit.spacer(18))
	_status = UIStyle.label("", 18, UIStyle.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 480
	column.add_child(_status)

	_side = PanelContainer.new()
	_side.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_side.grow_vertical = Control.GROW_DIRECTION_BOTH
	_side.position.x = -80
	_side.visible = false
	_root.add_child(_side)
	_side_content = VBoxContainer.new()
	_side_content.add_theme_constant_override(&"separation", 10)
	_side.add_child(_side_content)
	refresh()


## Re-reads the save folder (Continue is disabled when there is nothing to continue).
func refresh() -> void:
	var newest: String = SaveManager.get_most_recent_slot()
	_continue.disabled = newest.is_empty()
	_continue.text = "Continue" if newest.is_empty() else "Continue      %s" % SaveManager.describe_slot(newest).get_slice("  ·  ", 1)
	(_continue if not newest.is_empty() else _buttons.get_child(1) as Button).grab_focus.call_deferred()


func set_status(text: String) -> void:
	_status.text = text


func set_menu_visible(shown: bool) -> void:
	_root.visible = shown


func is_capturing_input() -> bool:
	for child: Node in _side_content.get_children():
		if child is SettingsPanel and (child as SettingsPanel).is_listening():
			return true
	return false


func close_side_panel() -> void:
	_side.visible = false


func _menu_button(text: String, action: Callable) -> Button:
	var node: Button = UIKit.button(text, action)
	node.add_theme_font_size_override(&"font_size", 26)
	node.name = text.replace(" ", "")
	_buttons.add_child(node)
	return node


func _open_side(title: String) -> void:
	UIKit.clear(_side_content)
	_side.visible = true
	var header := HBoxContainer.new()
	var heading := UIStyle.label(title.to_upper(), 34, UIStyle.TEXT, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(UIKit.button("Close", close_side_panel, false))
	_side_content.add_child(header)


func _show_load() -> void:
	_open_side("Load")
	var slots: PackedStringArray = [SaveManager.AUTOSAVE_SLOT]
	slots.append_array(SaveManager.MANUAL_SLOTS)
	for slot: String in slots:
		var description: String = SaveManager.describe_slot(slot)
		var slot_button: Button = UIKit.button("%s      %s" % [str(PauseMenu.SLOT_NAMES[slot]), description if not description.is_empty() else "Empty"],
				func() -> void: load_requested.emit(slot))
		slot_button.disabled = description.is_empty()
		slot_button.custom_minimum_size.x = 720
		_side_content.add_child(slot_button)


## Every objective of every act, to start directly.
func _show_missions() -> void:
	_open_side("Missions")
	var note: Label = UIStyle.label("Jump straight to any part of the game. Progress in a mission is not saved and your saves are not touched.", 19, UIStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 720
	_side_content.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var all: Dictionary = Missions.data()
	var first: Button = null
	for area: String in Chapters.ORDER:
		list.add_child(UIKit.section(str(Missions.ACT_NAMES.get(area, area))))
		var number: int = 1
		for mission: Dictionary in all.get(area, []):
			var id: String = str(mission.get("id", ""))
			var button: Button = UIKit.button("%d.  %s      %s" % [number, str(mission.get("title", id)), str(mission.get("note", ""))],
					func() -> void: mission_requested.emit(id))
			button.name = "Mission_" + id
			button.custom_minimum_size.x = 720
			list.add_child(button)
			if first == null:
				first = button
			number += 1
	if first != null:
		first.grab_focus.call_deferred()


func _show_chapters() -> void:
	_open_side("Chapters")
	var note: Label = UIStyle.label("Start any act again with a fresh Kael. Your saves are not touched.", 19, UIStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 640
	_side_content.add_child(note)
	var chapters: Dictionary = Chapters.data()
	for area: String in Chapters.ORDER:
		var chapter: Dictionary = chapters.get(area, {})
		var button: Button = UIKit.button("%s      %s" % [str(chapter.get("title", area)), str(chapter.get("place", ""))],
				func() -> void: chapter_requested.emit(area))
		button.name = "Chapter_" + area
		button.custom_minimum_size.x = 640
		_side_content.add_child(button)


func _show_settings() -> void:
	_open_side("Settings")
	var panel := SettingsPanel.new()
	_side_content.add_child(panel)


func _show_credits() -> void:
	_open_side("Credits")
	var text := UIStyle.label(CREDITS, 21)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 640
	_side_content.add_child(text)
