class_name Logic_Grid_Cursor
extends RefCounted
## === A cursor on a grid of cells ===
## Pure logic, no nodes: feed it the held direction and the frame time, and it says where the
## cursor is. Rules (from Picross S, confirmed by JR):
##   - one step when a direction is pressed, then a short wait (`repeat.initial_delay`), then
##     steps at `repeat.repeat_rate` while the direction stays held
##   - at the edge, a HELD direction stops; a fresh press wraps to the other side

var width := 1
var height := 1
var position := Vector2i.ZERO
## Timing of held directions. The delay is the player's "hold delay" setting. GUESS: a grid
## cursor repeats faster than a menu (0.07 s a step, about 14 cells a second; menus use 0.12).
var repeat := Logic_Stick_Repeat.new()

func _init() -> void:
	repeat.repeat_rate = 0.07

func setup(grid_width: int, grid_height: int) -> void:
	width = maxi(grid_width, 1)
	height = maxi(grid_height, 1)
	position = Vector2i.ZERO
	repeat.reset()

## Put the cursor on a cell (clamped inside the grid). Used by the mouse.
func place(cell: Vector2i) -> void:
	position = Vector2i(clampi(cell.x, 0, width - 1), clampi(cell.y, 0, height - 1))

func index() -> int:
	return position.y * width + position.x

## One frame. `dir` is -1/0/1 per axis (use `orthogonal` to turn a stick into one). Returns
## true if the cursor moved.
func update(dir: Vector2i, delta: float) -> bool:
	if not repeat.update(dir, delta):
		return false
	return step(dir, repeat.last_fire_was_fresh)

## Move one cell. A step off the edge wraps only when `fresh` is true.
func step(dir: Vector2i, fresh: bool) -> bool:
	if dir == Vector2i.ZERO:
		return false
	var target := position + dir
	var inside := target.x >= 0 and target.x < width and target.y >= 0 and target.y < height
	if inside:
		position = target
		return true
	if not fresh:
		return false  # holding stops at the edge
	position = Vector2i(posmod(target.x, width), posmod(target.y, height))
	return true

## A stick or d-pad direction can be diagonal; the cursor moves along one axis only, the
## stronger one.
static func orthogonal(dir: Vector2i, raw: Vector2) -> Vector2i:
	if dir.x != 0 and dir.y != 0:
		return Vector2i(dir.x, 0) if absf(raw.x) >= absf(raw.y) else Vector2i(0, dir.y)
	return dir
