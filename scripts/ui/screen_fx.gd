class_name ScreenFX
extends CanvasLayer
## The film look over the 3D view (under the HUD): vignette, grain, a little
## chromatic aberration, and a red edge that pulses when Kael is hit and beats
## when his health is low. Settings > Graphics > "Film look" turns it off.

const SHADER: Shader = preload("res://assets/shaders/screen_fx.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial
var _hurt: float = 0.0
var _last_health: float = -1.0
var _low: float = 0.0
## Photo mode keeps the effect on (for its filters) even with Film look off.
var force_visible: bool = false
## Photo mode filter names, in shader order.
const FILTERS: PackedStringArray = ["None", "Noir", "Dusk", "Cold", "Echo", "Faded film"]


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect.material = _material
	add_child(_rect)
	EventBus.health_changed.connect(_on_health_changed)


func _on_health_changed(current: float, maximum: float) -> void:
	if _last_health >= 0.0 and current < _last_health - 0.5:
		_hurt = 0.6 if Accessibility.reduce_flashing() else 1.0
	_last_health = current
	_low = 1.0 if maximum > 0.0 and current / maximum < 0.3 and current > 0.0 else 0.0


func hurt_amount() -> float:
	return _hurt


func is_active() -> bool:
	return _rect.visible


func set_filter(index: int) -> void:
	_material.set_shader_parameter(&"filter", clampi(index, 0, FILTERS.size() - 1))


func set_letterbox(on: bool) -> void:
	_material.set_shader_parameter(&"letterbox", 1.0 if on else 0.0)


func set_grain(amount: float) -> void:
	_material.set_shader_parameter(&"grain", amount)


func set_tint(color: Color) -> void:
	_material.set_shader_parameter(&"tint", color)


func _process(delta: float) -> void:
	_rect.visible = force_visible or SettingsManager.get_bool("graphics", "film_look")
	_hurt = move_toward(_hurt, 0.0, delta * 2.2)
	_material.set_shader_parameter(&"hurt", _hurt)
	_material.set_shader_parameter(&"low_health", _low)
