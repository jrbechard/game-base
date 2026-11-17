class_name UI_Level_Bar
extends Range
## === A stepped level shown as a row of blocks (volume, strength, delay) ===
## A Range, so the focus navigator already steps it with Left and Right and the settings screen
## treats it like any slider. `step` sets the number of blocks (0.2 = 5, 0.1 = 10). Clicking a
## block sets the level. Placeholder look: colours here are GUESS until the polish pass.

const FILLED := Color(0.35, 0.6, 1.0)
const EMPTY := Color(0.22, 0.24, 0.32)
const GAP := 4.0

# Why: the scene sets min, max and step; setting them here would run after the scene's values.
func _init() -> void:
	focus_mode = Control.FOCUS_ALL

func _ready() -> void:
	value_changed.connect(func(_v: float) -> void: queue_redraw())
	changed.connect(queue_redraw)

func notch_count() -> int:
	return maxi(1, roundi((max_value - min_value) / step))

## How many blocks are lit for the current value.
func lit_count() -> int:
	return roundi((value - min_value) / step)

func _draw() -> void:
	var count := notch_count()
	var lit := lit_count()
	var width := (size.x - GAP * (count - 1)) / count
	for i in count:
		draw_rect(Rect2(i * (width + GAP), 0.0, width, size.y), FILLED if i < lit else EMPTY)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var count := notch_count()
		var block := clampi(int(event.position.x / (size.x / count)), 0, count - 1)
		value = min_value + (block + 1) * step
		accept_event()
