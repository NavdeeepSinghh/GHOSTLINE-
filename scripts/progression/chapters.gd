class_name Chapters
extends RefCounted
## Chapter select: once the game has been finished on this computer, any of the
## three acts can be started again from the main menu with a fresh Kael
## carrying what a player would have by then (data/progression/chapters.json).

const DATA_PATH: String = "res://data/progression/chapters.json"
const ORDER: PackedStringArray = ["dead_city", "forest", "facility"]


static func data() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func is_unlocked() -> bool:
	return SettingsManager.get_bool("progress", "game_complete")


## Remembered in the settings file, so it survives new games and deleted saves.
static func mark_game_complete() -> void:
	SettingsManager.set_value("progress", "game_complete", true)


## Resets GameState for a fresh start at the beginning of `area`.
static func apply(area: String) -> void:
	var chapter: Dictionary = data().get(area, {})
	GameState.reset()
	GameState.current_area = area
	var weapons: Dictionary = chapter.get("weapons", {"rebar_pipe": 0})
	GameState.weapons = {}
	for id: String in weapons:
		GameState.weapons[id] = int(weapons[id])
	GameState.equipped_weapon = str(chapter.get("equipped", "rebar_pipe"))
	GameState.salvage = int(chapter.get("salvage", 0))
	GameState.max_health = float(chapter.get("max_health", 100.0))
	GameState.health = GameState.max_health
	GameState.max_stamina = float(chapter.get("max_stamina", 100.0))
