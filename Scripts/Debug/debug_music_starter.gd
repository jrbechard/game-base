extends Node
## === Debug_Music_Starter: plays the placeholder music so volume sliders can be heard ===
## Lives in Debug_Settings only. Waits one frame, because Main initialises the managers in
## its own _ready, which runs after this node's. F10 quits.

func _ready() -> void:
	await get_tree().process_frame
	Global_Manager_Music.play(&"placeholder_theme")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		get_tree().quit()
