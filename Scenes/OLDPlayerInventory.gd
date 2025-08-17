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

# -------- Data caches --------
var _all_items_for_owner: Array = []     # [{id, row, lc_name, lc_type, lc_desc, qty}]
var _filtered_ids: Array = []            # record_id list in current list order
var row
var row_raw 

const RARITY_ORDER := ["common","uncommon","rare","epic","legendary","mythic"]

func _ready() -> void:
	_load_owner_items()
	_build_filter_options()
	_connect_ui()
	_apply_filters_and_search()
	_clear_preview()


# Canonical key: turn any int/float/string into a stable string key.
func _key_str(k) -> String:
	if typeof(k) == TYPE_FLOAT:
		var i = int(round(k))
		return str(i) if is_equal_approx(float(i), k) else str(k)
	return str(k)

var _items_by_key: Dictionary = {}  # "8" -> row dict
# -------- Load + index --------
func _load_owner_items() -> void:
	_all_items_for_owner.clear()
	_items_by_key.clear()

	var owner = str(Global.ACTIVE_USER_NAME).strip_edges().to_lower()
	if owner == "": return

	var src: Dictionary = Global.CHARACTER_ITEMS
	for rid in src.keys():
		row_raw = src[rid]
		

		var row_owner = str(row_raw.get("Owner","")).strip_edges().to_lower()
		if row_owner != owner: continue
		var name = str(row_raw.get("Name",""))
		var type_val = str(row_raw.get("Type",""))
		var rarity_val = str(row_raw.get("Rarity",""))
		var qty = _to_int_or_zero(row_raw.get("Quantity", row_raw.get("Qty", row_raw.get("Count", null))))
		var desc_text = str(row_raw.get("Description",""))

		var key = _key_str(rid)  # <- canonical ID

		_items_by_key[key] = row_raw
		_all_items_for_owner.append({
			"id": key, "row": row_raw,   # <- store canonical ID (string)
			"lc_name": name.to_lower(), "lc_type": type_val.to_lower(),
			"lc_desc": desc_text.to_lower(),
			"qty": qty,
			"name": name, "type": type_val, "rarity": rarity_val, "desc": desc_text
		})

# Replace your qty parsing with this helper:
func _to_int_or_zero(v) -> int:
	if v == null: return 0
	if typeof(v) == TYPE_INT: return int(v)
	if typeof(v) == TYPE_FLOAT: return int(round(v))
	var s := str(v).strip_edges()
	if s == "": return 0
	# Remove commas or leading 'x' like "x12"
	s = s.replace(",", "")
	if s.begins_with("x") or s.begins_with("X"):
		s = s.substr(1, s.length() - 1)
	return int(s) if s.is_valid_int() else 0


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
	rar_list.sort() # keep simple; or use your RARITY_ORDER sorter

	for r in rar_list:
		rarity_filter.add_item(str(r))

	# ✅ Ensure index 0 (“All …”) is selected
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
	list.item_activated.connect(_on_item_activated) # double-click/Enter if you want

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

	# ✅ Make a filtered copy and sort it by name before listing
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
		list.set_item_metadata(idx, it["id"])
		_filtered_ids.append(it["id"])

	_clear_preview()

# -------- Selection + preview --------
func _on_item_selected(idx: int) -> void:
	var rid = list.get_item_metadata(idx)
	print(rid)
	_show_preview(rid)

# Optional: activate could be used to open a detail modal, etc.
func _on_item_activated(idx: int) -> void:
	var rid = list.get_item_metadata(idx)
	_show_preview(int(rid))

func _show_preview(rid) -> void:
	row = _get_row_by_id(rid)
	if row.is_empty():
		_clear_preview()
		return

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
	type_lbl.text = "Type: " + type_val
	rarity_lbl.text = "Rarity: " + rarity_val
	desc_lbl.text = desc_text

	#icon_tex.texture = _get_icon_for(name, type_val, rarity_val)


func _get_row_by_id(rid) -> Dictionary:
	print (rid)
	return _items_by_key.get(_key_str(rid), {})


func _clear_preview() -> void:
	icon_tex.texture = null
	name_lbl.text = ""
	qty_lbl.text = ""
	type_lbl.text = ""
	rarity_lbl.text = ""
	desc_lbl.text = ""

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
