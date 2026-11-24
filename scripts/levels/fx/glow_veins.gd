class_name GlowVeins
extends MultiMeshInstance3D
## Glowing Echo growth drawn in one go: a set of thin boxes sharing one
## emissive material that slowly pulses, as if something underneath breathes.

var color: Color = Color(0.27, 0.92, 1.0)
var pulse_seconds: float = 4.0
var base_energy: float = 2.4

var _material: StandardMaterial3D
var _time: float = 0.0


static func make(transforms: Array[Transform3D], tint: Color = Color(0.27, 0.92, 1.0)) -> GlowVeins:
	var veins := GlowVeins.new()
	veins.color = tint
	var mesh := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = tint * 0.3
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = veins.base_energy
	mesh.material = material
	veins._material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	veins.multimesh = multimesh
	veins.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return veins


func _process(delta: float) -> void:
	_time += delta
	var wave: float = 0.5 + 0.5 * sin(_time * TAU / pulse_seconds)
	if Accessibility.reduce_flashing():
		wave = 0.5
	_material.emission_energy_multiplier = base_energy * lerpf(0.45, 1.3, wave)
