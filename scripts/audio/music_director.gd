extends Node
## Adaptive music. Each area has four layers of one loop (assets/audio/music/
## <area>_<layer>.wav): explore, tension, combat and boss. All four play in
## sync from the start; the director only changes their volumes, crossfading
## as the situation changes:
##   explore  nothing is after Kael
##   tension  an enemy is suspicious, investigating or searching
##   combat   at least one enemy is engaged with him
##   boss     between EventBus.boss_started and boss_ended
##   silent   while a cinematic plays (outside boss fights)
## Levels live in data/audio_mix.json.

const MUSIC_DIR: String = "res://assets/audio/music/"
const MIX_PATH: String = "res://data/audio_mix.json"
const LAYERS: PackedStringArray = ["explore", "tension", "combat", "boss"]
const SILENT_DB: float = -60.0

var area: String = ""
var state: String = "explore"
var mix: Dictionary = {}

var _players: Dictionary = {}
var _boss_active: bool = false
var _cinematic: bool = false
var _check: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mix = load_mix()
	EventBus.boss_started.connect(func(_name: String) -> void: _boss_active = true)
	EventBus.boss_ended.connect(func() -> void: _boss_active = false)
	EventBus.cinematic_changed.connect(_on_cinematic_changed)


func _on_cinematic_changed(playing: bool) -> void:
	_cinematic = playing
	# Ambience steps back under cinematic dialogue.
	SettingsManager.set_bus_offset("ambience", float(mix.get("cinematic_ambience_duck_db", -6.0)) if playing else 0.0)


static func load_mix() -> Dictionary:
	var file := FileAccess.open(MIX_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## Starts an area's music from the top (all layers together). "" stops it.
func set_area(new_area: String) -> void:
	stop()
	area = new_area
	_boss_active = false
	_cinematic = false
	state = "explore"
	if new_area.is_empty():
		return
	for layer: String in LAYERS:
		var path: String = "%s%s_%s.wav" % [MUSIC_DIR, new_area, layer]
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStreamWAV = load(path) as AudioStreamWAV
		if stream == null:
			continue
		if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = &"Music"
		player.volume_db = target_db(state, layer)
		add_child(player)
		_players[layer] = player
	# Started in one go so the layers stay locked together.
	for layer: String in _players:
		(_players[layer] as AudioStreamPlayer).play()


func stop() -> void:
	if _cinematic:
		_on_cinematic_changed(false)
	for layer: String in _players:
		var player: AudioStreamPlayer = _players[layer]
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_players.clear()
	area = ""


func is_playing() -> bool:
	for layer: String in _players:
		if (_players[layer] as AudioStreamPlayer).playing:
			return true
	return false


func layer_count() -> int:
	return _players.size()


func layer_volume(layer: String) -> float:
	return (_players[layer] as AudioStreamPlayer).volume_db if _players.has(layer) else SILENT_DB


## The music state for a situation. Pure, so tests can drive it directly.
static func choose_state(cinematic: bool, boss: bool, engaged: int, suspicious: bool) -> String:
	# A boss fight keeps its music through the short camera moments inside it.
	if boss:
		return "boss"
	if cinematic:
		return "silent"
	if engaged > 0:
		return "combat"
	if suspicious:
		return "tension"
	return "explore"


func target_db(for_state: String, layer: String) -> float:
	var states: Dictionary = mix.get("states", {})
	var levels: Dictionary = states.get(for_state, states.get("explore", {}))
	return float(levels.get(layer, SILENT_DB)) + float(mix.get("master_music_db", 0.0))


func _any_enemy_suspicious() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.is_dead() or enemy.is_asleep():
			continue
		if enemy.state in [Enemy.AIState.SUSPICIOUS, Enemy.AIState.INVESTIGATE, Enemy.AIState.SEARCH]:
			return true
	return false


func _process(delta: float) -> void:
	if _players.is_empty():
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.25
		state = choose_state(_cinematic, _boss_active, CombatDirector.engaged_count(), _any_enemy_suspicious())
	# Crossfade in linear amplitude so a fade sounds even.
	var rate: float = delta / maxf(float(mix.get("crossfade_seconds", 1.5)), 0.05)
	for layer: String in _players:
		var player: AudioStreamPlayer = _players[layer]
		var now: float = db_to_linear(player.volume_db)
		var goal: float = db_to_linear(target_db(state, layer))
		player.volume_db = linear_to_db(maxf(move_toward(now, goal, rate), 0.00001))
