class_name CityBuilder
extends Node3D
## Builds the Dead City's static world from simple calls and keeps it cheap:
## every box of one look is a single MultiMesh draw call, and all collision
## lives on two static bodies (plain and climbable) assembled off-tree.
##
## Looks share one world-space shader (assets/shaders/city_surface.gdshader),
## so walls, streets and facades need no textures or UVs.

enum Look { ASPHALT, CONCRETE, FACADE, METAL, INTERIOR, RUBBLE, EARTH, PANEL }

const SHADER_PATH: String = "res://assets/shaders/city_surface.gdshader"
const HEADING_FONT_PATH: String = "res://assets/fonts/Rajdhani-SemiBold.ttf"

const COLOR_ASPHALT := Color(0.085, 0.09, 0.1)
const COLOR_SIDEWALK := Color(0.2, 0.2, 0.21)
const COLOR_CONCRETE := Color(0.26, 0.26, 0.27)
const COLOR_DARK := Color(0.1, 0.105, 0.115)
const COLOR_RUST := Color(0.3, 0.16, 0.09)
const COLOR_PAINT := Color(0.95, 0.72, 0.1)
const COLOR_ECHO := Color(0.27, 0.92, 1.0)
const COLOR_SODIUM := Color(1.0, 0.56, 0.2)
const COLOR_MAGENTA := Color(1.0, 0.2, 0.6)
const COLOR_RED := Color(1.0, 0.12, 0.08)
const COLOR_WARM := Color(1.0, 0.82, 0.6)
const COLOR_VINE := Color(0.07, 0.15, 0.08)
const FACADE_TINTS: Array[Color] = [
	Color(0.24, 0.22, 0.21), Color(0.19, 0.2, 0.22), Color(0.27, 0.21, 0.17),
	Color(0.16, 0.17, 0.18), Color(0.22, 0.24, 0.23), Color(0.3, 0.27, 0.24),
]

## Look -> settings for the shared shader.
const LOOK_SETTINGS: Dictionary = {
	Look.ASPHALT: {"base_roughness": 0.9, "wetness": 0.85, "puddle_amount": 1.0, "road_markings": 1.0, "ripple_strength": 1.0},
	Look.CONCRETE: {"base_roughness": 0.86, "wetness": 0.7, "puddle_amount": 0.35, "seams": 1.0, "seam_size": 2.4},
	Look.FACADE: {"base_roughness": 0.88, "wetness": 0.6, "windows": 1.0},
	Look.METAL: {"base_roughness": 0.55, "wetness": 0.8, "metallic_amount": 0.7, "puddle_amount": 0.2},
	Look.INTERIOR: {"base_roughness": 0.8, "wetness": 0.0, "seams": 1.0, "seam_size": 1.2},
	Look.RUBBLE: {"base_roughness": 0.95, "wetness": 0.5},
	Look.EARTH: {"base_roughness": 0.97, "wetness": 0.15},
	Look.PANEL: {"base_roughness": 0.45, "wetness": 0.0, "seams": 1.0, "seam_size": 1.5},
}

var _world_body: StaticBody3D
var _climb_body: StaticBody3D
## Look -> [transforms, colors]
var _boxes: Dictionary = {}
## emissive colour -> transforms
var _strips: Dictionary = {}
var _paint: Array[Transform3D] = []
var _font: Font
var _random := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _box_count: int = 0


func _init() -> void:
	_world_body = StaticBody3D.new()
	_world_body.name = "WorldCollision"
	_world_body.collision_layer = Player.LAYER_WORLD
	_world_body.collision_mask = 0
	_climb_body = StaticBody3D.new()
	_climb_body.name = "ClimbableCollision"
	_climb_body.collision_layer = Player.LAYER_WORLD | Player.LAYER_CLIMBABLE
	_climb_body.collision_mask = 0
	_font = load(HEADING_FONT_PATH)
	_random.seed = 2097


func get_box_count() -> int:
	return _box_count


# --- Primitive pieces ---------------------------------------------------------

