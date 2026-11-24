class_name WardenController
extends Node
## The Warden: a military exosuit fused with a Hollow. It is an ordinary Enemy
## (so it paths, telegraphs and can be parried like the rest) driven through
## three phases by this controller, which rewrites its numbers and adds the
## flamethrower sweep.
##
## Phase 1: heavy swings, with a shoulder charge mixed in.
## Phase 2 (60%): the armour falls away; faster, and a flame sweep that must be
##                dodged by putting a pillar between Kael and the Warden.
## Phase 3 (25%): the suit malfunctions: wild lunges with long recoveries.

signal phase_changed(phase: int)
signal defeated

const BASE_DATA: String = "res://data/enemies/bulwark.tres"

var enemy: Enemy
var phase: int = 1
var tuning: Dictionary = {}
var is_flaming: bool = false

var _swap_timer: float = 6.0
var _flame_timer: float = 7.0
var _flame_time: float = 0.0
var _flame_tick: float = 0.0
var _flame_yaw: float = 0.0
var _flame_visual: Node3D
var _done: bool = false


## Builds the Warden's data from the Bulwark's, scaled up.
static func make_data(values: Dictionary) -> EnemyData:
	var data: EnemyData = (load(BASE_DATA) as EnemyData).duplicate()
	data.id = "warden"
	data.display_name = "The Warden"
	data.model_scale *= 1.45
	data.body_radius = 0.6
	data.body_height = 2.5
	data.eye_height = 2.1
	data.max_health = float(values.get("health", 520.0))
	data.armor = float(values.get("armor", 110.0))
	data.attack_damage = float(values.get("swing_damage", 24.0))
	data.attack_kind = EnemyData.AttackKind.MELEE
	data.attack_range = 2.6
	data.attack_reach = 2.0
	data.attack_radius = 1.5
	data.attack_windup = 0.8
	data.attack_recovery = 0.9
	data.attack_cooldown = 1.6
	data.chase_speed = 3.1
	data.flinches = false
	data.stunnable = false
	data.takedown_allowed = false
	data.stagger_threshold = 90.0
	data.vision_range = 40.0
	data.lose_target_time = 60.0
	return data


func _ready() -> void:
	enemy = get_parent() as Enemy
	EventBus.boss_started.emit(enemy.data.display_name)


func _physics_process(delta: float) -> void:
	if _done or enemy == null:
		return
	var ratio: float = enemy.health.get_ratio()
	EventBus.boss_health_changed.emit(ratio)
	if enemy.is_dead():
		_done = true
		_end_flame()
		EventBus.boss_ended.emit()
		defeated.emit()
		return
	if phase == 1 and ratio <= float(tuning.get("phase_2_at", 0.6)):
		_enter_phase(2)
	elif phase == 2 and ratio <= float(tuning.get("phase_3_at", 0.25)):
		_enter_phase(3)
	if is_flaming:
		_update_flame(delta)
		return
	if not enemy.is_aware() or enemy.state == Enemy.AIState.ATTACK:
		return
	if phase == 1:
		# Every few seconds the next attack is a shoulder charge instead of a swing.
		_swap_timer -= delta
		if _swap_timer <= 0.0:
			_swap_timer = 6.0
			_set_charge(enemy.data.attack_kind != EnemyData.AttackKind.DASH)
	elif phase == 2:
		_flame_timer -= delta
		if _flame_timer <= 0.0 and enemy.target != null:
			_start_flame()


func _enter_phase(next: int) -> void:
	phase = next
	_end_flame()
	var data: EnemyData = enemy.data
	if next == 2:
		enemy.armor_points = 0.0
		enemy.visuals.break_armor()
		_set_charge(false)
		data.chase_speed = 3.9
		data.attack_cooldown = 1.0
		data.attack_windup = 0.6
		var core := OmniLight3D.new()
		core.light_color = GrayboxBuilder.COLOR_ECHO
		core.light_energy = 3.0
		core.omni_range = 6.0
		core.position.y = 1.6
		enemy.add_child(core)
	else:
		_set_charge(true)
		data.attack_lunge_speed = 13.0
		data.attack_windup = 0.5
		data.attack_recovery = float(tuning.get("phase_3_recovery", 1.8))
		data.attack_cooldown = 0.8
	AudioManager.play_sfx(&"boss_roar", enemy.global_position + Vector3.UP * 1.5, 4.0)
	CombatFX.shake(0.5)
	phase_changed.emit(next)


