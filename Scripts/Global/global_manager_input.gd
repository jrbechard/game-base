extends Node
## === Input router: raw device events -> logical menu actions, announced on the bus ===
## Ported from Ever Blue / Pogne with these changes: the stick follows the LAST-USED pad
## (not pad 0), nothing here calls a menu or plays a sound (it announces on the bus),
## and gameplay reads one Input_Source chosen by device mode.

enum DeviceMode { KEYBOARD, GAMEPAD, MOUSE }

# Tuning carried over from Pogne (tested there).
const MOUSE_MOTION_DEADZONE := 60.0   # pixels of motion needed to enter mouse mode
const MOUSE_MOTION_DECAY := 200.0     # pixels/second the motion count bleeds back
const PAD_MOTION_MIN := 0.3           # GUESS: stick motion below this does not claim the pad

const _UI_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel", &"ui_right", &"ui_left", &"ui_up", &"ui_down"]
# Why: only these keys switch to keyboard mode, so menu/F-keys do not yank mouse players.
const _MODE_SWITCH_KEY_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel", &"ui_left", &"ui_right", &"ui_up", &"ui_down"]

var device_mode: DeviceMode = DeviceMode.KEYBOARD
var gamepad_type: Logic_Input_Layout.GamepadType = Logic_Input_Layout.GamepadType.NONE
## Last pad that produced input; -1 when none. The only pad the menu stick reads.
var last_gamepad_device := -1
## The active gameplay source (keyboard for keyboard and mouse mode, gamepad for pad mode).
var source: Input_Source
## Pad name lookup. Replaceable in tests, which cannot fake a real pad name.
var joy_name_lookup: Callable = Callable(Input, &"get_joy_name")

var _keyboard_source: Input_Source_Keyboard
var _gamepad_source: Input_Source_Gamepad
var _repeat := Logic_Stick_Repeat.new()
var _button_held := {}
var _stick_held := {}
var _action_held := {}
var _mouse_motion := 0.0

func init() -> void:
	device_mode = DeviceMode.KEYBOARD
	gamepad_type = Logic_Input_Layout.GamepadType.NONE
	last_gamepad_device = -1
	joy_name_lookup = Callable(Input, &"get_joy_name")
	_repeat.reset()
	_button_held.clear()
	_stick_held.clear()
	_action_held.clear()
	_mouse_motion = 0.0
	_keyboard_source = Input_Source_Keyboard.new()
	_gamepad_source = Input_Source_Gamepad.new(
			func() -> int: return last_gamepad_device,
			func() -> int: return gamepad_type)
	source = _keyboard_source
	Logic_Mouse_Cursors.apply()  # the game's own pointer, hand, pencil and eraser pictures
	# Why: init may run more than once in tests; never connect twice.
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# The player's hold delay (a setting) decides how long a held stick waits to repeat.
	if not Global_Manager_Events.setting_changed.is_connected(_on_setting_changed):
		Global_Manager_Events.setting_changed.connect(_on_setting_changed)

func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"hold_delay":
		_repeat.initial_delay = Logic_Stick_Repeat.delay_for_setting(value)

# === Read ===
func is_action_held(action: StringName) -> bool:
	return _action_held.get(action, false)

# === Events ===
func _input(event: InputEvent) -> void:
	if source == null:
		return  # init() has not run yet
	_route(event)
	# Why: this router is the only thing that turns input into menu actions. Without this,
	# Godot's built-in focus movement also fires and every press moves two steps.
	if _consumes(event):
		get_viewport().set_input_as_handled()

