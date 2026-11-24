extends SceneTree
## Dev tool: builds the corrupted wolf (low-poly, matching the chunky KayKit
## style) with its animation clips and saves it as a scene.
##   godot --headless --path . -s tools/dev/build_wolf.gd
## Faces +Z like the KayKit models; EnemyVisuals turns it round.

const OUT: String = "res://assets/models/characters/wolf/wolf.tscn"
const FUR := Color(0.3, 0.28, 0.25)
const FUR_DARK := Color(0.16, 0.15, 0.14)
const FUR_LIGHT := Color(0.48, 0.44, 0.38)
const BONE := Color(0.82, 0.8, 0.72)
const ECHO := Color(0.27, 0.92, 1.0)
const BODY_Y: float = 0.67

var wolf: Node3D
var _materials: Dictionary = {}


func _init() -> void:
	wolf = Node3D.new()
	wolf.name = "Wolf"
	var body: Node3D = _pivot(wolf, "Body", Vector3(0.0, BODY_Y, 0.0))
	_box(body, "Torso", Vector3(0.34, 0.32, 0.86), Vector3(0.0, 0.0, -0.02), FUR)
	_box(body, "Chest", Vector3(0.4, 0.42, 0.36), Vector3(0.0, -0.02, 0.28), FUR)
	_box(body, "Belly", Vector3(0.26, 0.08, 0.6), Vector3(0.0, -0.17, 0.02), FUR_LIGHT)
	_box(body, "Hips", Vector3(0.34, 0.3, 0.3), Vector3(0.0, 0.02, -0.34), FUR)
	_box(body, "Back", Vector3(0.24, 0.06, 0.8), Vector3(0.0, 0.17, -0.02), FUR_DARK)
	_box(body, "Mane", Vector3(0.46, 0.44, 0.22), Vector3(0.0, 0.06, 0.42), FUR_DARK, Vector3(-12.0, 0.0, 0.0))
	# The Echo has split the hide: glowing seams along the spine and ribs.
	_glow(body, "Spine", Vector3(0.03, 0.03, 0.62), Vector3(0.0, 0.205, -0.04))
	for rib: int in 3:
		for side: float in [-1.0, 1.0]:
			_glow(body, "Rib%d%s" % [rib, "L" if side < 0.0 else "R"], Vector3(0.02, 0.2, 0.025),
					Vector3(side * 0.172, 0.0, 0.12 - rib * 0.16), Vector3(0.0, 0.0, side * 12.0))
	var neck: Node3D = _pivot(body, "Neck", Vector3(0.0, 0.1, 0.42))
	_box(neck, "NeckMesh", Vector3(0.22, 0.24, 0.3), Vector3(0.0, 0.06, 0.12), FUR, Vector3(-25.0, 0.0, 0.0))
	var head: Node3D = _pivot(neck, "Head", Vector3(0.0, 0.15, 0.27))
	_box(head, "Skull", Vector3(0.26, 0.22, 0.26), Vector3(0.0, 0.0, 0.04), FUR)
	_box(head, "Brow", Vector3(0.24, 0.05, 0.1), Vector3(0.0, 0.08, 0.13), FUR_DARK)
	_box(head, "Snout", Vector3(0.14, 0.11, 0.22), Vector3(0.0, -0.04, 0.26), FUR)
	_box(head, "SnoutTop", Vector3(0.1, 0.04, 0.2), Vector3(0.0, 0.02, 0.25), FUR_DARK)
	_box(head, "Nose", Vector3(0.06, 0.05, 0.04), Vector3(0.0, -0.01, 0.38), Color(0.03, 0.03, 0.03))
	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.09, 0.13, 0.05)
		ear.mesh = prism
		ear.name = "Ear" + ("L" if side < 0.0 else "R")
		ear.position = Vector3(side * 0.085, 0.17, -0.02)
		ear.rotation_degrees = Vector3(-10.0, 0.0, side * -12.0)
		ear.material_override = _material(FUR_DARK)
		_own(head, ear)
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.024
		sphere.height = 0.034
		sphere.radial_segments = 8
		sphere.rings = 4
		eye.mesh = sphere
		eye.name = ("L" if side < 0.0 else "R") + "_Eyes"
		eye.position = Vector3(side * 0.075, 0.04, 0.17)
		_own(head, eye)
	var jaw: Node3D = _pivot(head, "Jaw", Vector3(0.0, -0.09, 0.17))
	_box(jaw, "LowerJaw", Vector3(0.12, 0.045, 0.2), Vector3(0.0, -0.01, 0.1), FUR_LIGHT)
	for side: float in [-1.0, 1.0]:
		_box(jaw, "Fang" + ("L" if side < 0.0 else "R"), Vector3(0.02, 0.05, 0.02), Vector3(side * 0.045, 0.03, 0.18), BONE)
		_box(head, "UpperFang" + ("L" if side < 0.0 else "R"), Vector3(0.02, 0.05, 0.02), Vector3(side * 0.05, -0.11, 0.33), BONE)
	for leg: Array in [["FL", Vector3(-0.13, -0.08, 0.32), 1.0], ["FR", Vector3(0.13, -0.08, 0.32), 1.0],
			["BL", Vector3(-0.13, -0.06, -0.34), -1.0], ["BR", Vector3(0.13, -0.06, -0.34), -1.0]]:
		var hip: Node3D = _pivot(body, "Leg" + str(leg[0]), leg[1])
		var front: bool = float(leg[2]) > 0.0
		_box(hip, "Upper", Vector3(0.11, 0.32, 0.14) if not front else Vector3(0.1, 0.3, 0.12), Vector3(0.0, -0.14, 0.0), FUR)
		var knee: Node3D = _pivot(hip, "Knee" + str(leg[0]), Vector3(0.0, -0.3 if front else -0.32, 0.0))
		_box(knee, "Lower", Vector3(0.075, 0.26, 0.08), Vector3(0.0, -0.13, 0.0), FUR_DARK)
		_box(knee, "Paw", Vector3(0.1, 0.05, 0.13), Vector3(0.0, -0.27 if front else -0.25, 0.03), FUR_DARK)
	var tail: Node3D = _pivot(body, "Tail", Vector3(0.0, 0.09, -0.48))
	_box(tail, "TailBase", Vector3(0.09, 0.09, 0.26), Vector3(0.0, 0.0, -0.12), FUR)
	var tail_tip: Node3D = _pivot(tail, "TailTip", Vector3(0.0, 0.0, -0.25))
	_box(tail_tip, "TailEnd", Vector3(0.11, 0.11, 0.26), Vector3(0.0, 0.0, -0.12), FUR_DARK)
	tail.rotation.x = -0.55
	var anchor := Marker3D.new()
	anchor.name = "EyeAnchor"
	anchor.position = Vector3(0.0, 1.0, 0.62)
	_own(wolf, anchor)

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	_own(wolf, player)
	var library := AnimationLibrary.new()
	library.add_animation(&"Idle", _idle())
	library.add_animation(&"Walk", _gait(0.9, 0.38, 0.55, [0.0, 0.5, 0.5, 0.0], 0.015, 0.0))
	library.add_animation(&"Run", _gait(0.5, 0.72, 0.95, [0.0, 0.08, 0.5, 0.58], 0.05, 0.1))
	library.add_animation(&"Attack", _attack())
	library.add_animation(&"Hit", _hit())
	library.add_animation(&"Stagger", _stagger())
	library.add_animation(&"Death", _death())
	library.add_animation(&"Howl", _howl())
	player.add_animation_library(&"", library)

	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var scene := PackedScene.new()
	var error: Error = scene.pack(wolf)
	if error == OK:
		error = ResourceSaver.save(scene, OUT)
	print("wolf saved: ", error_string(error))
	wolf.free()
	quit(0 if error == OK else 1)


