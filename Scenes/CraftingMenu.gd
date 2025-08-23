extends Control
# Godot 4.4.1 — Crafting Menu with end-of-function validation prints

# --------------------------
# EXPECTED GLOBAL SHAPES
# --------------------------
# Global.CRAFTING_RECIPES: Dictionary { record_id: { "Role","Product","Region","Description","Icon","Material","Quantity" }, ... }
# Global.CHARACTERS_NAME: { readable_name: record_id }
# Global.ACTIVE_USER_NAME: readable_name
# Global.CHARACTERS[record_id]["Role"]
# Global.INVENTORY: Array[Dictionary] OR Dictionary id->dict  (fields: "Id","Name","Type","Quantity","Icon?")
# Global.decrement_inventory(id, qty) -> bool
# Global.give_item_to_player(product_name, qty, target) -> void
# Global.get_party_names() -> Array[String]
# Global.Log(category, action, related_type, related_id, old_values, new_values, metadata, result, severity)

# --------------------------
# UI node paths (for re-resolve)
# --------------------------
const PATH_RECIPE_LIST: String = "HSplit/LeftPanel/LeftVBox/Scroll/RecipeList"
const PATH_SEARCH: String = "HSplit/LeftPanel/LeftVBox/LeftHeader/Search"
const PATH_TARGET_SELECT: String = "HSplit/RightPanel/RightVBox/BottomBar/TargetSelect"
const PATH_QTY_SPIN: String = "HSplit/RightPanel/RightVBox/BottomBar/QtySpin"
const PATH_CONFIRM: String = "HSplit/RightPanel/RightVBox/BottomBar/Confirm"
const PATH_ROWS: String = "HSplit/RightPanel/RightVBox/IngredientsVBox/Rows"
const PATH_ICON: String = "HSplit/RightPanel/RightVBox/TopPreview/TopHBox/Icon"
const PATH_PRODUCT_LBL: String = "HSplit/RightPanel/RightVBox/TopPreview/TopHBox/MetaVBox/ProductLabel"
const PATH_REGION_LBL: String = "HSplit/RightPanel/RightVBox/TopPreview/TopHBox/MetaVBox/RegionLabel"
const PATH_DESC: String = "HSplit/RightPanel/RightVBox/TopPreview/TopHBox/MetaVBox/Desc"
const PATH_BOTTOM_BAR: String = "HSplit/RightPanel/RightVBox/BottomBar"

# --------------------------
# Nodes (nullable; we re-resolve)
# --------------------------
@onready var recipe_list: VBoxContainer = get_node_or_null(PATH_RECIPE_LIST)
@onready var search: LineEdit = get_node_or_null(PATH_SEARCH)
@onready var target_select: OptionButton = get_node_or_null(PATH_TARGET_SELECT)
@onready var qty_spin: SpinBox = get_node_or_null(PATH_QTY_SPIN)
@onready var confirm_btn: Button = get_node_or_null(PATH_CONFIRM)
@onready var rows: VBoxContainer = get_node_or_null(PATH_ROWS)
@onready var icon_rect: TextureRect = get_node_or_null(PATH_ICON)
@onready var product_label: Label = get_node_or_null(PATH_PRODUCT_LBL)
@onready var region_label: Label = get_node_or_null(PATH_REGION_LBL)
@onready var desc: RichTextLabel = get_node_or_null(PATH_DESC)


const MAX_SLOTS: int = 6

# --------------------------
# STATE
# --------------------------
var _grouped_recipes: Dictionary = {}     # product -> { meta: {...}, requirements: [ {material,quantity}, ... ] }
var _visible_products: Array[String] = []
var _selected_product: String = ""
var _slot_to_item_id: Dictionary = {}     # slot_idx -> inventory item Id
var _slot_requirements: Array = []        # current product requirements
var _inventory_snapshot_before: Dictionary = {}
var inv


# --------------------------
# Helpers (logging + safe getters)
# --------------------------
func _log(msg: String) -> void:
	print("[CraftingMenu] %s" % msg)

func _get_row(i: int) -> HBoxContainer:
	var parent := rows if rows != null else get_node_or_null(PATH_ROWS)
	if parent == null:
		return null
	return parent.get_node_or_null("Row%d" % (i + 1)) as HBoxContainer

func _get_opt(i: int) -> OptionButton:
	var row := _get_row(i)
	if row == null:
		return null
	return row.get_node_or_null("Opt%d" % (i + 1)) as OptionButton

func _get_req_label(i: int) -> Label:
	var row := _get_row(i)
	if row == null:
		return null
	return row.get_node_or_null("Req%d" % (i + 1)) as Label

func _get_have_need(i: int) -> Label:
	var row := _get_row(i)
	if row == null:
		return null
	return row.get_node_or_null("HaveNeed%d" % (i + 1)) as Label

# --------------------------
# Ready / UI init
# --------------------------
func _ready() -> void:
	call_deferred("_init_ui")
	_log("[_ready] deferred UI init scheduled")

