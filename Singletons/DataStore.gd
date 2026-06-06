extends Node
## Facade over CanonicalSave. The actual storage is one consolidated JSON file
## owned by CanonicalSave; this file's API stays for back-compat with code that
## calls load_table / persist_table / save_table / get_table_as_array.
##
## On host: persistence flows DataStore.persist_table → CanonicalSave.save_to_disk
## (one file write per mutation, atomic via tmp+promote+.bak).
##
## On first run with the new code, migrate_legacy_if_needed() consolidates
## any prior user://data/*.json + user://save.tres into canonical_save.json.

const DATA_DIR := "user://data/"
const BUNDLED_DIR := "res://data/"

var _is_host := false
var _did_migration_check := false

func set_host(value: bool) -> void:
	_is_host = value
	if _is_host:
		DirAccess.make_dir_recursive_absolute(DATA_DIR)
		_migrate_legacy_if_needed()

## One-shot migration: if no canonical save exists but legacy per-table JSONs
## do, consolidate them into canonical_save.json and rename originals to
## .legacy so we don't migrate them twice.
func _migrate_legacy_if_needed() -> void:
	if _did_migration_check:
		return
	_did_migration_check = true
	if FileAccess.file_exists(CanonicalSave.SAVE_PATH):
		return  # Already have a canonical save
	if CanonicalSave.migrate_from_legacy():
		print("DataStore: migrated legacy per-table JSONs into canonical save")

## Load a single table from JSON. On host with a canonical save, reads from
## CanonicalSave directly. Otherwise reads bundled res://data/ JSON for
## first-run defaults.
func load_table(table_name: String) -> Array:
	if _is_host and CanonicalSave.has_data():
		var dict: Dictionary = CanonicalSave.get_table(table_name)
		if not dict.is_empty():
			return dict.values()

	# Fall through to bundled defaults (first-run path).
	var bundled_path := BUNDLED_DIR + table_name + ".json"
	if not FileAccess.file_exists(bundled_path):
		push_warning("DataStore: no data for table '%s' (no canonical save, no bundled JSON)" % table_name)
		return []

	var file := FileAccess.open(bundled_path, FileAccess.READ)
	if file == null:
		push_error("DataStore: cannot open '%s'" % bundled_path)
		return []
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		push_error("DataStore: invalid JSON in '%s'" % bundled_path)
		return []
	return parsed

## Load all tables listed in Global.TABLES. Returns a Dictionary of table_name -> Array.
func load_all_tables() -> Dictionary:
	var result := {}
	for table_name in Global.TABLES:
		result[table_name] = load_table(table_name)
	return result

## Save a single table. Now routes through CanonicalSave so all tables persist
## to one consolidated file. The records array is taken as authoritative for
## that table — it replaces CanonicalSave.tables[table_name].
func save_table(table_name: String, records: Array) -> void:
	if not _is_host:
		push_error("DataStore: save_table called on non-host")
		return
	CanonicalSave.replace_table(table_name, records)
	CanonicalSave.save_to_disk()

## Convenience: get the current records array for a table from Global's dictionaries.
## This converts the id-keyed dictionary back to an array for saving.
func get_table_as_array(table_name: String) -> Array:
	var dict: Dictionary = _get_global_dict(table_name)
	if dict.is_empty():
		return []
	return dict.values()

## Save the current in-memory state to disk (host only). Because all tables
## share one file in the canonical save, this writes the entire save —
## regardless of which table_name is passed (kept as a parameter only for
## back-compat with existing callers).
func persist_table(table_name: String) -> void:
	if not _is_host:
		return
	# The in-memory state in Global._synced IS CanonicalSave.tables (via the
	# delegating property in Global.gd), so we just need to flush to disk.
	CanonicalSave.save_to_disk()

func _get_global_dict(table_name: String) -> Dictionary:
	match table_name:
		"Characters": return Global.CHARACTERS
		"Weapons": return Global.WEAPONS
		"Artifacts": return Global.ARTIFACTS
		"Reactions": return Global.REACTIONS
		"Abilities": return Global.ABILITIES
		"Companions": return Global.COMPANIONS
		"Crafting_Recipes": return Global.CRAFTING_RECIPES
		"Items": return Global.ITEMS
		"Enemies": return Global.ENEMIES
		"BattleEnemies": return Global.BATTLEENEMIES
		"Character_Weapons": return Global.CHARACTER_WEAPONS
		"Character_Artifacts": return Global.CHARACTER_ARTIFACTS
		"Character_Items": return Global.CHARACTER_ITEMS
		"Talents": return Global.TALENTS
		"Constellations": return Global.CONSTELLATIONS
		"Material_Caches": return Global.MATERIAL_CACHES
		"Party": return Global.PARTY
		"Active_Status_Effects": return Global.ACTIVE_STATUS_EFFECTS
		"Status_Effects": return Global.STATUS_EFFECTS
		"Game_Config": return Global.GAME_CONFIG
		"Minigames": return Global.MINIGAMES
		"Minigames_Results": return Global.MINIGAMES_RESULTS
	return {}
