extends Node
## Handles reading/writing JSON data files from disk.
## The host saves to user://data/, clients hold data in memory only.

const DATA_DIR := "user://data/"
const BUNDLED_DIR := "res://data/"

var _is_host := false

func set_host(value: bool) -> void:
	_is_host = value
	if _is_host:
		DirAccess.make_dir_recursive_absolute(DATA_DIR)

## Load a single table from JSON. Host reads from user://data/ (falling back to
## res://data/ on first run). Returns an Array of Dictionaries.
func load_table(table_name: String) -> Array:
	var user_path := DATA_DIR + table_name + ".json"
	var bundled_path := BUNDLED_DIR + table_name + ".json"

	var path := ""
	if _is_host and FileAccess.file_exists(user_path):
		path = user_path
	elif FileAccess.file_exists(bundled_path):
		path = bundled_path
	else:
		push_warning("DataStore: no file found for table '%s'" % table_name)
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataStore: cannot open '%s'" % path)
		return []

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		push_error("DataStore: invalid JSON in '%s'" % path)
		return []

	return parsed

## Load all tables listed in Global.TABLES. Returns a Dictionary of table_name -> Array.
func load_all_tables() -> Dictionary:
	var result := {}
	for table_name in Global.TABLES:
		result[table_name] = load_table(table_name)
	return result

## Save a single table to user://data/. Only called on host.
func save_table(table_name: String, records: Array) -> void:
	if not _is_host:
		push_error("DataStore: save_table called on non-host")
		return

	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var path := DATA_DIR + table_name + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DataStore: cannot write '%s'" % path)
		return

	file.store_string(JSON.stringify(records, "\t"))
	file.close()

## Convenience: get the current records array for a table from Global's dictionaries.
## This converts the id-keyed dictionary back to an array for saving.
func get_table_as_array(table_name: String) -> Array:
	var dict: Dictionary = _get_global_dict(table_name)
	if dict.is_empty():
		return []
	return dict.values()

## Save the current in-memory state of a table to disk (host only).
func persist_table(table_name: String) -> void:
	if not _is_host:
		return
	var records := get_table_as_array(table_name)
	save_table(table_name, records)

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
		"Active_Abilities": return Global.ACTIVE_ABILITIES
		"Active_Status_Effects": return Global.ACTIVE_STATUS_EFFECTS
		"Status_Effects": return Global.STATUS_EFFECTS
		"Game_Config": return Global.GAME_CONFIG
		"Minigames": return Global.MINIGAMES
		"Minigames_Results": return Global.MINIGAMES_RESULTS
	return {}
