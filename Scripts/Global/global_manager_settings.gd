extends Node
## === Settings: the one writer of State_Settings ===
## A screen sends `setting_change_requested`; this validates it, writes the state, applies
## what it owns (audio bus volumes, language, reduce motion), announces `setting_changed`
## (rumble strength is applied by the rumble manager listening to that), and autosaves to
## its own file. Pogne's version hard-coded bus numbers and an absolute node path; this one
## uses bus names and the bus.

const DEFAULT_PATH := "user://settings.json"
const FORMAT_VERSION := 1
const AUTOSAVE_DELAY := 0.25  # GUESS: short delay so dragging a slider saves once

## Setting key -> the audio bus it controls.
const VOLUME_BUSES := {
	&"volume_master": Logic_Audio_Buses.MASTER,
	&"volume_music": Logic_Audio_Buses.MUSIC,
	&"volume_sfx": Logic_Audio_Buses.SFX,
	&"volume_ambience": Logic_Audio_Buses.AMBIENCE,
	&"volume_ui": Logic_Audio_Buses.UI,
}

var state := State_Settings.new()
var save_path := DEFAULT_PATH

var _timer: Timer
var _dirty := false

func init(path: String = DEFAULT_PATH) -> void:
	save_path = path
	Logic_Audio_Buses.ensure_buses()
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(save_now)
		add_child(_timer)
	_timer.wait_time = AUTOSAVE_DELAY
	_timer.stop()
	_dirty = false
	if not Global_Manager_Events.setting_change_requested.is_connected(_on_change_requested):
		Global_Manager_Events.setting_change_requested.connect(_on_change_requested)
	if not Global_Manager_Events.settings_reset_requested.is_connected(reset_to_defaults):
		Global_Manager_Events.settings_reset_requested.connect(reset_to_defaults)
	var saved := Logic_Json_File.read(path, "settings")
	state.reset()
	if not saved.is_empty():
		state.from_dict(saved["settings"])
	# Apply and announce every setting, so the game starts exactly as the player left it.
	for key in state.values:
		_apply(key, state.values[key])
		Global_Manager_Events.setting_changed.emit(key, state.values[key])

# === Read ===
func get_value(key: StringName) -> Variant:
	if not state.values.has(key):
		push_warning("Settings: unknown setting '%s'" % key)
		return null
	return state.values[key]

# === Write ===
## Change one setting. Returns false if the value was invalid or unchanged.
func set_value(key: StringName, value: Variant) -> bool:
	var clean: Variant = State_Settings.sanitize(key, value)
	if clean == null:
		push_warning("Settings: '%s' is not a valid value for '%s'" % [str(value), key])
		return false
	if clean == state.values[key]:
		return false
	state.values[key] = clean
	_apply(key, clean)
	Global_Manager_Events.setting_changed.emit(key, clean)
	_dirty = true
	_timer.start()  # restarts, so a slider drag becomes one write
	return true

func _on_change_requested(key: StringName, value: Variant) -> void:
	set_value(key, value)

## Every setting back to its default, each one announced so screens and audio follow.
func reset_to_defaults() -> void:
	for key in State_Settings.DEFAULTS:
		set_value(key, State_Settings.DEFAULTS[key])

# What this manager owns. Rumble strength is applied by the rumble manager from the event.
func _apply(key: StringName, value: Variant) -> void:
	if VOLUME_BUSES.has(key):
		Logic_Audio_Buses.set_volume(VOLUME_BUSES[key], value)
	elif key == &"language":
		TranslationServer.set_locale(String(value))
	elif key == &"reduce_motion":
		UI_Animator.motion_scale = 0.0 if value else 1.0

# === Save ===
func save_now() -> bool:
	_timer.stop()
	_dirty = false
	return Logic_Json_File.write_atomic(save_path, {"version": FORMAT_VERSION, "settings": state.to_dict()})

# Why: a change made just before quitting must not be lost, whether the window is closed
# or the game calls quit() itself.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _dirty:
		save_now()

func _exit_tree() -> void:
	if _dirty:
		save_now()
