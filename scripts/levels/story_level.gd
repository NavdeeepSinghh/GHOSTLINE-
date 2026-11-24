class_name StoryLevel
extends Level
## Shared machinery for the three story areas: things Kael can use and pick up,
## documents, trigger zones, checkpoints, radio lines and hints, doors and
## ladders, far-enemy sleeping, and the part of saving that every area needs.
## Each area script adds its own geometry, enemies and story flow on top.

## Short prefix for this area's flags and checkpoint ids ("dc", "ff", "uf").
var flag_prefix: String = "xx"
var area_title: String = ""
var tuning: Dictionary = {}
var story: Dictionary = {}
var documents: Array = []
var cinematic: Cinematic
var navigation_region: NavigationRegion3D
## Named things other code and tests reach for: usables, doors, ladders.
var objects: Dictionary = {}
## Rooms and tunnels where rain does not fall.
var interiors: Array[AABB] = []
## [AABB, surface name] for footsteps; anything else is `default_surface`.
var surfaces: Array = []
var default_surface: String = "concrete"
## Colour of the film look over this area (see ScreenFX).
var screen_tint: Color = Color.WHITE
var enemies_defeated: int = 0
var takedowns: int = 0

var _player: Player
var _hints_shown: Dictionary = {}
## Keys of one-shot things already taken or used (saved).
var _taken: Dictionary = {}
## One-shot trigger zones in creation order, and which have fired (saved).
var _zones: Array[TriggerZone] = []
var _fired: Dictionary = {}


## Loads the area's data files and creates the cinematic player. Call first in _ready.
func setup_story(prefix: String, title_text: String, tuning_path: String, story_path: String, documents_path: String) -> void:
	flag_prefix = prefix
	area_title = title_text
	tuning = _load_json(tuning_path)
	story = _load_json(story_path)
	documents = _load_json(documents_path).get("documents", [])
	cinematic = Cinematic.new()
	cinematic.name = "Cinematic"
	add_child(cinematic)
	Footsteps.surface_provider = get_surface
	EventBus.enemy_died.connect(func(_enemy: Node3D) -> void: enemies_defeated += 1)
	EventBus.takedown_performed.connect(func() -> void: takedowns += 1)
	hint_settings = _load_json(HINTS_PATH)
	var stuck_timer := Timer.new()
	stuck_timer.name = "StuckTimer"
	stuck_timer.wait_time = 1.0
	stuck_timer.autostart = true
	stuck_timer.timeout.connect(tick_stuck.bind(1.0))
	add_child(stuck_timer)


# --- Help when stuck -------------------------------------------------------------

const HINTS_PATH: String = "res://data/hints.json"

var hint_settings: Dictionary = {}
## Seconds spent on the current objective (cinematics and menus do not count).
var stuck_seconds: float = 0.0
var _stuck_level: int = 0
var _stuck_key: String = ""
var _reminded: bool = false


## Hook: the key of the current objective in data/story/<area>.json "stuck".
func current_stage_key() -> String:
	return ""


## The stuck hints for the current objective: [gentle, step by step].
func stuck_hints() -> Array:
	var all: Dictionary = story.get("stuck", {})
	var lines: Variant = all.get(current_stage_key(), [])
	return lines if lines is Array else []


func tick_stuck(seconds: float) -> void:
	var key: String = current_stage_key()
	if key != _stuck_key:
		_stuck_key = key
		stuck_seconds = 0.0
		_stuck_level = 0
		return
	if cinematic.is_playing or get_tree().paused:
		return
	stuck_seconds += seconds
	var hints: Array = stuck_hints()
	if hints.is_empty():
		return
	var thresholds: Array = [float(hint_settings.get("first_seconds", 50.0)), float(hint_settings.get("second_seconds", 110.0))]
	if _stuck_level < mini(hints.size(), 2) and stuck_seconds >= float(thresholds[_stuck_level]):
		var text: String = str(hints[_stuck_level])
		if not _reminded:
			text += "\n" + str(hint_settings.get("first_hint_reminder", ""))
			_reminded = true
		EventBus.hint_requested.emit(text, float(hint_settings.get("hint_seconds", 11.0)))
		_stuck_level += 1


