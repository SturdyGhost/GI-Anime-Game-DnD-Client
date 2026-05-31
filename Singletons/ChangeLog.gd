extends Node
## Append-only history of every mutation made to the canonical save.
##
## Entry format:
##   {
##     "ts": <int ms since unix epoch>,
##     "actor": "host" | "<player name>",
##     "op": "update" | "insert" | "remove",
##     "table": "Characters",
##     "record_id": 5,
##     "field": "Element"   | null for insert/remove,
##     "value": "Wind"      | full record dict for insert, null for remove,
##     "old_value": "Fire"  | optional, for debugging/audit
##   }
##
## Two purposes:
##   1) Audit trail of everything that's happened in the campaign.
##   2) Per-field LWW reconciliation: when an offline player returns with
##      their own offline_change_log.json, we compare each entry's ts against
##      ChangeLog.latest_for(table, record_id, field) to decide who wins.
##
## Storage: user://change_log.json (append-only, atomic writes).
## Retention: full history, never purged (user's call, this can grow but the
## per-field LWW index keeps lookups O(1) regardless of file size).

const LOG_PATH   = "user://change_log.json"
const LOG_TMP    = "user://change_log.json.tmp"
const LOG_BACKUP = "user://change_log.json.bak"

# All entries, append-only.
var entries: Array = []

# Index: "table|record_id|field" -> Entry (the most recent one). Rebuilt on
# load and maintained on every append. Used by latest_for() for O(1) lookups.
var _latest_by_field: Dictionary = {}

signal entry_appended(entry: Dictionary)

func _ready() -> void:
	# Load is explicit (triggered by NetworkManager.host_game / offline mode
	# entry) for the same autoload-order reason as CanonicalSave.
	pass

# ── Load / Save ─────────────────────────────────────────────────────────────

func load_from_disk() -> bool:
	if FileAccess.file_exists(LOG_PATH):
		if _load_file(LOG_PATH):
			return true
		push_warning("ChangeLog: main load failed, falling back to backup")
	if FileAccess.file_exists(LOG_BACKUP):
		if _load_file(LOG_BACKUP):
			push_warning("ChangeLog: recovered from %s" % LOG_BACKUP)
			return true
	# No log on disk — start fresh.
	entries = []
	_latest_by_field.clear()
	return false

func _load_file(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		push_error("ChangeLog: invalid JSON array in %s" % path)
		return false
	entries = parsed
	_rebuild_index()
	print("ChangeLog: loaded %d entries from %s" % [entries.size(), path])
	return true

func save_to_disk() -> void:
	var json_str := JSON.stringify(entries, "\t")
	var tmp = FileAccess.open(LOG_TMP, FileAccess.WRITE)
	if tmp == null:
		push_error("ChangeLog: cannot open tmp file for write")
		return
	tmp.store_string(json_str)
	tmp.close()
	if FileAccess.file_exists(LOG_PATH):
		var bak_err = DirAccess.copy_absolute(LOG_PATH, LOG_BACKUP)
		if bak_err != OK:
			push_warning("ChangeLog: could not promote LOG_PATH to backup (error %d)" % bak_err)
	var promote_err = DirAccess.copy_absolute(LOG_TMP, LOG_PATH)
	if promote_err != OK:
		push_error("ChangeLog: could not promote tmp to LOG_PATH (error %d)" % promote_err)
		return
	DirAccess.remove_absolute(LOG_TMP)

# ── Append API ──────────────────────────────────────────────────────────────

## Append an update entry (one field of one record changed).
func append_update(actor: String, table: String, record_id, field: String, value, old_value = null) -> void:
	var entry := {
		"ts": Time.get_unix_time_from_system() * 1000.0 as int,
		"actor": actor,
		"op": "update",
		"table": table,
		"record_id": int(record_id),
		"field": field,
		"value": value,
		"old_value": old_value,
	}
	_append(entry)

## Append an insert entry (new record). `value` is the full record dict.
func append_insert(actor: String, table: String, record_id, record: Dictionary) -> void:
	var entry := {
		"ts": Time.get_unix_time_from_system() * 1000.0 as int,
		"actor": actor,
		"op": "insert",
		"table": table,
		"record_id": int(record_id),
		"field": null,
		"value": record,
		"old_value": null,
	}
	_append(entry)

## Append a remove entry.
func append_remove(actor: String, table: String, record_id) -> void:
	var entry := {
		"ts": Time.get_unix_time_from_system() * 1000.0 as int,
		"actor": actor,
		"op": "remove",
		"table": table,
		"record_id": int(record_id),
		"field": null,
		"value": null,
		"old_value": null,
	}
	_append(entry)

## Append a pre-built entry verbatim — used during offline reconciliation when
## we want to preserve the client's original timestamp.
func append_raw(entry: Dictionary) -> void:
	if not entry.has("ts") or not entry.has("op") or not entry.has("table"):
		push_error("ChangeLog: append_raw missing required fields")
		return
	_append(entry.duplicate(true))

func _append(entry: Dictionary) -> void:
	entries.append(entry)
	_index_entry(entry)
	save_to_disk()
	emit_signal("entry_appended", entry)

# ── Query API ──────────────────────────────────────────────────────────────

## Return the most recent entry for a given field, or null if no entry exists.
## Used by reconciliation to decide whether to accept an offline change.
func latest_for(table: String, record_id, field: String):
	var key := "%s|%d|%s" % [table, int(record_id), field]
	return _latest_by_field.get(key, null)

## Find the most recent op of any kind (insert / remove / update) for a record.
## Used to detect deleted-then-modified situations.
func latest_record_op(table: String, record_id):
	var best = null
	var rid := int(record_id)
	# Scan backwards — entries are in append order so the last match wins.
	for i in range(entries.size() - 1, -1, -1):
		var e = entries[i]
		if str(e.get("table", "")) == table and int(e.get("record_id", -1)) == rid:
			best = e
			break
	return best

# ── Indexing ───────────────────────────────────────────────────────────────

func _index_entry(entry: Dictionary) -> void:
	var op = entry.get("op", "")
	if op == "update":
		var key := "%s|%d|%s" % [str(entry.get("table", "")), int(entry.get("record_id", 0)), str(entry.get("field", ""))]
		var existing = _latest_by_field.get(key)
		if existing == null or int(entry.get("ts", 0)) >= int(existing.get("ts", 0)):
			_latest_by_field[key] = entry
	# Inserts and removes affect whole records; the per-field index doesn't
	# need entries for them (latest_record_op handles those queries).

func _rebuild_index() -> void:
	_latest_by_field.clear()
	for e in entries:
		_index_entry(e)
