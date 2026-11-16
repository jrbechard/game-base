class_name Data_UI_Animation
extends Resource
## === One reusable animation look for UI_Animator ===
## Define a look once (slide_left, fade, pop, ...) and reuse it. Every duration is
## explicit; nothing is hidden in code. Authored data: read-only at runtime.

enum Pivot {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	CENTER_LEFT, CENTER, CENTER_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT
}

@export_group("Slide")
## The side it enters from, e.g. (-1, 0) slides in from the left. Zero distance = no slide.
@export var slide_direction := Vector2.LEFT
@export var slide_distance := 0.0
## Pixels past the resting spot at the end of a show, before settling back.
@export var slide_overshoot := 0.0
## Pixels pulled back before leaving on a hide.
@export var slide_anticipation := 0.0

@export_group("Fade")
@export var fade := false

@export_group("Scale")
## Scale while hidden. 1.0 = no scale effect, 0.0 = pops in from nothing.
@export var scale_hidden := 1.0
## Extra scale past 1.0 at the end of a show, before settling.
@export var scale_overshoot := 0.0
## Extra scale before shrinking away on a hide.
@export var scale_anticipation := 0.0
## Where the scale grows from (Controls only).
@export var pivot := Pivot.CENTER

@export_group("Timing")
## Show: time to reach the overshoot peak (or the resting spot when there is no overshoot).
@export var in_duration := 0.3
## Show: time to settle from the overshoot peak back to rest.
@export var settle_duration := 0.1
## Hide: time of the pull-back before leaving (used only when an anticipation is set).
@export var anticipation_duration := 0.08
## Hide: time of the exit itself.
@export var out_duration := 0.22
@export var transition := Tween.TRANS_CUBIC

@export_group("Shake")
@export var shake_amplitude := 0.0
@export var shake_frequency := 5
@export var shake_duration := 0.4

## True when this look moves the node's position (slide or shake). Position effects are
## overridden by layout containers, so UI_Animator warns about that case.
func moves_position() -> bool:
	return slide_distance > 0.0 or shake_amplitude > 0.0

func pivot_factor() -> Vector2:
	match pivot:
		Pivot.TOP_LEFT: return Vector2(0.0, 0.0)
		Pivot.TOP_CENTER: return Vector2(0.5, 0.0)
		Pivot.TOP_RIGHT: return Vector2(1.0, 0.0)
		Pivot.CENTER_LEFT: return Vector2(0.0, 0.5)
		Pivot.CENTER_RIGHT: return Vector2(1.0, 0.5)
		Pivot.BOTTOM_LEFT: return Vector2(0.0, 1.0)
		Pivot.BOTTOM_CENTER: return Vector2(0.5, 1.0)
		Pivot.BOTTOM_RIGHT: return Vector2(1.0, 1.0)
	return Vector2(0.5, 0.5)
