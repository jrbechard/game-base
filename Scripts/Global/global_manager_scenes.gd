extends Node
## === Screen switching ===
## Owns swapping the current screen inside Screen_Host.

var _screen_host: Node
var _current: Node

# Why: Main hands in the host, so no absolute node path is needed.
func init(screen_host: Node) -> void:
	_screen_host = screen_host
	_current = null

## Swap in a new screen and return it (so the caller can set it up).
func change_screen(scene: PackedScene, scene_id: StringName) -> Node:
	for child in _screen_host.get_children():
		child.queue_free()
	_current = scene.instantiate()
	_screen_host.add_child(_current)
	Global_Manager_Events.scene_changed.emit(scene_id)
	return _current

## The screen showing now, or null.
func current_screen() -> Node:
	return _current if is_instance_valid(_current) else null
