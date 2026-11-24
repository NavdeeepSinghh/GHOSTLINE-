class_name Documents
extends RefCounted
## Every readable document in the game, loaded from data/documents/*.json.

const FILES: PackedStringArray = ["res://data/documents/dead_city.json", "res://data/documents/forest.json", "res://data/documents/facility.json"]

static var _areas: Array = []


## List of {"area": id, "area_title": String, "documents": Array of document dictionaries}.
static func areas() -> Array:
	if _areas.is_empty():
		for path: String in FILES:
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				continue
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_areas.append(parsed)
	return _areas


static func find(document_id: String) -> Dictionary:
	for area: Dictionary in areas():
		for document: Dictionary in area.get("documents", []):
			if str(document["id"]) == document_id:
				return document
	return {}


static func total() -> int:
	var count: int = 0
	for area: Dictionary in areas():
		count += (area.get("documents", []) as Array).size()
	return count
