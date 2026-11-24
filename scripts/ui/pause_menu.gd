class_name PauseMenu
extends CanvasLayer
## The pause screen: a list of pages on the left (Objectives, Inventory,
## Documents, Settings, Save, Load) and the open page on the right, plus
## Resume, Load Checkpoint, the benchmark and the two ways out.
##
## It reads GameState and MissionManager; Game writes Kael's current numbers
## into GameState just before opening it.

signal resume_requested
signal respawn_requested
signal benchmark_requested
signal quit_requested
signal quit_to_menu_requested
signal save_requested(slot: String)
signal load_requested(slot: String)
signal photo_mode_requested

const PAGES: PackedStringArray = ["Objectives", "Inventory", "Documents", "Settings", "Save game", "Load game"]
const SLOT_NAMES: Dictionary = {"autosave": "Autosave", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3"}

var current_page: String = "Objectives"
## False in levels that cannot be saved (the Proving Ground).
var saving_enabled: bool = true

var _resume: Button
var _page: VBoxContainer
var _page_title: Label
var _settings: SettingsPanel
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UIStyle.theme()
	add_child(center)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 18)
	center.add_child(columns)

	var nav_panel := PanelContainer.new()
	nav_panel.custom_minimum_size = Vector2(330, 0)
	columns.add_child(nav_panel)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override(&"separation", 9)
	nav_panel.add_child(nav)
	nav.add_child(UIStyle.label("PAUSED", 48, UIStyle.TEXT, true))
	nav.add_child(UIStyle.label("GHOSTLINE", 18, UIStyle.ECHO, true))
	nav.add_child(UIKit.spacer(6))
	_resume = UIKit.button("Resume", func() -> void: resume_requested.emit())
	nav.add_child(_resume)
	for page: String in PAGES:
		var page_button: Button = UIKit.button(page, show_page.bind(page))
		page_button.name = "Page_" + page.replace(" ", "")
		nav.add_child(page_button)
	nav.add_child(UIKit.spacer(10))
	var photo: Button = UIKit.button("Photo mode", func() -> void: photo_mode_requested.emit())
	photo.name = "PhotoMode"
	nav.add_child(photo)
	nav.add_child(UIKit.button("Load checkpoint", func() -> void: respawn_requested.emit()))
	nav.add_child(UIKit.button("Run benchmark (60 s)", func() -> void: benchmark_requested.emit()))
	nav.add_child(UIKit.spacer(10))
	nav.add_child(UIKit.button("Quit to menu", func() -> void: quit_to_menu_requested.emit()))
	nav.add_child(UIKit.button("Quit to desktop", func() -> void: quit_requested.emit()))

	var page_panel := PanelContainer.new()
	page_panel.custom_minimum_size = Vector2(840, 720)
	columns.add_child(page_panel)
	var page_column := VBoxContainer.new()
	page_column.add_theme_constant_override(&"separation", 10)
	page_panel.add_child(page_column)
	_page_title = UIStyle.label("", 34, UIStyle.TEXT, true)
	page_column.add_child(_page_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_column.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override(&"separation", 8)
	_scroll.add_child(_page)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_column.add_child(_settings)


func open() -> void:
	visible = true
	show_page(current_page)
	_resume.grab_focus()


func close() -> void:
	visible = false


## True while the settings page is waiting for a key to bind (Esc must not close the menu).
func is_capturing_input() -> bool:
	return visible and _settings.visible and _settings.is_listening()


func show_page(page: String) -> void:
	current_page = page
	_page_title.text = page.to_upper()
	UIKit.clear(_page)
	_settings.visible = page == "Settings"
	_scroll.visible = page != "Settings"
	match page:
		"Objectives":
			_build_objectives()
		"Inventory":
			_build_inventory()
		"Documents":
			_build_documents("")
		"Save game":
			_build_slots(true)
		"Load game":
			_build_slots(false)


# --- Pages --------------------------------------------------------------------------

func _build_objectives() -> void:
	_page.add_child(UIKit.section(MissionManager.mission_title if not MissionManager.mission_title.is_empty() else "Mission"))
	if MissionManager.current_objective.is_empty():
		_page.add_child(UIKit.note("No objective here."))
	else:
		_page.add_child(_line("▸  " + MissionManager.current_objective, UIStyle.TEXT, 24))
	for done: String in MissionManager.completed:
		_page.add_child(_line("✓  " + done, UIStyle.TEXT_DIM))
	if not MissionManager.side_objectives.is_empty():
		_page.add_child(UIKit.section("Side objectives"))
		for id: String in MissionManager.side_objectives:
			var entry: Dictionary = MissionManager.side_objectives[id]
			var done: bool = bool(entry["done"])
			_page.add_child(_line(("✓  " if done else "▸  ") + str(entry["text"]).replace("Optional: ", ""),
					UIStyle.TEXT_DIM if done else UIStyle.TEXT))
	_page.add_child(UIKit.spacer(8))
	_page.add_child(UIKit.note("The marker on screen points at the current objective. Turn it off under Settings, Gameplay."))


func _build_inventory() -> void:
	_page.add_child(UIKit.section("Weapons"))
	for path: String in Player.WEAPON_PATHS:
		var data: WeaponData = load(path) as WeaponData
		if not GameState.weapons.has(data.id):
			continue
		var tier: int = Upgrades.tier(data.id)
		var equipped: String = "   (equipped)" if GameState.equipped_weapon == data.id else ""
		_page.add_child(_pair(data.display_name + equipped, "Tier %d / %d   %s" % [tier, Upgrades.MAX_TIER, "◆".repeat(tier) + "◇".repeat(Upgrades.MAX_TIER - tier)]))
	_page.add_child(UIKit.section("Carried"))
	_page.add_child(_pair("Health", "%d / %d" % [roundi(GameState.health), roundi(GameState.max_health)]))
	_page.add_child(_pair("Stamina", "%d" % roundi(GameState.max_stamina)))
	_page.add_child(_pair("Injectors", str(GameState.injectors)))
	_page.add_child(_pair("Bottles", str(GameState.throwables)))
	_page.add_child(_pair("Salvage", str(GameState.salvage)))
	_page.add_child(UIKit.section("Found"))
	var cores: int = int(GameState.has_flag("dc_vital_core"))
	var lungs: int = int(GameState.has_flag("dc_lung_core"))
	_page.add_child(_pair("Vital Cores", "%d / 3" % cores))
	_page.add_child(_pair("Lung Cores", "%d / 3" % lungs))
	var fuses: int = int(GameState.has_flag("dc_fuse_metro")) + int(GameState.has_flag("dc_fuse_school"))
	if fuses > 0 and not GameState.has_flag("dc_power_on"):
		_page.add_child(_pair("Tower fuses", "%d / 2" % fuses))
	_page.add_child(_pair("Documents", "%d / %d" % [GameState.collected_documents.size(), Documents.total()]))
	if NewGamePlus.cycle() > 0:
		_page.add_child(_pair("New Game+", "Cycle %d   (enemies %d%% tougher)" % [NewGamePlus.cycle(), roundi((NewGamePlus.enemy_health_scale() - 1.0) * 100.0)]))
	_page.add_child(UIKit.spacer(8))
	_page.add_child(UIKit.note("Weapons are upgraded with salvage at workbenches."))


func _build_documents(open_id: String) -> void:
	UIKit.clear(_page)
	if not open_id.is_empty():
		var document: Dictionary = Documents.find(open_id)
		_page.add_child(UIKit.button("‹  Back to the list", _build_documents.bind("")))
		_page.add_child(UIStyle.label(str(document.get("kind", "")).to_upper(), 16, UIStyle.ECHO, true))
		_page.add_child(UIStyle.label(str(document.get("title", "")), 30, UIStyle.TEXT, true))
		var body := UIStyle.label(str(document.get("body", "")), 21)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 760
		_page.add_child(body)
		return
	for area: Dictionary in Documents.areas():
		var documents: Array = area.get("documents", [])
		var found: int = 0
		for document: Dictionary in documents:
			if GameState.collected_documents.has(str(document["id"])):
				found += 1
		_page.add_child(UIKit.section("%s   %d / %d" % [str(area.get("area_title", "")), found, documents.size()]))
		for document: Dictionary in documents:
			if GameState.collected_documents.has(str(document["id"])):
				_page.add_child(UIKit.button(str(document["title"]), _build_documents.bind(str(document["id"]))))
			else:
				_page.add_child(_line("?  Not found yet", UIStyle.TEXT_DIM))


func _build_slots(saving: bool) -> void:
	if saving and not saving_enabled:
		_page.add_child(UIKit.note("This level cannot be saved."))
		return
	_page.add_child(UIKit.note("Saving keeps everything you have done and found. Loading puts Kael back where he stood, or at the last checkpoint if he was fighting, climbing or falling."
			if saving else "Loading replaces the current run with the saved one."))
	var slots: PackedStringArray = SaveManager.MANUAL_SLOTS.duplicate()
	if not saving:
		slots.insert(0, SaveManager.AUTOSAVE_SLOT)
	for slot: String in slots:
		var description: String = SaveManager.describe_slot(slot)
		var text: String = "%s      %s" % [str(SLOT_NAMES[slot]), description if not description.is_empty() else "Empty"]
		var slot_button: Button = UIKit.button(text, Callable())
		slot_button.name = "Slot_" + slot
		if saving:
			slot_button.pressed.connect(func() -> void:
				save_requested.emit(slot)
				if current_page == "Save game":
					show_page("Save game"))
		else:
			slot_button.disabled = description.is_empty()
			slot_button.pressed.connect(func() -> void: load_requested.emit(slot))
		_page.add_child(slot_button)


func _line(text: String, color: Color, size: int = 21) -> Label:
	var label := UIStyle.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 760
	return label


func _pair(left: String, right: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	var name_label := UIStyle.label(left, 21)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(name_label)
	box.add_child(UIStyle.label(right, 21, UIStyle.TEXT_DIM))
	return box
