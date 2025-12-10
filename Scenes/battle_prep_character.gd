extends Control

@onready var Checkbox = $CheckBox
@onready var FoodButton = $OptionButton
@onready var FoodConfirm = $Button
@onready var PlayerLabel = $Label

var PlayerID
signal FoodBuffChanged
var _food_desc_by_index: Dictionary = {}  # index -> description

func _ready() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)


func _on_data_load_complete():
	
	for player_data in Global.CHARACTERS.values():
		if player_data.get("Name") == PlayerLabel.text and player_data.get("Ready") != Checkbox.button_pressed:
			Checkbox.button_pressed = player_data.get("Ready")


func assign_player(player: String) -> void:
	PlayerLabel.text = str(player)
	PlayerID = int(Global.CHARACTERS_NAME[player])

	# Build lookup: item name → record (for Description/Buff_Duration, etc.)
	var item_lookup: Dictionary = {}
	for rec in Global.ITEMS.values():
		var name_key = str(rec.get("Item", ""))
		if name_key != "":
			item_lookup[name_key] = rec

	# Reset UI
	FoodButton.clear()
	_food_desc_by_index.clear()

	# Populate the OptionButton and set per-row tooltips
	var popup: PopupMenu = FoodButton.get_popup()

	for item in Global.CHARACTER_ITEMS.values():
		var item_name = str(item.get("Name", ""))
		if item_name == "":
			continue

		# Find matching item record (for Description/Buff_Duration)
		var record: Dictionary = {}
		if item_lookup.has(item_name):
			record = item_lookup[item_name]

		# Filters
		var is_consumable = str(item.get("Type", "")) == "Consumable"
		var owned_by_player = str(item.get("Owner", "")) == player
		var qty_ok = int(item.get("Quantity", 0)) > 0
		var has_duration = record.has("Buff_Duration") and record.get("Buff_Duration") != null

		if is_consumable and owned_by_player and qty_ok and has_duration:
			var qty = int(item.get("Quantity", 0))
			var display_text = item_name + " - x" + str(qty)

			FoodButton.add_item(display_text)
			var idx = FoodButton.get_item_count() - 1

			# Description priority: item → record → fallback
			var desc = ""
			if item.has("Description") and str(item.get("Description")) != "":
				desc = str(item.get("Description"))
			elif record.has("Description") and str(record.get("Description")) != "":
				desc = str(record.get("Description"))
			else:
				desc = "No description available."

			popup.set_item_metadata(idx, {"name": item_name, "qty": qty, "desc": desc})
			popup.set_item_tooltip(idx, desc)

	_sync_foodbutton_tooltip_to_selected()

	if player != Global.ACTIVE_USER_NAME:
		Checkbox.disabled = true
		FoodConfirm.disabled = true
	else:
		Checkbox.disabled = false
		FoodConfirm.disabled = false


func _sync_foodbutton_tooltip_to_selected() -> void:
	if FoodButton.get_item_count() == 0:
		FoodButton.tooltip_text = ""
		return
	var sel = FoodButton.get_selected()
	if sel < 0:
		sel = 0
	var popup: PopupMenu = FoodButton.get_popup()
	var meta = popup.get_item_metadata(sel)
	if typeof(meta) == TYPE_DICTIONARY and meta.has("desc"):
		FoodButton.tooltip_text = str(meta["desc"])
	else:
		FoodButton.tooltip_text = ""


# Connect to FoodButton.item_selected in the editor or via code
func _on_FoodButton_item_selected(index: int) -> void:
	_sync_foodbutton_tooltip_to_selected()



func _on_check_box_toggled(toggled_on: bool) -> void:
	print({"table": "Characters","record": PlayerID,"field": "Ready","value":Checkbox.button_pressed})
	Global.Update_Records([{"table": "Characters","record_id": PlayerID,"field": "Ready","value":Checkbox.button_pressed}])
	pass # Replace with function body.



func _on_button_pressed() -> void:
	var BaseName 
	var item_record_id
	var item_current_quantity
	var item_description
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
				item_description = item.get("Description")
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
