class_name VFX
extends Node
## One-shot visual effects tied to gameplay events: dust when Kael lands or
## dodges, splashes on wet ground, and an Echo burst when an enemy dies.
## Game adds one VFX node; it listens on the EventBus and spawns effects into
## the world. Counts come from data/vfx.json and follow the graphics preset.

const DATA_PATH: String = "res://data/vfx.json"

static var _data: Dictionary = {}

var world: Node


static func value(key: String) -> float:
	if _data.is_empty():
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return float(_data.get(key, 0.0))


static func count(key: String) -> int:
	return maxi(int(round(value(key) * CityFX.amount_scale())), 1)


func _ready() -> void:
	EventBus.player_landed.connect(_on_landed)
	EventBus.player_state_changed.connect(_on_player_state)
	EventBus.enemy_died.connect(_on_enemy_died)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _on_landed(impact_speed: float) -> void:
	var player: Node3D = _player()
	if player == null or impact_speed < value("landing_min_speed"):
		return
	_spawn(ground_burst(player.global_position, Footsteps.get_surface(player.global_position) == "wet", count("landing_dust")))


func _on_player_state(_previous: StringName, current: StringName) -> void:
	if current != &"Dodge":
		return
	var player: Node3D = _player()
	if player != null:
		_spawn(ground_burst(player.global_position, Footsteps.get_surface(player.global_position) == "wet", count("dodge_dust")))


func _on_enemy_died(enemy: Node3D) -> void:
	if enemy != null and is_instance_valid(enemy):
		_spawn(echo_burst(enemy.global_position + Vector3.UP * 1.0))


func _spawn(effect: Node3D) -> void:
	var parent: Node = world if world != null and is_instance_valid(world) else get_tree().current_scene
	if parent == null:
		effect.free()
		return
	var at: Vector3 = effect.position
	parent.add_child(effect)
	effect.global_position = at


## A splash at a footstep on wet ground (called by Footsteps).
static func step_splash(parent: Node, at: Vector3) -> void:
	if parent == null:
		return
	var effect: GPUParticles3D = ground_burst(at, true, count("step_splash"))
	parent.add_child(effect)
	effect.global_position = at


# --- Builders (return a node positioned in world space; it frees itself) ---------

static func _one_shot(particles: GPUParticles3D, at: Vector3) -> GPUParticles3D:
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.preprocess = 0.0
	particles.emitting = true
	particles.position = at
	# A timer rather than the `finished` signal: it also fires when particles are
	# not simulated (headless runs), so nothing is ever left behind.
	var timer := Timer.new()
	timer.one_shot = true
	timer.autostart = true
	timer.wait_time = particles.lifetime + 0.3
	timer.timeout.connect(particles.queue_free)
	particles.add_child(timer)
	return particles


## Dust (dry ground) or a spray of droplets (wet ground) kicked up at the feet.
static func ground_burst(at: Vector3, wet: bool, amount: int) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.35
	process.emission_ring_inner_radius = 0.1
	process.emission_ring_height = 0.05
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 75.0
	process.radial_velocity_min = 0.8
	process.radial_velocity_max = 1.8
	var lifetime: float
	var size: float
	if wet:
		process.initial_velocity_min = 1.2
		process.initial_velocity_max = 2.4
		process.gravity = Vector3(0.0, -9.0, 0.0)
		process.color_ramp = CityFX._ramp([[0.0, Color(0.75, 0.82, 0.9, 0.55)], [1.0, Color(0.6, 0.68, 0.75, 0.0)]])
		process.scale_min = 0.4
		process.scale_max = 0.8
		lifetime = 0.45
		size = 0.07
	else:
		process.initial_velocity_min = 0.3
		process.initial_velocity_max = 0.9
		process.gravity = Vector3(0.0, 0.15, 0.0)
		process.damping_min = 1.5
		process.damping_max = 2.5
		process.scale_curve = CityFX._curve([Vector2(0.0, 0.4), Vector2(1.0, 1.0)])
		process.color_ramp = CityFX._ramp([[0.0, Color(0.42, 0.4, 0.36, 0.0)], [0.15, Color(0.4, 0.38, 0.34, 0.22)], [1.0, Color(0.36, 0.34, 0.3, 0.0)]])
		lifetime = 1.1
		size = 0.7
	var particles: GPUParticles3D = CityFX._particles(amount, lifetime, process, size, false, AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6)))
	return _one_shot(particles, at + Vector3(0.0, 0.05, 0.0))


