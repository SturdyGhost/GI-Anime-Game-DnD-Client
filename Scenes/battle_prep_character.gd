extends Control

@onready var Checkbox = $CheckBox
@onready var FoodButton = $OptionButton
@onready var FoodConfirm = $Button
@onready var PlayerLabel = $Label

var PlayerID
signal FoodBuffChanged

func _ready() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)


func _on_data_load_complete():
	
	for player_data in Global.CHARACTERS.values():
		if player_data.get("Name") == PlayerLabel.text and player_data.get("Ready") != Checkbox.button_pressed:
			Checkbox.button_pressed = player_data.get("Ready")


func assign_player(player):
	PlayerLabel.text = str(player)
	PlayerID = int(Global.CHARACTERS_NAME[player])
	var ItemRecord
	for item in Global.CHARACTER_ITEMS.values():
		for record in Global.ITEMS.values():
			if item.get("Name") == record.get("Item"):
				ItemRecord = record
		if item.get("Type") == "Consumable" and item.get("Owner") == player and item.get("Quantity") > 0 and ItemRecord.get("Buff_Duration") != null:
			FoodButton.add_item(item.get("Name")+" - x"+str(item.get("Quantity")))
	if player != Global.ACTIVE_USER_NAME:
		Checkbox.disabled = true
		FoodConfirm.disabled = true



func _on_check_box_toggled(toggled_on: bool) -> void:
	print({"table": "Characters","record": PlayerID,"field": "Ready","value":Checkbox.button_pressed})
	Global.Update_Records([{"table": "Characters","record_id": PlayerID,"field": "Ready","value":Checkbox.button_pressed}])
	pass # Replace with function body.



func _on_button_pressed() -> void:
	var BaseName 
	var item_record_id
	var item_current_quantity
	var item_name
	var item_duration
	var ItemRecord
	if FoodButton.get_item_text(FoodButton.selected) != "" and FoodButton.selected >= 0:
		BaseName = FoodButton.get_item_text(FoodButton.selected)
		var NameOnly = BaseName.split(" - ")[0]
	
		for item in Global.CHARACTER_ITEMS.values():
			for record in Global.ITEMS.values():
				if item.get("Name") == record.get("Item"):
					ItemRecord = record
			if item.get("Type") == "Consumable" and item.get("Owner") == Global.ACTIVE_USER_NAME and item.get("Name") == NameOnly and ItemRecord.get("Buff_Duration") != null:
				item_record_id = item.get("id")
				item_current_quantity = item.get("Quantity")
				item_name = item.get("Name")
				print (item.get("Name"))
				for DBItem in Global.ITEMS.values():
					if DBItem.get("Item") == item_name:
						item_duration = DBItem.get("Buff_Duration")
		if item_name != null:
			item_current_quantity -= 1
			var updates = [{"table": "Character_Items","record_id": item_record_id,"field": "Quantity","value": item_current_quantity},
			{"table": "Party","record_id": Global.Current_Party.get("id"),"field": "Active_Food_Buff","value": item_name},
			{"table": "Party","record_id": Global.Current_Party.get("id"),"field": "Buff_Battles_Left","value": item_duration}]
			Global.data_load_complete.connect(_on_table_loaded)
			Global.Update_Records(updates)
			#FoodButton.set_item_text(FoodButton.selected,str(NameOnly+" - "+str(item_current_quantity)))

func _on_table_loaded() -> void:
	print ("Emitting Signal FoodBuffChanged")
	emit_signal("FoodBuffChanged")
	pass # Replace with function body.
