extends GutTest
## === The company splash: its pitch maths and its whoosh cue (no Main needed) ===

func test_the_whoosh_pitch_rises_with_the_spin() -> void:
	var splash: Node = load("res://Scenes/Shell/shell_splash.tscn").instantiate()
	autofree(splash)
	assert_almost_eq(splash.whoosh_pitch_for(0.0), splash.whoosh_pitch_min, 0.001)
	assert_almost_eq(splash.whoosh_pitch_for(999.0), splash.whoosh_pitch_max, 0.001)
	assert_gt(splash.whoosh_pitch_for(10.0), splash.whoosh_pitch_for(2.0))

func test_the_whoosh_is_a_cue_the_sfx_manager_knows() -> void:
	Global_Manager_Events.init()
	Global_Manager_GameData.init()
	Global_Manager_SFX.init()
	var heard: Array = []
	Global_Manager_SFX.playback_backend = func(_s: AudioStream, _b: StringName, _v: float, pitch: float) -> int:
		heard.append(pitch)
		return 1
	Global_Manager_SFX.play(&"splash_whoosh", 0.0, 1.5)
	assert_eq(heard.size(), 1)
	assert_almost_eq(heard[0], 1.5, 0.001)
	Global_Manager_SFX.init()
