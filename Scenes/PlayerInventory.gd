extends Control

# -------- UI refs --------
@onready var search_box: LineEdit      = $MarginContainer/HBoxContainer/LeftPane/SearchRow/SearchBox
@onready var clear_btn: Button         = $MarginContainer/HBoxContainer/LeftPane/SearchRow/ClearBtn
@onready var type_filter: OptionButton = $MarginContainer/HBoxContainer/LeftPane/FilterRow/TypeFilter
@onready var rarity_filter: OptionButton = $MarginContainer/HBoxContainer/LeftPane/FilterRow/RarityFilter
@onready var only_owned: CheckBox      = $MarginContainer/HBoxContainer/LeftPane/OnlyOwned
@onready var list: ItemList            = $MarginContainer/HBoxContainer/LeftPane/List

@onready var icon_tex: TextureRect     = $MarginContainer/HBoxContainer/RightPane/Icon
@onready var name_lbl: Label           = $MarginContainer/HBoxContainer/RightPane/NameLabel
@onready var qty_lbl: Label            = $MarginContainer/HBoxContainer/RightPane/QtyLabel
@onready var type_lbl: Label           = $MarginContainer/HBoxContainer/RightPane/TypeLabel
@onready var rarity_lbl: Label         = $MarginContainer/HBoxContainer/RightPane/RarityLabel
@onready var desc_lbl: RichTextLabel   = $MarginContainer/HBoxContainer/RightPane/DescLabel

# NEW: give-items UI (added below DescLabel in the scene)
@onready var player_dropdown: OptionButton = $MarginContainer/HBoxContainer/RightPane/GiveRow/PlayerDropdown
@onready var give_amount: SpinBox = $MarginContainer/HBoxContainer/RightPane/GiveRow/GiveAmount
@onready var give_button: Button = $MarginContainer/HBoxContainer/RightPane/GiveRow/GiveButton


# -------- Data caches --------
var _all_items_for_owner: Array = []     # [{id, row, lc_name, lc_type, lc_desc, qty, name, type, rarity, desc}]
var _filtered_ids: Array = []            # record_id list in current list order
var _selected_item

const RARITY_ORDER := ["common","uncommon","rare","epic","legendary","mythic"]

func _ready() -> void:
	_load_owner_items()
	_build_filter_options()
	_connect_ui()
	_apply_filters_and_search()
	_clear_preview()

	# NEW: populate “other players” and hook button
	_populate_player_dropdown()
	give_button.pressed.connect(_on_give_button_pressed)

# Canonical key: turn any int/float/string into a stable string key.
func _key_str(k) -> String:
	if typeof(k) == TYPE_FLOAT:
		var i = int(round(k))
		return str(i) if is_equal_approx(float(i), k) else str(k)
	return str(k)

var _items_by_key: Dictionary = {}  # "8" -> row dict

# -------- Load + index --------
func _to_int_or_zero(v) -> int:
	if v == null:
		return 0
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return int(round(v))
	var s: String = str(v).strip_edges()
	if s == "":
		return 0
	s = s.replace(",", "")
	if s.begins_with("x") or s.begins_with("X"):
		s = s.substr(1, s.length() - 1)
	return int(s) if s.is_valid_int() else 0

func _load_owner_items() -> void:
	_all_items_for_owner.clear()
	_items_by_key.clear()

	var owner: String = ""

	owner = str(Global.ACTIVE_USER_NAME).strip_edges().to_lower()
	if owner == "":
		return

	var src: Dictionary = Global.CHARACTER_ITEMS
	for rid in src.keys():
		var row_raw = src[rid]
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		# Owner match (case/space-insensitive)
		var row_owner: String = str(row_raw.get("Owner","")).strip_edges().to_lower()
		if row_owner != owner:
			continue

		var name: String = str(row_raw.get("Name",""))
		var type_val: String = str(row_raw.get("Type",""))
		var rarity_val: String = str(row_raw.get("Rarity",""))
		var qty: int = _to_int_or_zero(row_raw.get("Quantity", row_raw.get("Qty", row_raw.get("Count", null))))
		var desc_text: String = str(row_raw.get("Description",""))

		var key := _key_str(rid)  # canonical id ("8" for 8 / 8.0 / "8")
		_items_by_key[key] = row_raw

		_all_items_for_owner.append({
			"id": key, "row": row_raw,
			"lc_name": name.to_lower(), "lc_type": type_val.to_lower(),
			"lc_desc": desc_text.to_lower(),
			"qty": qty,
			"name": name, "type": type_val, "rarity": rarity_val, "desc": desc_text
		})

