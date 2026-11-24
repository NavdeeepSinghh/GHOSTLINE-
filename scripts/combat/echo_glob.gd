class_name EchoGlob
extends Ballistic
## A Spitter's shot: an arcing glob of Echo matter. Hurts on a direct hit and
## leaves a puddle that keeps hurting anyone who stands in it.

var damage: float = 14.0
var puddle_radius: float = 1.5
var puddle_seconds: float = 4.0
var puddle_damage_per_tick: float = 5.0


func _ready() -> void:
	gravity = 12.0
	collision_mask = Player.LAYER_WORLD | Player.LAYER_PLAYER
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.material_override = HazardPuddle.echo_material(3.0)
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = GrayboxBuilder.COLOR_ECHO
	light.light_energy = 1.2
	light.omni_range = 3.5
	add_child(light)


func _on_impact(collider: Node, point: Vector3, _normal: Vector3) -> void:
	if collider != null and collider.has_method(&"receive_hit"):
		var hit := HitInfo.new()
		hit.attacker = source
		hit.origin = point - velocity.normalized()
		hit.damage = damage
		hit.poise = 14.0
		hit.can_be_parried = false
		collider.call(&"receive_hit", hit)
	CombatFX.sfx(&"splat", point)
	var puddle := HazardPuddle.new()
	puddle.radius = puddle_radius
	puddle.seconds = puddle_seconds
	puddle.damage_per_tick = puddle_damage_per_tick
	get_parent().add_child(puddle)
	var ground: Vector3 = point
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point + Vector3.DOWN * 3.0, Player.LAYER_WORLD)
	var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty():
		ground = floor_hit["position"]
	puddle.global_position = ground
	queue_free()
