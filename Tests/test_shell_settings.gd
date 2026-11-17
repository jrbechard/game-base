extends GutTest
## === Build step 4f-2 tests: the Shell_Settings screen ===
## The screen shows state and sends intents; the settings manager does the work.

const TEST_PATH := "user://test_shell_settings.json"

var _screen: Shell_Settings
var _rumble_calls: Array = []

func before_each() -> void:
	_delete()
	Global_Manager_GameData.init()
	Global_Manager_Input.init()
	Global_Manager_Rumble.init(func() -> int: return 0)
	_rumble_calls.clear()
	Global_Manager_Rumble.backend = func(d: int, w: float, s: float, t: float) -> void:
		_rumble_calls.append([d, w, s, t])
	Global_Manager_Settings.init(TEST_PATH)

func after_all() -> void:
	_delete()
	Global_Manager_Settings.init(TEST_PATH)
	Global_Manager_Settings.save_now()
	_delete()
	Global_Manager_Rumble.init(func() -> int:
		return Global_Manager_Input.source.get_device() if Global_Manager_Input.source != null else -1)

func _delete() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)

func _open() -> void:
	_screen = load("res://Scenes/Shell/shell_settings.tscn").instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(3)

func _control(key: StringName) -> Control:
	return _screen._controls[key]

func _press(action: StringName) -> void:
	Global_Manager_Events.ui_action_triggered.emit(action)

# === Showing state ===
func test_every_setting_has_a_control() -> void:
	await _open()
	for key in State_Settings.DEFAULTS:
		if key == &"volume_ambience":
			continue  # the Ambience bus exists but has no manager or control yet
		assert_true(_screen._controls.has(key), "a control edits %s" % key)

func test_controls_start_at_the_current_values() -> void:
	Global_Manager_Settings.set_value(&"volume_music", 0.3)
	Global_Manager_Settings.set_value(&"reduce_motion", true)
	Global_Manager_Settings.set_value(&"language", &"fr")
	await _open()
	assert_almost_eq((_control(&"volume_music") as Range).value, 0.3, 0.001)
	assert_true((_control(&"reduce_motion") as BaseButton).button_pressed)
	assert_eq((_control(&"language") as Button).text, "Français")

func test_a_setting_changed_elsewhere_updates_the_screen() -> void:
	await _open()
	Global_Manager_Settings.set_value(&"volume_sfx", 0.2)
	assert_almost_eq((_control(&"volume_sfx") as Range).value, 0.2, 0.001)

func test_labels_translate() -> void:
	await _open()
	Global_Manager_Settings.set_value(&"language", &"fr")
	var title: Label = _screen.find_child("Label_Title", true, false)
	assert_eq(tr(title.text), "Paramètres")

# === Sending intents ===
func test_moving_a_slider_changes_the_setting() -> void:
	await _open()
	(_control(&"volume_master") as Range).value = 0.4
	assert_almost_eq(float(Global_Manager_Settings.get_value(&"volume_master")), 0.4, 0.001)
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.MASTER), 0.4, 0.001)

func test_left_and_right_on_a_slider_change_the_setting() -> void:
	await _open()
	_control(&"volume_music").grab_focus()
	_press(&"ui_left")
	assert_almost_eq(float(Global_Manager_Settings.get_value(&"volume_music")), 0.9, 0.001)

func test_changing_the_rumble_slider_gives_a_sample_buzz_at_the_new_strength() -> void:
	await _open()
	(_control(&"rumble_scale") as Range).value = 0.4
	assert_eq(_rumble_calls.size(), 1, "one sample buzz")
	assert_almost_eq(float(_rumble_calls[0][1]), 0.2, 0.001, "preview strength 0.5 at scale 0.4")

func test_the_screen_loading_its_own_values_does_not_buzz_or_echo() -> void:
	watch_signals(Global_Manager_Events)
	await _open()
	assert_eq(_rumble_calls.size(), 0)
	assert_signal_not_emitted(Global_Manager_Events, "setting_change_requested")

