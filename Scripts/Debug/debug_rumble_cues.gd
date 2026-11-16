extends Control
## === Debug_Rumble_Cues: feel the starter rumble cues (build step 4e hardware test) ===
## Move with keyboard, pad or mouse; activate a button to fire a cue on the ACTIVE pad
## (the last one you pressed a button on). Keyboard and mouse buzz nothing, by design.
##   - One button per cue fires it directly.
##   - "Grant next item" goes the whole way: intent -> Progress -> item_acquired -> rumble.
##   - "Strength" cycles the master rumble scale 100% / 50% / 0%.
## F10 quits. Does not touch your real save (Save is not started here).

const SCALES: Array[float] = [1.0, 0.5, 0.0]

var _nav: Component_Focus_Navigator
var _status: Label
var _strength_button: Button
var _scale_index := 0

func _ready() -> void:
	# Standalone scene: Main is not running, so start what this test needs.
	Global_Manager_GameData.init()
	Global_Manager_Progress.init()
	Global_Manager_Progress.state.from_dict({})
	Global_Manager_Input.init()
	Global_Manager_Rumble.init(func() -> int: return Global_Manager_Input.source.get_device())
	_wrap_backend_for_logging()
	Global_Manager_Events.item_acquired.connect(func(id: StringName) -> void: print("RUMBLE_CUES item_acquired on the bus: ", id))

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override(&"separation", 16)
	add_child(column)

	var title := Label.new()
	title.text = "RUMBLE CUES   (F10 quits)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	for cue in _cue_ids():
		column.add_child(_button(String(cue), cue))
	column.add_child(_button("Grant next item (full chain)", &"__grant"))
	_strength_button = _button("", &"__strength")
	column.add_child(_strength_button)
	_refresh_strength_label()

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(420, 0)
	column.add_child(_status)

	_nav = Component_Focus_Navigator.new()
	_nav.root = self
	add_child(_nav)
	_nav.activated.connect(_on_activated)
	await get_tree().process_frame
	_nav.focus_default()

func _button(text: String, tag: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta(&"tag", tag)
	b.custom_minimum_size = Vector2(420, 60)
	b.focus_mode = Control.FOCUS_ALL
	b.add_child(Component_Hover_Effect.new())
	return b

func _on_activated(control: Control) -> void:
	var tag: StringName = control.get_meta(&"tag")
	var device := Global_Manager_Input.source.get_device()
	print("RUMBLE_CUES activated '%s'  mode=%s  active pad=%d" % [
			tag, Global_Manager_Input.DeviceMode.keys()[Global_Manager_Input.device_mode], device])
	match tag:
		&"__grant": _grant_next_item()
		&"__strength": _cycle_strength()
		_: Global_Manager_Rumble.play(tag)
	_say("%s  |  active pad: %s" % [tag, "none (keyboard/mouse)" if device < 0 else Input.get_joy_name(device)])

# The lists come from the data, so this scene never names a particular game's cues or items.
func _cue_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for fx: Data_Rumble_Effect in Global_Manager_GameData.get_all_rumble_effects():
		ids.append(fx.id)
	ids.sort()
	return ids

func _item_ids() -> Array[StringName]:
	var items := Global_Manager_GameData.get_all_items()
	items.sort_custom(func(a: Data_Item, b: Data_Item) -> bool: return a.number < b.number)
	var ids: Array[StringName] = []
	for item: Data_Item in items:
		ids.append(item.id)
	return ids

func _grant_next_item() -> void:
	for id in _item_ids():
		if not Global_Manager_Progress.has_item(id):
			Global_Manager_Events.item_grant_requested.emit(id)
			return
	Global_Manager_Progress.state.from_dict({})  # all owned: start over
	print("RUMBLE_CUES all items owned, reset. Press again to grant the first one.")

func _cycle_strength() -> void:
	_scale_index = (_scale_index + 1) % SCALES.size()
	Global_Manager_Rumble.rumble_scale = SCALES[_scale_index]
	_refresh_strength_label()

func _refresh_strength_label() -> void:
	_strength_button.text = "Strength: %d%%" % int(SCALES[_scale_index] * 100.0)

func _say(text: String) -> void:
	_status.text = text

# Log every hardware call, then pass it on to the real one.
func _wrap_backend_for_logging() -> void:
	var real := Global_Manager_Rumble.backend
	Global_Manager_Rumble.backend = func(d: int, w: float, s: float, t: float) -> void:
		print("RUMBLE_CUES send device=%d weak=%.2f strong=%.2f duration=%.2f" % [d, w, s, t])
		real.call(d, w, s, t)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		get_tree().quit()
