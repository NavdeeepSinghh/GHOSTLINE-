class_name Enemy
extends CharacterBody3D
## One enemy. Behaviour is a state machine driven by its senses:
##
##   PATROL -> SUSPICIOUS -> INVESTIGATE -> COMBAT <-> ATTACK -> SEARCH -> PATROL
##
## plus reactions (HIT, STAGGER, STUNNED), TAKEDOWN and DEAD. What kind of enemy
## it is (Hollow, Skitter, Bulwark, Spitter) comes entirely from its EnemyData.

signal state_changed(previous: AIState, current: AIState)
signal died(enemy: Enemy)

enum AIState { PATROL, SUSPICIOUS, INVESTIGATE, COMBAT, ATTACK, SEARCH, HIT, STAGGER, STUNNED, TAKEDOWN, DEAD }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }

const GRAVITY: float = 24.0
const CIRCLE_DISTANCE: float = 3.4
const FAR_THINK_DISTANCE: float = 26.0
const FAR_THINK_FRAMES: int = 6
const SUSPICION_SECONDS: float = 1.3
const CORPSE_SECONDS: float = 10.0
const REPATH_SECONDS: float = 0.45
const WAYPOINT_REACHED: float = 0.7

@export var data: EnemyData
## World points walked in order; empty means stand guard.
@export var patrol_points: Array[Vector3] = []

var state: AIState = AIState.PATROL
var state_time: float = 0.0
## Radians; 0 faces -Z.
var facing_yaw: float = 0.0
var health: HealthComponent
var perception: PerceptionComponent
var visuals: EnemyVisuals
var hitbox: HitboxComponent
var target: Player
var last_known_position: Vector3
var armor_points: float = 0.0
var attack_phase: AttackPhase = AttackPhase.WINDUP
var attack_cooldown: float = 0.0

var _home: Vector3
var _home_yaw: float = 0.0
var _patrol_index: int = 0
var _wait: float = 0.0
var _lost_time: float = 0.0
var _poise_damage: float = 0.0
var _reaction_time: float = 0.0
var _search_points: Array[Vector3] = []
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _attack_done: bool = false
var _feint_time: float = 0.0
var _frame: int = 0
var _look_base_yaw: float = 0.0
var _path: PackedVector3Array = []
var _path_index: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_timer: float = 0.0
var _asleep: bool = false


func _ready() -> void:
	facing_yaw = rotation.y
	rotation.y = 0.0
	_home = global_position
	_home_yaw = facing_yaw
	last_known_position = global_position
	collision_layer = Player.LAYER_ENEMY
	collision_mask = Player.LAYER_WORLD | Player.LAYER_PLAYER | Player.LAYER_ENEMY
	floor_snap_length = 0.3
	var capsule := CapsuleShape3D.new()
	capsule.radius = data.body_radius
	capsule.height = data.body_height
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = data.body_height * 0.5
	add_child(collider)

	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = data.max_health * NewGamePlus.enemy_health_scale()
	add_child(health)
	armor_points = data.armor
	perception = PerceptionComponent.new()
	perception.name = "Perception"
	add_child(perception)
	hitbox = HitboxComponent.new()
	hitbox.name = "Hitbox"
	hitbox.height = data.body_height * 0.6
	add_child(hitbox)
	visuals = EnemyVisuals.new()
	visuals.name = "Visuals"
	add_child(visuals)
	visuals.setup(data)
	visuals.rotation.y = facing_yaw

	add_to_group(&"enemies")
	add_to_group(CameraRig.LOCK_ON_GROUP)
	_strafe_sign = 1.0 if randf() > 0.5 else -1.0
	_frame = randi() % FAR_THINK_FRAMES


func _exit_tree() -> void:
	CombatDirector.release(self)
	CombatDirector.disengage(self)


## Set when this enemy starts clinging to a wall (see WallPerch).
var perch: WallPerch


