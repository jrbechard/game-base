extends Node
## === Company splash (Club Cabanon) ===
## Ported from Pogne. The logo spins faster and faster, leaving afterimage trails, then the
## screen fades to white. The smear comes from a feedback rig (Accum_Viewport never clears
## and a low-alpha black quad fades the old frames), so the logo's metal shader is untouched.
##
## It sends nothing to other screens: when done it announces `splash_finished` on the bus and
## Main opens the first screen. Any key, pad button or mouse click skips it.
## Differences from Pogne: the whoosh is a data cue (`splash_whoosh`) played through
## Global_Manager_SFX, and there is no bus-volume ride (Picrops has no Amplify on the SFX bus);
## a skip simply fades the stinger and cuts the whooshes at the white-out.

@export_group("Spin")
## Spin speed at scene start, in turns per second (nonzero: the logo already turns on frame one).
@export var start_spin_speed: float = 1.0
## Spin speed at the climax, in turns per second.
@export var peak_spin_speed: float = 12.0
## Time to ramp from start to peak. EASE_IN keeps the acceleration back-loaded (longer trails).
@export var spin_duration: float = 3.0

@export_group("Fade")
@export var fade_in_duration: float = 1.0
## Color the screen fades to at the end. White for the N64-style flash.
@export var fade_color: Color = Color.WHITE
@export var fade_duration: float = 0.6
## Faster white-out used when the player skips.
@export var skip_fade_duration: float = 0.3
## When to start the fade, as a fraction of spin_duration (0-1).
@export_range(0.0, 1.0) var fade_start_ratio: float = 0.8

@export_group("Whoosh")
## Radian offset of the whoosh trigger within each half-turn (the logo whips edge-on every PI).
@export var whoosh_phase_offset: float = PI / 2.0
## Id of the whoosh cue on Global_Manager_SFX.
@export var whoosh_cue: StringName = &"splash_whoosh"
@export var whoosh_volume_db: float = 0.0
## Pitch at slow spin speed and at peak speed.
@export var whoosh_pitch_min: float = 0.9
@export var whoosh_pitch_max: float = 1.6
## Spin speed (turns/sec) at which the whoosh reaches whoosh_pitch_max.
@export var whoosh_speed_for_max_pitch: float = 12.0
## Most whooshes a single frame may fire, so the fast tail builds to a swell, not a wall of noise.
@export var max_whooshes_per_frame: int = 2

@export_group("Stinger")
## The company sound, fired this many seconds into the splash, on its own player.
@export var stinger_delay: float = 2.0
@export var stinger_volume_db: float = 0.0
## How long the stinger takes to fade when the player skips.
@export var stinger_skip_fade: float = 0.3
## On a natural end, let the stinger's tail keep ringing into the next screen (it is moved to
## the tree root and frees itself). A skip fades it out instead.
@export var stinger_persist_on_scene_change: bool = true
## Level the stinger fades to on a skip.
@export var silence_db: float = -60.0

@onready var logo_pivot: Node3D = $Live_Viewport/Logo_Pivot
@onready var transition = $Transition_Fade
@onready var stinger_player: AudioStreamPlayer = $Stinger_Player
@onready var live_viewport: SubViewport = $Live_Viewport
@onready var accum_viewport: SubViewport = $Accum_Viewport
@onready var live_display: TextureRect = $Accum_Viewport/Live_Display
@onready var trail_display: TextureRect = $Trail_Display

var _finishing := false
var _can_skip := false
var _spinning := false
var _spin_speed := 0.0
var _last_spin_y := 0.0

func _ready() -> void:
	# The viewport textures are wired here, not in the scene: a ViewportTexture saved in the
	# .tscn is resolved by path before the SubViewports exist and prints an error on every open.
	live_display.texture = live_viewport.get_texture()
	trail_display.texture = accum_viewport.get_texture()
	# Start fully black so the scene fades up from black.
	transition.cover(Color.BLACK)
	_run()

func _run() -> void:
	transition.fade_in(fade_in_duration)  # not awaited: the spin runs during the fade
	_spin_speed = start_spin_speed
	_last_spin_y = logo_pivot.rotation.y
	_spinning = true
	var spin := create_tween()
	spin.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	spin.tween_property(self, "_spin_speed", peak_spin_speed, spin_duration)
	_play_stinger_after(stinger_delay)
	_can_skip = true
	await get_tree().create_timer(spin_duration * fade_start_ratio).timeout
	_finish(fade_duration)

func _play_stinger_after(delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if _finishing:  # skipped before the stinger's mark: it must not bleed into the next screen
		return
	stinger_player.volume_db = stinger_volume_db
	stinger_player.play()

func _process(delta: float) -> void:
	if not _spinning or delta <= 0.0:
		return
	logo_pivot.rotation.y -= _spin_speed * TAU * delta
	# A whoosh each time the logo whips edge-on: count the PI boundaries crossed this frame.
	# They bunch up as the spin accelerates, so the whooshes speed up on their own.
	var current_y: float = logo_pivot.rotation.y
	var t_last := (_last_spin_y - whoosh_phase_offset) / PI
	var t_cur := (current_y - whoosh_phase_offset) / PI
	var crossings := int(floor(t_last)) - int(floor(t_cur))
	if crossings > 0:
		crossings = mini(crossings, max_whooshes_per_frame)
		var base_pitch := whoosh_pitch_for(_spin_speed)
		for i in crossings:
			Global_Manager_SFX.play(whoosh_cue, whoosh_volume_db, base_pitch)
	_last_spin_y = current_y

## The whoosh pitch for a spin speed: rises from min to max as the logo speeds up.
func whoosh_pitch_for(spin_speed: float) -> float:
	return lerpf(whoosh_pitch_min, whoosh_pitch_max, clampf(spin_speed / whoosh_speed_for_max_pitch, 0.0, 1.0))

func _input(event: InputEvent) -> void:
	if not _can_skip or event.is_echo() or not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		skip()

## Skip to the white-out now (does nothing once the end has started).
func skip() -> void:
	if _can_skip:
		_finish(skip_fade_duration, true)

func _finish(fade_dur: float, is_skip: bool = false) -> void:
	# The natural timeout and a skip both end here; once only.
	if _finishing:
		return
	_finishing = true
	_can_skip = false
	# The logo is deliberately NOT stopped: still spinning as the screen whites out.
	transition.fade_out(fade_color, fade_dur)
	# A skip fades the stinger with the white-out; a natural end lets it ring on.
	if is_skip and stinger_player.playing:
		create_tween().tween_property(stinger_player, "volume_db", silence_db, stinger_skip_fade)
	await transition.fade_finished
	_spinning = false  # the screen is fully white: no new whooshes
	if is_skip:
		Global_Manager_SFX.stop_all()  # a natural end lets the whoosh tails ring into the next screen
	# Let the fully white frame present before the swap.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_skip and stinger_persist_on_scene_change and stinger_player.playing:
		# Carry the tail over: detach the player from this (about to be freed) screen.
		stinger_player.finished.connect(stinger_player.queue_free)
		stinger_player.reparent(get_tree().root)
	elif stinger_player.playing:
		stinger_player.stop()
	Global_Manager_Events.splash_finished.emit()
