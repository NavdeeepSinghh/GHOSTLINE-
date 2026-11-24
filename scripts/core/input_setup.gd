extends Node
## Registers the game's input actions at startup from one table.
##
## Bindings live here (not in project.godot) so there is a single readable source
## of defaults. Rebinding replaces an action's first keyboard/mouse binding; the
## overrides are stored in settings (section "bindings") and applied at startup.

enum Kind { KEY, MOUSE, JOY_BUTTON, JOY_AXIS }

const STICK_DEADZONE: float = 0.2
const BUTTON_DEADZONE: float = 0.5

## action name -> list of [Kind, code, (axis sign)]
const BINDINGS: Dictionary = {
	"move_forward": [[Kind.KEY, KEY_W], [Kind.JOY_AXIS, JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [[Kind.KEY, KEY_S], [Kind.JOY_AXIS, JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [[Kind.KEY, KEY_A], [Kind.JOY_AXIS, JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[Kind.KEY, KEY_D], [Kind.JOY_AXIS, JOY_AXIS_LEFT_X, 1.0]],
	"look_up": [[Kind.JOY_AXIS, JOY_AXIS_RIGHT_Y, -1.0]],
	"look_down": [[Kind.JOY_AXIS, JOY_AXIS_RIGHT_Y, 1.0]],
	"look_left": [[Kind.JOY_AXIS, JOY_AXIS_RIGHT_X, -1.0]],
	"look_right": [[Kind.JOY_AXIS, JOY_AXIS_RIGHT_X, 1.0]],
	"sprint": [[Kind.KEY, KEY_SHIFT], [Kind.JOY_BUTTON, JOY_BUTTON_LEFT_STICK]],
	"walk": [[Kind.KEY, KEY_X]],
	"jump": [[Kind.KEY, KEY_SPACE], [Kind.JOY_BUTTON, JOY_BUTTON_A]],
	"crouch": [[Kind.KEY, KEY_C], [Kind.KEY, KEY_CTRL], [Kind.JOY_BUTTON, JOY_BUTTON_B]],
	"interact": [[Kind.KEY, KEY_E], [Kind.JOY_BUTTON, JOY_BUTTON_X]],
	"lock_on": [[Kind.KEY, KEY_TAB], [Kind.MOUSE, MOUSE_BUTTON_MIDDLE], [Kind.JOY_BUTTON, JOY_BUTTON_RIGHT_STICK]],
	"pause": [[Kind.KEY, KEY_ESCAPE], [Kind.JOY_BUTTON, JOY_BUTTON_START]],
	"debug_overlay": [[Kind.KEY, KEY_F3], [Kind.KEY, KEY_QUOTELEFT]],
	"help": [[Kind.KEY, KEY_F1], [Kind.KEY, KEY_SLASH]],
	# Combat and stealth (Milestone 2).
	"light_attack": [[Kind.MOUSE, MOUSE_BUTTON_LEFT], [Kind.JOY_BUTTON, JOY_BUTTON_RIGHT_SHOULDER]],
	"heavy_attack": [[Kind.MOUSE, MOUSE_BUTTON_RIGHT], [Kind.JOY_AXIS, JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"block": [[Kind.KEY, KEY_Q], [Kind.JOY_BUTTON, JOY_BUTTON_LEFT_SHOULDER]],
	"dodge": [[Kind.KEY, KEY_ALT], [Kind.KEY, KEY_F], [Kind.JOY_BUTTON, JOY_BUTTON_Y]],
	"throw": [[Kind.KEY, KEY_G], [Kind.JOY_AXIS, JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"heal": [[Kind.KEY, KEY_H], [Kind.JOY_BUTTON, JOY_BUTTON_DPAD_UP]],
	"hint": [[Kind.KEY, KEY_T], [Kind.JOY_BUTTON, JOY_BUTTON_DPAD_DOWN]],
	"weapon_next": [[Kind.MOUSE, MOUSE_BUTTON_WHEEL_DOWN], [Kind.JOY_BUTTON, JOY_BUTTON_DPAD_RIGHT]],
	"weapon_1": [[Kind.KEY, KEY_1]],
	"weapon_2": [[Kind.KEY, KEY_2]],
	"weapon_3": [[Kind.KEY, KEY_3]],
	"weapon_prev": [[Kind.MOUSE, MOUSE_BUTTON_WHEEL_UP], [Kind.JOY_BUTTON, JOY_BUTTON_DPAD_LEFT]],
}


## Actions offered on the rebinding screen, with their display names.
const REBINDABLE: Dictionary = {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right",
	"sprint": "Sprint", "walk": "Walk", "jump": "Jump / climb", "crouch": "Crouch", "interact": "Interact", "hint": "Hint",
	"light_attack": "Light attack", "heavy_attack": "Heavy attack", "block": "Block / parry", "dodge": "Dodge",
	"throw": "Throw bottle", "heal": "Use injector", "lock_on": "Lock on",
	"weapon_1": "Weapon 1", "weapon_2": "Weapon 2", "weapon_3": "Weapon 3",
}

## Actions whose controller button can be changed (sticks and triggers stay fixed).
const PAD_REBINDABLE: Dictionary = {
	"jump": "Jump / climb", "crouch": "Crouch", "interact": "Interact", "sprint": "Sprint",
	"light_attack": "Light attack", "block": "Block / parry", "dodge": "Dodge", "heal": "Use injector",
	"lock_on": "Lock on", "hint": "Hint", "weapon_next": "Next weapon", "weapon_prev": "Previous weapon",
}
const PAD_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A / Cross", JOY_BUTTON_B: "B / Circle", JOY_BUTTON_X: "X / Square", JOY_BUTTON_Y: "Y / Triangle",
	JOY_BUTTON_LEFT_SHOULDER: "LB / L1", JOY_BUTTON_RIGHT_SHOULDER: "RB / R1", JOY_BUTTON_LEFT_STICK: "Left stick press",
	JOY_BUTTON_RIGHT_STICK: "Right stick press", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_BACK: "View / Share",
}

## action -> [Kind, code] chosen by the player.
var _overrides: Dictionary = {}
## action -> controller button index chosen by the player.
var _pad_overrides: Dictionary = {}


func _enter_tree() -> void:
	register_defaults()


func _ready() -> void:
	# Settings load in their own autoload; pick the saved bindings up once everything exists.
	_load_overrides.call_deferred()


func _load_overrides() -> void:
	var saved: Variant = SettingsManager.get_section("bindings")
	if saved is Dictionary:
		for action: String in saved:
			var binding: Variant = saved[action]
			if BINDINGS.has(action) and binding is Array and (binding as Array).size() >= 2:
				_overrides[action] = [int(binding[0]), int(binding[1])]
	var pad: Variant = SettingsManager.get_section("pad_bindings")
	if pad is Dictionary:
		for action: String in pad:
			if PAD_REBINDABLE.has(action) and (pad[action] is int or pad[action] is float) and int(pad[action]) >= 0:
				_pad_overrides[action] = int(pad[action])
	register_defaults()


## Rebinds an action's keyboard/mouse input. If another action already uses
## that input, the two swap so nothing is left unbound.
func rebind(action: String, event: InputEvent) -> bool:
	var binding: Array = []
	if event is InputEventKey:
		binding = [Kind.KEY, int((event as InputEventKey).physical_keycode)]
	elif event is InputEventMouseButton:
		binding = [Kind.MOUSE, int((event as InputEventMouseButton).button_index)]
	if binding.is_empty() or not BINDINGS.has(action):
		return false
	var previous: Array = get_primary_binding(action)
	for other: String in REBINDABLE:
		if other != action and get_primary_binding(other) == binding and not previous.is_empty():
			_overrides[other] = previous
			SettingsManager.set_value("bindings", other, previous, false)
	_overrides[action] = binding
	SettingsManager.set_value("bindings", action, binding)
	register_defaults()
	return true


## Rebinds an action's controller button. Like the keyboard, two actions that
## would share a button swap instead.
func rebind_pad(action: String, event: InputEvent) -> bool:
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	if button_event == null or not PAD_REBINDABLE.has(action):
		return false
	var button: int = int(button_event.button_index)
	var previous: int = get_pad_button(action)
	for other: String in PAD_REBINDABLE:
		if other != action and get_pad_button(other) == button and previous >= 0:
			_pad_overrides[other] = previous
			SettingsManager.set_value("pad_bindings", other, previous, false)
	_pad_overrides[action] = button
	SettingsManager.set_value("pad_bindings", action, button)
	register_defaults()
	return true


## The controller button currently used for an action, or -1.
func get_pad_button(action: String) -> int:
	if _pad_overrides.has(action):
		return int(_pad_overrides[action])
	for binding: Array in BINDINGS.get(action, []):
		if binding[0] == Kind.JOY_BUTTON:
			return int(binding[1])
	return -1


func get_pad_label(action: String) -> String:
	var button: int = get_pad_button(action)
	return str(PAD_BUTTON_NAMES.get(button, "Button %d" % button)) if button >= 0 else "-"


func reset_bindings() -> void:
	for action: String in _overrides:
		SettingsManager.set_value("bindings", action, [], false)
	_overrides.clear()
	for action: String in _pad_overrides:
		SettingsManager.set_value("pad_bindings", action, -1, false)
	_pad_overrides.clear()
	SettingsManager.save_settings()
	register_defaults()


## The keyboard/mouse binding currently in effect for an action: [Kind, code], or [].
func get_primary_binding(action: String) -> Array:
	if _overrides.has(action):
		return _overrides[action]
	for binding: Array in BINDINGS.get(action, []):
		if binding[0] == Kind.KEY or binding[0] == Kind.MOUSE:
			return [int(binding[0]), int(binding[1])]
	return []


## Adds every action in BINDINGS to the InputMap. Safe to call more than once.
func register_defaults() -> void:
	for action: String in BINDINGS:
		var is_axis_action: bool = _uses_axis(BINDINGS[action])
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, STICK_DEADZONE if is_axis_action else BUTTON_DEADZONE)
		var replaced: bool = false
		var pad_replaced: bool = false
		for binding: Array in BINDINGS[action]:
			if binding[0] == Kind.JOY_BUTTON and _pad_overrides.has(action):
				if not pad_replaced:
					InputMap.action_add_event(action, _make_event([Kind.JOY_BUTTON, int(_pad_overrides[action])]))
					pad_replaced = true
				continue
			var is_desktop: bool = binding[0] == Kind.KEY or binding[0] == Kind.MOUSE
			if _overrides.has(action) and is_desktop:
				# The player's choice stands in for every default keyboard/mouse binding.
				if not replaced:
					InputMap.action_add_event(action, _make_event(_overrides[action]))
					replaced = true
				continue
			InputMap.action_add_event(action, _make_event(binding))
		if _overrides.has(action) and not replaced:
			InputMap.action_add_event(action, _make_event(_overrides[action]))


func _uses_axis(bindings: Array) -> bool:
	for binding: Array in bindings:
		if binding[0] == Kind.JOY_AXIS:
			return true
	return false


func _make_event(binding: Array) -> InputEvent:
	match binding[0]:
		Kind.KEY:
			var key := InputEventKey.new()
			key.physical_keycode = binding[1]
			return key
		Kind.MOUSE:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = binding[1]
			return mouse
		Kind.JOY_BUTTON:
			var button := InputEventJoypadButton.new()
			button.button_index = binding[1]
			return button
		_:
			var axis := InputEventJoypadMotion.new()
			axis.axis = binding[1]
			axis.axis_value = binding[2]
			return axis


## Human-readable label for the first keyboard/mouse binding of an action (for prompts).
func get_action_label(action: String) -> String:
	var binding: Array = get_primary_binding(action)
	if binding.is_empty():
		return action
	if binding[0] == Kind.KEY:
		return OS.get_keycode_string(binding[1])
	match binding[1]:
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
	return "Mouse %d" % int(binding[1])
