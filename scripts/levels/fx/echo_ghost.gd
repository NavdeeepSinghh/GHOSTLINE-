class_name EchoGhost
extends Node3D
## An Echo of someone caught in their last ordinary moment: a faint cyan figure
## sitting, standing or lying where they were, repeating it. A whispered line
## shows as Kael nears; when he comes close it scatters into motes and returns
## once he has gone.

const MODEL: String = "res://assets/models/characters/kael_standin/Rogue_Hooded.glb"
const SHADER: String = "res://assets/shaders/echo_ghost.gdshader"
const HIDDEN: PackedStringArray = ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable", "Rogue_Cape"]
const SCATTER_DISTANCE: float = 3.5
const RETURN_DISTANCE: float = 12.0
const WHISPER_DISTANCE: float = 11.0
const SLEEP_DISTANCE: float = 45.0

## Looping pose from the model (Idle, Sit_Chair_Idle, Sit_Floor_Idle, Lie_Idle, Interact…).
var clip: StringName = &"Idle"
var line: String = ""
var colour: Color = Color(0.22, 0.7, 0.9)

var scattered: bool = false
var _material: ShaderMaterial
var _player: AnimationPlayer
var _label: Label3D
var _dissolve: float = 0.0
var _label_alpha: float = 0.0
var _check: float = 0.0
var _distance: float = INF


func _ready() -> void:
	var model: Node3D = (load(MODEL) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * 0.8
	add_child(model)
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_material.set_shader_parameter(&"colour", colour)
	_material.set_shader_parameter(&"flicker", 0.0 if Accessibility.reduce_flashing() else 1.0)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if HIDDEN.has(String(mesh.name)):
			mesh.visible = false
			continue
		mesh.material_override = _material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null and _player.has_animation(clip):
		_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_player.play(clip)
		_player.seek(randf() * 2.0, true)
		_player.speed_scale = 0.6
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 0.35
	light.omni_range = 2.5
	light.position = Vector3(0.0, 1.0, 0.0)
	light.name = "Glow"
	add_child(light)
	if not line.is_empty():
		_label = Label3D.new()
		_label.text = line
		_label.font = UIStyle.heading_font()
		_label.font_size = 56
		_label.pixel_size = 0.0045
		_label.outline_size = 10
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.modulate = Color(colour.r, colour.g, colour.b, 0.0)
		_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.0)
		_label.no_depth_test = false
		_label.fixed_size = false
		_label.position = Vector3(0.0, 2.1 if clip != &"Lie_Idle" else 1.0, 0.0)
		add_child(_label)


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.2
		var kael: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
		_distance = global_position.distance_to(kael.global_position) if kael != null else INF
		var awake: bool = _distance < SLEEP_DISTANCE
		visible = awake
		if _player != null:
			_player.active = awake
		if not scattered and _distance < SCATTER_DISTANCE:
			scatter()
		elif scattered and _distance > RETURN_DISTANCE:
			scattered = false
	if not visible:
		return
	_dissolve = move_toward(_dissolve, 1.0 if scattered else 0.0, delta * (1.4 if scattered else 0.5))
	_material.set_shader_parameter(&"dissolve", _dissolve)
	_material.set_shader_parameter(&"strength", 0.75 + 0.15 * sin(Time.get_ticks_msec() * 0.002 + position.x))
	(get_node(^"Glow") as OmniLight3D).light_energy = 0.35 * (1.0 - _dissolve)
	if _label != null:
		var want: float = 0.85 if (_distance < WHISPER_DISTANCE and not scattered) else 0.0
		_label_alpha = move_toward(_label_alpha, want, delta * 0.8)
		_label.modulate.a = _label_alpha
		_label.outline_modulate.a = _label_alpha * 0.6


const DATA: String = "res://data/story/echo_ghosts.json"


## The ghosts listed for `area` in data/story/echo_ghosts.json. Facility entries
## have no position; they take `spots` ([floor point, yaw degrees]) in order.
static func from_data(area: String, spots: Array = []) -> Array[EchoGhost]:
	var ghosts: Array[EchoGhost] = []
	var file: FileAccess = FileAccess.open(DATA, FileAccess.READ)
	if file == null:
		return ghosts
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return ghosts
	var index: int = 0
	for entry: Dictionary in (parsed as Dictionary).get(area, []):
		var ghost := EchoGhost.new()
		ghost.clip = StringName(str(entry.get("clip", "Idle")))
		ghost.line = str(entry.get("line", ""))
		if entry.has("at"):
			var at: Array = entry["at"]
			ghost.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
			if entry.has("face"):
				var face: Array = entry["face"]
				ghost.rotation.y = atan2(float(face[0]) - ghost.position.x, float(face[1]) - ghost.position.z)
			else:
				ghost.rotation_degrees.y = float(entry.get("yaw", 0.0))
		elif index < spots.size():
			ghost.position = spots[index][0]
			ghost.rotation_degrees.y = float(spots[index][1])
			index += 1
		else:
			ghost.free()
			continue
		ghosts.append(ghost)
	return ghosts


## Breaks up into motes (Kael walked into it).
func scatter() -> void:
	if scattered:
		return
	scattered = true
	var burst: GPUParticles3D = CityFX.motes(Vector3(0.0, 1.0, 0.0), Vector3(0.3, 0.8, 0.3), 50, colour)
	burst.one_shot = true
	burst.explosiveness = 0.85
	(burst.process_material as ParticleProcessMaterial).initial_velocity_max = 1.2
	add_child(burst)
	get_tree().create_timer(7.0, false).timeout.connect(burst.queue_free)
	AudioManager.play_sfx(&"echo_swell", global_position + Vector3.UP, -12.0)


func dissolve_amount() -> float:
	return _dissolve
