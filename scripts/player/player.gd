class_name Player
extends CharacterBody3D
## Kael's body: shared movement helpers, stamina, crouch and stair stepping.
## The StateMachine child decides what he is doing (Ground, Air, Mantle,
## LedgeHang, Ladder); states call the helpers here.

enum MoveMode { IDLE, WALK, JOG, SPRINT, CROUCH }

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
const LAYER_CLIMBABLE: int = 8
const DEFAULT_TUNING_PATH: String = "res://data/player_tuning.tres"
const DEFAULT_COMBAT_PATH: String = "res://data/combat_tuning.tres"
const WEAPON_PATHS: PackedStringArray = [
	"res://data/weapons/rebar_pipe.tres",
	"res://data/weapons/fire_axe.tres",
	"res://data/weapons/resonance_blade.tres",
]

## Weapon ids Kael starts with. Empty means all of them (test levels).
static var starting_weapons: PackedStringArray = []

@export var tuning: PlayerTuning
@export var combat: CombatTuning

## Set by whoever spawns the player; movement input is relative to its yaw.
var camera_rig: CameraRig
## False while menus or cinematics own the input.
var input_enabled: bool = true
## Base stamina plus Lung Cores.
var max_stamina: float = 100.0
## Cinematics and the benchmark make Kael untouchable.
var god_mode: bool = false
var stamina: float = 100.0
var is_crouching: bool = false
var is_sprinting: bool = false
var move_mode: MoveMode = MoveMode.IDLE
## Radians; 0 faces -Z.
var facing_yaw: float = 0.0
var jump_buffer_timer: float = 0.0
var ledge_cooldown: float = 0.0
## Radius of the sound Kael is currently making (drives stealth in Milestone 2).
var noise_radius: float = 0.0


# --- Combat ---
var health: HealthComponent
var hitbox: HitboxComponent
var weapons: Array[WeaponData] = []
var weapon: WeaponData
var weapon_index: int = 0
var injectors: int = 3
var throwables: int = 3
## True during the invulnerable part of a dodge or a takedown.
var dodge_invulnerable: bool = false
## Counts down after a hit; no new damage while above zero.
var hurt_invulnerable_time: float = 0.0
var light_buffer_timer: float = 0.0
var heavy_buffer_timer: float = 0.0
## Physics time (seconds) the guard was last lowered; gates parry re-arming.
var block_ended_at: float = -10.0
var throw_cooldown: float = 0.0
var heal_timer: float = 0.0
## The enemy a silent takedown would hit right now, if any.
var takedown_target: Node3D
# --- Stealth ---
## Number of shadow / hiding volumes Kael is standing in (set by StealthZone).
var shadow_zones: int = 0
var hide_zones: int = 0
var clock: float = 0.0

var _capsule: CapsuleShape3D
var _stamina_idle_time: float = 0.0
var _sprint_locked_out: bool = false
var _sprint_latched: bool = false
var _noise_timer: float = 0.0
var _motion_params := PhysicsTestMotionParameters3D.new()
var _motion_result := PhysicsTestMotionResult3D.new()

@onready var collider: CollisionShape3D = $Collider
@onready var visuals: PlayerVisuals = $Visuals
@onready var state_machine: StateMachine = $StateMachine
@onready var ledge_detector: LedgeDetector = $LedgeDetector
@onready var interaction: InteractionSensor = $InteractionSensor


func _ready() -> void:
	if tuning == null:
		tuning = load(DEFAULT_TUNING_PATH)
	_capsule = CapsuleShape3D.new()
	collider.shape = _capsule
	_apply_capsule_height(tuning.stand_height)
	floor_max_angle = deg_to_rad(tuning.floor_max_angle_degrees)
	floor_snap_length = 0.35
	floor_stop_on_slope = true
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD | LAYER_ENEMY
	max_stamina = tuning.max_stamina
	stamina = max_stamina
	_setup_combat()
	facing_yaw = rotation.y
	rotation.y = 0.0
	visuals.rotation.y = facing_yaw
	add_to_group(&"player")
	state_machine.state_changed.connect(_on_state_changed)
	state_machine.start()
	EventBus.player_spawned.emit(self)
	EventBus.stamina_changed.emit(stamina, max_stamina)
	emit_combat_status()


