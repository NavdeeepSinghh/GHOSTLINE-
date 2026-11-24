extends GutTest
## Milestone 8: Skitters waiting on walls.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

var world: Node3D
var player: Player
var skitter: Enemy
var perch: WallPerch


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatDirector.clear()
	world = Node3D.new()
	add_child_autofree(world)
	for entry: Array in [[Vector3(0, -0.5, 0), Vector3(60, 1, 60)], [Vector3(0, 4, -10.5), Vector3(20, 8, 1)]]:
		var body := StaticBody3D.new()
		body.collision_layer = Player.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		shape.shape = box
		body.add_child(shape)
		body.position = entry[0]
		world.add_child(body)
	skitter = Enemy.new()
	skitter.data = load("res://data/enemies/skitter.tres")
	skitter.position = Vector3(0, 0.05, -7)
	perch = WallPerch.new()
	perch.wall_point = Vector3(0, 4.0, -10.0)
	perch.wall_normal = Vector3(0, 0, 1)
	perch.landing = Vector3(0, 0.05, -7)
	skitter.perch = perch
	skitter.add_child(perch)
	world.add_child(skitter)


func _spawn_player(at: Vector3) -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = at
	world.add_child(player)
	await wait_physics_frames(6)


func test_clings_to_the_wall_until_it_sees_kael() -> void:
	await _spawn_player(Vector3(0, 0.1, 20))
	await wait_physics_frames(20)
	assert_false(perch.letting_go, "too far away to notice")
	assert_gt(skitter.global_position.y, 3.0, "up on the wall")
	assert_lt(absf(skitter.global_position.z + 9.65), 0.2, "flat against it")
	assert_gt((-skitter.global_basis.z).dot(Vector3.DOWN), 0.9, "head down")
	assert_eq(skitter.state, Enemy.AIState.PATROL)
	player.teleport(Vector3(0, 0.1, -2), PI)
	await wait_seconds(1.2)
	assert_true(not is_instance_valid(perch) or perch.letting_go, "it saw him")
	assert_lt(skitter.global_position.y, 0.6, "and dropped to the ground")
	assert_almost_eq(skitter.global_basis.y.dot(Vector3.UP), 1.0, 0.05, "upright again")
	assert_ne(skitter.state, Enemy.AIState.PATROL, "and comes for him")


func test_noise_or_a_hit_brings_it_down() -> void:
	await _spawn_player(Vector3(0, 0.1, 30))
	EventBus.noise_emitted.emit(Vector3(0, 0, -6), 8.0, null)
	assert_true(perch.letting_go, "a bottle smashing below startles it")
	var second := Enemy.new()
	second.data = load("res://data/enemies/skitter.tres")
	var second_perch := WallPerch.new()
	second_perch.wall_point = Vector3(5, 4.0, -10.0)
	second_perch.wall_normal = Vector3(0, 0, 1)
	second_perch.landing = Vector3(5, 0.05, -7)
	second.perch = second_perch
	second.add_child(second_perch)
	second.position = second_perch.landing
	world.add_child(second)
	await wait_physics_frames(3)
	var hit := HitInfo.new()
	hit.damage = 5.0
	second.receive_hit(hit)
	assert_true(second_perch.letting_go, "so does being hit")


func test_levels_place_wall_skitters() -> void:
	for path: String in ["res://scenes/levels/dead_city/dead_city.tscn", "res://scenes/levels/facility/facility.tscn"]:
		var level: Level = (load(path) as PackedScene).instantiate() as Level
		add_child(level)
		await wait_frames(2)
		var perched: int = 0
		for enemy: Enemy in level.get_enemies():
			if enemy.perch != null:
				perched += 1
		assert_gt(perched, 1, "%s has Skitters on its walls" % path.get_file())
		level.free()
		await wait_frames(2)
