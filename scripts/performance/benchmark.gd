class_name Benchmark
extends Node
## Flies a camera through the level's heaviest views and records every frame
## time, then writes a CSV and a summary a tester can send back.
##
## Runs uncapped (V-Sync off, no FPS limit) so the result shows real headroom:
## an average well above 60 means the game will hold a locked 60 with margin.
## Start it from the pause menu, or launch with:  -- --benchmark
## Options:  --benchmark-seconds=120   --benchmark-preset=low|medium|high   --benchmark-quit

signal finished(summary: Dictionary)

const WARMUP_SECONDS: float = 2.0
const SECONDS_PER_LEG: float = 6.0
const HITCH_MS: float = 33.34
const BUDGET_MS: float = 16.67

var is_running: bool = false

var _stops: Array[Array] = []
var _camera: Camera3D
var _previous_camera: Camera3D
var _duration: float = 60.0
var _elapsed: float = 0.0
var _frame_times: PackedFloat32Array = []
var _draw_calls_total: float = 0.0
var _primitives_total: float = 0.0
var _last_tick: int = 0
var _previous_vsync: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED
var _previous_max_fps: int = 60


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## `stops` is a list of [camera position, look-at point] pairs to fly between.
func start(stops: Array[Array], duration_seconds: float = 60.0) -> void:
	if is_running or stops.size() < 2:
		return
	is_running = true
	_stops = stops
	_duration = duration_seconds
	_elapsed = -WARMUP_SECONDS
	_frame_times = PackedFloat32Array()
	_draw_calls_total = 0.0
	_primitives_total = 0.0

	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = SettingsManager.get_float("graphics", "view_distance")
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_camera)
	_camera.make_current()

	_previous_vsync = DisplayServer.window_get_vsync_mode()
	_previous_max_fps = Engine.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_last_tick = Time.get_ticks_usec()
	set_process(true)


func cancel() -> void:
	if is_running:
		_restore()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - _last_tick) / 1000.0
	_last_tick = now
	_elapsed += frame_ms / 1000.0
	_place_camera(maxf(_elapsed + WARMUP_SECONDS, 0.0))
	if _elapsed < 0.0:
		return
	_frame_times.append(frame_ms)
	_draw_calls_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_primitives_total += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if _elapsed >= _duration:
		_finish()


## Smooth loop through the stops (Catmull-Rom on both position and look-at).
func _place_camera(time: float) -> void:
	var count: int = _stops.size()
	var along: float = time / SECONDS_PER_LEG
	var index: int = int(floor(along)) % count
	var t: float = along - floor(along)
	var p0: Array = _stops[(index - 1 + count) % count]
	var p1: Array = _stops[index]
	var p2: Array = _stops[(index + 1) % count]
	var p3: Array = _stops[(index + 2) % count]
	var position_now: Vector3 = _catmull(p0[0], p1[0], p2[0], p3[0], t)
	var look_now: Vector3 = _catmull(p0[1], p1[1], p2[1], p3[1], t)
	if position_now.distance_squared_to(look_now) > 0.01:
		_camera.look_at_from_position(position_now, look_now, Vector3.UP)


func _catmull(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	return 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t
			+ (-a + 3.0 * b - 3.0 * c + d) * t * t * t)


func _finish() -> void:
	var summary: Dictionary = summarize(_frame_times)
	var frames: float = maxf(_frame_times.size(), 1)
	var window: Vector2i = DisplayServer.window_get_size()
	var scale: float = get_tree().root.scaling_3d_scale
	summary.merge({
		"game_version": str(ProjectSettings.get_setting("application/config/version")),
		"engine_version": Engine.get_version_info()["string"],
		"timestamp": Time.get_datetime_string_from_system(),
		"duration_seconds": _duration,
		"preset": str(SettingsManager.get_value("graphics", "preset")),
		"render_scale": scale,
		"window_size": "%d x %d" % [window.x, window.y],
		"render_size_3d": "%d x %d" % [roundi(window.x * scale), roundi(window.y * scale)],
		"upscaler_mode": get_tree().root.scaling_3d_mode,
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"model": OS.get_model_name(),
		"average_draw_calls": roundi(_draw_calls_total / frames),
		"average_triangles": roundi(_primitives_total / frames),
	})
	var refresh: float = DisplayServer.screen_get_refresh_rate()
	summary["refresh_locked_seconds"] = snappedf(refresh_locked_seconds(_frame_times, refresh if refresh > 1.0 else 60.0), 0.1)
	var frame_times: PackedFloat32Array = _frame_times
	_restore()
	summary["files"] = _write_results(summary, frame_times)
	finished.emit(summary)
	EventBus.benchmark_finished.emit(summary)


