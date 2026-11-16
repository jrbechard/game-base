extends GutTest
## === Logic_Grid_Cursor: stepping, holding and wrapping ===

const RIGHT := Vector2i(1, 0)
const LEFT := Vector2i(-1, 0)
const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)

var cursor: Logic_Grid_Cursor

func before_each() -> void:
	cursor = Logic_Grid_Cursor.new()
	cursor.setup(4, 3)
	cursor.repeat.initial_delay = 0.3
	cursor.repeat.repeat_rate = 0.1

func test_a_press_moves_one_cell_at_once() -> void:
	assert_true(cursor.update(RIGHT, 0.016))
	assert_eq(cursor.position, Vector2i(1, 0))

func test_holding_waits_then_repeats() -> void:
	cursor.update(RIGHT, 0.016)             # moves to x=1
	assert_false(cursor.update(RIGHT, 0.1))  # still waiting out the delay
	assert_false(cursor.update(RIGHT, 0.1))
	assert_true(cursor.update(RIGHT, 0.15))  # the delay has passed
	assert_eq(cursor.position, Vector2i(2, 0))
	assert_true(cursor.update(RIGHT, 0.1), "then it repeats at the rate")
	assert_eq(cursor.position, Vector2i(3, 0))

func test_holding_stops_at_the_edge_and_does_not_wrap() -> void:
	cursor.place(Vector2i(3, 0))
	cursor.update(LEFT, 0.016)  # fresh: moves to x=2
	for i in 30:
		cursor.update(RIGHT if false else LEFT, 0.1)
	assert_eq(cursor.position, Vector2i(0, 0), "stopped at the left edge")
	for i in 10:
		cursor.update(LEFT, 0.1)
	assert_eq(cursor.position, Vector2i(0, 0), "still held: no wrap")

func test_a_fresh_press_at_the_edge_wraps() -> void:
	cursor.place(Vector2i(0, 0))
	cursor.update(LEFT, 0.016)
	assert_eq(cursor.position, Vector2i(3, 0))
	cursor.update(Vector2i.ZERO, 0.016)
	cursor.update(UP, 0.016)
	assert_eq(cursor.position, Vector2i(3, 2), "up from the top row wraps to the bottom")

func test_releasing_and_pressing_again_after_a_held_stop_wraps() -> void:
	cursor.place(Vector2i(2, 0))
	cursor.update(RIGHT, 0.016)  # to x=3, the edge
	for i in 6:
		cursor.update(RIGHT, 0.1)
	assert_eq(cursor.position, Vector2i(3, 0))
	cursor.update(Vector2i.ZERO, 0.016)  # let go
	cursor.update(RIGHT, 0.016)          # fresh press
	assert_eq(cursor.position, Vector2i(0, 0))

func test_changing_direction_while_holding_counts_as_a_fresh_press() -> void:
	cursor.place(Vector2i(3, 0))
	cursor.update(RIGHT, 0.016)  # fresh press at the edge wraps to x=0
	assert_eq(cursor.position, Vector2i(0, 0))
	cursor.update(UP, 0.016)     # a new direction: fresh, wraps to the bottom
	assert_eq(cursor.position, Vector2i(0, 2))

func test_place_clamps_inside_the_grid() -> void:
	cursor.place(Vector2i(99, -5))
	assert_eq(cursor.position, Vector2i(3, 0))

func test_index_is_row_by_row() -> void:
	cursor.place(Vector2i(2, 1))
	assert_eq(cursor.index(), 1 * 4 + 2)

func test_diagonals_pick_the_stronger_axis() -> void:
	assert_eq(Logic_Grid_Cursor.orthogonal(Vector2i(1, 1), Vector2(0.9, 0.6)), Vector2i(1, 0))
	assert_eq(Logic_Grid_Cursor.orthogonal(Vector2i(1, -1), Vector2(0.55, -0.9)), Vector2i(0, -1))
	assert_eq(Logic_Grid_Cursor.orthogonal(Vector2i(-1, 0), Vector2(-1.0, 0.1)), Vector2i(-1, 0))

func test_a_longer_hold_delay_waits_longer() -> void:
	cursor.repeat.initial_delay = 0.6
	cursor.update(RIGHT, 0.016)
	assert_false(cursor.update(RIGHT, 0.5))
	assert_true(cursor.update(RIGHT, 0.2))

# === The hold-delay setting ===
func test_the_hold_delay_setting_maps_to_seconds() -> void:
	assert_almost_eq(Logic_Stick_Repeat.delay_for_setting(0.0), 0.0, 0.0001)
	assert_almost_eq(Logic_Stick_Repeat.delay_for_setting(0.5), 0.35, 0.0001, "the default is the old 0.35 s")
	assert_almost_eq(Logic_Stick_Repeat.delay_for_setting(1.0), Logic_Stick_Repeat.MAX_INITIAL_DELAY, 0.0001)
	assert_almost_eq(Logic_Stick_Repeat.delay_for_setting(7.0), Logic_Stick_Repeat.MAX_INITIAL_DELAY, 0.0001, "clamped")

func test_the_router_follows_the_hold_delay_setting() -> void:
	Global_Manager_Input.init()
	Global_Manager_Events.setting_changed.emit(&"hold_delay", 1.0)
	assert_almost_eq(Global_Manager_Input._repeat.initial_delay, Logic_Stick_Repeat.MAX_INITIAL_DELAY, 0.0001)
	Global_Manager_Events.setting_changed.emit(&"hold_delay", 0.5)
	assert_almost_eq(Global_Manager_Input._repeat.initial_delay, 0.35, 0.0001)

func test_the_default_setting_is_half() -> void:
	assert_eq(State_Settings.DEFAULTS[&"hold_delay"], 0.5)
	assert_eq(State_Settings.sanitize(&"hold_delay", 3), 1.0, "clamped like every slider")
