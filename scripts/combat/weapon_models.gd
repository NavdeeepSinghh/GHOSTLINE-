class_name WeaponModels
extends RefCounted
## Builds simple placeholder weapon models from primitives. The grip sits at the
## origin and the weapon points along +Y (the hand slot's "up").


static func build(look: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon"
	match look:
		"axe":
			_part(root, _cylinder(0.035, 1.05), Vector3(0, 0.42, 0), _metal(Color(0.32, 0.2, 0.12), 0.1, 0.8))
			_part(root, _box(Vector3(0.05, 0.3, 0.34)), Vector3(0, 0.82, 0.14), _metal(Color(0.62, 0.1, 0.08), 0.6, 0.45))
			_part(root, _box(Vector3(0.02, 0.34, 0.06)), Vector3(0, 0.82, 0.33), _metal(Color(0.8, 0.8, 0.82), 0.9, 0.25))
		"blade":
			_part(root, _cylinder(0.04, 0.3), Vector3(0, 0.02, 0), _metal(Color(0.1, 0.11, 0.13), 0.7, 0.4))
			_part(root, _box(Vector3(0.24, 0.04, 0.07)), Vector3(0, 0.18, 0), _metal(Color(0.1, 0.11, 0.13), 0.7, 0.4))
			var glow := StandardMaterial3D.new()
			glow.albedo_color = Color(0.1, 0.3, 0.34)
			glow.emission_enabled = true
			glow.emission = Color(0.27, 0.92, 1.0)
			glow.emission_energy_multiplier = 2.6
			_part(root, _box(Vector3(0.07, 1.0, 0.02)), Vector3(0, 0.7, 0), glow)
		_:
			_part(root, _cylinder(0.04, 1.1), Vector3(0, 0.4, 0), _metal(Color(0.3, 0.2, 0.15), 0.85, 0.6))
			_part(root, _cylinder(0.055, 0.12), Vector3(0, 0.9, 0), _metal(Color(0.25, 0.25, 0.27), 0.9, 0.5))
	return root


static func _part(root: Node3D, mesh: Mesh, at: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	root.add_child(instance)


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
