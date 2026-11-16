extends GutTest
## === Build step 1 boundary test: Main boots and opens the empty shell ===

func test_main_boots_to_shell() -> void:
	var main: Node = load("res://Scenes/Global/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(2)
	var host: Node = main.get_node("Screen_Host")
	assert_eq(host.get_child_count(), 1, "one screen in Screen_Host")
	assert_eq(host.get_child(0).name, &"Shell_Empty")