func _init_ui() -> void:
	_resolve_ui_refs()

	# Signals (null-safe)
	if search != null:
		search.text_changed.connect(_on_search_changed)
	if qty_spin != null:
		qty_spin.value_changed.connect(_on_qty_changed)
	if confirm_btn != null:
		confirm_btn.pressed.connect(_on_confirm_pressed)

	_build_product_groups()
	_build_recipe_buttons()
	_populate_party_targets()
	_tune_row_layout()
	_refresh_confirm_enabled()
	_log("[_init_ui] UI wired; products=%d, visible=%d" % [_grouped_recipes.size(), _visible_products.size()])

func _resolve_ui_refs() -> void:
	# Re-resolve in case scene changed
	if recipe_list == null: recipe_list = get_node_or_null(PATH_RECIPE_LIST)
	if search == null: search = get_node_or_null(PATH_SEARCH)
	if target_select == null: target_select = get_node_or_null(PATH_TARGET_SELECT)
	if qty_spin == null: qty_spin = get_node_or_null(PATH_QTY_SPIN)
	if confirm_btn == null: confirm_btn = get_node_or_null(PATH_CONFIRM)
	if rows == null: rows = get_node_or_null(PATH_ROWS)
	if icon_rect == null: icon_rect = get_node_or_null(PATH_ICON)
	if product_label == null: product_label = get_node_or_null(PATH_PRODUCT_LBL)
	if region_label == null: region_label = get_node_or_null(PATH_REGION_LBL)
	if desc == null: desc = get_node_or_null(PATH_DESC)
	_log("[_resolve_ui_refs] resolved nodes: list=%s search=%s target=%s qty=%s confirm=%s rows=%s"
		% [recipe_list != null, search != null, target_select != null, qty_spin != null, confirm_btn != null, rows != null])

# --------------------------
# Party
# --------------------------
func _populate_party_targets() -> void:
	if target_select == null:
		print("[CraftingMenu] [_populate_party_targets] target_select missing")
		return

	target_select.clear()
	var idx = 0

	# Always include the active user first
	var active_name: String = Global.ACTIVE_USER_NAME
	target_select.add_item(active_name)
	target_select.set_item_metadata(0, Global.CHARACTERS_NAME.get(active_name, null))

	# Then try to get Party Member 1 & 2 from Global.CHARACTERS
	for slot_label in ["Party_Member_1", "Party_Member_2"]:
		if Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]].has(slot_label):
			idx += 1
			var pm_name = Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]][slot_label]
			target_select.add_item(pm_name)
			target_select.set_item_metadata(idx, pm_name)
		else:
			print("[CraftingMenu] %s not in Global.CHARACTERS" % slot_label)

	# Select the first option (active user) by default
	if target_select.item_count > 0:
		target_select.select(0)

	print("[CraftingMenu] [_populate_party_targets] targets=%d (selected=%s)" %
		[target_select.item_count, target_select.get_item_text(target_select.get_selected_id())])

func _tune_row_layout() -> void:
	for i in range(MAX_SLOTS):
		var row := _get_row(i)
		if row == null: 
			continue

		var req := _get_req_label(i)       # left "Material" label
		var opt := _get_opt(i)             # middle OptionButton
		var hn  := _get_have_need(i)       # right "have/need" label

		# Left label: fixed-ish width
		if req:
			req.size_flags_horizontal = Control.SIZE_FILL
			req.size_flags_stretch_ratio = 1.0
			req.custom_minimum_size.x = max(req.custom_minimum_size.x, 450.0)

		# Middle dropdown: ~70% of original width
		if opt:
			opt.size_flags_horizontal = Control.SIZE_FILL
			opt.size_flags_stretch_ratio = 2.1  # ↓ lowered from 3.0 → ~70% width
			opt.fit_to_longest_item = false
			if "clip_text" in opt:
				opt.clip_text = true
			if "text_overrun_behavior" in opt:
				opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			opt.custom_minimum_size.x = 650.0  # cap width to keep it small

		# Right label: aligned right
		if hn:
			hn.size_flags_horizontal = Control.SIZE_FILL
			hn.size_flags_stretch_ratio = 0.7
			if "horizontal_alignment" in hn:
				hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hn.custom_minimum_size.x = max(hn.custom_minimum_size.x, 80.0)



# --------------------------
# Role / Recipes
# --------------------------
func _get_active_role() -> String:
	var role: String = ""
	if "ACTIVE_USER_NAME" in Global and "CHARACTERS_NAME" in Global and "CHARACTERS" in Global:
		var readable: String = Global.ACTIVE_USER_NAME
		var rec_id = Global.CHARACTERS_NAME.get(readable, null)
		if rec_id != null and rec_id in Global.CHARACTERS:
			role = str(Global.CHARACTERS[rec_id].get("Role", ""))
	_log("[_get_active_role] role='%s'" % role)
	return role

func _build_product_groups() -> void:
	_grouped_recipes.clear()
	var active_role: String = _get_active_role()
	var added: int = 0
	if "CRAFTING_RECIPES" in Global and Global.CRAFTING_RECIPES is Dictionary:
		for rec_id in Global.CRAFTING_RECIPES.keys():
			var r: Dictionary = Global.CRAFTING_RECIPES[rec_id]
			if str(r.get("Role", "")) != active_role:
				continue
			var product: String = str(r.get("Product", ""))
			if product == "":
				continue
			if not _grouped_recipes.has(product):
				_grouped_recipes[product] = {
					"meta": {
						"Product": product,
						"Region": str(r.get("Region", "")),
						"Description": str(r.get("Description", "")),
						"Icon": r.get("Icon", null)
					},
					"requirements": []
				}
			_grouped_recipes[product]["requirements"].append({
				"material": str(r.get("Material", "")),
				"quantity": int(r.get("Quantity", 1))
			})
			added += 1
	_log("[_build_product_groups] grouped_products=%d rows_added=%d" % [_grouped_recipes.size(), added])

