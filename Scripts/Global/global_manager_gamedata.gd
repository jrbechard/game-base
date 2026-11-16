extends Node
## === Id lookup for every Data_ resource ===
## Why: the only reader of Data/ files. Systems ask here by id and never load data themselves.

const ITEMS_DIR := "res://Data/Items"
const RUMBLE_DIR := "res://Data/Rumble"
const AUDIO_CUES_DIR := "res://Data/Audio/Cues"      # effects, menu sounds, ui
const AUDIO_TRACKS_DIR := "res://Data/Audio/Tracks"  # music

var _items: Dictionary = {}    # StringName -> Data_Item
var _rumble: Dictionary = {}   # StringName -> Data_Rumble_Effect
var _audio: Dictionary = {}    # StringName -> Data_Audio_Cue (cues and tracks share one id space)

func init() -> void:
	_items = _load_dir(ITEMS_DIR)
	_rumble = _load_dir(RUMBLE_DIR)
	_audio = _load_dir(AUDIO_CUES_DIR)
	_audio.merge(_load_dir(AUDIO_TRACKS_DIR))

# === Lookup ===
func get_item(id: StringName) -> Data_Item:
	if not _items.has(id):
		push_warning("GameData: no item with id '%s'" % id)
		return null
	return _items[id]

func get_all_items() -> Array:
	return _items.values()

func get_rumble_effect(id: StringName) -> Data_Rumble_Effect:
	if not _rumble.has(id):
		push_warning("GameData: no rumble effect with id '%s'" % id)
		return null
	return _rumble[id]

func get_all_rumble_effects() -> Array:
	return _rumble.values()

func get_audio_cue(id: StringName) -> Data_Audio_Cue:
	if not _audio.has(id):
		push_warning("GameData: no audio cue with id '%s'" % id)
		return null
	return _audio[id]

func get_all_audio_cues() -> Array:
	return _audio.values()

# === Loading ===
# Any resource with an `id` is accepted, so every data type shares this loader.
func _load_dir(dir_path: String) -> Dictionary:
	var result := {}
	for file_name in DirAccess.get_files_at(dir_path):
		# Why: exported builds list .tres files as .tres.remap.
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var res := load("%s/%s" % [dir_path, clean])
		if res == null or not ("id" in res):
			continue
		if result.has(res.id):
			push_error("GameData: duplicate id '%s' in %s" % [res.id, dir_path])
			continue
		result[res.id] = res
	return result
