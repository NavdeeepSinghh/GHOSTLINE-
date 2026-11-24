class_name LoadingScreen
extends CanvasLayer
## A black screen with the area's name, shown from the moment a load starts
## until the new area is built and its first frames are drawn. While it is up,
## a few enemies, effects and materials are drawn once out of sight so their
## shaders are compiled before play rather than in the middle of a fight.

signal finished

const AREA_NAMES: Dictionary = {
	"dead_city": "THE DEAD CITY",
	"forest": "THE FORGOTTEN FOREST",
	"facility": "THE UNDERGROUND FACILITY",
	"proving_ground": "PROVING GROUND",
}
const WARM_UP_FRAMES: int = 4

var area_title: String = ""
var _panel: ColorRect
var _warm_up: Node3D


static func for_area(area: String) -> LoadingScreen:
	var screen := LoadingScreen.new()
	screen.area_title = str(AREA_NAMES.get(area, area.to_upper()))
	return screen


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	_panel.color = Color.BLACK
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(-72, -72)
	box.alignment = BoxContainer.ALIGNMENT_END
	_panel.add_child(box)
	var heading: Label = UIStyle.label(area_title, 40, UIStyle.TEXT, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(heading)
	var loading: Label = UIStyle.label("Loading", 22, UIStyle.ECHO)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(loading)


## Draws one of each enemy and effect in front of `camera` (hidden by this
## screen), waits a few frames, cleans up, then fades out and frees itself.
func finish(world: Node, camera: Camera3D) -> void:
	if world != null and camera != null and is_instance_valid(camera):
		_warm_up = build_warm_up(camera)
		world.add_child(_warm_up)
	for i: int in WARM_UP_FRAMES:
		await get_tree().process_frame
	if _warm_up != null and is_instance_valid(_warm_up):
		_warm_up.queue_free()
		_warm_up = null
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.45)
	await tween.finished
	finished.emit()
	queue_free()


func is_warming_up() -> bool:
	return _warm_up != null and is_instance_valid(_warm_up)


static func build_warm_up(camera: Camera3D) -> Node3D:
	var root := Node3D.new()
	root.name = "ShaderWarmUp"
	var front: Transform3D = camera.global_transform
	root.transform = Transform3D(front.basis, front.origin - front.basis.z * 6.0)
	var x: float = -3.0
	for path: String in ["res://data/enemies/hollow.tres", "res://data/enemies/skitter.tres", "res://data/enemies/bulwark.tres",
			"res://data/enemies/spitter.tres", "res://data/enemies/wolf.tres"]:
		var data: EnemyData = load(path) as EnemyData
		if data == null:
			continue
		var visuals := EnemyVisuals.new()
		visuals.position = Vector3(x, -0.9, 0.0)
		root.add_child(visuals)
		visuals.setup(data)
		x += 1.5
	root.add_child(CityFX.fire(Vector3(0.0, -0.5, -1.0), 0.4, 0.5))
	root.add_child(CityFX.steam(Vector3(1.0, -1.0, -1.0), 4))
	for effect: Node3D in VFX.warm_up_set():
		root.add_child(effect)
	return root
