@tool
class_name UI_Animator
extends Node
## === One animator for slide, fade, scale and shake ===
## Replaces Ever Blue's four animators. It owns ALL motion on its target, so slide and
## shake combine here and no screen script has to add offsets by hand.
##
## Put it under the node to animate (or set `target`). With `animate_children` it
## animates the target's children one after another using `stagger`.
## Calls are awaitable:  await animator.show_animated()
##
## Limit: slide and shake move `position`, which layout containers (VBoxContainer ...)
## reset every layout pass. Fade and scale still work inside containers; for slide and
## shake animate a plain Control wrapper. The editor shows a warning in that case.

## Fired when a show or hide finishes (not when it is interrupted).
signal finished

@export var preset: Data_UI_Animation
## Node to animate. Empty = this node's parent.
@export var target: CanvasItem
@export var animate_children := false
## Seconds between each child's start when animate_children is on.
@export var stagger := 0.05
@export var start_shown := false

## Global speed scale for every animator: 1 = normal, 0 = everything instant.
## Why: a reduce-motion setting (step 4f) sets this one value.
static var motion_scale := 1.0

var is_shown := false

var _tracks: Array[_Track] = []
var _motion := _Batch.new()
var _shake := _Batch.new()

# === Lifecycle ===
func _ready() -> void:
	if Engine.is_editor_hint():
		return  # never touch the edited scene
	_build_tracks()
	is_shown = start_shown
	_set_state(is_shown)
	# Why: layout containers move things on the first frame, so rest positions are
	# re-read after it.
	await get_tree().process_frame
	for t in _tracks:
		t.recapture()

func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if preset == null:
		out.append("Set a preset (a Data_UI_Animation resource).")
	elif preset.moves_position() and _root_is_container():
		out.append("Slide and shake move position, which a layout container overrides. Animate a plain Control wrapper instead, or use fade and scale only.")
	return out

# === Public API ===
func show_instant() -> void:
	_cancel_motion()
	_cancel_shake()
	is_shown = true
	_set_state(true)

func hide_instant() -> void:
	_cancel_motion()
	_cancel_shake()
	is_shown = false
	_set_state(false)

func show_animated() -> void:
	if preset == null or _tracks.is_empty():
		return
	if is_shown and not _motion.busy:
		return  # already fully shown
	is_shown = true
	_cancel_motion()
	if motion_scale <= 0.0:
		_set_state(true)
		finished.emit()
		return
	_prepare_tracks()
	var batch := _Batch.new()
	_motion = batch
	for i in _tracks.size():
		batch.add(_make_in_tween(_tracks[i], i * stagger * motion_scale))
	if await batch.done:
		finished.emit()

func hide_animated() -> void:
	if preset == null or _tracks.is_empty():
		return
	if not is_shown and not _motion.busy:
		return  # already fully hidden
	is_shown = false
	_cancel_motion()
	if motion_scale <= 0.0:
		_set_state(false)
		finished.emit()
		return
	_prepare_tracks()
	var batch := _Batch.new()
	_motion = batch
	for i in _tracks.size():
		batch.add(_make_out_tween(_tracks[i], i * stagger * motion_scale))
	if await batch.done:
		finished.emit()

## A one-shot feedback shake (a wrong move, a refused action). Combines with any slide.
func play_shake() -> void:
	if preset == null or preset.shake_amplitude <= 0.0 or motion_scale <= 0.0:
		return
	_cancel_shake()
	var batch := _Batch.new()
	_shake = batch
	for t in _tracks:
		batch.add(_make_shake_tween(t))
	await batch.done

# === State ===
func _hidden_offset() -> Vector2:
	return preset.slide_direction * preset.slide_distance

func _set_state(shown: bool) -> void:
	if preset == null:
		return
	for t in _tracks:
		t.prepare_pivot(preset)
		t.slide = Vector2.ZERO if shown else _hidden_offset()
		t.alpha = 1.0 if (shown or not preset.fade) else 0.0
		t.scl = 1.0 if shown else preset.scale_hidden
		t.shake = Vector2.ZERO

func _prepare_tracks() -> void:
	for t in _tracks:
		t.recapture()
		t.prepare_pivot(preset)

func _cancel_motion() -> void:
	_motion.cancel()

func _cancel_shake() -> void:
	_shake.cancel()
	for t in _tracks:
		t.shake = Vector2.ZERO

# === Tracks ===
func _get_root() -> CanvasItem:
	return target if target != null else get_parent() as CanvasItem

func _root_is_container() -> bool:
	var root := _get_root()
	if root == null:
		return false
	return root.get_parent() is Container if not animate_children else root is Container

func _build_tracks() -> void:
	_tracks.clear()
	if preset == null:
		push_warning("UI_Animator '%s': no preset set" % name)
		return
	var root := _get_root()
	if root == null:
		push_warning("UI_Animator '%s': no CanvasItem to animate" % name)
		return
	if animate_children:
		for child in root.get_children():
			if child is CanvasItem:
				_tracks.append(_Track.new(child))
	else:
		_tracks.append(_Track.new(root))
	if preset.moves_position() and _root_is_container():
		push_warning("UI_Animator '%s': slide/shake inside a Container is overridden by the layout; animate a plain Control wrapper" % name)