## A box by centre and size. `yaw` in degrees.
func box(center: Vector3, size: Vector3, look: Look = Look.CONCRETE, color: Color = COLOR_CONCRETE,
		collide: bool = true, climbable: bool = false, yaw: float = 0.0, tilt: Vector3 = Vector3.ZERO) -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(tilt.x), deg_to_rad(yaw), deg_to_rad(tilt.z)))
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = Transform3D(basis, center)
		(_climb_body if climbable else _world_body).add_child(collision)
	_push(look, Transform3D(basis * Basis.from_scale(size), center), color)
	if climbable:
		_add_paint_edges(center, size)


## A thin square-section bar from `a` to `b` (cables, rails, pipes). Visual only.
func segment(a: Vector3, b: Vector3, thickness: float, look: Look = Look.METAL, color: Color = COLOR_DARK) -> void:
	var along: Vector3 = b - a
	var length: float = along.length()
	if length < 0.001:
		return
	var z_axis: Vector3 = along / length
	var up: Vector3 = Vector3.UP if absf(z_axis.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x_axis: Vector3 = up.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis)
	_push(look, Transform3D(Basis(x_axis * thickness, y_axis * thickness, z_axis * length), (a + b) * 0.5), color)


func _push(look: Look, transform: Transform3D, color: Color) -> void:
	if not _boxes.has(look):
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		_boxes[look] = [transforms, colors]
	(_boxes[look][0] as Array[Transform3D]).append(transform)
	(_boxes[look][1] as Array[Color]).append(color)
	_box_count += 1


## Invisible collision only (for shapes drawn by tilted or decorative pieces).
func collider(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	_world_body.add_child(collision)


## A box standing on `base_y`, given by its footprint corners.
func block(x0: float, z0: float, x1: float, z1: float, height: float, base_y: float = 0.0,
		look: Look = Look.CONCRETE, color: Color = COLOR_CONCRETE, climbable: bool = false, collide: bool = true) -> void:
	box(Vector3((x0 + x1) * 0.5, base_y + height * 0.5, (z0 + z1) * 0.5),
			Vector3(absf(x1 - x0), height, absf(z1 - z0)), look, color, collide, climbable)


## A walkable slab from `low` to `high` (centre points of its two ends).
func ramp(low: Vector3, high: Vector3, width: float, look: Look = Look.CONCRETE,
		color: Color = COLOR_CONCRETE, thickness: float = 0.4) -> void:
	var along: Vector3 = high - low
	var forward: Vector3 = along.normalized()
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	var normal: Vector3 = side.cross(forward).normalized()
	var basis := Basis(side, normal, -forward)
	var center: Vector3 = (low + high) * 0.5 - normal * thickness * 0.5
	var size := Vector3(width, thickness, along.length())
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(basis, center)
	_world_body.add_child(collision)
	if not _boxes.has(look):
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		_boxes[look] = [transforms, colors]
	(_boxes[look][0] as Array[Transform3D]).append(Transform3D(basis * Basis.from_scale(size), center))
	(_boxes[look][1] as Array[Color]).append(color)
	_box_count += 1


## Ground slab covering `area` (x/z rectangle, top at `top_y`) with rectangular holes cut out.
func ground(area: Rect2, holes: Array[Rect2] = [], look: Look = Look.ASPHALT, color: Color = COLOR_ASPHALT,
		top_y: float = 0.0, thickness: float = 1.0) -> void:
	var pieces: Array[Rect2] = [area]
	for hole: Rect2 in holes:
		var next: Array[Rect2] = []
		for piece: Rect2 in pieces:
			next.append_array(subtract_rect(piece, hole))
		pieces = next
	for piece: Rect2 in pieces:
		block(piece.position.x, piece.position.y, piece.end.x, piece.end.y, thickness, top_y - thickness, look, color)


## `piece` minus `hole`, as up to four rectangles.
static func subtract_rect(piece: Rect2, hole: Rect2) -> Array[Rect2]:
	var cut: Rect2 = piece.intersection(hole)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return [piece]
	var result: Array[Rect2] = []
	if cut.position.y > piece.position.y:
		result.append(Rect2(piece.position.x, piece.position.y, piece.size.x, cut.position.y - piece.position.y))
	if cut.end.y < piece.end.y:
		result.append(Rect2(piece.position.x, cut.end.y, piece.size.x, piece.end.y - cut.end.y))
	if cut.position.x > piece.position.x:
		result.append(Rect2(piece.position.x, cut.position.y, cut.position.x - piece.position.x, cut.size.y))
	if cut.end.x < piece.end.x:
		result.append(Rect2(cut.end.x, cut.position.y, piece.end.x - cut.end.x, cut.size.y))
	return result


## A glowing strip (sign tube, lamp head, indicator). Purely visual.
func strip(center: Vector3, size: Vector3, color: Color = COLOR_ECHO, yaw: float = 0.0) -> void:
	if not _strips.has(color):
		var list: Array[Transform3D] = []
		_strips[color] = list
	(_strips[color] as Array[Transform3D]).append(
			Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)) * Basis.from_scale(size), center))


