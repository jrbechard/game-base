extends Control
## === Debug_Audio_Test: hear the audio core (build step 4f-1 ear test) ===
## All sounds are generated PLACEHOLDER tones. Move focus with keyboard, pad or mouse:
## every move plays the navigate tick and every activation plays the confirm tone, from the
## menu events, with no menu wiring its own sound. The buttons then add:
##   - one button per sound cue in the data (every cue that is not music)
##   - music: play, stop (fade), duck on/off
##   - bus mutes: mute the UI, SFX or Music bus and check that only that kind of sound goes
## F10 quits.

const MUTABLE: Array[StringName] = [&"UI", &"SFX", &"Music"]

var _nav: Component_Focus_Navigator
var _status: Label
var _muted := {}  # bus name -> bool
var _ducked := false

func _ready() -> void:
	# Standalone scene: Main is not running, so start what this test needs.
	Global_Manager_GameData.init()
	Global_Manager_Input.init()
	Global_Manager_SFX.init()
	Global_Manager_Music.init()
	_wrap_sfx_backend_for_logging()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override(&"separation", 12)
	add_child(column)

	var title := Label.new()
	title.text = "AUDIO TEST   placeholder tones   (F10 quits)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	for cue in _sfx_cue_ids():
		column.add_child(_button(String(cue), cue))
	column.add_child(_button("Music: play", &"__music_play"))
	column.add_child(_button("Music: stop (fade)", &"__music_stop"))
	column.add_child(_button("Music: duck on/off", &"__music_duck"))
	for bus in MUTABLE:
		_muted[bus] = false
		column.add_child(_button("", StringName("__mute_" + bus)))
	_refresh_mute_labels(column)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(460, 0)
	column.add_child(_status)

	_nav = Component_Focus_Navigator.new()
	_nav.root = self
	add_child(_nav)
	_nav.activated.connect(_on_activated.bind(column))
	await get_tree().process_frame
	_nav.focus_default()

# Every cue that is not a music track, read from the data, so this scene never lists a
# particular game's sounds and stays the same in every game.
func _sfx_cue_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cue: Data_Audio_Cue in Global_Manager_GameData.get_all_audio_cues():
		if cue.bus != Logic_Audio_Buses.MUSIC:
			ids.append(cue.id)
	ids.sort()
	return ids

func _button(text: String, tag: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta(&"tag", tag)
	b.custom_minimum_size = Vector2(460, 52)
	b.focus_mode = Control.FOCUS_ALL
	b.add_child(Component_Hover_Effect.new())
	return b

func _on_activated(control: Control, column: Control) -> void:
	var tag: StringName = control.get_meta(&"tag")
	print("AUDIO_TEST activated '%s'" % tag)
	match tag:
		&"__music_play":
			Global_Manager_Music.play(&"placeholder_theme")
		&"__music_stop":
			Global_Manager_Music.fade_out()
		&"__music_duck":
			_ducked = not _ducked
			Global_Manager_Music.set_ducked(_ducked)
		_:
			if String(tag).begins_with("__mute_"):
				var bus := StringName(String(tag).trim_prefix("__mute_"))
				_muted[bus] = not _muted[bus]
				Logic_Audio_Buses.set_volume(bus, 0.0 if _muted[bus] else 1.0)
				_refresh_mute_labels(column)
			else:
				Global_Manager_SFX.play(tag)
	_status.text = "%s   |   ducked: %s   muted: %s" % [tag, _ducked, _muted.keys().filter(func(b: StringName) -> bool: return _muted[b])]

func _refresh_mute_labels(column: Control) -> void:
	for child in column.get_children():
		if child is Button and String(child.get_meta(&"tag", &"")).begins_with("__mute_"):
			var bus := StringName(String(child.get_meta(&"tag")).trim_prefix("__mute_"))
			child.text = "%s bus: %s" % [bus, "MUTED" if _muted[bus] else "on"]

# Log every sound the SFX manager makes (cue, bus, level), then pass it on.
func _wrap_sfx_backend_for_logging() -> void:
	var real := Global_Manager_SFX.playback_backend
	Global_Manager_SFX.playback_backend = func(stream: AudioStream, bus: StringName, volume_db: float, pitch: float) -> int:
		print("AUDIO_TEST sound bus=%s volume=%.1f dB pitch=%.3f %s" % [bus, volume_db, pitch, stream.resource_path.get_file()])
		return real.call(stream, bus, volume_db, pitch)

func _exit_tree() -> void:
	for bus in MUTABLE:
		Logic_Audio_Buses.set_volume(bus, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		get_tree().quit()