func _physics_process(delta: float) -> void:
	clock += delta
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	ledge_cooldown = maxf(ledge_cooldown - delta, 0.0)
	if input_enabled and Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = tuning.jump_buffer_time
	_update_combat_timers(delta)
	_update_double_tap()
	state_machine.physics_update(delta)
	_update_stamina(delta)
	_update_noise(delta)
	takedown_target = _find_takedown_target()
	visuals.rotation.y = facing_yaw


func _process(delta: float) -> void:
	state_machine.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled:
		state_machine.handle_input(event)


# --- Input ------------------------------------------------------------------

func get_move_input() -> Vector2:
	if not input_enabled:
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


## Camera-relative move direction on the ground plane; length 0..1.
func get_move_direction() -> Vector3:
	var input: Vector2 = get_move_input()
	if input.is_zero_approx():
		return Vector3.ZERO
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, get_camera_yaw())
	return direction.limit_length(1.0)


func get_camera_yaw() -> float:
	return camera_rig.yaw if camera_rig != null else 0.0


const DIRECTION_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right"]

## Set for one physics frame when a direction was tapped twice quickly.
var double_tap_requested: bool = false
var _last_tap: Dictionary = {}


func _update_double_tap() -> void:
	double_tap_requested = false
	if not input_enabled or not SettingsManager.get_bool("controls", "double_tap_dodge"):
		return
	for action: StringName in DIRECTION_ACTIONS:
		if Input.is_action_just_pressed(action) and register_direction_tap(action):
			double_tap_requested = true


## Records a tap of one direction; true when it is the second tap inside the window.
func register_direction_tap(action: StringName) -> bool:
	var previous: float = float(_last_tap.get(action, -100.0))
	if clock - previous <= combat.double_tap_window:
		_last_tap[action] = -100.0
		return true
	# A different direction breaks any half-finished double tap.
	_last_tap.clear()
	_last_tap[action] = clock
	return false


func is_action_held(action: StringName) -> bool:
	return input_enabled and Input.is_action_pressed(action)


func is_action_just_pressed(action: StringName) -> bool:
	return input_enabled and Input.is_action_just_pressed(action)


func consume_jump_buffer() -> bool:
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		return true
	return false


# --- Movement helpers -------------------------------------------------------

func get_facing_direction() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Accelerates the horizontal velocity toward direction * speed.
func accelerate_horizontal(direction: Vector3, speed: float, acceleration: float, delta: float) -> void:
	var target: Vector3 = direction * speed
	var horizontal: Vector3 = get_horizontal_velocity().move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Turns the body toward a direction at turn_speed radians per second.