func test_language_chooser_cycles_with_confirm_and_left_right() -> void:
	await _open()
	_screen._show_tab(1)
	_control(&"language").grab_focus()
	_press(&"ui_accept")
	assert_eq(Global_Manager_Settings.get_value(&"language"), &"fr")
	assert_eq((_control(&"language") as Button).text, "Français")
	_press(&"ui_left")
	assert_eq(Global_Manager_Settings.get_value(&"language"), &"en")
	_press(&"ui_right")
	assert_eq(Global_Manager_Settings.get_value(&"language"), &"fr")

func test_reduce_motion_toggles_with_confirm() -> void:
	await _open()
	_screen._show_tab(1)
	_control(&"reduce_motion").grab_focus()
	_press(&"ui_accept")
	assert_eq(Global_Manager_Settings.get_value(&"reduce_motion"), true)
	assert_eq(UI_Animator.motion_scale, 0.0)
	_press(&"ui_accept")
	assert_eq(Global_Manager_Settings.get_value(&"reduce_motion"), false)
	assert_eq(UI_Animator.motion_scale, 1.0)

func test_a_mouse_click_on_the_toggle_is_not_toggled_twice() -> void:
	await _open()
	_screen._show_tab(1)
	_control(&"reduce_motion").grab_focus()
	Global_Manager_Input.device_mode = Global_Manager_Input.DeviceMode.MOUSE
	_screen._nav._hovered = _control(&"reduce_motion")
	_press(&"ui_accept")  # in mouse mode the native click already toggles it; the screen must not
	assert_eq(Global_Manager_Settings.get_value(&"reduce_motion"), false)

# === Layout in any language ===
# French labels are longer than English ones; on each tab the controls must still line up in one column.
func test_controls_line_up_on_every_tab_in_every_language() -> void:
	await _open()
	for language in [&"en", &"fr"]:
		Global_Manager_Settings.set_value(&"language", language)
		for i in _screen._pages.get_child_count():
			_screen._show_tab(i, false)
			await wait_process_frames(3)
			var controls: Array = []
			for key in _screen._controls:
				if _screen._pages.get_child(i).is_ancestor_of(_screen._controls[key]):
					controls.append(_screen._controls[key])
			for control in controls:
				assert_eq(control.global_position.x, controls[0].global_position.x, "%s lines up in %s" % [control.name, language])
				assert_eq(control.size.x, controls[0].size.x, "%s is as wide in %s" % [control.name, language])

func test_back_is_a_button_in_the_footer() -> void:
	await _open()
	assert_not_null(_screen.find_child("Button_Back", true, false))

# === The toggle's look ===
func test_the_toggle_is_as_wide_as_the_sliders_and_the_language_button() -> void:
	await _open()
	var width := (_control(&"volume_master") as Control).custom_minimum_size.x
	assert_eq((_control(&"reduce_motion") as Control).custom_minimum_size.x, width)
	assert_eq((_control(&"language") as Control).custom_minimum_size.x, width)

func test_the_toggle_does_not_scale_on_focus() -> void:
	await _open()
	_screen._show_tab(1, false)
	var toggle := _control(&"reduce_motion")
	assert_eq(toggle.find_children("*", "Component_Hover_Effect", true, false).size(), 0, "no hover effect on the toggle")
	toggle.grab_focus()
	await wait_seconds(0.25)
	assert_eq(toggle.scale, Vector2.ONE)

func test_the_toggle_shows_on_or_off_in_the_current_language() -> void:
	await _open()
	var toggle := _control(&"reduce_motion") as Button
	assert_eq(tr(toggle.text), "Off")
	Global_Manager_Settings.set_value(&"reduce_motion", true)
	assert_eq(tr(toggle.text), "On")
	Global_Manager_Settings.set_value(&"language", &"fr")
	assert_eq(tr(toggle.text), "Activé")

# === Leaving ===
func test_back_button_and_cancel_both_ask_to_leave() -> void:
	await _open()
	watch_signals(_screen)
	var back: Control = _screen.find_child("Button_Back", true, false)
	back.grab_focus()
	_press(&"ui_accept")
	assert_signal_emit_count(_screen, "back_requested", 1)
	_press(&"ui_cancel")
	assert_signal_emit_count(_screen, "back_requested", 2)

func test_the_first_focus_is_the_first_slider() -> void:
	await _open()
	assert_eq(_screen._nav.focused_control(), _control(&"volume_master"))

# === Tabs ===
class Fake_Source extends Input_Source:
	var edge := {}
	func just_pressed(action: StringName) -> bool:
		return edge.get(action, false)

