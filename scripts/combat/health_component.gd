class_name HealthComponent
extends Node
## Hit points for anything that can be hurt. Knows nothing about who owns it.

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

@export var max_health: float = 100.0

var health: float = 100.0


func _ready() -> void:
	health = max_health


func setup(maximum: float, current: float = -1.0) -> void:
	max_health = maximum
	health = maximum if current < 0.0 else minf(current, maximum)
	changed.emit(health, max_health)


func is_dead() -> bool:
	return health <= 0.0


func get_ratio() -> float:
	return health / maxf(max_health, 0.001)


## Returns the damage actually dealt.
func apply_damage(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return 0.0
	var dealt: float = minf(amount, health)
	health -= dealt
	changed.emit(health, max_health)
	damaged.emit(dealt)
	if health <= 0.0:
		died.emit()
	return dealt


func heal(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	health = minf(health + amount, max_health)
	changed.emit(health, max_health)


func revive() -> void:
	health = max_health
	changed.emit(health, max_health)
