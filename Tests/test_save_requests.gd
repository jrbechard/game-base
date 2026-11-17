extends GutTest
## === Save: knows if a file exists, and writes at once when asked on the bus ===

const TEST_SAVE := "user://test_save_requests.json"

func before_each() -> void:
	_clean()
	Global_Manager_Events.init()
	Global_Manager_Save.init([], TEST_SAVE)

func after_all() -> void:
	_clean()
	Global_Manager_Save.init([])

func _clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)

func test_save_exists_follows_the_file() -> void:
	assert_false(Global_Manager_Save.save_exists())
	assert_true(Global_Manager_Save.save_now())
	assert_true(Global_Manager_Save.save_exists())

func test_a_save_request_writes_without_waiting_for_the_autosave() -> void:
	Global_Manager_Events.save_requested.emit()
	assert_true(Global_Manager_Save.save_exists())
