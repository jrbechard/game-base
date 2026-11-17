extends Node
## === SFX: every one-shot sound cue (effects, menu sounds, ui) ===
## Ported from Pogne's SFX manager, with: sounds as data (Data_Audio_Cue, not a string
## library), cues that fire themselves from bus events, the bus chosen per cue (this also
## replaces Ever Blue's separate UI_Audio manager), and no hard-coded bus numbers.
## Keeps Pogne's same-frame dedup, pitch jitter, voice ids, and the explicit bus on every
## voice (since Godot 4.3 a voice would otherwise default to Master).
##
## `playback_backend` is the one function that makes sound; tests replace it with a recorder.

const MAX_POLYPHONY := 32

## (stream: AudioStream, bus: StringName, volume_db: float, pitch: float) -> int voice id
var playback_backend: Callable = Callable(self, &"_play_polyphonic")
var debug_print := false
## Replaceable in tests so pitch and stream choice are deterministic.
var rng := RandomNumberGenerator.new()

var _player: AudioStreamPlayer
var _playback: AudioStreamPlaybackPolyphonic
var _cues: Dictionary = {}              # StringName -> Data_Audio_Cue
var _connections: Array[Dictionary] = []  # {id, event, callable}
var _last_play_frame: Dictionary = {}   # cue id -> process frame of its last play
var _warned_missing_bus: Dictionary = {}

func init() -> void:
	Logic_Audio_Buses.ensure_buses()
	_disconnect_all()
	_cues.clear()
	_last_play_frame.clear()
	_warned_missing_bus.clear()
	playback_backend = Callable(self, &"_play_polyphonic")
	rng.randomize()
	_ensure_player()
	for cue: Data_Audio_Cue in Global_Manager_GameData.get_all_audio_cues():
		if cue.bus != Logic_Audio_Buses.MUSIC:  # music tracks belong to Global_Manager_Music
			register_cue(cue)

func _ensure_player() -> void:
	if _player != null:
		return
	_player = AudioStreamPlayer.new()
	var stream := AudioStreamPolyphonic.new()
	stream.polyphony = MAX_POLYPHONY
	_player.stream = stream
	_player.bus = Logic_Audio_Buses.SFX
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamPlaybackPolyphonic

# Why no shutdown cleanup here: the "AudioStreamPlaybackPolyphonic leaked at exit" warning
# comes from Godot itself. Its AudioServer lets go of a playing stream a few frames after
# the player stops, and quitting gives it no such frames. An empty project with one playing
# AudioStreamPlayer leaks the same way, and freeing the player in _exit_tree did not help.

# === Cues ===
## Add or replace a cue. Connects its trigger event, if it has one.
func register_cue(cue: Data_Audio_Cue) -> void:
	_disconnect_for(cue.id)
	_cues[cue.id] = cue
	if cue.trigger_event == &"":
		return
	var handler: Callable
	if cue.pitch_from_value:
		handler = Logic_Bus_Trigger.connect_trigger_value(Global_Manager_Events, cue.trigger_event, _on_trigger_value.bind(cue))
	else:
		handler = Logic_Bus_Trigger.connect_trigger(Global_Manager_Events, cue.trigger_event, _on_trigger.bind(cue))
	if not handler.is_valid():
		push_warning("SFX: cue '%s' triggers on '%s', which is not an event on the bus" % [cue.id, cue.trigger_event])
		return
	_connections.append({"id": cue.id, "event": cue.trigger_event, "callable": handler})

func _on_trigger(cue: Data_Audio_Cue) -> void:
	_play_cue(cue, 0.0)

# The event's value (0 to 1) picks the pitch between the cue's two ends.
func _on_trigger_value(value: Variant, cue: Data_Audio_Cue) -> void:
	_play_cue(cue, 0.0, pitch_for_value(cue, float(value)))

## The pitch multiplier a cue uses for an event value (clamped to 0..1).
static func pitch_for_value(cue: Data_Audio_Cue, value: float) -> float:
	return lerpf(cue.value_pitch_min, cue.value_pitch_max, clampf(value, 0.0, 1.0))

# === Playing ===
## Play a cue by hand. Returns a voice id for stop(), or -1 if nothing played.
## `pitch_scale` multiplies the cue's pitch (used by the splash whoosh, which rises as it speeds up).
func play(id: StringName, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> int:
	if not _cues.has(id):
		push_warning("SFX: no cue with id '%s'" % id)
		return -1
	return _play_cue(_cues[id], volume_offset_db, pitch_scale)

func _play_cue(cue: Data_Audio_Cue, volume_offset_db: float, pitch_scale: float = 1.0) -> int:
	if cue.streams.is_empty():
		push_warning("SFX: cue '%s' has no streams" % cue.id)
		return -1
	# Same-frame dedup: the same cue twice in one frame stacks into one doubled, phasey voice.
	var frame := Engine.get_process_frames()
	if _last_play_frame.get(cue.id, -1) == frame:
		return -1
	_last_play_frame[cue.id] = frame

	var stream: AudioStream = cue.streams[rng.randi() % cue.streams.size()]
	var pitch := cue.base_pitch * pitch_scale * rng.randf_range(1.0 - cue.pitch_range, 1.0 + cue.pitch_range)
	var bus := cue.bus
	if not Logic_Audio_Buses.has_bus(bus):
		if not _warned_missing_bus.has(cue.id):
			_warned_missing_bus[cue.id] = true
			push_warning("SFX: cue '%s' uses bus '%s', which does not exist; using SFX" % [cue.id, bus])
		bus = Logic_Audio_Buses.SFX
	var volume := cue.volume_db + volume_offset_db
	if debug_print:
		print("[SFX] %s on %s  %.1f dB  pitch %.3f" % [cue.id, bus, volume, pitch])
	return playback_backend.call(stream, bus, volume, pitch)

## Stop one voice (the id play() returned). Safe with -1.
func stop(voice_id: int) -> void:
	if _playback != null and voice_id >= 0:
		_playback.stop_stream(voice_id)

## Cut every sound, including ringing tails. Restarting the player drops all voices.
func stop_all() -> void:
	if _player == null:
		return
	_player.stop()
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamPlaybackPolyphonic

# === Hardware ===
func _play_polyphonic(stream: AudioStream, bus: StringName, volume_db: float, pitch: float) -> int:
	if _playback == null:
		return -1
	# Bus passed explicitly: play_stream defaults the voice to Master otherwise.
	return _playback.play_stream(stream, 0.0, volume_db, pitch, AudioServer.PLAYBACK_TYPE_DEFAULT, bus)

# === Bus wiring ===
func _disconnect_for(id: StringName) -> void:
	for i in range(_connections.size() - 1, -1, -1):
		if _connections[i]["id"] == id:
			Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, _connections[i]["event"], _connections[i]["callable"])
			_connections.remove_at(i)

func _disconnect_all() -> void:
	for c in _connections:
		Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, c["event"], c["callable"])
	_connections.clear()
