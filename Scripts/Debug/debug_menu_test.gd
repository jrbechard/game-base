extends Control
## === Debug_Menu_Test: the step 4 hardware test menu ===
## One menu that must work with keyboard, both pads and the mouse.
## Cancel (Esc / pad B-label / right click) hides and re-shows the menu, to show the
## animator and the navigator working together. F10 quits.
## Built in code on purpose: it is a throwaway test screen, not a real game screen.

const BUTTON_WIDTH := 300.0  # wide enough for the longest label, so no column grows
# Two buttons plus the 20 px gap between them.
const GRID_WIDTH := BUTTON_WIDTH * 2.0 + 20.0

var _nav: Component_Focus_Navigator
var _anim: UI_Animator
var _status: Label

func _ready() -> void:
	Global_Manager_Input.init()  # standalone scene: Main is not running
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override(&"separation", 24)
	add_child(column)

	var title := Label.new()
	title.text = "MENU TEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 20)
	grid.add_theme_constant_override(&"v_separation", 20)
	column.add_child(grid)
	for label in ["Start", "Options", "Items", "Extras", "Locked (disabled)", "Credits"]:
		var b := _button(label)
		b.disabled = label.begins_with("Locked")
		grid.add_child(b)

	# Why: a VBoxContainer makes every child as wide as its widest one. The status sentence
	# used to be that widest child, so Back stretched with it. Everything now shares the
	# grid's fixed width, and the status text wraps instead of growing.
	var back := _button("Back")
	back.custom_minimum_size = Vector2(GRID_WIDTH, 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(back)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(GRID_WIDTH, 0)
	column.add_child(_status)

	# Staggered pop-in over the grid's buttons (scale and fade work inside containers).
	_anim = UI_Animator.new()
	_anim.preset = load("res://Data/UI/Animations/pop.tres")
	_anim.animate_children = true
	_anim.stagger = 0.06
	_anim.start_shown = false
	grid.add_child(_anim)

	_nav = Component_Focus_Navigator.new()
	_nav.root = self
	_nav.enabled = false
	add_child(_nav)
	_nav.activated.connect(_on_activated)
	_nav.cancelled.connect(_on_cancelled)
	Global_Manager_Events.menu_navigated.connect(func() -> void: _say("navigated -> " + _focus_name()))
	# Why: logs the cause of every move (device mode + action) so one-step-per-press is checkable.
	Global_Manager_Events.ui_action_triggered.connect(func(a: StringName) -> void:
			print("MENU_TEST action %s  mode=%s  focus=%s" % [
					a, Global_Manager_Input.DeviceMode.keys()[Global_Manager_Input.device_mode], _focus_name()]))

	await get_tree().process_frame
	await _enter()

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(BUTTON_WIDTH, 64)
	b.focus_mode = Control.FOCUS_ALL
	var fx := Component_Hover_Effect.new()
	b.add_child(fx)
	return b

# Disable input while animating; hand it back and focus the default when settled.
func _enter() -> void:
	_nav.enabled = false
	await _anim.show_animated()
	_nav.enabled = true
	_nav.focus_default()

func _on_activated(control: Control) -> void:
	_say("ACTIVATED: " + (control as Button).text)

func _on_cancelled() -> void:
	_say("CANCELLED: hiding, then showing again")
	_nav.enabled = false
	await _anim.hide_animated()
	await get_tree().create_timer(0.4).timeout
	await _enter()

func _focus_name() -> String:
	var f := _nav.focused_control() as Button
	return f.text if f != null else "none"

func _say(text: String) -> void:
	print("MENU_TEST ", text)
	_status.text = text

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		get_tree().quit()
