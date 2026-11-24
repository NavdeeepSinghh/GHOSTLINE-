class_name HazardPuddle
extends Area3D
## A pool of Echo matter on the ground. Damages the player at intervals while
## they stand in it, then fades away.

const TICK_SECONDS: float = 0.5

var radius: float = 1.5
var seconds: float = 4.0
var damage_per_tick: float = 5.0

var _age: float = 0.0
var _tick: float = 0.15
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


static func echo_material(energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.25, 0.3)
	material.emission_enabled = true
	material.emission = GrayboxBuilder.COLOR_ECHO
	material.emission_energy_multiplier = energy
	return material


func _ready() -> void:
	add_to_group(&"transient")
	collision_layer = 0
	collision_mask = Player.LAYER_PLAYER
	monitoring = true
	monitorable = false
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.6
	add_child(collision)
	_mesh = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.03
	disc.radial_segments = 20
	_mesh.mesh = disc
	_mesh.position.y = 0.025
	_material = echo_material(0.5)
	_material.albedo_color = Color(0.02, 0.1, 0.12, 0.6)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= seconds:
		queue_free()
		return
	var fade: float = clampf((seconds - _age) / 0.8, 0.0, 1.0)
	_material.albedo_color.a = fade * 0.6
	_material.emission_energy_multiplier = (0.45 + sin(_age * 9.0) * 0.2) * fade
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK_SECONDS
	for body: Node3D in get_overlapping_bodies():
		if body.has_method(&"receive_hit"):
			var hit := HitInfo.new()
			hit.origin = global_position
			hit.damage = damage_per_tick
			hit.poise = 0.0
			hit.can_be_blocked = false
			hit.can_be_parried = false
			body.call(&"receive_hit", hit)
