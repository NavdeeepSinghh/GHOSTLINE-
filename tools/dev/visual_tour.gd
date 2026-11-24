extends Node
## Dev tool: drives the player through each station and saves screenshots so
## visuals can be reviewed without a GPU.  Launch:  -- --visual-tour=<output dir> [--shots=a,b]
## Not part of the shipped game (the export preset excludes tools/).

var _game: Node
var _out: String
var _player: Player
var _rig: CameraRig
var _only: PackedStringArray = []


func run(game: Node, out_dir: String) -> void:
	_game = game
	_out = out_dir
	_player = game.get("player")
	_rig = game.get("camera_rig")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_only = argument.trim_prefix("--shots=").split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	(game.get("hud") as HUD).hide_intro()
	if game.get("main_menu") != null:
		_run_menu()
		return
	if game.get("level") is DeadCity:
		_run_city()
		return
	_run_all()


## Main menu shots (run with --show-menu).
func _run_menu() -> void:
	var menu: MainMenu = _game.get("main_menu")
	await _wait(3.0)
	await _shot("menu_1_title")
	for entry: Array in [["Settings", "menu_2_settings"], ["Load", "menu_3_load"], ["Missions", "menu_3b_missions"], ["Credits", "menu_4_credits"]]:
		(menu.find_child(str(entry[0]), true, false) as Button).pressed.emit()
		await _wait(0.6)
		await _shot(str(entry[1]))
	for tab: String in ["Controls", "Audio", "Gameplay"]:
		(menu.find_child("Settings", true, false) as Button).pressed.emit()
		await _frames(2)
		for node: Node in menu.find_children("*", "SettingsPanel", true, false):
			(node as SettingsPanel).show_tab(tab)
		await _wait(0.4)
		await _shot("menu_5_settings_%s" % tab.to_lower())
	if _wants("reload") and not _only.is_empty():
		# Checks the real New Game path: the scene reloads and boots straight into play.
		print("MENU DONE, STARTING NEW GAME")
		_game.call(&"start_new_game")
		return
	print("VISUAL TOUR DONE")
	_game.call(&"quit_game")


