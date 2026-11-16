@tool
class_name Component_Hover_Effect
extends Node
## === Small focus look: a slight scale-up and brightness on the focused control ===
## Reacts to focus only (Component_Focus_Navigator focuses on mouse hover too), so one
## code path covers keyboard, pad and mouse. Ever Blue's wave and shader tints can be
## added here later once real screens are designed.
## Note: do not combine with a scale-based UI_Animator preset (pop) on the same node at
## the same moment; both write the node's scale.

## Control to affect. Empty = this node's parent.
@export var target: Control
@export var hover_scale := 1.08
## Extra brightness added while focused (0 = none).
@export_range(0.0, 1.0) var brightness := 0.12
@export var duration := 0.12

var _target: Control
var _rest_scale := Vector2.ONE
var _tween: Tween

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_target = target if target != null else get_parent() as Control
	if _target == null:
		push_warning("Component_Hover_Effect '%s': no Control to affect" % name)
		return
	_rest_scale = _target.scale
	_target.focus_entered.connect(_set_hovered.bind(true))
	_target.focus_exited.connect(_set_hovered.bind(false))

func _set_hovered(on: bool) -> void:
	if _tween != null:
		_tween.kill()
	_target.pivot_offset = _target.size * 0.5
	var scale_to := _rest_scale * (hover_scale if on else 1.0)
	var tint := Color(1.0 + brightness, 1.0 + brightness, 1.0 + brightness) if on else Color.WHITE
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_target, "scale", scale_to, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_target, "self_modulate", tint, duration)
