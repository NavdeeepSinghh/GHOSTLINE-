extends PlayerState
## Kael is down. The game respawns him at the last checkpoint.


func enter(_previous: StringName, _message: Dictionary) -> void:
	player.is_sprinting = false
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.hitbox.end()
	player.visuals.play_action(&"Death_A")
	CombatFX.sfx(&"death", player.global_position + Vector3.UP)
	EventBus.player_died.emit()


func physics_update(delta: float) -> void:
	player.accelerate_horizontal(Vector3.ZERO, 0.0, 20.0, delta)
	player.ground_move(delta)