func _physics_process(delta: float) -> void:
	if perch != null and is_instance_valid(perch) and perch.holds_enemy():
		return
	if state == AIState.DEAD:
		_apply_gravity(delta)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Player
		perception.target = target
	state_time += delta
	_repath_timer -= delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	_poise_damage = maxf(_poise_damage - 6.0 * delta, 0.0)
	_think(delta)

	match state:
		AIState.PATROL: _state_patrol(delta)
		AIState.SUSPICIOUS: _state_suspicious(delta)
		AIState.INVESTIGATE: _state_investigate(delta)
		AIState.COMBAT: _state_combat(delta)
		AIState.ATTACK: _state_attack(delta)
		AIState.SEARCH: _state_search(delta)
		AIState.HIT, AIState.STAGGER, AIState.STUNNED: _state_reaction(delta)
		AIState.TAKEDOWN: _stop(delta)

	_apply_gravity(delta)
	move_and_slide()
	visuals.rotation.y = facing_yaw
	_update_locomotion_animation()


# --- Public API ---------------------------------------------------------------

func get_facing_direction() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


func get_lock_on_point() -> Vector3:
	return global_position + Vector3.UP * data.body_height * 0.62


func get_marker_point() -> Vector3:
	return global_position + Vector3.UP * (data.body_height + 0.35)


func is_dead() -> bool:
	return state == AIState.DEAD


func is_aware() -> bool:
	return state in [AIState.COMBAT, AIState.ATTACK, AIState.SEARCH, AIState.HIT, AIState.STAGGER]


func has_armor() -> bool:
	return armor_points > 0.0


## Far-away enemies are put to sleep by the level: no thinking, no drawing.
## An enemy that is fighting or hunting never sleeps.
func set_asleep(asleep: bool) -> void:
	if asleep == _asleep or state == AIState.DEAD:
		return
	if asleep and (is_aware() or state == AIState.TAKEDOWN):
		return
	_asleep = asleep
	set_physics_process(not asleep)
	visible = not asleep


func is_asleep() -> bool:
	return _asleep


## Another enemy (or a script) tells this one where the player is.
func alert(position: Vector3) -> void:
	set_asleep(false)
	if state in [AIState.PATROL, AIState.SUSPICIOUS, AIState.INVESTIGATE, AIState.SEARCH]:
		last_known_position = position
		perception.detection = 1.0
		_set_state(AIState.COMBAT)


func stun(seconds: float) -> void:
	if not data.stunnable or state == AIState.DEAD or state == AIState.TAKEDOWN:
		return
	_interrupt_attack()
	_reaction_time = seconds
	_set_state(AIState.STUNNED)
	state_time = 0.0
	visuals.play_once(data.stagger_clip, 0.35)


## The player parried this enemy's attack.
func on_parried(_by: Node3D) -> void:
	if state == AIState.DEAD:
		return
	_interrupt_attack()
	_reaction_time = data.parried_stagger_time
	_set_state(AIState.STAGGER)
	visuals.play_once(data.stagger_clip, 0.6)
	visuals.flash()


func can_be_taken_down(by: Player) -> bool:
	if not data.takedown_allowed or state == AIState.DEAD or state == AIState.TAKEDOWN:
		return false
	if state == AIState.STUNNED:
		return true
	if is_aware():
		return false
	var to_player: Vector3 = by.global_position - global_position
	to_player.y = 0.0
	return get_facing_direction().dot(to_player.normalized()) < -0.25


func begin_takedown(_by: Player) -> void:
	_interrupt_attack()
	_set_state(AIState.TAKEDOWN)
	visuals.play_once(data.stagger_clip, 0.5)


func finish_takedown() -> void:
	if state != AIState.DEAD:
		health.apply_damage(health.health)
		_die(true)


