class_name TargetDummy
extends Node3D
## A practice target for lock-on: a post with a glowing core. Enemies will join
## the same "lock_on_target" group in Milestone 2.

@export var core_height: float = 1.25

var _core: MeshInstance3D
var _material: StandardMaterial3D
var _is_locked: bool = false


func _ready() -> void:
	add_to_group(CameraRig.LOCK_ON_GROUP)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.09
	post_mesh.bottom_radius = 0.16
	post_mesh.height = core_height
	post.mesh = post_mesh
	post.position.y = core_height * 0.5
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color(0.12, 0.13, 0.15)
	post_material.roughness = 0.6
	post_material.metallic = 0.6
	post.material_override = post_material
	add_child(post)

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.24
	core_mesh.height = 0.48
	_core.mesh = core_mesh
	_core.position.y = core_height + 0.2
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.05, 0.12, 0.14)
	_material.emission_enabled = true
	_material.emission = GrayboxBuilder.COLOR_ECHO
	_material.emission_energy_multiplier = 1.4
	_core.material_override = _material
	add_child(_core)

	var light := OmniLight3D.new()
	light.position.y = core_height + 0.2
	light.light_color = GrayboxBuilder.COLOR_ECHO
	light.light_energy = 0.7
	light.omni_range = 4.5
	add_child(light)

	var body := StaticBody3D.new()
	body.collision_layer = Player.LAYER_WORLD
	body.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 0.24
	shape.height = core_height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	body.add_child(collision)
	add_child(body)

	EventBus.lock_on_changed.connect(_on_lock_on_changed)


func _process(delta: float) -> void:
	_core.rotate_y(delta * 0.8)
	var pulse: float = 1.4 + sin(Time.get_ticks_msec() * 0.004) * 0.3
	_material.emission_energy_multiplier = lerpf(_material.emission_energy_multiplier,
			4.5 if _is_locked else pulse, 1.0 - exp(-8.0 * delta))


func get_lock_on_point() -> Vector3:
	return global_position + Vector3.UP * (core_height + 0.2)


func _on_lock_on_changed(target: Node3D) -> void:
	_is_locked = target == self
