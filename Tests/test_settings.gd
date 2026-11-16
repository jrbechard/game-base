extends GutTest
## === Build step 4f-2 tests: Global_Manager_Settings and State_Settings ===
## Uses its own settings file, so the real one is never touched.

const TEST_PATH := "user://test_settings.json"

func before_each() -> void:
	_delete()
	Global_Manager_GameData.init()
	Global_Manager_Rumble.init(func() -> int: return -1)
	Global_Manager_Settings.init(TEST_PATH)

func after_all() -> void:
	# Leave the game in its default state (volumes, language, motion, rumble) and no files behind.
	_delete()
	Global_Manager_Settings.init(TEST_PATH)
	Global_Manager_Settings.save_now()
	_delete()

func _delete() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)

func _write_raw(text: String) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()

# === Defaults and validation ===
func test_defaults() -> void:
	assert_eq(Global_Manager_Settings.get_value(&"volume_master"), 1.0)
	assert_eq(Global_Manager_Settings.get_value(&"language"), &"en")
	assert_eq(Global_Manager_Settings.get_value(&"rumble_scale"), 1.0)
	assert_eq(Global_Manager_Settings.get_value(&"reduce_motion"), false)

func test_values_are_clamped_to_zero_one() -> void:
	Global_Manager_Settings.set_value(&"volume_sfx", -3.0)
	assert_eq(Global_Manager_Settings.get_value(&"volume_sfx"), 0.0)
	Global_Manager_Settings.set_value(&"volume_sfx", 7.0)
	assert_eq(Global_Manager_Settings.get_value(&"volume_sfx"), 1.0)

func test_invalid_requests_are_refused_with_a_warning() -> void:
	assert_false(Global_Manager_Settings.set_value(&"no_such_setting", 1.0))
	assert_false(Global_Manager_Settings.set_value(&"volume_sfx", "loud"))
	assert_false(Global_Manager_Settings.set_value(&"language", &"xx"))
	assert_false(Global_Manager_Settings.set_value(&"reduce_motion", "yes"))
	assert_push_warning_count(4)
	assert_eq(Global_Manager_Settings.get_value(&"language"), &"en", "nothing changed")

func test_reading_an_unknown_setting_warns() -> void:
	assert_null(Global_Manager_Settings.get_value(&"no_such_setting"))
	assert_push_warning_count(1)

# === Applying ===
func test_volume_is_applied_to_the_right_bus_by_name() -> void:
	Global_Manager_Settings.set_value(&"volume_sfx", 0.5)
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.SFX), 0.5, 0.001)
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.MUSIC), 1.0, 0.001, "other buses untouched")
	Global_Manager_Settings.set_value(&"volume_master", 0.25)
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.MASTER), 0.25, 0.001)

func test_language_changes_the_locale_and_translations() -> void:
	Global_Manager_Settings.set_value(&"language", &"fr")
	assert_true(TranslationServer.get_locale().begins_with("fr"))
	assert_eq(tr("ui_back"), "Retour")
	Global_Manager_Settings.set_value(&"language", &"en")
	assert_eq(tr("ui_back"), "Back")

func test_reduce_motion_sets_the_animator_scale() -> void:
	Global_Manager_Settings.set_value(&"reduce_motion", true)
	assert_eq(UI_Animator.motion_scale, 0.0)
	Global_Manager_Settings.set_value(&"reduce_motion", false)
	assert_eq(UI_Animator.motion_scale, 1.0)

func test_rumble_strength_reaches_the_rumble_manager_through_the_bus() -> void:
	Global_Manager_Settings.set_value(&"rumble_scale", 0.4)
	assert_almost_eq(Global_Manager_Rumble.rumble_scale, 0.4, 0.001)

# === Events ===
func test_a_change_is_announced_with_its_key_and_value() -> void:
	watch_signals(Global_Manager_Events)
	Global_Manager_Settings.set_value(&"volume_music", 0.5)
	assert_signal_emitted_with_parameters(Global_Manager_Events, "setting_changed", [&"volume_music", 0.5])

