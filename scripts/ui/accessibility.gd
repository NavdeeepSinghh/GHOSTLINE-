class_name Accessibility
extends RefCounted
## Read-only helpers for the Accessibility settings, used by the systems they
## change: danger-cue colours (data/ui_palette.json) and reduced flashing.

const PALETTE_PATH: String = "res://data/ui_palette.json"

static var _palette: Dictionary = {}


static func reduce_flashing() -> bool:
	return SettingsManager.get_bool("accessibility", "reduce_flashing")


static func high_contrast() -> bool:
	return SettingsManager.get_bool("accessibility", "high_contrast_cues")


## The colour for a danger cue ("telegraph", "sentinel_alert", "choir_telegraph", "choir_edge").
static func cue(name: String) -> Color:
	if _palette.is_empty():
		var file := FileAccess.open(PALETTE_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_palette = parsed
	var set_name: String = "high_contrast" if high_contrast() else "standard"
	var values: Array = (_palette.get(set_name, {}) as Dictionary).get(name, [1.0, 0.0, 1.0, 1.0])
	return Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
