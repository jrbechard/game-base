class_name Logic_Mouse_Cursors
extends RefCounted
## === The game's own mouse cursors (Kenney's Cursor Pack, CC0, see docs/CREDITS.md) ===
## Godot lets a game replace each standard cursor shape with its own picture. `apply()` does it
## once at start-up; after that any Control that asks for a shape (a button asks for the hand, the
## puzzle grid asks for the pencil) shows ours. The shapes the game uses:
##   ARROW          the pointer          POINTING_HAND  over buttons
##   CROSS          a pencil, over the grid    CAN_DROP  an eraser, while erasing in the editor
##   BUSY           waiting              FORBIDDEN      not allowed here
## Hotspots are the pixel of the picture that does the pointing (the arrow's tip, the pencil's point).

const ROOT := "res://Assets/Cursors/"

## shape -> [file name, hotspot in the 32 px picture]
const SHAPES := {
	Input.CURSOR_ARROW: ["pointer_a.png", Vector2(9, 6)],
	Input.CURSOR_POINTING_HAND: ["hand_point.png", Vector2(9, 3)],
	Input.CURSOR_BUSY: ["busy_circle.png", Vector2(15, 15)],
	Input.CURSOR_FORBIDDEN: ["cursor_disabled.png", Vector2(3, 2)],
	Input.CURSOR_CROSS: ["drawing_pencil.png", Vector2(5, 5)],
	Input.CURSOR_CAN_DROP: ["drawing_eraser.png", Vector2(15, 15)],
}

## Give every shape above its picture.
static func apply() -> void:
	for shape in SHAPES:
		var entry: Array = SHAPES[shape]
		var texture := load(ROOT + entry[0]) as Texture2D
		if texture == null:
			push_warning("Logic_Mouse_Cursors: cannot load %s" % entry[0])
			continue
		Input.set_custom_mouse_cursor(texture, shape as Input.CursorShape, entry[1])
