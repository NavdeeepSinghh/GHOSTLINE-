class_name HologramScreen
extends Node3D
## A holographic advert still running on emergency power: a glitching screen
## with a line of text, a faint glow on the wall below and now and then a
## stutter (none with Reduce flashing).

const SHADER: Shader = preload("res://assets/shaders/hologram.gdshader")

var text: String = "MERIDIAN"
var size: Vector2 = Vector2(4.0, 2.2)
var colour: Color = Color(0.25, 0.85, 1.0)

var _material: ShaderMaterial
var _label: Label3D
var _next_glitch: float = 2.0
var _glitch: float = 0.0


func _ready() -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"colour", colour)
	mesh.material = _material
	quad.mesh = mesh
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	_label = Label3D.new()
	_label.text = text
	_label.font = UIStyle.heading_font()
	_label.font_size = 96
	_label.pixel_size = size.y * 0.0016
	_label.modulate = Color(colour.r * 1.6, colour.g * 1.6, colour.b * 1.6, 0.95)
	_label.outline_size = 0
	_label.position = Vector3(size.x * 0.12, -size.y * 0.28, 0.02)
	_label.shaded = false
	_label.double_sided = false
	add_child(_label)
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 1.2
	light.omni_range = size.x * 1.4
	light.position = Vector3(0.0, 0.0, 0.8)
	light.distance_fade_enabled = true
	light.distance_fade_begin = 50.0
	light.distance_fade_length = 10.0
	add_child(light)
	_next_glitch = randf_range(1.0, 5.0)


func _process(delta: float) -> void:
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_next_glitch = randf_range(2.0, 7.0)
		_glitch = 0.0 if Accessibility.reduce_flashing() else 1.0
	_glitch = move_toward(_glitch, 0.0, delta * 3.0)
	_material.set_shader_parameter(&"glitch", _glitch)
	_label.position.x = size.x * 0.12 + (randf_range(-0.08, 0.08) if _glitch > 0.3 else 0.0)
