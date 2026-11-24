class_name Footsteps
extends Node
## Plays Kael's footsteps: one step per stride of ground covered, with the
## sound set chosen by the surface under him. Louder when sprinting, nearly
## silent when crouched (the stealth noise itself is emitted by Player).

const SURFACES: PackedStringArray = ["concrete", "wet", "metal", "grass", "gravel"]
const VARIATIONS: int = 3

## Set by the current level: func(position: Vector3) -> String (a name in SURFACES).
static var surface_provider: Callable = Callable()

var steps_taken: int = 0
var last_surface: String = ""

var _player: Player
var _travelled: float = 0.0
var _last_position: Vector3
var _last_variation: int = 0


func _ready() -> void:
	_player = get_parent() as Player
	_last_position = _player.global_position
	EventBus.player_landed.connect(_on_landed)


func _physics_process(_delta: float) -> void:
	var position: Vector3 = _player.global_position
	var moved: float = Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if not _player.state_machine.is_in(&"Ground") or moved > 1.0:
		_travelled = 0.0
		return
	_travelled += moved
	var stride: float = 1.25
	var volume: float = -9.0
	match _player.move_mode:
		Player.MoveMode.SPRINT:
			stride = 1.7
			volume = -4.0
		Player.MoveMode.WALK:
			stride = 0.8
			volume = -15.0
		Player.MoveMode.CROUCH:
			stride = 0.65
			volume = -24.0
	if _travelled >= stride:
		_travelled = 0.0
		_play(volume)


static func get_surface(position: Vector3) -> String:
	if surface_provider.is_valid():
		return str(surface_provider.call(position))
	return "concrete"


func _play(volume_db: float) -> void:
	last_surface = get_surface(_player.global_position)
	var variation: int = (_last_variation + 1 + randi() % (VARIATIONS - 1)) % VARIATIONS
	_last_variation = variation
	steps_taken += 1
	AudioManager.play_sfx(StringName("step_%s_%d" % [last_surface, variation + 1]), _player.global_position, volume_db, 0.1)
	if last_surface == "wet" and _player.move_mode == Player.MoveMode.SPRINT:
		VFX.step_splash(_player.get_parent(), _player.global_position)


func _on_landed(impact_speed: float) -> void:
	if impact_speed > 2.0:
		_play(clampf(-12.0 + impact_speed, -10.0, 0.0))
