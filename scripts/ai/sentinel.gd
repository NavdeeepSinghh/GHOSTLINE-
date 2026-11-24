class_name Sentinel
extends Node3D
## A facility security camera. Its cone sweeps left and right; if Kael stays
## in it long enough the alarm sounds and nearby enemies come running. A
## control panel elsewhere can switch a group of Sentinels off.

signal alarm_raised(sentinel: Sentinel)

const IDLE_COLOR := Color(0.5, 0.42, 0.22, 0.035)
const ALERT_COLOR := Color(1.0, 0.15, 0.1, 0.16)

@export var sweep_degrees: float = 80.0
@export var sweep_seconds: float = 6.0
@export var view_range: float = 12.0
@export var view_half_angle: float = 22.0
@export var detect_seconds: float = 1.1
@export var alarm_radius: float = 28.0
@export var alarm_cooldown: float = 12.0

var enabled: bool = true
## 0..1, how close the Sentinel is to raising the alarm.
var suspicion: float = 0.0

var _time: float = 0.0
var _base_yaw: float = 0.0
var _cooldown: float = 0.0
var _head: Node3D
var _cone: MeshInstance3D
var _material: StandardMaterial3D
var _player: Player


func _ready() -> void:
	_base_yaw = rotation.y
	_time = randf() * sweep_seconds
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.25, 0.45)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.13, 0.15)
	metal.metallic = 0.7
	metal.roughness = 0.4
	box.material = metal
	body.mesh = box
	_head = Node3D.new()
	add_child(_head)
	_head.add_child(body)
	# The visible cone: shape and motion carry the meaning, colour only reinforces it.
	_cone = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = view_range * tan(deg_to_rad(view_half_angle))
	cone.height = view_range
	cone.radial_segments = 16
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = IDLE_COLOR
	_material.disable_fog = true
	_material.no_depth_test = false
	cone.material = _material
	_cone.mesh = cone
	_cone.rotation_degrees.x = -90.0
	_cone.position.z = -view_range * 0.5
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(_cone)
	_head.rotation_degrees.x = -28.0


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	rotation.y = _base_yaw + deg_to_rad(sweep_degrees * 0.5) * sin(_time * TAU / sweep_seconds)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	var seen: bool = sees(_player)
	suspicion = clampf(suspicion + (delta / detect_seconds if seen else -delta * 0.6), 0.0, 1.0)
	_material.albedo_color = IDLE_COLOR.lerp(Accessibility.cue("sentinel_alert"), suspicion)
	if suspicion >= 1.0 and _cooldown <= 0.0:
		raise_alarm()


func sees(victim: Player) -> bool:
	if victim == null or victim.is_dead() or victim.god_mode:
		return false
	var eye: Vector3 = _head.global_position
	var chest: Vector3 = victim.global_position + Vector3.UP * 1.0
	var to_victim: Vector3 = chest - eye
	if to_victim.length() > view_range:
		return false
	var forward: Vector3 = -_head.global_basis.z
	if forward.angle_to(to_victim.normalized()) > deg_to_rad(view_half_angle):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, chest, Player.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func raise_alarm() -> void:
	_cooldown = alarm_cooldown
	suspicion = 0.0
	AudioManager.play_sfx(&"enemy_alert", global_position, 6.0)
	EventBus.toast_requested.emit("Sentinel alarm", 2.5)
	if _player != null:
		EventBus.noise_emitted.emit(_player.global_position, alarm_radius, self)
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			var enemy: Enemy = node as Enemy
			if enemy != null and not enemy.is_dead() and enemy.global_position.distance_to(global_position) <= alarm_radius:
				enemy.alert(_player.global_position)
	alarm_raised.emit(self)


func disable() -> void:
	enabled = false
	suspicion = 0.0
	_cone.visible = false
