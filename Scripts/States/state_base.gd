class_name State_Base
extends Resource
## === Contract every saved State_ resource follows ===
## Why: Global_Manager_Save only knows this contract, so new states (any new kind of saved data)
## plug in without touching Save. Each State has exactly one writer manager.

## Key the state is stored under in the save file.
func save_key() -> StringName:
	push_error("State_Base.save_key must be overridden")
	return &""

func to_dict() -> Dictionary:
	push_error("State_Base.to_dict must be overridden")
	return {}

## Replaces all contents from a saved dictionary. Missing keys fall back to defaults.
func from_dict(_data: Dictionary) -> void:
	push_error("State_Base.from_dict must be overridden")
