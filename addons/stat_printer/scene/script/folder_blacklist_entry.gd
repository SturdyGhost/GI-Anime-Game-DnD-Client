@tool
extends HBoxContainer

var text : LineEdit
var menu_node
var delete : TextureButton
# Called when the node enters the scene tree for the first time.
func _ready():
	delete = $PanelContainer/DeleteButton
	text = $PanelContainer2/HBoxContainer/LineEdit
	

func on_delete_button_pressed():
	menu_node.entries.erase(name)
	queue_free()
