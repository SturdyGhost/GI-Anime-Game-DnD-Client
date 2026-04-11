extends PanelContainer
## Offline-only panel for players to add/remove weapons, artifacts, and items.
## Mirrors the DM Hub's first tab but scoped to the active player's character only.

signal panel_closed

var _category_btn: OptionButton
var _item_list: ItemList
var _search_field: LineEdit
var _add_btn: Button
var _remove_btn: Button
var _mora_spin: SpinBox
var _mora_btn: Button
var _close_btn: Button

var _current_category: String = "Weapons"
var _filtered_items: Array = []  # GameDB items matching current search
var _owned_items: Array = []     # Items owned by this player in _synced
var _player_rid: int = 0
var _avail_list: ItemList  # Store reference to avoid tree traversal

func _ready() -> void:
	_player_rid = Global.ACTIVE_USER_RECORD_ID
	_build_ui()
	_refresh_available_list("")
	_refresh_owned_list()

func _build_ui() -> void:
	custom_minimum_size = Vector2(500, 600)

	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Offline Inventory Management"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Category selector
	var cat_hbox = HBoxContainer.new()
	vbox.add_child(cat_hbox)
	var cat_label = Label.new()
	cat_label.text = "Category:"
	cat_hbox.add_child(cat_label)
	_category_btn = OptionButton.new()
	_category_btn.add_item("Weapons")
	_category_btn.add_item("Artifacts")
	_category_btn.add_item("Items")
	_category_btn.item_selected.connect(_on_category_changed)
	cat_hbox.add_child(_category_btn)

	# Search field
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Search..."
	_search_field.text_changed.connect(_on_search_changed)
	vbox.add_child(_search_field)

	# Split: available (left) and owned (right)
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	# Available items from GameDB
	var avail_vbox = VBoxContainer.new()
	split.add_child(avail_vbox)
	var avail_label = Label.new()
	avail_label.text = "Available"
	avail_vbox.add_child(avail_label)
	_avail_list = ItemList.new()
	_avail_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avail_vbox.add_child(_avail_list)

	# Owned items
	var own_vbox = VBoxContainer.new()
	split.add_child(own_vbox)
	var own_label = Label.new()
	own_label.text = "Owned"
	own_vbox.add_child(own_label)
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	own_vbox.add_child(_item_list)

	# Add/Remove buttons
	var btn_hbox = HBoxContainer.new()
	vbox.add_child(btn_hbox)
	_add_btn = Button.new()
	_add_btn.text = "Add Selected"
	_add_btn.pressed.connect(_on_add_pressed)
	btn_hbox.add_child(_add_btn)
	_remove_btn = Button.new()
	_remove_btn.text = "Remove Selected"
	_remove_btn.pressed.connect(_on_remove_pressed)
	btn_hbox.add_child(_remove_btn)

	# Mora editor — players coordinate verbally, highest value wins on merge
	var mora_hbox = HBoxContainer.new()
	vbox.add_child(mora_hbox)
	var mora_label = Label.new()
	mora_label.text = "Mora:"
	mora_hbox.add_child(mora_label)
	_mora_spin = SpinBox.new()
	_mora_spin.max_value = 999999
	_mora_spin.step = 100
	var party = Global.Current_Party
	_mora_spin.value = int(party.get("Mora", 0)) if party else 0
	mora_hbox.add_child(_mora_spin)
	_mora_btn = Button.new()
	_mora_btn.text = "Set Mora"
	_mora_btn.pressed.connect(_on_set_mora)
	mora_hbox.add_child(_mora_btn)

	# Region selector
	var region_hbox = HBoxContainer.new()
	vbox.add_child(region_hbox)
	var region_label = Label.new()
	region_label.text = "Region:"
	region_hbox.add_child(region_label)
	var region_btn = OptionButton.new()
	for r in ["Mondstadt", "Liyue", "Inazuma", "Sumeru", "Fontaine", "Natlan", "Snezhnaya"]:
		region_btn.add_item(r)
	# Set current region
	var current = Global.Current_Region
	for i in region_btn.item_count:
		if region_btn.get_item_text(i) == current:
			region_btn.selected = i
			break
	region_btn.item_selected.connect(func(idx):
		var new_region = region_btn.get_item_text(idx)
		var char_rid = Global.ACTIVE_USER_RECORD_ID
		Global.Update_Records([{"table": "Characters", "record_id": char_rid, "field": "Region", "value": new_region}])
		Global.Current_Region = new_region
	)
	region_hbox.add_child(region_btn)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(func(): panel_closed.emit(); queue_free())
	vbox.add_child(_close_btn)

