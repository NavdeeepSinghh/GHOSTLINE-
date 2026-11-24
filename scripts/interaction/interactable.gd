class_name Interactable
extends Area3D
## Shared interface for anything Kael can use with the Interact button:
## ladders now; doors, pickups, workbenches and documents later.
## Put a CollisionShape3D under it; the player's InteractionSensor finds it.

const LAYER_INTERACTABLE: int = 16

@export var prompt: String = "Interact"


func _init() -> void:
	collision_layer = LAYER_INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true


## Text shown next to the button prompt, e.g. "Climb".
func get_prompt(_player: Player) -> String:
	return prompt


func can_interact(_player: Player) -> bool:
	return true


func interact(_player: Player) -> void:
	pass
