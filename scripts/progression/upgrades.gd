class_name Upgrades
extends RefCounted
## Weapon upgrade tiers bought at workbenches with salvage. Tiers live in
## data/progression/upgrades.json; owned tiers live in GameState.weapons.

const DATA_PATH: String = "res://data/progression/upgrades.json"
const MAX_TIER: int = 3

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func tier(weapon_id: String) -> int:
	return clampi(int(GameState.weapons.get(weapon_id, 0)), 0, MAX_TIER)


static func _tier_entry(weapon_id: String, at_tier: int) -> Dictionary:
	var tiers: Array = (data().get(weapon_id, {}) as Dictionary).get("tiers", [])
	if at_tier <= 0 or at_tier > tiers.size():
		return {}
	return tiers[at_tier - 1]


static func damage_multiplier(weapon_id: String) -> float:
	return float(_tier_entry(weapon_id, tier(weapon_id)).get("damage", 1.0))


static func stamina_multiplier(weapon_id: String) -> float:
	return float(_tier_entry(weapon_id, tier(weapon_id)).get("stamina", 1.0))


## Tier 3 special property value, or 0 when the weapon does not have it yet.
static func special(weapon_id: String, key: String) -> float:
	return float((_tier_entry(weapon_id, tier(weapon_id)).get("special", {}) as Dictionary).get(key, 0.0))


## Salvage needed for the next tier; -1 when fully upgraded.
static func next_cost(weapon_id: String) -> int:
	var entry: Dictionary = _tier_entry(weapon_id, tier(weapon_id) + 1)
	return int(entry.get("cost", -1)) if not entry.is_empty() else -1


static func next_label(weapon_id: String) -> String:
	return str(_tier_entry(weapon_id, tier(weapon_id) + 1).get("label", "Fully upgraded"))


static func can_purchase(weapon_id: String) -> bool:
	var cost: int = next_cost(weapon_id)
	return GameState.weapons.has(weapon_id) and cost >= 0 and GameState.salvage >= cost


## Spends salvage and raises the weapon one tier. False if it cannot be bought.
static func purchase(weapon_id: String) -> bool:
	if not can_purchase(weapon_id):
		return false
	GameState.salvage -= next_cost(weapon_id)
	GameState.weapons[weapon_id] = tier(weapon_id) + 1
	return true


static func core_bonus(key: String) -> float:
	return float((data().get("cores", {}) as Dictionary).get(key, 0.0))
