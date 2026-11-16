class_name Input_Source_Keyboard
extends Input_Source
## === Keyboard gameplay input ===
## GUESS: key choices are placeholders until JR picks bindings; remapping comes later.

const _KEYS := {
	&"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
	&"cancel": [KEY_Q, KEY_BACKSPACE],
	&"menu": [KEY_ESCAPE, KEY_TAB],
	&"mark": [KEY_C],
	&"alt_interact": [KEY_Z],
	&"count": [KEY_R],
	&"alt_count": [KEY_SHIFT],
}
const _MOVE_KEYS := {
	"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
	"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
}

var _curr := {}
var _prev := {}

func poll() -> void:
	var tmp := _prev
	_prev = _curr
	_curr = tmp
	for action in _KEYS:
		_curr[action] = _any_down(_KEYS[action])

func pressed(action: StringName) -> bool:
	return _curr.get(action, false)

func just_pressed(action: StringName) -> bool:
	return _curr.get(action, false) and not _prev.get(action, false)

func move() -> Vector2:
	var v := Vector2(
		float(_any_down(_MOVE_KEYS["right"])) - float(_any_down(_MOVE_KEYS["left"])),
		float(_any_down(_MOVE_KEYS["down"])) - float(_any_down(_MOVE_KEYS["up"])))
	return v.limit_length(1.0)  # Why: diagonals must not move faster than straight lines.

static func _any_down(keys: Array) -> bool:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return true
	return false
