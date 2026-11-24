class_name Choir
extends Node3D
## The Choir: the Echo made visible, a mass of absorbed voices at the edge of
## the Resonance Chamber's platform. It does not move. It attacks the platform
## in patterns, and can only be hurt through its heart while that is exposed.
##
## Phase 1: slams where Kael stands and shockwave rings to jump or roll through;
##          the heart opens after each set.
## Phase 2: calls Hollows and Skitters, the platform's outer ring falls away,
##          and three resonance pillars must be struck to open the heart.
## Phase 3: Lyra breaks through and calls each attack before it lands
##          ("Left!", "Right!", "Jump!"), in sound and in subtitles.

signal phase_changed(phase: int)
signal summon_requested(count: int)
signal defeated

enum Attack { SLAM, RING, LEFT, RIGHT }

const TELEGRAPH_COLOR := Color(1.0, 0.5, 0.12, 0.3)

var tuning: Dictionary = {}
var max_health: float = 600.0
var health: float = 600.0
var phase: int = 1
var heart_exposed: bool = false
var arena_radius: float = 14.0
var is_active: bool = false
var pillars_struck: int = 0
## Attacks launched so far (tests and pacing).
var attacks_made: int = 0

var _player: Player
var _timer: float = 3.0
var _set_count: int = 0
var _expose_time: float = 0.0
var _heart: ChoirTarget
var _heart_mesh: MeshInstance3D
var _heart_light: OmniLight3D
var _pillars: Array[ChoirTarget] = []
var _pending: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _edge: MeshInstance3D
var _edge_tick: float = 0.0
var _done: bool = false


func _ready() -> void:
	max_health = float(tuning.get("health", 600.0)) * NewGamePlus.enemy_health_scale()
	health = max_health
	arena_radius = float(tuning.get("arena_radius", 14.0))
	_build_body()
	_heart = ChoirTarget.new()
	_heart.setup(self, -1, 1.1)
	_heart.position = Vector3(0.0, 1.6, -arena_radius + 1.2)
	add_child(_heart)
	_heart.add_to_group(CameraRig.LOCK_ON_GROUP)
	_heart_mesh = _glow_sphere(0.8, GrayboxBuilder.COLOR_ECHO)
	_heart.add_child(_heart_mesh)
	_heart_light = OmniLight3D.new()
	_heart_light.light_color = GrayboxBuilder.COLOR_ECHO
	_heart_light.omni_range = 9.0
	_heart.add_child(_heart_light)
	for i: int in 3:
		var angle: float = deg_to_rad(-90.0 + (i - 1) * 75.0) + PI
		var pillar := ChoirTarget.new()
		pillar.setup(self, i, 0.7)
		pillar.position = Vector3(cos(angle), 0.0, -sin(angle)) * (arena_radius * 0.55) + Vector3(0.0, 1.3, 0.0)
		add_child(pillar)
		var column := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.35
		mesh.bottom_radius = 0.5
		mesh.height = 2.6
		mesh.material = HazardPuddle.echo_material(2.0)
		column.mesh = mesh
		pillar.add_child(column)
		pillar.visible = false
		pillar.process_mode = Node.PROCESS_MODE_DISABLED
		_pillars.append(pillar)
	_set_heart(false)


## Starts the fight (the level calls this when Kael steps onto the platform).
func begin(player: Player) -> void:
	_player = player
	is_active = true
	EventBus.boss_started.emit("The Choir")
	AudioManager.play_ui(&"choir_swell", -2.0, &"SFX")


func get_ratio() -> float:
	return health / maxf(max_health, 0.001)


func _physics_process(delta: float) -> void:
	if not is_active or _done or _player == null or not is_instance_valid(_player):
		return
	_update_pending(delta)
	_update_rings(delta)
	_update_edge(delta)
	if heart_exposed:
		_expose_time -= delta
		if _expose_time <= 0.0:
			_set_heart(false)
			_timer = 1.5
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match phase:
		1:
			_attack(Attack.SLAM if _set_count % 3 != 2 else Attack.RING)
			_after_attack(3, float(tuning.get("expose_seconds", 5.0)))
		2:
			# The heart only opens through the pillars here.
			_attack(Attack.SLAM if _set_count % 2 == 0 else Attack.RING)
			_set_count += 1
			_timer = float(tuning.get("attack_gap", 2.4))
		_:
			var call: Attack = [Attack.LEFT, Attack.RING, Attack.RIGHT, Attack.RING][(_set_count + attacks_made) % 4]
			_attack(call)
			_after_attack(3, float(tuning.get("expose_seconds", 5.0)))


