class_name Component_Focus_Navigator
extends Node
## === Gamepad, keyboard and mouse focus for any menu ===
## Replaces Ever Blue's hand-written NAVIGATION table: the next control in each direction
## comes from the layout (Godot's focus neighbours, which you can still override in the
## inspector). It listens to the router's actions on the bus, never to raw input.
##
## Screens listen to `activated`, not to each button's `pressed`, so a click is never
## handled twice (a mouse click also arrives as ui_accept).
## One active navigator per screen; stacked menus come with overlays in a later step.

## Focus moved to this control (by any means, including mouse hover).
signal focus_changed(control: Control)
## The player confirmed this control (accept on the focused one, or a click on the hovered one).
signal activated(control: Control)
## The player pressed cancel/back.
signal cancelled
## Left or Right was pressed on a slider or chooser instead of moving focus. `direction` is -1 or +1.
## A Range (HSlider) has already been stepped by the time this fires; a control marked with the
## meta `adjustable` (for example a language chooser) is left for the screen to change.
signal adjusted(control: Control, direction: int)

## The container whose descendants are navigable. Empty = this node's parent.
@export var root: Control
## Control focused by focus_default(). Empty = the first focusable control.
@export var default_focus: Control
## Wrap to the far end of a row or column instead of stopping at the edge.
@export var wrap_around := false
## Off while a screen animates in or out, so input does nothing until it settles.
@export var enabled := true
## Left and Right step a focused slider instead of moving focus.
@export var adjust_ranges := true

var _watched: Dictionary = {}  # Control -> true, controls with hover/focus hooked up
var _hovered: Control
var _returns: Dictionary = {}  # Control -> {Side: Control}, where Up/Down/... leads back to

func _ready() -> void:
	if root == null:
		root = get_parent() as Control
	Global_Manager_Events.ui_action_triggered.connect(_on_action)
	get_tree().node_added.connect(_on_node_added)
	_watch_tree(root)

# === Public ===
## Focus the default control without any sound or event.
func focus_default() -> void:
	var c := default_focus if (default_focus != null and _focusable(default_focus)) else _first_focusable()
	if c != null:
		c.grab_focus()

## The focused control, if it belongs to this navigator.
func focused_control() -> Control:
	var f := get_viewport().gui_get_focus_owner()
	return f if (f != null and _in_scope(f)) else null

# === Actions ===
func _on_action(action: StringName) -> void:
	if not _active():
		return
	match action:
		&"ui_up": _move(SIDE_TOP)
		&"ui_down": _move(SIDE_BOTTOM)
		&"ui_left": _move(SIDE_LEFT)
		&"ui_right": _move(SIDE_RIGHT)
		&"ui_accept": _activate()
		&"ui_cancel":
			cancelled.emit()
			Global_Manager_Events.menu_cancelled.emit()

func _active() -> bool:
	return enabled and root != null and root.is_visible_in_tree()

func _activate() -> void:
	# Why: in mouse mode a click means the control under the cursor, not the focused one.
	var target := _hovered if Global_Manager_Input.device_mode == Global_Manager_Input.DeviceMode.MOUSE else focused_control()
	if target == null or not _focusable(target):
		return
	activated.emit(target)
	Global_Manager_Events.menu_confirmed.emit()

# === Movement ===
func _move(side: Side) -> void:
	var current := focused_control()
	if current == null:
		focus_default()  # nothing focused yet: the first press just lands on the default
		return
	if side == SIDE_LEFT or side == SIDE_RIGHT:
		if _try_adjust(current, -1 if side == SIDE_LEFT else 1):
			return
	# Why: going back the way you came returns to where you were, not to whatever the
	# geometry picks. From a wide Back button, Up returns to the column you left.
	var next := _remembered(current, side)
	if next == null:
		next = _neighbor(current, side)
	if next == null and wrap_around:
		next = _far_end(current, _opposite(side))
	if next == null or next == current:
		return  # at an edge: no move, no sound
	next.grab_focus()
	_returns[next] = {_opposite(side): current}  # only the latest arrival counts
	Global_Manager_Events.menu_navigated.emit()

