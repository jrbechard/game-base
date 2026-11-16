class_name Logic_Stick_Repeat
extends RefCounted
## === Menu stick repeat: fire once, wait, then repeat while held ===
## Why: pure timing with no nodes, so it is tested with fake time instead of a real stick.

## The longest the player can set the wait before a held direction repeats (the slider's end).
const MAX_INITIAL_DELAY := 0.7

## The wait, in seconds, for the "hold delay" setting (0..1). 0.5 gives 0.35 s.
static func delay_for_setting(setting: float) -> float:
	return clampf(setting, 0.0, 1.0) * MAX_INITIAL_DELAY

var initial_delay := 0.35
var repeat_rate := 0.12
var threshold := 0.5

## True when the last fire came from a NEW press (the direction just changed), false when it
## was a repeat of a held direction. A grid cursor only wraps around an edge on a fresh press.
var last_fire_was_fresh := false

var _dir := Vector2i.ZERO
var _timer := 0.0

## Stick vector -> -1/0/1 per axis, using the threshold.
func direction(raw: Vector2) -> Vector2i:
	return Vector2i(
		1 if raw.x > threshold else (-1 if raw.x < -threshold else 0),
		1 if raw.y > threshold else (-1 if raw.y < -threshold else 0))

## Advance time. Returns true when the direction should fire now.
func update(dir: Vector2i, delta: float) -> bool:
	if dir != _dir:
		# Direction changed (or returned to neutral): fire at once, restart the cadence.
		_dir = dir
		_timer = initial_delay
		last_fire_was_fresh = dir != Vector2i.ZERO
		return dir != Vector2i.ZERO
	if dir == Vector2i.ZERO:
		return false
	_timer -= delta
	if _timer <= 0.0:
		_timer = repeat_rate
		last_fire_was_fresh = false
		return true
	return false

func reset() -> void:
	_dir = Vector2i.ZERO
	_timer = 0.0
