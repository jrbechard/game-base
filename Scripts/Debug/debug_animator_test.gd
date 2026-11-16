extends Control
## === Debug_Animator_Test: watch the UI_Animator presets move (build step 4c) ===
## Keys / pad buttons:
##   1 = slide_left on 4 stacked boxes (staggered)   2 = fade box   3 = pop box
##   4 = shake box (shake_small)                      Space = toggle everything
##   M = toggle reduce motion (motion_scale 0 <-> 1)  Esc = quit
## Presets load from Data/UI/Animations/, so edit a .tres and re-run to tune it.

const PRESETS := "res://Data/UI/Animations/"

var _group_anim: UI_Animator
var _fade_anim: UI_Animator
var _pop_anim: UI_Animator
var _shake_anim: UI_Animator
var _status: Label

func _ready() -> void:
	_status = Label.new()
	_status.position = Vector2(40, 20)
	add_child(_status)

	var group := Control.new()  # plain Control, so slide works (not a container)
	group.position = Vector2(120, 120)
	add_child(group)
	for i in 4:
		group.add_child(_box(Vector2(0, i * 70), Color.from_hsv(0.55 + i * 0.05, 0.6, 0.9), "slide %d" % (i + 1)))
	_group_anim = _animator(group, "slide_left", true)

	var fade_box := _box(Vector2(560, 120), Color.CORAL, "fade")
	add_child(fade_box)
	_fade_anim = _animator(fade_box, "fade", false)

	var pop_box := _box(Vector2(560, 260), Color.GOLD, "pop")
	add_child(pop_box)
	_pop_anim = _animator(pop_box, "pop", false)

	var shake_box := _box(Vector2(560, 400), Color.MEDIUM_PURPLE, "shake")
	add_child(shake_box)
	_shake_anim = _animator(shake_box, "shake_small", false)
	_shake_anim.start_shown = true
	_shake_anim.show_instant()

func _box(pos: Vector2, color: Color, text: String) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = Vector2(300, 60)
	var l := Label.new()
	l.text = text
	l.position = Vector2(12, 14)
	l.add_theme_color_override(&"font_color", Color.BLACK)
	r.add_child(l)
	return r

func _animator(node: Node, preset_name: String, children: bool) -> UI_Animator:
	var a := UI_Animator.new()
	a.preset = load(PRESETS + preset_name + ".tres")
	a.animate_children = children
	a.stagger = 0.08
	a.start_shown = true
	node.add_child(a)
	return a

func _toggle(a: UI_Animator) -> void:
	if a.is_shown:
		a.hide_animated()
	else:
		a.show_animated()

# Why: Space and Esc are routed menu keys the input router consumes, so this reads `_input`
# (which runs before the router) and quits with F10.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_1: _toggle(_group_anim)
			KEY_2: _toggle(_fade_anim)
			KEY_3: _toggle(_pop_anim)
			KEY_4: _shake_anim.play_shake()
			KEY_SPACE:
				for a in [_group_anim, _fade_anim, _pop_anim]:
					_toggle(a)
				_shake_anim.play_shake()
			KEY_M: UI_Animator.motion_scale = 0.0 if UI_Animator.motion_scale > 0.0 else 1.0
			KEY_F10: get_tree().quit()
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed and pad.button_index == JOY_BUTTON_A:
		_toggle(_group_anim)

func _process(_delta: float) -> void:
	_status.text = "ANIMATOR TEST   1 slide-stagger  2 fade  3 pop  4 shake  Space all  M reduce-motion  F10 quit\nmotion_scale = %.1f" % UI_Animator.motion_scale
