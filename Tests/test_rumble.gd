extends GutTest
## === Build step 4e boundary tests: Global_Manager_Rumble ===
## The hardware call is replaced by a recorder, so these run with no pad plugged in.

const TEST_SAVE := "user://test_rumble_save.json"

var _device := 0
var _calls: Array = []  # each: [device, weak, strong, duration]

func before_each() -> void:
	Global_Manager_GameData.init()
	_device = 0
	_calls.clear()
	Global_Manager_Rumble.init(func() -> int: return _device)
	Global_Manager_Rumble.backend = func(d: int, w: float, s: float, t: float) -> void:
		_calls.append([d, w, s, t])

func after_all() -> void:
	# Hand rumble back to the real input source for any test that runs after this one.
	Global_Manager_Rumble.init(func() -> int:
		return Global_Manager_Input.source.get_device() if Global_Manager_Input.source != null else -1)

func _fx(id: StringName, weak := 0.5, strong := 0.25, duration := 0.03, pulses := 1, gap := 0.03, trigger := &"") -> Data_Rumble_Effect:
	var fx := Data_Rumble_Effect.new()
	fx.id = id
	fx.weak = weak
	fx.strong = strong
	fx.duration = duration
	fx.pulses = pulses
	fx.gap = gap
	fx.trigger_event = trigger
	Global_Manager_Rumble.register_effect(fx)
	return fx

# === Playing ===
func test_play_sends_scaled_values_to_the_active_pad() -> void:
	_fx(&"tap", 0.5, 0.25)
	Global_Manager_Rumble.play(&"tap")
	assert_eq(_calls.size(), 1)
	assert_eq(_calls[0], [0, 0.5, 0.25, 0.03])

func test_gain_and_master_scale_multiply_and_clamp() -> void:
	_fx(&"tap", 0.5, 0.8)
	Global_Manager_Rumble.rumble_scale = 0.5
	Global_Manager_Rumble.play(&"tap", 2.0)
	assert_almost_eq(_calls[0][1], 0.5, 0.0001, "0.5 * gain 2 * scale 0.5")
	assert_almost_eq(_calls[0][2], 0.8, 0.0001, "0.8 * 2 * 0.5")
	Global_Manager_Rumble.rumble_scale = 1.0
	_calls.clear()
	await wait_process_frames(1)  # a new frame, so dedup does not apply
	Global_Manager_Rumble.play(&"tap", 5.0)
	assert_eq(_calls[0][2], 1.0, "never above 1")

func test_keyboard_or_no_pad_does_nothing() -> void:
	_fx(&"tap")
	_device = -1
	Global_Manager_Rumble.play(&"tap")
	assert_eq(_calls.size(), 0)

func test_master_scale_zero_is_silent() -> void:
	_fx(&"tap")
	Global_Manager_Rumble.rumble_scale = 0.0
	Global_Manager_Rumble.play(&"tap")
	assert_eq(_calls.size(), 0)

func test_same_frame_duplicates_merge() -> void:
	_fx(&"tap")
	Global_Manager_Rumble.play(&"tap")
	Global_Manager_Rumble.play(&"tap")
	assert_eq(_calls.size(), 1)

func test_unknown_effect_warns_and_sends_nothing() -> void:
	Global_Manager_Rumble.play(&"no_such_cue")
	assert_eq(_calls.size(), 0)
	assert_push_warning_count(1)

# === Pulse trains ===
func test_pulse_train_sends_every_pulse() -> void:
	_fx(&"triple", 0.5, 0.5, 0.03, 3, 0.03)
	Global_Manager_Rumble.play(&"triple")
	assert_eq(_calls.size(), 1, "first pulse is immediate")
	await wait_seconds(0.4)
	assert_eq(_calls.size(), 3)

func test_stop_all_cancels_a_running_train_and_stops_the_pad() -> void:
	_fx(&"long", 0.5, 0.5, 0.05, 4, 0.05)
	Global_Manager_Rumble.play(&"long")
	await wait_seconds(0.12)
	Global_Manager_Rumble.stop_all()
	var sent := _calls.size()
	await wait_seconds(0.4)
	assert_eq(_calls.size(), sent, "no more pulses after stop_all")
	assert_eq(_calls[_calls.size() - 1], [0, 0.0, 0.0, 0.0], "the last call tells the pad to stop")
	var buzzes := _calls.filter(func(c: Array) -> bool: return c[1] > 0.0)
	assert_lt(buzzes.size(), 4)