func receive_hit(hit: HitInfo) -> HitInfo.Result:
	if state == AIState.DEAD or state == AIState.TAKEDOWN:
		return HitInfo.Result.IGNORED
	if perch != null and is_instance_valid(perch) and not perch.letting_go:
		perch.drop()
	var amount: float = hit.damage
	if data.is_echo_infused:
		amount *= hit.echo_multiplier
	# Striking an enemy that has not noticed Kael hits harder.
	if not is_aware() and state != AIState.STUNNED:
		amount *= 1.5
	var result: HitInfo.Result = HitInfo.Result.HIT
	var armor_broke: bool = false
	if armor_points > 0.0:
		if hit.is_heavy or hit.armor_multiplier > 1.0:
			armor_points -= amount * hit.armor_multiplier
			amount *= 0.5
			armor_broke = armor_points <= 0.0
		else:
			amount *= data.armor_light_multiplier
			result = HitInfo.Result.ARMORED
	health.apply_damage(amount)
	visuals.flash()
	if hit.attacker != null:
		last_known_position = hit.attacker.global_position
	if health.is_dead():
		_die(false)
		return HitInfo.Result.KILLED

	if armor_broke:
		armor_points = 0.0
		visuals.break_armor()
		CombatFX.sfx(&"guard_break", get_lock_on_point(), 2.0)
		CombatFX.impact(get_lock_on_point(), Vector3.UP, true, 30)
		_begin_reaction(AIState.STAGGER, data.stagger_time)
	elif hit.stun > 0.0 and data.stunnable:
		stun(hit.stun)
	elif result == HitInfo.Result.HIT:
		_poise_damage += hit.poise
		if _poise_damage >= data.stagger_threshold:
			_poise_damage = 0.0
			_begin_reaction(AIState.STAGGER, data.stagger_time)
		elif data.flinches and hit.poise > 0.0:
			_begin_reaction(AIState.HIT, data.flinch_time)
	if state in [AIState.PATROL, AIState.SUSPICIOUS, AIState.INVESTIGATE, AIState.SEARCH]:
		perception.detection = 1.0
		_set_state(AIState.COMBAT)
	return result


## Puts the enemy back where it started, as if nothing had happened.
func reset_to_home() -> void:
	CombatDirector.release(self)
	global_position = _home
	facing_yaw = _home_yaw
	velocity = Vector3.ZERO
	perception.reset()
	_patrol_index = 0
	attack_cooldown = 0.0
	_set_state(AIState.PATROL)
	reset_physics_interpolation()


# --- Thinking -----------------------------------------------------------------

## Updates the senses. Enemies far from the player think less often.
func _think(delta: float) -> void:
	_frame += 1
	var alerted: bool = is_aware()
	if target != null and not alerted and global_position.distance_squared_to(target.global_position) > FAR_THINK_DISTANCE * FAR_THINK_DISTANCE:
		if _frame % FAR_THINK_FRAMES == 0:
			perception.update(delta * FAR_THINK_FRAMES, false)
		return
	perception.update(delta, alerted)


func _set_state(next: AIState) -> void:
	if next == state:
		return
	var previous: AIState = state
	# Never more than a handful of enemies hunting Kael at once: the rest hold
	# their posts (still alarmed) until a place in the fight frees up.
	if next == AIState.COMBAT and not CombatDirector.engage(self):
		return
	if next in [AIState.PATROL, AIState.SUSPICIOUS, AIState.INVESTIGATE]:
		CombatDirector.disengage(self)
	_path_goal = Vector3.INF
	state = next
	state_time = 0.0
	_wait = 0.0
	match next:
		AIState.COMBAT:
			_lost_time = 0.0
			if previous in [AIState.PATROL, AIState.SUSPICIOUS, AIState.INVESTIGATE, AIState.SEARCH]:
				_on_spotted()
		AIState.SEARCH:
			_build_search_points()
		AIState.SUSPICIOUS, AIState.INVESTIGATE:
			_look_base_yaw = facing_yaw
	state_changed.emit(previous, next)


