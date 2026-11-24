extends GutTest
## Milestone 10: New Game+, the wolf model and the new details.

const MAIN_SCENE: String = "res://scenes/main/main.tscn"
const GAME_SCRIPT: String = "res://scripts/core/game.gd"


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	GameState.reset()
	CombatDirector.clear()


func after_each() -> void:
	SettingsManager.set_value("progress", "ng_plus_carry", {}, true)
	GameState.reset()
	get_tree().paused = false


func test_new_game_plus_carries_weapons_and_toughens_enemies() -> void:
	assert_false(NewGamePlus.is_available(), "locked until the game is finished")
	assert_eq(NewGamePlus.enemy_health_scale(), 1.0)
	GameState.weapons = {"rebar_pipe": 3, "fire_axe": 2}
	GameState.equipped_weapon = "fire_axe"
	GameState.salvage = 17
	GameState.max_health = 160.0
	GameState.collected_documents = ["dc_mara_1"] as Array[String]
	NewGamePlus.record_finish()
	assert_true(NewGamePlus.is_available())
	NewGamePlus.apply()
	assert_eq(GameState.weapons, {"rebar_pipe": 3, "fire_axe": 2}, "weapons and their upgrades carry over")
	assert_eq(GameState.equipped_weapon, "fire_axe")
	assert_eq(GameState.salvage, 17 + int(NewGamePlus.tuning()["bonus_salvage"]))
	assert_eq(GameState.max_health, 100.0, "health is found again through the Vital Cores")
	assert_true(GameState.collected_documents.is_empty(), "documents are found again")
	assert_eq(NewGamePlus.cycle(), 1)
	assert_eq(GameState.current_area, "dead_city")
	assert_almost_eq(NewGamePlus.enemy_health_scale(), 1.35, 0.001)
	assert_almost_eq(NewGamePlus.enemy_damage_scale(), 1.25, 0.001)
	# Finishing that run makes the next one harder still, up to the cap.
	NewGamePlus.record_finish()
	NewGamePlus.apply()
	assert_eq(NewGamePlus.cycle(), 2)
	GameState.set_flag(NewGamePlus.FLAG, 9)
	assert_almost_eq(NewGamePlus.enemy_health_scale(), 1.0 + 0.35 * 3, 0.001, "capped")


func test_enemies_and_their_hits_scale_in_new_game_plus() -> void:
	GameState.set_flag(NewGamePlus.FLAG, 1)
	var world := Node3D.new()
	add_child_autofree(world)
	var hollow := Enemy.new()
	hollow.data = load("res://data/enemies/hollow.tres")
	world.add_child(hollow)
	assert_almost_eq(hollow.health.max_health, hollow.data.max_health * 1.35, 0.01)
	var kael: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	world.add_child(kael)
	await wait_physics_frames(2)
	var hit := HitInfo.new()
	hit.damage = 20.0
	hit.origin = kael.global_position + Vector3(0, 0, -1)
	hit.can_be_blocked = false
	kael.receive_hit(hit)
	assert_almost_eq(kael.health.health, kael.health.max_health - 25.0, 0.01, "hits land 25% harder")
	assert_eq(hit.damage, 20.0, "the original hit is not changed")


func test_new_game_plus_from_the_menu_starts_on_the_rooftop_armed() -> void:
	GameState.weapons = {"rebar_pipe": 2, "fire_axe": 1}
	GameState.equipped_weapon = "fire_axe"
	NewGamePlus.record_finish()
	GameState.reset()
	(load(GAME_SCRIPT) as GDScript).set("boot_request", {"mode": "new_plus"})
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(game)
	await wait_physics_frames(20)
	var kael: Player = game.get("player")
	var owned: Array[String] = []
	for weapon: WeaponData in kael.weapons:
		owned.append(weapon.id)
	assert_true(owned.has("fire_axe"), "the axe came along")
	assert_eq(kael.weapon.id, "fire_axe")
	assert_eq(NewGamePlus.cycle(), 1)
	assert_true(game.get("level") is DeadCity)


func test_menu_shows_new_game_plus_only_after_finishing() -> void:
	var menu := MainMenu.new()
	add_child_autofree(menu)
	await wait_process_frames(2)
	assert_false((menu.find_child("NewGame+", true, false) as Button).visible)
	NewGamePlus.record_finish()
	var second := MainMenu.new()
	add_child_autofree(second)
	await wait_process_frames(2)
	assert_true((second.find_child("NewGame+", true, false) as Button).visible)


