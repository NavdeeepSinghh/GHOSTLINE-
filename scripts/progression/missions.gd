class_name Missions
extends RefCounted
## Mission select: start any objective of any act directly (main menu >
## Missions). A mission is built like a save: GameState gets the loadout, the
## flags earlier missions would have set and a level state that puts the area
## at that objective with Kael at its checkpoint; the level then restores it
## exactly as it restores a loaded game. Mission runs do not write saves.

const DATA_PATH: String = "res://data/progression/missions.json"
const PREFIXES: Dictionary = {"dead_city": "dc", "forest": "ff", "facility": "uf"}
const ACT_NAMES: Dictionary = {"dead_city": "Act 1  ·  The Dead City", "forest": "Act 2  ·  The Forgotten Forest", "facility": "Act 3  ·  The Underground Facility"}


static func data() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## [area, mission] for a mission id, or [] if there is none.
static func find(id: String) -> Array:
	var all: Dictionary = data()
	for area: String in Chapters.ORDER:
		for mission: Dictionary in all.get(area, []):
			if str(mission.get("id", "")) == id:
				return [area, mission]
	return []


## Prepares GameState for a mission. Returns false for an unknown id.
static func apply(id: String) -> bool:
	var found: Array = find(id)
	if found.is_empty():
		return false
	var area: String = found[0]
	var mission: Dictionary = found[1]
	Chapters.apply(area)
	var weapons: Variant = mission.get("weapons")
	if weapons is Dictionary:
		GameState.weapons = {}
		for weapon: String in weapons:
			GameState.weapons[weapon] = int(weapons[weapon])
		GameState.equipped_weapon = "fire_axe" if GameState.weapons.has("fire_axe") else "rebar_pipe"
	for flag: Variant in mission.get("flags", []):
		GameState.set_flag(str(flag))
	var spawn: Array = mission.get("spawn", [])
	var state: Dictionary = {
		"stage": int(mission.get("stage", 0)),
		"spawn": spawn,
		"taken": mission.get("taken", []),
		"hints": [],
		"zones": [],
	}
	var extra: Variant = mission.get("state")
	if extra is Dictionary:
		state.merge(extra, true)
	GameState.set_level_state(str(PREFIXES[area]), state)
	GameState.current_area = area
	GameState.checkpoint_id = "mission_" + id
	return true