func _restore() -> void:
	is_running = false
	set_process(false)
	DisplayServer.window_set_vsync_mode(_previous_vsync)
	Engine.max_fps = _previous_max_fps
	if _camera != null:
		_camera.queue_free()
		_camera = null
	if _previous_camera != null and is_instance_valid(_previous_camera):
		_previous_camera.make_current()


## Pure statistics over a list of frame times in milliseconds (unit-tested).
static func summarize(frame_times: PackedFloat32Array) -> Dictionary:
	var count: int = frame_times.size()
	if count == 0:
		return {"frames": 0}
	var sorted: PackedFloat32Array = frame_times.duplicate()
	sorted.sort()
	var total: float = 0.0
	var hitches: int = 0
	var within_budget: int = 0
	for value: float in frame_times:
		total += value
		if value > HITCH_MS:
			hitches += 1
		if value <= BUDGET_MS:
			within_budget += 1
	# "1% low": the average frame rate across the slowest 1% of frames.
	var slow_count: int = maxi(int(ceil(count * 0.01)), 1)
	var slow_total: float = 0.0
	for i: int in slow_count:
		slow_total += sorted[count - 1 - i]
	var average_ms: float = total / count
	return {
		"frames": count,
		"average_fps": snappedf(1000.0 / average_ms, 0.1),
		"average_frame_ms": snappedf(average_ms, 0.01),
		"median_frame_ms": snappedf(sorted[int(count * 0.5)], 0.01),
		"p95_frame_ms": snappedf(sorted[mini(int(count * 0.95), count - 1)], 0.01),
		"p99_frame_ms": snappedf(sorted[mini(int(count * 0.99), count - 1)], 0.01),
		"one_percent_low_fps": snappedf(1000.0 / (slow_total / slow_count), 0.1),
		"worst_frame_ms": snappedf(sorted[count - 1], 0.01),
		"hitches_over_33ms": hitches,
		"percent_frames_within_16_7ms": snappedf(100.0 * within_budget / count, 0.1),
	}


## Short text version for the results panel and the clipboard.
static func format_summary(summary: Dictionary) -> String:
	if int(summary.get("frames", 0)) == 0:
		return "No frames recorded."
	var lines: PackedStringArray = [
		"GHOSTLINE benchmark  (%s, %s)" % [summary.get("game_version", "?"), summary.get("timestamp", "?")],
		"Preset: %s   3D: %s (%d%%)   Window: %s" % [
			str(summary.get("preset", "?")).capitalize(), summary.get("render_size_3d", "?"),
			roundi(float(summary.get("render_scale", 1.0)) * 100.0), summary.get("window_size", "?")],
		"Average: %.1f FPS (%.2f ms)   1%% low: %.1f FPS" % [
			summary["average_fps"], summary["average_frame_ms"], summary["one_percent_low_fps"]],
		"p95: %.2f ms   p99: %.2f ms   Worst frame: %.2f ms" % [
			summary["p95_frame_ms"], summary["p99_frame_ms"], summary["worst_frame_ms"]],
		"Hitches over 33 ms: %d   Frames within 16.7 ms: %.1f%%" % [
			summary["hitches_over_33ms"], summary["percent_frames_within_16_7ms"]],
		"Draw calls: %d   Triangles: %d   Duration: %d s   Frames: %d" % [
			summary.get("average_draw_calls", 0), summary.get("average_triangles", 0),
			roundi(float(summary.get("duration_seconds", 0.0))), summary["frames"]],
		"GPU: %s (%s)   CPU: %s" % [summary.get("gpu", "?"), summary.get("rendering_driver", "?"), summary.get("cpu", "?")],
		"System: %s  %s" % [summary.get("os", "?"), summary.get("model", "")],
	]
	var locked: float = float(summary.get("refresh_locked_seconds", 0.0))
	if locked >= 1.0:
		lines.append("Note: %.1f s of this run were held at the display's refresh rate by the system, not by the game. Averages and lows read worse than the game ran. Run it again with nothing on top of the game." % locked)
	return "\n".join(lines)


