class_name State_Settings
extends State_Base
## === App settings: volumes, language, rumble strength, reduce motion ===
## Writer: Global_Manager_Settings only. Kept in its own file (not the game save), so
## deleting a save never resets the player's volume. All values are validated here, so a
## hand-edited or damaged file can never put the game in a bad state.

## Languages the game ships. es, de and ja are added when their translations exist.
const LOCALES: Array[StringName] = [&"en", &"fr"]

## Every setting and its default. The default's type decides how a value is validated.
const DEFAULTS := {
	&"volume_master": 1.0,
	&"volume_music": 1.0,
	&"volume_sfx": 1.0,
	&"volume_ambience": 1.0,
	&"volume_ui": 1.0,
	&"language": &"en",
	&"rumble_scale": 1.0,
	## How long a held direction waits before it starts repeating (a slider, 0..1; see
	## Logic_Stick_Repeat.delay_for_setting). GUESS: 0.5 is the 0.35 s the menus used before.
	&"hold_delay": 0.5,
	## Strength of the CRT overlay, 0 = off, 1 = full (Ever Blue's default look).
	&"screen_effect": 1.0,
	&"reduce_motion": false,
}

var values: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	values = DEFAULTS.duplicate()

func save_key() -> StringName:
	return &"settings"

func to_dict() -> Dictionary:
	var out := {}
	for key in values:
		out[String(key)] = String(values[key]) if values[key] is StringName else values[key]
	return out

func from_dict(data: Dictionary) -> void:
	reset()
	for key in DEFAULTS:
		if data.has(String(key)):
			var clean: Variant = sanitize(key, data[String(key)])
			if clean != null:
				values[key] = clean

## A valid value for `key`, or null if the key is unknown or the value is unusable.
## Sliders are clamped to 0..1; a language must be one of LOCALES.
static func sanitize(key: StringName, value: Variant) -> Variant:
	if not DEFAULTS.has(key):
		return null
	match typeof(DEFAULTS[key]):
		TYPE_FLOAT:
			if value is float or value is int:
				return clampf(float(value), 0.0, 1.0)
		TYPE_BOOL:
			if value is bool:
				return value
		TYPE_STRING_NAME:
			if (value is String or value is StringName) and LOCALES.has(StringName(value)):
				return StringName(value)
	return null
