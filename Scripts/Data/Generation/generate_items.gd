@tool
class_name Generate_Items
extends EditorScript
## === Build Data_Item .tres files from Data/Items/items.csv ===
## Run from the editor (File > Run) or call generate() from a test.
## One row per item. Re-running overwrites the .tres files.

const CSV_PATH := "res://Data/Items/items.csv"
const OUT_DIR := "res://Data/Items"
const TRANSLATIONS_PATH := "res://Data/Translations/items_translations.csv"
const LANGS: Array[String] = ["en", "fr"]  # es, de, ja are added later

func _run() -> void:
	generate()

# === Generation ===
## Returns the number of items written, or -1 on failure.
static func generate(csv_path: String = CSV_PATH, out_dir: String = OUT_DIR,
		translations_path: String = TRANSLATIONS_PATH) -> int:
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("Generate_Items: cannot open %s" % csv_path)
		return -1
	var header := file.get_csv_line()
	var translations := PackedStringArray(["keys," + ",".join(LANGS)])
	var count := 0
	while not file.eof_reached():
		var cols := file.get_csv_line()
		if cols.size() < header.size() or cols[0].is_empty():
			continue  # blank trailing line
		var row := {}
		for i in header.size():
			row[header[i]] = cols[i].strip_edges()

		var item := Data_Item.new()
		item.id = StringName(row["id"])
		item.number = int(row["number"])
		if not Data_Item.Kind.has(row["kind"]):
			push_error("Generate_Items: unknown kind '%s' for %s" % [row["kind"], row["id"]])
			return -1
		item.kind = Data_Item.Kind[row["kind"]]
		# Why: strings hold translation keys, not text.
		item.name = "item_%s_name" % row["id"]
		item.name_en = row["name_en"]

		var err := ResourceSaver.save(item, "%s/%03d_%s.tres" % [out_dir, item.number, row["id"]])
		if err != OK:
			push_error("Generate_Items: save failed for %s (%d)" % [row["id"], err])
			return -1
		var texts: Array[String] = []
		for lang in LANGS:
			texts.append(row["name_" + lang])
		translations.append("%s,%s" % [item.name, ",".join(texts)])
		count += 1
	DirAccess.make_dir_recursive_absolute(translations_path.get_base_dir())
	var out := FileAccess.open(translations_path, FileAccess.WRITE)
	out.store_string("\n".join(translations) + "\n")
	return count
