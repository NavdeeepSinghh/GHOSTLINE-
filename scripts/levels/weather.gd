class_name Weather
extends Node3D
## Rain and distant lightning. The rain falls in a small volume that follows
## the camera, dulls the Hollows' hearing while it lasts, and switches to a
## muffled indoor sound when Kael is under a roof.

const STREAK_SHADER: String = "res://assets/shaders/rain_streak.gdshader"

## Enemy hearing distance is multiplied by this while it rains.
var hearing_scale: float = 0.7
var particle_counts: Dictionary = {"low": 900, "medium": 1800, "high": 3000}
var lightning_interval: Vector2 = Vector2(18.0, 45.0)
## The moon/sky light that lightning brightens.
var flash_light: DirectionalLight3D
var sheltered: bool = false
## The most recent bolt drawn (freed after a moment).
var last_bolt: LightningBolt

var _rain: GPUParticles3D
var _flash: float = 0.0
var _flash_base: float = 1.0
var _next_strike: float = 12.0
var _previous_hearing: float = 1.0


func _ready() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.lifetime = 0.9
	_rain.preprocess = 0.9
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-20.0, -20.0, -20.0), Vector3(40.0, 40.0, 40.0))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(14.0, 0.5, 14.0)
	process.direction = Vector3(0.12, -1.0, 0.05)
	process.spread = 2.0
	process.initial_velocity_min = 17.0
	process.initial_velocity_max = 21.0
	process.gravity = Vector3(0.0, -4.0, 0.0)
	_rain.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.55)
	var material := ShaderMaterial.new()
	material.shader = load(STREAK_SHADER)
	quad.material = material
	_rain.draw_pass_1 = quad
	add_child(_rain)
	_apply_quality()
	SettingsManager.graphics_applied.connect(_apply_quality)
	_previous_hearing = PerceptionComponent.hearing_scale
	PerceptionComponent.hearing_scale = hearing_scale
	_next_strike = randf_range(lightning_interval.x, lightning_interval.y) * 0.5
	if flash_light != null:
		_flash_base = flash_light.light_energy
	AudioManager.set_ambience(&"rain", &"rain_loop", -9.0)
	AudioManager.set_ambience(&"rain_interior", &"rain_interior_loop", AudioManager.SILENT_DB)
	AudioManager.set_ambience(&"wind", &"wind_loop", -17.0)


func _exit_tree() -> void:
	PerceptionComponent.hearing_scale = _previous_hearing


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		# Keep the rain volume a little ahead of the camera so it fills the view.
		var ahead: Vector3 = -camera.global_basis.z
		ahead.y = 0.0
		_rain.global_position = camera.global_position + ahead * 6.0 + Vector3.UP * 9.0
	_update_lightning(delta)


## Under a roof: the rain stops falling around the camera and sounds muffled.
func set_sheltered(value: bool) -> void:
	if value == sheltered:
		return
	sheltered = value
	_rain.emitting = not value
	AudioManager.set_ambience(&"rain", &"rain_loop", AudioManager.SILENT_DB if value else -9.0)
	AudioManager.set_ambience(&"rain_interior", &"rain_interior_loop", -12.0 if value else AudioManager.SILENT_DB)
	AudioManager.set_ambience(&"wind", &"wind_loop", -30.0 if value else -17.0)


## Fires a lightning flash now (also used by cinematics).
func strike() -> void:
	# With reduced flashing the thunder still rolls, but the sky does not flash.
	_flash = 0.0 if Accessibility.reduce_flashing() else 1.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	if _flash > 0.0 and camera != null and is_inside_tree():
		# A bolt somewhere in front of the camera, far beyond the streets.
		var ahead: Vector3 = -camera.global_basis.z
		ahead.y = 0.0
		ahead = ahead.normalized().rotated(Vector3.UP, randf_range(-0.3, 0.3)) if ahead.length() > 0.01 else Vector3.FORWARD
		# Inside the view distance (120 m on Low) so it is never clipped away.
		var distance: float = clampf(camera.far * randf_range(0.6, 0.75), 70.0, 170.0)
		var ground: Vector3 = camera.global_position + ahead * distance
		ground.y = 0.0
		var height: float = minf(110.0, sqrt(maxf(camera.far * camera.far - distance * distance, 400.0)) * 0.85)
		last_bolt = LightningBolt.make(ground, height)
		add_child(last_bolt)
		last_bolt.global_position = ground
	var delay: float = randf_range(0.6, 2.4)
	get_tree().create_timer(delay, false).timeout.connect(
			func() -> void: AudioManager.play_ui(StringName("thunder_%d" % randi_range(1, 2)), -8.0 if not sheltered else -16.0, &"Ambience"))


func _update_lightning(delta: float) -> void:
	_next_strike -= delta
	if _next_strike <= 0.0:
		_next_strike = randf_range(lightning_interval.x, lightning_interval.y)
		strike()
	if flash_light == null:
		return
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 2.4, 0.0)
		# Two quick pulses, like real lightning.
		var pulse: float = _flash * _flash * (0.6 + 0.4 * sin(_flash * 40.0))
		flash_light.light_energy = _flash_base * (1.0 + pulse * 5.0)
	else:
		flash_light.light_energy = _flash_base


func _apply_quality() -> void:
	var preset: String = str(SettingsManager.get_value("graphics", "preset"))
	_rain.amount = int(particle_counts.get(preset, particle_counts.get("medium", 1800)))
