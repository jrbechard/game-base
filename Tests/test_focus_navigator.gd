extends GutTest
## === Build step 4d boundary tests: focus navigator, hover effect, router consume rule ===
## Layout (plain Controls, positioned by hand):
##     A  B  C        B is disabled in some tests
##     D  E  F

var _root: Control
var _nav: Component_Focus_Navigator
var _b := {}   # name -> Button

func before_each() -> void:
	Global_Manager_Input.init()
	_root = Control.new()
	_root.size = Vector2(400, 200)
	add_child_autofree(_root)
	for row in 2:
		for col in 3:
			var btn := Button.new()
			btn.size = Vector2(100, 40)
			btn.position = Vector2(col * 120, row * 60)
			btn.focus_mode = Control.FOCUS_ALL
			btn.text = "ABCDEF"[row * 3 + col]
			_root.add_child(btn)
			_b[btn.text] = btn
	_nav = Component_Focus_Navigator.new()
	_root.add_child(_nav)
	await wait_process_frames(1)

func after_all() -> void:
	Global_Manager_Input.init()

func _press(action: StringName) -> void:
	Global_Manager_Events.ui_action_triggered.emit(action)

# === Movement ===
func test_default_focus_is_the_first_control() -> void:
	_nav.focus_default()
	assert_eq(_nav.focused_control(), _b["A"])

func test_directions_move_through_the_layout() -> void:
	_nav.focus_default()
	_press(&"ui_right")
	assert_eq(_nav.focused_control(), _b["B"])
	_press(&"ui_down")
	assert_eq(_nav.focused_control(), _b["E"])
	_press(&"ui_left")
	assert_eq(_nav.focused_control(), _b["D"])
	_press(&"ui_up")
	assert_eq(_nav.focused_control(), _b["A"])

func test_first_press_with_nothing_focused_lands_on_default() -> void:
	_press(&"ui_right")
	assert_eq(_nav.focused_control(), _b["A"])

func test_edge_does_not_move_and_is_silent() -> void:
	_nav.focus_default()
	watch_signals(Global_Manager_Events)
	_press(&"ui_left")
	_press(&"ui_up")
	assert_eq(_nav.focused_control(), _b["A"])
	assert_signal_not_emitted(Global_Manager_Events, "menu_navigated")

func test_a_real_move_announces_navigated() -> void:
	_nav.focus_default()
	watch_signals(Global_Manager_Events)
	_press(&"ui_right")
	assert_signal_emit_count(Global_Manager_Events, "menu_navigated", 1)

func test_disabled_controls_are_skipped() -> void:
	_b["B"].disabled = true
	_nav.focus_default()
	_press(&"ui_right")
	assert_eq(_nav.focused_control(), _b["C"])

func test_wrap_goes_to_the_far_end() -> void:
	_nav.wrap_around = true
	_b["C"].grab_focus()
	_press(&"ui_right")
	assert_eq(_nav.focused_control(), _b["A"])

# A wide Back button under the grid: Up from it must return to the column we came from.
func _add_back_button() -> Button:
	var back := Button.new()
	back.size = Vector2(340, 40)
	back.position = Vector2(0, 120)
	back.focus_mode = Control.FOCUS_ALL
	back.text = "Back"
	_root.add_child(back)
	return back

func test_up_from_back_returns_to_the_column_we_came_from() -> void:
	var back := _add_back_button()
	_b["D"].grab_focus()
	_press(&"ui_down")
	assert_eq(_nav.focused_control(), back)
	_press(&"ui_up")
	assert_eq(_nav.focused_control(), _b["D"], "left column in, left column out")
	_b["F"].grab_focus()
	_press(&"ui_down")
	assert_eq(_nav.focused_control(), back)
	_press(&"ui_up")
	assert_eq(_nav.focused_control(), _b["F"], "right column in, right column out")

func test_return_memory_is_dropped_if_the_control_became_unusable() -> void:
	var back := _add_back_button()
	_b["E"].grab_focus()
	_press(&"ui_down")
	_b["E"].disabled = true
	_press(&"ui_up")
	assert_ne(_nav.focused_control(), _b["E"], "never returns to a disabled control")
	assert_ne(_nav.focused_control(), back, "and still moves somewhere sensible")

# === Sliders and choosers ===
# A slider under the grid: Left/Right change it instead of moving focus.
func _add_slider(value := 0.5) -> HSlider:
	var s := HSlider.new()
	s.size = Vector2(340, 30)
	s.position = Vector2(0, 120)
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.1
	s.value = value
	s.focus_mode = Control.FOCUS_ALL
	_root.add_child(s)
	return s

func test_left_and_right_step_a_focused_slider_without_moving_focus() -> void:
	var slider := _add_slider(0.5)
	slider.grab_focus()
	watch_signals(_nav)
	watch_signals(Global_Manager_Events)
	_press(&"ui_right")
	assert_almost_eq(slider.value, 0.6, 0.0001)
	_press(&"ui_left")
	_press(&"ui_left")
	assert_almost_eq(slider.value, 0.4, 0.0001)
	assert_eq(_nav.focused_control(), slider, "focus stayed on the slider")
	assert_signal_emit_count(_nav, "adjusted", 3)
	assert_signal_emit_count(Global_Manager_Events, "menu_adjusted", 3)

func test_adjusting_reports_the_direction() -> void:
	var slider := _add_slider(0.5)
	slider.grab_focus()
	watch_signals(_nav)
	_press(&"ui_right")
	assert_signal_emitted_with_parameters(_nav, "adjusted", [slider, 1])
	_press(&"ui_left")
	assert_signal_emitted_with_parameters(_nav, "adjusted", [slider, -1])

