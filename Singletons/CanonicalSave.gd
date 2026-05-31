extends Node
## Single source of truth on the DM host. All dynamic per-session state lives
## in one JSON file at user://canonical_save.json. Static game data (weapons,
## abilities, recipes, etc.) still lives in GameDB loaded from res:// .tres
## files — only mutable runtime state is in here.
##
## On-disk format:
##   {
##     "schema_version": 1,
##     "last_saved_ms": <int>,
##     "tables": {
##       "Characters": { "1": {record dict}, "2": {...}, ... },
##       "Character_Items": { ... },
##       ...
##     }
##   }
##
## Atomic writes: write to .tmp, promote existing to .bak, copy tmp to live,
## remove tmp. A mid-write crash leaves the previous live file untouched.

const SAVE_PATH      = "user://canonical_save.json"
const SAVE_TMP       = "user://canonical_save.json.tmp"
const SAVE_BACKUP    = "user://canonical_save.json.bak"
const SCHEMA_VERSION = 1

## Tables that the canonical save persists. Anything outside this list lives
## in GameDB (static) or is computed at runtime.
const PERSISTED_TABLES: Array = [
	"Characters",
	"Companions",
	"Character_Items",
	"Character_Weapons",
	"Character_Artifacts",
	"Talents",
	"Constellations",
	"Party",
	"Active_Abilities",
	"Active_Status_Effects",
	"BattleEnemies",
	"Game_Config",
	"Minigames_Results",
	"ActiveEffects",
]

# In-memory state: { table_name: { record_id_str: record_dict } }
var tables: Dictionary = {}

signal save_loaded
signal save_written

func _ready() -> void:
	# Loading is explicit. Triggered from NetworkManager.host_game() or lobby
	# offline-mode entry. Don't auto-load on _ready because autoload order
	# means we can't rely on DataStore/SaveManager being ready yet.
	pass

# ── Load ────────────────────────────────────────────────────────────────────

func load_from_disk() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		if _load_file(SAVE_PATH):
			return true
		push_warning("CanonicalSave: main load failed, falling back to backup")
	if FileAccess.file_exists(SAVE_BACKUP):
		if _load_file(SAVE_BACKUP):
			push_warning("CanonicalSave: recovered from %s" % SAVE_BACKUP)
			return true
	return false

func _load_file(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CanonicalSave: cannot open %s" % path)
		return false
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("CanonicalSave: invalid JSON in %s" % path)
		return false
	var ver = int(parsed.get("schema_version", 0))
	if ver != SCHEMA_VERSION:
		push_warning("CanonicalSave: schema version mismatch (file=%d, code=%d)" % [ver, SCHEMA_VERSION])
	var loaded_tables = parsed.get("tables", {})
	if typeof(loaded_tables) != TYPE_DICTIONARY:
		push_error("CanonicalSave: 'tables' is not a Dictionary in %s" % path)
		return false
	tables = loaded_tables
	# Ensure every persisted table has an entry (even if empty) so callers
	# don't have to null-check.
	for t in PERSISTED_TABLES:
		if not tables.has(t):
			tables[t] = {}
	_hydrate_static_tables_if_empty()
	emit_signal("save_loaded")
	print("CanonicalSave: loaded %d tables from %s" % [tables.size(), path])
	return true

# ── Static-table hydration ─────────────────────────────────────────────────
# Talents and Constellations are tracked as PERSISTED_TABLES so that "Chosen"
# state lives in the canonical save, but the rows themselves (Name, Element,
# Tier, full descriptions) come from res://data/*.json as the authoritative
# project source. Older canonical saves may have these tables present but
# empty — populate them on load so the profile UI and effect lookups work.
const _STATIC_HYDRATE_SOURCES := {
	"Talents":        "res://data/Talents.json",
	"Constellations": "res://data/Constellations.json",
}

func _hydrate_static_tables_if_empty() -> void:
	var hydrated_any := false
	for table_name in _STATIC_HYDRATE_SOURCES:
		if not tables[table_name].is_empty():
			continue
		var records = _read_json_array(_STATIC_HYDRATE_SOURCES[table_name])
		if records.is_empty():
			continue
		var rec_dict: Dictionary = {}
		for r in records:
			if typeof(r) != TYPE_DICTIONARY or not r.has("id"):
				continue
			rec_dict[str(int(r.get("id", 0)))] = r
		tables[table_name] = rec_dict
		hydrated_any = true
		print("CanonicalSave: hydrated empty '%s' from res:// defaults (%d records)" % [table_name, rec_dict.size()])
	if hydrated_any and DataStore._is_host:
		save_to_disk()

# ── Save ────────────────────────────────────────────────────────────────────

func save_to_disk() -> void:
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"last_saved_ms": Time.get_ticks_msec(),
		"tables": tables,
	}
	var json_str := JSON.stringify(payload, "\t")

	# Write to tmp first.
	var tmp = FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if tmp == null:
		push_error("CanonicalSave: cannot open tmp file for write — SAVE_PATH untouched")
		return
	tmp.store_string(json_str)
	tmp.close()

	# Promote existing live file to backup before overwriting.
	if FileAccess.file_exists(SAVE_PATH):
		var backup_err = DirAccess.copy_absolute(SAVE_PATH, SAVE_BACKUP)
		if backup_err != OK:
			push_warning("CanonicalSave: could not promote SAVE_PATH to backup (error %d)" % backup_err)

	var promote_err = DirAccess.copy_absolute(SAVE_TMP, SAVE_PATH)
	if promote_err != OK:
		push_error("CanonicalSave: could not promote tmp to SAVE_PATH (error %d) — previous save preserved" % promote_err)
		return
	DirAccess.remove_absolute(SAVE_TMP)
	emit_signal("save_written")

