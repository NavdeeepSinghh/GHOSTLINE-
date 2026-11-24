class_name TriggerZone
extends Area3D
## A box that reports when Kael walks into it (story beats, checkpoints, tutorials).

signal triggered(player: Player)

@export var size: Vector3 = Vector3(4.0, 3.0, 4.0)
@export var one_shot: bool = true

var enabled: bool = true


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
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or not enabled:
		return
	if one_shot:
		enabled = false
	triggered.emit(player)
