class_name Input_Source_Gamepad
extends Input_Source
## === Gamepad gameplay input, following the last pad the player used ===
## Why: Pogne bound to pad 0 only, so a second pad was ignored. Here the device and pad
## type come from getters handed in by Global_Manager_Input, so swapping pads just works
## and this class never holds a node path.

const _STICK_DEADZONE := 0.2     # radial deadzone, same as Pogne
const _ACTIONS: Array[StringName] = [&"interact", &"cancel", &"menu", &"mark", &"alt_interact", &"count", &"alt_count"]

var _device_getter: Callable   # () -> int
var _type_getter: Callable     # () -> Logic_Input_Layout.GamepadType
var _curr := {}
var _prev := {}

func _init(device_getter: Callable, type_getter: Callable) -> void:
	_device_getter = device_getter
	_type_getter = type_getter

func get_device() -> int:
	return _device_getter.call()

func poll() -> void:
	var tmp := _prev
	_prev = _curr
	_curr = tmp
	var device := get_device()
	var type: Logic_Input_Layout.GamepadType = _type_getter.call()
	for action in _ACTIONS:
		var button := Logic_Input_Layout.button_for_action(action, type)
		_curr[action] = device >= 0 and Input.is_joy_button_pressed(device, button)

func pressed(action: StringName) -> bool:
	return _curr.get(action, false)

func just_pressed(action: StringName) -> bool:
	return _curr.get(action, false) and not _prev.get(action, false)

func move() -> Vector2:
	var device := get_device()
	if device < 0:
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	if v.length() >= _STICK_DEADZONE:
		return v.limit_length(1.0)
	# D-pad as a fallback so a pad with a dead stick still walks.
	var dpad := Vector2(
		float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT)),
		float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP)))
	return dpad.limit_length(1.0)
