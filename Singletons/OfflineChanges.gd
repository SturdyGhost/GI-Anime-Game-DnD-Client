extends Node
## Logs mutations made during offline mode to user://offline_changes.json.
## On reconnect, the log is submitted to the host who reconciles it against
## its own ChangeLog using per-field last-write-wins by timestamp.
##
## Entry format matches ChangeLog so the host can compare directly:
##   {
##     "ts": <int ms since unix epoch>,
##     "actor": "<player name>",
##     "op": "update" | "insert" | "remove",
##     "table": "Characters",
##     "record_id": 5,
##     "field": "Element"   | null for insert/remove,
##     "value": "Wind"      | full record for insert, null for remove,
##     "old_value": null    | optional
##   }

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

static func _now_ms() -> int:
	return Time.get_unix_time_from_system() * 1000.0 as int

static func _actor_name() -> String:
	if "ACTIVE_USER_NAME" in Global:
		return str(Global.ACTIVE_USER_NAME)
	return "unknown"

func log_update(table: String, record_id: int, field: String, value) -> void:
	_changes.append({
		"ts": _now_ms(),
		"actor": _actor_name(),
		"op": "update",
		"table": table,
		"record_id": record_id,
		"field": field,
		"value": value,
		"old_value": null,
	})
	_save_to_disk()

func log_insert(table: String, record_id: int, record: Dictionary) -> void:
	_changes.append({
		"ts": _now_ms(),
		"actor": _actor_name(),
		"op": "insert",
		"table": table,
		"record_id": record_id,
		"field": null,
		"value": record.duplicate(true),
		"old_value": null,
	})
	_save_to_disk()

func log_delete(table: String, record_id: int) -> void:
	_changes.append({
		"ts": _now_ms(),
		"actor": _actor_name(),
		"op": "remove",
		"table": table,
		"record_id": record_id,
		"field": null,
		"value": null,
		"old_value": null,
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
