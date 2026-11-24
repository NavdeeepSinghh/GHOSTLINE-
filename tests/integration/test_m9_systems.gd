extends GutTest
## 1.2.0 atmosphere: the film look, rain splashes and the new effects.


class FakeLevel:
	extends Node3D
	var roof: bool = false

	func is_sheltered(_point: Vector3) -> bool:
		return roof


var fx: ScreenFX


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	fx = ScreenFX.new()
	add_child_autofree(fx)
	await wait_physics_frames(1)


func test_film_look_pulses_when_kael_is_hurt_and_can_be_turned_off() -> void:
	EventBus.health_changed.emit(100.0, 100.0)
	assert_eq(fx.hurt_amount(), 0.0, "first report is not a hit")
	EventBus.health_changed.emit(80.0, 100.0)
	assert_eq(fx.hurt_amount(), 1.0, "a hit flashes the edge")
	await wait_seconds(0.6)
	assert_lt(fx.hurt_amount(), 0.1, "and fades quickly")
	EventBus.health_changed.emit(90.0, 100.0)
	assert_eq(fx.hurt_amount(), 0.0, "healing does not flash")
	assert_true(fx.is_active())
	SettingsManager.set_value("graphics", "film_look", false, false)
	await wait_physics_frames(2)
	assert_false(fx.is_active(), "Settings turns it off")


func test_reduce_flashing_softens_the_hurt_edge() -> void:
	SettingsManager.set_value("accessibility", "reduce_flashing", true, false)
	EventBus.health_changed.emit(100.0, 100.0)
	EventBus.health_changed.emit(50.0, 100.0)
	assert_almost_eq(fx.hurt_amount(), 0.6, 0.01)


func test_rain_splashes_follow_kael_and_stop_under_cover() -> void:
	var level := FakeLevel.new()
	add_child_autofree(level)
	var kael := Node3D.new()
	kael.add_to_group(&"player")
	level.add_child(kael)
	kael.position = Vector3(4.0, 1.0, -3.0)
	var splashes := RainSplashes.new()
	splashes.level = level
	level.add_child(splashes)
	await wait_physics_frames(2)
	assert_true(splashes.emitting)
	assert_almost_eq(splashes.global_position.x, 4.0, 0.01)
	level.roof = true
	await wait_physics_frames(2)
	assert_false(splashes.emitting, "dry under a roof")


func test_hologram_and_veins_build() -> void:
	var screen := HologramScreen.new()
	screen.text = "RESONANCE IS PEACE"
	add_child_autofree(screen)
	await wait_physics_frames(1)
	assert_eq(screen.find_children("*", "Label3D", true, false).size(), 1)
	var transforms: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(1, 0, 0))]
	var veins: GlowVeins = GlowVeins.make(transforms)
	add_child_autofree(veins)
	assert_eq(veins.multimesh.instance_count, 2)
	var mist: FogVolume = CityFX.mist(Vector3.ZERO, Vector3(4, 1, 4))
	add_child_autofree(mist)
	assert_eq(mist.size, Vector3(4, 1, 4))


func _photo_world() -> Array:
	var world := Node3D.new()
	add_child_autofree(world)
	var wall := StaticBody3D.new()
	wall.collision_layer = Player.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 10, 1)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 2, -6)
	world.add_child(wall)
	var kael := Node3D.new()
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	kael.add_child(visuals)
	world.add_child(kael)
	var game_camera := Camera3D.new()
	world.add_child(game_camera)
	game_camera.position = Vector3(0, 2, 4)
	game_camera.make_current()
	var photo := PhotoMode.new()
	add_child_autofree(photo)
	return [world, kael, game_camera, photo]


