class_name Level
extends Node3D
## Base for playable areas. A level tells the game where the player starts,
## which camera stops show its heaviest views (for the benchmark fly-through),
## and which enemies live in it.

const ENEMY_DATA_DIR: String = "res://data/enemies/"

var spawn_position: Vector3 = Vector3.ZERO
## Radians; 0 faces -Z.
var spawn_yaw: float = 0.0

## Shown on the title card when the level starts.
var title: String = "GHOSTLINE"
var subtitle: String = ""
## Weapon ids Kael owns on arrival. Empty means all of them (test levels).
var starting_weapons: PackedStringArray = []

var _enemy_spawns: Array[Dictionary] = []
var _enemy_root: Node3D


## [camera position, look-at point] pairs. Override per level.
func get_tour_stops() -> Array[Array]:
	return []


## Called by the game once Kael, the camera and the interface exist.
## `skip_intro` is set for automated runs (tests, benchmark, screenshot tour).
func start_story(_player: Player, _skip_intro: bool) -> void:
	pass


## Writes whatever this level needs to resume into GameState.level_state.
func capture_state() -> void:
	pass


## Rebuilds the level's progress from GameState after a save was loaded.
func restore_state(_player: Player) -> void:
	pass


## The benchmark is about to fly its route: stage whatever makes it representative.
func prepare_benchmark(_player: Player) -> void:
	pass


## Registers an enemy to be placed by spawn_enemies(). `type` is a file name in data/enemies.
func add_enemy_spawn(type: String, at: Vector3, yaw_degrees: float = 0.0, patrol: Array[Vector3] = []) -> void:
	_enemy_spawns.append({"type": type, "position": at, "yaw": deg_to_rad(yaw_degrees), "patrol": patrol})


## An enemy that clings to a wall at `wall_point` (facing out along `wall_normal`)
## and leaps down to `landing`, a spot on the ground, when it notices Kael.
func add_wall_spawn(type: String, wall_point: Vector3, wall_normal: Vector3, landing: Vector3) -> void:
	_enemy_spawns.append({"type": type, "position": landing, "yaw": 0.0, "patrol": [] as Array[Vector3],
			"perch": [wall_point, wall_normal.normalized(), landing]})


func spawn_enemies() -> void:
	if _enemy_root == null:
		_enemy_root = Node3D.new()
		_enemy_root.name = "Enemies"
		add_child(_enemy_root)
	for spawn: Dictionary in _enemy_spawns:
		var enemy: Enemy = spawn_enemy(str(spawn["type"]), spawn["position"], spawn["yaw"], spawn["patrol"])
		if spawn.has("perch"):
			var perch := WallPerch.new()
			perch.wall_point = spawn["perch"][0]
			perch.wall_normal = spawn["perch"][1]
			perch.landing = spawn["perch"][2]
			enemy.perch = perch
			enemy.add_child(perch)


## Adds one enemy to the level right now. `yaw` in radians.
func spawn_enemy(type: String, at: Vector3, yaw: float = 0.0, patrol: Array[Vector3] = []) -> Enemy:
	if _enemy_root == null:
		_enemy_root = Node3D.new()
		_enemy_root.name = "Enemies"
		add_child(_enemy_root)
	var enemy := Enemy.new()
	enemy.data = load(ENEMY_DATA_DIR + type + ".tres")
	enemy.name = type.capitalize()
	enemy.position = at
	enemy.rotation.y = yaw
	enemy.patrol_points = patrol
	_enemy_root.add_child(enemy, true)
	return enemy


## Removes every enemy, projectile and puddle and puts fresh enemies back
## (after the player dies or rests at a checkpoint).
func reset_encounters() -> void:
	CombatDirector.clear()
	if _enemy_root != null:
		for child: Node in _enemy_root.get_children():
			child.queue_free()
	for node: Node in get_tree().get_nodes_in_group(&"transient"):
		node.queue_free()
	spawn_enemies()


func get_enemies() -> Array[Enemy]:
	var found: Array[Enemy] = []
	if _enemy_root != null:
		for child: Node in _enemy_root.get_children():
			if child is Enemy and not child.is_queued_for_deletion():
				found.append(child)
	return found
