class_name SparkEmitter
extends Node3D
## A broken cable that spits a shower of sparks every few seconds, with a
## brief blue-white light (no light with Reduce flashing on).

var interval: Vector2 = Vector2(1.5, 5.0)

var _particles: GPUParticles3D
var _light: OmniLight3D
var _wait: float = 1.0
var _light_time: float = 0.0


static func make(at: Vector3) -> SparkEmitter:
	var emitter := SparkEmitter.new()
	emitter.position = at
	return emitter


func _ready() -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.05
	process.direction = Vector3.DOWN
	process.spread = 70.0
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 4.0
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.color_ramp = CityFX._ramp([[0.0, Color(1.0, 1.0, 0.9, 1.0)], [0.4, Color(1.0, 0.8, 0.35, 1.0)], [1.0, Color(1.0, 0.4, 0.1, 0.0)]])
	_particles = CityFX._particles(int(18 * CityFX.amount_scale()), 0.8, process, 0.04, true, AABB(Vector3(-3, -5, -3), Vector3(6, 6, 6)))
	_particles.one_shot = true
	_particles.explosiveness = 0.85
	_particles.preprocess = 0.0
	_particles.emitting = false
	add_child(_particles)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.75, 0.85, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 4.0
	add_child(_light)
	_wait = randf_range(interval.x, interval.y)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = randf_range(interval.x, interval.y)
		_particles.restart()
		_particles.emitting = true
		_light_time = 0.0 if Accessibility.reduce_flashing() else 0.12
		AudioManager.play_sfx(&"switch", global_position, -18.0, 0.3)
	_light_time -= delta
	_light.light_energy = 2.5 if _light_time > 0.0 else 0.0
