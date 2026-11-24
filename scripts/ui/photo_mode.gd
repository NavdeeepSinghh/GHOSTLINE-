class_name PhotoMode
extends CanvasLayer
## Photo mode, opened from the pause menu. The world stays frozen; a free
## camera flies around Kael (up to MAX_DISTANCE away, never through walls) with
## field of view, roll, filters, widescreen bars, depth of field and the option
## to hide Kael. Enter (or A on a controller) saves a PNG to the photos folder.

signal closed

const MAX_DISTANCE: float = 14.0
const MOVE_SPEED: float = 4.0
const MOUSE_SENSITIVITY: float = 0.0025
const STICK_SPEED: float = 2.2
const FOV_RANGE: Vector2 = Vector2(20.0, 100.0)
const ROLL_LIMIT: float = 45.0
const FOLDER: String = "user://photos"

var active: bool = false
var camera: Camera3D
var fov: float = 65.0
var roll: float = 0.0
var filter: int = 0
var letterbox: bool = false
var depth_of_field: bool = false
var focus_distance: float = 5.0
var hide_kael: bool = false
var panel_visible: bool = true
var last_saved_path: String = ""

var _game_camera: Camera3D
var _player: Node3D
var _screen_fx: ScreenFX
var _attributes: CameraAttributesPractical
var _yaw: float = 0.0
var _pitch: float = 0.0
var _panel: PanelContainer
var _info: Label
var _status: Label
var _status_time: float = 0.0
var _taking: bool = false


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel = PanelContainer.new()
	_panel.theme = UIStyle.theme()
	_panel.position = Vector2(28, 28)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_panel.add_child(column)
	column.add_child(UIStyle.label("PHOTO MODE", 26, UIStyle.ECHO, true))
	_info = UIStyle.label("", 17, UIStyle.TEXT)
	column.add_child(_info)
	column.add_child(UIStyle.label(
			"Mouse / right stick  look      WASD / left stick  move\n"
			+ "Space / Ctrl  up, down      Shift  faster\n"
			+ "Wheel / triggers  zoom      Q E / bumpers  roll\n"
			+ "F / Y  filter      L  widescreen      B  depth of field\n"
			+ "[ ]  focus      K  hide Kael      H  hide this panel\n"
			+ "R  reset      Enter / A  save photo      Esc / B  back", 15, UIStyle.TEXT_DIM))
	_status = UIStyle.label("", 19, UIStyle.TEXT)
	_status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status.position = Vector2(-300, -70)
	_status.custom_minimum_size = Vector2(600, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)


## Takes over from the game camera. `world` is where the photo camera lives.
func open(world: Node, game_camera: Camera3D, player: Node3D, screen_fx: ScreenFX) -> void:
	if active:
		return
	_game_camera = game_camera
	_player = player
	_screen_fx = screen_fx
	camera = Camera3D.new()
	camera.name = "PhotoCamera"
	camera.near = 0.05
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	world.add_child(camera)
	if game_camera != null:
		camera.global_transform = game_camera.global_transform
		fov = game_camera.fov
	var euler: Vector3 = camera.global_basis.get_euler()
	_yaw = euler.y
	_pitch = euler.x
	roll = 0.0
	_attributes = CameraAttributesPractical.new()
	camera.attributes = _attributes
	camera.make_current()
	active = true
	visible = true
	panel_visible = true
	if _screen_fx != null:
		_screen_fx.force_visible = true
	_apply()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_flash("Photo mode. The world is frozen.")


func close() -> void:
	if not active:
		return
	active = false
	visible = false
	hide_kael = false
	filter = 0
	letterbox = false
	_apply()
	if _screen_fx != null:
		_screen_fx.force_visible = false
		_screen_fx.set_grain(0.035)
	if _game_camera != null and is_instance_valid(_game_camera):
		_game_camera.make_current()
	if camera != null:
		camera.queue_free()
		camera = null
	closed.emit()


func reset_camera() -> void:
	if _game_camera == null or camera == null:
		return
	camera.global_position = _game_camera.global_position
	var euler: Vector3 = _game_camera.global_basis.get_euler()
	_yaw = euler.y
	_pitch = euler.x
	roll = 0.0
	fov = _game_camera.fov
	_apply()


func cycle_filter(step: int = 1) -> void:
	filter = posmod(filter + step, ScreenFX.FILTERS.size())
	_apply()


## Moves the camera by `offset` (world space), stopping at walls and at
## MAX_DISTANCE from Kael.
func move_camera(offset: Vector3) -> void:
	if camera == null or offset.is_zero_approx():
		return
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + offset
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to + offset.normalized() * 0.25, Player.LAYER_WORLD)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		to = (hit["position"] as Vector3) - offset.normalized() * 0.25
		if (to - from).dot(offset) < 0.0:
			to = from
	if _player != null:
		var centre: Vector3 = _player.global_position + Vector3(0.0, 1.2, 0.0)
		var away: Vector3 = to - centre
		if away.length() > MAX_DISTANCE:
			to = centre + away.normalized() * MAX_DISTANCE
	camera.global_position = to


