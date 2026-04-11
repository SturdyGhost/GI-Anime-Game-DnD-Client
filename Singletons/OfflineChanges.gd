extends Node
## Logs mutations made during offline mode to user://offline_changes.json.
## On reconnect, the log is submitted to the host and cleared.

const CHANGES_PATH := "user://offline_changes.json"

var _changes: Array = []

func _ready() -> void:
	_load_from_disk()

func _load_from_disk() -> void:
	if not FileAccess.file_exists(CHANGES_PATH):
		_changes = []
		return
	var file = FileAccess.open(CHANGES_PATH, FileAccess.READ)
	if file == null:
		_changes = []
		return
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	_changes = parsed if parsed is Array else []

func _save_to_disk() -> void:
	var file = FileAccess.open(CHANGES_PATH, FileAccess.WRITE)
	if file == null:
		push_error("OfflineChanges: Failed to save changes log")
		return
	file.store_string(JSON.stringify(_changes, "\t"))
	file.close()

func log_update(table: String, record_id: int, field: String, value) -> void:
	_changes.append({
		"action": "update",
		"table": table,
		"record_id": record_id,
		"field": field,
		"value": value,
		"timestamp": Time.get_datetime_string_from_system()
	})
	_save_to_disk()

func log_insert(table: String, record_id: int, record: Dictionary) -> void:
	_changes.append({
		"action": "insert",
		"table": table,
		"record_id": record_id,
		"data": record.duplicate(true),
		"timestamp": Time.get_datetime_string_from_system()
	})
	_save_to_disk()

func log_delete(table: String, record_id: int) -> void:
	_changes.append({
		"action": "delete",
		"table": table,
		"record_id": record_id,
		"timestamp": Time.get_datetime_string_from_system()
	})
	_save_to_disk()

func has_changes() -> bool:
	return _changes.size() > 0

func get_changes_json() -> String:
	return JSON.stringify(_changes)

func clear() -> void:
	_changes = []
	if FileAccess.file_exists(CHANGES_PATH):
		DirAccess.remove_absolute(CHANGES_PATH)
