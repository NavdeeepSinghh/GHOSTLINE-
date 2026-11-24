class_name UIKit
extends RefCounted
## Small builders shared by the menus: buttons, labelled rows, and controls
## bound straight to a setting.


static func button(text: String, action: Callable, left_aligned: bool = true) -> Button:
	var node := Button.new()
	node.text = text
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT if left_aligned else HORIZONTAL_ALIGNMENT_CENTER
	if action.is_valid():
		node.pressed.connect(action)
	return node


## Removes a container's children now (queue_free alone leaves them in place
## until the end of the frame, which breaks naming and focus for their replacements).
static func clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func section(text: String) -> Label:
	var heading := UIStyle.label(text.to_upper(), 17, UIStyle.TEXT_DIM, true)
	heading.custom_minimum_size.y = 34
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return heading


static func spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size.y = height
	return node


static func note(text: String, size: int = 17) -> Label:
	var node := UIStyle.label(text, size, UIStyle.TEXT_DIM)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func row(text: String, control: Control, control_width: float = 280.0) -> HBoxContainer:
	var box := HBoxContainer.new()
	var name_label := UIStyle.label(text, 21)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(name_label)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, control_width)
	box.add_child(control)
	return box


static func toggle(setting_section: String, key: String) -> CheckButton:
	var node := CheckButton.new()
	node.button_pressed = SettingsManager.get_bool(setting_section, key)
	node.toggled.connect(func(pressed: bool) -> void: SettingsManager.set_value(setting_section, key, pressed))
	return node


static func slider(setting_section: String, key: String, low: float, high: float, step: float, percent: bool = false) -> HBoxContainer:
	var box := HBoxContainer.new()
	var node := HSlider.new()
	node.min_value = low
	node.max_value = high
	node.step = step
	node.value = SettingsManager.get_float(setting_section, key)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var readout := UIStyle.label(format_value(node.value, step, percent), 18, UIStyle.TEXT_DIM)
	readout.custom_minimum_size.x = 62
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node.value_changed.connect(func(value: float) -> void:
		readout.text = format_value(value, step, percent)
		SettingsManager.set_value(setting_section, key, value, false))
	node.drag_ended.connect(func(_changed: bool) -> void: SettingsManager.save_settings())
	box.add_child(node)
	box.add_child(readout)
	return box


## A drop-down bound to a setting. `choices` is a list of [label, value].
static func option(setting_section: String, key: String, choices: Array) -> OptionButton:
	var node := OptionButton.new()
	var current: Variant = SettingsManager.get_value(setting_section, key)
	for i: int in choices.size():
		node.add_item(str(choices[i][0]))
		if _same(choices[i][1], current):
			node.select(i)
	node.item_selected.connect(func(index: int) -> void: SettingsManager.set_value(setting_section, key, choices[index][1]))
	return node


static func format_value(value: float, step: float, percent: bool) -> String:
	if percent:
		return "%d%%" % roundi(value * 100.0)
	return "%d" % roundi(value) if step >= 1.0 else "%.2f" % value


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b
