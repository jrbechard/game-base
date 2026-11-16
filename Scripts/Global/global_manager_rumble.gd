extends Node
## === Rumble: controller force feedback, driven by data and bus events ===
## Built on the one call hardware testing proved (Input.start_joy_vibration; Xbox and
## Switch 1 Pro buzz, Switch 2 Pro does not). Effects are Data_Rumble_Effect resources;
## an effect with a `trigger_event` fires itself when that bus event is emitted.
##
## The device comes from the active Input_Source (handed in by Main), so the pad in use
## buzzes and keyboard or mouse do nothing (device -1).
##
## `backend` is the ONE function that touches the hardware. A Switch 2 or console port
## replaces just that. Zero strengths mean "stop".

## Master intensity; 0 is the off switch. The settings screen (step 4f) drives this.
var rumble_scale := 1.0
var debug_print := false
## (device: int, weak: float, strong: float, duration: float) -> void
var backend: Callable = Callable(self, &"_send_to_hardware")

var _effects: Dictionary = {}          # StringName -> Data_Rumble_Effect
var _device_getter := Callable()       # () -> int, the active pad or -1
var _connections: Array[Dictionary] = []  # {id, event, callable}
var _last_play_frame: Dictionary = {}  # effect id -> process frame of its last play
var _used_devices: Dictionary = {}     # devices we have buzzed, so stop_all can stop them
var _busy_until := 0.0     # seconds (engine time) until the current effect has finished
var _busy_priority := 0
var _epoch := 0                        # bumped by stop_all to cancel running pulse trains

# Why: Main hands in the device getter, so this manager needs no path to the input manager.
func init(device_getter: Callable) -> void:
	_device_getter = device_getter
	_disconnect_all()
	_effects.clear()
	_last_play_frame.clear()
	_busy_until = 0.0
	_busy_priority = 0
	_epoch += 1
	rumble_scale = 1.0
	backend = Callable(self, &"_send_to_hardware")
	for fx: Data_Rumble_Effect in Global_Manager_GameData.get_all_rumble_effects():
		register_effect(fx)
	# Why: the strength setting is applied here, from the bus, so settings need no call into rumble.
	if not Global_Manager_Events.setting_changed.is_connected(_on_setting_changed):
		Global_Manager_Events.setting_changed.connect(_on_setting_changed)
	if not Global_Manager_Events.rumble_preview_requested.is_connected(_on_preview_requested):
		Global_Manager_Events.rumble_preview_requested.connect(_on_preview_requested)

func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"rumble_scale":
		rumble_scale = clampf(float(value), 0.0, 1.0)

func _on_preview_requested() -> void:
	play(&"preview")

# === Effects ===
## Add or replace an effect. Connects its trigger event, if it has one.
func register_effect(fx: Data_Rumble_Effect) -> void:
	_disconnect_for(fx.id)
	_effects[fx.id] = fx
	if fx.trigger_event == &"":
		return
	var handler := Logic_Bus_Trigger.connect_trigger(Global_Manager_Events, fx.trigger_event, _on_trigger.bind(fx))
	if not handler.is_valid():
		push_warning("Rumble: effect '%s' triggers on '%s', which is not an event on the bus" % [fx.id, fx.trigger_event])
		return
	_connections.append({"id": fx.id, "event": fx.trigger_event, "callable": handler})

func _on_trigger(fx: Data_Rumble_Effect) -> void:
	_play_effect(fx, 1.0)

# === Playing ===
## Fire a cue by hand. `gain` scales its strength (for example by how hard something hit).
func play(id: StringName, gain: float = 1.0) -> void:
	if not _effects.has(id):
		push_warning("Rumble: no effect with id '%s'" % id)
		return
	_play_effect(_effects[id], gain)

func _play_effect(fx: Data_Rumble_Effect, gain: float) -> void:
	if rumble_scale <= 0.0:
		return
	var device := _device()
	if device < 0:
		return  # keyboard, mouse or no pad
	# Same-frame dedup: a doubled event must not restart the same cue twice.
	var frame := Engine.get_process_frames()
	if _last_play_frame.get(fx.id, -1) == frame:
		return
	_last_play_frame[fx.id] = frame

	# Priority: a lower-priority effect never cuts off a higher one that is still buzzing.
	var now := Time.get_ticks_msec() / 1000.0
	if now < _busy_until and fx.priority < _busy_priority:
		return
	_busy_priority = fx.priority
	_busy_until = now + maxi(fx.pulses - 1, 0) * (fx.duration + fx.gap) + fx.duration

	var weak := clampf(fx.weak * gain * rumble_scale, 0.0, 1.0)
	var strong := clampf(fx.strong * gain * rumble_scale, 0.0, 1.0)
	var epoch := _epoch
	for i in maxi(fx.pulses, 1):
		if i > 0:
			await get_tree().create_timer(fx.duration + fx.gap).timeout
			if epoch != _epoch:
				return  # stop_all() or init() cancelled this train
		_send(device, weak, strong, fx.duration)

## Stop everything now (scene changes, pausing). Also cancels pulse trains still running.
func stop_all() -> void:
	_epoch += 1
	_busy_until = 0.0
	for device in _used_devices:
		backend.call(device, 0.0, 0.0, 0.0)

# === Hardware ===
func _send(device: int, weak: float, strong: float, duration: float) -> void:
	_used_devices[device] = true
	if debug_print:
		print("[RUMBLE] device %d weak %.2f strong %.2f for %.2f s" % [device, weak, strong, duration])
	backend.call(device, weak, strong, duration)

func _send_to_hardware(device: int, weak: float, strong: float, duration: float) -> void:
	if weak <= 0.0 and strong <= 0.0:
		Input.stop_joy_vibration(device)
	else:
		Input.start_joy_vibration(device, weak, strong, duration)

func _device() -> int:
	return _device_getter.call() if _device_getter.is_valid() else -1

# === Bus wiring ===
func _disconnect_for(id: StringName) -> void:
	for i in range(_connections.size() - 1, -1, -1):
		if _connections[i]["id"] == id:
			Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, _connections[i]["event"], _connections[i]["callable"])
			_connections.remove_at(i)

func _disconnect_all() -> void:
	for c in _connections:
		Logic_Bus_Trigger.disconnect_trigger(Global_Manager_Events, c["event"], c["callable"])
	_connections.clear()
