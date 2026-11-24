class_name StealthZone
extends Area3D
## A volume that changes how visible Kael is: deep shadow shortens enemy
## sight; tall grass hides him almost completely while he crouches.

enum Kind { SHADOW, HIDING }

@export var kind: Kind = Kind.SHADOW
@export var size: Vector3 = Vector3(4.0, 2.5, 4.0)


func _ready() -> void:
	collision_layer = 0
	collision_mask = Player.LAYER_PLAYER
	monitoring = true
	monitorable = false
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)
	body_entered.connect(_on_body.bind(1))
	body_exited.connect(_on_body.bind(-1))


func _on_body(body: Node3D, change: int) -> void:
	var player: Player = body as Player
	if player == null:
		return
	if kind == Kind.SHADOW:
		player.shadow_zones = maxi(player.shadow_zones + change, 0)
	else:
		player.hide_zones = maxi(player.hide_zones + change, 0)
