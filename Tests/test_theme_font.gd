extends GutTest
## === The base's default font is Inter ===

const THEME := "res://Assets/Theming/theme_main.tres"
const FRENCH := "àâäçéèêëîïôöùûüÿœæÀÂÇÉÈÊËÎÏÔÙÛŒ«»’…"

func test_inter_is_the_default_font() -> void:
	var theme := load(THEME) as Theme
	var font := theme.default_font as FontFile
	assert_not_null(font)
	assert_string_ends_with(font.resource_path, "Inter_18pt-Regular.ttf")
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), THEME, "the project uses this theme")

func test_the_default_font_can_write_french() -> void:
	var font := (load(THEME) as Theme).default_font
	for c in FRENCH:
		assert_true(font.has_char(c.unicode_at(0)), c)

func test_a_bold_label_style_uses_inter_bold() -> void:
	var theme := load(THEME) as Theme
	var bold := theme.get_font(&"font", &"Label_Bold") as FontVariation
	assert_string_ends_with((bold.base_font as FontFile).resource_path, "Inter_18pt-Bold.ttf")
	assert_eq(theme.get_type_variation_base(&"Label_Bold"), &"Label")

func test_the_licence_travels_with_the_font() -> void:
	assert_true(FileAccess.file_exists("res://Assets/Fonts/OFL_Inter.txt"))