func _on_spotted() -> void:
	CombatFX.sfx(&"enemy_alert", get_lock_on_point(), -2.0)
	attack_cooldown = maxf(attack_cooldown, 0.5)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var ally: Enemy = node as Enemy
		if ally != null and ally != self and ally.global_position.distance_to(global_position) <= data.alert_radius:
			ally.alert(last_known_position)


# --- States -------------------------------------------------------------------

func _state_patrol(delta: float) -> void:
	if _react_to_senses():
		return
	if patrol_points.is_empty():
		# Standing guard: walk home if displaced, then face the original way.
		if _flat_distance(_home) > 0.6:
			_steer_to(_home, data.walk_speed, delta)
		else:
			_stop(delta)
			facing_yaw = rotate_toward(facing_yaw, _home_yaw, data.turn_speed * 0.4 * delta)
		return
	if _wait > 0.0:
		_wait -= delta
		_stop(delta)
		# Look left and right while pausing.
		facing_yaw += sin(state_time * 1.7) * 0.6 * delta
		return
	var point: Vector3 = patrol_points[_patrol_index]
	if _flat_distance(point) < 0.5:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_wait = randf_range(1.2, 2.6)
		return
	_steer_to(point, data.walk_speed, delta)


func _state_suspicious(delta: float) -> void:
	_stop(delta)
	if perception.is_spotted():
		_set_state(AIState.COMBAT)
		return
	if perception.consume_heard():
		last_known_position = perception.heard_position
	elif perception.sees_target:
		last_known_position = target.global_position
	_face_point(last_known_position, delta)
	if state_time >= SUSPICION_SECONDS:
		_set_state(AIState.INVESTIGATE)


func _state_investigate(delta: float) -> void:
	if perception.is_spotted():
		_set_state(AIState.COMBAT)
		return
	if perception.consume_heard():
		last_known_position = perception.heard_position
		_wait = 0.0
	elif perception.sees_target:
		last_known_position = target.global_position
	if _wait > 0.0:
		_wait -= delta
		_stop(delta)
		facing_yaw = _look_base_yaw + sin((2.6 - _wait) * 2.2) * 1.1
		if _wait <= 0.0:
			_set_state(AIState.PATROL)
		return
	if _flat_distance(last_known_position) < 1.1 or state_time > 12.0:
		_wait = 2.6
		_look_base_yaw = facing_yaw
		return
	_steer_to(last_known_position, data.walk_speed * 1.5, delta)


func _state_combat(delta: float) -> void:
	if target == null or target.is_dead():
		CombatDirector.release(self)
		_set_state(AIState.PATROL)
		return
	if perception.sees_target:
		last_known_position = target.global_position
		_lost_time = 0.0
	else:
		_lost_time += delta
		if _lost_time >= data.lose_target_time:
			CombatDirector.release(self)
			_set_state(AIState.SEARCH)
			return
	if data.attack_kind == EnemyData.AttackKind.RANGED:
		_combat_ranged(delta)
	else:
		_combat_melee(delta)


func _combat_melee(delta: float) -> void:
	var distance: float = _flat_distance(last_known_position)
	var is_dash: bool = data.attack_kind == EnemyData.AttackKind.DASH
	if _feint_time > 0.0:
		# A Skitter's feint: a quick sidestep before it commits.
		_feint_time -= delta
		_strafe(delta, data.chase_speed * 0.9)
		if _feint_time <= 0.0:
			_begin_attack()
		return
	var in_range: bool = distance <= data.attack_range and perception.sees_target
	if in_range and attack_cooldown <= 0.0 and CombatDirector.request(self):
		if is_dash:
			_feint_time = 0.32
			_strafe_sign = -_strafe_sign
		else:
			_begin_attack()
		return
	var has_slot: bool = CombatDirector.holds(self) or CombatDirector.count() < CombatDirector.MAX_ATTACKERS
	var hold_distance: float = data.attack_range * 0.8 if has_slot else maxf(CIRCLE_DISTANCE, data.attack_range)
	if is_dash:
		hold_distance = data.attack_range * 0.8
	if distance > hold_distance + 0.4:
		_steer_to(last_known_position, data.chase_speed, delta)
	elif distance < hold_distance - 0.8 and not has_slot:
		_steer_dir(-_direction_to(last_known_position), data.walk_speed, delta, false)
		_face_point(last_known_position, delta)
	else:
		# Waiting for an opening: circle the player.
		_strafe(delta, data.walk_speed * (1.6 if is_dash else 0.9))