func _after_attack(set_size: int, expose_for: float) -> void:
	_set_count += 1
	_timer = float(tuning.get("attack_gap", 2.4)) * (0.8 if phase == 3 else 1.0)
	if _set_count % set_size == 0:
		_pending.append({"kind": "expose", "time": _timer + 0.4, "seconds": expose_for})
		_timer += expose_for


# --- Attacks -------------------------------------------------------------------------

func _attack(kind: Attack) -> void:
	attacks_made += 1
	CombatFX.sfx(&"enemy_telegraph", global_position + Vector3.UP * 2.0, 4.0)
	match kind:
		Attack.SLAM:
			var at: Vector3 = _player.global_position
			at.y = global_position.y
			var radius: float = float(tuning.get("slam_radius", 3.2))
			_pending.append({"kind": "slam", "time": float(tuning.get("slam_windup", 1.1)), "at": at, "radius": radius,
					"visual": _disc(at, radius)})
		Attack.RING:
			if phase == 3:
				_lyra("Jump!")
			_pending.append({"kind": "ring", "time": 0.7 if phase == 3 else 0.3})
		Attack.LEFT, Attack.RIGHT:
			# Lyra names the safe side. Left is -X when facing the Choir.
			var safe_left: bool = kind == Attack.LEFT
			_lyra("Left!" if safe_left else "Right!")
			var center: Vector3 = global_position + Vector3((1.0 if safe_left else -1.0) * arena_radius * 0.5, 0.0, 0.0)
			_pending.append({"kind": "half", "time": float(tuning.get("half_windup", 1.4)), "safe_left": safe_left,
					"visual": _slab(center, Vector3(arena_radius, 0.05, arena_radius * 2.0))})


func _lyra(text: String) -> void:
	EventBus.dialogue_requested.emit([{"speaker": "Lyra", "text": text, "seconds": 1.3, "sound": "tone_2"}])


func _update_pending(delta: float) -> void:
	for i: int in range(_pending.size() - 1, -1, -1):
		var entry: Dictionary = _pending[i]
		entry["time"] = float(entry["time"]) - delta
		if float(entry["time"]) > 0.0:
			continue
		_pending.remove_at(i)
		if entry.has("visual"):
			(entry["visual"] as Node).queue_free()
		match str(entry["kind"]):
			"slam":
				CombatFX.sfx(&"slam", entry["at"], 4.0)
				CombatFX.shake(0.3)
				if _flat_distance(_player.global_position, entry["at"]) <= float(entry["radius"]):
					_hurt(float(tuning.get("slam_damage", 22.0)))
			"ring":
				AudioManager.play_sfx(&"shockwave", global_position, 4.0)
				_rings.append({"radius": 0.5, "visual": _ring_visual()})
			"half":
				CombatFX.sfx(&"slam", _player.global_position, 4.0)
				CombatFX.shake(0.4)
				var on_left: bool = _player.global_position.x < global_position.x
				if on_left != bool(entry["safe_left"]):
					_hurt(float(tuning.get("half_damage", 26.0)))
			"expose":
				_set_heart(true)
				_expose_time = float(entry["seconds"])


func _update_rings(delta: float) -> void:
	var speed: float = float(tuning.get("ring_speed", 9.0))
	for i: int in range(_rings.size() - 1, -1, -1):
		var ring: Dictionary = _rings[i]
		var before: float = float(ring["radius"])
		var after: float = before + speed * delta
		ring["radius"] = after
		var visual: MeshInstance3D = ring["visual"]
		visual.scale = Vector3(after, 1.0, after)
		# The ring hurts as it passes, unless Kael is in the air or mid-roll.
		var distance: float = _flat_distance(_player.global_position, global_position)
		if distance >= before - 0.4 and distance < after + 0.4 and not ring.has("hit"):
			ring["hit"] = true
			if _player.is_on_floor():
				_hurt(float(tuning.get("ring_damage", 16.0)))
		if after > arena_radius + 2.0:
			visual.queue_free()
			_rings.remove_at(i)