# --------------------------
# Left list (product buttons)
# --------------------------
func _build_recipe_buttons() -> void:
	_resolve_ui_refs()
	if recipe_list == null:
		_log("[_build_recipe_buttons] skipped (no RecipeList)")
		return

	for c in recipe_list.get_children():
		if c != null:
			c.queue_free()

	_visible_products = _filter_products(search.text if search != null else "")
	_visible_products.sort_custom(func(a, b): return a < b)

	for product in _visible_products:
		var btn := Button.new()
		btn.text = product
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_product_pressed.bind(product))
		btn.custom_minimum_size = Vector2(475,75)
		btn.autowrap_mode = 2
		recipe_list.add_child(btn)

	_log("[_build_recipe_buttons] built_buttons=%d (visible_products=%d)" % [recipe_list.get_child_count(), _visible_products.size()])

# Replace your existing _filter_products with this:
func _filter_products(query: String) -> Array[String]:
	var out: Array[String] = []

	if query.strip_edges() == "":
		# keys() returns Array (Variant); coerce to Array[String]
		for k in _grouped_recipes.keys():
			out.append(str(k))
		# Strings -> simple lexicographic sort is fine
		out.sort()
		return out

	var q: String = query.to_lower()
	for p in _grouped_recipes.keys():
		var product: String = str(p)
		var meta: Dictionary = _grouped_recipes[product]["meta"]
		var region: String = str(meta.get("Region", ""))
		if product.to_lower().find(q) != -1 or region.to_lower().find(q) != -1:
			out.append(product)

	out.sort()
	return out


func _on_search_changed(_t: String) -> void:
	_build_recipe_buttons()
	_log("[_on_search_changed] rebuilt list")

func _on_product_pressed(product: String) -> void:
	_selected_product = product
	_assign_icon(_selected_product)
	update_preview(product)
	_build_ingredient_rows(product)
	_refresh_confirm_enabled()
	_log("[_on_product_pressed] product='%s' selected" % product)

# --------------------------
# Top preview
# --------------------------
# --- ARTISAN: look up in Global.Items by value["Item"] == selected product ---
func _populate_artisan_preview(selected_item) -> void:
	var name: String = str(selected_item)
	var row: Dictionary = _lookup_items_by_item_field(name)

	if row.is_empty():
		_set_text(product_label, name)
		_set_text(region_label, "")
		_set_text(desc, "Details not found")
		return

	# Map your three labels
	_set_text(product_label, str(row.get("Item", name)))
	_set_text(region_label,  str(row.get("Region", row.get("Type", ""))))
	_set_text(desc,          str(row.get("Description", row.get("Notes", ""))))

# Strictly search Global.Items where row["Item"] matches the given name (case-insensitive).
func _lookup_items_by_item_field(name: String) -> Dictionary:
	var items = Global.ITEMS
	if typeof(items) != TYPE_DICTIONARY or items.is_empty():
		return {}

	var key: String = name.strip_edges()
	var key_lc: String = key.to_lower()

	# 1) If your Items uses the display name as a direct key, allow that too.
	if items.has(key):
		var direct_row = items[key]
		if typeof(direct_row) == TYPE_DICTIONARY:
			return direct_row

	# 2) Primary: match by the "Item" field (case-insensitive)
	for rid in items.keys():
		var row = items[rid]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item_field: String = str(row.get("Item", "")).strip_edges().to_lower()
		if item_field != "" and item_field == key_lc:
			return row

	# 3) Optional minor fallbacks (uncomment if helpful):
	# for rid in items.keys():
	#     var row2 = items[rid]
	#     var alt: String = str(row2.get("Name", row2.get("Product", ""))).strip_edges().to_lower()
	#     if alt != "" and alt == key_lc:
	#         return row2

	return {}

# ---------------- Blacksmith path ----------------
func _populate_blacksmith_preview(selected_item) -> void:
	var weapon: Dictionary = _lookup_weapon(selected_item)

	if weapon.is_empty():
		_clear_preview("Weapon not found: %s" % str(selected_item))
		return

	# ProductLabel → Name
	_set_text(product_label, str(weapon.get("Name", "")))

	# RegionLabel → "WeaponType · Rarity★" (if available)
	var w_type: String = str(weapon.get("WeaponType", weapon.get("Type", "")))
	var rarity: String = str(weapon.get("Rarity", weapon.get("Stars", "")))
	var type_line: String = w_type if rarity == "" else "%s · %s" % [w_type, rarity]
	_set_text(region_label, type_line)

	# Desc → compact stat/effect block
	_set_text(desc, _format_weapon_desc(weapon))

