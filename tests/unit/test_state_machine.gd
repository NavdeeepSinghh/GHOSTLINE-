extends GutTest
## The generic state machine: entering, exiting, messages and nested transitions.


class RecordingState:
	extends State
	var log: Array[String] = []
	var chain_to: StringName = &""

	func enter(previous: StringName, message: Dictionary) -> void:
		log.append("enter<%s>%s" % [previous, message.get("note", "")])
		if chain_to != &"":
			var next: StringName = chain_to
			chain_to = &""
			machine.transition_to(next)

	func exit(next: StringName) -> void:
		log.append("exit>%s" % next)


var _machine: StateMachine
var _a: RecordingState
var _b: RecordingState
var _c: RecordingState


func before_each() -> void:
	_machine = StateMachine.new()
	_a = RecordingState.new()
	_a.name = "A"
	_b = RecordingState.new()
	_b.name = "B"
	_c = RecordingState.new()
	_c.name = "C"
	_machine.add_child(_a)
	_machine.add_child(_b)
	_machine.add_child(_c)
	add_child_autofree(_machine)
	_machine.start()


func test_starts_in_first_state() -> void:
	assert_eq(_machine.current_name, &"A")
	assert_eq(_a.log, ["enter<>"] as Array[String])


func test_transition_calls_exit_then_enter_with_message() -> void:
	_machine.transition_to(&"B", {"note": "hello"})
	assert_eq(_machine.current_name, &"B")
	assert_eq(_machine.previous_name, &"A")
	assert_eq(_a.log[1], "exit>B")
	assert_eq(_b.log[0], "enter<A>hello")


func test_unknown_state_is_rejected() -> void:
	_machine.transition_to(&"Nope")
	assert_push_error("unknown state")
	assert_eq(_machine.current_name, &"A")


func test_transition_requested_during_enter_runs_afterwards() -> void:
	watch_signals(_machine)
	_b.chain_to = &"C"
	_machine.transition_to(&"B")
	assert_eq(_machine.current_name, &"C")
	assert_eq(_machine.previous_name, &"B")
	assert_signal_emit_count(_machine, "state_changed", 2)


func test_time_in_state_resets() -> void:
	_machine.physics_update(0.5)
	assert_almost_eq(_machine.time_in_state, 0.5, 0.0001)
	_machine.transition_to(&"B")
	assert_almost_eq(_machine.time_in_state, 0.0, 0.0001)
