extends Node
## Combat feedback in one place: hit-stop, impact particles, camera shake,
## controller rumble and sounds. Autoloaded as CombatFX.

## Tests turn this off so simulated time is never stretched.
var hitstop_enabled: bool = true

var _hitstop_serial: int = 0
var _spark_material: StandardMaterial3D
var _static_material: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spark_material = _particle_material(Color(1.0, 0.75, 0.35), 3.0)
	_static_material = _particle_material(Color(0.02, 0.02, 0.03), 0.0)


## Freezes the action for a moment so a hit feels like it connected.
func hit_stop(seconds: float) -> void:
	if not hitstop_enabled or seconds <= 0.0:
		return
	_hitstop_serial += 1
	var serial: int = _hitstop_serial
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	if serial == _hitstop_serial:
		Engine.time_scale = 1.0


func shake(trauma: float) -> void:
	EventBus.camera_shake_requested.emit(trauma)


func rumble(weak: float, strong: float, seconds: float) -> void:
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, seconds)


## Hollows bleed black static; armour and blocks throw sparks.
func impact(position: Vector3, direction: Vector3, sparks: bool, amount: int = 14) -> void:
	var tree: SceneTree = get_tree()
	if tree.current_scene == null:
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = 0.45 if sparks else 0.6
	particles.direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.5 if sparks else 4.0
	particles.gravity = Vector3(0.0, -9.0, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 0.14) if sparks else Vector3(0.07, 0.07, 0.07)
	mesh.material = _spark_material if sparks else _static_material
	particles.mesh = mesh
	tree.current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	tree.create_timer(1.2).timeout.connect(particles.queue_free)


func sfx(sound: StringName, position: Vector3, volume_db: float = 0.0) -> void:
	AudioManager.play_sfx(sound, position, volume_db)


func _particle_material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