func face_direction(direction: Vector3, turn_speed: float, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	facing_yaw = rotate_toward(facing_yaw, target_yaw, turn_speed * delta)


func snap_facing(direction: Vector3) -> void:
	if direction.length_squared() > 0.0001:
		facing_yaw = atan2(-direction.x, -direction.z)
		visuals.rotation.y = facing_yaw


## Gravity with half-step integration, so jump height matches the tuning exactly.
func apply_gravity_half(delta: float) -> void:
	var gravity: float = tuning.gravity
	if velocity.y < 0.0:
		gravity *= tuning.fall_gravity_multiplier
	velocity.y = maxf(velocity.y - gravity * delta * 0.5, -tuning.max_fall_speed)


## move_and_slide plus stepping up small ledges (curbs, debris) while grounded.
func move(delta: float) -> void:
	if tuning.step_height > 0.0 and is_on_floor() and _try_step_up(delta):
		return
	move_and_slide()


func teleport(target_position: Vector3, yaw: float = 0.0) -> void:
	global_position = target_position
	velocity = Vector3.ZERO
	facing_yaw = yaw
	visuals.rotation.y = yaw
	visuals.reset_offsets()
	if is_crouching:
		set_crouching(false, true)
	reset_physics_interpolation()
	state_machine.transition_to(&"Air")
	if camera_rig != null:
		camera_rig.snap_to_target()


# --- Combat -----------------------------------------------------------------

func _setup_combat() -> void:
	if combat == null:
		combat = load(DEFAULT_COMBAT_PATH)
	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = combat.max_health
	add_child(health)
	health.changed.connect(func(current: float, maximum: float) -> void: EventBus.health_changed.emit(current, maximum))
	hitbox = HitboxComponent.new()
	hitbox.name = "Hitbox"
	add_child(hitbox)
	hitbox.hit_landed.connect(_on_hit_landed)
	for path: String in WEAPON_PATHS:
		var data: WeaponData = load(path) as WeaponData
		if starting_weapons.is_empty() or starting_weapons.has(data.id):
			weapons.append(data)
	var footsteps := Footsteps.new()
	footsteps.name = "Footsteps"
	add_child(footsteps)
	injectors = combat.max_injectors
	throwables = combat.max_throwables
	equip_weapon(0, false)


## Re-announces health, injectors, bottles and weapon (for a HUD created later).
func emit_combat_status() -> void:
	EventBus.health_changed.emit(health.health, health.max_health)
	EventBus.injectors_changed.emit(injectors, combat.max_injectors)
	EventBus.throwables_changed.emit(throwables, combat.max_throwables)
	EventBus.weapon_changed.emit(weapon)


func _update_combat_timers(delta: float) -> void:
	light_buffer_timer = maxf(light_buffer_timer - delta, 0.0)
	heavy_buffer_timer = maxf(heavy_buffer_timer - delta, 0.0)
	hurt_invulnerable_time = maxf(hurt_invulnerable_time - delta, 0.0)
	throw_cooldown = maxf(throw_cooldown - delta, 0.0)
	if not input_enabled or is_dead():
		return
	if Input.is_action_just_pressed(&"light_attack"):
		light_buffer_timer = combat.attack_buffer_time
	if Input.is_action_just_pressed(&"heavy_attack"):
		heavy_buffer_timer = combat.attack_buffer_time
	for i: int in weapons.size():
		if Input.is_action_just_pressed(StringName("weapon_%d" % (i + 1))):
			equip_weapon(i)
	if Input.is_action_just_pressed(&"weapon_next"):
		equip_weapon(posmod(weapon_index + 1, weapons.size()))
	elif Input.is_action_just_pressed(&"weapon_prev"):
		equip_weapon(posmod(weapon_index - 1, weapons.size()))
	if heal_timer > 0.0:
		heal_timer -= delta
		if heal_timer <= 0.0:
			health.heal(combat.injector_heal)
			CombatFX.sfx(&"heal", global_position + Vector3.UP, -4.0)


## Adds a weapon found in the world and equips it. False if already owned.
func grant_weapon(weapon_id: String) -> bool:
	for owned: WeaponData in weapons:
		if owned.id == weapon_id:
			return false
	var order: Array[WeaponData] = []
	for path: String in WEAPON_PATHS:
		var data: WeaponData = load(path) as WeaponData
		if data.id == weapon_id or weapons.has(data):
			order.append(data)
	weapons = order
	GameState.weapons[weapon_id] = 0
	for i: int in weapons.size():
		if weapons[i].id == weapon_id:
			equip_weapon(i)
	return true


## Copies what a save needs from Kael into GameState.
func write_state() -> void:
	GameState.health = health.health
	GameState.max_health = health.max_health
	GameState.max_stamina = max_stamina
	GameState.injectors = injectors
	GameState.throwables = throwables
	GameState.equipped_weapon = weapon.id if weapon != null else "rebar_pipe"
	for owned: WeaponData in weapons:
		if not GameState.weapons.has(owned.id):
			GameState.weapons[owned.id] = 0


## Applies a loaded GameState to Kael: weapons, maximums, health, supplies.
func read_state() -> void:
	var order: Array[WeaponData] = []
	for path: String in WEAPON_PATHS:
		var data: WeaponData = load(path) as WeaponData
		if GameState.weapons.has(data.id):
			order.append(data)
	if not order.is_empty():
		weapons = order
		weapon_index = 0
		for i: int in weapons.size():
			if weapons[i].id == GameState.equipped_weapon:
				weapon_index = i
		equip_weapon(weapon_index, false)
	health.max_health = GameState.max_health
	health.health = clampf(GameState.health, 1.0, GameState.max_health)
	max_stamina = maxf(GameState.max_stamina, tuning.max_stamina)
	stamina = max_stamina
	injectors = GameState.injectors
	throwables = GameState.throwables
	emit_combat_status()
	EventBus.stamina_changed.emit(stamina, max_stamina)


## A Lung Core: more stamina, permanently.
func add_max_stamina(amount: float) -> void:
	max_stamina += amount
	stamina = max_stamina
	GameState.max_stamina = max_stamina
	EventBus.stamina_changed.emit(stamina, max_stamina)


func has_weapon(weapon_id: String) -> bool:
	for owned: WeaponData in weapons:
		if owned.id == weapon_id:
			return true
	return false


func is_dead() -> bool:
	return health != null and health.is_dead()


func is_healing() -> bool:
	return heal_timer > 0.0


func equip_weapon(index: int, announce: bool = true) -> void:
	if index < 0 or index >= weapons.size() or state_machine.is_in(&"Attack"):
		return
	weapon_index = index
	weapon = weapons[index]
	visuals.show_weapon(weapon)
	if announce:
		EventBus.weapon_changed.emit(weapon)


func consume_light_buffer() -> bool:
	if light_buffer_timer > 0.0:
		light_buffer_timer = 0.0
		return true
	return false


func consume_heavy_buffer() -> bool:
	if heavy_buffer_timer > 0.0:
		heavy_buffer_timer = 0.0
		return true
	return false


## Called every frame by states that allow combat actions (Ground, Block,
## the end of an attack). Starts the highest-priority action whose button is
## pressed and returns true if the state changed.
func try_combat_action(allow_block: bool = true) -> bool:
	if not input_enabled or is_dead():
		return false
	if takedown_target != null and is_action_just_pressed(&"interact"):
		state_machine.transition_to(&"Takedown", {"target": takedown_target})
		return true
	if (is_action_just_pressed(&"dodge") or double_tap_requested) and try_dodge():
		double_tap_requested = false
		return true
	if allow_block and is_block_wanted():
		if is_crouching and not set_crouching(false):
			return false
		state_machine.transition_to(&"Block")
		return true
	if (heavy_buffer_timer > 0.0 or light_buffer_timer > 0.0) and stamina > 0.0:
		if is_crouching and not set_crouching(false):
			return false
		if consume_heavy_buffer():
			light_buffer_timer = 0.0
			state_machine.transition_to(&"Attack", {"heavy": true})
		else:
			consume_light_buffer()
			state_machine.transition_to(&"Attack", {"combo": 0})
		return true
	if is_action_just_pressed(&"throw") and try_throw():
		return false
	if is_action_just_pressed(&"heal"):
		try_heal()
	return false


## Block is held by default; with "toggle block" one press raises the guard
## and the next lowers it.
var block_toggled: bool = false
var _block_toggle_frame: int = -1


func is_block_wanted() -> bool:
	if not SettingsManager.get_bool("controls", "toggle_block"):
		return is_action_held(&"block")
	if is_action_just_pressed(&"block") and _block_toggle_frame != Engine.get_physics_frames():
		_block_toggle_frame = Engine.get_physics_frames()
		block_toggled = not block_toggled
	return block_toggled and input_enabled


func try_dodge() -> bool:
	if not has_stamina(combat.dodge_stamina * 0.5):
		return false
	if is_crouching and not set_crouching(false):
		return false
	block_toggled = false
	state_machine.transition_to(&"Dodge")
	return true


func try_heal() -> bool:
	if injectors <= 0 or heal_timer > 0.0 or health.health >= health.max_health:
		return false
	injectors -= 1
	heal_timer = combat.injector_time
	EventBus.injectors_changed.emit(injectors, combat.max_injectors)
	return true


func try_throw() -> bool:
	if throwables <= 0 or throw_cooldown > 0.0:
		return false
	throwables -= 1
	throw_cooldown = combat.throw_cooldown
	EventBus.throwables_changed.emit(throwables, combat.max_throwables)
	var aim_yaw: float = get_camera_yaw()
	var aim_pitch: float = camera_rig.pitch if camera_rig != null else 0.0
	var direction := Vector3(0.0, 0.0, -1.0).rotated(Vector3.RIGHT, aim_pitch + 0.3).rotated(Vector3.UP, aim_yaw)
	var bottle := Throwable.new()
	get_parent().add_child(bottle)
	bottle.launch(self, global_position + Vector3.UP * 1.45 + direction * 0.4, direction * combat.throw_speed)
	return true


func add_throwables(amount: int) -> bool:
	if throwables >= combat.max_throwables:
		return false
	throwables = mini(throwables + amount, combat.max_throwables)
	EventBus.throwables_changed.emit(throwables, combat.max_throwables)
	return true


## Direction an attack should face: the lock-on target, else the stick, else forward.
func get_attack_direction() -> Vector3:
	if camera_rig != null and camera_rig.lock_target != null and is_instance_valid(camera_rig.lock_target):
		var to_target: Vector3 = camera_rig.lock_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			return to_target.normalized()
	var direction: Vector3 = get_move_direction()
	if direction.length_squared() > 0.04:
		return direction.normalized()
	return get_facing_direction()


## Gravity plus move_and_slide for states that stay on their feet.
func ground_move(delta: float) -> void:
	if is_on_floor():
		velocity.y = -2.0
		move_and_slide()
	else:
		apply_gravity_half(delta)
		move_and_slide()
		apply_gravity_half(delta)


func is_blocking() -> bool:
	return state_machine.is_in(&"Block")


func is_invulnerable() -> bool:
	if god_mode:
		return true
	return dodge_invulnerable or hurt_invulnerable_time > 0.0 or is_dead()


## Entry point for every hit aimed at Kael.
func receive_hit(hit: HitInfo) -> HitInfo.Result:
	if is_invulnerable():
		return HitInfo.Result.IGNORED
	if NewGamePlus.cycle() > 0:
		hit = hit.duplicate_hit()
		hit.damage *= NewGamePlus.enemy_damage_scale()
	var chest: Vector3 = global_position + Vector3.UP * 1.1
	var from_direction: Vector3 = hit.origin - global_position
	from_direction.y = 0.0
	from_direction = from_direction.normalized() if from_direction.length_squared() > 0.001 else get_facing_direction()

	if is_blocking() and hit.can_be_blocked:
		var in_front: bool = get_facing_direction().dot(from_direction) >= cos(deg_to_rad(combat.block_arc_degrees))
		if in_front:
			var block_state: Node = state_machine.current
			if hit.can_be_parried and bool(block_state.call(&"can_parry_now")):
				_on_parry(hit, chest)
				return HitInfo.Result.PARRIED
			return _on_blocked(hit, chest, from_direction)

	var amount: float = hit.damage * combat.get_damage_taken_multiplier()
	health.apply_damage(amount)
	heal_timer = 0.0
	hurt_invulnerable_time = combat.hurt_invulnerable_time
	visuals.flash(Color(1.0, 0.35, 0.3))
	CombatFX.sfx(&"hurt", chest)
	CombatFX.shake(0.25 if hit.poise < combat.stagger_poise else 0.45)
	CombatFX.rumble(0.5, 0.7, 0.2)
	if health.is_dead():
		state_machine.transition_to(&"Dead")
		return HitInfo.Result.KILLED
	if hit.poise > 0.0 and not state_machine.is_in(&"Takedown"):
		if state_machine.is_in(&"Ladder") or state_machine.is_in(&"LedgeHang") or state_machine.is_in(&"Mantle"):
			velocity = Vector3.ZERO
			state_machine.transition_to(&"Air")
		elif not state_machine.is_in(&"Air"):
			state_machine.transition_to(&"Hurt", {
				"stagger": hit.poise >= combat.stagger_poise, "from": from_direction})
	return HitInfo.Result.HIT


func revive() -> void:
	health.revive()
	stamina = max_stamina
	injectors = combat.max_injectors
	throwables = combat.max_throwables
	heal_timer = 0.0
	hurt_invulnerable_time = 0.0
	dodge_invulnerable = false
	input_enabled = true
	emit_combat_status()
	EventBus.stamina_changed.emit(stamina, max_stamina)
	EventBus.player_respawned.emit()


func _on_parry(hit: HitInfo, chest: Vector3) -> void:
	if hit.attacker != null and hit.attacker.has_method(&"on_parried"):
		hit.attacker.call(&"on_parried", self)
	visuals.flash(Color(0.6, 0.95, 1.0))
	CombatFX.sfx(&"parry", chest, 2.0)
	CombatFX.impact(chest + get_facing_direction() * 0.5, get_facing_direction(), true, 22)
	CombatFX.hit_stop(combat.hitstop_parry)
	CombatFX.shake(0.3)
	CombatFX.rumble(0.8, 0.4, 0.15)
	EventBus.toast_requested.emit("PARRY", 0.7)


func _on_blocked(hit: HitInfo, chest: Vector3, from_direction: Vector3) -> HitInfo.Result:
	var amount: float = hit.damage * combat.block_damage_multiplier * combat.get_damage_taken_multiplier()
	spend_stamina(hit.damage * combat.block_stamina_per_damage)
	CombatFX.impact(chest + from_direction * 0.4, from_direction, true, 10)
	if stamina <= 0.0 or hit.breaks_guard:
		health.apply_damage(amount)
		CombatFX.sfx(&"guard_break", chest)
		CombatFX.shake(0.4)
		if health.is_dead():
			state_machine.transition_to(&"Dead")
			return HitInfo.Result.KILLED
		state_machine.transition_to(&"Hurt", {"stagger": true, "from": from_direction, "duration": combat.guard_break_time})
		return HitInfo.Result.BLOCKED
	health.apply_damage(amount)
	CombatFX.sfx(&"block", chest)
	CombatFX.shake(0.15)
	visuals.play_action(&"Block_Hit")
	if health.is_dead():
		state_machine.transition_to(&"Dead")
		return HitInfo.Result.KILLED
	return HitInfo.Result.BLOCKED


func _on_hit_landed(target: Node3D, result: HitInfo.Result, hit: HitInfo) -> void:
	var point: Vector3 = target.global_position + Vector3.UP * 1.0
	var away: Vector3 = (target.global_position - global_position).normalized()
	match result:
		HitInfo.Result.ARMORED:
			CombatFX.sfx(&"hit_armor", point)
			CombatFX.impact(point, -away, true, 16)
			CombatFX.hit_stop(combat.hitstop_light)
			CombatFX.shake(combat.shake_light)
		HitInfo.Result.BLOCKED, HitInfo.Result.PARRIED:
			CombatFX.sfx(&"block", point)
			CombatFX.impact(point, -away, true, 10)
		_:
			CombatFX.sfx(&"hit_heavy" if hit.is_heavy else &"hit_light", point)
			CombatFX.impact(point, away, false, 20 if hit.is_heavy else 12)
			CombatFX.hit_stop(combat.hitstop_heavy if hit.is_heavy else combat.hitstop_light)
			CombatFX.shake(combat.shake_heavy if hit.is_heavy else combat.shake_light)
			CombatFX.rumble(0.3, 0.6 if hit.is_heavy else 0.25, 0.12)


# --- Stealth ----------------------------------------------------------------

func is_in_shadow() -> bool:
	return shadow_zones > 0


## Crouched in tall grass (or similar cover): nearly invisible until very close.
func is_hidden() -> bool:
	return hide_zones > 0 and is_crouching


func _find_takedown_target() -> Node3D:
	if not state_machine.is_in(&"Ground"):
		return null
	var best: Node3D = null
	var best_distance: float = combat.takedown_range
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node3D = node as Node3D
		if enemy == null or not enemy.has_method(&"can_be_taken_down"):
			continue
		var distance: float = enemy.global_position.distance_to(global_position)
		if distance < best_distance and bool(enemy.call(&"can_be_taken_down", self)):
			best = enemy
			best_distance = distance
	return best


# --- Crouch -----------------------------------------------------------------

## Returns false when standing up is blocked by a low ceiling.
func set_crouching(crouch: bool, force: bool = false) -> bool:
	if crouch == is_crouching:
		return true
	if not crouch and not force and not can_stand_up():
		return false
	is_crouching = crouch
	_apply_capsule_height(tuning.crouch_height if crouch else tuning.stand_height)
	return true


func can_stand_up() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = tuning.body_radius - 0.02
	shape.height = tuning.stand_height - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (tuning.stand_height * 0.5 + 0.03))
	query.collision_mask = LAYER_WORLD
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func get_current_height() -> float:
	return _capsule.height


