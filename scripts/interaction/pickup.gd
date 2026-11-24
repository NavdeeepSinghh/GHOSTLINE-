class_name ThrowablePickup
extends Interactable
## A crate of bottles: refills Kael's throwables.

@export var amount: int = 3


func _ready() -> void:
	prompt = "Take bottles"
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.4, 0.4)
	crate.mesh = box
	crate.position.y = 0.2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.22, 0.14)
	material.roughness = 0.9
	crate.material_override = material
	add_child(crate)
	for i: int in 3:
		var bottle := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.025
		cylinder.bottom_radius = 0.05
		cylinder.height = 0.26
		bottle.mesh = cylinder
		bottle.position = Vector3(-0.15 + i * 0.15, 0.5, 0.0)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.3, 0.6, 0.4)
		glass.emission_enabled = true
		glass.emission = Color(0.2, 0.6, 0.35)
		glass.emission_energy_multiplier = 0.6
		bottle.material_override = glass
		add_child(bottle)


func can_interact(player: Player) -> bool:
	return player.throwables < player.combat.max_throwables


func interact(player: Player) -> void:
	if player.add_throwables(amount):
		EventBus.toast_requested.emit("Bottles restocked", 1.5)
