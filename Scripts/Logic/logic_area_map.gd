class_name Logic_Area_Map
extends RefCounted
## === An area's tile map: walls and floor, as text ===
## Rows joined with "/": `#` wall, `.` floor. One area is one fixed screen: 32 x 18 tiles of 60
## pixels fill a 1920 x 1080 screen exactly. Pure logic: no nodes.

const TILE := 60
const WALL := "#"
const FLOOR := "."

var width := 0
var height := 0
var _solid := PackedByteArray()

## Returns a map, or null with a reason in `error` when the text is not a rectangle of # and . only.
static func parse(text: String, error: Array = []) -> Logic_Area_Map:
	var rows := text.strip_edges().split("/")
	if rows.is_empty() or rows[0].is_empty():
		error.append("the map is empty")
		return null
	var map := Logic_Area_Map.new()
	map.height = rows.size()
	map.width = rows[0].length()
	map._solid.resize(map.width * map.height)
	for y in map.height:
		if rows[y].length() != map.width:
			error.append("row %d has %d tiles, expected %d" % [y + 1, rows[y].length(), map.width])
			return null
		for x in map.width:
			var c := rows[y][x]
			if c != WALL and c != FLOOR:
				error.append("row %d has the character '%s'; only # and . are allowed" % [y + 1, c])
				return null
			map._solid[y * map.width + x] = 1 if c == WALL else 0
	return map

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

## Walls are solid, and so is everything outside the map (the player can never leave the screen).
func is_solid(cell: Vector2i) -> bool:
	return not in_bounds(cell) or _solid[cell.y * width + cell.x] == 1

static func cell_of(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))

static func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
