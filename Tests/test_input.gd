extends GutTest
## === Build step 4b boundary tests: input layout, stick repeat, router, sources ===
## Pad names are the real ones Godot reported on JR's hardware (see rumble test log).

const XBOX_NAME := "XInput Controller"
const SWITCH_NAME := "Nintendo Switch Pro Controller"
const SWITCH2_NAME := "Nintendo Switch 2 Pro Controller"

const Layout = preload("res://Scripts/Logic/logic_input_layout.gd")

func before_each() -> void:
	Global_Manager_Input.init()
	# Fake pads: device 0 is an Xbox, device 1 a Switch Pro.
	var names := {0: XBOX_NAME, 1: SWITCH_NAME}
	Global_Manager_Input.joy_name_lookup = func(d: int) -> String: return names.get(d, "")

func after_all() -> void:
	Global_Manager_Input.init()

func _button(device: int, index: int, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = index
	e.pressed = pressed
	return e

# === Logic_Input_Layout ===
func test_pad_type_from_real_names() -> void:
	assert_eq(Layout.gamepad_type_from_name(XBOX_NAME), Layout.GamepadType.XBOX)
	assert_eq(Layout.gamepad_type_from_name("Xbox Series X Controller"), Layout.GamepadType.XBOX)
	assert_eq(Layout.gamepad_type_from_name(SWITCH_NAME), Layout.GamepadType.SWITCH)
	assert_eq(Layout.gamepad_type_from_name(SWITCH2_NAME), Layout.GamepadType.SWITCH)
	assert_eq(Layout.gamepad_type_from_name(""), Layout.GamepadType.NONE)

func test_confirm_and_cancel_swap_on_switch() -> void:
	assert_eq(Layout.confirm_button(Layout.GamepadType.XBOX), JOY_BUTTON_A)
	assert_eq(Layout.cancel_button(Layout.GamepadType.XBOX), JOY_BUTTON_B)
	assert_eq(Layout.confirm_button(Layout.GamepadType.SWITCH), JOY_BUTTON_B)
	assert_eq(Layout.cancel_button(Layout.GamepadType.SWITCH), JOY_BUTTON_A)

func test_gameplay_action_buttons_follow_the_swap() -> void:
	assert_eq(Layout.button_for_action(&"interact", Layout.GamepadType.SWITCH), JOY_BUTTON_B)
	assert_eq(Layout.button_for_action(&"cancel", Layout.GamepadType.XBOX), JOY_BUTTON_B)
	assert_eq(Layout.button_for_action(&"menu", Layout.GamepadType.XBOX), JOY_BUTTON_START)
	assert_eq(Layout.button_for_action(&"nope", Layout.GamepadType.XBOX), -1)

# === Logic_Stick_Repeat ===
func test_stick_repeat_cadence() -> void:
	var r := Logic_Stick_Repeat.new()
	var right := Vector2i.RIGHT
	assert_false(r.update(Vector2i.ZERO, 0.1), "neutral never fires")
	assert_true(r.update(right, 0.0), "fires at once on direction change")
	assert_false(r.update(right, 0.2), "waits for the initial delay")
	assert_true(r.update(right, 0.2), "fires when the initial delay has passed")
	assert_false(r.update(right, 0.05), "then waits for the repeat rate")
	assert_true(r.update(right, 0.08), "and repeats")
	assert_false(r.update(Vector2i.ZERO, 0.1), "back to neutral is silent")
	assert_true(r.update(Vector2i.LEFT, 0.0), "a new direction fires at once")

func test_stick_direction_threshold() -> void:
	var r := Logic_Stick_Repeat.new()
	assert_eq(r.direction(Vector2(0.4, 0.0)), Vector2i.ZERO)
	assert_eq(r.direction(Vector2(0.6, -0.9)), Vector2i(1, -1))

# === Router: A/B swap ===
func test_xbox_a_confirms_and_b_cancels() -> void:
	watch_signals(Global_Manager_Events)
	Global_Manager_Input._input(_button(0, JOY_BUTTON_A))
	assert_signal_emitted_with_parameters(Global_Manager_Events, "ui_action_triggered", [&"ui_accept"])
	Global_Manager_Input._input(_button(0, JOY_BUTTON_B))
	assert_signal_emitted_with_parameters(Global_Manager_Events, "ui_action_triggered", [&"ui_cancel"])

func test_switch_pad_buttons_are_swapped() -> void:
	watch_signals(Global_Manager_Events)
	Global_Manager_Input._input(_button(1, JOY_BUTTON_B))  # Nintendo A (right) confirms
	assert_signal_emitted_with_parameters(Global_Manager_Events, "ui_action_triggered", [&"ui_accept"])
	Global_Manager_Input._input(_button(1, JOY_BUTTON_A))  # Nintendo B (bottom) cancels
	assert_signal_emitted_with_parameters(Global_Manager_Events, "ui_action_triggered", [&"ui_cancel"])

func test_held_state_follows_press_and_release() -> void:
	watch_signals(Global_Manager_Events)
	Global_Manager_Input._input(_button(1, JOY_BUTTON_B, true))
	assert_true(Global_Manager_Input.is_action_held(&"ui_accept"))
	Global_Manager_Input._input(_button(1, JOY_BUTTON_B, false))
	assert_false(Global_Manager_Input.is_action_held(&"ui_accept"))
	assert_signal_emit_count(Global_Manager_Events, "ui_action_held_changed", 2)

# === Router: device mode ===
func test_pad_button_switches_to_gamepad_mode_and_sets_type() -> void:
	watch_signals(Global_Manager_Events)
	Global_Manager_Input._input(_button(1, JOY_BUTTON_X))
	assert_eq(Global_Manager_Input.device_mode, Global_Manager_Input.DeviceMode.GAMEPAD)
	assert_eq(Global_Manager_Input.gamepad_type, Layout.GamepadType.SWITCH)
	assert_eq(Global_Manager_Input.last_gamepad_device, 1)
	assert_signal_emitted(Global_Manager_Events, "device_mode_changed")
	assert_signal_emitted_with_parameters(Global_Manager_Events, "gamepad_type_changed", [Layout.GamepadType.SWITCH])

func test_small_mouse_jitter_does_not_enter_mouse_mode() -> void:
	var m := InputEventMouseMotion.new()
	m.relative = Vector2(10, 0)
	Global_Manager_Input._input(m)
	assert_eq(Global_Manager_Input.device_mode, Global_Manager_Input.DeviceMode.KEYBOARD)
	m.relative = Vector2(80, 0)
	Global_Manager_Input._input(m)
	assert_eq(Global_Manager_Input.device_mode, Global_Manager_Input.DeviceMode.MOUSE)

func test_mouse_click_enters_mouse_mode_and_confirms() -> void:
	watch_signals(Global_Manager_Events)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Global_Manager_Input._input(click)
	assert_eq(Global_Manager_Input.device_mode, Global_Manager_Input.DeviceMode.MOUSE)
	assert_signal_emitted_with_parameters(Global_Manager_Events, "ui_action_triggered", [&"ui_accept"])

# === The Pogne bug: the stick must follow the last-used pad, not pad 0 ===
func test_stick_on_second_pad_navigates() -> void:
	Global_Manager_Input._input(_button(1, JOY_BUTTON_X))  # player picks up pad 1
	watch_signals(Global_Manager_Events)
	Global_Manager_Input._apply_stick(Vector2(1.0, 0.0), 0.0)
	assert_signal_emitted_with_parameters(Global_Manager_Events, "ui_action_triggered", [&"ui_right"])
	assert_eq(Global_Manager_Input.last_gamepad_device, 1)

func test_unplugging_the_active_pad_falls_back() -> void:
	Global_Manager_Input._input(_button(1, JOY_BUTTON_X))
	Global_Manager_Input._on_joy_connection_changed(1, false)
	assert_eq(Global_Manager_Input.last_gamepad_device, -1)
	assert_eq(Global_Manager_Input.gamepad_type, Layout.GamepadType.NONE)
	assert_eq(Global_Manager_Input.device_mode, Global_Manager_Input.DeviceMode.KEYBOARD)

# === Input_Source ===
func test_active_source_follows_device_mode() -> void:
	assert_true(Global_Manager_Input.source is Input_Source_Keyboard)
	Global_Manager_Input._input(_button(0, JOY_BUTTON_A))
	assert_true(Global_Manager_Input.source is Input_Source_Gamepad)
	assert_eq(Global_Manager_Input.source.get_device(), 0, "rumble gets its device from the source")

func test_keyboard_source_has_no_rumble_device() -> void:
	assert_eq(Global_Manager_Input.source.get_device(), -1)
