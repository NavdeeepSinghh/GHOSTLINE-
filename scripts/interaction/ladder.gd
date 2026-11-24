class_name Ladder
extends Interactable
## A climbable ladder. The node sits at the ladder's base; local +Z points away
## from the wall (the side the player climbs on). The interaction zone covers
## the foot of the ladder and the landing at the top, so it can be used from
## either end.

## Length of the ladder in metres.
@export var height: float = 4.0
## How far below the top the feet stop before pulling up onto the landing.
@export var top_feet_margin: float = 0.95
## False while a shortcut ladder is still folded up.
var enabled: bool = true


func _ready() -> void:
	prompt = "Climb"
	for child: Node in get_children():
		if child is CollisionShape3D:
			return
	_build_default_zone()


func get_base() -> Vector3:
	return global_position


func get_top() -> Vector3:
	return global_position + Vector3.UP * height


func get_normal() -> Vector3:
	var normal: Vector3 = global_basis.z
	normal.y = 0.0
	return normal.normalized()


func get_max_feet_height() -> float:
	return maxf(height - top_feet_margin, 0.1)


## Feet position while on the ladder at `feet_height` above the base.
func get_climb_position(feet_height: float, body_radius: float) -> Vector3:
	return get_base() + get_normal() * (body_radius + 0.05) + Vector3.UP * feet_height


## Where the player stands after climbing off the top.
func get_top_exit_position(body_radius: float) -> Vector3:
	return get_top() - get_normal() * (body_radius + 0.25) + Vector3.UP * 0.02


func get_prompt(player: Player) -> String:
	return "Climb down" if _is_at_top(player) else "Climb"


func can_interact(player: Player) -> bool:
	return enabled and not player.state_machine.is_in(&"Ladder") and not player.state_machine.is_in(&"Mantle")


func interact(player: Player) -> void:
	player.state_machine.transition_to(&"Ladder", {"ladder": self, "from_top": _is_at_top(player)})


func _is_at_top(player: Player) -> bool:
	return player.global_position.y > global_position.y + height * 0.6


func _build_default_zone() -> void:
	var foot := CollisionShape3D.new()
	var foot_box := BoxShape3D.new()
	foot_box.size = Vector3(1.2, height, 1.2)
	foot.shape = foot_box
	foot.position = Vector3(0.0, height * 0.5, 0.6)
	add_child(foot)
	var landing := CollisionShape3D.new()
	var landing_box := BoxShape3D.new()
	landing_box.size = Vector3(1.4, 1.6, 1.4)
	landing.shape = landing_box
	landing.position = Vector3(0.0, height + 0.8, -0.6)
	add_child(landing)