func test_a_slider_at_its_limit_stays_silent_and_keeps_focus() -> void:
	var slider := _add_slider(1.0)
	slider.grab_focus()
	watch_signals(Global_Manager_Events)
	_press(&"ui_right")
	assert_eq(slider.value, 1.0)
	assert_eq(_nav.focused_control(), slider)
	assert_signal_not_emitted(Global_Manager_Events, "menu_adjusted")

func test_up_and_down_still_leave_a_slider() -> void:
	var slider := _add_slider(0.5)
	slider.grab_focus()
	_press(&"ui_up")
	assert_ne(_nav.focused_control(), slider)

func test_ranges_are_left_alone_when_adjusting_is_off() -> void:
	var slider := _add_slider(0.5)
	_nav.adjust_ranges = false
	slider.grab_focus()
	watch_signals(_nav)
	_press(&"ui_right")
	assert_eq(slider.value, 0.5)
	assert_signal_not_emitted(_nav, "adjusted")

func test_a_control_marked_adjustable_reports_left_and_right() -> void:
	var chooser := Button.new()
	chooser.size = Vector2(340, 30)
	chooser.position = Vector2(0, 120)
	chooser.focus_mode = Control.FOCUS_ALL
	chooser.set_meta(&"adjustable", true)
	_root.add_child(chooser)
	chooser.grab_focus()
	watch_signals(_nav)
	_press(&"ui_right")
	assert_signal_emitted_with_parameters(_nav, "adjusted", [chooser, 1])
	_press(&"ui_left")
	assert_signal_emitted_with_parameters(_nav, "adjusted", [chooser, -1])
	assert_eq(_nav.focused_control(), chooser)

# === Activation and cancel ===
func test_accept_activates_the_focused_control_once() -> void:
	_nav.focus_default()
	_press(&"ui_right")
	watch_signals(_nav)
	watch_signals(Global_Manager_Events)
	_press(&"ui_accept")
	assert_signal_emit_count(_nav, "activated", 1)
	assert_signal_emitted_with_parameters(_nav, "activated", [_b["B"]])
	assert_signal_emitted(Global_Manager_Events, "menu_confirmed")

func test_native_button_press_is_not_a_second_activation() -> void:
	_nav.focus_default()
	watch_signals(_nav)
	_b["A"].pressed.emit()
	assert_signal_not_emitted(_nav, "activated")

func test_cancel_is_announced() -> void:
	watch_signals(_nav)
	watch_signals(Global_Manager_Events)
	_press(&"ui_cancel")
	assert_signal_emitted(_nav, "cancelled")
	assert_signal_emitted(Global_Manager_Events, "menu_cancelled")

func test_disabled_navigator_ignores_input() -> void:
	_nav.focus_default()
	_nav.enabled = false
	watch_signals(_nav)
	_press(&"ui_right")
	_press(&"ui_accept")
	assert_eq(_nav.focused_control(), _b["A"])
	assert_signal_not_emitted(_nav, "activated")

# === Mouse ===
func test_hover_is_ignored_unless_in_mouse_mode() -> void:
	_nav.focus_default()
	_b["C"].mouse_entered.emit()
	assert_eq(_nav.focused_control(), _b["A"], "keyboard mode: hover does not steal focus")

func test_hover_focuses_in_mouse_mode_and_accept_uses_the_hovered_control() -> void:
	_nav.focus_default()
	Global_Manager_Input.device_mode = Global_Manager_Input.DeviceMode.MOUSE
	_b["C"].mouse_entered.emit()
	assert_eq(_nav.focused_control(), _b["C"])
	watch_signals(_nav)
	_press(&"ui_accept")
	assert_signal_emitted_with_parameters(_nav, "activated", [_b["C"]])

func test_click_with_nothing_hovered_does_nothing_in_mouse_mode() -> void:
	_nav.focus_default()
	Global_Manager_Input.device_mode = Global_Manager_Input.DeviceMode.MOUSE
	watch_signals(_nav)
	_press(&"ui_accept")
	assert_signal_not_emitted(_nav, "activated")

# === Hover effect ===
func test_hover_effect_scales_on_focus_and_returns() -> void:
	var fx := Component_Hover_Effect.new()
	fx.duration = 0.05
	_b["A"].add_child(fx)
	await wait_process_frames(1)
	_b["A"].grab_focus()
	await wait_seconds(0.15)
	assert_gt(_b["A"].scale.x, 1.05, "grew while focused")
	_b["B"].grab_focus()
	await wait_seconds(0.15)
	assert_almost_eq(_b["A"].scale.x, 1.0, 0.001)

# === Router consume rule (4b follow-up) ===
func test_router_consumes_ui_keys_but_not_other_keys() -> void:
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	assert_true(Global_Manager_Input._consumes(right), "arrow keys are routed, so Godot must not also move focus")
	var other := InputEventKey.new()
	other.keycode = KEY_F10
	other.pressed = true
	assert_false(Global_Manager_Input._consumes(other))

func test_router_consumes_pad_confirm_and_cancel_on_both_layouts() -> void:
	var names := {0: "XInput Controller", 1: "Nintendo Switch Pro Controller"}
	Global_Manager_Input.joy_name_lookup = func(d: int) -> String: return names.get(d, "")
	for device in [0, 1]:
		for index in [JOY_BUTTON_A, JOY_BUTTON_B]:
			var e := InputEventJoypadButton.new()
			e.device = device
			e.button_index = index
			e.pressed = true
			assert_true(Global_Manager_Input._consumes(e), "pad %d button %d" % [device, index])
	var x := InputEventJoypadButton.new()
	x.device = 1
	x.button_index = JOY_BUTTON_X
	x.pressed = true
	assert_false(Global_Manager_Input._consumes(x), "X is not a menu button")

func test_router_does_not_consume_mouse_events() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_false(Global_Manager_Input._consumes(click))