## The Hint key: the step-by-step hint for the current objective, at once.
func request_hint() -> void:
	var hints: Array = stuck_hints()
	var text: String = str(hints[hints.size() - 1]) if not hints.is_empty() else "Follow the marker to your objective."
	EventBus.hint_requested.emit(text, float(hint_settings.get("hint_seconds", 11.0)))
	var ui: Node = get_tree().get_first_node_in_group(&"story_ui")
	if ui != null and ui.has_method(&"ping_marker"):
		ui.call(&"ping_marker")
	_stuck_level = 2


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"hint") and not cinematic.is_playing and not get_tree().paused:
		request_hint()
		get_viewport().set_input_as_handled()


## Gives an objective item a column of light, a pulsing glow and sparkles,
## removed when it is taken.
func _highlight(usable: Usable, color: Color) -> void:
	var beacon := KeyItemBeacon.new()
	beacon.color = color
	usable.add_child(beacon)
	usable.used.connect(func(_player: Player) -> void:
		if is_instance_valid(beacon):
			beacon.queue_free())


## A short camera moment in a boss fight (an entrance or a phase change). The
## boss and anything in `frozen` hold still while it plays, so the player loses
## nothing; then an optional title card names the boss. Does nothing if another
## cinematic is already running.
func boss_moment(shots: Array, frozen: Array, lines: Array = [], title_text: String = "", subtitle_text: String = "") -> void:
	if cinematic.is_playing:
		return
	for node: Variant in frozen:
		if node is Node and is_instance_valid(node):
			(node as Node).process_mode = Node.PROCESS_MODE_DISABLED
	cinematic.play(shots, lines, find_player())
	await cinematic.finished
	for node: Variant in frozen:
		if node is Node and is_instance_valid(node):
			(node as Node).process_mode = Node.PROCESS_MODE_INHERIT
	if not title_text.is_empty():
		EventBus.area_title_requested.emit(title_text, subtitle_text)


func find_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


## Hook: an area reacts to a document being read (side objectives, objective text).
func _document_collected(_document_id: String) -> void:
	pass


## The generic part of a save: taken things, fired triggers, hints, respawn point, counters.
func capture_common() -> Dictionary:
	return {
		"spawn": [spawn_position.x, spawn_position.y, spawn_position.z, spawn_yaw],
		"taken": _taken.keys(),
		"hints": _hints_shown.keys(),
		"zones": _fired.keys(),
		"defeated": enemies_defeated,
		"takedowns": takedowns,
	}


func restore_common(state: Dictionary) -> void:
	enemies_defeated = int(state.get("defeated", 0))
	takedowns = int(state.get("takedowns", 0))
	var spawn: Array = state.get("spawn", [])
	if spawn.size() >= 4:
		spawn_position = Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2]))
		spawn_yaw = float(spawn[3])
	for key: Variant in state.get("hints", []):
		_hints_shown[str(key)] = true
	for index: Variant in state.get("zones", []):
		_fired[int(index)] = true
		if int(index) < _zones.size():
			_zones[int(index)].enabled = false
	for key: Variant in state.get("taken", []):
		_taken[str(key)] = true
		var usable: Usable = objects.get(str(key)) as Usable
		if usable != null:
			usable.set_enabled(false)
			if usable.has_meta(&"mesh"):
				(usable.get_meta(&"mesh") as Node3D).visible = false


## This area's own saved state (GameState keeps one dictionary per area).
func saved_state() -> Dictionary:
	return GameState.get_level_state(flag_prefix)


func _exit_tree() -> void:
	Footsteps.surface_provider = Callable()


## Bakes a navigation mesh from the static colliders inside `bounds` (call after geometry is in the tree).
func bake_navigation(bounds: AABB) -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Player.LAYER_WORLD
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.agent_max_slope = 44.0
	mesh.filter_baking_aabb = bounds
	# Parse the whole level (by group) so a rebake after a door opens sees the same world.
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"navigation_source"
	add_to_group(&"navigation_source")
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, self)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "Navigation"
	navigation_region.navigation_mesh = mesh
	add_child(navigation_region)


