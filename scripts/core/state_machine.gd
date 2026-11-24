class_name StateMachine
extends Node
## Generic finite state machine. Child nodes that extend State are its states,
## addressed by node name. The owner drives it by calling update/physics_update.

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: NodePath

var current: State
var current_name: StringName = &""
var previous_name: StringName = &""
## Seconds spent in the current state.
var time_in_state: float = 0.0

var _states: Dictionary = {}
var _is_transitioning: bool = false
var _queued: Array = []


## Collects child states and enters the initial one. Call from the owner's _ready.
func start() -> void:
	_states.clear()
	for child: Node in get_children():
		if child is State:
			var state: State = child
			state.machine = self
			_states[StringName(child.name)] = state
	for state_name: StringName in _states:
		(_states[state_name] as State).setup()
	var first: State = get_node_or_null(initial_state) as State
	if first == null and not _states.is_empty():
		first = _states.values()[0]
	if first != null:
		current = first
		current_name = StringName(first.name)
		time_in_state = 0.0
		first.enter(&"", {})
		state_changed.emit(&"", current_name)


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func is_in(state_name: StringName) -> bool:
	return current_name == state_name


func transition_to(state_name: StringName, message: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: unknown state '%s'" % state_name)
		return
	# A transition requested from inside enter()/exit() runs after the current one finishes.
	if _is_transitioning:
		_queued = [state_name, message]
		return
	_is_transitioning = true
	var next: State = _states[state_name]
	if current != null:
		current.exit(state_name)
	previous_name = current_name
	current = next
	current_name = state_name
	time_in_state = 0.0
	next.enter(previous_name, message)
	_is_transitioning = false
	state_changed.emit(previous_name, current_name)
	if not _queued.is_empty():
		var queued: Array = _queued
		_queued = []
		transition_to(queued[0], queued[1])


func update(delta: float) -> void:
	if current != null:
		current.update(delta)


func physics_update(delta: float) -> void:
	time_in_state += delta
	if current != null:
		current.physics_update(delta)


func handle_input(event: InputEvent) -> void:
	if current != null:
		current.handle_input(event)