## Dead City shots: the prologue, play views with the interface, panels, then the fly-through stops.
func _run_city() -> void:
	var city: DeadCity = _game.get("level")
	var ui: StoryUI = _game.get("story_ui")
	await _frames(4)
	if _only.has("letterbox"):
		# Cinematic stills: widescreen bars and the film look, no interface.
		var fx: ScreenFX = _game.get("screen_fx")
		fx.force_visible = true
		fx.set_letterbox(true)
		(_game.get("hud") as HUD).set_hud_visible(false)
		(_game.get("story_ui") as CanvasLayer).visible = false
	if _wants("cine"):
		city.play_prologue()
		for mark: Array in [[3.0, "c1_roof"], [9.0, "c2_radio"], [16.0, "c3_tower"], [29.0, "c4_kael"], [41.0, "c5_wide"]]:
			while city.cinematic.is_playing and city.cinematic.get("_time") < float(mark[0]):
				await get_tree().process_frame
			await _shot(str(mark[1]))
		city.cinematic.skip()
		await _wait(0.5)
	if _wants("play"):
		_place(DeadCityLayout.SPAWN, 0.0)
		await _wait(1.0)
		await _shot("p1_camp")
		_place(Vector3(-29.0, 0.1, 54.0), -1.4)
		await _wait(2.5)
		await _shot("p2_south_street")
		_place(Vector3(-27.0, 0.1, 50.5), -1.5)
		_tap(&"crouch")
		await _wait(1.2)
		await _shot("p3_grass")
		_place(Vector3(-26.0, 0.1, 42.0), 0.0)
		await _wait(0.8)
		await _shot("p4_store")
		_place(Vector3(-12.0, 0.1, 60.5), 3.14)
		await _wait(0.8)
		await _shot("p5_apartment")
		_place(Vector3(-2.0, 0.1, -9.0), -1.57)
		await _wait(0.8)
		await _shot("p6_main_street")
		_place(Vector3(19.0, 0.1, 0.5), 2.4)
		await _wait(0.8)
		await _shot("p7_pharmacy")
		_place(Vector3(-20.0, DeadCityLayout.METRO_Y + 0.1, -12.0), 0.0)
		await _wait(0.8)
		await _shot("p8_metro")
		_place(Vector3(-22.0, DeadCityLayout.METRO_Y + 0.1, -50.0), 1.2)
		await _wait(0.8)
		await _shot("p9_echo_growth")
		_place(Vector3(-20.0, 0.1, -72.0), -0.6)
		await _wait(0.8)
		await _shot("p10_plaza")
		_place(Vector3(20.0, 0.1, -57.0), 3.14)
		await _wait(0.8)
		await _shot("p11_classroom")
		_place(Vector3(22.0, DeadCityLayout.ROOF_N2_Y + 0.1, -34.0), 0.4)
		await _wait(0.8)
		await _shot("p12_mara_roof")
		_place(Vector3(0.0, 0.1, -89.0), 0.6)
		await _wait(0.8)
		await _shot("p13_tower_room")
		city.fuses_found = 2
		city.restore_power()
		_place(Vector3(0.0, 0.1, -80.0), 3.14)
		_player.god_mode = true
		await _wait(5.0)
		await _shot("p14_tower_powered_wave")
		_rig.yaw = 0.0
		_rig.pitch = 0.45
		await _wait(0.5)
		await _shot("p15_mast")
		_player.god_mode = false
		_game.call(&"respawn_player")
		await _wait(0.3)
	if _wants("ui"):
		_place(Vector3(-12.0, 0.1, 62.0), 3.14)
		await _wait(0.5)
		(city.objects["dc_fridge_note"] as Usable).interact(_player)
		await _frames(4)
		await _shot("u1_document")
		ui.call(&"_close_modal")
		ui.show_puzzle(JunctionPuzzle.new(5, [0, 2, 3]), "Scrawled inside the panel door: \"1, 3, 4. Any order. — Arlo\"")
		await _frames(4)
		await _shot("u2_puzzle")
		ui.call(&"_close_modal")
		ui.show_summary("Act 1: The Dead City", "Act complete", city.get_summary_rows())
		await _frames(4)
		await _shot("u3_summary")
		ui.call(&"_close_modal")
		_game.call(&"set_paused", true)
		await _frames(3)
		await _shot("u4_pause")
		_game.call(&"set_paused", false)
	print("IN PLAY: level=%s stage=%d player_y=%.1f" % [city.name, int(city.stage), _player.global_position.y])
	if _wants("m4"):
		var pause: PauseMenu = _game.get("pause_menu")
		_place(Vector3(-27.5, 0.1, 5.0), 3.14)
		await _wait(1.5)
		await _shot("s1_marker_and_workbench")
		GameState.salvage = 150
		(city.objects["axe"] as Usable).interact(_player)
		(city.objects["workbench_main"] as Usable).interact(_player)
		await _frames(4)
		await _shot("s2_workbench_panel")
		ui.call(&"_close_modal")
		(city.objects["dc_fridge_note"] as Usable).interact(_player)
		ui.call(&"_close_modal")
		(city.objects["dc_mara_1"] as Usable).interact(_player)
		ui.call(&"_close_modal")
		_game.call(&"save_to_slot", "slot1")
		_game.call(&"set_paused", true)
		for page: String in PauseMenu.PAGES:
			pause.show_page(page)
			await _frames(3)
			await _shot("s3_pause_%s" % page.to_lower().replace(" ", "_"))
		_game.call(&"set_paused", false)
		SaveManager.delete_slot("slot1")
		SaveManager.delete_slot("autosave")
	if _wants("fuses"):
		# Kael at the plaza looking at the Learning Centre, then inside it, then in the metro hall.
		city.stage = DeadCity.Stage.RESTORE_POWER
		city.call(&"_update_objective")
		_place(Vector3(20.0, 0.1, -66.0), 0.0)
		await _wait(1.5)
		await _shot("f1_learning_centre_from_plaza")
		_place(Vector3(20.0, 0.1, -57.0), PI * 0.75)
		await _wait(1.5)
		await _shot("f2_school_fuse")
		_place(Vector3(-12.0, -4.9, -40.0), -PI * 0.5)
		await _wait(1.5)
		await _shot("f3_metro_fuse")
	if _wants("ghosts"):
		# Each Echo ghost with Kael 7 m in front of it, seen by a free camera; then a
		# lightning strike over Main Street and a dying Hollow.
		(_game.get("hud") as HUD).set_hud_visible(false)
		ui.visible = false
		var eye := Camera3D.new()
		eye.fov = 60.0
		eye.far = 200.0
		add_child(eye)
		var index: int = 0
		for ghost: EchoGhost in city.find_children("*", "EchoGhost", true, false):
			var front: Vector3 = ghost.global_transform.basis.z
			front.y = 0.0
			front = front.normalized()
			var side: Vector3 = front.cross(Vector3.UP)
			var floor_y: float = maxf(ghost.global_position.y - 0.3, 0.0)
			_place(Vector3(ghost.global_position.x, floor_y + 0.1, ghost.global_position.z) + front * 7.0 + side * 1.5, atan2(-front.x, -front.z))
			eye.make_current()
			eye.look_at_from_position(ghost.global_position + front * 3.2 + side * 0.8 + Vector3(0.0, 1.5, 0.0), ghost.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)
			await _wait(2.0)
			await _shot("g%d_ghost" % index)
			index += 1
		_place(Vector3(0.0, 0.1, 30.0), PI)
		eye.look_at_from_position(Vector3(0.0, 1.7, 30.0), Vector3(0.0, 30.0, -60.0), Vector3.UP)
		await _wait(1.0)
		var weather: Weather = city.find_children("*", "Weather", true, false)[0] as Weather
		weather.strike()
		await _frames(2)
		await _shot("g8_lightning")
		var hollow: Enemy = null
		for enemy: Enemy in city.get_enemies():
			hollow = enemy
			break
		if hollow != null:
			_place(hollow.global_position + Vector3(0.0, 0.1, 6.0), 0.0)
			eye.look_at_from_position(hollow.global_position + Vector3(0.0, 1.6, 2.6), hollow.global_position + Vector3(0.0, 0.7, 0.0), Vector3.UP)
			await _wait(0.5)
			hollow.visuals.set_dead()
			hollow.visuals.start_fade()
			hollow.set_physics_process(false)
			await _wait(0.9)
			await _shot("g9_dissolve")
		eye.queue_free()
		_rig.camera.make_current()
		(_game.get("hud") as HUD).set_hud_visible(true)
		ui.visible = true
	if _wants("details"):
		(_game.get("hud") as HUD).set_hud_visible(false)
		ui.visible = false
		var eye := Camera3D.new()
		eye.fov = 55.0
		add_child(eye)
		var ground_crows: Crows = null
		var roof_crows: Crows = null
		for flock: Crows in city.find_children("*", "Crows", true, false):
			if flock.on_ground and ground_crows == null:
				ground_crows = flock
			elif not flock.on_ground and roof_crows == null:
				roof_crows = flock
		_place(ground_crows.global_position + Vector3(0.0, 0.1, 20.0), 0.0)
		eye.make_current()
		eye.look_at_from_position(ground_crows.global_position + Vector3(2.0, 1.0, 3.0), ground_crows.global_position + Vector3(0.0, 0.2, 0.0), Vector3.UP)
		await _wait(1.0)
		await _shot("d0_crows_ground")
		_place(ground_crows.global_position + Vector3(0.0, 0.1, 5.5), 0.0)
		await _wait(0.6)
		await _shot("d1_crows_flush")
		_place(roof_crows.global_position * Vector3(1, 0, 1) + Vector3(0.0, 0.1, 0.0) + (roof_crows.global_basis.z * -8.0), 0.0)
		eye.look_at_from_position(roof_crows.global_position + roof_crows.global_basis.z * -4.0 + Vector3(0.0, 1.0, 0.0), roof_crows.global_position, Vector3.UP)
		await _wait(0.6)
		await _shot("d2_crows_roof")
		_place(Vector3(6.0, 0.1, 24.0), 0.0)
		eye.look_at_from_position(Vector3(6.0, 1.6, 24.0), Vector3(2.5, 0.6, 30.0), Vector3.UP)
		await _wait(0.5)
		await _shot("d3_hazards_a")
		await _wait(0.55)
		await _shot("d4_hazards_b")
		_place(Vector3(0.0, 0.1, 10.0), 0.0)
		eye.look_at_from_position(Vector3(-1.0, 1.2, 12.0), Vector3(3.0, 0.0, 4.0), Vector3.UP)
		await _wait(4.0)
		await _shot("d5_papers")
		eye.queue_free()
		_rig.camera.make_current()
	if _wants("filters"):
		# Photo-mode filters over the best Dead City views.
		_place(Vector3(2.0, 0.1, -66.0), PI)
		await _wait(1.5)
		_game.call(&"set_paused", true)
		_game.call(&"open_photo_mode")
		var photo: PhotoMode = _game.get("photo_mode")
		photo.panel_visible = false
		photo.letterbox = true
		for view: Array in [
				[Vector3(11.0, 1.2, -66.0), Vector3(2.0, 3.5, -88.0), 4, "f1_echo_plaza"],
				[Vector3(-3.0, 0.5, -64.0), Vector3(4.0, 2.0, -76.0), 1, "f2_noir_crowd"],
				[Vector3(6.0, 2.2, -60.0), Vector3(0.0, 8.0, -92.0), 2, "f3_dusk_tower"],
				[Vector3(-1.5, 1.7, -63.0), Vector3(2.0, 1.2, -66.0), 5, "f4_faded_kael"]]:
			photo.camera.look_at_from_position(view[0], view[1], Vector3.UP)
			var euler: Vector3 = photo.camera.global_basis.get_euler()
			photo.set("_yaw", euler.y)
			photo.set("_pitch", euler.x)
			photo.filter = int(view[2])
			photo._apply()
			await _frames(4)
			await _shot(str(view[3]))
		photo.close()
		_game.call(&"set_paused", false)
	if _wants("photo"):
		# Photo mode: panel, then each filter with widescreen bars, then depth of field.
		_place(Vector3(2.0, 0.1, -70.0), PI)
		await _wait(1.5)
		_game.call(&"set_paused", true)
		_game.call(&"open_photo_mode")
		var photo: PhotoMode = _game.get("photo_mode")
		photo.move_camera(Vector3(-2.0, 0.6, 1.5))
		await _frames(4)
		await _shot("p0_photo_panel")
		photo.panel_visible = false
		photo.letterbox = true
		for index: int in ScreenFX.FILTERS.size():
			photo.filter = index
			photo._apply()
			await _frames(3)
			await _shot("p%d_filter_%s" % [index + 1, ScreenFX.FILTERS[index].to_lower().replace(" ", "_")])
		photo.filter = 0
		photo.depth_of_field = true
		photo.focus_distance = 2.5
		photo._apply()
		await _frames(3)
		await _shot("p7_depth_of_field")
		photo.close()
		_game.call(&"set_paused", false)
	if _wants("tour"):
		(_game.get("hud") as HUD).set_hud_visible(false)
		ui.visible = false
		var camera := Camera3D.new()
		camera.fov = 70.0
		camera.far = 300.0
		add_child(camera)
		camera.make_current()
		var stops: Array[Array] = city.get_tour_stops()
		for i: int in stops.size():
			camera.look_at_from_position(stops[i][0], stops[i][1], Vector3.UP)
			await _frames(5)
			await _shot("tour_%02d" % i)
	print("VISUAL TOUR DONE")
	_game.call(&"quit_game")


