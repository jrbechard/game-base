class_name Data_Rumble_Effect
extends Resource
## === One rumble cue ===
## Add a cue by adding a .tres file: no code. If `trigger_event` names a bus event, the
## effect fires automatically whenever that event is emitted. Authored data: read-only at
## runtime. All starter values are GUESS: until felt on real hardware.

## Id used by Global_Manager_Rumble.play(), e.g. &"item_acquired".
@export var id: StringName
## Strength of the weak (high-frequency) and strong (low-frequency) motors, 0 to 1.
@export_range(0.0, 1.0) var weak := 0.5
@export_range(0.0, 1.0) var strong := 0.5
## Length of one pulse, in seconds.
@export_range(0.01, 2.0) var duration := 0.15
## How many pulses (2 = a double tap).
@export_range(1, 8) var pulses := 1
## Silence between pulses, in seconds.
@export_range(0.0, 1.0) var gap := 0.08
## When two effects overlap, a lower priority never cuts off a higher one that is still
## buzzing; the same or a higher priority replaces it (0 = ordinary).
@export var priority := 0
## The event's first argument (a number from 0 to 1) scales the strength: `value_strength_min` of
## the full strength at 0, the full strength at 1.
@export var strength_from_value := false
@export_range(0.0, 1.0) var value_strength_min := 0.4
## Bus event that fires this effect (a signal name on Global_Manager_Events). Empty = manual only.
@export var trigger_event: StringName
