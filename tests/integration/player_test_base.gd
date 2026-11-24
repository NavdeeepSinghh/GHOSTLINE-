class_name PlayerTestBase
extends GutTest
## Shared scaffolding for movement tests: a flat test world, a real Player
## instance, simulated input and helpers to advance the physics simulation.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const ACTIONS: PackedStringArray = [
	"move_forward", "move_back", "move_left", "move_right",
	"sprint", "walk", "jump", "crouch", "interact", "lock_on",
	"light_attack", "heavy_attack", "block", "dodge", "throw", "heal",
	"weapon_1", "weapon_2", "weapon_3", "weapon_next", "weapon_prev",
]

var world: Node3D
var player: Player
var tuning: PlayerTuning


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatFX.hitstop_enabled = false
	CombatDirector.clear()
	PerceptionComponent.hearing_scale = 1.0
	world = Node3D.new()
	add_child_autofree(world)
	# Ground: top surface at y = 0.
	add_box(Vector3(0.0, -0.5, 0.0), Vector3(200.0, 1.0, 200.0))


func after_each() -> void:
	release_all()


## Spawns the player on the ground and lets him settle.
func spawn_player(at: Vector3 = Vector3(0.0, 0.02, 0.0), yaw: float = 0.0) -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = at
	player.rotation.y = yaw
	world.add_child(player)
	tuning = player.tuning
	await step(12)


func add_box(center: Vector3, size: Vector3, climbable: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Player.LAYER_WORLD | (Player.LAYER_CLIMBABLE if climbable else 0)
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = center
	world.add_child(body)
	return body


## A box standing on the ground: `x`/`z` centre, footprint and height.
func add_block(x: float, z: float, size_x: float, size_z: float, height: float, climbable: bool = false) -> StaticBody3D:
	return add_box(Vector3(x, height * 0.5, z), Vector3(size_x, height, size_z), climbable)


func step(frames: int = 1) -> void:
	await wait_physics_frames(frames)


func seconds(time: float) -> void:
	await wait_physics_frames(int(round(time * 60.0)))


func press(action: StringName) -> void:
	Input.action_press(action)


func release(action: StringName) -> void:
	Input.action_release(action)


## Presses an action for two physics frames (a quick tap).
func tap(action: StringName) -> void:
	Input.action_press(action)
	await step(2)
	Input.action_release(action)


func release_all() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)


func state() -> StringName:
	return player.state_machine.current_name


## Advances until the player is in `wanted`, up to `timeout` seconds. Returns true on success.
func until_state(wanted: StringName, timeout: float = 2.0) -> bool:
	for i: int in int(timeout * 60.0):
		if state() == wanted:
			return true
		await step(1)
	return state() == wanted


## Spawns an enemy. `passive` enemies stand still and never act (a punching bag).
func spawn_enemy(type: String, at: Vector3, yaw_degrees: float = 0.0, passive: bool = false, max_health: float = -1.0) -> Enemy:
	var enemy := Enemy.new()
	enemy.data = (load(Level.ENEMY_DATA_DIR + type + ".tres") as EnemyData).duplicate()
	if max_health > 0.0:
		enemy.data.max_health = max_health
	enemy.position = at
	enemy.rotation.y = deg_to_rad(yaw_degrees)
	world.add_child(enemy)
	if passive:
		enemy.set_physics_process(false)
	return enemy


func make_hit(damage: float, from: Vector3, poise: float = 10.0) -> HitInfo:
	var hit := HitInfo.new()
	hit.damage = damage
	hit.poise = poise
	hit.origin = from
	return hit


func until(condition: Callable, timeout: float = 3.0) -> bool:
	for i: int in int(timeout * 60.0):
		if condition.call():
			return true
		await step(1)
	return condition.call()
