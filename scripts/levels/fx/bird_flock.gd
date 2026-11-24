class_name BirdFlock
extends Node3D
## A few dark birds wheeling over the canopy: each one circles the flock's
## centre on its own radius, height and speed, flapping now and then.

var count: int = 7
var radius: float = 18.0
var height: float = 28.0

var _birds: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.05, 0.05)
	material.roughness = 1.0
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(0.45, 0.03, 0.18)
	wing_mesh.material = material
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.1, 0.08, 0.32)
	body_mesh.material = material
	for i: int in count:
		var bird := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		bird.add_child(body)
		var wings: Array[Node3D] = []
		for side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			bird.add_child(pivot)
			var wing := MeshInstance3D.new()
			wing.mesh = wing_mesh
			wing.position.x = side * 0.24
			pivot.add_child(wing)
			pivot.set_meta(&"side", side)
			wings.append(pivot)
		for child: Node in bird.find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bird)
		_birds.append({
			"node": bird, "wings": wings, "phase": randf() * TAU,
			"radius": radius * randf_range(0.6, 1.2), "height": height + randf_range(-4.0, 4.0),
			"speed": randf_range(0.18, 0.28) * (1.0 if i % 3 else -1.0), "flap": randf() * 10.0,
		})


func _process(delta: float) -> void:
	_time += delta
	for bird: Dictionary in _birds:
		var angle: float = float(bird["phase"]) + _time * float(bird["speed"])
		var r: float = float(bird["radius"]) * (1.0 + 0.15 * sin(_time * 0.3 + float(bird["phase"])))
		var node: Node3D = bird["node"]
		var at := Vector3(cos(angle) * r, float(bird["height"]) + sin(_time * 0.7 + float(bird["phase"])) * 1.5, sin(angle) * r)
		var ahead := Vector3(cos(angle + 0.05 * signf(float(bird["speed"]))) * r, at.y, sin(angle + 0.05 * signf(float(bird["speed"]))) * r)
		node.position = at
		if not at.is_equal_approx(ahead):
			node.look_at(global_transform * ahead, Vector3.UP)
		# Bursts of flapping between glides.
		var flap_clock: float = fmod(_time + float(bird["flap"]), 4.0)
		var beat: float = sin(_time * 16.0) * 0.6 if flap_clock < 1.4 else 0.1
		for pivot: Node3D in bird["wings"]:
			pivot.rotation.z = beat * float(pivot.get_meta(&"side"))