## Seconds of a run spent locked to the display refresh while the rest of the
## run was clearly faster. The benchmark switches VSync off, but the system can
## still pace a full-screen game to the display for a while (for example when a
## notification or another window is drawn over it). Such stretches say nothing
## about the game's speed, so the report calls them out.
static func refresh_locked_seconds(frame_times_ms: PackedFloat32Array, refresh_hz: float = 60.0) -> float:
	var count: int = frame_times_ms.size()
	if count < 120 or refresh_hz <= 1.0:
		return 0.0
	var period: float = 1000.0 / refresh_hz
	var sorted: PackedFloat32Array = frame_times_ms.duplicate()
	sorted.sort()
	# Only meaningful when the typical frame is well under one refresh period.
	if sorted[count / 2] > period * 0.8:
		return 0.0
	var window: int = 30
	var near: PackedInt32Array = []
	near.resize(count)
	for i: int in count:
		near[i] = 1 if absf(frame_times_ms[i] - period) < period * 0.12 else 0
	var in_window: int = 0
	var locked: PackedByteArray = []
	locked.resize(count)
	for i: int in count:
		in_window += near[i]
		if i >= window:
			in_window -= near[i - window]
		if i >= window - 1 and in_window >= window - 3:
			for j: int in range(i - window + 1, i + 1):
				locked[j] = 1
	var total: float = 0.0
	for i: int in count:
		if locked[i] == 1:
			total += frame_times_ms[i]
	return total / 1000.0


## Writes summary + per-frame CSV to user://benchmarks and, when possible, to a
## "Ghostline-benchmarks" folder beside the application so it is easy to find.
func _write_results(summary: Dictionary, frame_times: PackedFloat32Array) -> PackedStringArray:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var base_name: String = "benchmark_%s_%s" % [summary.get("preset", "custom"), stamp]
	var csv := PackedStringArray(["frame,frame_ms"])
	for i: int in frame_times.size():
		csv.append("%d,%.3f" % [i, frame_times[i]])
	var written: PackedStringArray = []
	for directory: String in _output_directories():
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			continue
		var text_path: String = directory.path_join(base_name + ".txt")
		var text_file := FileAccess.open(text_path, FileAccess.WRITE)
		if text_file == null:
			continue
		text_file.store_string(format_summary(summary) + "\n\n" + JSON.stringify(summary, "\t") + "\n")
		text_file.close()
		var csv_file := FileAccess.open(directory.path_join(base_name + ".csv"), FileAccess.WRITE)
		if csv_file != null:
			csv_file.store_string("\n".join(csv) + "\n")
			csv_file.close()
		written.append(ProjectSettings.globalize_path(text_path))
	return written


func _output_directories() -> PackedStringArray:
	var directories: PackedStringArray = ["user://benchmarks"]
	if OS.has_feature("editor"):
		return directories
	var executable_dir: String = OS.get_executable_path().get_base_dir()
	# On macOS the executable sits in Game.app/Contents/MacOS; step out of the bundle.
	var bundle_marker: int = executable_dir.find(".app/Contents/MacOS")
	if bundle_marker >= 0:
		executable_dir = executable_dir.substr(0, bundle_marker + 4).get_base_dir()
	directories.append(executable_dir.path_join("Ghostline-benchmarks"))
	return directories
