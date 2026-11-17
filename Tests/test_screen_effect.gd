extends GutTest
## === The CRT overlay: one layer over every screen, strength from the setting ===

const MAIN := preload("res://Scenes/Global/main.tscn")
var _main: Node

func before_each() -> void:
	_main = MAIN.instantiate()
	_main.splash = null
	add_child_autofree(_main)
	await wait_process_frames(2)

func _fx() -> Shell_Screen_Effect:
	return _main.get_node("Screen_Effect")

func _strength() -> float:
	return _fx().get_node("Effect_Rect").material.get_shader_parameter("effect_intensity")

func test_it_defaults_to_full_strength_like_ever_blue() -> void:
	assert_eq(State_Settings.DEFAULTS[&"screen_effect"], 1.0)

func test_the_overlay_sits_above_the_screens_and_below_the_transition() -> void:
	assert_gt(_fx().layer, _main.get_node("Overlay_Host").layer)
	assert_lt(_fx().layer, _main.get_node("Transition").layer)

func test_the_setting_changes_the_strength_through_the_bus() -> void:
	Global_Manager_Events.setting_changed.emit(&"screen_effect", 0.4)
	assert_almost_eq(_strength(), 0.4, 0.001)
	assert_true(_fx().get_node("Effect_Rect").visible)

func test_zero_switches_the_overlay_off_entirely() -> void:
	Global_Manager_Events.setting_changed.emit(&"screen_effect", 0.0)
	assert_false(_fx().get_node("Effect_Rect").visible)
	Global_Manager_Events.setting_changed.emit(&"screen_effect", 1.0)
	assert_true(_fx().get_node("Effect_Rect").visible)

func test_the_overlay_is_held_back_until_the_splash_is_done() -> void:
	var main: Node = MAIN.instantiate()
	main.splash = preload("res://Scenes/Shell/shell_splash.tscn")  # a Main that plays the splash
	add_child_autofree(main)
	await wait_process_frames(2)
	assert_false(main.get_node("Screen_Effect/Effect_Rect").visible, "hidden while the splash plays")
	Global_Manager_Events.splash_finished.emit()
	assert_true(main.get_node("Screen_Effect/Effect_Rect").visible, "shown after it")

func test_the_setting_is_validated_like_the_others() -> void:
	assert_eq(State_Settings.sanitize(&"screen_effect", 5.0), 1.0)
	assert_null(State_Settings.sanitize(&"screen_effect", "lots"))