func _apply_capsule_height(height: float) -> void:
	_capsule.radius = tuning.body_radius
	_capsule.height = height
	collider.position.y = height * 0.5


# --- Stamina ----------------------------------------------------------------

func spend_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = maxf(stamina - amount, 0.0)
	_stamina_idle_time = 0.0
	EventBus.stamina_changed.emit(stamina, max_stamina)


func has_stamina(amount: float) -> bool:
	return stamina >= amount


## Decides whether Kael sprints this frame and drains stamina if so.
func update_sprint(wants_to_move: bool, delta: float) -> bool:
	var held: bool = is_action_held(&"sprint")
	if SettingsManager.get_bool("controls", "toggle_sprint"):
		if is_action_just_pressed(&"sprint"):
			_sprint_latched = not _sprint_latched
		if not wants_to_move:
			_sprint_latched = false
		held = _sprint_latched
	if not held:
		_sprint_locked_out = false
	var can_sprint: bool = held and wants_to_move and not is_crouching and not _sprint_locked_out
	if can_sprint and not is_sprinting and stamina < tuning.min_stamina_to_sprint:
		can_sprint = false
	if can_sprint:
		spend_stamina(tuning.sprint_stamina_per_second * delta)
		if stamina <= 0.0:
			_sprint_locked_out = true
			_sprint_latched = false
			can_sprint = false
	is_sprinting = can_sprint
	return is_sprinting