func _combat_ranged(delta: float) -> void:
	var distance: float = _flat_distance(last_known_position)
	if perception.sees_target and attack_cooldown <= 0.0 and distance <= data.ranged_max_distance + 1.0 \
			and distance >= data.ranged_min_distance * 0.6:
		_begin_attack()
		return
	if not perception.sees_target or distance > data.ranged_max_distance:
		_steer_to(last_known_position, data.chase_speed, delta)
	elif distance < data.ranged_min_distance:
		# Too close: back away while keeping eyes on the player.
		_steer_dir(-_direction_to(last_known_position), data.chase_speed * 0.85, delta, false)
		_face_point(last_known_position, delta)
	else:
		_strafe(delta, data.walk_speed * 0.7)


func _begin_attack() -> void:
	_set_state(AIState.ATTACK)
	attack_phase = AttackPhase.WINDUP
	_attack_done = false
	visuals.set_telegraph(true)
	CombatFX.sfx(&"enemy_telegraph", get_lock_on_point(), -4.0)
	var impact: float = visuals.get_clip_length(data.attack_clip) * data.attack_impact_fraction
	visuals.play_once(data.attack_clip, impact / maxf(data.attack_windup, 0.05))


func _state_attack(delta: float) -> void:
	match attack_phase:
		AttackPhase.WINDUP:
			_stop(delta)
			# Tracks the player through most of the windup, then commits to a direction.
			if state_time < data.attack_windup * 0.75:
				_face_point(target.global_position if target != null else last_known_position, delta)
			if state_time >= data.attack_windup:
				attack_phase = AttackPhase.ACTIVE
				state_time = 0.0
				visuals.set_telegraph(false)
				visuals.set_speed(1.0)
				_start_active()
		AttackPhase.ACTIVE:
			# Lunge forward, but do not shove into a target that is already in reach.
			var lunge: float = data.attack_lunge_speed
			if target != null and _flat_distance(target.global_position) < data.body_radius + 0.75:
				lunge = 0.0
			var forward: Vector3 = get_facing_direction()
			velocity.x = forward.x * lunge
			velocity.z = forward.z * lunge
			if state_time >= data.attack_active:
				hitbox.end()
				attack_phase = AttackPhase.RECOVERY
				state_time = 0.0
		AttackPhase.RECOVERY:
			_stop(delta)
			if state_time >= data.attack_recovery:
				_end_attack()


func _start_active() -> void:
	match data.attack_kind:
		EnemyData.AttackKind.MELEE, EnemyData.AttackKind.DASH:
			hitbox.begin(_build_hit(), data.attack_reach, data.attack_radius, Player.LAYER_PLAYER)
			CombatFX.sfx(&"swing_light", get_lock_on_point(), -5.0)
		EnemyData.AttackKind.SLAM:
			_slam()
		EnemyData.AttackKind.RANGED:
			_spit()


func _build_hit() -> HitInfo:
	var hit := HitInfo.new()
	hit.attacker = self
	hit.origin = global_position
	hit.damage = data.attack_damage
	hit.poise = data.attack_poise
	hit.breaks_guard = data.attack_breaks_guard
	return hit


