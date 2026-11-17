class_name UI_Prompt_Line
extends HBoxContainer
## === A line of hints with real button pictures: "[A] Fill  [B] X  [ZR] Count" ===
## `text_key` names a translation whose text holds action tokens in braces, for example
## "{interact} Fill   {cancel} X   {menu} Pause". Each token becomes a UI_Prompt_Icon (which
## follows the device in use by itself); the words around them become labels. The line is
## rebuilt when the language changes. It only displays.

@export var text_key := "":
	set(value):
		text_key = value
		_rebuild()

## Size of the pictures in pixels.
@export var icon_size := 32.0
## Small text: the theme's `Label_Small` style (Sniglet, 24 px) instead of the main font.
@export var small_text := true

func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)

func _ready() -> void:
	_rebuild()

func _notification(what: int) -> void:
	# Deferred: changing children while the language change is still being passed down the tree
	# is not allowed ("parent is busy").
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_rebuild.call_deferred()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if text_key.is_empty():
		return
	for piece: Dictionary in Logic_Input_Prompts.parse(tr(text_key)):
		if piece.has("action"):
			var icon := UI_Prompt_Icon.new()
			icon.icon_size = icon_size
			icon.action = piece["action"]
			add_child(icon)
		else:
			var label := Label.new()
			label.text = String(piece["text"]).strip_edges(true, false) if get_child_count() == 0 else piece["text"]
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if small_text:
				label.theme_type_variation = &"Label_Small"
			add_child(label)
