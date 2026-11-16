class_name Logic_Json_File
extends RefCounted
## === Crash-safe JSON files ===
## Shared by the game save and the settings file, so the safe-write rule is written once.
## A write goes to a temp file first, and the previous file is kept as a backup, so a crash
## mid-write cannot destroy what was there. A read falls back to the backup when the main
## file is missing or corrupt.

## Write `data` to `path`. Returns false (with an error) if the file cannot be written.
static func write_atomic(path: String, data: Dictionary) -> bool:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Logic_Json_File: cannot write %s" % tmp_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# Swap: the current file becomes the backup, the temp file becomes the file.
	var bak_path := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		DirAccess.rename_absolute(path, bak_path)
	DirAccess.rename_absolute(tmp_path, path)
	return true

## Read `path`, falling back to its backup. Returns {} if neither is usable. When
## `required_key` is given, a file only counts if it holds a Dictionary under that key.
static func read(path: String, required_key: String = "") -> Dictionary:
	var data := _read_one(path, required_key)
	if data.is_empty():
		data = _read_one(path + ".bak", required_key)
	return data

# Returns {} when the file is missing, unreadable or not valid (warns about the last two).
static func _read_one(path: String, required_key: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# Why: JSON.new().parse() reports a bad file quietly; parse_string logs an engine error.
	var json := JSON.new()
	var parsed: Variant = null
	if json.parse(FileAccess.get_file_as_string(path)) == OK:
		parsed = json.data
	var valid: bool = parsed is Dictionary and (required_key.is_empty() or parsed.get(required_key) is Dictionary)
	if not valid:
		push_warning("Logic_Json_File: %s is not a valid file" % path)
		return {}
	return parsed