# === Tweens ===
# Each track gets one parallel tween; stages are placed with absolute delays so a show
# with overshoot is "travel to the peak, then settle" without hidden fractions.
func _make_in_tween(t: _Track, delay: float) -> Tween:
	var p := preset
	var ms := motion_scale
	var d_in := p.in_duration * ms
	var settle := p.settle_duration * ms
	var tw := create_tween().set_parallel(true)
	if p.slide_distance > 0.0:
		if p.slide_overshoot > 0.0 and settle > 0.0:
			_to(tw, t, "slide", -p.slide_direction * p.slide_overshoot, d_in, delay, Tween.EASE_OUT)
			_to(tw, t, "slide", Vector2.ZERO, settle, delay + d_in, Tween.EASE_OUT)
		else:
			_to(tw, t, "slide", Vector2.ZERO, d_in, delay, Tween.EASE_OUT)
	if p.fade:
		_to(tw, t, "alpha", 1.0, d_in, delay, Tween.EASE_OUT)
	if p.scale_hidden != 1.0:
		if p.scale_overshoot > 0.0 and settle > 0.0:
			_to(tw, t, "scl", 1.0 + p.scale_overshoot, d_in, delay, Tween.EASE_OUT)
			_to(tw, t, "scl", 1.0, settle, delay + d_in, Tween.EASE_OUT)
		else:
			_to(tw, t, "scl", 1.0, d_in, delay, Tween.EASE_OUT)
	# Why: also fixes the tween's total length, and keeps a no-effect preset valid.
	tw.tween_interval(delay + d_in + settle)
	return tw

func _make_out_tween(t: _Track, delay: float) -> Tween:
	var p := preset
	var ms := motion_scale
	var has_anticipation := p.slide_anticipation > 0.0 or p.scale_anticipation > 0.0
	var d_ant := p.anticipation_duration * ms if has_anticipation else 0.0
	var d_out := p.out_duration * ms
	var exit_at := delay + d_ant
	var tw := create_tween().set_parallel(true)
	if p.slide_distance > 0.0:
		if p.slide_anticipation > 0.0:
			_to(tw, t, "slide", -p.slide_direction * p.slide_anticipation, d_ant, delay, Tween.EASE_OUT)
		_to(tw, t, "slide", _hidden_offset(), d_out, exit_at, Tween.EASE_IN)
	if p.fade:
		_to(tw, t, "alpha", 0.0, d_out, exit_at, Tween.EASE_IN)
	if p.scale_hidden != 1.0:
		if p.scale_anticipation > 0.0:
			_to(tw, t, "scl", 1.0 + p.scale_anticipation, d_ant, delay, Tween.EASE_OUT)
		_to(tw, t, "scl", p.scale_hidden, d_out, exit_at, Tween.EASE_IN)
	tw.tween_interval(exit_at + d_out)
	return tw

func _make_shake_tween(t: _Track) -> Tween:
	var p := preset
	var steps := p.shake_frequency * 2
	var step_time := p.shake_duration * motion_scale / steps
	var tw := create_tween()
	for i in steps:
		var fade_out := 1.0 - float(i) / float(steps)  # each swing is smaller than the last
		var side := 1.0 if i % 2 == 0 else -1.0
		tw.tween_property(t, "shake", Vector2(side * p.shake_amplitude * fade_out, 0.0), step_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(t, "shake", Vector2.ZERO, step_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw

func _to(tw: Tween, t: _Track, prop: String, value: Variant, duration: float, delay: float, ease_type: Tween.EaseType) -> void:
	tw.tween_property(t, prop, value, duration).set_delay(delay) \
			.set_trans(preset.transition).set_ease(ease_type)

# === Inner classes ===
## One animated node. Slide, shake, alpha and scale are kept as separate parts and the
## final position/alpha/scale is rebuilt from all of them, so effects never fight.
class _Track extends RefCounted:
	var node: CanvasItem
	var rest_pos: Vector2
	var rest_scale: Vector2
	var rest_alpha: float
	var slide := Vector2.ZERO:
		set(v):
			slide = v
			_apply()
	var shake := Vector2.ZERO:
		set(v):
			shake = v
			_apply()
	var alpha := 1.0:
		set(v):
			alpha = v
			_apply()
	var scl := 1.0:
		set(v):
			scl = v
			_apply()

	func _init(n: CanvasItem) -> void:
		node = n
		rest_pos = n.get(&"position")
		rest_scale = n.get(&"scale")
		rest_alpha = n.modulate.a

	# Why: if a layout moved the node while it was shown, the new spot becomes the rest.
	func recapture() -> void:
		rest_pos = (node.get(&"position") as Vector2) - slide - shake

	func prepare_pivot(p: Data_UI_Animation) -> void:
		if node is Control and p.scale_hidden != 1.0:
			(node as Control).pivot_offset = (node as Control).size * p.pivot_factor()

	func _apply() -> void:
		if not is_instance_valid(node):
			return
		node.set(&"position", rest_pos + slide + shake)
		node.set(&"scale", rest_scale * scl)
		node.modulate.a = rest_alpha * alpha

## Counts finishing tweens so one `await batch.done` covers many, and releases the awaiter
## (with false) when the batch is cancelled, so an interrupted call never hangs.
class _Batch extends RefCounted:
	signal done(completed: bool)
	var busy := false
	var _pending := 0
	var _tweens: Array[Tween] = []

	func add(tw: Tween) -> void:
		_tweens.append(tw)
		_pending += 1
		busy = true
		tw.finished.connect(_on_one_finished)

	func _on_one_finished() -> void:
		_pending -= 1
		if _pending == 0:
			busy = false
			_tweens.clear()
			done.emit(true)

	func cancel() -> void:
		if _pending == 0:
			return
		for tw in _tweens:
			if tw.is_valid():
				tw.kill()
		_tweens.clear()
		_pending = 0
		busy = false
		done.emit(false)
