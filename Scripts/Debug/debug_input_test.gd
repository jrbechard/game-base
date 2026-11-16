extends Control
## === Debug_Input_Test: hardware check for the input router (build step 4b) ===
## Shows what Global_Manager_Input currently believes, and every action it announces.
## Try: press A/B on each pad (the A-label should show "ui_accept" on both pad types),
## push each pad's stick, use d-pad, keys, mouse. Unplug the active pad. Esc quits.

const MAX_LOG := 12

@onready var _label: Label = $Label
var _log: Array[String] = []

func _ready() -> void:
	# Why: this scene runs on its own, without Main, so it starts the router itself.
	Global_Manager_Input.init()
	Global_Manager_Events.ui_action_triggered.connect(func(a: StringName) -> void: _add("triggered " + a))
	Global_Manager_Events.ui_action_held_changed.connect(
			func(a: StringName, h: bool) -> void: _add("%s %s" % [a, "HELD" if h else "released"]))
	Global_Manager_Events.device_mode_changed.connect(
			func(m: int) -> void: _add("MODE -> " + Global_Manager_Input.DeviceMode.keys()[m]))
	Global_Manager_Events.gamepad_type_changed.connect(
			func(t: int) -> void: _add("PAD TYPE -> " + Logic_Input_Layout.GamepadType.keys()[t]))

# Why: Esc is now a routed menu key that the input router consumes, so quit is F10.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		get_tree().quit()

func _add(line: String) -> void:
	print("INPUT_TEST ", line)
	_log.push_front(line)
	if _log.size() > MAX_LOG:
		_log.pop_back()

func _process(_delta: float) -> void:
	var inp := Global_Manager_Input
	var pad := inp.last_gamepad_device
	var lines: Array[String] = [
		"INPUT TEST   (F10 quits)", "",
		"Mode: " + Global_Manager_Input.DeviceMode.keys()[inp.device_mode],
		"Pad type: " + Logic_Input_Layout.GamepadType.keys()[inp.gamepad_type],
		"Active pad: %s" % ("none" if pad < 0 else "%d  (%s)" % [pad, Input.get_joy_name(pad)]),
		"Source: %s   move: %s   rumble device: %d" % [inp.source.get_script().get_global_name(), inp.source.move().snappedf(0.01), inp.source.get_device()],
		"Interact held: %s   Cancel held: %s   Menu held: %s" % [inp.source.pressed(&"interact"), inp.source.pressed(&"cancel"), inp.source.pressed(&"menu")],
		"", "Recent:"]
	lines.append_array(_log)
	_label.text = "\n".join(lines)