# Left/Right on a slider or chooser changes it instead of moving focus (even at its limit,
# so focus never slips off a slider sideways). Returns true if the press was used up.
func _try_adjust(c: Control, direction: int) -> bool:
	if adjust_ranges and c is Range:
		var range_control := c as Range
		var step := range_control.step if range_control.step > 0.0 else (range_control.max_value - range_control.min_value) / 20.0
		var next_value := clampf(range_control.value + direction * step, range_control.min_value, range_control.max_value)
		if is_equal_approx(next_value, range_control.value):
			return true  # at the limit: nothing changes and nothing sounds
		range_control.value = next_value
		adjusted.emit(c, direction)
		Global_Manager_Events.menu_adjusted.emit()
		return true
	if c.has_meta(&"adjustable"):
		adjusted.emit(c, direction)
		Global_Manager_Events.menu_adjusted.emit()
		return true
	return false

# The control we arrived from, if it is the way back and still usable.
func _remembered(from: Control, side: Side) -> Control:
	var back = _returns.get(from, {}).get(side)
	if back != null and is_instance_valid(back) and _focusable(back) and _in_scope(back):
		return back
	return null

# The next usable control from `from`, skipping disabled or hidden ones.
func _neighbor(from: Control, side: Side) -> Control:
	var c := from
	for i in 32:  # bounded: a bad neighbour loop must never hang the game
		c = c.find_valid_focus_neighbor(side)
		if c == null or not _in_scope(c):
			return null
		if _focusable(c):
			return c
	return null

# The last control reached by walking the opposite way; used for wrap-around.
func _far_end(from: Control, side: Side) -> Control:
	var c := from
	for i in 32:
		var n := _neighbor(c, side)
		if n == null or n == from:
			break
		c = n
	return c if c != from else null

func _opposite(side: Side) -> Side:
	match side:
		SIDE_LEFT: return SIDE_RIGHT
		SIDE_RIGHT: return SIDE_LEFT
		SIDE_TOP: return SIDE_BOTTOM
	return SIDE_TOP

# === Focus rules ===
func _focusable(c: Control) -> bool:
	if c.focus_mode == Control.FOCUS_NONE or not c.is_visible_in_tree():
		return false
	if c is BaseButton and (c as BaseButton).disabled:
		return false
	return true

func _in_scope(c: Control) -> bool:
	return root != null and (c == root or root.is_ancestor_of(c))

func _first_focusable() -> Control:
	return _find_first(root)

func _find_first(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			if _focusable(child):
				return child
			var deeper := _find_first(child)
			if deeper != null:
				return deeper
	return null

# === Hover and focus hooks ===
func _on_node_added(node: Node) -> void:
	if node is Control and _in_scope(node):
		_watch(node)

func _watch_tree(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			_watch(child)
		_watch_tree(child)

func _watch(c: Control) -> void:
	if _watched.has(c) or c.focus_mode == Control.FOCUS_NONE:
		return
	_watched[c] = true
	c.mouse_entered.connect(_on_hover.bind(c))
	c.mouse_exited.connect(_on_unhover.bind(c))
	c.focus_entered.connect(func() -> void: focus_changed.emit(c))

func _on_hover(c: Control) -> void:
	_hovered = c
	# Why: hover only moves focus in mouse mode, so a resting cursor never steals a pad's focus.
	if not _active() or Global_Manager_Input.device_mode != Global_Manager_Input.DeviceMode.MOUSE:
		return
	if _focusable(c) and focused_control() != c:
		_returns.erase(c)  # arriving by mouse says nothing about a way back
		c.grab_focus()
		Global_Manager_Events.menu_navigated.emit()

func _on_unhover(c: Control) -> void:
	if _hovered == c:
		_hovered = null
