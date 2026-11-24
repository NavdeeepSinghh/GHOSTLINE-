class_name State
extends Node
## One state in a StateMachine. Override the callbacks you need.

var machine: StateMachine


## Called once when the machine is set up, before any state is entered.
func setup() -> void:
	pass


func enter(_previous: StringName, _message: Dictionary) -> void:
	pass


func exit(_next: StringName) -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
