extends GutTest
## === Build step 4f-1 tests: Global_Manager_Music ===
## Short fades and tiny generated tracks, so the tests run in a few seconds.

const TARGET_DB := -10.0

func before_each() -> void:
	Global_Manager_GameData.init()
	Global_Manager_Music.init()
	Global_Manager_Music.crossfade_duration = 0.1
	Global_Manager_Music.fade_duration = 0.1
	Global_Manager_Music.register_track(_track(&"a"))
	Global_Manager_Music.register_track(_track(&"b"))

func after_all() -> void:
	Global_Manager_Music.init()

# A one-second silent loop, so it keeps "playing" for the whole test.
func _track(id: StringName) -> Data_Audio_Cue:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(22050 * 2)
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 22050
	var cue := Data_Audio_Cue.new()
	cue.id = id
	cue.streams.append(wav)
	cue.bus = &"Music"
	cue.volume_db = TARGET_DB
	return cue

func _playing_count() -> int:
	var n := 0
	for p in Global_Manager_Music._players:
		if p.playing:
			n += 1
	return n

func test_play_starts_the_track_and_fades_up_to_its_level() -> void:
	Global_Manager_Music.play(&"a")
	assert_eq(Global_Manager_Music.current_track, &"a")
	assert_true(Global_Manager_Music.is_playing())
	await wait_seconds(0.3)
	assert_almost_eq(Global_Manager_Music.active_volume_db(), TARGET_DB, 0.5)

func test_asking_for_the_playing_track_does_nothing() -> void:
	Global_Manager_Music.play(&"a")
	var active_before: int = Global_Manager_Music._active
	await wait_seconds(0.3)
	Global_Manager_Music.play(&"a")
	assert_eq(Global_Manager_Music._active, active_before, "no restart, no swap")
	assert_eq(_playing_count(), 1)

func test_crossfade_leaves_only_the_new_track_playing() -> void:
	Global_Manager_Music.play(&"a")
	await wait_seconds(0.3)
	Global_Manager_Music.play(&"b")
	assert_eq(_playing_count(), 2, "both play during the crossfade")
	await wait_seconds(0.3)
	assert_eq(Global_Manager_Music.current_track, &"b")
	assert_eq(_playing_count(), 1, "the old track stopped")
	assert_almost_eq(Global_Manager_Music.active_volume_db(), TARGET_DB, 0.5)

func test_interrupted_crossfade_still_ends_with_one_track() -> void:
	Global_Manager_Music.play(&"a")
	await wait_seconds(0.3)
	Global_Manager_Music.play(&"b")
	await wait_seconds(0.04)
	Global_Manager_Music.play(&"a")  # change of mind in the middle of the fade
	await wait_seconds(0.4)
	assert_eq(Global_Manager_Music.current_track, &"a")
	assert_eq(_playing_count(), 1)

func test_fade_out_stops_the_music() -> void:
	Global_Manager_Music.play(&"a")
	await wait_seconds(0.3)
	Global_Manager_Music.fade_out()
	assert_eq(Global_Manager_Music.current_track, &"")
	await wait_seconds(0.3)
	assert_false(Global_Manager_Music.is_playing())

func test_ducking_dips_and_restores_the_level() -> void:
	Global_Manager_Music.play(&"a")
	await wait_seconds(0.3)
	Global_Manager_Music.set_ducked(true)
	await wait_seconds(0.25)
	assert_almost_eq(Global_Manager_Music.active_volume_db(), TARGET_DB + Global_Manager_Music.DUCK_OFFSET_DB, 0.5)
	Global_Manager_Music.set_ducked(false)
	await wait_seconds(0.25)
	assert_almost_eq(Global_Manager_Music.active_volume_db(), TARGET_DB, 0.5)

func test_duck_before_play_applies_to_the_next_track() -> void:
	Global_Manager_Music.set_ducked(true)
	Global_Manager_Music.play(&"a")
	await wait_seconds(0.3)
	assert_almost_eq(Global_Manager_Music.active_volume_db(), TARGET_DB + Global_Manager_Music.DUCK_OFFSET_DB, 0.5)

func test_unknown_track_warns_and_plays_nothing() -> void:
	Global_Manager_Music.play(&"no_such_track")
	assert_push_warning_count(1)
	assert_false(Global_Manager_Music.is_playing())

func test_the_shipped_placeholder_track_loads_on_the_music_bus() -> void:
	var cue := Global_Manager_GameData.get_audio_cue(&"placeholder_theme")
	assert_not_null(cue)
	assert_eq(cue.bus, Logic_Audio_Buses.MUSIC)
	assert_gt(cue.streams.size(), 0)
	Global_Manager_Music.play(&"placeholder_theme")
	assert_eq(Global_Manager_Music.current_track, &"placeholder_theme")
	assert_true(Global_Manager_Music.is_playing())
	Global_Manager_Music.init()