func test_an_unchanged_value_is_not_announced() -> void:
	watch_signals(Global_Manager_Events)
	assert_false(Global_Manager_Settings.set_value(&"volume_music", 1.0))
	assert_signal_not_emitted(Global_Manager_Events, "setting_changed")

func test_a_screen_intent_changes_the_setting() -> void:
	Global_Manager_Events.setting_change_requested.emit(&"volume_music", 0.25)
	assert_eq(Global_Manager_Settings.get_value(&"volume_music"), 0.25)

func test_init_announces_every_setting_so_other_managers_start_in_sync() -> void:
	watch_signals(Global_Manager_Events)
	Global_Manager_Settings.init(TEST_PATH)
	assert_signal_emit_count(Global_Manager_Events, "setting_changed", State_Settings.DEFAULTS.size())

# === Saving ===
func test_settings_survive_a_restart() -> void:
	Global_Manager_Settings.set_value(&"volume_sfx", 0.3)
	Global_Manager_Settings.set_value(&"language", &"fr")
	Global_Manager_Settings.set_value(&"reduce_motion", true)
	Global_Manager_Settings.set_value(&"rumble_scale", 0.6)
	assert_true(Global_Manager_Settings.save_now())
	# "Restart": wipe what is in memory and applied, then start the manager again.
	Global_Manager_Settings.state.reset()
	Logic_Audio_Buses.set_volume(Logic_Audio_Buses.SFX, 1.0)
	UI_Animator.motion_scale = 1.0
	Global_Manager_Settings.init(TEST_PATH)
	assert_eq(Global_Manager_Settings.get_value(&"volume_sfx"), 0.3)
	assert_eq(Global_Manager_Settings.get_value(&"language"), &"fr")
	assert_eq(Global_Manager_Settings.get_value(&"reduce_motion"), true)
	assert_almost_eq(Logic_Audio_Buses.get_volume(Logic_Audio_Buses.SFX), 0.3, 0.001, "applied again at startup")
	assert_eq(UI_Animator.motion_scale, 0.0)
	assert_almost_eq(Global_Manager_Rumble.rumble_scale, 0.6, 0.001)

func test_a_change_autosaves_shortly_after() -> void:
	Global_Manager_Settings.set_value(&"volume_ui", 0.5)
	assert_false(FileAccess.file_exists(TEST_PATH), "not written instantly")
	# Polls instead of a fixed wait, so a slow or busy machine cannot make this flaky.
	await wait_until(func() -> bool: return FileAccess.file_exists(TEST_PATH), 1.5)
	assert_true(FileAccess.file_exists(TEST_PATH))

func test_a_damaged_file_falls_back_to_defaults() -> void:
	_write_raw("garbage")
	Global_Manager_Settings.init(TEST_PATH)
	assert_eq(Global_Manager_Settings.get_value(&"volume_master"), 1.0)
	assert_push_warning_count(1)

func test_bad_values_in_a_file_are_cleaned_not_trusted() -> void:
	_write_raw('{"version": 1, "settings": {"volume_sfx": 9, "language": "xx", "reduce_motion": "yes", "volume_music": 0.4, "bogus": 1}}')
	Global_Manager_Settings.init(TEST_PATH)
	assert_eq(Global_Manager_Settings.get_value(&"volume_sfx"), 1.0, "clamped")
	assert_eq(Global_Manager_Settings.get_value(&"language"), &"en", "unknown language ignored")
	assert_eq(Global_Manager_Settings.get_value(&"reduce_motion"), false, "wrong type ignored")
	assert_eq(Global_Manager_Settings.get_value(&"volume_music"), 0.4, "good values still load")
	assert_push_warning_count(0)

func test_the_settings_file_is_separate_from_the_game_save() -> void:
	assert_ne(Global_Manager_Settings.save_path, Global_Manager_Save.save_path)
