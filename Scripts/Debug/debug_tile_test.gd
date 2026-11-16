extends Node2D
## === Debug_Tile_Test: vector tile seam test (build step 1) ===
## Why: proves SVG tiles imported at scale 4 show no seams while the camera
## moves at fractional positions. Run windowed (headless has no renderer):
##   Godot --path . res://Scenes/Global/debug_tile_test.tscn -- filter=linear|nearest
## Window size sets the test resolution (--resolution 1280x720 etc.).

const TILE_PX := 64            # 16 SVG units at import scale 4
const SOLID_CELLS := 40        # tile 0 only, so any other pixel is a seam
const MAP_CELLS := 80
const FRAMES := 60
const TOLERANCE := 3           # per channel, 0-255
const SOLID_COLOR := Color("4CAF50")

@onready var _camera: Camera2D = $Camera2D
@onready var _layer: TileMapLayer = $TileMapLayer

func _ready() -> void:
	var filter := "linear"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("filter="):
			filter = arg.get_slice("=", 1)
	_layer.texture_filter = (CanvasItem.TEXTURE_FILTER_NEAREST if filter == "nearest"
			else CanvasItem.TEXTURE_FILTER_LINEAR)
	_layer.tile_set = _build_tile_set()
	_fill_map()
	_run_test(filter)

# === Build ===
func _build_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_PX, TILE_PX)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://Assets/SVG/tiles_test.svg")
	src.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	for i in 8:
		src.create_tile(Vector2i(i % 4, i / 4))
	ts.add_source(src)
	return ts

func _fill_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for y in MAP_CELLS:
		for x in MAP_CELLS:
			var id := 0
			if x >= SOLID_CELLS or y >= SOLID_CELLS:
				id = rng.randi_range(0, 7)
			_layer.set_cell(Vector2i(x, y), 0, Vector2i(id % 4, id / 4))

# === Test ===
func _run_test(filter: String) -> void:
	var center := Vector2(SOLID_CELLS * TILE_PX * 0.5, SOLID_CELLS * TILE_PX * 0.5)
	var worst := 0
	var shot_saved := false
	for f in FRAMES:
		# Why: odd fractional steps hit many sub-pixel offsets, where seams appear.
		_camera.position = center + Vector2(f * 0.37, f * 0.23 + sin(f * 0.5) * 3.1)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var bad := _count_bad_pixels(img)
		worst = maxi(worst, bad)
		if not shot_saved:
			img.save_png("user://tile_test_%dx%d_%s.png" % [img.get_width(), img.get_height(), filter])
			shot_saved = true
	print("TILE_TEST size=%s filter=%s frames=%d worst_bad_pixels=%d" % [
			get_viewport().get_visible_rect().size, filter, FRAMES, worst])
	get_tree().quit()

func _count_bad_pixels(img: Image) -> int:
	var bad := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if absf(c.r - SOLID_COLOR.r) * 255.0 > TOLERANCE \
					or absf(c.g - SOLID_COLOR.g) * 255.0 > TOLERANCE \
					or absf(c.b - SOLID_COLOR.b) * 255.0 > TOLERANCE:
				bad += 1
	return bad
