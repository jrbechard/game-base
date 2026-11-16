class_name Shell_Settings
extends Control
## === Settings screen ===
## Sliders for the volumes and the rumble strength, a language chooser, a reduce-motion
## toggle, and Back. The screen only DISPLAYS state and SENDS INTENTS: a change goes out as
## `setting_change_requested` and the settings manager acts on it. Each control names the
## setting it edits with the metadata `setting_key`, so restyling the scene in the editor
## never touches this script.

## The player asked to leave (Back, or cancel). Global_Manager_Scenes will act on this later.
signal back_requested

const LANGUAGE_NAMES := {&"en": "English", &"fr": "Français"}

@onready var _nav: Component_Focus_Navigator = $Component_Focus_Navigator

var _controls: Dictionary = {}  # setting key -> the control that edits it
var _syncing := false           # true while the screen updates controls from state

func _ready() -> void:
	_collect_controls(self)
	for key in _controls:
		var control: Control = _controls[key]
		if control is Range:
			(control as Range).value_changed.connect(_on_slider_changed.bind(key))
		elif _is_toggle(control):
			(control as BaseButton).toggled.connect(_on_toggled.bind(key))
	_nav.activated.connect(_on_activated)
	_nav.adjusted.connect(_on_adjusted)
	_nav.cancelled.connect(func() -> void: back_requested.emit())
	Global_Manager_Events.setting_changed.connect(_on_setting_changed)
	for key in _controls:
		_show(key, Global_Manager_Settings.get_value(key))
	await get_tree().process_frame
	_nav.focus_default()

func _collect_controls(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta(&"setting_key"):
			_controls[child.get_meta(&"setting_key")] = child
		_collect_controls(child)

# === Intents out ===
func _request(key: StringName, value: Variant) -> void:
	Global_Manager_Events.setting_change_requested.emit(key, value)

func _on_slider_changed(value: float, key: StringName) -> void:
	if _syncing:
		return
	_request(key, value)
	if key == &"rumble_scale":
		# The change is applied synchronously above, so the sample buzz is at the new strength.
		Global_Manager_Events.rumble_preview_requested.emit()

func _on_toggled(pressed: bool, key: StringName) -> void:
	if not _syncing:
		_request(key, pressed)

func _on_activated(control: Control) -> void:
	if control.get_meta(&"action", &"") == &"back":
		back_requested.emit()
	elif control.get_meta(&"setting_key", &"") == &"language":
		_cycle_language(1)
	elif _is_toggle(control):
		# Why: a mouse click already flips a toggle button natively; keyboard and pad do not,
		# because the input router consumes the confirm key.
		if Global_Manager_Input.device_mode != Global_Manager_Input.DeviceMode.MOUSE:
			(control as BaseButton).button_pressed = not (control as BaseButton).button_pressed

func _on_adjusted(control: Control, direction: int) -> void:
	if control.get_meta(&"setting_key", &"") == &"language":
		_cycle_language(direction)

func _cycle_language(direction: int) -> void:
	var languages := State_Settings.LOCALES
	var index := languages.find(Global_Manager_Settings.get_value(&"language"))
	_request(&"language", languages[(index + direction + languages.size()) % languages.size()])

# === State in ===
func _on_setting_changed(key: StringName, value: Variant) -> void:
	_show(key, value)

func _show(key: StringName, value: Variant) -> void:
	if not _controls.has(key):
		return
	_syncing = true
	var control: Control = _controls[key]
	if control is Range:
		(control as Range).value = value
	elif _is_toggle(control):
		(control as BaseButton).button_pressed = value
		# The text is a translation key, so it follows the language by itself.
		(control as BaseButton).text = "ui_on" if value else "ui_off"
	elif key == &"language":
		(control as Button).text = LANGUAGE_NAMES.get(value, String(value))
	_syncing = false

# A button that stays pressed (on) or released (off): the reduce-motion switch.
func _is_toggle(control: Control) -> bool:
	return control is BaseButton and (control as BaseButton).toggle_mode
