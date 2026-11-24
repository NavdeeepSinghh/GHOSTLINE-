class_name Drip
extends Node3D
## Water leaking through the ceiling: a drop falls every couple of seconds into
## a glossy puddle, rings spread out and it plinks when Kael is near.
## Placed at the floor; `drop_height` is how far up the leak is.

const HEAR_DISTANCE: float = 12.0

var drop_height: float = 3.9
var interval: Vector2 = Vector2(1.2, 3.2)

var drops: int = 0
var _drop: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _ring_age: Array[float] = []
var _ring_material: StandardMaterial3D
var _next: float = 0.0
var _falling: float = -1.0
var _speed: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_next = _rng.randf_range(0.2, interval.y)
	var puddle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.004
	disc.radial_segments = 14
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(0.02, 0.025, 0.03, 0.45)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness = 0.03
	wet.metallic = 0.4
	wet.metallic_specular = 1.0
	disc.material = wet
	puddle.mesh = disc
	puddle.name = "Puddle"
	puddle.position.y = 0.006
	puddle.scale = Vector3(_rng.randf_range(0.8, 1.5), 1.0, _rng.randf_range(0.7, 1.2))
	puddle.rotation.y = _rng.randf() * TAU
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puddle)
	_drop = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.04
	sphere.radial_segments = 6
	sphere.rings = 3
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.7, 0.8, 0.85, 0.7)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.0
	water.emission_enabled = true
	water.emission = Color(0.2, 0.25, 0.28)
	sphere.material = water
	_drop.mesh = sphere
	_drop.visible = false
	_drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drop)
	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = Color(0.75, 0.82, 0.88, 0.5)
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.05
	torus.rings = 16
	torus.ring_segments = 3
	for i: int in 3:
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = _ring_material.duplicate()
		ring.position.y = 0.01
		ring.scale = Vector3(1.0, 0.1, 1.0)
		ring.visible = false
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
		_ring_age.append(-1.0)


func _process(delta: float) -> void:
	if _falling >= 0.0:
		_speed += 9.8 * delta
		_falling += _speed * delta
		_drop.position.y = drop_height - _falling
		if _drop.position.y <= 0.01:
			_splash()
	else:
		_next -= delta
		if _next <= 0.0:
			_falling = 0.0
			_speed = 0.0
			_drop.visible = true
			_drop.position = Vector3(0.0, drop_height, 0.0)
	for i: int in _rings.size():
		if _ring_age[i] < 0.0:
			continue
		_ring_age[i] += delta
		var t: float = _ring_age[i] / 0.9
		if t >= 1.0:
			_ring_age[i] = -1.0
			_rings[i].visible = false
			continue
		var size: float = 1.0 + t * 7.0
		_rings[i].scale = Vector3(size, 0.1, size)
		(_rings[i].material_override as StandardMaterial3D).albedo_color.a = 0.5 * (1.0 - t)


func _splash() -> void:
	drops += 1
	_falling = -1.0
	_drop.visible = false
	_next = _rng.randf_range(interval.x, interval.y)
	for i: int in _rings.size():
		if _ring_age[i] < 0.0:
			_ring_age[i] = 0.0
			_rings[i].visible = true
			break
	var kael: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if kael != null and kael.global_position.distance_to(global_position) < HEAR_DISTANCE:
		AudioManager.play_sfx(StringName("water_drip_%d" % _rng.randi_range(1, 2)), global_position, -14.0, 0.12)
