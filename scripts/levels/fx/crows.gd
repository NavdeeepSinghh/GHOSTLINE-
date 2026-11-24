class_name Crows
extends Node3D
## A few crows on a roof edge or picking at the street. They hop, peck and
## look about; when Kael comes close or something makes a noise nearby they
## burst into the air with a clatter of wings and fly off, coming back a while
## after he has gone.

const NOTICE_DISTANCE: float = 7.0
const RETURN_SECONDS: float = 30.0
const RETURN_DISTANCE: float = 25.0
const SLEEP_DISTANCE: float = 60.0

var count: int = 4
## Spread of the group along its local X (a roof edge) or as a patch (ground).
var spread: float = 2.0
var on_ground: bool = true

var flushed: bool = false
var _crows: Array[Dictionary] = []
var _gone_for: float = 0.0
var _check: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.04, 0.04, 0.05)
	black.roughness = 0.6
	black.metallic_specular = 0.7
	var beak := StandardMaterial3D.new()
	beak.albedo_color = Color(0.12, 0.11, 0.1)
	for i: int in count:
		var crow := Node3D.new()
		crow.name = "Crow%d" % i
		var body := _part(crow, Vector3(0.11, 0.11, 0.24), Vector3(0.0, 0.12, 0.0), black)
		body.rotation.x = -0.25
		_part(crow, Vector3(0.08, 0.03, 0.14), Vector3(0.0, 0.1, -0.16), black).rotation.x = 0.35
		var head := Node3D.new()
		head.position = Vector3(0.0, 0.2, 0.1)
		crow.add_child(head)
		_part(head, Vector3(0.08, 0.08, 0.09), Vector3.ZERO, black)
		_part(head, Vector3(0.03, 0.03, 0.07), Vector3(0.0, -0.01, 0.07), beak)
		for side: float in [-1.0, 1.0]:
			_part(crow, Vector3(0.015, 0.08, 0.015), Vector3(side * 0.03, 0.04, 0.02), beak)
		var wings: Array[Node3D] = []
		for side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.05, 0.15, 0.0)
			crow.add_child(pivot)
			_part(pivot, Vector3(0.22, 0.02, 0.15), Vector3(side * 0.11, 0.0, -0.02), black)
			pivot.rotation = Vector3(0.0, side * 1.45, 0.0)  # folded back along the body
			pivot.set_meta(&"side", side)
			wings.append(pivot)
		crow.scale = Vector3.ONE * 1.4
		add_child(crow)
		var home: Vector3
		if on_ground:
			home = Vector3(_rng.randf_range(-spread, spread), 0.0, _rng.randf_range(-spread, spread))
		else:
			home = Vector3(lerpf(-spread, spread, (float(i) + _rng.randf_range(0.2, 0.8)) / float(count)), 0.0, 0.0)
		crow.position = home
		crow.rotation.y = _rng.randf() * TAU if on_ground else _rng.randf_range(-0.6, 0.6) + (PI if _rng.randf() < 0.3 else 0.0)
		_crows.append({"node": crow, "head": head, "wings": wings, "home": home, "yaw": crow.rotation.y,
				"next": _rng.randf_range(0.5, 3.0), "peck": 0.0, "velocity": Vector3.ZERO, "flap": _rng.randf() * TAU})
	EventBus.noise_emitted.connect(_on_noise)
	_settle.call_deferred()


## Drops each crow onto whatever is under it (a parapet, a kerb, a car roof).
func _settle() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for crow: Dictionary in _crows:
		var node: Node3D = crow["node"]
		var from: Vector3 = node.global_position + Vector3.UP * 2.5
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, Player.LAYER_WORLD)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var home: Vector3 = crow["home"]
		home.y = to_local(hit["position"]).y
		crow["home"] = home
		if not flushed:
			node.position.y = home.y


