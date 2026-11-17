class_name UI_Prompt_Icon
extends TextureRect
## === One button picture for an action, always the right one for the device in use ===
## Shows the key, Xbox button or Nintendo button for `action` (see Logic_Input_Prompts) and
## changes by itself when the player switches between keyboard, mouse and pads, or between pad
## types. It only displays: it sends nothing.

## The router's action name: interact, cancel, mark, count, undo, redo, menu or move.
@export var action: StringName = &"interact":
	set(value):
		action = value
		_refresh()

## Side of the picture in pixels (the pictures are 64 px; they are drawn smaller).
@export var icon_size := 40.0:
	set(value):
		icon_size = value
		custom_minimum_size = Vector2(icon_size, icon_size)

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(icon_size, icon_size)

func _ready() -> void:
	Global_Manager_Events.device_mode_changed.connect(_on_device_changed)
	Global_Manager_Events.gamepad_type_changed.connect(_on_device_changed)
	_refresh()

func _on_device_changed(_value: int) -> void:
	_refresh()

## The family of pictures in use right now.
static func current_family() -> Logic_Input_Prompts.Family:
	var input := Global_Manager_Input
	return Logic_Input_Prompts.family_for(input.device_mode == input.DeviceMode.GAMEPAD, input.gamepad_type)

func _refresh() -> void:
	if not is_inside_tree():
		return
	texture = Logic_Input_Prompts.icon(action, current_family())
