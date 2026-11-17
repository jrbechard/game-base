extends GutTest
## === Step 7 pure logic: the area map, free movement and reach ===

const TILE := Logic_Area_Map.TILE

# === The map text ===
func test_a_map_parses_into_walls_and_floor() -> void:
	var map := Logic_Area_Map.parse("###/#.#/###")
	assert_not_null(map)
	assert_eq(map.width, 3)
	assert_eq(map.height, 3)
	assert_true(map.is_solid(Vector2i(0, 0)))
	assert_false(map.is_solid(Vector2i(1, 1)))

func test_everything_outside_the_map_is_solid() -> void:
	var map := Logic_Area_Map.parse("...")
	assert_true(map.is_solid(Vector2i(-1, 0)))
	assert_true(map.is_solid(Vector2i(3, 0)))
	assert_true(map.is_solid(Vector2i(0, 1)))

func test_bad_maps_are_refused_with_a_reason() -> void:
	var why := []
	assert_null(Logic_Area_Map.parse("", why))
	assert_null(Logic_Area_Map.parse("##/#", why), "rows of different lengths")
	assert_null(Logic_Area_Map.parse("#x#", why), "an unknown character")
	assert_eq(why.size(), 3)

func test_cell_and_pixel_conversion_round_trip() -> void:
	assert_eq(Logic_Area_Map.cell_of(Vector2(125, 61)), Vector2i(2, 1))
	assert_eq(Logic_Area_Map.cell_of(Vector2(-1, -1)), Vector2i(-1, -1))
	assert_eq(Logic_Area_Map.center_of(Vector2i(2, 1)), Vector2(150, 90))

# === Walking ===
func _open_room() -> Callable:
	var map := Logic_Area_Map.parse("#####/#...#/#...#/#...#/#####")
	return func(cell: Vector2i) -> bool: return map.is_solid(cell)

func test_walking_in_open_floor_moves_the_full_distance() -> void:
	var end := Logic_Overworld_Move.move(Vector2(150, 150), Vector2(20, 10), 22.0, _open_room())
	assert_eq(end, Vector2(170, 160))

func test_a_wall_stops_the_player_flush_against_it() -> void:
	var end := Logic_Overworld_Move.move(Vector2(200, 150), Vector2(500, 0), 22.0, _open_room())
	assert_lt(end.x, 4.0 * TILE - 22.0 + 0.01, "never inside the wall")
	assert_gt(end.x, 4.0 * TILE - 22.0 - 0.1, "and right up against it")

func test_a_diagonal_push_slides_along_the_wall() -> void:
	var end := Logic_Overworld_Move.move(Vector2(4.0 * TILE - 22.0 - 0.01, 150), Vector2(30, 30), 22.0, _open_room())
	assert_almost_eq(end.y, 180.0, 0.01, "the free axis still moves")
	assert_lt(end.x, 4.0 * TILE - 22.0 + 0.01, "the blocked axis does not")

func test_a_huge_step_cannot_tunnel_through_a_wall() -> void:
	var end := Logic_Overworld_Move.move(Vector2(150, 150), Vector2(5000, 0), 22.0, _open_room())
	assert_lt(end.x, 4.0 * TILE)

func test_a_gap_one_tile_wide_lets_the_player_through() -> void:
	var map := Logic_Area_Map.parse("#####/#.#.#/#...#/#.#.#/#####")  # the middle tile of each pillar row is open
	var blocked := func(cell: Vector2i) -> bool: return map.is_solid(cell)
	var pos := Vector2(1.5 * TILE, 2.5 * TILE)
	for i in 30:
		pos = Logic_Overworld_Move.move(pos, Vector2(6, 0), 22.0, blocked)
	assert_gt(pos.x, 3.0 * TILE, "walked down the one-tile corridor to the far side")

func test_a_diagonal_is_no_faster_than_a_straight_line() -> void:
	assert_almost_eq(Logic_Overworld_Move.walk_direction(Vector2(1, 1)).length(), 1.0, 0.001)
	assert_almost_eq(Logic_Overworld_Move.walk_direction(Vector2(1, 0)).length(), 1.0, 0.001)
	assert_almost_eq(Logic_Overworld_Move.walk_direction(Vector2(0.3, 0)).length(), 0.3, 0.001, "a gentle stick walks slowly")

func test_the_directions_pull_the_stick_like_a_magnet() -> void:
	# A stick a few degrees off "right" is pulled most of the way onto it (not necessarily all of it).
	var near := Logic_Overworld_Move.walk_direction(Vector2.from_angle(deg_to_rad(4.0)))
	assert_lt(absf(rad_to_deg(near.angle())), 1.0, "4 degrees off is pulled to under 1")
	# Exactly on a direction stays there.
	assert_almost_eq(rad_to_deg(Logic_Overworld_Move.walk_direction(Vector2(1, 1)).angle()), 45.0, 0.01)
	# Halfway between two directions the stick is left alone: free angles still exist.
	var between := Logic_Overworld_Move.walk_direction(Vector2.from_angle(deg_to_rad(22.0)))
	assert_almost_eq(rad_to_deg(between.angle()), 22.0, 1.0)
	assert_eq(Logic_Overworld_Move.walk_direction(Vector2.ZERO), Vector2.ZERO)

func test_the_pull_never_jumps_between_directions() -> void:
	# Turning the stick a little never turns the walk by a lot, also across the halfway point.
	var last := Logic_Overworld_Move.walk_direction(Vector2.from_angle(0.0)).angle()
	for i in range(1, 361):
		var now := Logic_Overworld_Move.walk_direction(Vector2.from_angle(deg_to_rad(float(i)))).angle()
		assert_lt(absf(angle_difference(last, now)), deg_to_rad(4.0), "no jump at %d degrees" % i)
		last = now

func test_the_pull_keeps_the_stick_strength() -> void:
	assert_almost_eq(Logic_Overworld_Move.walk_direction(Vector2(0.3, 0.05)).length(), 0.304, 0.01)

# === Reach ===
func test_the_nearest_thing_in_reach_wins() -> void:
	var points := PackedVector2Array([Vector2(100, 0), Vector2(40, 0), Vector2(500, 0)])
	assert_eq(Logic_Overworld_Move.nearest_in_reach(Vector2.ZERO, points, 96.0), 1)

func test_nothing_in_reach_gives_minus_one() -> void:
	assert_eq(Logic_Overworld_Move.nearest_in_reach(Vector2.ZERO, PackedVector2Array([Vector2(300, 0)]), 96.0), -1)
	assert_eq(Logic_Overworld_Move.nearest_in_reach(Vector2.ZERO, PackedVector2Array(), 96.0), -1)