# Build Type/Rarity options from owner’s items
func _build_filter_options() -> void:
	type_filter.clear()
	rarity_filter.clear()
	type_filter.add_item("All Types")
	rarity_filter.add_item("All Rarities")
	var types := {}
	var rarities := {}
	for it in _all_items_for_owner:
		if it["type"] != "":
			types[it["type"]] = true
		if it["rarity"] != "":
			rarities[it["rarity"]] = true
	for t in types.keys():
		type_filter.add_item(t)
	var rar_list: Array = rarities.keys()
	rar_list.sort_custom(func(a, b):
		var ai := RARITY_ORDER.find(str(a).to_lower())
		var bi := RARITY_ORDER.find(str(b).to_lower())
		if ai == -1 and bi == -1: return str(a) < str(b)
		if ai == -1: return false
		if bi == -1: return true
		return ai < bi
	)
	for r in rar_list:
		rarity_filter.add_item(str(r))
	# ensure “All” is selected
	if type_filter.item_count > 0:
		type_filter.select(0)
	if rarity_filter.item_count > 0:
		rarity_filter.select(0)

# -------- UI wiring --------
func _connect_ui() -> void:
	search_box.text_changed.connect(func(_t): _apply_filters_and_search())
	clear_btn.pressed.connect(func():
		search_box.text = ""
		type_filter.select(0)
		rarity_filter.select(0)
		only_owned.button_pressed = false
		_apply_filters_and_search()
	)
	type_filter.item_selected.connect(func(_i): _apply_filters_and_search())
	rarity_filter.item_selected.connect(func(_i): _apply_filters_and_search())
	only_owned.toggled.connect(func(_p): _apply_filters_and_search())
	list.item_selected.connect(_on_item_selected)
	list.item_activated.connect(_on_item_activated)

# -------- Filtering + search --------
func _apply_filters_and_search() -> void:
	list.clear()
	_filtered_ids.clear()

	var q: String = search_box.text.strip_edges().to_lower()

	var sel_type := ""
	var idx_t := type_filter.selected
	if idx_t > 0: # 0 == “All Types”
		sel_type = type_filter.get_item_text(idx_t).to_lower()

	var sel_rarity := ""
	var idx_r := rarity_filter.selected
	if idx_r > 0: # 0 == “All Rarities”
		sel_rarity = rarity_filter.get_item_text(idx_r).to_lower()

	var qty_gate := only_owned.button_pressed

	# Build filtered set
	var visible_items := []
	for it in _all_items_for_owner:
		if qty_gate and it["qty"] <= 0:
			continue
		if sel_type != "" and it["lc_type"] != sel_type:
			continue
		if sel_rarity != "" and str(it["rarity"]).to_lower() != sel_rarity:
			continue
		if q != "":
			var hit = it["lc_name"].find(q) != -1 \
				or it["lc_type"].find(q) != -1 \
				or it["lc_desc"].find(q) != -1
			if not hit:
				continue
		visible_items.append(it)

	# Sort alphabetically by name
	visible_items.sort_custom(func(a, b):
		return str(a["name"]).to_lower() < str(b["name"]).to_lower()
	)

	# Add to ItemList
	for it in visible_items:
		var qty: int = it["qty"]
		var line: String = "x" + str(qty)
		# Determine spacing based on digit count
		var digits := str(qty).length()
		var spaces := 1  # default for 4+ digits
		match digits:
			1:
				spaces = 4
			2:
				spaces = 3
			3:
				spaces = 2
			_:
				spaces = 1

		line += " ".repeat(spaces) + it["name"]
		var idx := list.add_item(line)
		var rid_key: String = it["id"]  # canonical string key
		list.set_item_metadata(idx, rid_key)
		_filtered_ids.append(rid_key)

	_clear_preview()