# Resolve a STRING selection to a weapon dictionary in Global.Weapons.
# Handles: direct key match, case-insensitive Name match, and a couple alt name fields.
func _lookup_weapon(selection) -> Dictionary:


	# 1) If selection is a direct key in Global.Weapons (ID or name-as-key)
	if typeof(selection) == TYPE_STRING:
		var key: String = selection.strip_edges()
		if Global.WEAPONS.has(key):
			return Global.WEAPONS[key]

		# 2) Search by Name (case-insensitive)
		var key_lc: String = key.to_lower()
		for id in Global.WEAPONS.keys():
			var w: Dictionary = Global.WEAPONS[id]
			var nm: String = str(w.get("Name", "")).to_lower()
			if nm == key_lc:
				return w

		# 3) Try common alternate fields used as display names
		for id in Global.WEAPONS.keys():
			var w2: Dictionary = Global.WEAPONS[id]
			var alt: String = str(w2.get("WeaponName", w2.get("Product", ""))).to_lower()
			if alt != "" and alt == key_lc:
				return w2

		return {}

	# If someone passes a dict later, be forgiving:
	if typeof(selection) == TYPE_DICTIONARY:
		if selection.has("WeaponId"):
			var wid = selection["WeaponId"]
			if Global.WEAPONS.has(wid):
				return Global.WEAPONS[wid]
		if selection.has("Name"):
			return _lookup_weapon(selection["Name"])

	# Numeric IDs as a last-ditch
	var id_str: String = str(selection)
	if Global.WEAPONS.has(id_str):
		return Global.WEAPONS[id_str]

	return {}

func _format_weapon_desc(w: Dictionary) -> String:
	var lines: Array[String] = []

	if w.has("Stat_3_Type") and w.get("Stat_3_Type") != null:
		lines.append(w.get("Stat_1_Type")+": "+str(w.get("Stat_1_Value")))
		lines.append(w.get("Stat_2_Type")+": "+str(w.get("Stat_2_Value")))
		lines.append(w.get("Stat_3_Type")+": "+str(w.get("Stat_3_Value")))
	elif w.has("Stat_2_Type") and w.get("Stat_2_Type") != null:
		lines.append(w.get("Stat_1_Type")+": "+str(w.get("Stat_1_Value")))
		lines.append(w.get("Stat_2_Type")+": "+str(w.get("Stat_2_Value")))
	else:
		lines.append(w.get("Stat_1_Type")+": "+str(w.get("Stat_1_Value")))

	var effect_text: String = str(w.get("Effect", w.get("Passive", "")))
	if effect_text != "" and effect_text != "<null>":
		lines.append("")
		lines.append(effect_text)

	return "\n".join(lines)

# ------- Helpers -------
func _set_text(node: Node, value: String) -> void:
	if node == null:
		return
	if node is RichTextLabel:
		(node as RichTextLabel).text = value
	elif node is Label:
		(node as Label).text = value

func _clear_preview(reason: String = "") -> void:
	_set_text(product_label, "")
	_set_text(region_label, "")
	_set_text(desc, reason)

# --------------------------
# Ingredients (right side)
# --------------------------
func _build_ingredient_rows(product: String) -> void:
	_slot_to_item_id.clear()
	_inventory_snapshot_before = _snapshot_inventory()

	# Hide/reset all rows
	for i in range(MAX_SLOTS):
		var row := _get_row(i)
		if row != null:
			row.visible = false
			_set_row_warning(row, false)
		var hn := _get_have_need(i)
		if hn != null:
			hn.text = "0 / 0"
		var opt := _get_opt(i)
		if opt != null:
			opt.clear()
			for c in opt.get_signal_connection_list("item_selected"):
				if "callable" in c and c["callable"] is Callable:
					opt.disconnect("item_selected", c["callable"])

	# Load requirements
	_slot_requirements = []
	var reqs: Array = _grouped_recipes[product]["requirements"]
	var count: int = min(reqs.size(), MAX_SLOTS)
	for i in range(count):
		var req: Dictionary = reqs[i]
		_slot_requirements.append(req)

		var row2 := _get_row(i)
		if row2 != null:
			var req_label := _get_req_label(i)
			if req_label != null:
				req_label.text = str(req.get("material", "Material"))
			row2.visible = true

		var opt2 := _get_opt(i)
		if opt2 != null:
			_populate_option_for_requirement(opt2, i, req)
			if opt2.is_inside_tree():
				opt2.item_selected.connect(_on_option_selected.bind(i))

	_update_have_need_labels()
	_validate_all_rows()
	_log("[_build_ingredient_rows] product='%s' slots_built=%d" % [product, _slot_requirements.size()])
	_log("[_build_ingredient_rows] product='%s' slots=%d auto_selected=%d snapshot=%d"
	% [_selected_product, _slot_requirements.size(), _slot_to_item_id.size(), _inventory_snapshot_before.size()])


