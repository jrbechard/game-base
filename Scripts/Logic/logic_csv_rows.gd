class_name Logic_Csv_Rows
extends RefCounted
## === Read a data sheet (CSV) as a list of rows, each a dictionary keyed by the header ===
## Used by the Generate_ scripts. Blank lines are skipped and every value is trimmed.

static func read(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var cols := file.get_csv_line()
		if cols.size() < header.size() or cols[0].strip_edges().is_empty():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = cols[i].strip_edges()
		rows.append(row)
	return rows
