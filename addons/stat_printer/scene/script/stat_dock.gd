@tool
extends Control

var output
var base
var scan_button : Button


# Called when the node enters the scene tree for the first time.
func _ready():
	base = $BaseContainer
	output = $BaseContainer/OutputPanelContainer/OutputSplitContainer/OutputTextPanelContainer/HBoxContainer/ScrollContainer/Output
	scan_button = $BaseContainer/OutputPanelContainer/OutputSplitContainer/OutputButtonVBox/OutputButtonPanelContainer/ScanButton
	
	StatCollectorGlobals.scanner_menu = $"BaseContainer/PanelContainer/TabContainer/Text Scanners"
	StatCollectorGlobals.folder_blacklist_menu = $"BaseContainer/PanelContainer/TabContainer/Folder Blacklist"
	StatCollectorGlobals.file_type_menu = $"BaseContainer/PanelContainer/TabContainer/File Types"
	StatCollectorGlobals.dock = self

func collect():
	StatCollectorGlobals.collect()
	
func load_defaults():
	StatCollectorGlobals.load_defaults()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	$BaseContainer.size = get_parent().size