func _on_category_changed(_index: int) -> void:
	_current_category = _category_btn.get_item_text(_index)
	_search_field.text = ""
	_refresh_available_list("")
	_refresh_owned_list()

func _on_search_changed(text: String) -> void:
	_refresh_available_list(text)

func _get_display_name(res: Resource) -> String:
	## Extract a human-readable display name from a GameDB typed resource.
	## WeaponData uses .name, ItemData uses .item_name, ArtifactSetData uses .artifact_set.
	match _current_category:
		"Weapons":
			return str((res as WeaponData).name) if res is WeaponData else ""
		"Items":
			return str((res as ItemData).item_name) if res is ItemData else ""
		"Artifacts":
			if res is ArtifactSetData:
				var a := res as ArtifactSetData
				return "%s (%dpc)" % [a.artifact_set, a.bonus_type]
			return ""
	return ""

func _refresh_available_list(search: String) -> void:
	_filtered_items.clear()
	var source_dict: Dictionary = {}
	match _current_category:
		"Weapons":
			source_dict = GameDB.weapons
		"Artifacts":
			source_dict = GameDB.artifact_sets
		"Items":
			source_dict = GameDB.items

	for id in source_dict.keys():
		var res = source_dict[id]
		var item_name: String = _get_display_name(res)
		if search == "" or search.to_lower() in item_name.to_lower():
			_filtered_items.append({"id": id, "Name": item_name, "_resource": res})

	_avail_list.clear()
	for item in _filtered_items:
		_avail_list.add_item(item["Name"])

func _refresh_owned_list() -> void:
	_owned_items.clear()
	var table_name = _synced_table_for_category()
	var synced_table = Global._synced.get(table_name, {})
	for rid in synced_table.keys():
		var record = synced_table[rid]
		# Filter to only this player's items
		var owner_id = int(record.get("Owner", record.get("Character_Id", 0)))
		if owner_id == _player_rid:
			_owned_items.append(record)

	_item_list.clear()
	for item in _owned_items:
		var display = str(item.get("Name", "Item #%s" % str(item.get("id", "?"))))
		if item.has("Equipped") and item["Equipped"]:
			display += " [E]"
		_item_list.add_item(display)

func _synced_table_for_category() -> String:
	match _current_category:
		"Weapons": return "Character_Weapons"
		"Artifacts": return "Character_Artifacts"
		"Items": return "Character_Items"
	return ""

func _on_add_pressed() -> void:
	if not _avail_list.is_anything_selected():
		return
	var selected_indices = _avail_list.get_selected_items()
	if selected_indices.is_empty():
		return
	var idx = selected_indices[0]
	if idx >= _filtered_items.size():
		return

	var source_item = _filtered_items[idx]
	var table = _synced_table_for_category()
	var columns: Array = []
	var values: Array = []

	match _current_category:
		"Weapons":
			columns = ["Name", "Owner", "Equipped", "Refinement"]
			values = [source_item.get("Name", ""), _player_rid, false, 1]
		"Artifacts":
			# Store the raw artifact_set name (without the "(Xpc)" suffix) for DB compatibility
			var raw_set_name := ""
			if source_item["_resource"] is ArtifactSetData:
				raw_set_name = (source_item["_resource"] as ArtifactSetData).artifact_set
			columns = ["Name", "Owner", "Equipped", "Set_Name"]
			values = [source_item.get("Name", ""), _player_rid, false, raw_set_name]
		"Items":
			columns = ["Name", "Owner", "Quantity"]
			values = [source_item.get("Name", ""), _player_rid, 1]

	Global.Insert(table, columns, values)
	_refresh_owned_list()

func _on_remove_pressed() -> void:
	if not _item_list.is_anything_selected():
		return
	var selected_indices = _item_list.get_selected_items()
	if selected_indices.is_empty():
		return
	var idx = selected_indices[0]
	if idx >= _owned_items.size():
		return

	var record = _owned_items[idx]
	var table = _synced_table_for_category()
	Global.Remove_Record(table, int(record.get("id", 0)))
	_refresh_owned_list()

func _on_set_mora() -> void:
	var party = Global.Current_Party
	if party == null or not party.has("id"):
		return
	Global.Update_Records([{
		"table": "Party",
		"record_id": int(party["id"]),
		"field": "Mora",
		"value": int(_mora_spin.value)
	}])
