class_name RainSplashes
extends GPUParticles3D
## Raindrops bursting on the ground around Kael (not under cover). The emitter
## follows him at his feet, so the splashes are wherever he looks nearby.

var level: Node


func _ready() -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(11.0, 0.02, 11.0)
	process.direction = Vector3.UP
	process.spread = 35.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.4
	process.gravity = Vector3(0.0, -9.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.0
	process.color_ramp = CityFX._ramp([[0.0, Color(0.75, 0.82, 0.9, 0.7)], [1.0, Color(0.6, 0.7, 0.8, 0.0)]])
	amount = int(160 * CityFX.amount_scale())
	lifetime = 0.3
	process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	quad.material = CityFX._sprite_material(false)
	draw_pass_1 = quad
	visibility_aabb = AABB(Vector3(-13, -1, -13), Vector3(26, 3, 26))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		emitting = false
		return
	global_position = player.global_position + Vector3(0.0, 0.03, 0.0)
	var covered: bool = level != null and level.has_method(&"is_sheltered") and bool(level.call(&"is_sheltered", player.global_position))
	emitting = not covered
