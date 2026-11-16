extends GutTest
## === Build step 4c boundary tests: UI_Animator ===
## Real (short) durations, so these also prove the awaits resolve.

const REST := Vector2(100, 50)

var _holder: Control

func before_each() -> void:
	UI_Animator.motion_scale = 1.0
	_holder = Control.new()
	add_child_autofree(_holder)

func after_each() -> void:
	UI_Animator.motion_scale = 1.0

# A fast preset with every effect, so the tests stay quick.
func _preset(slide := true, fade := true, shake := false) -> Data_UI_Animation:
	var p := Data_UI_Animation.new()
	p.slide_direction = Vector2.LEFT
	p.slide_distance = 60.0 if slide else 0.0
	p.slide_overshoot = 8.0 if slide else 0.0
	p.slide_anticipation = 4.0 if slide else 0.0
	p.fade = fade
	p.in_duration = 0.08
	p.settle_duration = 0.04
	p.anticipation_duration = 0.03
	p.out_duration = 0.08
	if shake:
		p.shake_amplitude = 6.0
		p.shake_duration = 0.12
	return p

func _box(pos := REST, parent: Node = null) -> ColorRect:
	var c := ColorRect.new()
	c.size = Vector2(40, 20)
	c.position = pos
	(parent if parent != null else _holder).add_child(c)
	return c

func _animator(box: Control, p: Data_UI_Animation, start_shown := true) -> UI_Animator:
	var a := UI_Animator.new()
	a.preset = p
	a.start_shown = start_shown
	box.add_child(a)
	return a

# === State ===
func test_hide_instant_then_show_instant_restores_rest() -> void:
	var box := _box()
	var a := _animator(box, _preset())
	a.hide_instant()
	assert_eq(box.modulate.a, 0.0, "faded out")
	assert_eq(box.position, REST + Vector2(-60, 0), "slid to the hidden side")
	a.show_instant()
	assert_eq(box.position, REST)
	assert_eq(box.modulate.a, 1.0)

func test_start_hidden_applies_the_hidden_look() -> void:
	var box := _box()
	_animator(box, _preset(), false)
	assert_eq(box.modulate.a, 0.0)

# === Animated show and hide ===
func test_show_animated_ends_exactly_at_rest_and_finishes() -> void:
	var box := _box()
	var a := _animator(box, _preset(), false)
	await wait_process_frames(2)
	watch_signals(a)
	await a.show_animated()
	assert_true(a.is_shown)
	assert_eq(box.position, REST)
	assert_eq(box.modulate.a, 1.0)
	assert_signal_emitted(a, "finished")

func test_hide_animated_ends_hidden() -> void:
	var box := _box()
	var a := _animator(box, _preset())
	await wait_process_frames(2)
	await a.hide_animated()
	assert_false(a.is_shown)
	assert_eq(box.modulate.a, 0.0)
	assert_eq(box.position, REST + Vector2(-60, 0))

func test_scale_effect_pops_from_nothing() -> void:
	var p := _preset(false, true)
	p.scale_hidden = 0.0
	p.scale_overshoot = 0.1
	var box := _box()
	var a := _animator(box, p, false)
	# Why: Godot clamps a Control's scale to 0.00001, never exactly zero.
	assert_almost_eq(box.scale, Vector2.ZERO, Vector2(0.001, 0.001))
	await wait_process_frames(2)
	await a.show_animated()
	assert_eq(box.scale, Vector2.ONE)

# === Combining effects: the Ever Blue problem ===
func test_slide_plus_shake_end_exactly_at_rest() -> void:
	var box := _box()
	var a := _animator(box, _preset(true, true, true), false)
	await wait_process_frames(2)
	a.show_animated()  # not awaited: shake runs at the same time
	a.play_shake()
	await wait_seconds(0.4)
	assert_eq(box.position, REST, "no drift after slide and shake together")

# === Stagger ===
func test_children_start_one_after_another() -> void:
	var p := _preset(false, true)
	var group := _box(Vector2.ZERO)
	var kids := [_box(Vector2(0, 0), group), _box(Vector2(0, 30), group), _box(Vector2(0, 60), group)]
	var a := UI_Animator.new()
	a.preset = p
	a.animate_children = true
	a.stagger = 0.2
	a.start_shown = false
	group.add_child(a)
	await wait_process_frames(2)
	a.show_animated()
	await wait_seconds(0.13)
	assert_gt(kids[0].modulate.a, 0.9, "first child is done")
	assert_lt(kids[1].modulate.a, 0.05, "second child has not started")
	assert_eq(kids[2].modulate.a, 0.0, "third child has not started")
	await wait_seconds(0.5)
	assert_eq(kids[2].modulate.a, 1.0, "all shown in the end")

# === Interruptions and settings ===
func test_hide_interrupting_a_show_ends_hidden_and_releases_the_first_call() -> void:
	var box := _box()
	var a := _animator(box, _preset(), false)
	await wait_process_frames(2)
	var state := {"first_returned": false}
	var first := func() -> void:
		await a.show_animated()
		state["first_returned"] = true
	first.call()
	await wait_seconds(0.03)
	await a.hide_animated()
	assert_true(state["first_returned"], "the interrupted show did not hang")
	assert_false(a.is_shown)
	assert_eq(box.modulate.a, 0.0)

func test_motion_scale_zero_is_instant() -> void:
	UI_Animator.motion_scale = 0.0
	var box := _box()
	var a := _animator(box, _preset(), false)
	await wait_process_frames(2)
	var start := Time.get_ticks_msec()
	await a.show_animated()
	assert_lt(Time.get_ticks_msec() - start, 40, "returned at once")
	assert_eq(box.modulate.a, 1.0)
	assert_eq(box.position, REST)

func test_slide_inside_a_container_warns() -> void:
	var vbox := VBoxContainer.new()
	_holder.add_child(vbox)
	var box := _box(Vector2.ZERO, vbox)
	_animator(box, _preset(true, false))
	assert_push_warning_count(1)

func test_fade_inside_a_container_does_not_warn() -> void:
	var vbox := VBoxContainer.new()
	_holder.add_child(vbox)
	var box := _box(Vector2.ZERO, vbox)
	var p := _preset(false, true)
	_animator(box, p)
	assert_push_warning_count(0)