func test_photo_camera_stays_out_of_walls_and_near_kael() -> void:
	var parts: Array = _photo_world()
	var photo: PhotoMode = parts[3]
	var game_camera: Camera3D = parts[2]
	watch_signals(photo)
	photo.open(parts[0], game_camera, parts[1], fx)
	await wait_physics_frames(2)
	assert_true(photo.active)
	assert_true(photo.camera.current, "the photo camera takes over")
	assert_true(fx.is_active(), "filters work even with Film look off")
	photo.move_camera(Vector3(0, 0, -20))
	assert_gt(photo.camera.global_position.z, -5.6, "stopped in front of the wall")
	photo.move_camera(Vector3(0, 0, 60))
	assert_lt(photo.camera.global_position.distance_to(Vector3(0, 1.2, 0)), PhotoMode.MAX_DISTANCE + 0.01, "kept near Kael")
	photo.cycle_filter()
	assert_eq(ScreenFX.FILTERS[photo.filter], "Noir")
	photo.cycle_filter(-2)
	assert_eq(ScreenFX.FILTERS[photo.filter], "Faded film", "wraps around")
	photo.hide_kael = true
	photo._apply()
	assert_false(((parts[1] as Node3D).get_node("Visuals") as Node3D).visible)
	photo.close()
	await wait_physics_frames(1)
	assert_signal_emitted(photo, "closed")
	assert_true(game_camera.current, "back to the game camera")
	assert_true(((parts[1] as Node3D).get_node("Visuals") as Node3D).visible, "Kael shown again")
	assert_eq(photo.filter, 0)


func test_photo_file_names() -> void:
	var path: String = PhotoMode.new_photo_path()
	assert_true(path.begins_with("user://photos/ghostline_"))
	assert_true(path.ends_with(".png"))
	assert_false(path.contains(":") and path.find(":") > 5, "no colons in the file name")


func test_lightning_bolt_builds_and_goes() -> void:
	var bolt: LightningBolt = LightningBolt.make(Vector3(0, 0, -100), 90.0, 7)
	add_child(bolt)
	assert_gt(bolt.mesh.get_faces().size(), 100, "a jagged bolt with branches")
	assert_gt(bolt.mesh.get_aabb().size.y, 80.0)
	await wait_seconds(LightningBolt.LIFETIME + 0.2)
	assert_false(is_instance_valid(bolt), "gone after a moment")


func test_echo_ghosts_scatter_and_return() -> void:
	var dead_city: Array[EchoGhost] = EchoGhost.from_data("dead_city")
	assert_gt(dead_city.size(), 4)
	for extra: EchoGhost in dead_city:
		extra.free()
	var spots: Array = [[Vector3(5, 0, 5), 90.0]]
	var facility: Array[EchoGhost] = EchoGhost.from_data("facility", spots)
	assert_eq(facility.size(), 1, "only as many as the dressing found desks for")
	assert_eq(facility[0].position, Vector3(5, 0, 5))
	var ghost: EchoGhost = facility[0]
	ghost.position = Vector3.ZERO
	add_child_autofree(ghost)
	var kael := Node3D.new()
	kael.add_to_group(&"player")
	add_child_autofree(kael)
	kael.position = Vector3(0, 0, 20)
	await wait_seconds(0.3)
	assert_false(ghost.scattered)
	assert_true(ghost.visible)
	kael.position = Vector3(0, 0, 2)
	await wait_seconds(1.2)
	assert_true(ghost.scattered, "breaks up when Kael walks into it")
	assert_gt(ghost.dissolve_amount(), 0.9)
	kael.position = Vector3(0, 0, 30)
	await wait_seconds(0.4)
	assert_false(ghost.scattered, "comes back once he has gone")
	kael.position = Vector3(0, 0, 80)
	await wait_seconds(0.4)
	assert_false(ghost.visible, "sleeps when far away")


func test_dying_hollow_burns_away() -> void:
	var visuals := EnemyVisuals.new()
	add_child_autofree(visuals)
	visuals.setup(load("res://data/enemies/hollow.tres"))
	visuals.set_dead()
	visuals.start_fade()
	await wait_seconds(0.5)
	assert_true(visuals.is_dissolving())
	assert_eq(visuals.find_children("*", "GPUParticles3D", true, false).size(), 1, "embers rise")
