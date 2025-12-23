@tool
extends EditorPlugin


const MainPanel = preload("res://addons/stat_printer/scene/stat_dock.tscn")

var main_panel_instance

func _enter_tree():
	main_panel_instance = MainPanel.instantiate()
	# Add the main panel to the editor's main viewport.
	EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
	# Hide the main panel. Very much required.
	_make_visible(false)
	add_autoload_singleton("StatCollectorGlobals", "res://addons/stat_printer/scene/script/globals.gd")

func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()
	remove_autoload_singleton("StatCollectorGlobals")

func _has_main_screen():
	return true



func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible


func _get_plugin_name():
	return "Project Statistics"


func _get_plugin_icon():
	# Must return some kind of Texture for the icon.
	return load("res://addons/stat_printer/texture/icon.png")