# Fills one requirement dropdown; calls _format_option_label for visible text
func _populate_option_for_requirement(opt: OptionButton, slot_idx: int, req: Dictionary) -> void:
	if opt == null:
		_log("[_populate_option_for_requirement] skipped (opt null)")
		return
	opt.clear()

	var material: String = str(req.get("material", ""))
	var matches: Array = _find_inventory_matches(material)

	opt.add_item("— Select —")
	opt.set_item_metadata(0, null)

	var need_per: int = int(req.get("quantity", 1))
	var need_total: int = need_per * int(qty_spin.value if qty_spin != null else 1)

	var exact_idx := -1
	for item in matches:
		var label := _format_option_label(item, need_total)
		var icon = item.get("Icon", null)

		var idx: int
		if icon is Texture2D:
			idx = opt.item_count
			opt.add_icon_item(icon, label)
		else:
			idx = opt.item_count
			opt.add_item(label)

		opt.set_item_metadata(idx, item.get("Id", null))

		var tip := "Name: %s\nType: %s\nHave: %d\nNeed: %d" % [
			str(item.get("Name","")),
			str(item.get("Type","")),
			_to_int(item.get("Quantity",0)),
			need_total
		]
		opt.set_item_tooltip(idx, tip)

		if str(item.get("Name","")).to_lower() == material.to_lower():
			exact_idx = idx

	if exact_idx != -1:
		opt.select(exact_idx)
		_slot_to_item_id[slot_idx] = opt.get_item_metadata(exact_idx)
		_log("[_populate_option_for_requirement] slot=%d auto-selected exact name id=%s" % [slot_idx, str(_slot_to_item_id[slot_idx])])
	elif matches.size() == 1:
		opt.select(1)
		_slot_to_item_id[slot_idx] = matches[0].get("Id", null)
		_log("[_populate_option_for_requirement] slot=%d auto-selected single match id=%s" % [slot_idx, str(_slot_to_item_id[slot_idx])])
	else:
		opt.select(0)
		_log("[_populate_option_for_requirement] slot=%d no auto-select (matches=%d)" % [slot_idx, matches.size()])

	# NEW: make the right label match the currently selected option (or 0/need if none selected)
	_update_have_need_for_slot(slot_idx, need_total)
	# Right label uses the same numbers as the dropdown
	var selected_have := 0
	if opt.selected > 0:
		var sel_meta = opt.get_selected_metadata()
		var sel_item := _get_inventory_item_by_id(sel_meta)
		if sel_item.size() > 0:
			selected_have = _to_int(sel_item.get("Quantity", 0))
	var hn := _get_have_need(slot_idx)
	if hn != null:
		hn.text = "%d / %d" % [selected_have, need_total]


func _update_have_need_for_slot(slot_idx: int, need_total: int) -> void:
	var have := 0
	var opt := _get_opt(slot_idx)
	if opt != null and opt.selected > 0:
		var meta = opt.get_selected_metadata()
		var item := _get_inventory_item_by_id(meta)
		if item.size() > 0:
			have = _to_int(item.get("Quantity", 0))
	var hn := _get_have_need(slot_idx)
	if hn != null:
		hn.text = "%d / %d" % [have, need_total]


# Shows exactly which item is being offered in the dropdown.
# Example: "Water 1-Star Gem — (x12 have; need 6)" or with type: "Sea Ganoderma [Plant] — (x4 have; need 2)"
func _format_option_label(item: Dictionary, need_total: int) -> String:
	var name_str := str(item.get("Name", "Unknown"))
	var type_str := str(item.get("Type", "")).strip_edges()
	var have := _to_int(item.get("Quantity", 0))

	# If Type is useful to distinguish items with same name, include it in brackets.
	var head := name_str if type_str == "" else "%s [%s]" % [name_str, type_str]
	return "%s — (x%d have; need %d)" % [head, have, need_total]

func _on_option_selected(_index: int, slot_idx: int) -> void:
	var opt := _get_opt(slot_idx)
	if opt == null:
		return
	var meta = opt.get_selected_metadata()
	if meta == null:
		_slot_to_item_id.erase(slot_idx)
	else:
		_slot_to_item_id[slot_idx] = meta

	# Same vars as dropdown: have & need_total
	var have := 0
	if opt.selected > 0:
		var item := _get_inventory_item_by_id(meta)
		if item.size() > 0:
			have = _to_int(item.get("Quantity", 0))

	var need_per := int(_slot_requirements[slot_idx].get("quantity", 1))
	var need_total := need_per * int(qty_spin.value if qty_spin != null else 1)
	var hn := _get_have_need(slot_idx)
	if hn != null:
		hn.text = "%d / %d" % [have, need_total]

	# keep your existing behavior
	_validate_all_rows()
	_refresh_confirm_enabled()
	_log("[_on_option_selected] slot=%d item_id=%s" % [slot_idx, str(meta)])

func _on_qty_changed(_v: float) -> void:
	for i in range(_slot_requirements.size()):
		var opt := _get_opt(i)
		if opt == null: 
			continue

		var have := 0
		if opt.selected > 0:
			var meta = opt.get_selected_metadata()
			var item := _get_inventory_item_by_id(meta)
			if item.size() > 0:
				have = _to_int(item.get("Quantity", 0))

		var need_per := int(_slot_requirements[i].get("quantity", 1))
		var need_total := need_per * int(qty_spin.value if qty_spin != null else 1)

		var hn := _get_have_need(i)
		if hn != null:
			hn.text = "%d / %d" % [have, need_total]

		# (optional) also refresh dropdown item texts so "...need N" changes visibly
		var opt_btn := opt
		for idx in range(1, opt_btn.item_count):
			var id_meta = opt_btn.get_item_metadata(idx)
			var it = _get_inventory_item_by_id(id_meta)
			if it.size() > 0:
				opt_btn.set_item_text(idx, _format_option_label(it, need_total))

	_validate_all_rows()
	_refresh_confirm_enabled()


