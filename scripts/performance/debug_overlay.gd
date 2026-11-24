class_name DebugOverlay
extends CanvasLayer
## Performance overlay (F3 or `): FPS, a frame-time graph with 60 and 30 FPS
## guide lines, draw calls, triangles, memory, the active graphics settings and
## the player's movement state.

const HISTORY: int = 240
const GRAPH_SIZE := Vector2(420, 96)

var player: Player

var _panel: PanelContainer
var _text: Label
var _graph: FrameGraph
var _frame_times: PackedFloat32Array = []
var _refresh: float = 0.0
var _last_tick: int = 0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel = PanelContainer.new()
	_panel.theme = UIStyle.theme()
	_panel.add_theme_stylebox_override(&"panel", UIStyle.panel_box(UIStyle.PANEL))
	_panel.position = Vector2(24, 24)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	_panel.add_child(column)
	_graph = FrameGraph.new()
	_graph.custom_minimum_size = GRAPH_SIZE
	column.add_child(_graph)
	_text = UIStyle.label("", 16)
	column.add_child(_text)
	_last_tick = Time.get_ticks_usec()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - _last_tick) / 1000.0
	_last_tick = now
	_frame_times.append(frame_ms)
	if _frame_times.size() > HISTORY:
		_frame_times.remove_at(0)
	if not visible:
		return
	_graph.samples = _frame_times
	_graph.queue_redraw()
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_text.text = _build_text()


func _build_text() -> String:
	var worst: float = 0.0
	var total: float = 0.0
	for sample: float in _frame_times:
		worst = maxf(worst, sample)
		total += sample
	var average: float = total / maxf(_frame_times.size(), 1)
	var real: Vector2i = DisplayServer.window_get_size()
	var scale: float = get_tree().root.scaling_3d_scale
	var lines: PackedStringArray = [
		"%d FPS    avg %.1f ms    worst %.1f ms" % [Engine.get_frames_per_second(), average, worst],
		"Draw calls %d    Triangles %s    Objects %d" % [
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			_short(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))],
		"Video mem %.0f MB    Static mem %.0f MB" % [
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0],
		"Preset %s    3D %d x %d (%d%%)    Window %d x %d" % [
			str(SettingsManager.get_value("graphics", "preset")).capitalize(),
			roundi(real.x * scale), roundi(real.y * scale), roundi(scale * 100.0), real.x, real.y],
		"%s  ·  %s" % [RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()],
	]
	if player != null and is_instance_valid(player):
		lines.append("State %s    Mode %s    Speed %.1f m/s" % [
			player.state_machine.current_name,
			Player.MoveMode.keys()[player.move_mode].capitalize(),
			player.get_horizontal_speed()])
		lines.append("Stamina %d    Noise radius %.1f m    Floor %s" % [
			roundi(player.stamina), player.noise_radius, "yes" if player.is_on_floor() else "no"])
	return "\n".join(lines)


func _short(value: float) -> String:
	if value >= 1000000.0:
		return "%.2f M" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.1f k" % (value / 1000.0)
	return "%d" % int(value)


class FrameGraph:
	extends Control
	## Frame times as a line; the dashed guides mark 16.7 ms (60 FPS) and 33.3 ms (30 FPS).

	const MAX_MS: float = 40.0
	var samples: PackedFloat32Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		for guide: float in [16.667, 33.333]:
			var y: float = size.y * (1.0 - guide / MAX_MS)
			draw_dashed_line(Vector2(0, y), Vector2(size.x, y), UIStyle.LINE, 1.0, 6.0)
			draw_string(UIStyle.body_font(), Vector2(4, y - 3), "%.1f ms" % guide,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.TEXT_DIM)
		if samples.size() < 2:
			return
		var points: PackedVector2Array = []
		var step: float = size.x / float(DebugOverlay.HISTORY - 1)
		var over_budget: bool = false
		for i: int in samples.size():
			var ms: float = minf(samples[i], MAX_MS)
			over_budget = over_budget or samples[i] > 17.5
			points.append(Vector2(i * step, size.y * (1.0 - ms / MAX_MS)))
		draw_polyline(points, UIStyle.WARNING if over_budget else UIStyle.ECHO, 1.5, true)
