extends Control
## === Debug_Rumble_Test: bare hardware rumble test (build step 4a) ===
## Why: Pogne's rumble did not work on hardware, so before any rumble system exists
## we prove a pad can buzz at all. Nothing here is reused later except what we learn.
##
## Pad buttons (buzz the pad you pressed):
##   A / south  = weak (high-frequency) motor only
##   B / east   = strong (low-frequency) motor only
##   X / west   = both motors, full, 1 s
##   Y / north  = both motors, half, 2 s
## Start / Space = automatic sequence on every pad. Esc = quit.

const SEQUENCE := [
	{"label": "weak only", "weak": 1.0, "strong": 0.0, "time": 1.0},
	{"label": "strong only", "weak": 0.0, "strong": 1.0, "time": 1.0},
	{"label": "both full", "weak": 1.0, "strong": 1.0, "time": 1.0},
]

@onready var _label: Label = $Label
var _last_event := "press a button on a pad"
var _running_sequence := false

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_print_pads("startup")

func _process(_delta: float) -> void:
	_refresh_label()

# === Input ===
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_SPACE:
			_run_sequence()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A: _buzz(event.device, 1.0, 0.0, 1.0, "weak only")
			JOY_BUTTON_B: _buzz(event.device, 0.0, 1.0, 1.0, "strong only")
			JOY_BUTTON_X: _buzz(event.device, 1.0, 1.0, 1.0, "both full")
			JOY_BUTTON_Y: _buzz(event.device, 0.5, 0.5, 2.0, "both half")
			JOY_BUTTON_START: _run_sequence()

# === Rumble ===
func _buzz(device: int, weak: float, strong: float, time: float, label: String) -> void:
	Input.start_joy_vibration(device, weak, strong, time)
	_last_event = "pad %d: %s (weak %.1f, strong %.1f, %.1f s)" % [device, label, weak, strong, time]
	print("RUMBLE_TEST sent: ", _last_event)

func _run_sequence() -> void:
	if _running_sequence:
		return
	_running_sequence = true
	for step in SEQUENCE:
		for device in Input.get_connected_joypads():
			_buzz(device, step["weak"], step["strong"], step["time"], "sequence " + step["label"])
		await get_tree().create_timer(step["time"] + 0.7).timeout
	_running_sequence = false

# === Info ===
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_last_event = "pad %d %s" % [device, "connected" if connected else "DISCONNECTED"]
	_print_pads(_last_event)

func _print_pads(reason: String) -> void:
	print("RUMBLE_TEST pads (%s): %d connected" % [reason, Input.get_connected_joypads().size()])
	for device in Input.get_connected_joypads():
		print("RUMBLE_TEST   pad %d name='%s' guid=%s known=%s info=%s" % [
				device, Input.get_joy_name(device), Input.get_joy_guid(device),
				Input.is_joy_known(device), Input.get_joy_info(device)])

func _refresh_label() -> void:
	var lines: Array[String] = ["RUMBLE TEST   (A weak, B strong, X both, Y half/2s, Start or Space = sequence, Esc = quit)", ""]
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		lines.append("No pads connected.")
	for device in pads:
		lines.append("Pad %d: %s" % [device, Input.get_joy_name(device)])
		lines.append("    guid %s   known mapping: %s" % [Input.get_joy_guid(device), Input.is_joy_known(device)])
		lines.append("    rumble now: weak %.1f  strong %.1f" % [
				Input.get_joy_vibration_strength(device).x, Input.get_joy_vibration_strength(device).y])
	lines.append("")
	lines.append("Last: " + _last_event)
	_label.text = "\n".join(lines)