func _process(delta: float) -> void:
	if not active or camera == null:
		return
	var step: float = minf(delta, 0.05)
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	_yaw -= look.x * STICK_SPEED * step
	_pitch = clampf(_pitch - look.y * STICK_SPEED * step, -1.45, 1.45)
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var rise: float = 0.0
	if Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		rise += 1.0
	if Input.is_key_pressed(KEY_CTRL) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		rise -= 1.0
	var basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var offset: Vector3 = (basis.x * input.x + basis.z * input.y + Vector3.UP * rise)
	var speed: float = MOVE_SPEED * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	move_camera(offset.limit_length(1.0) * speed * step)
	var zoom: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	if absf(zoom) > 0.1:
		fov = clampf(fov + zoom * 40.0 * step, FOV_RANGE.x, FOV_RANGE.y)
	if Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		roll = clampf(roll + 40.0 * step, -ROLL_LIMIT, ROLL_LIMIT)
	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		roll = clampf(roll - 40.0 * step, -ROLL_LIMIT, ROLL_LIMIT)
	if Input.is_key_pressed(KEY_Q):
		roll = clampf(roll + 40.0 * step, -ROLL_LIMIT, ROLL_LIMIT)
	if Input.is_key_pressed(KEY_E):
		roll = clampf(roll - 40.0 * step, -ROLL_LIMIT, ROLL_LIMIT)
	_apply()
	if _status_time > 0.0:
		_status_time -= delta
		_status.modulate.a = clampf(_status_time, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not active or _taking:
		return
	var handled: bool = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				fov = clampf(fov - 3.0, FOV_RANGE.x, FOV_RANGE.y)
			MOUSE_BUTTON_WHEEL_DOWN:
				fov = clampf(fov + 3.0, FOV_RANGE.x, FOV_RANGE.y)
			MOUSE_BUTTON_LEFT:
				take_photo()
			_:
				handled = false
	elif event is InputEventKey and event.pressed and not event.is_echo():
		match (event as InputEventKey).physical_keycode:
			KEY_F:
				cycle_filter()
			KEY_L:
				letterbox = not letterbox
			KEY_B:
				depth_of_field = not depth_of_field
			KEY_BRACKETLEFT:
				focus_distance = maxf(0.5, focus_distance - 0.5)
			KEY_BRACKETRIGHT:
				focus_distance = minf(40.0, focus_distance + 0.5)
			KEY_K:
				hide_kael = not hide_kael
			KEY_H:
				panel_visible = not panel_visible
			KEY_R:
				reset_camera()
			KEY_ENTER, KEY_KP_ENTER, KEY_P:
				take_photo()
			KEY_ESCAPE:
				close()
			_:
				handled = false
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				take_photo()
			JOY_BUTTON_B, JOY_BUTTON_START:
				close()
			JOY_BUTTON_Y:
				cycle_filter()
			JOY_BUTTON_X:
				hide_kael = not hide_kael
			JOY_BUTTON_BACK:
				panel_visible = not panel_visible
			_:
				handled = false
	else:
		handled = false
	if handled:
		_apply()
		get_viewport().set_input_as_handled()


func _apply() -> void:
	if camera != null:
		camera.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * Basis(Vector3.BACK, deg_to_rad(roll))
		camera.fov = fov
	if _attributes != null:
		_attributes.dof_blur_far_enabled = depth_of_field
		_attributes.dof_blur_near_enabled = depth_of_field
		_attributes.dof_blur_far_distance = focus_distance * 1.4
		_attributes.dof_blur_far_transition = maxf(1.0, focus_distance)
		_attributes.dof_blur_near_distance = maxf(0.1, focus_distance * 0.5)
		_attributes.dof_blur_near_transition = maxf(0.1, focus_distance * 0.4)
		_attributes.dof_blur_amount = 0.12
	if _player != null and _player.has_node(^"Visuals"):
		(_player.get_node(^"Visuals") as Node3D).visible = not hide_kael
	if _screen_fx != null:
		_screen_fx.set_filter(filter)
		_screen_fx.set_letterbox(letterbox)
	_panel.visible = panel_visible and active
	_info.text = "Filter  %s      Zoom  %d°      Roll  %d°\nWidescreen  %s      Depth of field  %s (focus %.1f m)      Kael  %s" % [
			ScreenFX.FILTERS[filter], roundi(fov), roundi(roll), _on_off(letterbox), _on_off(depth_of_field),
			focus_distance, "hidden" if hide_kael else "shown"]


static func _on_off(value: bool) -> String:
	return "on" if value else "off"


## File name for a new photo, e.g. user://photos/ghostline_2026-11-20_14-03-22.png.
static func new_photo_path() -> String:
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var path: String = "%s/ghostline_%s.png" % [FOLDER, stamp]
	var index: int = 2
	while FileAccess.file_exists(path):
		path = "%s/ghostline_%s_%d.png" % [FOLDER, stamp, index]
		index += 1
	return path


## Hides the panel for a frame, grabs the screen and writes it. Returns the
## saved path ("" if the screen could not be read, e.g. with no renderer).
func take_photo() -> String:
	if _taking or not active:
		return ""
	_taking = true
	_panel.visible = false
	_status.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	_status.visible = true
	_taking = false
	_apply()
	if image == null or image.is_empty():
		_flash("Could not read the screen.")
		return ""
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var path: String = new_photo_path()
	if image.save_png(path) != OK:
		_flash("Could not save the photo.")
		return ""
	last_saved_path = path
	_flash("Saved  %s" % ProjectSettings.globalize_path(path).get_file())
	AudioManager.play_ui(&"switch", -4.0)
	return path


func _flash(text: String) -> void:
	_status.text = text
	_status_time = 3.0
	_status.modulate.a = 1.0
