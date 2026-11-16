class_name State_Progress
extends State_Base
## === What the player has: the worked example of a saved state ===
## Writer: Global_Manager_Progress only. Everything else reads. Replace or extend per game:
## add a list for each kind of thing the game tracks (levels cleared, doors opened, ...).

var items_owned: Array[StringName] = []
## Free-form flags a game can set (for example &"met_the_baker").
var flags: Array[StringName] = []

func save_key() -> StringName:
	return &"progress"

func to_dict() -> Dictionary:
	return {
		"items_owned": _to_strings(items_owned),
		"flags": _to_strings(flags),
	}

func from_dict(data: Dictionary) -> void:
	items_owned = _to_ids(data.get("items_owned", []))
	flags = _to_ids(data.get("flags", []))

# Why: JSON stores plain strings; ids are StringName everywhere else.
static func _to_strings(ids: Array[StringName]) -> Array:
	var out := []
	for id in ids:
		out.append(String(id))
	return out

static func _to_ids(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array:
		for entry in raw:
			out.append(StringName(str(entry)))
	return out
