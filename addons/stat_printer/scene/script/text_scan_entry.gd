@tool
extends HBoxContainer

var type_name : LineEdit
var text : LineEdit
var menu_node
var delete : TextureButton
# Called when the node enters the scene tree for the first time.
func _ready():
	delete = $PanelContainer/DeleteButton
	text = $PanelContainer2/HBoxContainer/LineEdit
	type_name = $PanelContainer2/HBoxContainer/TypeName
	

func on_delete_button_pressed():
	menu_node.entries.erase(name)
	queue_free()
