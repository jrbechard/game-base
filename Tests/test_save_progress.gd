extends GutTest
## === Build step 3 boundary test: grant an item, save, quit, load, still owned ===
## Uses a separate save path so a real save is never touched.

const TEST_PATH := "user://test_save.json"

func before_all() -> void:
	Global_Manager_GameData.init()

func before_each() -> void:
	_delete_test_files()
	Global_Manager_Progress.init()
	Global_Manager_Progress.state.from_dict({})
	Global_Manager_Save.init([Global_Manager_Progress.state], TEST_PATH)

func after_all() -> void:
	_delete_test_files()
	Global_Manager_Save.init([Global_Manager_Progress.state])  # back to the real path

func _delete_test_files() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)

func _grant(id: StringName) -> void:
	Global_Manager_Events.item_grant_requested.emit(id)

# === Core loop ===
func test_grant_save_quit_load() -> void:
	_grant(&"example_tool")
	assert_true(Global_Manager_Progress.has_item(&"example_tool"))
	assert_true(Global_Manager_Save.save_now())
	# "Quit": the in-memory state is gone.
	Global_Manager_Progress.state.from_dict({})
	assert_false(Global_Manager_Progress.has_item(&"example_tool"))
	assert_true(Global_Manager_Save.load_now())
	assert_true(Global_Manager_Progress.has_item(&"example_tool"), "item survives save and load")

func test_grant_emits_item_acquired_once() -> void:
	watch_signals(Global_Manager_Events)
	_grant(&"example_boost")
	_grant(&"example_boost")
	assert_signal_emit_count(Global_Manager_Events, "item_acquired", 1)
	assert_signal_emitted_with_parameters(Global_Manager_Events, "item_acquired", [&"example_boost"])

func test_unknown_item_is_refused() -> void:
	_grant(&"does_not_exist")
	assert_false(Global_Manager_Progress.has_item(&"does_not_exist"))
	assert_push_warning_count(1)

# === Autosave ===
func test_change_autosaves() -> void:
	_grant(&"key")
	assert_false(FileAccess.file_exists(TEST_PATH), "not written instantly")
	await wait_seconds(0.6)
	assert_true(FileAccess.file_exists(TEST_PATH), "written shortly after the change")

# === Safety ===
func test_corrupt_save_falls_back_to_backup() -> void:
	_grant(&"example_tool")
	Global_Manager_Save.save_now()
	_grant(&"example_boost")
	Global_Manager_Save.save_now()  # the first save is now the backup
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	Global_Manager_Progress.state.from_dict({})
	assert_true(Global_Manager_Save.load_now(), "backup loaded")
	assert_true(Global_Manager_Progress.has_item(&"example_tool"))
	assert_false(Global_Manager_Progress.has_item(&"example_boost"), "backup predates the boost")
	assert_push_warning_count(1)

func test_corrupt_save_without_backup_does_not_crash() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	assert_false(Global_Manager_Save.load_now())
	assert_eq(Global_Manager_Progress.state.items_owned.size(), 0)
	assert_push_warning_count(1)
