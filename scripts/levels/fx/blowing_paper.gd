class_name BlowingPaper
extends GPUParticles3D
## Old newspapers and flyers skittering down the street in the wind, around
## Kael. None under cover.

const WIND: Vector3 = Vector3(1.0, 0.0, 0.35)

var level: Node


func _ready() -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(14.0, 0.05, 14.0)
	process.direction = WIND.normalized() + Vector3(0.0, 0.08, 0.0)
	process.spread = 18.0
	process.initial_velocity_min = 1.4
	process.initial_velocity_max = 3.2
	process.gravity = Vector3(0.0, -0.4, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 2.0
	process.turbulence_noise_scale = 3.0
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.15
	process.particle_flag_rotate_y = true
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -200.0
	process.angular_velocity_max = 200.0
	process.scale_min = 0.7
	process.scale_max = 1.3
	process.color_ramp = CityFX._ramp([[0.0, Color(1, 1, 1, 0)], [0.1, Color(1, 1, 1, 1)], [0.85, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]])
	process.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	process_material = process
	amount = maxi(3, int(10 * CityFX.amount_scale()))
	lifetime = 6.0
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(0.34, 0.25)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.62, 0.6, 0.53)
	paper.vertex_color_use_as_albedo = true
	paper.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.roughness = 0.95
	sheet.material = paper
	draw_pass_1 = sheet
	visibility_aabb = AABB(Vector3(-20, -1, -20), Vector3(40, 4, 40))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	local_coords = false


func _process(_delta: float) -> void:
	var kael: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if kael == null:
		emitting = false
		return
	# Upwind of Kael so the sheets blow past him.
	global_position = Vector3(kael.global_position.x, 0.06, kael.global_position.z) - WIND.normalized() * 6.0
	var covered: bool = level != null and level.has_method(&"is_sheltered") and bool(level.call(&"is_sheltered", kael.global_position))
	emitting = not covered and kael.global_position.y > -1.0
