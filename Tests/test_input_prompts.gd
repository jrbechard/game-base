extends GutTest
## === Logic_Input_Prompts: which button picture shows for an action ===

const Family := Logic_Input_Prompts.Family
const PadType := Logic_Input_Layout.GamepadType

func test_a_keyboard_or_mouse_shows_keys() -> void:
	for type in [PadType.NONE, PadType.XBOX, PadType.SWITCH]:
		assert_eq(Logic_Input_Prompts.family_for(false, type), Family.KEYBOARD)

func test_a_pad_shows_its_own_buttons() -> void:
	assert_eq(Logic_Input_Prompts.family_for(true, PadType.SWITCH), Family.SWITCH)
	assert_eq(Logic_Input_Prompts.family_for(true, PadType.XBOX), Family.XBOX)
	assert_eq(Logic_Input_Prompts.family_for(true, PadType.NONE), Family.XBOX, "an unknown pad shows the standard layout")

func test_the_label_means_the_same_on_every_pad() -> void:
	assert_string_ends_with(Logic_Input_Prompts.icon_path(&"interact", Family.SWITCH), "switch_button_a.png")
	assert_string_ends_with(Logic_Input_Prompts.icon_path(&"interact", Family.XBOX), "xbox_button_a.png")
	assert_string_ends_with(Logic_Input_Prompts.icon_path(&"cancel", Family.SWITCH), "switch_button_b.png")

func test_mark_is_the_top_button_on_every_pad() -> void:
	assert_string_ends_with(Logic_Input_Prompts.icon_path(&"mark", Family.SWITCH), "switch_button_x.png", "X on a Nintendo pad")
	assert_string_ends_with(Logic_Input_Prompts.icon_path(&"mark", Family.XBOX), "xbox_button_y.png", "Y on an Xbox pad")

func test_count_is_the_right_trigger() -> void:
	assert_string_ends_with(Logic_Input_Prompts.icon_path(&"count", Family.SWITCH), "switch_button_zr.png")
	assert_string_ends_with(Logic_Input_Prompts.icon_path(&"count", Family.XBOX), "xbox_rt.png")

func test_an_unknown_action_has_no_picture() -> void:
	assert_eq(Logic_Input_Prompts.icon_path(&"nonsense", Family.SWITCH), "")
	assert_null(Logic_Input_Prompts.icon(&"nonsense", Family.SWITCH))

# Every picture the table names must be a real imported file.
func test_every_listed_picture_exists() -> void:
	for family in Logic_Input_Prompts.ICONS:
		for action in Logic_Input_Prompts.ICONS[family]:
			assert_not_null(Logic_Input_Prompts.icon(action, family), "%s on %s" % [action, Logic_Input_Prompts.FOLDERS[family]])

func test_every_family_covers_the_same_actions() -> void:
	var keyboard: Array = Logic_Input_Prompts.ICONS[Family.KEYBOARD].keys()
	for family in [Family.XBOX, Family.SWITCH]:
		var actions: Array = Logic_Input_Prompts.ICONS[family].keys()
		keyboard.sort()
		actions.sort()
		assert_eq(actions, keyboard)

func test_the_keys_shown_match_the_keys_that_work() -> void:
	# The keyboard picture must show a key the keyboard source really binds for that action.
	var shown := {&"interact": KEY_E, &"cancel": KEY_Q, &"mark": KEY_C, &"count": KEY_X, &"undo": KEY_Z, &"redo": KEY_Y, &"menu": KEY_ESCAPE}
	for action in shown:
		assert_true(Input_Source_Keyboard.ACTION_KEYS[action].has(shown[action]), "%s" % action)

# === Hint text ===
func test_a_hint_splits_into_icons_and_text() -> void:
	var pieces := Logic_Input_Prompts.parse("{interact} Fill   {cancel} X")
	assert_eq(pieces, [{"action": &"interact"}, {"text": " Fill   "}, {"action": &"cancel"}, {"text": " X"}])

func test_plain_text_is_one_piece() -> void:
	assert_eq(Logic_Input_Prompts.parse("Just words"), [{"text": "Just words"}])
	assert_eq(Logic_Input_Prompts.parse(""), [])

func test_a_token_at_the_start_and_end() -> void:
	assert_eq(Logic_Input_Prompts.parse("{menu}"), [{"action": &"menu"}])
	assert_eq(Logic_Input_Prompts.parse("Pause {menu}"), [{"text": "Pause "}, {"action": &"menu"}])

func test_an_unknown_token_stays_as_text() -> void:
	var pieces := Logic_Input_Prompts.parse("a {oops} b {interact}")
	var joined := ""
	for p in pieces:
		joined += p.get("text", "<%s>" % p.get("action", ""))
	assert_eq(joined, "a {oops} b <interact>")

func test_an_unclosed_brace_is_plain_text() -> void:
	assert_eq(Logic_Input_Prompts.parse("a {interact"), [{"text": "a {interact"}])
