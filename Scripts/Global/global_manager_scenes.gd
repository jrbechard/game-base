extends Node
## === Screen switching ===
## Owns swapping the current screen inside Screen_Host.

var _screen_host: Node

# Why: Main hands in the host, so no absolute node path is needed.
func init(screen_host: Node) -> void:
	_screen_host = screen_host

func change_screen(scene: PackedScene, scene_id: StringName) -> void:
	for child in _screen_host.get_children():
		child.queue_free()
	_screen_host.add_child(scene.instantiate())
	Global_Manager_Events.scene_changed.emit(scene_id)