## Phase 2 onward: the outer ring of the platform is gone; standing there burns.
## While the heart is open the growth draws back, so Kael can reach it.
func _update_edge(delta: float) -> void:
	if phase < 2 or heart_exposed:
		return
	_edge_tick -= delta
	if _edge_tick <= 0.0:
		_edge_tick = 0.5
		if _flat_distance(_player.global_position, global_position) > get_safe_radius():
			_hurt(float(tuning.get("edge_damage_per_tick", 7.0)))


func get_safe_radius() -> float:
	return arena_radius * (float(tuning.get("shrink_factor", 0.72)) if phase >= 2 else 1.0)


func _hurt(amount: float) -> void:
	var hit := HitInfo.new()
	hit.damage = amount
	hit.attacker = self
	hit.origin = global_position
	hit.can_be_blocked = false
	hit.can_be_parried = false
	_player.receive_hit(hit)


# --- Being hit -----------------------------------------------------------------------

## Called by the heart (index -1) and the pillars (0..2) when Kael strikes them.
func on_target_hit(index: int, hit: HitInfo) -> HitInfo.Result:
	if _done or not is_active:
		return HitInfo.Result.IGNORED
	if index >= 0:
		var pillar: ChoirTarget = _pillars[index]
		if phase != 2 or not pillar.visible:
			return HitInfo.Result.IGNORED
		pillar.visible = false
		pillar.process_mode = Node.PROCESS_MODE_DISABLED
		pillars_struck += 1
		AudioManager.play_sfx(StringName("tone_%d" % index), pillar.global_position, 4.0)
		if pillars_struck >= _pillars.size():
			_set_heart(true)
			_expose_time = float(tuning.get("pillar_expose_seconds", 8.0))
		return HitInfo.Result.HIT
	if not heart_exposed:
		return HitInfo.Result.ARMORED
	health = maxf(health - hit.damage * hit.echo_multiplier, 0.0)
	EventBus.boss_health_changed.emit(get_ratio())
	CombatFX.impact(_heart.global_position, Vector3.BACK, true, 18)
	if health <= 0.0:
		_finish()
		return HitInfo.Result.KILLED
	var ratio: float = get_ratio()
	if phase == 1 and ratio <= float(tuning.get("phase_2_at", 0.66)):
		_enter_phase(2)
	elif phase == 2 and ratio <= float(tuning.get("phase_3_at", 0.33)):
		_enter_phase(3)
	return HitInfo.Result.HIT


func _enter_phase(next: int) -> void:
	phase = next
	_set_heart(false)
	_set_count = 0
	_timer = 3.0
	AudioManager.play_ui(&"choir_swell", 0.0, &"SFX")
	CombatFX.shake(0.6)
	if next == 2:
		_show_edge()
		_raise_pillars()
		summon_requested.emit(int(tuning.get("summon_count", 4)))
	else:
		for pillar: ChoirTarget in _pillars:
			pillar.visible = false
			pillar.process_mode = Node.PROCESS_MODE_DISABLED
	phase_changed.emit(next)


func _raise_pillars() -> void:
	pillars_struck = 0
	for pillar: ChoirTarget in _pillars:
		pillar.visible = true
		pillar.process_mode = Node.PROCESS_MODE_INHERIT


func _set_heart(exposed: bool) -> void:
	var was: bool = heart_exposed
	heart_exposed = exposed
	_heart_mesh.scale = Vector3.ONE * (1.5 if exposed else 0.7)
	_heart_light.light_energy = 6.0 if exposed else 0.8
	if exposed and not was:
		AudioManager.play_sfx(&"echo_swell", _heart.global_position, 2.0)
		EventBus.hint_requested.emit("The heart is open. Strike it!", 3.0)
	elif was and not exposed and phase == 2 and not _done:
		_raise_pillars()


