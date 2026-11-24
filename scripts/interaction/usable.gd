class_name Usable
extends Interactable
## A generic thing Kael can use with Interact: pickups, switches, panels,
## documents. The owner connects `used` and decides what happens.

signal used(player: Player)

@export var radius: float = 1.0
@export var one_shot: bool = false

var enabled: bool = true
## Optional glow that marks the object; hidden once a one-shot is used.
var beacon: Node3D


func _ready() -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.6
	add_child(collision)


func can_interact(_player: Player) -> bool:
	return enabled


func interact(player: Player) -> void:
	if not enabled:
		return
	if one_shot:
		set_enabled(false)
	used.emit(player)


func set_enabled(value: bool) -> void:
	enabled = value
	if beacon != null:
		beacon.visible = value


## Adds a small pulsing light so the object can be found in the dark.
func add_beacon(color: Color, height: float = 0.5, energy: float = 0.9) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 2.6
	light.position.y = height
	light.distance_fade_enabled = true
	light.distance_fade_begin = 30.0
	light.distance_fade_length = 8.0
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color * 1.6
	sphere.material = material
	mesh.mesh = sphere
	light.add_child(mesh)
	add_child(light)
	beacon = light
