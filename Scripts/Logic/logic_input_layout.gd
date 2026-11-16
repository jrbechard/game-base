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

## Gameplay action -> button index for a pad type. -1 for an unknown action.
static func button_for_action(action: StringName, type: GamepadType) -> int:
	match action:
		&"interact": return confirm_button(type)
		&"cancel": return cancel_button(type)
		&"menu": return JOY_BUTTON_START
	return -1
