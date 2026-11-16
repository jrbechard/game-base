class_name Data_Audio_Cue
extends Resource
## === One sound cue (or music track) ===
## Code says `play(&"menu_confirm")` and never loads files. Add a sound by adding a .tres.
## If `trigger_event` names a bus event, the cue plays itself when that event is emitted.
## Authored data: read-only at runtime. Starter sounds are generated placeholders.

## Id used by Global_Manager_SFX.play() or Global_Manager_Music.play().
@export var id: StringName
## One or more sounds; one is picked at random each time (variation).
@export var streams: Array[AudioStream] = []
## Bus it plays on: SFX, UI, Ambience or Music (see Logic_Audio_Buses).
@export var bus: StringName = &"SFX"
@export_range(-40.0, 12.0) var volume_db := 0.0
## Random pitch variation, as a fraction (0.05 = plus or minus 5%).
@export_range(0.0, 0.5) var pitch_range := 0.05
## Pitch multiplier before the random variation (1.0 = as recorded).
@export_range(0.25, 4.0) var base_pitch := 1.0
## Bus event that plays this cue (a signal name on Global_Manager_Events). Empty = manual only.
@export var trigger_event: StringName
