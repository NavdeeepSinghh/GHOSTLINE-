extends GutTest
## Milestone 3 systems that do not need the whole city: the junction puzzle,
## the cap on engaged enemies, cinematics, ground subtraction and the story UI.


func before_each() -> void:
	CombatDirector.clear()
	CombatFX.hitstop_enabled = false


func test_junction_puzzle_is_solved_by_its_scramble() -> void:
	var puzzle := JunctionPuzzle.new(5, [0, 2, 3])
	assert_false(puzzle.is_solved(), "starts unsolved")
	puzzle.press(3)
	puzzle.press(0)
	assert_false(puzzle.is_solved())
	puzzle.press(2)
	assert_true(puzzle.is_solved(), "the engineer's note (1, 3, 4 in any order) works")
	assert_eq(puzzle.presses, 3)


func test_junction_breaker_flips_itself_and_neighbours() -> void:
	var puzzle := JunctionPuzzle.new(5, [])
	assert_true(puzzle.is_solved())
	puzzle.press(0)
	assert_eq(puzzle.relays, [false, false, true, true, true] as Array[bool])
	puzzle.press(4)
	assert_eq(puzzle.relays, [false, false, true, false, false] as Array[bool])
	puzzle.press(9)
	assert_eq(puzzle.presses, 2, "out-of-range presses are ignored")


func test_no_more_than_eight_enemies_engage_at_once() -> void:
	var nodes: Array[Node] = []
	for i: int in 11:
		var node := Node.new()
		add_child_autofree(node)
		nodes.append(node)
	var accepted: int = 0
	for node: Node in nodes:
		if CombatDirector.engage(node):
			accepted += 1
	assert_eq(accepted, CombatDirector.MAX_ENGAGED)
	assert_eq(CombatDirector.MAX_ENGAGED, 8)
	assert_false(CombatDirector.engage(nodes[10]))
	CombatDirector.disengage(nodes[0])
	assert_true(CombatDirector.engage(nodes[10]), "a freed place is taken by the next enemy")
	assert_true(CombatDirector.engage(nodes[1]), "already engaged enemies stay engaged")


func test_alerted_enemies_beyond_the_cap_wait_their_turn() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var enemies: Array[Enemy] = []
	for i: int in 10:
		var enemy := Enemy.new()
		enemy.data = load(Level.ENEMY_DATA_DIR + "hollow.tres")
		enemy.position = Vector3(i * 3.0, 0.0, 0.0)
		world.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	for enemy: Enemy in enemies:
		enemy.alert(Vector3(0.0, 0.0, 30.0))
	var fighting: int = 0
	for enemy: Enemy in enemies:
		if enemy.state == Enemy.AIState.COMBAT:
			fighting += 1
	assert_eq(fighting, 8)
	enemies[0].finish_takedown()
	enemies[9].alert(Vector3(0.0, 0.0, 30.0))
	assert_eq(enemies[9].state, Enemy.AIState.COMBAT, "joins once a place frees up")


func test_sleeping_enemies_wake_when_alerted() -> void:
	var enemy := Enemy.new()
	enemy.data = load(Level.ENEMY_DATA_DIR + "hollow.tres")
	add_child_autofree(enemy)
	enemy.set_asleep(true)
	assert_true(enemy.is_asleep())
	assert_false(enemy.is_physics_processing())
	enemy.alert(Vector3(5.0, 0.0, 0.0))
	assert_false(enemy.is_asleep())
	enemy.set_asleep(true)
	assert_false(enemy.is_asleep(), "an enemy in a fight never sleeps")


func test_ground_subtraction_leaves_a_hole() -> void:
	var pieces: Array[Rect2] = CityBuilder.subtract_rect(Rect2(0, 0, 10, 10), Rect2(4, 4, 2, 2))
	assert_eq(pieces.size(), 4)
	var area: float = 0.0
	for piece: Rect2 in pieces:
		area += piece.get_area()
		assert_false(piece.intersects(Rect2(4.01, 4.01, 1.98, 1.98)), "nothing covers the hole")
	assert_almost_eq(area, 96.0, 0.001)
	assert_eq(CityBuilder.subtract_rect(Rect2(0, 0, 4, 4), Rect2(10, 10, 2, 2)).size(), 1, "no overlap, no change")


