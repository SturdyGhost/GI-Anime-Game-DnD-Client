@tool
extends Node

const file_type_defaults = {"Scripts": "gd", "PNGs": "png", "Scenes": "tscn", "Resources": "tres"}
const script_scanner_defaults = {"Classes": "class_name ", "Variables": "var ", "Functions": "func ", "Lambda Functions": "func(", "If Statements": "if ", "Match Statements": "match ", "Else If Statements": "elif ", "Else Statements": "else:", "Signals": "signal "}
const blacklisted_folder_defaults = ["addons", ".godot"]

var file_types = {}
var script_scanners = {}
var blacklisted_folders = []

var char_count = 0
var counts = {}

var scanner_menu
var file_type_menu
var folder_blacklist_menu
var dock


#region Load Functions
func _enter_tree():
	if FileAccess.file_exists("res://addons/stat_printer/saved/save.json"):
		
		load_save()
		
	else:
		create_save_file()

func _exit_tree():
	save()

func load_save():
	var file = FileAccess.open("res://addons/stat_printer/saved/save.json", FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file_types = json["file_types"]
	script_scanners = json["script_scanners"]
	blacklisted_folders = json["blacklisted_folders"]
	file.close()
	load_save_entries()
	
func load_save_entries():

	if scanner_menu != null:
		scanner_menu.load_save()
	if file_type_menu != null:
		file_type_menu.load_save()
	if folder_blacklist_menu != null:
		folder_blacklist_menu.load_save()
	

func save():
	collect_entries()
	var dict = {"file_types": file_types, "script_scanners": script_scanners, "blacklisted_folders": blacklisted_folders}
	var file = FileAccess.open("res://addons/stat_printer/saved/save.json", FileAccess.WRITE_READ)
	file.store_string(JSON.stringify(dict, "\t"))
	file.close()

func create_save_file():
	var file = FileAccess.open("res://addons/stat_printer/saved/save.json", FileAccess.WRITE_READ)
	file.close()
	
func load_defaults():
	file_type_menu.clear()
	folder_blacklist_menu.clear()
	scanner_menu.clear()
	file_types = file_type_defaults
	script_scanners = script_scanner_defaults
	blacklisted_folders = blacklisted_folder_defaults
	file_type_menu.load_defaults()
	folder_blacklist_menu.load_defaults()
	scanner_menu.load_defaults()
	
#endregion

#region Scan Functions

func collect_entries():
	blacklisted_folders = folder_blacklist_menu.collect_entries()
	file_types = file_type_menu.collect_entries()
	script_scanners = scanner_menu.collect_entries()
	

func collect(): # Start Scan
	dock.output.text = ""
	collect_entries()
	counts.clear()
	char_count = 0
	var folder_paths = collect_folder_paths()
	var file_paths = collect_file_paths(folder_paths)
	for path in file_paths:
		collect_files(path)
	for entry_name in counts:
		var entry = counts[entry_name]
		dock.output.text = dock.output.text + str(entry_name) + ": " + str(entry) + "\n"

func collect_file_paths(dir_paths: Array):
	var file_paths = []
	for path in dir_paths:
		var files = DirAccess.get_files_at(path)
		for file_path in files:
			if not ends_with_any(file_path, file_types.values()):
				continue
			file_paths.append(path + "/" + file_path)
	return file_paths
	
func collect_folder_paths(dir_path: String = "res://"):
	var folders = DirAccess.get_directories_at(dir_path)
	var folder_paths = []
	for folder in folders:
		if contains_any(folder, blacklisted_folders):
			continue
		folder_paths.append(dir_path + folder)
		folder_paths.append_array(collect_folder_paths(dir_path + folder + "/"))
	return folder_paths

func contains_any(string: String, chars: Array):
	var result = false
	for char in chars:
		if string.contains(char):
			result = true
			break
	return result

func ends_with_any(string: String, chars: Array):
	var result = false
	for char in chars:
		
		if string.ends_with(char):
			result = true
			break
	return result

func collect_file_counts(file_path: String):
	for file_type in file_types:
		var type = file_types[file_type]
		if file_path.ends_with("." + type):
			if counts.has(file_type):
				counts[file_type] += 1
			else:
				counts[file_type] = 1

func collect_files(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file_path.ends_with(".gd"):
		var text = file.get_as_text()
		char_count += text.length()
		collect_script_stuff(text)
	collect_file_counts(file_path)

func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		save()
	
func collect_script_stuff(string: String):
	for scanner_name in script_scanners:
		var scanner = script_scanners[scanner_name]
		if counts.has(scanner_name):
			counts[scanner_name] += string.count(scanner)
		else:
			counts[scanner_name] = string.count(scanner)
#endregion