# -------- Selection + preview --------
func _on_item_selected(idx: int) -> void:
	var rid = list.get_item_metadata(idx)
	_show_preview(rid)

# Optional: activate could be used to open a detail modal, etc.
func _on_item_activated(idx: int) -> void:
	var rid = list.get_item_metadata(idx)
	_show_preview(int(rid))

func _show_preview(rid) -> void:
	var row := _get_row_by_id(rid)
	if row.is_empty():
		_clear_preview()
		return
	_selected_item = row
	var name: String = str(row.get("Name",""))
	var qty: int = _to_int_or_zero(row.get("Quantity", row.get("Qty", row.get("Count", null))))
	var type_val: String = str(row.get("Type",""))
	var rarity_val: String = str(row.get("Rarity",""))
	var desc_text: String
	if row.get("Description") != null:
		desc_text= str(row.get("Description",""))
	else:
		desc_text = ""

	name_lbl.text = name
	qty_lbl.text = "Quantity: " + str(qty)

	# NEW: set SpinBox bounds for giving
	if give_amount != null:
		give_amount.min_value = 1
		give_amount.max_value = max(1, qty)
		give_amount.value = min(1, qty) if qty > 0 else 1

	type_lbl.text = "Type: " + type_val
	rarity_lbl.text = "Rarity: " + rarity_val
	desc_lbl.text = desc_text
	var hyphenname = name.to_lower().replace(" ","-")
	if row.get("Type") == "Consumable":
		icon_tex.texture = load("res://UI/Food Icons/"+hyphenname+".png")
	else:
		icon_tex.texture = load("res://UI/Item Icons/"+hyphenname+".png")

func _get_row_by_id(rid) -> Dictionary:
	return _items_by_key.get(_key_str(rid), {})

func _clear_preview() -> void:
	icon_tex.texture = null
	name_lbl.text = ""
	qty_lbl.text = ""
	type_lbl.text = ""
	rarity_lbl.text = ""
	desc_lbl.text = ""

# -------- Give UI helpers --------
func _populate_player_dropdown() -> void:
	if player_dropdown == null:
		return
	player_dropdown.clear()

	for pname in Global.CHARACTERS_NAME.keys():
		if pname != Global.ACTIVE_USER_NAME and pname != "Chase":
			player_dropdown.add_item(pname)

func _on_give_button_pressed() -> void:
	var idx := player_dropdown.selected if player_dropdown != null else -1
	if idx < 0:
		print("[Give] No target selected")
		return
	var target_name := player_dropdown.get_item_text(idx)
	var amount := int(give_amount.value) if give_amount != null else 0
	var item_name := name_lbl.text
	print("[Give] Request -> give", amount, "of", item_name, "to", target_name)
	# TODO: call your transfer function here
	# transfer_item(Global.ACTIVE_USER_NAME, target_name, current_item_id, amount)

# -------- Icon hook (you set these up) --------
func _get_icon_for(name: String, type_val: String, rarity_val: String) -> Texture2D:
	# Example lookups; replace with your own
	if Global.has("ITEM_ICONS_BY_NAME"):
		var t = Global.ITEM_ICONS_BY_NAME.get(name, null)
		if t is Texture2D:
			return t
	if Global.has("ITEM_ICONS_BY_TYPE"):
		var t2 = Global.ITEM_ICONS_BY_TYPE.get(type_val, null)
		if t2 is Texture2D:
			return t2
	return null


func _on_exit_button_pressed() -> void:
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()
	pass # Replace with function body.
