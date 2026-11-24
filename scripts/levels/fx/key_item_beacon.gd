class_name KeyItemBeacon
extends Node3D
## Makes an objective item easy to spot: a soft column of light rising from
## it, a pulsing glow and a few sparkles. Visible through the rain from a
## distance; it goes away when the item is taken.

var color: Color = Color(1.0, 0.6, 0.15)
var height: float = 4.5

var _light: OmniLight3D
var _beam_material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.28
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_material.albedo_color = Color(color.r, color.g, color.b, 0.35)
	cylinder.material = _beam_material
	beam.mesh = cylinder
	beam.position.y = height * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 2.5
	_light.omni_range = 5.5
	_light.position.y = 0.6
	_light.light_volumetric_fog_energy = 2.0
	add_child(_light)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.3
	process.direction = Vector3.UP
	process.spread = 20.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0.0, 0.2, 0.0)
	process.color_ramp = CityFX._ramp([[0.0, Color(color.r, color.g, color.b, 0.0)], [0.3, Color(1.0, 0.95, 0.8, 1.0)], [1.0, Color(color.r, color.g, color.b, 0.0)]])
	add_child(CityFX._particles(14, 2.2, process, 0.05, true, AABB(Vector3(-2, -1, -2), Vector3(4, 7, 4))))


func _process(delta: float) -> void:
	_time += delta
	var wave: float = 0.5 + 0.5 * sin(_time * 3.0)
	if Accessibility.reduce_flashing():
		wave = 0.6
	_light.light_energy = lerpf(1.4, 3.2, wave)
	_beam_material.albedo_color.a = lerpf(0.18, 0.4, wave)