# --- Building ---------------------------------------------------------------------

func _own(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = wolf


func _pivot(parent: Node3D, pivot_name: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = at
	_own(parent, pivot)
	return pivot


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.92
		_materials[color] = material
	return _materials[color]


func _box(parent: Node3D, box_name: String, size: Vector3, at: Vector3, color: Color, degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.name = box_name
	mesh.position = at
	mesh.rotation_degrees = degrees
	mesh.material_override = _material(color)
	_own(parent, mesh)
	return mesh


func _glow(parent: Node3D, glow_name: String, size: Vector3, at: Vector3, degrees: Vector3 = Vector3.ZERO) -> void:
	var mesh: MeshInstance3D = _box(parent, "Glow" + glow_name, size, at, ECHO, degrees)
	if not _materials.has("glow"):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.05, 0.2, 0.24)
		material.emission_enabled = true
		material.emission = ECHO
		material.emission_energy_multiplier = 1.6
		_materials["glow"] = material
	mesh.material_override = _materials["glow"]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Animation --------------------------------------------------------------------

## Adds a track for `property` of `node_path` with [time, value] keys.
func _track(animation: Animation, node_path: String, property: String, keys: Array) -> void:
	var index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, NodePath("%s:%s" % [node_path, property]))
	animation.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
	for key: Array in keys:
		animation.track_insert_key(index, float(key[0]), key[1])


func _rest_rotations(animation: Animation, skip: PackedStringArray) -> void:
	# Every clip keys every joint, so a clip never inherits a pose from the last one.
	var joints: Dictionary = {
		"Body": Vector3.ZERO, "Body/Neck": Vector3.ZERO, "Body/Neck/Head": Vector3.ZERO, "Body/Neck/Head/Jaw": Vector3.ZERO,
		"Body/Tail": Vector3(-0.55, 0.0, 0.0), "Body/Tail/TailTip": Vector3.ZERO,
	}
	for leg: String in ["FL", "FR", "BL", "BR"]:
		joints["Body/Leg" + leg] = Vector3.ZERO
		joints["Body/Leg%s/Knee%s" % [leg, leg]] = Vector3.ZERO
	for path: String in joints:
		if not skip.has(path):
			_track(animation, path, "rotation", [[0.0, joints[path]]])
	if not skip.has("Body:position"):
		_track(animation, "Body", "position", [[0.0, Vector3(0.0, BODY_Y, 0.0)]])


func _idle() -> Animation:
	var animation := Animation.new()
	animation.length = 2.4
	animation.loop_mode = Animation.LOOP_LINEAR
	_rest_rotations(animation, ["Body:position", "Body/Neck/Head", "Body/Tail", "Body/Neck/Head/Jaw"])
	_track(animation, "Body", "position", [[0.0, Vector3(0, BODY_Y, 0)], [1.2, Vector3(0, BODY_Y + 0.01, 0)], [2.4, Vector3(0, BODY_Y, 0)]])
	_track(animation, "Body/Neck/Head", "rotation", [[0.0, Vector3(0.15, 0.0, 0.0)], [0.8, Vector3(0.1, 0.25, 0.0)], [1.6, Vector3(0.18, -0.2, 0.0)], [2.4, Vector3(0.15, 0.0, 0.0)]])
	_track(animation, "Body/Neck/Head/Jaw", "rotation", [[0.0, Vector3(0.08, 0, 0)], [1.2, Vector3(0.15, 0, 0)], [2.4, Vector3(0.08, 0, 0)]])
	_track(animation, "Body/Tail", "rotation", [[0.0, Vector3(-0.6, 0.2, 0.0)], [1.2, Vector3(-0.6, -0.2, 0.0)], [2.4, Vector3(-0.6, 0.2, 0.0)]])
	return animation


## A walk or gallop: each leg swings with its own phase; the knee folds as the
## leg comes forward.
func _gait(length: float, swing: float, fold: float, phases: Array, bob: float, pitch: float) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR
	_rest_rotations(animation, ["Body", "Body:position", "Body/Tail", "Body/Neck/Head",
			"Body/LegFL", "Body/LegFR", "Body/LegBL", "Body/LegBR",
			"Body/LegFL/KneeFL", "Body/LegFR/KneeFR", "Body/LegBL/KneeBL", "Body/LegBR/KneeBR"])
	var steps: int = 8
	var legs: Array = ["FL", "FR", "BL", "BR"]
	for i: int in legs.size():
		var leg: String = legs[i]
		var swing_keys: Array = []
		var knee_keys: Array = []
		var back: bool = leg.begins_with("B")
		for step: int in steps + 1:
			var t: float = float(step) / float(steps)
			var angle: float = TAU * (t + float(phases[i]))
			# Positive swing pushes the paw back; negative reaches forward.
			swing_keys.append([t * length, Vector3(swing * sin(angle), 0.0, 0.0)])
			var lift: float = maxf(0.0, cos(angle)) * fold
			knee_keys.append([t * length, Vector3(-lift if back else lift, 0.0, 0.0)])
		_track(animation, "Body/Leg" + leg, "rotation", swing_keys)
		_track(animation, "Body/Leg%s/Knee%s" % [leg, leg], "rotation", knee_keys)
	var body_keys: Array = []
	var position_keys: Array = []
	var head_keys: Array = []
	var tail_keys: Array = []
	for step: int in steps + 1:
		var t: float = float(step) / float(steps)
		body_keys.append([t * length, Vector3(pitch * sin(TAU * t), 0.0, 0.0)])
		position_keys.append([t * length, Vector3(0.0, BODY_Y + bob * absf(sin(TAU * t)), 0.0)])
		head_keys.append([t * length, Vector3(0.1 - pitch * sin(TAU * t) * 0.8, 0.0, 0.0)])
		tail_keys.append([t * length, Vector3(-0.35 - pitch * 2.0, 0.25 * sin(TAU * t * 2.0) * (0.4 if pitch > 0.0 else 1.0), 0.0)])
	_track(animation, "Body", "rotation", body_keys)
	_track(animation, "Body", "position", position_keys)
	_track(animation, "Body/Neck/Head", "rotation", head_keys)
	_track(animation, "Body/Tail", "rotation", tail_keys)
	return animation


func _attack() -> Animation:
	var animation := Animation.new()
	animation.length = 0.75
	_rest_rotations(animation, ["Body", "Body:position", "Body/Neck/Head", "Body/Neck/Head/Jaw", "Body/LegFL", "Body/LegFR", "Body/LegBL", "Body/LegBR"])
	# Crouch, spring, snap (at 0.34 s), land.
	_track(animation, "Body", "position", [[0.0, Vector3(0, BODY_Y, 0)], [0.2, Vector3(0, BODY_Y - 0.1, -0.12)], [0.34, Vector3(0, BODY_Y + 0.08, 0.3)], [0.55, Vector3(0, BODY_Y, 0.2)], [0.75, Vector3(0, BODY_Y, 0)]])
	_track(animation, "Body", "rotation", [[0.0, Vector3.ZERO], [0.2, Vector3(0.12, 0, 0)], [0.34, Vector3(-0.15, 0, 0)], [0.75, Vector3.ZERO]])
	_track(animation, "Body/Neck/Head", "rotation", [[0.0, Vector3(0.1, 0, 0)], [0.2, Vector3(0.35, 0, 0)], [0.34, Vector3(-0.1, 0, 0)], [0.75, Vector3(0.1, 0, 0)]])
	_track(animation, "Body/Neck/Head/Jaw", "rotation", [[0.0, Vector3(0.05, 0, 0)], [0.24, Vector3(0.75, 0, 0)], [0.34, Vector3(0.0, 0, 0)], [0.5, Vector3(0.2, 0, 0)], [0.75, Vector3(0.05, 0, 0)]])
	for leg: String in ["FL", "FR"]:
		_track(animation, "Body/Leg" + leg, "rotation", [[0.0, Vector3.ZERO], [0.2, Vector3(0.3, 0, 0)], [0.34, Vector3(-0.9, 0, 0)], [0.55, Vector3(-0.2, 0, 0)], [0.75, Vector3.ZERO]])
	for leg: String in ["BL", "BR"]:
		_track(animation, "Body/Leg" + leg, "rotation", [[0.0, Vector3.ZERO], [0.2, Vector3(-0.35, 0, 0)], [0.34, Vector3(0.7, 0, 0)], [0.55, Vector3(0.2, 0, 0)], [0.75, Vector3.ZERO]])
	return animation


func _hit() -> Animation:
	var animation := Animation.new()
	animation.length = 0.4
	_rest_rotations(animation, ["Body", "Body/Neck/Head"])
	_track(animation, "Body", "rotation", [[0.0, Vector3.ZERO], [0.1, Vector3(-0.1, 0, 0.18)], [0.4, Vector3.ZERO]])
	_track(animation, "Body/Neck/Head", "rotation", [[0.0, Vector3(0.1, 0, 0)], [0.1, Vector3(-0.45, 0.3, 0)], [0.4, Vector3(0.1, 0, 0)]])
	return animation


func _stagger() -> Animation:
	var animation := Animation.new()
	animation.length = 0.9
	_rest_rotations(animation, ["Body", "Body:position", "Body/Neck/Head", "Body/LegFL", "Body/LegFR"])
	_track(animation, "Body", "rotation", [[0.0, Vector3.ZERO], [0.2, Vector3(0, 0, 0.3)], [0.45, Vector3(0, 0, -0.2)], [0.9, Vector3.ZERO]])
	_track(animation, "Body", "position", [[0.0, Vector3(0, BODY_Y, 0)], [0.25, Vector3(0.1, BODY_Y - 0.12, -0.15)], [0.9, Vector3(0, BODY_Y, 0)]])
	_track(animation, "Body/Neck/Head", "rotation", [[0.0, Vector3(0.1, 0, 0)], [0.3, Vector3(0.6, -0.3, 0)], [0.9, Vector3(0.1, 0, 0)]])
	_track(animation, "Body/LegFL", "rotation", [[0.0, Vector3.ZERO], [0.3, Vector3(-0.3, 0, -0.25)], [0.9, Vector3.ZERO]])
	_track(animation, "Body/LegFR", "rotation", [[0.0, Vector3.ZERO], [0.3, Vector3(0.2, 0, 0.25)], [0.9, Vector3.ZERO]])
	return animation


func _death() -> Animation:
	var animation := Animation.new()
	animation.length = 1.2
	_rest_rotations(animation, ["Body", "Body:position", "Body/Neck/Head", "Body/Neck/Head/Jaw", "Body/Tail", "Body/LegFL", "Body/LegFR", "Body/LegBL", "Body/LegBR"])
	# Legs buckle, then it rolls onto its side.
	_track(animation, "Body", "position", [[0.0, Vector3(0, BODY_Y, 0)], [0.35, Vector3(0, BODY_Y - 0.25, 0)], [0.8, Vector3(0, 0.22, 0)], [1.2, Vector3(0, 0.2, 0)]])
	_track(animation, "Body", "rotation", [[0.0, Vector3.ZERO], [0.35, Vector3(0.15, 0, 0.1)], [0.8, Vector3(0.05, 0, 1.45)], [1.2, Vector3(0, 0, 1.5)]])
	_track(animation, "Body/Neck/Head", "rotation", [[0.0, Vector3(0.1, 0, 0)], [0.3, Vector3(-0.4, 0, 0)], [1.2, Vector3(0.3, 0, -0.2)]])
	_track(animation, "Body/Neck/Head/Jaw", "rotation", [[0.0, Vector3.ZERO], [0.3, Vector3(0.6, 0, 0)], [1.2, Vector3(0.25, 0, 0)]])
	_track(animation, "Body/Tail", "rotation", [[0.0, Vector3(-0.55, 0, 0)], [1.2, Vector3(-0.1, 0.3, 0)]])
	for leg: String in ["FL", "FR", "BL", "BR"]:
		var out: float = -0.5 if leg.begins_with("F") else 0.5
		_track(animation, "Body/Leg" + leg, "rotation", [[0.0, Vector3.ZERO], [0.35, Vector3(out * 0.5, 0, 0)], [1.2, Vector3(out, 0, 0)]])
	return animation


func _howl() -> Animation:
	var animation := Animation.new()
	animation.length = 1.4
	_rest_rotations(animation, ["Body", "Body/Neck", "Body/Neck/Head", "Body/Neck/Head/Jaw"])
	_track(animation, "Body", "rotation", [[0.0, Vector3.ZERO], [0.4, Vector3(-0.12, 0, 0)], [1.1, Vector3(-0.12, 0, 0)], [1.4, Vector3.ZERO]])
	_track(animation, "Body/Neck", "rotation", [[0.0, Vector3.ZERO], [0.4, Vector3(-0.28, 0, 0)], [1.1, Vector3(-0.28, 0, 0)], [1.4, Vector3.ZERO]])
	_track(animation, "Body/Neck/Head", "rotation", [[0.0, Vector3(0.1, 0, 0)], [0.4, Vector3(-0.45, 0, 0)], [1.1, Vector3(-0.5, 0, 0)], [1.4, Vector3(0.1, 0, 0)]])
	_track(animation, "Body/Neck/Head/Jaw", "rotation", [[0.0, Vector3.ZERO], [0.45, Vector3(0.55, 0, 0)], [1.05, Vector3(0.5, 0, 0)], [1.4, Vector3.ZERO]])
	return animation
