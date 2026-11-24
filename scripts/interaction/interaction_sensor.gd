class_name InteractionSensor
extends Area3D
## Lives on the player. Tracks nearby Interactables, picks the closest usable
## one, publishes its prompt and triggers it when Interact is pressed.

var current: Interactable

var _player: Player
var _last_prompt: String = ""


func _ready() -> void:
	_player = get_parent() as Player
	collision_layer = 0
	collision_mask = Interactable.LAYER_INTERACTABLE
	monitoring = true
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = 1.1
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.9, 0.0)
	add_child(collision)


func _physics_process(_delta: float) -> void:
	current = _find_best()
	var text: String = ""
	# A silent takedown takes priority over anything else on the Interact button.
	var takedown: bool = _player.takedown_target != null
	if takedown:
		text = "%s   Takedown" % InputSetup.get_action_label("interact")
	elif current != null:
		text = "%s   %s" % [InputSetup.get_action_label("interact"), current.get_prompt(_player)]
	if text != _last_prompt:
		_last_prompt = text
		EventBus.interaction_prompt_changed.emit(text)
	if current != null and not takedown and _player.is_action_just_pressed(&"interact"):
		current.interact(_player)


func _find_best() -> Interactable:
	var best: Interactable = null
	var best_distance: float = INF
	for area: Area3D in get_overlapping_areas():
		var candidate: Interactable = area as Interactable
		if candidate == null or not candidate.can_interact(_player):
			continue
		var distance: float = candidate.global_position.distance_squared_to(_player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
