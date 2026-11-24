class_name GrayboxBuilder
extends Node3D
## Builds graybox geometry from simple calls (blocks, ramps, strips, signs) and
## keeps it cheap: every box of one material is a single MultiMesh draw call,
## and all collision lives on two static bodies (plain and climbable).
##
## Used by test levels. Story levels (Milestone 3+) are authored scenes.

const SHADER_PATH: String = "res://assets/shaders/proto_grid.gdshader"
const HEADING_FONT_PATH: String = "res://assets/fonts/Rajdhani-SemiBold.ttf"

const COLOR_FLOOR := Color(0.105, 0.118, 0.135)
const COLOR_BLOCK := Color(0.2, 0.22, 0.25)
const COLOR_WALL := Color(0.13, 0.145, 0.165)
const COLOR_CLIMB := Color(0.27, 0.265, 0.25)
const COLOR_PAINT := Color(0.95, 0.72, 0.1)
const COLOR_ECHO := Color(0.27, 0.92, 1.0)
const COLOR_SODIUM := Color(1.0, 0.56, 0.2)
const COLOR_MAGENTA := Color(1.0, 0.25, 0.62)
const COLOR_TEXT := Color(0.92, 0.9, 0.86)

var _world_body: StaticBody3D
var _climb_body: StaticBody3D
var _grid_transforms: Array[Transform3D] = []
var _grid_colors: Array[Color] = []
## emissive strips grouped by colour
var _strip_transforms: Dictionary = {}
var _paint_transforms: Array[Transform3D] = []
var _font: Font


func _init() -> void:
	_world_body = StaticBody3D.new()
	_world_body.name = "WorldCollision"
	_world_body.collision_layer = Player.LAYER_WORLD
	_world_body.collision_mask = 0
	add_child(_world_body)
	_climb_body = StaticBody3D.new()
	_climb_body.name = "ClimbableCollision"
	_climb_body.collision_layer = Player.LAYER_WORLD | Player.LAYER_CLIMBABLE
	_climb_body.collision_mask = 0
	add_child(_climb_body)
	_font = load(HEADING_FONT_PATH)


## A box resting on `base_y`, centred on (x, z).
func add_block(x: float, z: float, size_x: float, size_z: float, height: float,
		base_y: float = 0.0, climbable: bool = false, color: Color = COLOR_BLOCK) -> void:
	var center := Vector3(x, base_y + height * 0.5, z)
	var size := Vector3(size_x, height, size_z)
	_add_box(Transform3D(Basis.IDENTITY, center), size, climbable, COLOR_CLIMB if climbable else color)
	if climbable:
		_add_paint_edges(center, size)


## A walkable slab rising from `low` to `high` (centre points of its two ends).
func add_ramp(low: Vector3, high: Vector3, width: float, color: Color = COLOR_BLOCK, thickness: float = 0.3) -> void:
	var along: Vector3 = high - low
	var length: float = along.length()
	var forward: Vector3 = along / length
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	var normal: Vector3 = side.cross(forward).normalized()
	var basis := Basis(side, normal, -forward)
	var center: Vector3 = (low + high) * 0.5 - normal * thickness * 0.5
	_add_box(Transform3D(basis, center), Vector3(width, thickness, length), false, color)


## A glowing strip (lane marking, trim light). Purely visual.
func add_strip(center: Vector3, size: Vector3, color: Color = COLOR_ECHO) -> void:
	if not _strip_transforms.has(color):
		var list: Array[Transform3D] = []
		_strip_transforms[color] = list
	(_strip_transforms[color] as Array[Transform3D]).append(Transform3D(Basis.from_scale(size), center))


## Flat text in the world. `yaw_degrees` 0 faces +Z (toward the player start).
func add_sign(text: String, position_3d: Vector3, yaw_degrees: float = 0.0, size: float = 1.0,
		color: Color = COLOR_TEXT, flat_on_ground: bool = false) -> Label3D:
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
	label.position = position_3d
	label.rotation_degrees = Vector3(-90.0 if flat_on_ground else 0.0, yaw_degrees, 0.0)
	add_child(label)
	return label


## A lamp post with a warm light.
func add_lamp(x: float, z: float, color: Color = COLOR_SODIUM, height: float = 4.2,
		energy: float = 2.6, casts_shadow: bool = false) -> OmniLight3D:
	_add_box(Transform3D(Basis.IDENTITY, Vector3(x, height * 0.5, z)), Vector3(0.14, height, 0.14), false, COLOR_WALL)
	add_strip(Vector3(x, height + 0.06, z), Vector3(0.5, 0.1, 0.5), color)
	var light := OmniLight3D.new()
	light.position = Vector3(x, height - 0.25, z)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 13.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = casts_shadow
	light.light_volumetric_fog_energy = 1.6
	add_child(light)
	return light


## Call once after all add_* calls: turns the collected boxes into MultiMeshes.
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

	var grid_material := ShaderMaterial.new()
	grid_material.shader = load(SHADER_PATH)
	grid_material.set_shader_parameter(&"noise_texture", noise_texture)
	_commit_multimesh("GridBlocks", _grid_transforms, _grid_colors, grid_material, true)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = COLOR_PAINT
	paint.roughness = 0.7
	paint.emission_enabled = true
	paint.emission = COLOR_PAINT
	paint.emission_energy_multiplier = 0.35
	_commit_multimesh("ClimbPaint", _paint_transforms, [], paint, false)

	for color: Color in _strip_transforms:
		var glow := StandardMaterial3D.new()
		glow.albedo_color = color * 0.2
		glow.emission_enabled = true
		glow.emission = color
		glow.emission_energy_multiplier = 3.2
		glow.roughness = 0.4
		_commit_multimesh("Strips_%s" % color.to_html(false), _strip_transforms[color], [], glow, false)


func _add_box(transform_3d: Transform3D, size: Vector3, climbable: bool, color: Color) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = transform_3d
	(_climb_body if climbable else _world_body).add_child(collision)
	_grid_transforms.append(Transform3D(transform_3d.basis * Basis.from_scale(size), transform_3d.origin))
	_grid_colors.append(color)


## Yellow paint along the top edges marks a surface as climbable.
func _add_paint_edges(center: Vector3, size: Vector3) -> void:
	var band: float = 0.07
	var top: float = center.y + size.y * 0.5 - band * 0.5 + 0.004
	var half_x: float = size.x * 0.5 + 0.004
	var half_z: float = size.z * 0.5 + 0.004
	for side: float in [-1.0, 1.0]:
		_paint_transforms.append(Transform3D(Basis.from_scale(Vector3(size.x + 0.02, band, band)),
				Vector3(center.x, top, center.z + side * half_z - side * band * 0.5)))
		_paint_transforms.append(Transform3D(Basis.from_scale(Vector3(band, band, size.z + 0.02)),
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
