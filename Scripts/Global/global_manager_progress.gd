extends Node
## === Progress: the only writer of State_Progress ===
## Listens for intents on the bus, validates them against GameData, writes the
## state, then announces the result. UI and other systems only read.

var state := State_Progress.new()

func init() -> void:
	# Why: init may run more than once in tests; never connect twice.
	if not Global_Manager_Events.item_grant_requested.is_connected(_on_item_grant_requested):
		Global_Manager_Events.item_grant_requested.connect(_on_item_grant_requested)

# === Read ===
func has_item(item_id: StringName) -> bool:
	return state.items_owned.has(item_id)

# === Intents ===
func _on_item_grant_requested(item_id: StringName) -> void:
	if Global_Manager_GameData.get_item(item_id) == null:
		return  # GameData already warned about the unknown id
	if has_item(item_id):
		return
	state.items_owned.append(item_id)
	Global_Manager_Events.item_acquired.emit(item_id)
	Global_Manager_Events.state_changed.emit(state.save_key())
