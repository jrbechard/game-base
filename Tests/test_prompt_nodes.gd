extends GutTest
## === Button pictures on screen and the mouse cursors (reusable: nothing here is game specific) ===

# === Hint lines and prompt icons ===
func test_a_hint_line_turns_tokens_into_pictures() -> void:
	var line := UI_Prompt_Line.new()
	line.text_key = "{interact} Fill   {menu} Pause"
	add_child_autofree(line)
	await wait_process_frames(2)
	var icons := line.get_children().filter(func(c: Node) -> bool: return c is UI_Prompt_Icon)
	assert_eq(icons.size(), 2)
	assert_eq(icons[0].action, &"interact")
	assert_not_null(icons[0].texture)

func test_small_text_uses_the_small_label_style() -> void:
	var line := UI_Prompt_Line.new()
	line.text_key = "{interact} Go"
	add_child_autofree(line)
	await wait_process_frames(2)
	var labels := line.get_children().filter(func(c: Node) -> bool: return c is Label)
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].theme_type_variation, &"Label_Small")

func test_a_prompt_icon_follows_the_device_in_use() -> void:
	var icon := UI_Prompt_Icon.new()
	icon.action = &"interact"
	add_child_autofree(icon)
	var input := Global_Manager_Input
	var saved_mode := input.device_mode
	var saved_type := input.gamepad_type
	input.device_mode = input.DeviceMode.KEYBOARD
	Global_Manager_Events.device_mode_changed.emit(input.DeviceMode.KEYBOARD)
	assert_string_ends_with(icon.texture.resource_path, "keyboard_e.png")
	input.device_mode = input.DeviceMode.GAMEPAD
	input.gamepad_type = Logic_Input_Layout.GamepadType.SWITCH
	Global_Manager_Events.gamepad_type_changed.emit(Logic_Input_Layout.GamepadType.SWITCH)
	assert_string_ends_with(icon.texture.resource_path, "switch_button_a.png")
	input.gamepad_type = Logic_Input_Layout.GamepadType.XBOX
	Global_Manager_Events.gamepad_type_changed.emit(Logic_Input_Layout.GamepadType.XBOX)
	assert_string_ends_with(icon.texture.resource_path, "xbox_button_a.png")
	input.device_mode = saved_mode
	input.gamepad_type = saved_type

# === Mouse cursors ===
func test_every_cursor_picture_exists_and_its_hotspot_is_inside_it() -> void:
	for shape in Logic_Mouse_Cursors.SHAPES:
		var entry: Array = Logic_Mouse_Cursors.SHAPES[shape]
		var texture := load(Logic_Mouse_Cursors.ROOT + entry[0]) as Texture2D
		assert_not_null(texture, entry[0])
		if texture != null:
			var hot: Vector2 = entry[1]
			assert_true(hot.x >= 0 and hot.y >= 0 and hot.x < texture.get_width() and hot.y < texture.get_height(), "%s hotspot" % entry[0])

func test_applying_the_cursors_does_not_fail() -> void:
	Logic_Mouse_Cursors.apply()
	assert_true(true)

func test_buttons_with_a_hover_effect_show_the_hand() -> void:
	var button := Button.new()
	var hover := Component_Hover_Effect.new()
	button.add_child(hover)
	add_child_autofree(button)
	assert_eq(button.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)

func test_the_credits_list_names_the_kenney_packs() -> void:
	var text := FileAccess.get_file_as_string("res://docs/CREDITS.md")
	assert_string_contains(text, "Input Prompts")
	assert_string_contains(text, "Cursor Pack")
	assert_true(FileAccess.file_exists("res://Assets/Prompts/License_Kenney_Input_Prompts.txt"))
	assert_true(FileAccess.file_exists("res://Assets/Cursors/License_Kenney_Cursor_Pack.txt"))
