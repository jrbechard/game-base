extends Node
## === Save: reads and writes every State_ resource to one JSON file ===
## Autosaves shortly after any change. The safe-write rule (temp file, backup, fallback)
## lives in Logic_Json_File, shared with the settings file.

const DEFAULT_PATH := "user://save.json"
const FORMAT_VERSION := 1
const AUTOSAVE_DELAY := 0.25  # GUESS: short delay so a burst of changes saves once

var save_path := DEFAULT_PATH
var _states: Dictionary = {}  # StringName -> State_Base
var _timer: Timer

# Why: Main hands in the states, so Save needs no node paths to the managers that own them.
func init(states: Array, path: String = DEFAULT_PATH) -> void:
	save_path = path
	_states.clear()
	for s in states:
		_states[(s as State_Base).save_key()] = s
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(save_now)
		add_child(_timer)
	_timer.wait_time = AUTOSAVE_DELAY
	if not Global_Manager_Events.state_changed.is_connected(_on_state_changed):
		Global_Manager_Events.state_changed.connect(_on_state_changed)
	if not Global_Manager_Events.save_requested.is_connected(save_now):
		Global_Manager_Events.save_requested.connect(save_now)

# === Autosave ===
func _on_state_changed(_state_key: StringName) -> void:
	_timer.start()  # restarts, so many changes in a row become one write

func _notification(what: int) -> void:
	# Why: never lose a change made just before the window closes.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _timer != null and not _timer.is_stopped():
		save_now()

## True when a save file exists (the title menu shows Continue only then).
func save_exists() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")

# === Write ===
func save_now() -> bool:
	if _timer != null:
		_timer.stop()
	var payload := {"version": FORMAT_VERSION, "states": {}}
	for key in _states:
		payload["states"][String(key)] = (_states[key] as State_Base).to_dict()
	if not Logic_Json_File.write_atomic(save_path, payload):
		return false
	Global_Manager_Events.save_completed.emit()
	return true

# === Read ===
## Loads the save, falling back to the backup. Returns false (states untouched) if neither works.
func load_now() -> bool:
	var data := Logic_Json_File.read(save_path, "states")
	if data.is_empty():
		Global_Manager_Events.load_completed.emit(false)
		return false
	var saved: Dictionary = data["states"]
	for key in _states:
		(_states[key] as State_Base).from_dict(saved.get(String(key), {}))
	Global_Manager_Events.load_completed.emit(true)
	return true
