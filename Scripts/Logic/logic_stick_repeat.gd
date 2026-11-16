class_name Logic_Stick_Repeat
extends RefCounted
## === Menu stick repeat: fire once, wait, then repeat while held ===
## Why: pure timing with no nodes, so it is tested with fake time instead of a real stick.

var initial_delay := 0.35
var repeat_rate := 0.12
var threshold := 0.5

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
		return dir != Vector2i.ZERO
	if dir == Vector2i.ZERO:
		return false
	_timer -= delta
	if _timer <= 0.0:
		_timer = repeat_rate
		return true
	return false

func reset() -> void:
	_dir = Vector2i.ZERO
	_timer = 0.0
