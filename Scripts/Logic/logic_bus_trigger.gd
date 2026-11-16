class_name Logic_Bus_Trigger
extends RefCounted
## === Connect a data cue to an event on the bus ===
## Shared by rumble and audio, so the "cue fires itself from a bus event" rule is written
## once. Bus events carry different arguments; the handler an effect gives takes none, so
## the arguments are dropped here.

## Most arguments a bus event may have and still be triggerable this way.
const MAX_ARGS := 6

## Number of arguments of a bus event, or -1 if the bus script declares no such event.
## Only events declared by the bus script count (not Node's own, like `ready`).
static func event_arg_count(bus: Object, event: StringName) -> int:
	for s in bus.get_script().get_script_signal_list():
		if s["name"] == event:
			return (s["args"] as Array).size()
	return -1

## Connect `action` (a Callable taking no arguments) to `event`. Returns the connected
## handler, which must be passed to disconnect_trigger later, or an invalid Callable if the
## event does not exist (the caller decides whether to warn).
static func connect_trigger(bus: Object, event: StringName, action: Callable) -> Callable:
	var arg_count := event_arg_count(bus, event)
	if arg_count < 0 or arg_count > MAX_ARGS:
		return Callable()
	# Why a fresh wrapper per connection: Godot treats two bound callables of the same
	# method as the SAME connection, so two cues on one event would collide ("already
	# connected"). Each wrapper below is a distinct callable that ignores the event's arguments.
	var handler: Callable
	match arg_count:
		0: handler = func() -> void: action.call()
		1: handler = func(_a) -> void: action.call()
		2: handler = func(_a, _b) -> void: action.call()
		3: handler = func(_a, _b, _c) -> void: action.call()
		4: handler = func(_a, _b, _c, _d) -> void: action.call()
		5: handler = func(_a, _b, _c, _d, _e) -> void: action.call()
		_: handler = func(_a, _b, _c, _d, _e, _f) -> void: action.call()
	bus.connect(event, handler)
	return handler

## Like connect_trigger, but `action` takes ONE argument: the event's first argument, so a cue can
## depend on a value (for example how big something is). Returns an invalid Callable if the event
## does not exist or has no arguments.
static func connect_trigger_value(bus: Object, event: StringName, action: Callable) -> Callable:
	var arg_count := event_arg_count(bus, event)
	if arg_count < 1 or arg_count > MAX_ARGS:
		return Callable()
	var handler: Callable
	match arg_count:
		1: handler = func(a) -> void: action.call(a)
		2: handler = func(a, _b) -> void: action.call(a)
		3: handler = func(a, _b, _c) -> void: action.call(a)
		4: handler = func(a, _b, _c, _d) -> void: action.call(a)
		5: handler = func(a, _b, _c, _d, _e) -> void: action.call(a)
		_: handler = func(a, _b, _c, _d, _e, _f) -> void: action.call(a)
	bus.connect(event, handler)
	return handler

static func disconnect_trigger(bus: Object, event: StringName, handler: Callable) -> void:
	if handler.is_valid() and bus.is_connected(event, handler):
		bus.disconnect(event, handler)
