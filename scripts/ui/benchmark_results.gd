class_name BenchmarkResults
extends CanvasLayer
## Shows the benchmark summary once a run finishes.

signal closed

var _text: Label
var _files: Label
var _close: Button


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UIStyle.theme()
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	panel.add_child(column)
	column.add_child(UIStyle.label("BENCHMARK RESULT", 44, UIStyle.TEXT, true))
	_text = UIStyle.label("", 21)
	column.add_child(_text)
	_files = UIStyle.label("", 16, UIStyle.TEXT_DIM)
	_files.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	column.add_child(_files)
	column.add_child(UIStyle.label("This summary has been copied to the clipboard. Paste it back to Claude.", 18, UIStyle.ECHO))
	_close = Button.new()
	_close.text = "Close"
	_close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	column.add_child(_close)


func show_summary(summary: Dictionary) -> void:
	var text: String = Benchmark.format_summary(summary)
	_text.text = text
	var files: PackedStringArray = summary.get("files", PackedStringArray())
	_files.text = "Saved to:\n" + "\n".join(files) if not files.is_empty() else ""
	DisplayServer.clipboard_set(text)
	visible = true
	_close.grab_focus()