func _set_charge(charging: bool) -> void:
	var data: EnemyData = enemy.data
	if charging:
		data.attack_kind = EnemyData.AttackKind.DASH
		data.attack_range = 7.5
		data.attack_lunge_speed = 11.0
		data.attack_active = 0.5
		data.attack_reach = 1.4
	else:
		data.attack_kind = EnemyData.AttackKind.MELEE
		data.attack_range = 2.6
		data.attack_lunge_speed = 2.0
		data.attack_active = 0.2
		data.attack_reach = 2.0


# --- Flamethrower sweep ---------------------------------------------------------------

func _start_flame() -> void:
	is_flaming = true
	_flame_time = 0.0
	_flame_tick = 0.0
	enemy.set_physics_process(false)
	enemy.visuals.play_once(enemy.data.alert_clip, 0.6)
	var to_target: Vector3 = enemy.target.global_position - enemy.global_position
	_flame_yaw = atan2(to_target.x, to_target.z)
	AudioManager.play_sfx(&"boss_roar", enemy.global_position + Vector3.UP * 1.5, 2.0)
	EventBus.hint_requested.emit("Flame! Get behind a pillar", 3.0)
	_flame_visual = Node3D.new()
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = float(tuning.get("flame_range", 11.0)) * 0.3
	mesh.height = float(tuning.get("flame_range", 11.0))
	mesh.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.45, 0.1, 0.35)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	cone.mesh = mesh
	cone.rotation_degrees.x = 90.0
	cone.position.z = mesh.height * 0.5
	_flame_visual.add_child(cone)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 4.0
	light.omni_range = 10.0
	light.position.z = 3.0
	_flame_visual.add_child(light)
	_flame_visual.add_child(VFX.flame_embers(float(tuning.get("flame_range", 11.0))))
	_flame_visual.visible = false
	enemy.add_child(_flame_visual)
	_flame_visual.position.y = 1.5


func _update_flame(delta: float) -> void:
	_flame_time += delta
	var windup: float = float(tuning.get("flame_windup", 1.0))
	var duration: float = float(tuning.get("flame_seconds", 3.2))
	if _flame_time < windup:
		return
	if _flame_time >= windup + duration:
		_end_flame()
		_flame_timer = float(tuning.get("flame_interval", 10.0))
		return
	if not _flame_visual.visible:
		_flame_visual.visible = true
		AudioManager.play_sfx(&"flame", enemy.global_position + Vector3.UP * 1.5, 4.0)
	# Sweeps across an arc centred on where Kael stood when it began.
	var sweep: float = deg_to_rad(float(tuning.get("flame_arc_degrees", 110.0)))
	var yaw: float = _flame_yaw + lerpf(-sweep * 0.5, sweep * 0.5, (_flame_time - windup) / duration)
	_flame_visual.global_rotation = Vector3(0.0, yaw, 0.0)
	_flame_tick -= delta
	if _flame_tick <= 0.0:
		_flame_tick = 0.25
		if flame_reaches(enemy.target, yaw):
			var hit := HitInfo.new()
			hit.damage = float(tuning.get("flame_damage_per_tick", 8.0))
			hit.attacker = enemy
			hit.origin = enemy.global_position
			hit.can_be_blocked = false
			hit.can_be_parried = false
			hit.poise = 0.0
			enemy.target.receive_hit(hit)


## True when `victim` is inside the flame cone pointing along `yaw` with nothing solid in between.
func flame_reaches(victim: Node3D, yaw: float) -> bool:
	if victim == null:
		return false
	var origin: Vector3 = enemy.global_position + Vector3.UP * 1.5
	var chest: Vector3 = victim.global_position + Vector3.UP * 1.0
	var to_victim: Vector3 = chest - origin
	to_victim.y = 0.0
	if to_victim.length() > float(tuning.get("flame_range", 11.0)):
		return false
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	if forward.angle_to(to_victim.normalized()) > deg_to_rad(float(tuning.get("flame_half_angle_degrees", 17.0))):
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, chest, Player.LAYER_WORLD)
	return enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _end_flame() -> void:
	if not is_flaming:
		return
	is_flaming = false
	if _flame_visual != null and is_instance_valid(_flame_visual):
		_flame_visual.queue_free()
	_flame_visual = null
	if enemy != null and not enemy.is_dead():
		enemy.set_physics_process(true)