func _update_stamina(delta: float) -> void:
	_stamina_idle_time += delta
	if _stamina_idle_time >= tuning.stamina_regen_delay and stamina < max_stamina:
		stamina = minf(stamina + tuning.stamina_regen_per_second * delta, max_stamina)
		EventBus.stamina_changed.emit(stamina, max_stamina)


# --- Noise (stealth scaffolding) --------------------------------------------

func emit_noise(radius: float) -> void:
	if radius > 0.0:
		EventBus.noise_emitted.emit(global_position, radius, self)


func _update_noise(delta: float) -> void:
	noise_radius = 0.0
	if state_machine.is_in(&"Ground") and get_horizontal_speed() > 0.3:
		match move_mode:
			MoveMode.SPRINT: noise_radius = tuning.noise_sprint
			MoveMode.JOG: noise_radius = tuning.noise_jog
			MoveMode.WALK: noise_radius = tuning.noise_walk
			MoveMode.CROUCH: noise_radius = tuning.noise_crouch
	_noise_timer -= delta
	if noise_radius > 0.0 and _noise_timer <= 0.0:
		_noise_timer = 0.35
		emit_noise(noise_radius)


# --- Stair stepping ---------------------------------------------------------

func _try_step_up(delta: float) -> bool:
	var horizontal: Vector3 = get_horizontal_velocity()
	if horizontal.length_squared() < 0.04 or velocity.y > 0.5:
		return false
	var start: Transform3D = global_transform
	var motion: Vector3 = horizontal * delta
	# 1. Is the way ahead blocked by something wall-like?
	if not _test_motion(start, motion):
		return false
	# The capsule's rounded base meets the lip of a low step at a slanted angle,
	# so only contacts the body could simply walk up are left to move_and_slide.
	var blocker_normal: Vector3 = _motion_result.get_collision_normal()
	if blocker_normal.y >= cos(floor_max_angle):
		return false
	if horizontal.normalized().dot(Vector3(blocker_normal.x, 0.0, blocker_normal.z).normalized()) > -0.35:
		return false
	# 2. Rise by the step height (less under a low ceiling).
	var rise: Vector3 = Vector3.UP * tuning.step_height
	if _test_motion(start, rise):
		rise = _motion_result.get_travel()
	if rise.y < 0.04:
		return false
	# 3. Move forward far enough to stand on the step, not balance on its edge.
	var raised: Transform3D = start.translated(rise)
	var forward: Vector3 = horizontal.normalized() * maxf(motion.length(), tuning.body_radius * 0.5)
	if _test_motion(raised, forward):
		return false
	# 4. Settle back down; it must land on walkable ground higher than before.
	var over_step: Transform3D = raised.translated(forward)
	if not _test_motion(over_step, Vector3.DOWN * (rise.y + 0.05)):
		return false
	if _motion_result.get_collision_normal().y < cos(floor_max_angle):
		return false
	var landed: Vector3 = over_step.origin + _motion_result.get_travel()
	var gained: float = landed.y - start.origin.y
	if gained < 0.03:
		return false
	var before: Vector3 = global_position
	global_position = landed
	velocity.y = 0.0
	visuals.absorb_step(before + motion - landed)
	return true


func _test_motion(from: Transform3D, motion: Vector3) -> bool:
	_motion_params.from = from
	_motion_params.motion = motion
	_motion_params.margin = safe_margin
	_motion_params.recovery_as_collision = false
	return PhysicsServer3D.body_test_motion(get_rid(), _motion_params, _motion_result)


func _on_state_changed(previous: StringName, current: StringName) -> void:
	EventBus.player_state_changed.emit(previous, current)
