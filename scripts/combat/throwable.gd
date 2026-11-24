class_name Throwable
extends Ballistic
## A bottle Kael throws. Where it breaks it makes a loud noise that draws
## enemies; a direct hit stuns weaker ones.


func _ready() -> void:
	collision_mask = Player.LAYER_WORLD | Player.LAYER_ENEMY
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.025
	shape.bottom_radius = 0.05
	shape.height = 0.24
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.55, 0.4, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.1
	material.emission_enabled = true
	material.emission = Color(0.2, 0.5, 0.3)
	material.emission_energy_multiplier = 0.4
	mesh.material_override = material
	add_child(mesh)


func _process(delta: float) -> void:
	rotate_x(delta * 12.0)


func _on_impact(collider: Node, point: Vector3, normal: Vector3) -> void:
	var combat: CombatTuning = (source as Player).combat if source is Player else load(Player.DEFAULT_COMBAT_PATH)
	if collider != null and collider.has_method(&"receive_hit"):
		var hit := HitInfo.new()
		hit.attacker = source
		hit.origin = point - velocity.normalized()
		hit.damage = 4.0
		hit.poise = 0.0
		hit.stun = combat.throw_stun_time
		collider.call(&"receive_hit", hit)
	CombatFX.sfx(&"bottle_break", point, 2.0)
	CombatFX.impact(point, normal, true, 12)
	EventBus.noise_emitted.emit(point, combat.throw_noise_radius, self)
	queue_free()
