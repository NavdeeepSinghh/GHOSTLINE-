extends Node
## The game was called The Last Echo until 1.4.1, and kept its saves, settings,
## benchmarks and photos in a "TheLastEcho" data folder. On the first launch as
## Ghostline this copies that folder into the new one, so nothing is lost. It
## runs before every other autoload and never touches the old folder.

const OLD_FOLDER: String = "TheLastEcho"

var copied: int = 0


func _init() -> void:
	var new_root: String = ProjectSettings.globalize_path("user://").trim_suffix("/")
	copied = migrate(OS.get_data_dir().path_join(OLD_FOLDER), new_root)
	if copied > 0:
		print("Ghostline: carried over %d files from %s" % [copied, OLD_FOLDER])


## Copies everything under `old_root` into `new_root` when the new folder has no
## settings yet. Returns the number of files copied.
static func migrate(old_root: String, new_root: String) -> int:
	if old_root == new_root or not DirAccess.dir_exists_absolute(old_root):
		return 0
	if FileAccess.file_exists(new_root.path_join("settings.cfg")):
		return 0
	return _copy_tree(old_root, new_root)


static func _copy_tree(from: String, to: String) -> int:
	DirAccess.make_dir_recursive_absolute(to)
	var count: int = 0
	var dir: DirAccess = DirAccess.open(from)
	if dir == null:
		return 0
	for file: String in dir.get_files():
		var target: String = to.path_join(file)
		if not FileAccess.file_exists(target) and DirAccess.copy_absolute(from.path_join(file), target) == OK:
			count += 1
	for folder: String in dir.get_directories():
		count += _copy_tree(from.path_join(folder), to.path_join(folder))
	return count