func _finish() -> void:
	_done = true
	for entry: Dictionary in _pending:
		if entry.has("visual"):
			(entry["visual"] as Node).queue_free()
	_pending.clear()
	for ring: Dictionary in _rings:
		(ring["visual"] as Node).queue_free()
	_rings.clear()
	EventBus.boss_ended.emit()
	defeated.emit()


## The ending: the body sinks into the dark and its lights die out.
func collapse(seconds: float) -> void:
	var tween: Tween = create_tween().set_parallel()
	for child: Node in get_children():
		var part: Node3D = child as Node3D
		if part == null:
			continue
		var delay: float = randf_range(0.0, seconds * 0.35)
		tween.tween_property(part, "position:y", part.position.y - randf_range(5.0, 9.0), seconds - delay) \
				.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(part, "rotation:z", part.rotation.z + randf_range(-0.5, 0.5), seconds - delay).set_delay(delay)
		for light: Node in part.find_children("*", "Light3D", true, false):
			tween.tween_property(light, "light_energy", 0.0, seconds * 0.8).set_delay(delay)
		if part is Light3D:
			tween.tween_property(part, "light_energy", 0.0, seconds * 0.8)
	AudioManager.play_sfx(&"shockwave", global_position, 4.0)


# --- Visuals -------------------------------------------------------------------------

func _build_body() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 77
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.13, 0.15)
	dark.roughness = 0.45
	dark.metallic = 0.2
	dark.emission_enabled = true
	dark.emission = GrayboxBuilder.COLOR_ECHO
	dark.emission_energy_multiplier = 0.015
	for i: int in 22:
		var lump := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var size: float = random.randf_range(1.6, 4.2)
		sphere.radius = size
		sphere.height = size * random.randf_range(2.0, 3.6)
		sphere.radial_segments = 14
		sphere.rings = 7
		sphere.material = dark
		lump.mesh = sphere
		lump.position = Vector3(random.randf_range(-9.0, 9.0), random.randf_range(2.0, 16.0), -arena_radius - random.randf_range(2.5, 9.0))
		add_child(lump)
	for i: int in 9:
		var mouth: MeshInstance3D = _glow_sphere(random.randf_range(0.25, 0.6), GrayboxBuilder.COLOR_ECHO)
		mouth.position = Vector3(random.randf_range(-7.0, 7.0), random.randf_range(3.0, 13.0), -arena_radius - 1.6)
		add_child(mouth)
	var glow := OmniLight3D.new()
	glow.light_color = GrayboxBuilder.COLOR_ECHO
	glow.light_energy = 3.0
	glow.omni_range = 30.0
	glow.position = Vector3(0.0, 8.0, -arena_radius)
	add_child(glow)


func _glow_sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color * 2.0
	sphere.material = material
	mesh.mesh = sphere
	return mesh


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material


func _disc(at: Vector3, radius: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	mesh.material = _flat_material(Accessibility.cue("choir_telegraph"))
	disc.mesh = mesh
	add_child(disc)
	disc.global_position = at + Vector3.UP * 0.06
	return disc


func _slab(center: Vector3, size: Vector3) -> MeshInstance3D:
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _flat_material(Accessibility.cue("choir_telegraph"))
	slab.mesh = mesh
	add_child(slab)
	slab.global_position = center + Vector3.UP * 0.06
	return slab


func _ring_visual() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 6
	mesh.material = _flat_material(Color(0.3, 0.95, 1.0, 0.7))
	ring.mesh = mesh
	ring.position.y = 0.25
	add_child(ring)
	return ring


func _show_edge() -> void:
	_edge = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = get_safe_radius()
	mesh.outer_radius = arena_radius + 0.5
	mesh.rings = 64
	mesh.ring_segments = 4
	mesh.material = _flat_material(Accessibility.cue("choir_edge"))
	_edge.mesh = mesh
	_edge.scale.y = 0.05
	_edge.position.y = 0.08
	add_child(_edge)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