func test_wolf_has_its_own_model_and_every_clip() -> void:
	var data: EnemyData = load("res://data/enemies/wolf.tres")
	assert_true(data.model.resource_path.ends_with("wolf.tscn"))
	var visuals := EnemyVisuals.new()
	add_child_autofree(visuals)
	visuals.setup(data)
	for clip: StringName in [data.idle_clip, data.walk_clip, data.run_clip, data.attack_clip, data.hit_clip, data.stagger_clip, data.death_clip, data.alert_clip]:
		assert_gt(visuals.get_clip_length(clip), 0.2, "%s exists" % clip)
	assert_eq(visuals.find_children("*_Eyes", "MeshInstance3D", true, false).size(), 2, "two glowing eyes")
	visuals.play_loop(data.run_clip)
	await wait_seconds(0.2)
	visuals.play_once(data.death_clip)
	await wait_seconds(1.3)
	var body: Node3D = visuals.find_child("Body", true, false) as Node3D
	assert_gt(absf(body.rotation.z), 1.3, "rolled onto its side")


func _kael_at(at: Vector3) -> Node3D:
	var kael := Node3D.new()
	kael.add_to_group(&"player")
	add_child_autofree(kael)
	kael.position = at
	return kael


func test_crows_fly_off_when_kael_comes_close_and_come_back() -> void:
	var crows := Crows.new()
	crows.count = 3
	add_child_autofree(crows)
	var kael: Node3D = _kael_at(Vector3(0, 0, 20))
	await wait_seconds(0.3)
	assert_false(crows.flushed)
	kael.position = Vector3(0, 0, 4)
	await wait_seconds(1.0)
	assert_true(crows.flushed, "off they go")
	var crow: Node3D = crows.get_child(0) as Node3D
	assert_gt(crow.position.y, 1.0, "up into the air")
	kael.position = Vector3(0, 0, 60)
	crows.set("_gone_for", Crows.RETURN_SECONDS + 1.0)
	await wait_seconds(0.3)
	assert_false(crows.flushed, "back once he has gone")
	assert_almost_eq(crow.position.y, 0.0, 0.1)


func test_a_noise_startles_crows() -> void:
	var crows := Crows.new()
	add_child_autofree(crows)
	_kael_at(Vector3(0, 0, 40))
	await wait_physics_frames(2)
	EventBus.noise_emitted.emit(Vector3(10, 0, 0), 4.0, null)
	assert_false(crows.flushed, "too far away")
	EventBus.noise_emitted.emit(Vector3(5, 0, 0), 8.0, null)
	assert_true(crows.flushed, "a bottle smashing nearby")


func test_drip_falls_into_its_puddle() -> void:
	var drip := Drip.new()
	drip.interval = Vector2(0.1, 0.2)
	drip.drop_height = 2.0
	add_child_autofree(drip)
	await wait_seconds(2.5)
	assert_gt(drip.drops, 1, "drop after drop")


func test_papers_blow_only_outside() -> void:
	var level := Node3D.new()
	level.set_script(load("res://tests/integration/sheltered_level.gd"))
	add_child_autofree(level)
	_kael_at(Vector3(3, 0, 3))
	var papers := BlowingPaper.new()
	papers.level = level
	level.add_child(papers)
	await wait_physics_frames(2)
	assert_true(papers.emitting)
	level.set("roof", true)
	await wait_physics_frames(2)
	assert_false(papers.emitting)


func test_saves_carry_over_from_the_old_name() -> void:
	var base: String = ProjectSettings.globalize_path("user://migration_test")
	var old_root: String = base.path_join("TheLastEcho")
	var new_root: String = base.path_join("Ghostline")
	DirAccess.make_dir_recursive_absolute(old_root.path_join("saves"))
	for path: String in [old_root.path_join("settings.cfg"), old_root.path_join("saves/slot1.save")]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("kept")
		file.close()
	var script: GDScript = load("res://scripts/core/user_data_migration.gd")
	assert_eq(script.call("migrate", old_root, new_root), 2, "settings and the save come across")
	assert_eq(FileAccess.get_file_as_string(new_root.path_join("saves/slot1.save")), "kept")
	assert_true(FileAccess.file_exists(old_root.path_join("settings.cfg")), "the old folder is left alone")
	assert_eq(script.call("migrate", old_root, new_root), 0, "only once")
	_remove_tree(base)


func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for folder: String in dir.get_directories():
		_remove_tree(path.path_join(folder))
	DirAccess.remove_absolute(path)