# === Bus wiring ===
func test_event_without_arguments_fires_its_effect() -> void:
	_fx(&"on_confirm", 0.4, 0.4, 0.03, 1, 0.03, &"menu_confirmed")
	Global_Manager_Events.menu_confirmed.emit()
	assert_eq(_calls.size(), 1)

func test_event_with_arguments_fires_its_effect() -> void:
	_fx(&"on_scene", 0.4, 0.4, 0.03, 1, 0.03, &"scene_changed")
	Global_Manager_Events.scene_changed.emit(&"anything")
	assert_eq(_calls.size(), 1)

func test_unknown_trigger_event_warns_but_the_effect_still_plays_by_hand() -> void:
	_fx(&"orphan", 0.4, 0.4, 0.03, 1, 0.03, &"no_such_event")
	assert_push_warning_count(1)
	Global_Manager_Rumble.play(&"orphan")
	assert_eq(_calls.size(), 1)

func test_registering_an_effect_again_does_not_double_fire() -> void:
	_fx(&"on_confirm", 0.4, 0.4, 0.03, 1, 0.03, &"menu_confirmed")
	_fx(&"on_confirm", 0.4, 0.4, 0.03, 1, 0.03, &"menu_confirmed")
	Global_Manager_Events.menu_confirmed.emit()
	assert_eq(_calls.size(), 1)

# === Settings and preview (step 4f-2) ===
func test_the_strength_setting_event_changes_the_master_scale() -> void:
	Global_Manager_Events.setting_changed.emit(&"rumble_scale", 0.5)
	assert_almost_eq(Global_Manager_Rumble.rumble_scale, 0.5, 0.001)
	Global_Manager_Events.setting_changed.emit(&"volume_music", 0.1)
	assert_almost_eq(Global_Manager_Rumble.rumble_scale, 0.5, 0.001, "other settings are ignored")

func test_a_preview_request_gives_a_sample_buzz_at_the_current_strength() -> void:
	Global_Manager_Events.setting_changed.emit(&"rumble_scale", 0.5)
	Global_Manager_Events.rumble_preview_requested.emit()
	assert_eq(_calls.size(), 1)
	var preview := Global_Manager_GameData.get_rumble_effect(&"preview")
	assert_almost_eq(float(_calls[0][1]), preview.weak * 0.5, 0.001)

# === The shipped cues ===
func test_starter_cues_load_and_trigger_real_bus_events() -> void:
	var bus_events: Array = Global_Manager_Events.get_script().get_script_signal_list().map(func(s: Dictionary) -> String: return s["name"])
	for id in [&"item_acquired"]:
		var fx := Global_Manager_GameData.get_rumble_effect(id)
		assert_not_null(fx, "cue %s exists" % id)
		if fx == null:
			continue
		assert_true(fx.weak >= 0.0 and fx.weak <= 1.0 and fx.strong >= 0.0 and fx.strong <= 1.0, "%s strengths in range" % id)
		assert_gt(fx.duration, 0.0)
		assert_gte(fx.pulses, 1)
		assert_true(bus_events.has(String(fx.trigger_event)), "%s triggers on a real bus event" % id)

# === End to end: intent -> Progress -> item_acquired -> rumble ===
func test_granting_an_item_buzzes_the_pad() -> void:
	# A separate save path, so the real save is never touched by this test.
	Global_Manager_Progress.init()
	Global_Manager_Progress.state.from_dict({})
	Global_Manager_Save.init([Global_Manager_Progress.state], TEST_SAVE)
	Global_Manager_Events.item_grant_requested.emit(&"example_tool")
	await wait_seconds(0.5)  # also lets the autosave finish into the test file
	var fx := Global_Manager_GameData.get_rumble_effect(&"item_acquired")
	assert_eq(_calls.size(), fx.pulses, "one buzz per pulse of the item_acquired cue")
	assert_eq(_calls[0][0], 0, "on the active pad")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
	Global_Manager_Progress.state.from_dict({})
	Global_Manager_Save.init([Global_Manager_Progress.state])  # back to the real path