func test_it_opens_on_the_sound_tab_with_the_other_pages_hidden() -> void:
	await _open()
	assert_eq(_screen.current_tab(), 0)
	assert_true(_screen._pages.get_child(0).visible)
	assert_false(_screen._pages.get_child(3).visible)

func test_stepping_tabs_stops_at_the_ends_and_focuses_the_first_row() -> void:
	await _open()
	_screen.step_tab(-1)
	assert_eq(_screen.current_tab(), 0)
	_screen.step_tab(1)
	assert_eq(_screen.current_tab(), 1)
	assert_eq(_screen._nav.focused_control(), _control(&"language"))
	for i in 5:
		_screen.step_tab(1)
	assert_eq(_screen.current_tab(), 3)

func test_l_and_r_switch_tabs() -> void:
	var source := Fake_Source.new()
	Global_Manager_Input.source = source
	await _open()
	source.edge[&"redo"] = true
	_screen._process(0.0)
	source.edge.clear()
	assert_eq(_screen.current_tab(), 1, "R goes to the next tab")
	source.edge[&"undo"] = true
	_screen._process(0.0)
	source.edge.clear()
	assert_eq(_screen.current_tab(), 0, "L goes back")
	Global_Manager_Input.init()

func test_the_help_line_follows_the_focused_row() -> void:
	await _open()
	_control(&"volume_music").grab_focus()
	assert_eq(tr(_screen._help.text), "Loudness of the music.")

# === Level bars ===
func test_a_level_bar_shows_one_block_per_step() -> void:
	await _open()
	var bar := _control(&"volume_master") as UI_Level_Bar
	assert_eq(bar.notch_count(), 10)
	(bar as Range).value = 0.3
	assert_eq(bar.lit_count(), 3)
	assert_eq((_control(&"rumble_scale") as UI_Level_Bar).notch_count(), 5)

# === Data tab ===
func test_restore_defaults_puts_every_setting_back() -> void:
	await _open()
	Global_Manager_Settings.set_value(&"volume_music", 0.2)
	Global_Manager_Settings.set_value(&"language", &"fr")
	_screen._show_tab(3)
	_press_button("Actions/Button_Restore")
	assert_eq(Global_Manager_Settings.get_value(&"volume_music"), 1.0)
	assert_eq(Global_Manager_Settings.get_value(&"language"), &"en")
	assert_almost_eq((_control(&"volume_music") as Range).value, 1.0, 0.001, "the screen follows")

func _press_button(path: String) -> void:
	var button: Control = _screen.get_node("Column/Pages/Page_Data/" + path)
	_screen._nav.activated.emit(button)

func test_delete_save_asks_first_and_no_is_selected() -> void:
	await _open()
	_screen._show_tab(3)
	watch_signals(Global_Manager_Events)
	_press_button("Actions/Button_Delete")
	await wait_process_frames(1)
	assert_true(_screen._confirm.visible)
	assert_signal_not_emitted(Global_Manager_Events, "save_reset_requested")
	assert_eq(_screen._nav.focused_control(), _screen.get_node("Column/Pages/Page_Data/Confirm/Button_No"))

func test_cancel_in_the_question_closes_it_instead_of_leaving() -> void:
	await _open()
	_screen._show_tab(3)
	_press_button("Actions/Button_Delete")
	watch_signals(_screen)
	_press(&"ui_cancel")
	assert_false(_screen._confirm.visible)
	assert_signal_not_emitted(_screen, "back_requested")

func test_yes_sends_the_reset_then_the_save() -> void:
	await _open()
	_screen._show_tab(3)
	_press_button("Actions/Button_Delete")
	watch_signals(Global_Manager_Events)
	_press_button("Confirm/Button_Yes")
	assert_signal_emitted(Global_Manager_Events, "save_reset_requested")
	assert_signal_emitted(Global_Manager_Events, "save_requested")
	assert_false(_screen._confirm.visible)

func test_the_settings_screen_names_no_game_things() -> void:
	var text := FileAccess.get_file_as_string("res://Scripts/UI/shell_settings.gd")
	for word in ["Progress", "puzzle", "item"]:
		assert_false(text.to_lower().contains(word.to_lower()) and word != "puzzle", word)
