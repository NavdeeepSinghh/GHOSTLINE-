class_name LightningBolt
extends MeshInstance3D
## A jagged bolt in the distant sky for a moment (with branches), drawn as
## crossed glowing ribbons that ignore the fog. Frees itself.

const LIFETIME: float = 0.45

var _age: float = 0.0
var _material: StandardMaterial3D


## A bolt from high above `ground` down to it, `seed` for repeatable shapes in tests.
static func make(ground: Vector3, height: float = 110.0, seed: int = -1) -> LightningBolt:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	var bolt := LightningBolt.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var main: PackedVector3Array = _path(rng, Vector3(0.0, height, 0.0), Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-12.0, 12.0)), 14, 6.0)
	_ribbon(surface, main, 2.2)
	for branch: int in rng.randi_range(1, 3):
		var start: Vector3 = main[rng.randi_range(2, main.size() - 5)]
		var end: Vector3 = start + Vector3(rng.randf_range(-30.0, 30.0), -rng.randf_range(15.0, 40.0), rng.randf_range(-30.0, 30.0))
		_ribbon(surface, _path(rng, start, end, 6, 3.5), 1.1)
	bolt.mesh = surface.commit()
	bolt._material = StandardMaterial3D.new()
	bolt._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt._material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bolt._material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bolt._material.disable_fog = true
	bolt._material.albedo_color = Color(0.85, 0.92, 1.0)
	bolt.material_override = bolt._material
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.position = ground
	return bolt


static func _path(rng: RandomNumberGenerator, from: Vector3, to: Vector3, steps: int, jitter: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var point: Vector3 = from.lerp(to, t)
		if i > 0 and i < steps:
			point += Vector3(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter) * 0.3, rng.randf_range(-jitter, jitter))
		points.append(point)
	return points


static func _ribbon(surface: SurfaceTool, points: PackedVector3Array, width: float) -> void:
	for i: int in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var taper: float = width * (1.0 - float(i) / float(points.size()) * 0.6)
		for side: Vector3 in [Vector3(taper, 0.0, 0.0), Vector3(0.0, 0.0, taper)]:
			# Real normals: a mesh without them can put NaNs into the glow pass.
			var normal: Vector3 = side.cross(b - a).normalized()
			if not normal.is_finite() or normal.is_zero_approx():
				normal = Vector3.BACK
			surface.set_normal(normal)
			surface.set_uv(Vector2.ZERO)
			surface.add_vertex(a - side)
			surface.add_vertex(a + side)
			surface.add_vertex(b + side)
			surface.add_vertex(a - side)
			surface.add_vertex(b + side)
			surface.add_vertex(b - side)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# Bright, a flicker off, bright again, then gone.
	var on: bool = _age < 0.08 or (_age > 0.14 and _age < 0.3)
	var fade: float = 1.0 - _age / LIFETIME
	_material.albedo_color.a = (1.0 if on else 0.15) * fade