## An enemy dies: Echo-blue sparks and a fading mist lift out of the body.
static func echo_burst(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	var sparks := ParticleProcessMaterial.new()
	sparks.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.5
	sparks.direction = Vector3.UP
	sparks.spread = 60.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 3.5
	sparks.gravity = Vector3(0.0, 0.6, 0.0)
	sparks.damping_min = 1.0
	sparks.damping_max = 2.0
	sparks.turbulence_enabled = true
	sparks.turbulence_noise_strength = 1.5
	sparks.color_ramp = CityFX._ramp([[0.0, Color(0.6, 1.0, 1.0, 1.0)], [0.5, Color(0.27, 0.92, 1.0, 0.8)], [1.0, Color(0.1, 0.4, 0.6, 0.0)]])
	root.add_child(_one_shot(CityFX._particles(count("death_sparks"), 1.4, sparks, 0.09, true, AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))), Vector3.ZERO))
	var mist := ParticleProcessMaterial.new()
	mist.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 0.4
	mist.direction = Vector3.UP
	mist.spread = 30.0
	mist.initial_velocity_min = 0.3
	mist.initial_velocity_max = 0.8
	mist.gravity = Vector3(0.0, 0.3, 0.0)
	mist.scale_curve = CityFX._curve([Vector2(0.0, 0.5), Vector2(1.0, 1.4)])
	mist.color_ramp = CityFX._ramp([[0.0, Color(0.27, 0.92, 1.0, 0.0)], [0.2, Color(0.27, 0.92, 1.0, 0.18)], [1.0, Color(0.1, 0.5, 0.6, 0.0)]])
	var cloud: GPUParticles3D = _one_shot(CityFX._particles(count("death_mist"), 1.8, mist, 1.2, true, AABB(Vector3(-3, -2, -3), Vector3(6, 7, 6))), Vector3.ZERO)
	root.add_child(cloud)
	# The root goes when its longest-lived part does.
	cloud.tree_exiting.connect(root.queue_free)
	return root


## Embers streaming along the Warden's flame (added to its flame visual).
static func flame_embers(length: float) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.3
	process.direction = Vector3(0.0, 0.0, 1.0)
	process.spread = 14.0
	process.initial_velocity_min = length * 0.9
	process.initial_velocity_max = length * 1.4
	process.gravity = Vector3(0.0, 1.5, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 2.0
	process.scale_min = 0.5
	process.scale_max = 1.2
	process.color_ramp = CityFX._ramp([[0.0, Color(1.0, 0.85, 0.5, 1.0)], [0.6, Color(1.0, 0.4, 0.1, 0.8)], [1.0, Color(0.5, 0.1, 0.02, 0.0)]])
	var particles: GPUParticles3D = CityFX._particles(count("flame_embers"), 0.9, process, 0.12, true,
			AABB(Vector3(-length, -3, -2), Vector3(length * 2.0, 8, length * 1.6)))
	particles.preprocess = 0.0
	return particles


## Effects drawn once behind the loading screen so their shaders compile early.
static func warm_up_set() -> Array[Node3D]:
	var effects: Array[Node3D] = []
	effects.append(ground_burst(Vector3(-1.0, -1.0, 0.0), false, 2))
	effects.append(ground_burst(Vector3(1.0, -1.0, 0.0), true, 2))
	effects.append(echo_burst(Vector3(0.0, 0.0, 0.0)))
	effects.append(flame_embers(4.0))
	return effects