## True for events the router turned into (or replaced) a built-in UI action. Mouse events
## are left alone so hover and clicks still reach controls.
func _consumes(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var type := _type_of(event.device)
		var index := (event as InputEventJoypadButton).button_index
		if index == Logic_Input_Layout.confirm_button(type) or index == Logic_Input_Layout.cancel_button(type):
			return true
	for action in _UI_ACTIONS:
		if event.is_action(action):
			return true
	return false

func _route(event: InputEvent) -> void:
	_detect_device(event)
	_update_held(event)

	# Mouse clicks: left confirms, right cancels.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: _trigger(&"ui_accept")
			MOUSE_BUTTON_RIGHT: _trigger(&"ui_cancel")
		return

	# Raw stick motion is polled with throttling in _process; d-pad buttons still flow here.
	if event is InputEventJoypadMotion:
		return

	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var jb := event as InputEventJoypadButton
		var type := _type_of(jb.device)
		if jb.button_index == Logic_Input_Layout.confirm_button(type):
			_trigger(&"ui_accept")
			return
		if jb.button_index == Logic_Input_Layout.cancel_button(type):
			_trigger(&"ui_cancel")
			return

	for action in _UI_ACTIONS:
		if event.is_action_pressed(action):
			_trigger(action)
			break

func _process(delta: float) -> void:
	if source == null:
		return  # init() has not run yet
	# Bleed the mouse count so slow ambient drift never crosses the deadzone.
	if device_mode != DeviceMode.MOUSE and _mouse_motion > 0.0:
		_mouse_motion = maxf(0.0, _mouse_motion - MOUSE_MOTION_DECAY * delta)
	var raw := Vector2.ZERO
	if last_gamepad_device >= 0:
		raw = Vector2(Input.get_joy_axis(last_gamepad_device, JOY_AXIS_LEFT_X),
				Input.get_joy_axis(last_gamepad_device, JOY_AXIS_LEFT_Y))
	_apply_stick(raw, delta)
	source.poll()

# Menu stick: held-state transitions every frame, repeat-fire on the cadence.
func _apply_stick(raw: Vector2, delta: float) -> void:
	var dir := _repeat.direction(raw)
	_set_held(_stick_held, &"ui_left", dir.x < 0)
	_set_held(_stick_held, &"ui_right", dir.x > 0)
	_set_held(_stick_held, &"ui_up", dir.y < 0)
	_set_held(_stick_held, &"ui_down", dir.y > 0)
	if _repeat.update(dir, delta):
		if dir.x > 0: _trigger(&"ui_right")
		elif dir.x < 0: _trigger(&"ui_left")
		if dir.y > 0: _trigger(&"ui_down")
		elif dir.y < 0: _trigger(&"ui_up")

func _trigger(action: StringName) -> void:
	Global_Manager_Events.ui_action_triggered.emit(action)

# === Held-state tracking ===
# Why: stick and button contributions are kept apart and OR'd, so a held key is not reported
# released the moment the stick returns to neutral.
func _set_held(store: Dictionary, action: StringName, held: bool) -> void:
	store[action] = held
	var now: bool = _button_held.get(action, false) or _stick_held.get(action, false)
	if now == _action_held.get(action, false):
		return
	_action_held[action] = now
	Global_Manager_Events.ui_action_held_changed.emit(action, now)

func _update_held(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_set_held(_button_held, &"ui_accept", mb.pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_set_held(_button_held, &"ui_cancel", mb.pressed)
		return
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		var type := _type_of(jb.device)
		if jb.button_index == Logic_Input_Layout.confirm_button(type):
			_set_held(_button_held, &"ui_accept", jb.pressed)
			return
		if jb.button_index == Logic_Input_Layout.cancel_button(type):
			_set_held(_button_held, &"ui_cancel", jb.pressed)
			return
	for action in _UI_ACTIONS:
		if event.is_action_pressed(action):
			_set_held(_button_held, action, true)
		elif event.is_action_released(action):
			_set_held(_button_held, action, false)

# === Device mode ===
func _detect_device(event: InputEvent) -> void:
	# The pad that moves a stick past the minimum, or presses a button, becomes the active pad.
	if event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= PAD_MOTION_MIN):
		_set_last_pad(event.device)

	var new_mode := device_mode
	if event is InputEventMouseMotion:
		if device_mode != DeviceMode.MOUSE:
			_mouse_motion += (event as InputEventMouseMotion).relative.length()
			if _mouse_motion >= MOUSE_MOTION_DEADZONE:
				new_mode = DeviceMode.MOUSE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		new_mode = DeviceMode.MOUSE  # clicks are unambiguous intent
	elif event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= PAD_MOTION_MIN):
		new_mode = DeviceMode.GAMEPAD
		_mouse_motion = 0.0
	elif event is InputEventKey and event.pressed:
		for action in _MODE_SWITCH_KEY_ACTIONS:
			if event.is_action_pressed(action):
				new_mode = DeviceMode.KEYBOARD
				_mouse_motion = 0.0
				break
	_set_mode(new_mode)

func _set_mode(new_mode: DeviceMode) -> void:
	if new_mode == device_mode:
		return
	device_mode = new_mode
	source = _gamepad_source if new_mode == DeviceMode.GAMEPAD else _keyboard_source
	Global_Manager_Events.device_mode_changed.emit(new_mode)

func _set_last_pad(device: int) -> void:
	if device == last_gamepad_device:
		return
	last_gamepad_device = device
	_update_gamepad_type()

func _update_gamepad_type() -> void:
	var new_type := Logic_Input_Layout.GamepadType.NONE
	if last_gamepad_device >= 0:
		new_type = _type_of(last_gamepad_device)
	if new_type != gamepad_type:
		gamepad_type = new_type
		Global_Manager_Events.gamepad_type_changed.emit(new_type)

func _type_of(device: int) -> Logic_Input_Layout.GamepadType:
	return Logic_Input_Layout.gamepad_type_from_name(joy_name_lookup.call(device))

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or device != last_gamepad_device:
		return
	# Why: the active pad was unplugged; fall back so nothing reads a dead device.
	last_gamepad_device = -1
	_update_gamepad_type()
	_set_mode(DeviceMode.KEYBOARD)
