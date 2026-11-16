class_name Logic_Stopwatch
extends RefCounted
## === A stopwatch that counts up ===
## Pure logic, no nodes: feed it the frame time while something is running, so it is tested with
## fake time. It counts seconds, never stops by itself and has no limit.

var elapsed := 0.0
var running := false

## Advance time. Does nothing while stopped.
func update(delta: float) -> void:
	if running and delta > 0.0:
		elapsed += delta

func start() -> void:
	running = true

func stop() -> void:
	running = false

func reset() -> void:
	elapsed = 0.0

## Put back a saved time (a damaged or negative value becomes 0).
func restore(seconds: float) -> void:
	elapsed = maxf(seconds, 0.0) if is_finite(seconds) else 0.0

## Seconds as hours:minutes:seconds, like Picross S ("00:02:00").
static func format(seconds: float) -> String:
	var total := maxi(int(floorf(seconds)), 0)
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
