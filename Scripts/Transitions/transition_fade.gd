extends Node

## Reusable full-screen fade. Instance this scene anywhere and call:
##   fade_out(Color.WHITE, 0.6)  -> cover the screen in `color`
##   fade_in(0.6)                -> reveal whatever is behind it
##   cover(Color.WHITE)          -> snap to fully covered (no animation)
## Listen for `fade_finished` to chain the next step.

signal fade_finished

@onready var fade_rect: ColorRect = $CanvasLayer/Fade_Rect

var _tween: Tween

## Cover the screen: alpha 0 -> 1 in the given color.
func fade_out(color: Color = Color.BLACK, duration: float = 0.6) -> void:
	# Keep the requested RGB but start transparent, so we fade the cover IN.
	fade_rect.color = Color(color.r, color.g, color.b, 0.0)
	_tween_alpha(1.0, duration)

## Reveal the screen: alpha 1 -> 0, keeping the current color.
func fade_in(duration: float = 0.6) -> void:
	_tween_alpha(0.0, duration)

## Snap to fully covering the screen in `color`, no animation.
## Use at the start of the NEXT scene before calling fade_in() for a clean handoff.
func cover(color: Color = Color.BLACK) -> void:
	fade_rect.color = Color(color.r, color.g, color.b, 1.0)

func _tween_alpha(target_alpha: float, duration: float) -> void:
	# Kill any in-flight fade first. Without this, a skip that starts the
	# white-out while the fade-in is still running leaves two tweens fighting
	# the rect's alpha — and the wrong one's fade_finished can fire.
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(fade_rect, "color:a", target_alpha, duration)
	_tween.tween_callback(fade_finished.emit)