## Ground slam: a shockwave around the enemy. Jump over it or roll through it.
func _slam() -> void:
	CombatFX.sfx(&"slam", global_position, 3.0)
	CombatFX.shake(0.4)
	CombatFX.impact(global_position + get_facing_direction() * 1.2 + Vector3.UP * 0.1, Vector3.UP, true, 26)
	if target == null:
		return
	var offset: Vector3 = target.global_position - global_position
	var airborne: bool = offset.y > 0.45
	offset.y = 0.0
	if offset.length() <= data.slam_radius and not airborne:
		var hit: HitInfo = _build_hit()
		hit.can_be_parried = false
		target.receive_hit(hit)


func _spit() -> void:
	var glob := EchoGlob.new()
	glob.damage = data.attack_damage
	get_parent().add_child(glob)
	var start: Vector3 = global_position + Vector3.UP * data.eye_height + get_facing_direction() * 0.5
	var aim: Vector3 = last_known_position + Vector3.UP * 0.2
	if target != null and perception.sees_target:
		# Lead the shot a little.
		aim = target.global_position + target.get_horizontal_velocity() * data.projectile_flight_time * 0.6 + Vector3.UP * 0.2
	glob.launch(self, start, Ballistic.solve_arc(start, aim, data.projectile_flight_time, glob.gravity))
	CombatFX.sfx(&"spit", start)


func _end_attack() -> void:
	CombatDirector.release(self)
	attack_cooldown = data.attack_cooldown * randf_range(0.8, 1.3)
	_set_state(AIState.COMBAT)


func _interrupt_attack() -> void:
	hitbox.end()
	visuals.set_telegraph(false)
	_feint_time = 0.0
	CombatDirector.release(self)
	if state == AIState.ATTACK:
		attack_cooldown = data.attack_cooldown * 0.6


func _state_search(delta: float) -> void:
	if perception.is_spotted() and perception.sees_target:
		_set_state(AIState.COMBAT)
		return
	if perception.consume_heard():
		_search_points.push_front(perception.heard_position)
		_wait = 0.0
	if _search_points.is_empty():
		perception.detection = 0.0
		_set_state(AIState.PATROL)
		return
	if _wait > 0.0:
		_wait -= delta
		_stop(delta)
		facing_yaw += 1.8 * delta
		if _wait <= 0.0:
			_search_points.pop_front()
		return
	if _flat_distance(_search_points[0]) < 1.0 or state_time > 5.0:
		_wait = 1.3
		state_time = 0.0
		return
	_steer_to(_search_points[0], data.walk_speed * 1.6, delta)


func _state_reaction(delta: float) -> void:
	_stop(delta, 10.0)
	if state_time < _reaction_time:
		return
	if state == AIState.STUNNED and perception.detection < 1.0:
		_set_state(AIState.SEARCH)
	else:
		perception.detection = 1.0
		_set_state(AIState.COMBAT)


func _begin_reaction(reaction: AIState, seconds: float) -> void:
	_interrupt_attack()
	_reaction_time = seconds
	_set_state(reaction)
	state_time = 0.0
	visuals.play_once(data.hit_clip if reaction == AIState.HIT else data.stagger_clip,
			1.6 if reaction == AIState.HIT else 0.7)
	if target != null:
		var push: Vector3 = -_direction_to(target.global_position) * (2.0 if reaction == AIState.HIT else 3.5)
		velocity.x = push.x
		velocity.z = push.z


func _die(silent: bool) -> void:
	_interrupt_attack()
	CombatDirector.disengage(self)
	var previous: AIState = state
	state = AIState.DEAD
	collision_layer = 0
	collision_mask = Player.LAYER_WORLD
	remove_from_group(&"enemies")
	remove_from_group(CameraRig.LOCK_ON_GROUP)
	visuals.set_dead()
	visuals.play_once(data.death_clip, 1.3)
	if not silent:
		CombatFX.sfx(&"enemy_death", get_lock_on_point())
	state_changed.emit(previous, AIState.DEAD)
	died.emit(self)
	EventBus.enemy_died.emit(self)
	var tree: SceneTree = get_tree()
	tree.create_timer(CORPSE_SECONDS - 2.0, false).timeout.connect(visuals.start_fade)
	tree.create_timer(CORPSE_SECONDS, false).timeout.connect(queue_free)


