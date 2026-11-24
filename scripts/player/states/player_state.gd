class_name PlayerState
extends State
## Base for Kael's states; gives each state typed access to the player.

var player: Player


func setup() -> void:
	player = machine.get_parent() as Player