## Text in the world. `yaw` 0 faces +Z.
func sign_text(text: String, at: Vector3, yaw: float = 0.0, size: float = 1.0,
		color: Color = Color(0.92, 0.9, 0.86), flat_on_ground: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 96
	label.pixel_size = 0.0042 * size
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	label.position = at
	label.rotation_degrees = Vector3(-90.0 if flat_on_ground else 0.0, yaw, 0.0)
	label.visibility_range_end = 90.0
	add_child(label)
	return label


# --- City pieces --------------------------------------------------------------

## A solid building with a windowed facade and a parapet.
func building(x0: float, z0: float, x1: float, z1: float, height: float, base_y: float = 0.0, tint: int = -1) -> void:
	var color: Color = FACADE_TINTS[tint if tint >= 0 else _random.randi() % FACADE_TINTS.size()]
	block(x0, z0, x1, z1, height, base_y, Look.FACADE, color)
	# Parapet lip and a few roof boxes break up the silhouette (no collision needed up there).
	var top: float = base_y + height
	block(x0 - 0.15, z0 - 0.15, x1 + 0.15, z1 + 0.15, 0.35, top, Look.CONCRETE, color * 0.8, false, false)
	if absf(x1 - x0) > 8.0 and absf(z1 - z0) > 8.0:
		var rx: float = lerpf(x0, x1, _random.randf_range(0.25, 0.7))
		var rz: float = lerpf(z0, z1, _random.randf_range(0.25, 0.7))
		block(rx, rz, rx + 3.0, rz + 2.4, _random.randf_range(1.4, 2.6), top, Look.CONCRETE, COLOR_DARK, false, false)
		block(rx - 4.0, rz + 1.0, rx - 2.6, rz + 2.4, 1.0, top, Look.METAL, COLOR_DARK, false, false)


## Four walls with door gaps and a ceiling: an enterable ground-floor room.
## `doors` entries: [side ("n", "s", "e", "w"), position along that wall, width].
func room(x0: float, z0: float, x1: float, z1: float, height: float, doors: Array = [],
		color: Color = Color(0.3, 0.29, 0.27), base_y: float = 0.0, with_ceiling: bool = true, look: Look = Look.INTERIOR) -> void:
	var t: float = 0.3
	var door_height: float = 2.4
	for side: String in ["n", "s", "e", "w"]:
		var horizontal: bool = side == "n" or side == "s"
		var from: float = x0 if horizontal else z0
		var to: float = x1 if horizontal else z1
		var fixed: float = z0 if side == "n" else (z1 if side == "s" else (x1 if side == "e" else x0))
		var gaps: Array[Vector2] = []
		for door: Array in doors:
			if str(door[0]) == side:
				gaps.append(Vector2(float(door[1]) - float(door[2]) * 0.5, float(door[1]) + float(door[2]) * 0.5))
		gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cursor: float = from
		for gap: Vector2 in gaps:
			_wall_piece(horizontal, cursor, gap.x, fixed, t, base_y, height, color, look)
			# Lintel over the doorway.
			_wall_piece(horizontal, gap.x, gap.y, fixed, t, base_y + door_height, height - door_height, color, look)
			cursor = gap.y
		_wall_piece(horizontal, cursor, to, fixed, t, base_y, height, color, look)
	if with_ceiling:
		block(x0, z0, x1, z1, 0.3, base_y + height, look, color * 0.7)


func _wall_piece(horizontal: bool, from: float, to: float, fixed: float, thickness: float,
		base_y: float, height: float, color: Color, look: Look = Look.INTERIOR) -> void:
	if to - from < 0.02 or height <= 0.0:
		return
	if horizontal:
		block(from, fixed - thickness * 0.5, to, fixed + thickness * 0.5, height, base_y, look, color)
	else:
		block(fixed - thickness * 0.5, from, fixed + thickness * 0.5, to, height, base_y, look, color)


## A street lamp. Dead lamps are just posts; lit ones carry a sodium light.
func lamp(x: float, z: float, lit: bool = true, color: Color = COLOR_SODIUM, height: float = 5.6,
		energy: float = 3.2, casts_shadow: bool = false, base_y: float = 0.0, flicker: bool = false) -> OmniLight3D:
	box(Vector3(x, base_y + height * 0.5, z), Vector3(0.16, height, 0.16), Look.METAL, COLOR_DARK)
	box(Vector3(x, base_y + height, z), Vector3(1.3, 0.1, 0.24), Look.METAL, COLOR_DARK, false)
	if not lit:
		return null
	strip(Vector3(x, base_y + height - 0.08, z), Vector3(0.9, 0.07, 0.2), color)
	return point_light(Vector3(x, base_y + height - 0.5, z), color, energy, 15.0, casts_shadow, flicker)


func point_light(at: Vector3, color: Color, energy: float, light_range: float, casts_shadow: bool = false,
		flicker: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	if flicker:
		light.set_script(load("res://scripts/levels/flicker_light.gd"))
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.25
	light.shadow_enabled = casts_shadow
	light.light_volumetric_fog_energy = 1.4
	light.distance_fade_enabled = true
	light.distance_fade_begin = 55.0
	light.distance_fade_length = 15.0
	light.distance_fade_shadow = 32.0
	add_child(light)
	return light


## A neon sign: glowing text, a tube under it, and coloured light spilling on the street.
func neon(text: String, at: Vector3, yaw: float, color: Color = COLOR_MAGENTA, size: float = 1.6,
		flicker: bool = true, energy: float = 2.4) -> void:
	var label: Label3D = sign_text(text, at, yaw, size, color)
	label.modulate = color * 1.8
	var forward := Vector3(sin(deg_to_rad(yaw)), 0.0, cos(deg_to_rad(yaw)))
	var width: float = float(text.length()) * 0.2 * size
	strip(at - Vector3(0.0, 0.3 * size, 0.0) - forward * 0.02, Vector3(width, 0.05, 0.05), color, yaw)
	var light: OmniLight3D = point_light(at + forward * 1.2 - Vector3(0.0, 0.6, 0.0), color, energy, 8.0, false, flicker)
	if flicker:
		light.set(&"linked_label", label)


## A rusted, abandoned car. Good cover; the roof can be climbed onto.
func car(x: float, z: float, yaw: float, color: Color = COLOR_RUST) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var at := Vector3(x, 0.0, z)
	box(at + basis * Vector3(0.0, 0.55, 0.0), Vector3(1.8, 0.7, 4.3), Look.METAL, color, true, false, yaw)
	box(at + basis * Vector3(0.0, 1.15, -0.2), Vector3(1.6, 0.55, 2.2), Look.METAL, color * 0.8, true, false, yaw)
	for wheel: Vector2 in [Vector2(-0.85, 1.4), Vector2(0.85, 1.4), Vector2(-0.85, -1.4), Vector2(0.85, -1.4)]:
		box(at + basis * Vector3(wheel.x, 0.3, wheel.y), Vector3(0.25, 0.6, 0.6), Look.RUBBLE, Color(0.03, 0.03, 0.03), false, false, yaw)


## A heap of broken concrete. Blocks movement and sight.
func rubble(x0: float, z0: float, x1: float, z1: float, height: float, pieces: int = 10) -> void:
	block(x0, z0, x1, z1, height * 0.55, 0.0, Look.RUBBLE, COLOR_CONCRETE * 0.7)
	for i: int in pieces:
		var size := Vector3(_random.randf_range(0.8, 2.6), _random.randf_range(0.5, 1.6), _random.randf_range(0.8, 2.6))
		var at := Vector3(_random.randf_range(x0, x1), height * _random.randf_range(0.45, 0.95), _random.randf_range(z0, z1))
		box(at, size, Look.RUBBLE, COLOR_CONCRETE * _random.randf_range(0.5, 0.95), false, false,
				_random.randf_range(0.0, 90.0), Vector3(_random.randf_range(-25.0, 25.0), 0.0, _random.randf_range(-25.0, 25.0)))


## Vines hanging down a facade (thin dark-green boxes, visual only).
func vines(from: Vector3, along: Vector3, length: float, count: int = 8, drop: float = 6.0) -> void:
	var out: Vector3 = along.cross(Vector3.UP).normalized() * 0.06
	for i: int in count:
		var at: Vector3 = from + along * (length * _random.randf())
		var hang: float = drop * _random.randf_range(0.3, 1.0)
		box(at + out - Vector3(0.0, hang * 0.5, 0.0), Vector3(absf(along.x) * 0.5 + 0.12, hang, absf(along.z) * 0.5 + 0.12),
				Look.RUBBLE, COLOR_VINE * _random.randf_range(0.7, 1.3), false)


## A waist-high barrier: cover that can be vaulted.
func barrier(x: float, z: float, length: float, yaw: float = 0.0, height: float = 1.0) -> void:
	box(Vector3(x, height * 0.5, z), Vector3(length, height, 0.45), Look.CONCRETE, COLOR_CONCRETE, true, true, yaw)


func random_range(low: float, high: float) -> float:
	return _random.randf_range(low, high)


# --- Finish -------------------------------------------------------------------

## Call once after all pieces are placed: creates the MultiMeshes and adds collision.
func commit() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var noise_texture := NoiseTexture2D.new()
	noise_texture.width = 512
	noise_texture.height = 512
	noise_texture.seamless = true
	noise_texture.generate_mipmaps = true
	noise_texture.noise = noise
	var shader: Shader = load(SHADER_PATH)
	for look: Look in _boxes:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(&"noise_texture", noise_texture)
		var settings: Dictionary = LOOK_SETTINGS[look]
		for key: String in settings:
			material.set_shader_parameter(key, settings[key])
		_materials[look] = material
		_commit_multimesh("Boxes_%s" % Look.keys()[look], _boxes[look][0], _boxes[look][1], material, true)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = COLOR_PAINT
	paint.roughness = 0.7
	paint.emission_enabled = true
	paint.emission = COLOR_PAINT
	paint.emission_energy_multiplier = 0.3
	_commit_multimesh("ClimbPaint", _paint, [], paint, false)

	for color: Color in _strips:
		var glow := StandardMaterial3D.new()
		glow.albedo_color = color * 0.2
		glow.emission_enabled = true
		glow.emission = color
		glow.emission_energy_multiplier = 3.4
		glow.roughness = 0.4
		_commit_multimesh("Strips_%s" % color.to_html(false), _strips[color], [], glow, false)
	add_child(_world_body)
	add_child(_climb_body)


## Rain makes puddles ripple; indoors-only test builds can switch it off.
func set_rain_ripples(amount: float) -> void:
	if _materials.has(Look.ASPHALT):
		(_materials[Look.ASPHALT] as ShaderMaterial).set_shader_parameter(&"ripple_strength", amount)


## Yellow paint along the top edges marks a surface as climbable.
func _add_paint_edges(center: Vector3, size: Vector3) -> void:
	var band: float = 0.07
	var top: float = center.y + size.y * 0.5 - band * 0.5 + 0.004
	var half_x: float = size.x * 0.5 + 0.004
	var half_z: float = size.z * 0.5 + 0.004
	for side: float in [-1.0, 1.0]:
		_paint.append(Transform3D(Basis.from_scale(Vector3(size.x + 0.02, band, band)),
				Vector3(center.x, top, center.z + side * half_z - side * band * 0.5)))
		_paint.append(Transform3D(Basis.from_scale(Vector3(band, band, size.z + 0.02)),
				Vector3(center.x + side * half_x - side * band * 0.5, top, center.z)))


func _commit_multimesh(node_name: String, transforms: Array, colors: Array, material: Material, cast_shadows: bool) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if not colors.is_empty():
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	add_child(instance)
