class_name Input_Source
extends RefCounted
## === Gameplay input from one device ===
## Gameplay reads this object instead of the global Input stream, so only the input layer
## knows device ids. One source is active at a time (no player seats). Actions:
## move (vector), interact, cancel, menu, plus mark, count, undo, redo (a game
## that does not use them just ignores them). Global_Manager_Input picks the active source.

## Call once per frame before reading, so just_pressed has edges to compare.
func poll() -> void:
	pass

func pressed(_action: StringName) -> bool:
	return false

func just_pressed(_action: StringName) -> bool:
	return false

func move() -> Vector2:
	return Vector2.ZERO

## Raw device index for rumble, or -1 when there is no rumble-capable device (keyboard).
func get_device() -> int:
	return -1