# ── Mutators ───────────────────────────────────────────────────────────────

## Returns the table dict (creating it if missing). Caller can mutate the
## returned dict and changes are live in the canonical save (in-memory).
## Disk persistence requires a save_to_disk() call.
func get_table(table_name: String) -> Dictionary:
	if not tables.has(table_name):
		tables[table_name] = {}
	return tables[table_name]

func get_record(table_name: String, record_id) -> Dictionary:
	var t: Dictionary = get_table(table_name)
	return t.get(str(record_id), {})

func has_record(table_name: String, record_id) -> bool:
	if not tables.has(table_name):
		return false
	return tables[table_name].has(str(record_id))

func set_record(table_name: String, record_id, record: Dictionary) -> void:
	get_table(table_name)[str(record_id)] = record

func update_field(table_name: String, record_id, field: String, value) -> bool:
	var t: Dictionary = get_table(table_name)
	var key = str(record_id)
	if not t.has(key):
		return false
	t[key][field] = value
	return true

func remove_record(table_name: String, record_id) -> bool:
	if not tables.has(table_name):
		return false
	return tables[table_name].erase(str(record_id))

func replace_table(table_name: String, records: Array) -> void:
	var d: Dictionary = {}
	for r in records:
		if typeof(r) != TYPE_DICTIONARY or not r.has("id"):
			continue
		d[str(int(r.get("id", 0)))] = r
	tables[table_name] = d

func has_data() -> bool:
	for t in PERSISTED_TABLES:
		if tables.has(t) and not tables[t].is_empty():
			return true
	return false

# ── Migration from legacy storage ──────────────────────────────────────────

## Returns true if a migration ran (no canonical save existed and legacy data
## was successfully consolidated).
func migrate_from_legacy() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		return false  # Already migrated or already canonical

	var data_dir := "user://data/"
	var migrated_any := false
	var dir = DirAccess.open(data_dir)
	if dir == null:
		# No legacy per-table folder either. Nothing to migrate.
		return false

	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json") and not fname.ends_with(".legacy"):
			var table_name = fname.trim_suffix(".json")
			var records = _read_json_array(data_dir + fname)
			if records.size() > 0:
				var rec_dict: Dictionary = {}
				for r in records:
					if typeof(r) != TYPE_DICTIONARY:
						continue
					if not r.has("id"):
						continue
					rec_dict[str(int(r.get("id", 0)))] = r
				tables[table_name] = rec_dict
				migrated_any = true
				print("CanonicalSave: migrated table '%s' (%d records)" % [table_name, rec_dict.size()])
		fname = dir.get_next()
	dir.list_dir_end()

	# Make sure static tables (Talents/Constellations) are populated even if
	# the legacy dir didn't include them — fall back to res:// defaults.
	for t in PERSISTED_TABLES:
		if not tables.has(t):
			tables[t] = {}
	_hydrate_static_tables_if_empty()

	if migrated_any:
		# Write the consolidated file before renaming legacy files (so a crash
		# mid-migration leaves the originals intact).
		save_to_disk()
		_rename_legacy_files()
	return migrated_any

func _rename_legacy_files() -> void:
	var data_dir := "user://data/"
	var dir = DirAccess.open(data_dir)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".json") and not fname.ends_with(".legacy"):
				DirAccess.rename_absolute(data_dir + fname, data_dir + fname + ".legacy")
			fname = dir.get_next()
		dir.list_dir_end()
	if FileAccess.file_exists("user://save.tres"):
		DirAccess.rename_absolute("user://save.tres", "user://save.tres.legacy")

func _read_json_array(path: String) -> Array:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []

# ── Snapshot for backup distribution (Phase 4) ─────────────────────────────

## Produces a deep-copied payload suitable for RPC broadcasting.
func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"last_saved_ms": Time.get_ticks_msec(),
		"tables": tables.duplicate(true),
	}

## Fingerprint of the current canonical content (the `tables` dict only —
## metadata like last_saved_ms is intentionally excluded so the same data
## always hashes the same). Used by the periodic backup broadcast to decide
## whether a given client is already up-to-date and can skip the full payload.
## Cheap to compute on demand at the ~5-min tick cadence; not cached because
## any mutator path would otherwise need to invalidate it.
func get_content_hash() -> String:
	return JSON.stringify(tables).sha256_text()
