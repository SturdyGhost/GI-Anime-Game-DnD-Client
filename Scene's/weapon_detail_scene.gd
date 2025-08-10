extends Panel
@onready var WeaponListVBox = $VBoxContainer/WeaponListContainer/WeaponListContainer
@onready var SearchBar = $VBoxContainer/SearchBar
@onready var SearchDebounce = $SearchDebounce
@onready var WeaponListItemScene: PackedScene = preload("res://Scene's/weapon_list_item.tscn")
@onready var CurrentWeaponPreview = $CurrentWeaponPreview
@onready var SelectedWeaponPreview = $SelectedWeaponPreview

var selected_weapon: Dictionary = {}
var weapon_items: Array = []
var ability_count = 0
var selected_weapon_count = 0
var unselected_weapon_count = 0
var weapon_type
var element
var updates = []
var current_sort_column = ""
var sort_ascending = true
var search_query: String = ""
var _confirm_locked := false
var _rows_to_init: int = 0

func _ready():
	populate_weapon_list()
	CurrentWeaponPreview.set_stats(selected_weapon)
	SearchBar.placeholder_text = "Search weapons…"
	SearchBar.text_changed.connect(_on_search_changed)
	if is_instance_valid(SearchDebounce):
		SearchDebounce.timeout.connect(_apply_filter)

func _process(delta: float) -> void:
	calc_selections()

func _on_preview_show(preview_stats: Dictionary, weapon_data: Dictionary):
	$StatPreviewPanel.show()
	$StatPreviewPanel.update_preview(preview_stats, weapon_data)

func _on_preview_hide():
	$StatPreviewPanel.hide()

func populate_weapon_list() -> void:
	for c in WeaponListVBox.get_children():
		c.queue_free()
	weapon_items.clear()
	selected_weapon = {}
	_rows_to_init = 0

	for data in Global.CHARACTER_WEAPONS.values():
		if data.get("Owner") == Global.ACTIVE_USER_NAME:
			var row = WeaponListItemScene.instantiate()
			WeaponListVBox.add_child(row)
			weapon_items.append(row)
			row.selected.connect(_on_weapon_selected)
			row.data_ready.connect(_on_row_data_ready)
			_rows_to_init += 1
			row.call_deferred("set_weapon_data", data)
			if data.get("Equipped", false):
				selected_weapon = data

func _on_row_data_ready() -> void:
	_rows_to_init -= 1
	if _rows_to_init <= 0:
		_apply_filter()  # now blobs are populated
		# re-apply current sort if you want:
		if current_sort_column != "":
			sort_weapon_list(current_sort_column)

func calc_selections():
	selected_weapon_count = 0
	unselected_weapon_count = 0
	for item in weapon_items:
		if item.get_node("EquipCheck").button_pressed == true:
			selected_weapon_count += 1
		else:
			unselected_weapon_count += 1
		
	

func _on_weapon_selected(data: Dictionary):
	selected_weapon = data
	SelectedWeaponPreview.set_stats(selected_weapon)

	# Uncheck all other items
	for item in weapon_items:
		if item.weapon_data != data:
			item.get_node("EquipCheck").button_pressed = false


func show_error(msg: String) -> void:
	$ErrorPopup.dialog_text = msg
	$ErrorPopup.popup_centered()

func _on_confirm_button_pressed() -> void:
	print("Confirm Button Pressed")
	if _confirm_locked:
		return
	_confirm_locked = true

	if selected_weapon.is_empty():
		show_error("No weapon selected.")
		_confirm_locked = false
		return

	
	var weapon_type = selected_weapon.get("Type")
	var char_id = Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]
	var element = Global.CHARACTERS[char_id].get("Element", null)

	
	
	if selected_weapon_count == 0:
		$"Error Label".text = "You do not have any weapon selected and 1 is required. Please select a weapon."
		_confirm_locked = false
		return
	elif selected_weapon_count >= 2:
		$"Error Label".text = "You have more than 1 weapon selected. Please select only 1 weapon to equip."
		_confirm_locked = false
		return

	for ability in Global.ABILITIES.values():
		if ability.get("Weapon") == weapon_type and ability.get("Element") == element and ability.get("Character") == Global.ACTIVE_USER_NAME:
			ability_count += 1

	if ability_count < 1:
		$"Error Label".text = "There is no valid kit that fits that element and weapon type. Please choose a valid weapon type or update your element."
		_confirm_locked = false
		return

	$"Error Label".text = ""

	# --------- DETERMINE CURRENT + TARGET RECORDS ---------
	var owner = Global.ACTIVE_USER_NAME
	var target_weapon_name = selected_weapon.get("Weapon")

	var equipped_ids: Array = []    # any currently true
	var target_id: String = ""      # the row that should be true

	for rec_id in Global.CHARACTER_WEAPONS.keys():
		var cw = Global.CHARACTER_WEAPONS[rec_id]
		if cw.get("Owner") != owner:
			continue
		if cw.get("Equipped", false) == true:
			equipped_ids.append(rec_id)
		if cw.get("Weapon") == target_weapon_name:
			target_id = rec_id

	# If target is already the only equipped, just close out early
	if equipped_ids.size() == 1 and equipped_ids[0] == target_id:
		queue_free()
		_confirm_locked = false
		return

	var updates: Array = []

	# --------- PASS 1: UNEQUIP EVERYTHING (except target if already true) ---------
	for rec_id in equipped_ids:
		if rec_id == target_id:
			continue
		updates.append({"table": "Character_Weapons", "record_id": float(rec_id), "field": "Equipped", "value": false})
		# local cache to keep UI steady
		Global.CHARACTER_WEAPONS[rec_id]["Equipped"] = false

	# --------- PASS 2: EQUIP TARGET ---------
	if target_id != "":
		updates.append({"table": "Character_Weapons", "record_id": float(target_id), "field": "Equipped", "value": true})
		Global.CHARACTER_WEAPONS[target_id]["Equipped"] = true

	# --------- PASS 3: UPDATE CHARACTER FIELDS ---------
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Current_Weapon", "value": target_weapon_name})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Type", "value": selected_weapon.get("Type")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Region", "value": selected_weapon.get("Region")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Rarity", "value": selected_weapon.get("Rarity")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Effect", "value": selected_weapon.get("Effect")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Refinement", "value": selected_weapon.get("Refinement")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Stat_1", "value": selected_weapon.get("Stat_1_Type")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Stat_1_Value", "value": selected_weapon.get("Stat_1_Value")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Stat_2", "value": selected_weapon.get("Stat_2_Type")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Stat_2_Value", "value": selected_weapon.get("Stat_2_Value")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Stat_3", "value": selected_weapon.get("Stat_3_Type")})
	updates.append({"table": "Characters", "record_id": float(char_id), "field": "Weapon_Stat_3_Value", "value": selected_weapon.get("Stat_3_Value")})


	

	# Send updates (your function already pauses poller etc.)
	Global.Update_Records(updates)


	# brief lock so you can’t double-fire while request is in flight
	await get_tree().create_timer(0.1).timeout
	_confirm_locked = false
	# Recalc + UI before network so the screen stays consistent
	Global.calculate_all_stats()
	get_parent().set_ui()
	queue_free()