func _update_have_need_labels() -> void:
	for i in range(_slot_requirements.size()):
		var opt := _get_opt(i)
		if opt == null:
			continue
		var need_per2: int = int(_slot_requirements[i].get("quantity", 1))
		var need_total2: int = need_per2 * int(qty_spin.value if qty_spin != null else 1)
		for idx in range(1, opt.item_count):
			var id_meta = opt.get_item_metadata(idx)
			var item = _get_inventory_item_by_id(id_meta)
			if item.size() > 0:
				opt.set_item_text(idx, _format_option_label(item, need_total2))

	# Refresh dropdown item texts to reflect current "need"
	for i in range(_slot_requirements.size()):
		var opt := _get_opt(i)
		if opt == null:
			continue
		var need_per2: int = int(_slot_requirements[i].get("quantity", 1))
		var need_total2: int = need_per2 * int(qty_spin.value if qty_spin != null else 1)
		for idx in range(1, opt.item_count):
			var id_meta = opt.get_item_metadata(idx)
			var item = _get_inventory_item_by_id(id_meta)
			if item.size() > 0:
				opt.set_item_text(idx, _format_option_label(item, need_total2))
	_log("[_update_have_need_labels] updated %d rows" % _slot_requirements.size())

func _validate_all_rows() -> void:
	var warnings: int = 0
	for i in range(_slot_requirements.size()):
		var row := _get_row(i)
		if row == null:
			continue
		var enough: bool = _has_enough_for_slot(i)
		_set_row_warning(row, not enough)
		if not enough:
			warnings += 1
	_log("[_validate_all_rows] checked=%d warnings=%d" % [_slot_requirements.size(), warnings])

func _set_row_warning(row: HBoxContainer, warn: bool) -> void:
	if row == null:
		_log("[_set_row_warning] skipped (row null)")
		return
	row.modulate = Color(0.8, 0.3, 0.3, 1.0) if warn else Color(1, 1, 1, 1)
	_log("[_set_row_warning] warn=%s" % str(warn))

func _refresh_confirm_enabled() -> void:
	var ok: bool = true
	if _selected_product == "":
		ok = false
	if target_select == null or target_select.selected < 0:
		ok = false
	for i in range(_slot_requirements.size()):
		if not _slot_to_item_id.has(i) or not _has_enough_for_slot(i):
			ok = false
			break
	if confirm_btn != null:
		confirm_btn.disabled = not ok
	_log("[_refresh_confirm_enabled] enabled=%s" % str(ok))

# --------------------------
# Inventory / Matching
# --------------------------
func _has_enough_for_slot(slot_idx: int) -> bool:
	var need_per: int = int(_slot_requirements[slot_idx].get("quantity", 1))
	var qty_total: int = need_per * int(qty_spin.value if qty_spin != null else 1)
	var have: int = _get_selected_item_quantity(slot_idx)
	var enough: bool = have >= qty_total
	_log("[_has_enough_for_slot] slot=%d have=%d need=%d -> %s" % [slot_idx, have, qty_total, str(enough)])
	return enough

func _get_selected_item_quantity(slot_idx: int) -> int:
	if not _slot_to_item_id.has(slot_idx):
		_log("[_get_selected_item_quantity] slot=%d no selection" % slot_idx)
		return 0
	var item = _get_inventory_item_by_id(_slot_to_item_id[slot_idx])
	if item.size() == 0:
		_log("[_get_selected_item_quantity] slot=%d item missing" % slot_idx)
		return 0
	var qty: int = int(item.get("Quantity", 0))
	_log("[_get_selected_item_quantity] slot=%d qty=%d" % [slot_idx, qty])
	return qty

func _get_inventory_item_by_id(item_id) -> Dictionary:
	var inv = _get_inventory_array()
	for it in inv:
		if it.get("Id", null) == item_id:
			_log("[_get_inventory_item_by_id] found id=%s" % str(item_id))
			return it
	_log("[_get_inventory_item_by_id] not found id=%s" % str(item_id))
	return {}

func _find_inventory_matches(material_or_type: String) -> Array:
	var inv = _get_inventory_array()
	var out: Array = []
	var needle = material_or_type.strip_edges().to_lower()
	for it in inv:
		var nm = str(it.get("Name", "")).to_lower()
		var tp = str(it.get("Type", "")).to_lower()
		var have = int(it.get("Quantity", 0))
		# Accept exact Name, exact Type, or Type containing needle (e.g., "1-Star Gem" matches "Water 1-Star Gem")
		if have > 0 and (nm == needle or tp == needle or (needle != "" and tp.find(needle) != -1)):
			out.append(it)
	_log("[_find_inventory_matches] '%s' -> %d matches" % [material_or_type, out.size()])
	return out


