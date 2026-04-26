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

# Artifact prompt fields
var _artifact_fields: VBoxContainer
var _artifact_type_btn: OptionButton
var _artifact_stat1_btn: OptionButton
var _artifact_stat1_val: SpinBox
var _artifact_stat2_btn: OptionButton
var _artifact_stat2_val: SpinBox

const ARTIFACT_SLOTS = ["Flower of Life", "Feather of Death", "Sands of Time", "Goblet of Space", "Circlet of Principles"]
const ARTIFACT_STATS = ["HP", "ATK", "DEF", "HP%", "ATK%", "DEF%", "Elemental Mastery", "Energy Recharge%", "Crit Rate%", "Crit DMG%", "Physical DMG%", "Elemental DMG%", "Healing Bonus%"]

func _ready() -> void:
	_player_rid = Global.ACTIVE_USER_RECORD_ID
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.065, 0.082, 0.122, 0.98)
	bg.set_content_margin_all(16)
	add_theme_stylebox_override("panel", bg)
	_build_ui()
	_refresh_available_list("")
	_refresh_owned_list()

func _build_ui() -> void:
	# Fill the entire parent (full-screen Window)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Top bar: title + close button
	var top_bar = HBoxContainer.new()
	vbox.add_child(top_bar)
	var title = Label.new()
	title.text = "Offline Inventory Management"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)
	_close_btn = Button.new()
	_close_btn.text = "X  Close"
	_close_btn.pressed.connect(func(): panel_closed.emit(); queue_free())
	top_bar.add_child(_close_btn)

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

	# Artifact detail fields (hidden unless category is Artifacts)
	_artifact_fields = VBoxContainer.new()
	_artifact_fields.visible = false
	vbox.add_child(_artifact_fields)
	var af_label = Label.new()
	af_label.text = "Artifact Details"
	af_label.add_theme_font_size_override("font_size", 16)
	_artifact_fields.add_child(af_label)

	var type_row = HBoxContainer.new()
	_artifact_fields.add_child(type_row)
	var type_lbl = Label.new()
	type_lbl.text = "Slot:"
	type_row.add_child(type_lbl)
	_artifact_type_btn = OptionButton.new()
	for slot in ARTIFACT_SLOTS:
		_artifact_type_btn.add_item(slot)
	type_row.add_child(_artifact_type_btn)

	var stat1_row = HBoxContainer.new()
	_artifact_fields.add_child(stat1_row)
	var s1_lbl = Label.new()
	s1_lbl.text = "Stat 1:"
	stat1_row.add_child(s1_lbl)
	_artifact_stat1_btn = OptionButton.new()
	for s in ARTIFACT_STATS:
		_artifact_stat1_btn.add_item(s)
	stat1_row.add_child(_artifact_stat1_btn)
	_artifact_stat1_val = SpinBox.new()
	_artifact_stat1_val.max_value = 9999
	stat1_row.add_child(_artifact_stat1_val)

	var stat2_row = HBoxContainer.new()
	_artifact_fields.add_child(stat2_row)
	var s2_lbl = Label.new()
	s2_lbl.text = "Stat 2:"
	stat2_row.add_child(s2_lbl)
	_artifact_stat2_btn = OptionButton.new()
	for s in ARTIFACT_STATS:
		_artifact_stat2_btn.add_item(s)
	stat2_row.add_child(_artifact_stat2_btn)
	_artifact_stat2_val = SpinBox.new()
	_artifact_stat2_val.max_value = 9999
	stat2_row.add_child(_artifact_stat2_val)

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
		Global.Update_Records([{"table": "Characters", "record_id": char_rid, "field": "Current_Region", "value": new_region}])
		Global.Current_Region = new_region
	)
	region_hbox.add_child(region_btn)

	# Close button is at the top bar

func _on_category_changed(_index: int) -> void:
	_current_category = _category_btn.get_item_text(_index)
	_search_field.text = ""
	_artifact_fields.visible = (_current_category == "Artifacts")
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
			var raw_set_name := ""
			if source_item["_resource"] is ArtifactSetData:
				raw_set_name = (source_item["_resource"] as ArtifactSetData).artifact_set
			var slot_type = _artifact_type_btn.get_item_text(_artifact_type_btn.selected)
			var stat1 = _artifact_stat1_btn.get_item_text(_artifact_stat1_btn.selected)
			var stat1v = int(_artifact_stat1_val.value)
			var stat2 = _artifact_stat2_btn.get_item_text(_artifact_stat2_btn.selected)
			var stat2v = int(_artifact_stat2_val.value)
			columns = ["Name", "Owner", "Equipped", "Set_Name", "Type", "Stat1", "Stat1Value", "Stat2", "Stat2Value"]
			values = [source_item.get("Name", ""), _player_rid, false, raw_set_name, slot_type, stat1, stat1v, stat2, stat2v]
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