func _on_exit_button_pressed() -> void:
	queue_free()
	pass # Replace with function body.

func sort_weapon_list(column_name: String) -> void:
	if current_sort_column == column_name:
		sort_ascending = !sort_ascending
	else:
		current_sort_column = column_name
		sort_ascending = true

	var items: Array = WeaponListVBox.get_children()
	items.sort_custom(Callable(self, "_compare_items"))

	# 🔧 instead of WeaponListContainer.clear()
	# remove (don’t free) then re-add in sorted order
	for n in items:
		WeaponListVBox.remove_child(n)
	for n in items:
		WeaponListVBox.add_child(n)

func get_item_value(row: Node, column_name: String):
	return row.get_sort_value(column_name) if row.has_method("get_sort_value") else ""

func _apply_filter() -> void:
	var tokens = search_query.to_lower().split(" ", false, 0)
	for row in WeaponListVBox.get_children():
		var hay = row.get_search_blob() if row.has_method("get_search_blob") else ""
		var show := tokens.is_empty()
		if !show:
			show = true
			for t in tokens:
				if t != "" and hay.findn(t) == -1:
					show = false
					break
		row.visible = show
		if row.has_method("apply_highlight"):
			row.apply_highlight(tokens if show else [])

func _compare_items(a: Node, b: Node) -> bool:
	var av = get_item_value(a, current_sort_column)
	var bv = get_item_value(b, current_sort_column)

	if str(av).is_valid_float() and str(bv).is_valid_float():
		var af = float(av)
		var bf = float(bv)
		return sort_ascending if af < bf else af > bf

	var cmp = str(av).nocasecmp_to(str(bv))
	return sort_ascending if cmp < 0 else cmp > 0

func _on_search_changed(new_text: String) -> void:
	search_query = new_text.strip_edges()
	if is_instance_valid(SearchDebounce):
		SearchDebounce.start()
	else:
		_apply_filter()

func get_row_search_blob(row: Node) -> String:
	# If your row scene exposes a helper, prefer that:
	if row.has_method("get_search_blob"):
		return str(row.get_search_blob()).to_lower()

	var parts: Array = []
	var cols = [
		"Name","Type","Region","Refinement",
		"Stat1","Stat1Value","Stat2","Stat2Value","Stat3","Stat3Value",
		"Effect","Equipped"
	]
	for c in cols:
		parts.append(str(get_item_value(row, c)))
	return " | ".join(parts).to_lower()

func _on_name_button_pressed() -> void:
	sort_weapon_list("Name")
	pass # Replace with function body.

func _on_type_button_pressed() -> void:
	sort_weapon_list("Type")
	pass # Replace with function body.

func _on_region_button_pressed() -> void:
	sort_weapon_list("Region")
	pass # Replace with function body.

func _on_refinement_button_pressed() -> void:
	sort_weapon_list("Refinement")
	pass # Replace with function body.

func _on_stat_1_button_pressed() -> void:
	sort_weapon_list("Stat1")
	pass # Replace with function body.

func _on_stat_1_value_button_pressed() -> void:
	sort_weapon_list("Stat1Value")
	pass # Replace with function body.

func _on_stat_2_button_pressed() -> void:
	sort_weapon_list("Stat2")
	pass # Replace with function body.

func _on_stat_2_value_button_pressed() -> void:
	sort_weapon_list("Stat2Value")
	pass # Replace with function body.

func _on_stat_3_button_pressed() -> void:
	sort_weapon_list("Stat3")
	pass # Replace with function body.

func _on_stat_3_value_button_pressed() -> void:
	sort_weapon_list("Stat3Value")
	pass # Replace with function body.

func _on_effect_button_pressed() -> void:
	sort_weapon_list("Effect")
	pass # Replace with function body.

func _on_equipped_button_pressed() -> void:
	sort_weapon_list("Equipped")
	pass # Replace with function body.
