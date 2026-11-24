class_name UIStyle
extends RefCounted
## Shared look for every screen: colours, fonts and a Theme built once.
## Minimal, slightly worn: warm off-white text, cyan for anything Echo-related.

const TEXT := Color(0.92, 0.9, 0.86)
const TEXT_DIM := Color(0.92, 0.9, 0.86, 0.55)
const ECHO := Color(0.27, 0.92, 1.0)
const WARNING := Color(1.0, 0.56, 0.2)
const DANGER := Color(1.0, 0.33, 0.3)
const PANEL := Color(0.035, 0.045, 0.058, 0.86)
const PANEL_SOFT := Color(0.035, 0.045, 0.058, 0.6)
const LINE := Color(0.92, 0.9, 0.86, 0.14)

const BODY_FONT_PATH: String = "res://assets/fonts/Inter-Variable.ttf"
const HEADING_FONT_PATH: String = "res://assets/fonts/Rajdhani-SemiBold.ttf"

static var _theme: Theme


static func heading_font() -> Font:
	return load(HEADING_FONT_PATH)


static func body_font() -> Font:
	return load(BODY_FONT_PATH)


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var built := Theme.new()
	built.default_font = body_font()
	built.default_font_size = 22

	built.set_color(&"font_color", &"Label", TEXT)

	var normal := _box(Color(1, 1, 1, 0.045), LINE)
	var hover := _box(Color(ECHO, 0.14), Color(ECHO, 0.7))
	var pressed := _box(Color(ECHO, 0.26), ECHO)
	var focus := _box(Color(0, 0, 0, 0), ECHO)
	for control: StringName in [&"Button", &"OptionButton", &"CheckButton"]:
		built.set_stylebox(&"normal", control, normal)
		built.set_stylebox(&"hover", control, hover)
		built.set_stylebox(&"pressed", control, pressed)
		built.set_stylebox(&"focus", control, focus)
		built.set_stylebox(&"disabled", control, _box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.05)))
		built.set_color(&"font_color", control, TEXT)
		built.set_color(&"font_hover_color", control, Color.WHITE)
		built.set_color(&"font_pressed_color", control, Color.WHITE)
		built.set_color(&"font_focus_color", control, Color.WHITE)
		built.set_color(&"font_disabled_color", control, TEXT_DIM)
	built.set_stylebox(&"hover_pressed", &"CheckButton", hover)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.set_corner_radius_all(3)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ECHO
	built.set_stylebox(&"slider", &"HSlider", track)
	built.set_stylebox(&"grabber_area", &"HSlider", fill)
	built.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)

	built.set_stylebox(&"panel", &"PanelContainer", panel_box())
	built.set_stylebox(&"panel", &"PopupMenu", panel_box())
	built.set_color(&"font_color", &"PopupMenu", TEXT)
	built.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
	built.set_stylebox(&"hover", &"PopupMenu", _box(Color(ECHO, 0.2), Color(0, 0, 0, 0)))
	_theme = built
	return built


static func panel_box(color: Color = PANEL) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(22)
	return box


static func label(text: String, size: int = 22, color: Color = TEXT, use_heading_font: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override(&"font_size", size)
	node.add_theme_color_override(&"font_color", color)
	if use_heading_font:
		node.add_theme_font_override(&"font", heading_font())
	return node


static func _box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box
