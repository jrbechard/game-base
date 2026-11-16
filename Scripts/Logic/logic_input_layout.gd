class_name Logic_Input_Layout
extends RefCounted
## === Pure functions: which kind of pad is this, and which buttons mean what ===
## Why: no nodes and no pad needed, so the layout rules are testable with real pad names.

## XBOX means "standard layout" (any non-Nintendo pad); SWITCH means Nintendo's A/B layout.
enum GamepadType { NONE, XBOX, SWITCH }

static func gamepad_type_from_name(joy_name: String) -> GamepadType:
	var n := joy_name.to_lower()
	if n.is_empty():
		return GamepadType.NONE
	var nintendo := n.contains("nintendo") or n.contains("switch") \
			or n.contains("joy-con") or n.contains("joycon") or n.contains("pro controller")
	return GamepadType.SWITCH if nintendo else GamepadType.XBOX

# === Face buttons ===
# Why: the A-label confirms and the B-label cancels on every pad. Nintendo pads put
# A on the right (JOY_BUTTON_B in Godot) and B on the bottom (JOY_BUTTON_A), so the
# index is picked per pad type to keep the label meaning the same.
static func confirm_button(type: GamepadType) -> int:
	return JOY_BUTTON_B if type == GamepadType.SWITCH else JOY_BUTTON_A

static func cancel_button(type: GamepadType) -> int:
	return JOY_BUTTON_A if type == GamepadType.SWITCH else JOY_BUTTON_B

## Gameplay action -> trigger axis, or -1 when the action is a button. Triggers count as pressed
## past `TRIGGER_THRESHOLD`.
const TRIGGER_THRESHOLD := 0.5
static func axis_for_action(action: StringName) -> int:
	match action:
		&"count": return JOY_AXIS_TRIGGER_RIGHT
	return -1

## Gameplay action -> button index for a pad type. -1 for an unknown action.
## Godot names buttons by Xbox POSITION: JOY_BUTTON_Y is the top button and JOY_BUTTON_X the
## left one on every pad (on a Nintendo pad the top button is labelled X and the left Y).
## `mark` is positional, so it sits in the same place on every pad. The shoulder buttons are undo
## (left) and redo (right). Count is the right TRIGGER (ZR on a Switch pad), which Godot reports
## as an axis, not a button: see `axis_for_action`.
static func button_for_action(action: StringName, type: GamepadType) -> int:
	match action:
		&"interact": return confirm_button(type)
		&"cancel": return cancel_button(type)
		&"menu": return JOY_BUTTON_START
		&"mark": return JOY_BUTTON_Y            # top button
		&"undo": return JOY_BUTTON_LEFT_SHOULDER
		&"redo": return JOY_BUTTON_RIGHT_SHOULDER
	return -1
