extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const DEFAULT_RESOURCES := {
	"prestige": 5,
}

var resources: Dictionary = DEFAULT_RESOURCES.duplicate()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func reset() -> void:
	resources = DEFAULT_RESOURCES.duplicate()


func save_game() -> Error:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_to_save_dict(), "\t"))
	return OK


func load_game() -> Error:
	if not has_save():
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return _apply_save_dict(parsed)


func _to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"resources": resources.duplicate(),
	}


func _apply_save_dict(data: Dictionary) -> Error:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return ERR_INVALID_DATA
	var saved_resources: Variant = data.get("resources")

	resources = DEFAULT_RESOURCES.duplicate()
	for key in resources:
		if saved_resources.has(key):
			resources[key] = saved_resources[key]
	return OK