func _part(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _on_noise(at: Vector3, radius: float, _source: Node) -> void:
	if not flushed and is_inside_tree() and global_position.distance_to(at) < radius + 4.0:
		flush(at)


## Up and away from `threat`.
func flush(threat: Vector3) -> void:
	if flushed:
		return
	flushed = true
	_gone_for = 0.0
	for crow: Dictionary in _crows:
		var node: Node3D = crow["node"]
		var away: Vector3 = node.global_position - threat
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		away = away.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
		crow["velocity"] = away * _rng.randf_range(4.0, 6.5) + Vector3.UP * _rng.randf_range(3.0, 4.5)
		crow["delay"] = _rng.randf_range(0.0, 0.35)
	AudioManager.play_sfx(&"wings_takeoff", global_position + Vector3.UP, -6.0)
	if _rng.randf() < 0.7:
		AudioManager.play_sfx(&"crow_caw", global_position + Vector3.UP * 2.0, -10.0, 0.15)


func _land() -> void:
	flushed = false
	for crow: Dictionary in _crows:
		var node: Node3D = crow["node"]
		node.position = crow["home"]
		node.rotation = Vector3(0.0, float(crow["yaw"]), 0.0)
		node.visible = true
		for pivot: Node3D in crow["wings"]:
			pivot.rotation = Vector3(0.0, float(pivot.get_meta(&"side")) * 1.45, 0.0)


func _process(delta: float) -> void:
	_check -= delta
	var kael: Node3D = null
	if _check <= 0.0:
		_check = 0.15
		kael = get_tree().get_first_node_in_group(&"player") as Node3D
		var distance: float = global_position.distance_to(kael.global_position) if kael != null else INF
		visible = distance < SLEEP_DISTANCE or flushed
		if not flushed and distance < NOTICE_DISTANCE:
			flush(kael.global_position)
		elif flushed and _gone_for > RETURN_SECONDS and distance > RETURN_DISTANCE:
			_land()
	if not visible:
		return
	if flushed:
		_gone_for += delta
		_fly(delta)
	else:
		_idle(delta)


func _fly(delta: float) -> void:
	for crow: Dictionary in _crows:
		var node: Node3D = crow["node"]
		if not node.visible:
			continue
		var wait: float = float(crow.get("delay", 0.0))
		if wait > 0.0:
			crow["delay"] = wait - delta
			continue
		var velocity: Vector3 = crow["velocity"]
		velocity.y = maxf(velocity.y - delta * 0.8, 1.2)
		crow["velocity"] = velocity
		node.position += velocity * delta
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if flat.length() > 0.1:
			node.rotation.y = atan2(flat.x, flat.z)
		node.rotation.x = -0.3
		crow["flap"] = float(crow["flap"]) + delta * 22.0
		for pivot: Node3D in crow["wings"]:
			pivot.rotation = Vector3(0.0, 0.0, float(pivot.get_meta(&"side")) * sin(float(crow["flap"])) * 0.9)
		if node.position.y > 40.0:
			node.visible = false


func _idle(delta: float) -> void:
	for crow: Dictionary in _crows:
		var node: Node3D = crow["node"]
		var head: Node3D = crow["head"]
		crow["next"] = float(crow["next"]) - delta
		crow["peck"] = maxf(float(crow["peck"]) - delta, 0.0)
		if float(crow["next"]) <= 0.0:
			crow["next"] = _rng.randf_range(0.8, 3.5)
			var roll: float = _rng.randf()
			if roll < 0.35:
				head.rotation.y = _rng.randf_range(-0.9, 0.9)
			elif roll < 0.65 and on_ground:
				crow["peck"] = 0.35
			elif on_ground:
				# A little hop to a new spot.
				node.rotation.y += _rng.randf_range(-1.2, 1.2)
				var step := Vector3(sin(node.rotation.y), 0.0, cos(node.rotation.y)) * _rng.randf_range(0.15, 0.4)
				var target: Vector3 = node.position + step
				if Vector2(target.x, target.z).length() < spread + 0.5:
					node.position = target
				crow["hop"] = 0.2
		var hop: float = float(crow.get("hop", 0.0))
		if hop > 0.0:
			crow["hop"] = hop - delta
		node.position.y = (crow["home"] as Vector3).y + sin(clampf(hop / 0.2, 0.0, 1.0) * PI) * 0.08
		head.rotation.x = sin(float(crow["peck"]) / 0.35 * PI) * 0.9