func _run_all() -> void:
	await _frames(4)
	if _only.has("letterbox"):
		# Cinematic stills: widescreen bars and the film look, no interface.
		var fx: ScreenFX = _game.get("screen_fx")
		fx.force_visible = true
		fx.set_letterbox(true)
		(_game.get("hud") as HUD).set_hud_visible(false)
		(_game.get("story_ui") as CanvasLayer).visible = false
	if _wants("bosses"):
		# Boss key art: Kael facing the Warden in its yard, or the Choir in the Chamber.
		var level: Node = _game.get("level")
		var eye := Camera3D.new()
		eye.fov = 50.0
		eye.far = 250.0
		add_child(eye)
		if level is Forest:
			var forest := level as Forest
			forest.call(&"_spawn_warden")
			var warden: Enemy = forest.warden
			var centre: Vector3 = Forest.ARENA_CENTER
			_place(centre + Vector3(1.0, 0.1, 0.0), PI * 0.5)
			await _wait(0.6)
			forest.call(&"_wake_warden", _player)
			await _wait(1.6)
			eye.make_current()
			eye.look_at_from_position(centre + Vector3(-3.5, 0.6, 3.2), warden.global_position + Vector3(0.0, 1.8, 0.0), Vector3.UP)
			await _frames(3)
			await _shot("b1_warden_low")
			warden.set_physics_process(false)
			warden.visuals.play_once(warden.data.attack_clip)
			await _wait(0.45)
			eye.look_at_from_position(warden.global_position + Vector3(-2.5, 1.2, -4.5), warden.global_position + Vector3(0.0, 1.6, 0.0), Vector3.UP)
			await _frames(3)
			await _shot("b2_warden_swing")
		elif level is Facility:
			var facility := level as Facility
			var centre: Vector3 = Facility.CHAMBER_CENTER
			_place(Vector3(162.0, centre.y + 0.1, 0.0), -PI * 0.5)
			await _wait(0.6)
			facility.choir.begin(_player)
			await _wait(2.5)
			eye.make_current()
			eye.look_at_from_position(Vector3(160.0, centre.y + 1.2, 2.5), centre + Vector3(0.0, 5.0, 0.0), Vector3.UP)
			await _frames(3)
			await _shot("b1_choir_wide")
			eye.look_at_from_position(centre + Vector3(-7.0, 0.8, 6.0), centre + Vector3(0.0, 4.0, 0.0), Vector3.UP)
			await _frames(3)
			await _shot("b2_choir_low")
		eye.queue_free()
		print("VISUAL TOUR DONE")
		_game.call(&"quit_game")
		return
	if _wants("crows"):
		var level: Node = _game.get("level")
		(_game.get("hud") as HUD).set_hud_visible(false)
		var eye := Camera3D.new()
		eye.fov = 45.0
		add_child(eye)
		var flock: Crows = level.find_children("*", "Crows", true, false)[0] as Crows
		_place(flock.global_position + Vector3(0.0, 0.1, 14.0), 0.0)
		eye.make_current()
		eye.look_at_from_position(flock.global_position + Vector3(1.5, 0.9, 2.5), flock.global_position + Vector3(0.0, 0.2, 0.0), Vector3.UP)
		await _wait(1.2)
		await _shot("c0_crows")
		flock.flush(flock.global_position + Vector3(0.0, 0.0, 3.0))
		await _wait(0.45)
		await _shot("c1_crows_flying")
		print("VISUAL TOUR DONE")
		_game.call(&"quit_game")
		return
	if _wants("drips"):
		var level: Node = _game.get("level")
		(_game.get("hud") as HUD).set_hud_visible(false)
		var eye := Camera3D.new()
		eye.fov = 55.0
		add_child(eye)
		var index: int = 0
		for drip: Drip in level.find_children("*", "Drip", true, false):
			if index > 2:
				break
			_place(drip.global_position + Vector3(4.0, 0.1, 0.0), 0.0)
			eye.make_current()
			eye.look_at_from_position(drip.global_position + Vector3(1.6, 1.1, 0.6), drip.global_position + Vector3(0.0, 0.3, 0.0), Vector3.UP)
			await _wait(2.5)
			await _shot("drip_%d" % index)
			index += 1
		print("VISUAL TOUR DONE")
		_game.call(&"quit_game")
		return
	if _wants("wolf"):
		# One wolf through its clips, side-on, then a pack from the front.
		var level: Level = _game.get("level")
		(_game.get("hud") as HUD).set_hud_visible(false)
		var wolves: Array[Enemy] = []
		for enemy: Enemy in level.get_enemies():
			if enemy.data.id == "wolf":
				enemy.set_physics_process(false)
				wolves.append(enemy)
		var wolf: Enemy = wolves[0]
		_place(wolf.global_position + Vector3(0.0, 0.1, 14.0), 0.0)
		var eye := Camera3D.new()
		eye.fov = 50.0
		add_child(eye)
		eye.make_current()
		var at: Vector3 = wolf.global_position
		eye.look_at_from_position(at + wolf.global_basis.x * 3.2 + Vector3(0.0, 1.0, 0.0), at + Vector3(0.0, 0.5, 0.0), Vector3.UP)
		for entry: Array in [["Idle", 0.8, true], ["Walk", 0.3, true], ["Run", 0.15, true], ["Run", 0.32, true], ["Attack", 0.24, false], ["Attack", 0.36, false], ["Howl", 0.6, false], ["Death", 1.3, false]]:
			if bool(entry[2]):
				wolf.visuals.play_loop(StringName(entry[0]))
			else:
				wolf.visuals.play_once(StringName(entry[0]))
			await _wait(float(entry[1]))
			await _shot("w_%s_%.2f" % [str(entry[0]).to_lower(), float(entry[1])])
		eye.look_at_from_position(at + wolf.global_basis.z * -4.0 + wolf.global_basis.x * 1.5 + Vector3(0.0, 0.8, 0.0), at + Vector3(0.0, 0.6, 0.0), Vector3.UP)
		wolf.visuals.play_loop(&"Idle")
		await _wait(0.5)
		await _shot("w_front")
		eye.queue_free()
		print("VISUAL TOUR DONE")
		_game.call(&"quit_game")
		return
	if _wants("ghosts"):
		var level: Node = _game.get("level")
		(_game.get("hud") as HUD).set_hud_visible(false)
		var eye := Camera3D.new()
		eye.fov = 60.0
		add_child(eye)
		var index: int = 0
		for ghost: EchoGhost in level.find_children("*", "EchoGhost", true, false):
			var front: Vector3 = ghost.global_transform.basis.z
			front.y = 0.0
			front = front.normalized()
			var side: Vector3 = front.cross(Vector3.UP)
			_place(ghost.global_position + front * 6.0 + side * 1.5 + Vector3(0.0, 0.1, 0.0), atan2(-front.x, -front.z))
			eye.make_current()
			eye.look_at_from_position(ghost.global_position + side * 2.6 - front * 1.2 + Vector3(0.0, 1.5, 0.0), ghost.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)
			await _wait(2.0)
			await _shot("g%d_ghost" % index)
			index += 1
		eye.queue_free()
		print("VISUAL TOUR DONE")
		_game.call(&"quit_game")
		return
	if _wants("spawn"):
		await _wait(0.6)
		await _shot("01_spawn")
	if _wants("run"):
		_place(Vector3(-16.0, 0.05, 6.0), 0.0)
		Input.action_press(&"move_forward")
		await _wait(0.9)
		await _shot("02_jog")
		Input.action_press(&"sprint")
		await _wait(0.9)
		await _shot("03_sprint")
		_release_all()
	if _wants("jump"):
		_place(Vector3(-6.0, 1.05, -1.0), 0.0)
		await _wait(0.3)
		Input.action_press(&"move_forward")
		await _wait(0.35)
		_tap(&"jump")
		await _wait(0.3)
		await _shot("04_jump")
		_release_all()
	if _wants("crouch"):
		_place(Vector3(2.0, 0.05, -11.0), 0.0)
		await _wait(0.3)
		_tap(&"crouch")
		await _wait(0.6)
		_rig.yaw = 0.9
		await _wait(0.3)
		await _shot("05_crouch_idle")
		_rig.yaw = 0.0
		Input.action_press(&"move_forward")
		await _wait(1.6)
		await _shot("06_crouch_tunnel")
		await _wait(4.5)
		_release_all()
		_tap(&"crouch")
		await _wait(0.4)
	if _wants("vault"):
		_place(Vector3(9.6, 0.05, 3.3), 0.0)
		await _wait(0.3)
		_tap(&"jump")
		await _wait(0.16)
		await _shot("07_vault")
		await _wait(0.6)
		await _shot("08_vault_done")
	if _wants("hang"):
		_place(Vector3(17.4, 0.05, 3.2), 0.0)
		await _wait(0.3)
		Input.action_press(&"move_forward")
		_tap(&"jump")
		await _until_state(&"LedgeHang", 1.5)
		Input.action_release(&"move_forward")
		await _wait(0.5)
		print("hang state: ", _player.state_machine.current_name, " pos=", _player.global_position)
		_rig.yaw = 0.9
		_rig.pitch = -0.05
		await _wait(0.3)
		await _shot("09_hang")
		_rig.yaw = 0.0
		_rig.pitch = -0.5
		await _wait(0.3)
		await _shot("10_hang_above")
		_rig.pitch = -0.2
		_tap(&"jump")
		await _wait(0.22)
		await _shot("11_mantle")
		await _wait(0.6)
		print("after climb: ", _player.state_machine.current_name, " pos=", _player.global_position)
	if _wants("shimmy"):
		_place(Vector3(12.0, 0.05, -6.5), 0.0)
		await _wait(0.3)
		Input.action_press(&"move_forward")
		_tap(&"jump")
		await _until_state(&"LedgeHang", 1.5)
		Input.action_release(&"move_forward")
		var start_x: float = _player.global_position.x
		Input.action_press(&"move_right")
		await _wait(1.5)
		print("shimmy state: ", _player.state_machine.current_name, " moved=", _player.global_position.x - start_x)
		_rig.yaw = 0.5
		await _wait(0.2)
		await _shot("12_shimmy")
		_rig.yaw = 0.0
		_release_all()
		_tap(&"crouch")
		await _wait(0.6)
	if _wants("ladder"):
		_place(Vector3(14.0, 0.05, -15.6), 0.0)
		await _wait(0.4)
		_tap(&"interact")
		await _wait(0.2)
		Input.action_press(&"move_forward")
		await _wait(0.9)
		print("ladder state: ", _player.state_machine.current_name, " pos=", _player.global_position)
		_rig.yaw = 0.8
		await _wait(0.2)
		await _shot("13_ladder")
		_rig.yaw = 0.0
		await _wait(2.4)
		print("ladder top state: ", _player.state_machine.current_name, " pos=", _player.global_position)
		_release_all()
		await _wait(0.3)
		await _shot("14_tower_top")
	if _wants("lock"):
		_place(Vector3(-8.5, 0.05, -31.0), 0.0)
		await _wait(0.4)
		_rig.toggle_lock_on()
		await _wait(0.8)
		(_game.get("debug_overlay") as CanvasLayer).visible = true
		await _wait(0.4)
		await _shot("15_lock_on_overlay")
		(_game.get("debug_overlay") as CanvasLayer).visible = false
		_rig.toggle_lock_on()
	if _wants("pause"):
		_place(Vector3(0.0, 0.05, 11.2), 0.0)
		await _wait(0.4)
		_game.call(&"set_paused", true)
		await _frames(3)
		await _shot("16_pause")
		_game.call(&"set_paused", false)
	if _wants("combat"):
		# Combat yard: approach, get spotted, block a hit, swing back.
		_place(Vector3(30.0, 0.05, -24.5), 0.0)
		await _wait(0.5)
		await _shot("20_combat_yard")
		Input.action_press(&"move_forward")
		await _wait(1.3)
		_release_all()
		await _wait(1.6)
		_rig.toggle_lock_on()
		await _wait(0.4)
		await _shot("21_spotted")
		Input.action_press(&"block")
		await _wait(1.4)
		await _shot("22_block")
		Input.action_release(&"block")
		for i: int in 3:
			_tap(&"light_attack")
			await _wait(0.2)
		await _shot("23_attack")
		await _wait(0.4)
		Input.action_press(&"heavy_attack")
		await _wait(1.2)
		await _shot("24_heavy_charge")
		Input.action_release(&"heavy_attack")
		await _wait(0.5)
		await _shot("25_after_heavy")
		print("combat: health=", _player.health.health, " state=", _player.state_machine.current_name)
		_rig.set_lock_target(null)
		_game.call(&"respawn_player")
		await _wait(0.3)
	if _wants("bulwark"):
		_place(Vector3(31.0, 0.05, -1.5), 0.0)
		_player.equip_weapon(1)
		await _wait(2.8)
		_rig.toggle_lock_on()
		await _wait(1.2)
		await _shot("26_bulwark")
		await _wait(1.0)
		await _shot("27_bulwark_close")
		_rig.set_lock_target(null)
		_game.call(&"respawn_player")
		await _wait(0.3)
	if _wants("stealth"):
		_place(Vector3(-29.0, 0.05, -29.0), 0.0)
		_tap(&"crouch")
		await _wait(0.8)
		await _shot("28_stealth_yard")
		_place(Vector3(-29.0, 0.05, -36.0), 0.0)
		_tap(&"crouch")
		await _wait(1.5)
		_rig.yaw = 0.9
		await _wait(0.3)
		await _shot("29_tall_grass")
		_game.call(&"respawn_player")
		await _wait(0.3)
	if _wants("tour"):
		(_game.get("hud") as HUD).set_hud_visible(false)
		(_game.get("story_ui") as CanvasLayer).visible = false
		var camera := Camera3D.new()
		camera.fov = 70.0
		camera.far = 300.0
		add_child(camera)
		camera.make_current()
		var stops: Array[Array] = (_game.get("level") as Level).get_tour_stops()
		for i: int in stops.size():
			camera.look_at_from_position(stops[i][0], stops[i][1], Vector3.UP)
			await _frames(5)
			await _shot("tour_%02d" % i)
	print("VISUAL TOUR DONE")
	_game.call(&"quit_game")


func _wants(shot: String) -> bool:
	return _only.is_empty() or _only.has(shot)


func _place(target: Vector3, yaw: float) -> void:
	_release_all()
	_player.teleport(target, yaw)
	_rig.yaw = yaw
	_rig.pitch = -0.2
	_rig.snap_to_target()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _release_all() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"jump", &"crouch", &"walk", &"interact"]:
		Input.action_release(action)


func _until_state(state: StringName, timeout: float) -> void:
	for i: int in int(timeout * 60.0):
		if _player.state_machine.is_in(state):
			return
		await get_tree().physics_frame


## Waits for game time, counted in physics ticks.
func _wait(seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(shot_name + ".png"))
	print("shot ", shot_name)