func test_cinematic_plays_lines_and_can_be_skipped() -> void:
	var cinematic := Cinematic.new()
	add_child_autofree(cinematic)
	var heard: Array = []
	var catch: Callable = func(lines: Array) -> void: heard.append_array(lines)
	EventBus.dialogue_requested.connect(catch)
	var fired: Array = []
	var shots: Array = [
		{"from": Vector3(0, 2, 5), "look": Vector3.ZERO, "seconds": 0.3},
		{"from": Vector3(3, 2, 5), "look": Vector3.ZERO, "to": Vector3(4, 2, 5), "seconds": 30.0},
	]
	var lines: Array = [{"at": 0.1, "speaker": "Lyra", "text": "Kael...", "seconds": 1.0}, {"at": 20.0, "speaker": "Oren", "text": "Late", "seconds": 1.0}]
	watch_signals(cinematic)
	cinematic.play(shots, lines, null, [{"at": 25.0, "call": func() -> void: fired.append(true)}])
	assert_almost_eq(cinematic.get_duration(), 30.3, 0.001)
	await wait_seconds(0.4)
	assert_true(cinematic.is_playing)
	assert_eq(heard.size(), 1, "only the first line so far")
	cinematic.skip()
	assert_false(cinematic.is_playing)
	assert_signal_emitted_with_parameters(cinematic, "finished", [true])
	assert_eq(fired.size(), 1, "scripted events still happen when skipping")
	EventBus.dialogue_requested.disconnect(catch)


func test_story_ui_objective_subtitles_and_puzzle() -> void:
	var ui := StoryUI.new()
	add_child_autofree(ui)
	EventBus.objective_changed.emit("Reach the tower", "Optional: something")
	assert_eq(ui.get_objective_text(), "Reach the tower")
	EventBus.dialogue_requested.emit([{"speaker": "Oren", "text": "Keep low, son.", "seconds": 2.0}])
	await wait_process_frames(3)
	assert_string_contains(ui.get_subtitle_text(), "OREN")
	assert_string_contains(ui.get_subtitle_text(), "Keep low, son.")
	# The puzzle panel pauses the game and reports when solved.
	watch_signals(ui)
	var puzzle := JunctionPuzzle.new(5, [1])
	ui.show_puzzle(puzzle)
	assert_true(ui.is_modal_open())
	assert_true(get_tree().paused)
	ui._press_breaker(1)
	await wait_seconds(1.2)
	assert_signal_emitted(ui, "puzzle_solved")
	assert_false(ui.is_modal_open())
	assert_false(get_tree().paused, "closing the panel resumes the game")
	ui.show_document({"title": "Note", "kind": "Test", "body": "Words."})
	assert_true(get_tree().paused)
	ui._close_modal()
	assert_false(get_tree().paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_footsteps_pick_surface_from_the_level() -> void:
	Footsteps.surface_provider = func(_at: Vector3) -> String: return "metal"
	assert_eq(Footsteps.get_surface(Vector3.ZERO), "metal")
	Footsteps.surface_provider = Callable()
	assert_eq(Footsteps.get_surface(Vector3.ZERO), "concrete")
	for surface: String in Footsteps.SURFACES:
		for variation: int in Footsteps.VARIATIONS:
			assert_true(AudioManager.has_sfx(StringName("step_%s_%d" % [surface, variation + 1])), "sound exists for %s" % surface)


func test_ambience_loops_are_set_to_loop() -> void:
	for sound: StringName in [&"rain_loop", &"rain_interior_loop", &"wind_loop", &"city_drone_loop", &"tunnel_loop", &"generator_loop"]:
		var stream: AudioStreamWAV = AudioManager.load_loop(sound) as AudioStreamWAV
		assert_not_null(stream, "%s exists" % sound)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_gt(stream.loop_end, 44100)