# --- Senses -> decisions --------------------------------------------------------

## Shared by PATROL: reacts to sight and sound. Returns true if the state changed.
func _react_to_senses() -> bool:
	if perception.is_spotted():
		last_known_position = target.global_position
		_set_state(AIState.COMBAT)
		return true
	if perception.consume_heard():
		last_known_position = perception.heard_position
		_set_state(AIState.SUSPICIOUS)
		return true
	if perception.detection >= 0.35 and perception.sees_target:
		last_known_position = target.global_position
		_set_state(AIState.SUSPICIOUS)
		return true
	return false


func _build_search_points() -> void:
	_search_points = [last_known_position]
	for i: int in 3:
		var angle: float = randf() * TAU
		_search_points.append(last_known_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(3.0, 6.0))


# --- Movement helpers -----------------------------------------------------------

func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _direction_to(point: Vector3) -> Vector3:
	var direction := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	return direction.normalized() if direction.length_squared() > 0.0001 else get_facing_direction()


func _steer_to(point: Vector3, speed: float, delta: float) -> void:
	_steer_dir(_direction_to(_next_waypoint(point)), speed, delta, true)


## The next point to walk toward on the way to `goal`. Follows the level's
## navigation mesh when there is one; otherwise heads straight for the goal.
func _next_waypoint(goal: Vector3) -> Vector3:
	if _repath_timer <= 0.0 or goal.distance_squared_to(_path_goal) > 2.25:
		_repath_timer = REPATH_SECONDS * randf_range(0.85, 1.2)
		_path_goal = goal
		_path = PackedVector3Array()
		_path_index = 0
		var map: RID = get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
	while _path_index < _path.size() - 1 and _flat_distance(_path[_path_index]) < WAYPOINT_REACHED:
		_path_index += 1
	if _path.size() < 2 or _path_index >= _path.size() - 1:
		return goal
	return _path[_path_index]


func _steer_dir(direction: Vector3, speed: float, delta: float, face: bool) -> void:
	var desired: Vector3 = direction * speed + _separation() * 2.0
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, 18.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if face:
		_face_direction(direction, delta)


func _strafe(delta: float, speed: float) -> void:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0 or is_on_wall():
		_strafe_timer = randf_range(1.2, 2.8)
		if randf() < 0.4 or is_on_wall():
			_strafe_sign = -_strafe_sign
	var to_target: Vector3 = _direction_to(last_known_position)
	var tangent: Vector3 = Vector3.UP.cross(to_target) * _strafe_sign
	_steer_dir(tangent, speed, delta, false)
	_face_point(last_known_position, delta)


func _stop(delta: float, deceleration: float = 24.0) -> void:
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _face_point(point: Vector3, delta: float) -> void:
	_face_direction(_direction_to(point), delta)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	facing_yaw = rotate_toward(facing_yaw, atan2(-direction.x, -direction.z), data.turn_speed * delta)


## Keeps enemies from stacking on top of each other.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other: Node3D = node as Node3D
		if other == self or other == null:
			continue
		var offset: Vector3 = global_position - other.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > 0.001 and distance < 1.4:
			push += offset / distance * (1.4 - distance)
	return push


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)


func _update_locomotion_animation() -> void:
	if state in [AIState.ATTACK, AIState.HIT, AIState.STAGGER, AIState.STUNNED, AIState.TAKEDOWN, AIState.DEAD]:
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed < 0.25:
		visuals.play_loop(data.idle_clip)
	elif speed < (data.walk_clip_speed + data.run_clip_speed) * 0.5:
		visuals.play_loop(data.walk_clip, clampf(speed / data.walk_clip_speed, 0.6, 2.0))
	else:
		visuals.play_loop(data.run_clip, clampf(speed / data.run_clip_speed, 0.7, 1.6))
