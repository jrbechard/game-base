extends GutTest
## === Build step 2 boundary test: generate items from CSV, fetch each by id ===

func before_all() -> void:
	assert_eq(Generate_Items.generate(), 3, "generator wrote 3 items")
	# Why: make the editor see the new files before GameData loads them.
	Global_Manager_GameData.init()

func test_fetch_each_item_by_id() -> void:
	var expected := {
		&"example_tool": [Data_Item.Kind.TOOL, "Example Tool"],
		&"example_key": [Data_Item.Kind.KEY, "Example Key"],
		&"example_boost": [Data_Item.Kind.BOOST, "Example Boost"],
	}
	for id in expected:
		var item := Global_Manager_GameData.get_item(id)
		assert_not_null(item, "found %s" % id)
		if item == null:
			continue
		assert_eq(item.id, id)
		assert_eq(item.kind, expected[id][0], "kind of %s" % id)
		assert_eq(item.name_en, expected[id][1], "name of %s" % id)
		assert_eq(item.name, "item_%s_name" % id, "name is a translation key")

func test_unknown_id_returns_null() -> void:
	assert_null(Global_Manager_GameData.get_item(&"does_not_exist"))
	assert_push_warning_count(1)

func test_name_key_translates() -> void:
	var item := Global_Manager_GameData.get_item(&"example_tool")
	TranslationServer.set_locale("en")
	assert_eq(tr(item.name), "Example Tool")
	TranslationServer.set_locale("fr")
	assert_eq(tr(item.name), "Outil exemple")
	TranslationServer.set_locale("en")