# Normalize many possible field names so we always end with {Id, Name, Type, Quantity, Icon}
func _normalize_inventory_item(raw: Dictionary, key = null) -> Dictionary:
	var id = raw.get("Id", key)
	var name = str(
		raw.get("Name",
		raw.get("ItemName",
		raw.get("Material",
		raw.get("Product",
		raw.get("DisplayName", ""))))))
	var typ = str(
		raw.get("Type",
		raw.get("Material_Type",
		raw.get("Category",
		raw.get("Kind",
		raw.get("Subtype", ""))))))
	var qty = _to_int(
		raw.get("Quantity",
		raw.get("Qty",
		raw.get("Count",
		raw.get("Owned",
		raw.get("Amount", 0))))))

	var icon = raw.get("Icon", raw.get("Image", raw.get("IconTexture", null)))
	return {"Id": id, "Name": name, "Type": typ, "Quantity": qty, "Icon": icon}


func _to_int(v) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)  # truncates toward zero
	if typeof(v) == TYPE_STRING:
		return String(v).to_int()  # returns 0 if not a number
	return 0

func _get_inventory_array() -> Array:
	if "CHARACTER_ITEMS" in Global:
		inv = Global.CHARACTER_ITEMS
		# Case A: already an array
		if inv is Array:
			var arr: Array = []
			for it in inv:
				if it is Dictionary:
					arr.append(_normalize_inventory_item(it, it.get("Id", null)))
			_log("[_get_inventory_array] array->norm size=%d" % arr.size())
			return arr
		# Case B: dictionary of id -> item
		if inv is Dictionary:
			var arr2: Array = []
			for k in inv.keys():
				var it = inv[k]
				if it is Dictionary and it.get("Owner") == Global.ACTIVE_USER_NAME:
					arr2.append(_normalize_inventory_item(it, k))
			_log("[_get_inventory_array] dict->norm size=%d" % arr2.size())
			return arr2
	_log("[_get_inventory_array] empty (no Global.INVENTORY or wrong shape)")
	return []

func _snapshot_inventory() -> Dictionary:
	var snap: Dictionary = {}
	var arr = _get_inventory_array()
	for it in arr:
		var iid = it.get("Id", null)
		if iid != null:
			snap[iid] = int(it.get("Quantity", 0))
	_log("[_snapshot_inventory] entries=%d (inv_seen=%d)" % [snap.size(), arr.size()])
	return snap


func update_preview(selected_item) -> void:
	var role = _get_active_role()
	if role == "Blacksmith":
		_populate_blacksmith_preview(selected_item)
	else:
		_populate_artisan_preview(selected_item)
# helpers (put these near the top of your script once)
func _as_int_id(v) -> int:
	if typeof(v) == TYPE_INT: return v
	if typeof(v) == TYPE_FLOAT: return int(v)
	if typeof(v) == TYPE_STRING: return String(v).to_int()  # "79.0" -> 79
	return 0

func _as_int(v) -> int:
	if typeof(v) == TYPE_INT: return v
	if typeof(v) == TYPE_FLOAT: return int(v)
	if typeof(v) == TYPE_STRING: return String(v).to_int()
	return 0