## Rebuilds the navmesh in the background (after a door that was baked in has opened).
func rebake_navigation() -> void:
	if navigation_region != null and is_instance_valid(navigation_region) and not navigation_region.is_baking():
		navigation_region.bake_navigation_mesh(true)


# --- Helpers ------------------------------------------------------------------------

func is_sheltered(point: Vector3) -> bool:
	for box: AABB in interiors:
		if box.has_point(point):
			return true
	return false


## Footstep surface under `point`.
func get_surface(point: Vector3) -> String:
	for entry: Array in surfaces:
		if (entry[0] as AABB).has_point(point):
			return str(entry[1])
	return default_surface


func get_document(document_id: String) -> Dictionary:
	for document: Dictionary in documents:
		if str(document["id"]) == document_id:
			return document
	return {}


func set_checkpoint(checkpoint_id: String, at: Vector3, yaw: float, force: bool = false) -> void:
	if GameState.checkpoint_id == checkpoint_id and not force:
		return
	GameState.checkpoint_id = checkpoint_id
	spawn_position = at
	spawn_yaw = yaw
	if _player != null and is_instance_valid(_player) and not _player.is_dead():
		_player.injectors = _player.combat.max_injectors
		_player.emit_combat_status()
	AudioManager.play_ui(&"checkpoint", -10.0)
	EventBus.toast_requested.emit("Checkpoint", 2.0)
	EventBus.checkpoint_reached.emit(StringName(checkpoint_id))


func _radio(key: String) -> void:
	if GameState.has_flag(flag_prefix + "_radio_" + key):
		return
	GameState.set_flag(flag_prefix + "_radio_" + key)
	EventBus.dialogue_requested.emit((story.get("radio", {}) as Dictionary).get(key, []))


func _hint(key: String, seconds: float = 7.0) -> void:
	if _hints_shown.has(key):
		return
	_hints_shown[key] = true
	EventBus.hint_requested.emit(str((story.get("hints", {}) as Dictionary).get(key, "")), seconds)


func _update_enemy_sleep(position_now: Vector3) -> void:
	var sleep_distance: float = float(tuning.get("enemy_sleep_distance", 80.0))
	var wake_distance: float = float(tuning.get("enemy_wake_distance", 68.0))
	for enemy: Enemy in get_enemies():
		var distance: float = enemy.global_position.distance_to(position_now)
		if distance > sleep_distance:
			enemy.set_asleep(true)
		elif distance < wake_distance:
			enemy.set_asleep(false)


func _trigger(center: Vector3, size: Vector3, action: Callable) -> TriggerZone:
	var zone := TriggerZone.new()
	zone.size = size
	zone.position = center
	add_child(zone)
	var index: int = _zones.size()
	_zones.append(zone)
	zone.triggered.connect(func(_player: Player) -> void: _fired[index] = true)
	zone.triggered.connect(action)
	return zone


## Names a usable so tests can reach it and saves remember one-shots.
func _track(key: String, usable: Usable) -> void:
	objects[key] = usable
	if usable.one_shot:
		usable.used.connect(func(_player: Player) -> void: _taken[key] = true)


func _make_usable(prompt: String, at: Vector3, one_shot: bool, radius: float = 1.2) -> Usable:
	var usable := Usable.new()
	usable.prompt = prompt
	usable.one_shot = one_shot
	usable.radius = radius
	usable.position = at
	add_child(usable)
	usable.add_beacon(CityBuilder.COLOR_WARM, 1.2, 0.5)
	return usable


## Something small Kael picks up; it disappears when taken.
func _make_pickup(prompt: String, at: Vector3, size: Vector3, color: Color, glow: Color) -> Usable:
	var usable := Usable.new()
	usable.prompt = prompt
	usable.one_shot = true
	usable.position = at
	add_child(usable)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = 0.25
	box.material = material
	mesh.mesh = box
	mesh.position.y = size.y * 0.5 + 0.02
	usable.add_child(mesh)
	usable.add_beacon(glow, size.y + 0.25, 0.7)
	usable.set_meta(&"mesh", mesh)
	usable.used.connect(func(_player: Player) -> void: mesh.visible = false)
	return usable


