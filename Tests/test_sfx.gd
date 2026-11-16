extends GutTest
## === Build step 4f-1 tests: Global_Manager_SFX ===
## The sound-making call is replaced by a recorder, so no audio output is needed.

var _calls: Array = []  # each: [stream, bus, volume_db, pitch]

func before_each() -> void:
	Global_Manager_GameData.init()
	Global_Manager_SFX.init()
	_calls.clear()
	Global_Manager_SFX.rng.seed = 7
	Global_Manager_SFX.playback_backend = func(stream: AudioStream, bus: StringName, volume_db: float, pitch: float) -> int:
		_calls.append([stream, bus, volume_db, pitch])
		return _calls.size()

func after_all() -> void:
	Global_Manager_SFX.init()  # leave it wired to the real player

func _cue(id: StringName, stream_count := 1, bus := &"SFX", volume := 0.0, pitch_range := 0.0, base_pitch := 1.0, trigger := &"") -> Data_Audio_Cue:
	var cue := Data_Audio_Cue.new()
	cue.id = id
	for i in stream_count:
		cue.streams.append(AudioStreamWAV.new())
	cue.bus = bus
	cue.volume_db = volume
	cue.pitch_range = pitch_range
	cue.base_pitch = base_pitch
	cue.trigger_event = trigger
	Global_Manager_SFX.register_cue(cue)
	return cue

# === Playing ===
func test_play_sends_the_cue_values_to_the_backend() -> void:
	var cue := _cue(&"t", 1, &"UI", -3.0, 0.0, 1.5)
	var voice := Global_Manager_SFX.play(&"t", 2.0)
	assert_eq(_calls.size(), 1)
	assert_eq(_calls[0][0], cue.streams[0])
	assert_eq(_calls[0][1], &"UI")
	assert_eq(_calls[0][2], -1.0, "-3 dB plus the +2 offset")
	assert_eq(_calls[0][3], 1.5, "no variation when pitch_range is 0")
	assert_eq(voice, 1, "returns the voice id")

func test_pitch_stays_within_the_range() -> void:
	for i in 30:
		_cue(StringName("p%d" % i), 1, &"SFX", 0.0, 0.1, 1.0)
		Global_Manager_SFX.play(StringName("p%d" % i))
	assert_eq(_calls.size(), 30)
	var low := 10.0
	var high := 0.0
	for c in _calls:
		low = minf(low, c[3])
		high = maxf(high, c[3])
	assert_gte(low, 0.9)
	assert_lte(high, 1.1)
	assert_gt(high - low, 0.05, "the pitch really varies")

func test_several_streams_are_picked_at_random() -> void:
	var cue := _cue(&"multi", 3)
	var used := {}
	for i in 30:
		Global_Manager_SFX.play(&"multi")
		await wait_process_frames(1)  # a new frame each time, so dedup does not apply
	for c in _calls:
		used[c[0]] = true
	assert_eq(used.size(), 3, "all three variations get used")
	assert_eq(cue.streams.size(), 3)

func test_same_frame_duplicates_merge() -> void:
	_cue(&"t")
	Global_Manager_SFX.play(&"t")
	Global_Manager_SFX.play(&"t")
	assert_eq(_calls.size(), 1)

func test_unknown_cue_warns() -> void:
	assert_eq(Global_Manager_SFX.play(&"no_such_cue"), -1)
	assert_push_warning_count(1)
	assert_eq(_calls.size(), 0)

func test_cue_without_streams_warns() -> void:
	_cue(&"empty", 0)
	assert_eq(Global_Manager_SFX.play(&"empty"), -1)
	assert_push_warning_count(1)

func test_missing_bus_falls_back_to_sfx_with_one_warning() -> void:
	_cue(&"lost", 1, &"No_Such_Bus")
	Global_Manager_SFX.play(&"lost")
	await wait_process_frames(1)
	Global_Manager_SFX.play(&"lost")
	assert_eq(_calls.size(), 2)
	assert_eq(_calls[0][1], &"SFX")
	assert_push_warning_count(1)

func test_stopping_with_no_voice_is_safe() -> void:
	Global_Manager_SFX.stop(-1)
	Global_Manager_SFX.stop_all()
	assert_true(true)

# === Bus events ===
# These use events no shipped cue listens to, so only the test cue plays.
func test_event_without_arguments_plays_its_cue() -> void:
	_cue(&"on_saved", 1, &"UI", 0.0, 0.0, 1.0, &"save_completed")
	Global_Manager_Events.save_completed.emit()
	assert_eq(_calls.size(), 1)

func test_event_with_arguments_plays_its_cue() -> void:
	_cue(&"on_scene", 1, &"SFX", 0.0, 0.0, 1.0, &"scene_changed")
	Global_Manager_Events.scene_changed.emit(&"x")
	assert_eq(_calls.size(), 1)

func test_registering_again_does_not_double_play() -> void:
	_cue(&"on_saved", 1, &"UI", 0.0, 0.0, 1.0, &"save_completed")
	_cue(&"on_saved", 1, &"UI", 0.0, 0.0, 1.0, &"save_completed")
	Global_Manager_Events.save_completed.emit()
	assert_eq(_calls.size(), 1)

func test_two_cues_on_the_same_event_both_play() -> void:
	_cue(&"first", 1, &"SFX", 0.0, 0.0, 1.0, &"save_completed")
	_cue(&"second", 1, &"SFX", 0.0, 0.0, 1.0, &"save_completed")
	Global_Manager_Events.save_completed.emit()
	assert_eq(_calls.size(), 2)

func test_unknown_trigger_event_warns() -> void:
	_cue(&"orphan", 1, &"SFX", 0.0, 0.0, 1.0, &"no_such_event")
	assert_push_warning_count(1)

# === The shipped cues ===
func test_shipped_cues_are_valid() -> void:
	var ids := [&"menu_navigate", &"menu_confirm", &"menu_cancel", &"menu_adjust", &"item_acquired"]
	for id in ids:
		var cue := Global_Manager_GameData.get_audio_cue(id)
		assert_not_null(cue, "cue %s exists" % id)
		if cue == null:
			continue
		assert_gt(cue.streams.size(), 0, "%s has a sound" % id)
		assert_true(Logic_Audio_Buses.has_bus(cue.bus), "%s uses a real bus" % id)
		assert_gte(Logic_Bus_Trigger.event_arg_count(Global_Manager_Events, cue.trigger_event), 0, "%s listens to a real bus event" % id)

func test_menu_events_play_the_menu_cues_on_the_ui_bus() -> void:
	Global_Manager_Events.menu_navigated.emit()
	Global_Manager_Events.menu_confirmed.emit()
	Global_Manager_Events.menu_cancelled.emit()
	Global_Manager_Events.menu_adjusted.emit()
	assert_eq(_calls.size(), 4)
	for c in _calls:
		assert_eq(c[1], &"UI")

func test_game_events_play_their_cues_on_the_sfx_bus() -> void:
	Global_Manager_Events.item_acquired.emit(&"example_tool")
	assert_eq(_calls.size(), 1)
	for c in _calls:
		assert_eq(c[1], &"SFX")

func test_music_tracks_are_not_sfx_cues() -> void:
	Global_Manager_SFX.play(&"placeholder_theme")
	assert_push_warning_count(1)
	assert_eq(_calls.size(), 0)
