class_name NewGamePlus
extends RefCounted
## New Game+: after the ending, a new run from the rooftop carrying Kael's
## weapons, their upgrades and his salvage, against tougher enemies.
## What carries over is remembered in the settings file (like Chapters), so it
## survives deleted saves. The cycle number lives in the run's own flags.

const DATA_PATH: String = "res://data/progression/new_game_plus.json"
const FLAG: String = "ng_plus"


static func tuning() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## Called when the ending finishes: remembers what the next cycle starts with.
static func record_finish() -> void:
	SettingsManager.set_value("progress", "ng_plus_carry", {
		"weapons": GameState.weapons.duplicate(),
		"equipped": GameState.equipped_weapon,
		"salvage": GameState.salvage,
		"cycle": cycle() + 1,
	})


static func carry() -> Dictionary:
	var value: Variant = SettingsManager.get_value("progress", "ng_plus_carry")
	return value if value is Dictionary else {}


static func is_available() -> bool:
	return not carry().is_empty()


## Which New Game+ cycle the current run is (0 for a first playthrough).
static func cycle() -> int:
	return int(GameState.flags.get(FLAG, 0))


## Resets GameState for a New Game+ start.
static func apply() -> void:
	var saved: Dictionary = carry()
	GameState.reset()
	GameState.current_area = "dead_city"
	GameState.weapons = {}
	var weapons: Dictionary = saved.get("weapons", {"rebar_pipe": 0})
	for id: String in weapons:
		GameState.weapons[id] = int(weapons[id])
	if GameState.weapons.is_empty():
		GameState.weapons = {"rebar_pipe": 0}
	GameState.equipped_weapon = str(saved.get("equipped", "rebar_pipe"))
	if not GameState.weapons.has(GameState.equipped_weapon):
		GameState.equipped_weapon = str(GameState.weapons.keys()[0])
	GameState.salvage = int(saved.get("salvage", 0)) + int(tuning().get("bonus_salvage", 0))
	GameState.set_flag(FLAG, maxi(1, int(saved.get("cycle", 1))))


static func _scaled(per_cycle_key: String) -> float:
	var settings: Dictionary = tuning()
	var steps: int = mini(cycle(), int(settings.get("max_cycles", 3)))
	return 1.0 + float(settings.get(per_cycle_key, 0.0)) * steps


static func enemy_health_scale() -> float:
	return _scaled("enemy_health_per_cycle")


static func enemy_damage_scale() -> float:
	return _scaled("enemy_damage_per_cycle")
