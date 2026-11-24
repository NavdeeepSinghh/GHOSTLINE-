extends Node
## Run-time game data that a save file captures: player stats, inventory,
## world flags and progress. Systems read and write it; SaveManager serializes it.

const SAVE_VERSION: int = 3

var current_area: String = "proving_ground"
var checkpoint_id: String = ""
var max_health: float = 100.0
var health: float = 100.0
var max_stamina: float = 100.0
var injectors: int = 3
var throwables: int = 3
var salvage: int = 0
var playtime_seconds: float = 0.0
## weapon id -> upgrade tier
var weapons: Dictionary = {"rebar_pipe": 0}
var equipped_weapon: String = "rebar_pipe"
## ids of collected documents, opened shortcuts, solved puzzles, defeated bosses…
var flags: Dictionary = {}
var collected_documents: Array[String] = []
## Free-form state owned by each area, keyed by the area's prefix (story stage, taken pickups, respawn point).
var level_states: Dictionary = {}
## Where Kael stood when the game was saved: [area, x, y, z, yaw], or empty when
## the save was made somewhere unsafe (then loading uses the last checkpoint).
var resume_point: Array = []


func _process(delta: float) -> void:
	if not get_tree().paused:
		playtime_seconds += delta


func reset() -> void:
	current_area = "proving_ground"
	checkpoint_id = ""
	max_health = 100.0
	health = 100.0
	max_stamina = 100.0
	injectors = 3
	throwables = 3
	salvage = 0
	playtime_seconds = 0.0
	weapons = {"rebar_pipe": 0}
	equipped_weapon = "rebar_pipe"
	flags = {}
	collected_documents = []
	level_states = {}
	resume_point = []


func get_level_state(prefix: String) -> Dictionary:
	return level_states.get(prefix, {})


func set_level_state(prefix: String, state: Dictionary) -> void:
	level_states[prefix] = state


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"current_area": current_area,
		"checkpoint_id": checkpoint_id,
		"max_health": max_health,
		"health": health,
		"max_stamina": max_stamina,
		"injectors": injectors,
		"throwables": throwables,
		"salvage": salvage,
		"playtime_seconds": playtime_seconds,
		"weapons": weapons.duplicate(true),
		"equipped_weapon": equipped_weapon,
		"flags": flags.duplicate(true),
		"collected_documents": collected_documents.duplicate(),
		"level_states": level_states.duplicate(true),
		"resume_point": resume_point.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	current_area = str(data.get("current_area", current_area))
	checkpoint_id = str(data.get("checkpoint_id", checkpoint_id))
	max_health = float(data.get("max_health", max_health))
	health = float(data.get("health", health))
	max_stamina = float(data.get("max_stamina", max_stamina))
	injectors = int(data.get("injectors", injectors))
	throwables = int(data.get("throwables", throwables))
	var saved_levels: Variant = data.get("level_states", {})
	if saved_levels is Dictionary:
		level_states = (saved_levels as Dictionary).duplicate(true)
	salvage = int(data.get("salvage", salvage))
	var saved_resume: Variant = data.get("resume_point", [])
	if saved_resume is Array and (saved_resume as Array).size() == 5:
		resume_point = (saved_resume as Array).duplicate()
	playtime_seconds = float(data.get("playtime_seconds", playtime_seconds))
	equipped_weapon = str(data.get("equipped_weapon", equipped_weapon))
	var saved_weapons: Variant = data.get("weapons", {})
	if saved_weapons is Dictionary:
		weapons = {}
		for weapon_id: String in saved_weapons:
			weapons[weapon_id] = int(saved_weapons[weapon_id])
	var saved_flags: Variant = data.get("flags", {})
	if saved_flags is Dictionary:
		flags = (saved_flags as Dictionary).duplicate(true)
	collected_documents = []
	for document_id: Variant in data.get("collected_documents", []):
		collected_documents.append(str(document_id))
