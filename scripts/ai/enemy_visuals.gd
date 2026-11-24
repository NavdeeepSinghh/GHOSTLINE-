class_name EnemyVisuals
extends Node3D
## An enemy's model and animation: locomotion picked from speed, one-off clips
## for attacks and reactions, glowing eyes that flare as an attack winds up.

var _data: EnemyData
var _model: Node3D
var _player: AnimationPlayer
var _meshes: Array[GeometryInstance3D] = []
var _eye_material: StandardMaterial3D
var _eye_light: OmniLight3D
var _flash_material: StandardMaterial3D
var _flash_time: float = 0.0
var _telegraph: float = 0.0
var _telegraph_target: float = 0.0
var _armor: Node3D
var _current: StringName = &""
var _fade: float = 0.0
var _fading: bool = false
var _dissolve: ShaderMaterial


func setup(data: EnemyData) -> void:
	_data = data
	_model = data.model.instantiate()
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * data.model_scale
	add_child(_model)
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: StringName in [data.idle_clip, data.walk_clip, data.run_clip]:
		if _player.has_animation(clip):
			_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = Color(0.02, 0.05, 0.06)
	_eye_material.emission_enabled = true
	_eye_material.emission = GrayboxBuilder.COLOR_ECHO
	_eye_material.emission_energy_multiplier = 2.5
	for node: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		var mesh: GeometryInstance3D = node as GeometryInstance3D
		_meshes.append(mesh)
		if String(mesh.name).ends_with("_Eyes"):
			mesh.material_override = _eye_material
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = GrayboxBuilder.COLOR_ECHO
	_eye_light.light_energy = 0.5
	_eye_light.omni_range = 2.6
	_eye_light.position = Vector3(0.0, data.eye_height, -0.25)
	# Models that are not humanoid mark where their eyes are.
	var anchor: Node3D = _model.get_node_or_null(^"EyeAnchor") as Node3D
	if anchor != null:
		_eye_light.position = _model.transform * anchor.position
	add_child(_eye_light)
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0)
	if data.armor > 0.0:
		_build_armor()
	play_loop(data.idle_clip)


func _process(delta: float) -> void:
	_telegraph = move_toward(_telegraph, _telegraph_target, delta * 5.0)
	var color: Color = GrayboxBuilder.COLOR_ECHO.lerp(Accessibility.cue("telegraph"), _telegraph)
	_eye_material.emission = color
	_eye_material.emission_energy_multiplier = 2.5 + _telegraph * 6.0
	_eye_light.light_color = color
	_eye_light.light_energy = 0.5 + _telegraph * 3.5
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_material.albedo_color.a = clampf(_flash_time / 0.1, 0.0, 1.0) * 0.75
		if _flash_time <= 0.0:
			for mesh: GeometryInstance3D in _meshes:
				mesh.material_overlay = null
	if _fading:
		_fade = minf(_fade + delta * 0.5, 1.0)
		_dissolve.set_shader_parameter(&"progress", _fade)
		for mesh: GeometryInstance3D in _meshes:
			mesh.transparency = _fade * _fade
			mesh.material_overlay = _dissolve


## Looping locomotion clip. `speed` scales playback (to match ground speed).
func play_loop(clip: StringName, speed: float = 1.0) -> void:
	if _current != clip:
		_current = clip
		_player.play(clip, 0.2)
	_player.speed_scale = speed


## One-off clip from the start.
func play_once(clip: StringName, speed: float = 1.0) -> void:
	_current = clip
	_player.play(clip, 0.1)
	_player.seek(0.0, true)
	_player.speed_scale = speed


func set_speed(speed: float) -> void:
	_player.speed_scale = speed


func get_clip_length(clip: StringName) -> float:
	return _player.get_animation(clip).length if _player.has_animation(clip) else 1.0


## Eyes flare orange while an attack winds up.
func set_telegraph(active: bool) -> void:
	_telegraph_target = 1.0 if active else 0.0


func flash() -> void:
	if Accessibility.reduce_flashing():
		return
	_flash_material.albedo_color = Color(1, 1, 1, 0.75)
	_flash_time = 0.1
	for mesh: GeometryInstance3D in _meshes:
		mesh.material_overlay = _flash_material


func break_armor() -> void:
	if _armor != null:
		_armor.queue_free()
		_armor = null


func set_dead() -> void:
	set_telegraph(false)
	_eye_light.visible = false
	_eye_material.emission_energy_multiplier = 0.0
	set_process(true)


## The body burns away into the Echo: a cyan edge climbs through it and
## embers drift up while it fades.
func start_fade() -> void:
	_fading = true
	_dissolve = ShaderMaterial.new()
	_dissolve.shader = load("res://assets/shaders/echo_dissolve.gdshader")
	var embers: GPUParticles3D = CityFX.motes(Vector3(0.0, 0.9, 0.0), Vector3(0.35, 0.8, 0.35), 40, Color(0.35, 0.9, 1.0))
	var process := embers.process_material as ParticleProcessMaterial
	process.gravity = Vector3(0.0, 0.9, 0.0)
	embers.lifetime = 1.6
	add_child(embers)


func is_dissolving() -> bool:
	return _fading


## Fused-debris plating on the chest and shoulders, removed when the armour breaks.
func _build_armor() -> void:
	var skeleton: Skeleton3D = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var bone: int = skeleton.find_bone("chest")
	if bone < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "chest"
	skeleton.add_child(attachment)
	_armor = attachment
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.15, 0.14)
	material.metallic = 0.85
	material.roughness = 0.45
	# Plates are laid out in model space (Y up, Z forward) around the chest,
	# then converted into the bone's own space so they follow the animation.
	var chest: Transform3D = skeleton.get_bone_global_rest(bone)
	var to_bone: Transform3D = chest.affine_inverse()
	var plates: Array[Array] = [
		[Vector3(0.0, 0.05, 0.34), Vector3(0.8, 0.55, 0.1)],
		[Vector3(0.0, 0.05, -0.34), Vector3(0.8, 0.55, 0.1)],
		[Vector3(0.6, 0.32, 0.0), Vector3(0.42, 0.16, 0.6)],
		[Vector3(-0.6, 0.32, 0.0), Vector3(0.42, 0.16, 0.6)],
	]
	for plate: Array in plates:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = plate[1]
		mesh.mesh = box
		mesh.transform = to_bone * Transform3D(Basis.IDENTITY, chest.origin + (plate[0] as Vector3))
		mesh.material_override = material
		attachment.add_child(mesh)