# --------------------------
# Confirm
# --------------------------
func _on_confirm_pressed() -> void:
	if confirm_btn != null and confirm_btn.disabled: return
	if _selected_product == "": return

	var qty_to_make: int = _as_int(qty_spin.value if qty_spin != null else 1)
	var target: String = target_select.get_item_text(target_select.selected) \
		if target_select != null and target_select.selected >= 0 else "Unknown"

	# Build consumption plan (normalize IDs)
	var consumption: Array = []
	for i in range(_slot_requirements.size()):
		var need_per := _as_int(_slot_requirements[i].get("quantity", 1))
		var total_need := need_per * qty_to_make
		var raw_id = _slot_to_item_id.get(i, null)
		var rid := _as_int_id(raw_id)            #  <-- ensure integer PK
		consumption.append({ "id": rid, "take": total_need })

	# Decrement inventory -> build updates with INT id and INT value
	var updates: Array = []
	for c in consumption:
		var rid = c["id"]                       # int
		# CHARACTER_ITEMS keys may be strings: access by string key safely
		var key = str(rid)
		print (consumption)
		var current_amount = _as_int(Global.CHARACTER_ITEMS[str(float(rid))].get("Quantity", 0))
		var new_qty = current_amount - _as_int(c["take"])
		updates.append({
			"table": "Character_Items",
			"record_id": rid,                    # <-- int, not "79.0"
			"field": "Quantity",
			"value": _as_int(new_qty)            # <-- int, not 5.0
		})

	# Grant product (normalize product_record and quantities to int)
	var has_item := false
	var product_amount := 0
	var product_record := 0
	if _get_active_role() == "Artisan":
		for item_key in Global.CHARACTER_ITEMS:
			var it = Global.CHARACTER_ITEMS[item_key]
			if it.get("Name") == _selected_product and it.get("Owner") == target:
				has_item = true
				product_amount = _as_int(it.get("Quantity", 0))
				product_record = _as_int_id(item_key)    # <-- normalize key to int
				break

		if has_item:
			updates.append({
				"table": "Character_Items",
				"record_id": product_record,            # int
				"field": "Quantity",
				"value": _as_int(qty_to_make + product_amount)  # int
			})
		else:
			var Type = ""
			var Rarity = ""
			var Description = ""
			for item in Global.ITEMS.values():
				if item.get("Item") == _selected_product:
					Type = str(item.get("Type", ""))
					Rarity = str(item.get("Rarity", ""))
					Description = str(item.get("Description", ""))
			Global.Insert(
				"Character_Items",
				["Owner","Name","Type","Rarity","Quantity","Description"],
				[target, _selected_product, Type, Rarity, _as_int(qty_to_make), Description]
			)
	else:
		for item_key in Global.CHARACTER_WEAPONS:
			var it = Global.CHARACTER_WEAPONS[item_key]
			if it.get("Weapon") == _selected_product and it.get("Owner") == target:
				has_item = true
				product_amount = _as_int(it.get("Quantity", 0))
				product_record = _as_int_id(item_key)    # <-- normalize key to int
				break

		if has_item:
			updates.append({
				"table": "Character_Weapons",
				"record_id": product_record,            # int
				"field": "Quantity",
				"value": _as_int(qty_to_make + product_amount)  # int
			})
		else:
			var Type = ""
			var Rarity = ""
			var Effect = ""
			var Region = ""
			var Stat1Type = ""
			var Stat2Type = ""
			var Stat3Type = ""
			var Stat1Value = ""
			var Stat2Value = ""
			var Stat3Value = ""
			for item in Global.WEAPONS.values():
				if item.get("Name") == _selected_product:
					Type = str(item.get("Weapon_Type", ""))
					Rarity = str(item.get("Rarity", ""))
					if item.get("Effect", "") != null:
						Effect = str(item.get("Effect", ""))
					else:
						Effect = ""
					Region = str(item.get("Region", ""))
					Stat1Type = str(item.get("Stat_1_Type", ""))
					Stat1Value =  (item.get("Stat_1_Value", ""))
					if item.get("Stat_2_Type") != null:
						Stat2Type = str(item.get("Stat_2_Type", ""))
						Stat2Value =  (item.get("Stat_2_Value", ""))
					else:
						Stat2Type = null
						Stat2Value = null
					if item.get("Stat_3_Type") != null:
						Stat3Type = str(item.get("Stat_3_Type", ""))
						Stat3Value =  (item.get("Stat_3_Value", ""))
					else:
						Stat3Type = null
						Stat3Value = null
					
			Global.Insert(
				"Character_Weapons",
				["Owner","Weapon","Type","Rarity","Region","Quantity","Effect","Stat_1_Type","Stat_2_Type","Stat_3_Type","Stat_1_Value","Stat_2_Value","Stat_3_Value","Refinement","Equipped"],
				[target, _selected_product, Type, Rarity,Region, _as_int(qty_to_make), Effect,Stat1Type,Stat2Type,Stat3Type,Stat1Value,Stat2Value,Stat3Value,0,false]
			)
			print ([target, _selected_product, Type, Rarity,Region, _as_int(qty_to_make), Effect,Stat1Type,Stat2Type,Stat3Type,Stat1Value,Stat2Value,Stat3Value,0,false])
		

	# Ship updates if any
	if updates.size() > 0:
		Global.Update_Records(updates)



	# Log per your rule (confirm buttons must log)
	if "Log" in Global:
		var old_values: Dictionary = {"inventory_before": _inventory_snapshot_before.duplicate()}
		var new_values: Dictionary = {
			"crafted_product": _selected_product,
			"quantity": qty_to_make,
			"target": target,
			"consumed": consumption
		}
		var metadata: Dictionary = {"screen": "CraftingMenu"}
		Global.Log("crafting", "Craft %s" % _selected_product, "Recipe", _selected_product, old_values, new_values, metadata, "success", "audit")

	_show_toast("Crafted %d × %s for %s" % [qty_to_make, _selected_product, target])
	_update_have_need_labels()
	_validate_all_rows()
	_refresh_confirm_enabled()
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

func _fallback_decrement_inventory(item_id: String, amount: int) -> bool:
	var inv = _get_inventory_array()
	for it in inv:
		if it.get("Id", "") == item_id:
			var have: int = int(it.get("Quantity", 0))
			if have < amount:
				_log("[_fallback_decrement_inventory] not enough id=%s have=%d need=%d" % [item_id, have, amount])
				return false
			it["Quantity"] = have - amount
			_log("[_fallback_decrement_inventory] decremented id=%s by %d -> %d" % [item_id, amount, int(it["Quantity"])])
			return true
	_log("[_fallback_decrement_inventory] id not found=%s" % item_id)
	return false


# --------------------------
# Sets Icon
# --------------------------
func _assign_icon(item):
	var HyphenName = item.to_lower().replace(" ","-")
	if _get_active_role() == "Artisan":
		$HSplit/RightPanel/RightVBox/TopPreview/TopHBox/Icon.texture = load(str("res://UI/Food Icons/"+HyphenName+".png"))
	else:
		$HSplit/RightPanel/RightVBox/TopPreview/TopHBox/Icon.texture = load(str("res://UI/Weapon Icons/"+HyphenName+".png"))



# --------------------------
# Feedback
# --------------------------
func _show_toast(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	l.modulate = Color(1, 1, 1, 0)
	add_child(l)
	l.global_position = Vector2(40, 40)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.3)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.finished.connect(l.queue_free)
	_log("[_show_toast] '%s'" % msg)


func _on_button_pressed() -> void:
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()
	pass # Replace with function body.
