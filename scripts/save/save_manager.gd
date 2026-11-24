extends Node
## Writes and reads save files as versioned JSON in user://saves/.
##
## Writes are atomic: data goes to a temp file, the previous save becomes a
## .bak, then the temp file is renamed into place. A crash mid-write can never
## leave a half-written save, and a corrupt save falls back to its backup.
##
## Autosave happens at every checkpoint and workbench (Game does it); the
## pause menu writes the three manual slots; Continue loads the newest save.

signal saved(slot: String)
signal loaded(slot: String)

const SAVE_DIR: String = "user://saves"
const AUTOSAVE_SLOT: String = "autosave"
const MANUAL_SLOTS: PackedStringArray = ["slot1", "slot2", "slot3"]

## Tests point this at a scratch directory.
var save_dir: String = SAVE_DIR


func save_game(slot: String = AUTOSAVE_SLOT) -> Error:
	var data: Dictionary = GameState.to_dict()
	data["saved_at_unix"] = int(Time.get_unix_time_from_system())
	var error: Error = write_slot(slot, data)
	if error == OK:
		saved.emit(slot)
	return error


func load_game(slot: String = AUTOSAVE_SLOT) -> Error:
	var data: Dictionary = read_slot(slot)
	if data.is_empty():
		return ERR_FILE_NOT_FOUND
	GameState.from_dict(_migrate(data))
	loaded.emit(slot)
	return OK


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot)) or FileAccess.file_exists(_slot_path(slot) + ".bak")


## Slot name of the newest save on disk, or "" when there is none (drives Continue).
func get_most_recent_slot() -> String:
	var newest_slot: String = ""
	var newest_time: int = -1
	var slots: PackedStringArray = MANUAL_SLOTS.duplicate()
	slots.append(AUTOSAVE_SLOT)
	for slot: String in slots:
		var data: Dictionary = read_slot(slot)
		if data.is_empty():
			continue
		var saved_at: int = int(data.get("saved_at_unix", 0))
		if saved_at > newest_time:
			newest_time = saved_at
			newest_slot = slot
	return newest_slot


func write_slot(slot: String, data: Dictionary) -> Error:
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(save_dir)
	if dir_error != OK:
		return dir_error
	var final_path: String = _slot_path(slot)
	var temp_path: String = final_path + ".tmp"
	var backup_path: String = final_path + ".bak"

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	if FileAccess.file_exists(final_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		DirAccess.rename_absolute(final_path, backup_path)
	return DirAccess.rename_absolute(temp_path, final_path)


## Returns the parsed save, falling back to the backup; {} when nothing readable exists.
func read_slot(slot: String) -> Dictionary:
	for path: String in [_slot_path(slot), _slot_path(slot) + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		# JSON.parse (unlike JSON.parse_string) reports bad data without logging an engine error.
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary and (json.data as Dictionary).has("version"):
			return json.data
		push_warning("Save file unreadable, trying backup: %s" % path)
	return {}


## One line describing a slot for menus: area, playtime, when it was saved. "" if empty.
func describe_slot(slot: String) -> String:
	var data: Dictionary = read_slot(slot)
	if data.is_empty():
		return ""
	var seconds: int = int(data.get("playtime_seconds", 0.0))
	var when: String = Time.get_datetime_string_from_unix_time(int(data.get("saved_at_unix", 0)), true)
	return "%s  ·  %d:%02d played  ·  %s UTC" % [str(data.get("current_area", "")).capitalize(), seconds / 60, seconds % 60, when.left(16)]


func delete_slot(slot: String) -> void:
	for path: String in [_slot_path(slot), _slot_path(slot) + ".bak", _slot_path(slot) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Upgrades old save data step by step to the current version.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	if version < 2:
		# Version 2 (Milestone 4) added bottles carried and per-level state.
		data["throwables"] = int(data.get("throwables", 3))
		if not data.has("level_state"):
			data["level_state"] = {}
		version = 2
	if version < 3:
		# Version 3 (Milestone 5) keeps one state dictionary per area.
		var old_state: Variant = data.get("level_state", {})
		data["level_states"] = {"dc": old_state} if old_state is Dictionary and not (old_state as Dictionary).is_empty() else {}
		data.erase("level_state")
		version = 3
	data["version"] = maxi(version, GameState.SAVE_VERSION)
	return data


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [save_dir, slot]
