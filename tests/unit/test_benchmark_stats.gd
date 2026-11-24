extends GutTest
## Benchmark statistics are pure functions, so they can be checked exactly.


func test_empty_input() -> void:
	assert_eq(Benchmark.summarize(PackedFloat32Array()), {"frames": 0})


func test_steady_sixty_fps() -> void:
	var frames := PackedFloat32Array()
	for i: int in 600:
		frames.append(1000.0 / 60.0)
	var summary: Dictionary = Benchmark.summarize(frames)
	assert_eq(summary["frames"], 600)
	assert_almost_eq(float(summary["average_fps"]), 60.0, 0.11)
	assert_almost_eq(float(summary["one_percent_low_fps"]), 60.0, 0.11)
	assert_eq(summary["hitches_over_33ms"], 0)
	assert_almost_eq(float(summary["percent_frames_within_16_7ms"]), 100.0, 0.01)


func test_hitches_and_one_percent_low() -> void:
	var frames := PackedFloat32Array()
	for i: int in 198:
		frames.append(10.0)
	frames.append(50.0)
	frames.append(50.0)
	var summary: Dictionary = Benchmark.summarize(frames)
	assert_eq(summary["hitches_over_33ms"], 2)
	assert_almost_eq(float(summary["worst_frame_ms"]), 50.0, 0.01)
	# Slowest 1% of 200 frames = 2 frames of 50 ms = 20 FPS.
	assert_almost_eq(float(summary["one_percent_low_fps"]), 20.0, 0.11)
	assert_almost_eq(float(summary["average_frame_ms"]), 10.4, 0.01)
	assert_almost_eq(float(summary["percent_frames_within_16_7ms"]), 99.0, 0.01)


func test_summary_text_mentions_key_numbers() -> void:
	var frames := PackedFloat32Array([16.0, 16.0, 17.0, 40.0])
	var summary: Dictionary = Benchmark.summarize(frames)
	summary["preset"] = "medium"
	var text: String = Benchmark.format_summary(summary)
	assert_string_contains(text, "Medium")
	assert_string_contains(text, "1% low")
	assert_string_contains(text, "Hitches over 33 ms: 1")


func test_stretches_held_at_display_refresh_are_reported() -> void:
	# 113 FPS for 20 s, then 5 s paced at exactly 60 Hz, then fast again.
	var frames := PackedFloat32Array()
	for i: int in 2200:
		frames.append(8.0 if i % 2 == 0 else 9.8)
	for i: int in 300:
		frames.append(16.67 + (0.4 if i % 2 == 0 else -0.4))
	for i: int in 1200:
		frames.append(8.9)
	assert_almost_eq(Benchmark.refresh_locked_seconds(frames, 60.0), 5.0, 0.2)
	var summary: Dictionary = Benchmark.summarize(frames)
	summary["refresh_locked_seconds"] = 5.0
	assert_string_contains(Benchmark.format_summary(summary), "held at the display's refresh rate")


func test_a_game_that_really_runs_at_sixty_is_not_flagged() -> void:
	var steady := PackedFloat32Array()
	for i: int in 3000:
		steady.append(16.6)
	assert_eq(Benchmark.refresh_locked_seconds(steady, 60.0), 0.0, "typical frame is not faster than the display")
	var fast := PackedFloat32Array()
	for i: int in 3000:
		fast.append(9.0 if i % 50 != 0 else 17.0)
	assert_eq(Benchmark.refresh_locked_seconds(fast, 60.0), 0.0, "isolated slow frames are not a lock")
