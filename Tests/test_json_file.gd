extends GutTest
## === Build step 4f-2 tests: Logic_Json_File (shared by the save and the settings) ===

const PATH := "user://test_json_file.json"

func before_each() -> void:
	_delete()

func after_all() -> void:
	_delete()

func _delete() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

func _corrupt(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()

func test_write_then_read_round_trips() -> void:
	assert_true(Logic_Json_File.write_atomic(PATH, {"a": 1.0, "b": "x"}))
	assert_eq(Logic_Json_File.read(PATH), {"a": 1.0, "b": "x"})

func test_no_temp_file_is_left_behind() -> void:
	Logic_Json_File.write_atomic(PATH, {"a": 1.0})
	assert_false(FileAccess.file_exists(PATH + ".tmp"))

func test_second_write_keeps_the_first_as_a_backup() -> void:
	Logic_Json_File.write_atomic(PATH, {"v": 1.0})
	Logic_Json_File.write_atomic(PATH, {"v": 2.0})
	assert_eq(Logic_Json_File.read(PATH), {"v": 2.0})
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH + ".bak"))
	assert_eq(backup, {"v": 1.0})

func test_corrupt_file_falls_back_to_the_backup() -> void:
	Logic_Json_File.write_atomic(PATH, {"v": 1.0})
	Logic_Json_File.write_atomic(PATH, {"v": 2.0})
	_corrupt(PATH)
	assert_eq(Logic_Json_File.read(PATH), {"v": 1.0})
	assert_push_warning_count(1)

func test_both_files_corrupt_gives_empty() -> void:
	Logic_Json_File.write_atomic(PATH, {"v": 1.0})
	Logic_Json_File.write_atomic(PATH, {"v": 2.0})
	_corrupt(PATH)
	_corrupt(PATH + ".bak")
	assert_eq(Logic_Json_File.read(PATH), {})
	assert_push_warning_count(2)

func test_missing_file_gives_empty_without_a_warning() -> void:
	assert_eq(Logic_Json_File.read(PATH), {})
	assert_push_warning_count(0)

func test_required_key_must_hold_a_dictionary() -> void:
	Logic_Json_File.write_atomic(PATH, {"other": 1.0})
	assert_eq(Logic_Json_File.read(PATH, "settings"), {})
	assert_push_warning_count(1)
	_delete()
	Logic_Json_File.write_atomic(PATH, {"settings": {"x": 1.0}})
	assert_eq(Logic_Json_File.read(PATH, "settings"), {"settings": {"x": 1.0}})
