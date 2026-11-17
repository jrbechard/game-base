class_name Logic_Overworld_Move
extends RefCounted
## === Free top-down movement against tiles, and who is in reach ===
## Pure functions. The player is a square of half-size `half`; `blocked` is a Callable
## (Vector2i cell) -> bool. Each axis moves on its own, so a diagonal push against a wall
## slides along it instead of sticking.

## GUESS: how strongly the 8 directions pull the stick. 1 = no pull (fully free), higher = a wider
## and stronger magnet around each direction, and a loose stick between them.
const SNAP_PULL := 2.5

## The direction to walk: the stick or keys, eased toward the 8 directions like a magnet. Close to
## right (or up, or a diagonal) it lands exactly on it; further away it blends smoothly into free
## angles, with no sudden jump between directions. Never longer than 1, so a diagonal is no faster
## than a straight line. A weak stick keeps its small size (slow walking).
static func walk_direction(input: Vector2) -> Vector2:
	var strength := minf(input.length(), 1.0)
	if is_zero_approx(strength):
		return Vector2.ZERO
	var step := TAU / 8.0
	var angle := input.angle()
	var nearest := roundf(angle / step) * step
	var offset := angle - nearest                      # -step/2 .. step/2 away from the direction
	var closeness := absf(offset) / (step * 0.5)       # 0 on the direction, 1 halfway to the next one
	# The pull shrinks the offset near a direction and leaves it whole halfway between two.
	var eased := offset * pow(closeness, SNAP_PULL - 1.0)
	return Vector2.from_angle(nearest + eased) * strength

## A long step (a frame hitch) is cut into pieces of at most half a tile, so it can never jump over
## a wall and always ends flush against the first one it meets.
static func move(position: Vector2, motion: Vector2, half: float, blocked: Callable) -> Vector2:
	var pieces := maxi(1, ceili(maxf(absf(motion.x), absf(motion.y)) / (Logic_Area_Map.TILE * 0.5)))
	var piece := motion / pieces
	var pos := position
	for i in pieces:
		pos.x = _move_axis(pos, piece.x, half, blocked, true)
		pos.y = _move_axis(pos, piece.y, half, blocked, false)
	return pos

static func _move_axis(pos: Vector2, amount: float, half: float, blocked: Callable, horizontal: bool) -> float:
	var start := pos.x if horizontal else pos.y
	if is_zero_approx(amount):
		return start
	var target := start + amount
	var test := pos
	if horizontal:
		test.x = target
	else:
		test.y = target
	if not _box_blocked(test, half, blocked):
		return target
	# Blocked: stand against the wall instead (flush with the tile edge, never inside it).
	var tile := float(Logic_Area_Map.TILE)
	var edge_cell := floorf((target + half * signf(amount)) / tile)
	var flush := edge_cell * tile - half - 0.001 if amount > 0.0 else (edge_cell + 1.0) * tile + half + 0.001
	if (amount > 0.0 and flush < start) or (amount < 0.0 and flush > start):
		return start  # already touching: do not jump backwards
	var moved := pos
	if horizontal:
		moved.x = flush
	else:
		moved.y = flush
	return flush if not _box_blocked(moved, half, blocked) else start

static func _box_blocked(pos: Vector2, half: float, blocked: Callable) -> bool:
	var lo := Logic_Area_Map.cell_of(pos - Vector2(half, half))
	var hi := Logic_Area_Map.cell_of(pos + Vector2(half, half))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if blocked.call(Vector2i(x, y)):
				return true
	return false

## The index of the nearest point within `reach` of `from`, or -1 when none is.
static func nearest_in_reach(from: Vector2, points: PackedVector2Array, reach: float) -> int:
	var best := -1
	var best_distance := reach
	for i in points.size():
		var d := from.distance_to(points[i])
		if d <= best_distance:
			best_distance = d
			best = i
	return best
