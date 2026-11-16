extends Node
## === Music: tracks with crossfade, fade-out and ducking ===
## Ported from Pogne's music manager. Tracks are Data_Audio_Cue resources on the Music bus,
## and two players crossfade, so switching tracks (later: per place) never cuts.
## Idempotent: asking for the track already playing does nothing.

const DUCK_OFFSET_DB := -5.0   # GUESS: how far a ducked track sits below its normal level
const SILENT_DB := -80.0

## Seconds to crossfade into a new track.
var crossfade_duration := 1.0
## Seconds to fade for ducking and fade-out.
var fade_duration := 0.4

var current_track: StringName = &""
var is_ducked := false

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _cue: Data_Audio_Cue
var _tween: Tween
var _tracks: Dictionary = {}  # StringName -> Data_Audio_Cue, the cues on the Music bus

func init() -> void:
	Logic_Audio_Buses.ensure_buses()
	_tracks.clear()
	for cue: Data_Audio_Cue in Global_Manager_GameData.get_all_audio_cues():
		if cue.bus == Logic_Audio_Buses.MUSIC:
			register_track(cue)
	if _players.is_empty():
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.bus = Logic_Audio_Buses.MUSIC
			add_child(p)
			_players.append(p)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for p in _players:
		p.stop()
		p.volume_db = SILENT_DB
	current_track = &""
	is_ducked = false
	_cue = null
	crossfade_duration = 1.0
	fade_duration = 0.4

# Why: release the playing stream at shutdown so the engine finds nothing still in use.
func _exit_tree() -> void:
	_kill_tween()
	for p in _players:
		p.stop()
		p.stream = null

# === Public ===
## Add or replace a track.
func register_track(cue: Data_Audio_Cue) -> void:
	_tracks[cue.id] = cue

## Start a track, crossfading from the current one. `fade` < 0 uses crossfade_duration.
func play(track_id: StringName, fade: float = -1.0) -> void:
	if not _tracks.has(track_id):
		push_warning("Music: no track with id '%s'" % track_id)
		return
	var cue: Data_Audio_Cue = _tracks[track_id]
	if cue.streams.is_empty():
		push_warning("Music: track '%s' has no stream" % track_id)
		return
	if track_id == current_track and _players[_active].playing:
		return
	var seconds := crossfade_duration if fade < 0.0 else fade
	_kill_tween()
	var old := _players[_active]
	_active = 1 - _active
	var next := _players[_active]
	next.stop()  # reuse the player that was fading out, if a fade was interrupted
	next.stream = cue.streams[0]
	next.volume_db = SILENT_DB
	next.play()
	_cue = cue
	current_track = track_id

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(next, "volume_db", _target_db(), seconds)
	if old.playing:
		_tween.tween_property(old, "volume_db", SILENT_DB, seconds)
		_tween.chain().tween_callback(old.stop)

## Fade the current track out, then stop it.
func fade_out(seconds: float = -1.0) -> void:
	var player := _players[_active]
	if not player.playing:
		return
	_kill_tween()
	current_track = &""
	_cue = null
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", SILENT_DB, fade_duration if seconds < 0.0 else seconds)
	_tween.tween_callback(player.stop)

## Dip (true) or restore (false) the track's volume.
func set_ducked(ducked: bool) -> void:
	if ducked == is_ducked:
		return
	is_ducked = ducked
	if _cue == null or not _players[_active].playing:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_players[_active], "volume_db", _target_db(), fade_duration)

func is_playing() -> bool:
	return _players.size() == 2 and (_players[0].playing or _players[1].playing)

## Volume of the track that is playing now (for tests and the debug screen).
func active_volume_db() -> float:
	return _players[_active].volume_db

# === Internals ===
func _target_db() -> float:
	return _cue.volume_db + (DUCK_OFFSET_DB if is_ducked else 0.0)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