func _add_document(document_id: String, at: Vector3) -> void:
	var paper: Usable = _make_pickup("Read", at, Vector3(0.22, 0.02, 0.3), Color(0.85, 0.82, 0.72), Color(1.0, 0.95, 0.8))
	_track(document_id, paper)
	paper.used.connect(_on_document_read.bind(document_id))


func _on_document_read(_player_node: Player, document_id: String) -> void:
	if not GameState.collected_documents.has(document_id):
		GameState.collected_documents.append(document_id)
	var document: Dictionary = get_document(document_id).duplicate()
	var found_here: int = 0
	for entry: Dictionary in documents:
		if GameState.collected_documents.has(str(entry["id"])):
			found_here += 1
	document["footer"] = "Documents found in %s: %d / %d" % [area_title, found_here, documents.size()]
	EventBus.document_collected.emit(document)
	_document_collected(document_id)


func _make_door(center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Player.LAYER_WORLD
	body.collision_mask = 0
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	material.roughness = 0.5
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	add_child(body)
	return body


## Opens (removes) a door. `rebake`: the door was part of the navmesh bake, so
## paths are rebuilt now that it is gone.
func _open_door(key: String, rebake: bool = false) -> void:
	var door: StaticBody3D = objects.get(key)
	if door != null and is_instance_valid(door):
		if door.get_parent() != null:
			door.get_parent().remove_child(door)
		door.queue_free()
		objects.erase(key)
		if rebake:
			rebake_navigation()


## A ladder with worn yellow rails. `faces_north`: the climbing side points to -Z.
func _make_ladder(base: Vector3, height: float, faces_north: bool, usable: bool) -> Ladder:
	var ladder := Ladder.new()
	ladder.height = height
	ladder.position = base
	ladder.rotation.y = PI if faces_north else 0.0
	ladder.enabled = usable
	add_child(ladder)
	var pieces: Array[Transform3D] = []
	for side: float in [-0.26, 0.26]:
		pieces.append(Transform3D(Basis.from_scale(Vector3(0.05, height + 0.9, 0.05)), Vector3(side, (height + 0.9) * 0.5, 0.06)))
	for i: int in range(1, int(height / 0.3) + 1):
		pieces.append(Transform3D(Basis.from_scale(Vector3(0.5, 0.035, 0.035)), Vector3(0.0, i * 0.3, 0.06)))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.5, 0.12)
	material.metallic = 0.5
	material.roughness = 0.6
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = pieces.size()
	for i: int in pieces.size():
		multimesh.set_instance_transform(i, pieces[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = "Visual"
	visual.multimesh = multimesh
	visual.visible = usable
	ladder.add_child(visual)
	return ladder


## A patch of tall grass: one MultiMesh of blades plus a hiding volume.
func _add_grass(at: Vector3, area: Vector2) -> void:
	var zone := StealthZone.new()
	zone.kind = StealthZone.Kind.HIDING
	zone.size = Vector3(area.x, 1.6, area.y)
	zone.position = at
	add_child(zone)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.05, 1.0, 0.012)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.15, 0.09)
	material.roughness = 0.9
	blade.material = material
	var density: float = 45.0 * SettingsManager.get_float("graphics", "foliage_density")
	var count: int = maxi(int(area.x * area.y * density), 1)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade
	multimesh.instance_count = count
	var random := RandomNumberGenerator.new()
	random.seed = int(at.x * 31.0 + at.z * 17.0)
	for i: int in count:
		var height: float = random.randf_range(0.7, 1.25)
		var basis := Basis(Vector3.UP, random.randf() * TAU) * Basis(Vector3.RIGHT, random.randf_range(-0.22, 0.22))
		basis = basis.scaled(Vector3(1.0, height, 1.0))
		var offset := Vector3(random.randf_range(-0.5, 0.5) * area.x, height * 0.5, random.randf_range(-0.5, 0.5) * area.y)
		multimesh.set_instance_transform(i, Transform3D(basis, offset))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 70.0
	add_child(instance)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
