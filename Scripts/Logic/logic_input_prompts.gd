class_name Logic_Input_Prompts
extends RefCounted
## === Pure functions: which button picture shows for an action, on which device ===
## Why: no nodes and no pad needed, so the rules are testable. Icons are Kenney's Input Prompts
## (CC0, see docs/CREDITS.md), kept in Assets/Prompts/<family>/.
## Actions are the router's names (`interact`, `cancel`, `mark`, `count`, `undo`, `redo`, `menu`)
## plus `move`. They mean the LABEL on the button: on a Nintendo pad `interact` is the button
## labelled A (the right one), on an Xbox pad the one labelled A (the bottom one). The router
## already swaps the physical buttons per pad type (see Logic_Input_Layout), so the picture and
## the button always agree.

enum Family { KEYBOARD, XBOX, SWITCH }

const FOLDERS := {Family.KEYBOARD: "keyboard", Family.XBOX: "xbox", Family.SWITCH: "switch"}
const ROOT := "res://Assets/Prompts/"

# action -> icon file name (without .png), per family. Mark is the TOP face button: Y on an Xbox
# pad, X on a Nintendo pad.
const ICONS := {
	Family.KEYBOARD: {
		&"interact": "keyboard_e", &"cancel": "keyboard_q", &"mark": "keyboard_c",
		&"count": "keyboard_x", &"undo": "keyboard_z", &"redo": "keyboard_y",
		&"menu": "keyboard_escape", &"move": "keyboard_arrows",
	},
	Family.XBOX: {
		&"interact": "xbox_button_a", &"cancel": "xbox_button_b", &"mark": "xbox_button_y",
		&"count": "xbox_rt", &"undo": "xbox_lb", &"redo": "xbox_rb",
		&"menu": "xbox_button_menu", &"move": "xbox_stick_l",
	},
	Family.SWITCH: {
		&"interact": "switch_button_a", &"cancel": "switch_button_b", &"mark": "switch_button_x",
		&"count": "switch_button_zr", &"undo": "switch_button_l", &"redo": "switch_button_r",
		&"menu": "switch_button_plus", &"move": "switch_stick_l",
	},
}

static var _cache: Dictionary = {}

## Which set of pictures to show. A keyboard or mouse shows keys; a pad shows its own buttons
## (any pad that is not a Nintendo one shows the standard Xbox layout).
static func family_for(using_gamepad: bool, type: Logic_Input_Layout.GamepadType) -> Family:
	if not using_gamepad:
		return Family.KEYBOARD
	return Family.SWITCH if type == Logic_Input_Layout.GamepadType.SWITCH else Family.XBOX

## The picture's path for an action, or an empty string when the action has no picture.
static func icon_path(action: StringName, family: Family) -> String:
	var name: String = ICONS[family].get(action, "")
	if name.is_empty():
		return ""
	return "%s%s/%s.png" % [ROOT, FOLDERS[family], name]

## The picture itself (cached), or null when there is none.
static func icon(action: StringName, family: Family) -> Texture2D:
	var path := icon_path(action, family)
	if path.is_empty():
		return null
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D
	return _cache[path]

## Split a hint such as "{interact} Fill   {cancel} X" into pieces, in order: {"action": &"interact"}
## for a token and {"text": "Fill   "} for plain text. Unknown tokens stay as plain text.
static func parse(text: String) -> Array:
	var pieces: Array = []
	var rest := text
	while not rest.is_empty():
		var open := rest.find("{")
		var close := rest.find("}", open + 1) if open >= 0 else -1
		if open < 0 or close < 0:
			pieces.append({"text": rest})
			break
		var action := StringName(rest.substr(open + 1, close - open - 1))
		if not ICONS[Family.KEYBOARD].has(action):
			# Not an action: keep the braces as ordinary text and carry on after them.
			pieces.append({"text": rest.substr(0, close + 1)})
			rest = rest.substr(close + 1)
			continue
		if open > 0:
			pieces.append({"text": rest.substr(0, open)})
		pieces.append({"action": action})
		rest = rest.substr(close + 1)
	return pieces
