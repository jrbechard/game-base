class_name Shell_Settings
extends Control
## === Settings screen: tabs of rows, with a help line ===
## Modelled on Picross S4's options: L and R switch tabs (Sound, Display, Controls, Data), each row
## is a label with a control on its right (a level bar, a choice, an On/Off button), and a help
## line under the list explains the focused row. The screen only DISPLAYS state and SENDS INTENTS:
## a change goes out as `setting_change_requested` and the settings manager acts on it. Each control
## names its setting with the metadata `setting_key` and its help text with `help` (a translation
## key), so restyling or adding a row in the editor never touches this script. A page is a child of
## `Column/Pages` with the metadata `tab_title` (a translation key) for its tab label.
## The Data tab holds Restore default settings (an intent only the settings manager answers) and
## Delete save data (asks first, then sends `save_reset_requested` and `save_requested`).

## The player asked to leave (Back, or cancel). Global_Manager_Scenes will act on this later.
signal back_requested

const SCENE_PATH := "res://Scenes/Shell/shell_settings.tscn"  # loaded on use: the scene uses this script
const LANGUAGE_NAMES := {&"en": "English", &"fr": "Français"}
const TAB_ON := Color(1, 1, 1, 1)
const TAB_OFF := Color(1, 1, 1, 0.45)

@onready var _nav: Component_Focus_Navigator = $Component_Focus_Navigator
@onready var _tabs: HBoxContainer = $Column/Tabs
@onready var _dots: Label = $Column/Label_Dots
@onready var _help: Label = $Column/Label_Help
@onready var _pages: Control = $Column/Pages
@onready var _actions: Control = $Column/Pages/Page_Data/Actions
@onready var _confirm: Control = $Column/Pages/Page_Data/Confirm

var _controls: Dictionary = {}  # setting key -> the control that edits it
var _syncing := false           # true while the screen updates controls from state
var _tab := 0
var _tab_labels: Array[Label] = []
var _row_normal: StyleBoxFlat
var _row_selected: StyleBoxFlat

func _ready() -> void:
	_make_row_styles()
	_collect_controls(self)
	_style_rows(self)
	for key in _controls:
		var control: Control = _controls[key]
		if control is Range:
			(control as Range).value_changed.connect(_on_slider_changed.bind(key))
		elif _is_toggle(control):
			(control as BaseButton).toggled.connect(_on_toggled.bind(key))
	_build_tabs()
	_nav.activated.connect(_on_activated)
	_nav.adjusted.connect(_on_adjusted)
	_nav.focus_changed.connect(_on_focus_changed)
	_nav.cancelled.connect(_on_cancelled)
	Global_Manager_Events.setting_changed.connect(_on_setting_changed)
	for key in _controls:
		_show(key, Global_Manager_Settings.get_value(key))
	_show_tab(0, false)
	await get_tree().process_frame
	_focus_page_start()

func _process(_delta: float) -> void:
	# Why: L and R are the pad's undo and redo actions; here they switch tabs instead.
	if not is_visible_in_tree() or _confirm.visible or Global_Manager_Input.source == null:
		return
	if Global_Manager_Input.source.just_pressed(&"undo"):
		step_tab(-1)
	elif Global_Manager_Input.source.just_pressed(&"redo"):
		step_tab(1)

func _collect_controls(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.has_meta(&"setting_key"):
			_controls[child.get_meta(&"setting_key")] = child
		_collect_controls(child)

# === Tabs ===
func _build_tabs() -> void:
	for i in _pages.get_child_count():
		var label := Label.new()
		label.text = _pages.get_child(i).get_meta(&"tab_title", "")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_tab(i, true))
		_tabs.add_child(label)
		_tab_labels.append(label)

## Move to the next (+1) or previous (-1) tab, stopping at the ends.
func step_tab(direction: int) -> void:
	var next := clampi(_tab + direction, 0, _pages.get_child_count() - 1)
	if next != _tab:
		_show_tab(next, true)
		Global_Manager_Events.menu_navigated.emit()

func current_tab() -> int:
	return _tab

func _show_tab(index: int, focus := true) -> void:
	_tab = index
	_close_confirm()
	for i in _pages.get_child_count():
		(_pages.get_child(i) as Control).visible = i == index
		_tab_labels[i].modulate = TAB_ON if i == index else TAB_OFF
	var dots := ""
	for i in _pages.get_child_count():
		dots += ("◆ " if i == index else "◇ ")
	_dots.text = dots.strip_edges()
	if focus:
		_focus_page_start()

func _focus_page_start() -> void:
	var page := _pages.get_child(_tab) as Control
	for control in page.find_children("*", "Control", true, false):
		if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
			control.grab_focus()
			return

# === Rows ===
func _make_row_styles() -> void:
	_row_normal = StyleBoxFlat.new()
	_row_normal.bg_color = Color(0.16, 0.17, 0.23)
	_row_normal.set_corner_radius_all(6)
	_row_normal.set_content_margin_all(8)
	_row_selected = _row_normal.duplicate()
	_row_selected.bg_color = Color(0.2, 0.26, 0.4)
	_row_selected.set_border_width_all(2)
	_row_selected.border_color = Color(0.35, 0.6, 1.0)

# Every PanelContainer called Row_* gets the plain look; the focused one gets the selected look.
func _style_rows(node: Node) -> void:
	for child in node.get_children():
		if child is PanelContainer and String(child.name).begins_with("Row_"):
			(child as PanelContainer).add_theme_stylebox_override("panel", _row_normal)
		_style_rows(child)

func _on_focus_changed(control: Control) -> void:
	_help.text = control.get_meta(&"help", "")
	_mark_selected_row(control)

func _mark_selected_row(control: Control) -> void:
	for row in find_children("Row_*", "PanelContainer", true, false):
		(row as PanelContainer).add_theme_stylebox_override("panel", _row_selected if row.is_ancestor_of(control) else _row_normal)

func _on_cancelled() -> void:
	if _confirm.visible:
		_close_confirm()
		_focus_page_start()
	else:
		back_requested.emit()

# === Delete save data: asks first ===
func _open_confirm() -> void:
	_actions.visible = false
	_confirm.visible = true
	($Column/Pages/Page_Data/Confirm/Button_No as Control).grab_focus()

func _close_confirm() -> void:
	_confirm.visible = false
	_actions.visible = true

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
	match control.get_meta(&"action", &""):
		&"back":
			back_requested.emit()
			return
		&"restore":
			Global_Manager_Events.settings_reset_requested.emit()
			return
		&"delete":
			_open_confirm()
			return
		&"delete_no":
			_close_confirm()
			_focus_page_start()
			return
		&"delete_yes":
			Global_Manager_Events.save_reset_requested.emit()
			Global_Manager_Events.save_requested.emit()
			_close_confirm()
			_focus_page_start()
			return
	if control.get_meta(&"setting_key", &"") == &"language":
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

## Open the settings screen on top of `parent` (a Control), with a plain backdrop so the screen
## underneath does not show through. `on_close` runs after Back, once the settings are gone.
## Used by every screen that offers Settings (title, pause, puzzle pause).
static func open_over(parent: Control, on_close: Callable) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.1, 0.11, 0.16, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(backdrop)
	var settings: Shell_Settings = (load(SCENE_PATH) as PackedScene).instantiate()
	parent.add_child(settings)
	settings.back_requested.connect(func() -> void:
		settings.queue_free()
		backdrop.queue_free()
		on_close.call())
