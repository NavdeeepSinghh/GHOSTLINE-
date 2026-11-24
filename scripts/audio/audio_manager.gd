extends Node
## Creates the audio bus layout and plays one-shot sound effects.
##
## Milestone 2 adds combat sound effects (synthesized, see tools/assets/make_sfx.py).
## Milestone 3 adds looping ambience layers (rain, wind, city drone, tunnels) and
## footsteps. Music and reverb zones are Milestone 6.

const BUSES: PackedStringArray = ["Music", "SFX", "Ambience", "Dialogue", "UI"]
const SFX_DIR: String = "res://assets/audio/sfx/"
const AMBIENCE_DIR: String = "res://assets/audio/ambience/"
const SILENT_DB: float = -60.0
const MAX_VOICES: int = 20

var _streams: Dictionary = {}
var _voices: int = 0
## layer name -> AudioStreamPlayer
var _layers: Dictionary = {}
## layer name -> target volume in dB
var _layer_targets: Dictionary = {}


func _ready() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


## Plays a sound at a world position. `pitch_spread` randomizes pitch a little
## so repeated hits do not sound identical.
func play_sfx(sound: StringName, position: Vector3, volume_db: float = 0.0, pitch_spread: float = 0.08) -> void:
	var stream: AudioStream = _get_stream(sound)
	if stream == null or _voices >= MAX_VOICES:
		return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.bus = &"SFX"
	voice.volume_db = volume_db
	voice.unit_size = 6.0
	voice.max_distance = 45.0
	voice.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	add_child(voice)
	voice.global_position = position
	_voices += 1
	voice.finished.connect(_on_voice_finished.bind(voice))
	voice.play()


## Plays a sound with no position (interface clicks, radio, story stings).
func play_ui(sound: StringName, volume_db: float = 0.0, bus: StringName = &"UI") -> void:
	var stream: AudioStream = _get_stream(sound)
	if stream == null:
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.bus = bus
	voice.volume_db = volume_db
	voice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()


## Starts (or retargets) a looping ambience layer and fades it to `volume_db`.
func set_ambience(layer: StringName, sound: StringName, volume_db: float) -> void:
	if not _layers.has(layer):
		var stream: AudioStream = load_loop(sound)
		if stream == null:
			return
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = &"Ambience"
		player.volume_db = SILENT_DB
		add_child(player)
		player.play()
		_layers[layer] = player
	_layer_targets[layer] = volume_db


## Stops and removes every ambience layer (when leaving a level).
func clear_ambience() -> void:
	for layer: StringName in _layers:
		var player: AudioStreamPlayer = _layers[layer]
		if is_instance_valid(player):
			player.stop()
			player.free()
	_layers.clear()
	_layer_targets.clear()


## Silences everything this manager is playing (before the game exits).
func stop_all() -> void:
	clear_ambience()
	var music: Node = get_node_or_null(^"/root/MusicDirector")
	if music != null:
		music.call(&"stop")
	for child: Node in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.call(&"stop")
			child.queue_free()
	_voices = 0


func get_ambience_volume(layer: StringName) -> float:
	return (_layers[layer] as AudioStreamPlayer).volume_db if _layers.has(layer) else SILENT_DB


## A looping stream from assets/audio/ambience (loop points set to the whole clip).
func load_loop(sound: StringName) -> AudioStream:
	var path: String = AMBIENCE_DIR + String(sound) + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStreamWAV = load(path) as AudioStreamWAV
	if stream != null and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func _process(delta: float) -> void:
	for layer: StringName in _layers:
		var player: AudioStreamPlayer = _layers[layer]
		player.volume_db = move_toward(player.volume_db, float(_layer_targets[layer]), 30.0 * delta)


func has_sfx(sound: StringName) -> bool:
	return _get_stream(sound) != null


func _get_stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		var path: String = SFX_DIR + String(sound) + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


func _on_voice_finished(voice: AudioStreamPlayer3D) -> void:
	_voices -= 1
	voice.queue_free()
