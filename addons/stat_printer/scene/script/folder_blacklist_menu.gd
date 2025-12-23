@tool
extends PanelContainer

var vbox : VBoxContainer
var add_entry : Button
var entries = {}
# Called when the node enters the scene tree for the first time.
func _ready():
	vbox = $ScrollContainer/VBoxContainer
	add_entry = $ScrollContainer/VBoxContainer/AddNewEntryButton


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	update_new_entry_child_position()
	StatCollectorGlobals.folder_blacklist_menu = self
	
func update_new_entry_child_position():
	var ch_count = vbox.get_child_count()
	vbox.move_child(add_entry, ch_count - 1)

const entry_scene = preload("res://addons/stat_printer/scene/folder_blacklist_entry.tscn")


func load_save():
	for entry_text in StatCollectorGlobals.blacklisted_folders:
		var entry = entry_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		vbox.add_child(entry)
		entry.name = str(randf())
		entry.menu_node = self
		entry.text.text = entry_text
		entries[entry.name] = entry

func load_defaults():
	for entry_text in StatCollectorGlobals.blacklisted_folder_defaults:
		var entry = entry_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		vbox.add_child(entry)
		entry.name = str(randf())
		entry.menu_node = self
		entry.text.text = entry_text
		entries[entry.name] = entry

func clear():
	for entry_key in entries:
		var entry = entries[entry_key]
		entry.queue_free()
	entries.clear()

func collect_entries():
	var result = []
	for entry_key in entries:
		var entry = entries[entry_key]
		result.append(entry.text.text)
	return result

func add_entry_pressed():
	var entry = entry_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	vbox.add_child(entry)
	entry.name = str(randf())
	entry.menu_node = self
	entries[entry.name] = entry
