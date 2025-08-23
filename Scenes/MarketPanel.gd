extends Control

@onready var ModeTabs: TabBar = $HeaderBar/ModeTabs
@onready var Shops: ItemList = $Body/ShopList/Shops
@onready var Items: ItemList = $Body/ItemListPanel/Items
@onready var NameLabel: Label = $Body/Details/Contents/NameLabel
@onready var InfoText: RichTextLabel = $Body/Details/Contents/InfoText
@onready var Quantity: SpinBox = $Body/Details/Contents/QuantityRow/Quantity
@onready var PricePreview: Label = $Body/Details/Contents/QuantityRow/PricePreview
@onready var Confirm: Button = $Body/Details/Contents/Confirm
@onready var Icon = $Body/Details/Contents/Icon

var _current_mode_buy = true
var _current_shop_name = "Weapons"
var _selected_index = -1
var _selected_entry: Dictionary = {}

#Market.Set_Daily_Luck(Global.DAILY_LUCK) 
#Market.Refresh_Stock(Global.Current_Region)
func _ready() -> void:
	Market.Refresh_Stock(Global.Current_Region)
	ModeTabs.clear_tabs()
	ModeTabs.add_tab("Buy")
	ModeTabs.add_tab("Sell")
	ModeTabs.current_tab = 0
	ModeTabs.tab_selected.connect(_on_mode_changed)

	_populate_shop_list()
	Shops.item_selected.connect(_on_shop_selected)
	Items.item_selected.connect(_on_item_selected)
	Quantity.value_changed.connect(_on_quantity_changed)
	Confirm.pressed.connect(_on_confirm)

	_reset_details()
	_refresh_items()

func _on_mode_changed(tab: int) -> void:
	_current_mode_buy = (tab == 0)
	if _current_mode_buy:
		Shops.visible = true
		_populate_shop_list()
		_current_shop_name = "Weapons"
	else:
		Shops.visible = false
	_items_clear_and_reload()

func _populate_shop_list() -> void:
	Shops.clear()
	var names = ["Weapons","Artifacts","Consumables","Elemental_Gems","Artisan","Blacksmith"]
	for n in names:
		Shops.add_item(n)
	Shops.select(0)
	_current_shop_name = "Weapons"

func _on_shop_selected(index: int) -> void:
	_current_shop_name = Shops.get_item_text(index)
	_items_clear_and_reload()

func _items_clear_and_reload() -> void:
	Items.clear()
	_reset_details()
	_refresh_items()

func _refresh_items() -> void:
	Items.clear()
	var rows: Array = []
	if _current_mode_buy:
		rows = Market.Get_Shop(_current_shop_name)
		# Filter out any zero-quantity entries to avoid stale selections
		var filtered: Array = []
		for r in rows:
			var rq = 1
			if r.has("Quantity") and r["Quantity"] != null:
				rq = int(r["Quantity"])
			if rq > 0:
				filtered.append(r)
		rows = filtered
	else:
		rows = _gather_sell_inventory_rows()

	var i = 0
	while i < rows.size():
		var r: Dictionary = rows[i]
		var label = _format_list_row_label(r)
		Items.add_item(label)
		i += 1




# ---- Local value lookup helpers (fallbacks) ----
func _get_item_value_by_name(item_name: String) -> int:
	if Market.has_method("_lookup_item_value"):
		return int(Market._lookup_item_value(item_name))
	return 0

func _weapon_base_value_from_recipes(weapon_name: String) -> int:
	# If your project has Global.CRAFTING_RECIPES[{ "Weapon": name, "Materials": [{"Item":name,"Qty":n}, ...]}]
	if "CRAFTING_RECIPES" in Global and Global.CRAFTING_RECIPES != null:
		for rid in Global.CRAFTING_RECIPES.keys():
			var rec: Dictionary = Global.CRAFTING_RECIPES[rid]
			if rec.get("Weapon") == weapon_name:
				var mats: Array = rec.get("Materials", [])
				var total := 0
				for m in mats:
					var iname = m.get("Item")
					var iqty = int(m.get("Qty", 1))
					total += _get_item_value_by_name(iname) * iqty
				return int(total * 2) # per rubric
	return -1

func _weapon_base_value_safe(w: Dictionary) -> int:
	# Prefer Market singleton methods if they exist
	if Market.has_method("_lookup_weapon_value"):
		return int(Market._lookup_weapon_value(w))
	if Market.has_method("Lookup_Weapon_Value"):
		return int(Market.Lookup_Weapon_Value(w))
	if Market.has_method("Get_Weapon_Value"):
		return int(Market.Get_Weapon_Value(w))
	# Try crafting recipe fallback
	var nm = w.get("Weapon", w.get("Name",""))
	var via_recipe = _weapon_base_value_from_recipes(nm)
	if via_recipe >= 0:
		return via_recipe
	# Rarity fallback (adjust as needed)
	var rarity = str(w.get("Rarity","")).to_lower()
	var map := {
		"common": 75,
		"uncommon": 500,
		"rare": 1000,
		"epic": 2000,
		"legendary": 4000
	}
	if rarity in map:
		return int(map[rarity])
	return int(w.get("Value", 0))


func _gather_sell_inventory_rows() -> Array:
	var out: Array = []
	# --- Items ---
	for id in Global.CHARACTER_ITEMS.keys():
		var row: Dictionary = Global.CHARACTER_ITEMS[id]
		if row.get("Owner") == Global.ACTIVE_USER_NAME:
			var qty = 0
			if "Quantity" in row and row["Quantity"] != null:
				qty = int(row["Quantity"])
			if qty <= 0:
				continue
			var name = row.get("Name")
			var value = row.get("Value", null)
			if value == null or int(value) == 0:
				value = _get_item_value_by_name(name)
			var entry: Dictionary = row.duplicate(true)
			entry["Quantity"] = qty
			entry["Name"] = name
			entry["Value"] = int(value)
			entry["__table"] = "Character_Items"
			entry["__record_id"] = id
			entry["__priority"] = 0
			out.append(entry)
	# --- Weapons ---
	if "CHARACTER_WEAPONS" in Global and Global.CHARACTER_WEAPONS != null:
		for wid in Global.CHARACTER_WEAPONS.keys():
			var w: Dictionary = Global.CHARACTER_WEAPONS[wid]
			if w.get("Owner") == Global.ACTIVE_USER_NAME and w.get("Quantity") > 0:
				var equipped = bool(w.get("Equipped", false) if w.get("Equipped") != null else false)
				if equipped:
					continue
				var name_w = w.get("Weapon", w.get("Name", "Weapon"))
				var value_w = int(w.get("Value", 0))
				if value_w == 0:
					value_w = _weapon_base_value_safe(w)
				var entry_w: Dictionary = w.duplicate(true)
				entry_w["Name"] = name_w
				entry_w["Quantity"] = w.get("Quantity")
				entry_w["Value"] = int(value_w)
				entry_w["__table"] = "Character_Weapons"
				entry_w["__record_id"] = wid
				entry_w["__priority"] = 1
				out.append(entry_w)
	# --- Artifacts ---
	if "CHARACTER_ARTIFACTS" in Global and Global.CHARACTER_ARTIFACTS != null:
		for aid in Global.CHARACTER_ARTIFACTS.keys():
			var a: Dictionary = Global.CHARACTER_ARTIFACTS[aid]
			if a.get("Owner") == Global.ACTIVE_USER_NAME:
				var equipped_a = bool(a.get("Equipped", false) if a.get("Equipped") != null else false)
				if equipped_a:
					continue
				var set_name = a.get("Artifact_Set", a.get("Set", "Artifact"))
				var type_name = a.get("Type", "")
				var label = "%s — %s" % [set_name, type_name] if type_name != "" else set_name
				var value_a = int(a.get("Value", 0))
				if value_a == 0:
					value_a = Market._price_artifact(a)
				var entry_a: Dictionary = a.duplicate(true)
				entry_a["Name"] = label
				entry_a["Quantity"] = 1
				entry_a["Value"] = int(value_a)
				entry_a["__table"] = "Character_Artifacts"
				entry_a["__record_id"] = aid
				entry_a["__priority"] = 2
				out.append(entry_a)
	# Sort: Items -> Weapons -> Artifacts, then Name (case-insensitive)
	out.sort_custom(func(a, b):
		if a["__priority"] == b["__priority"]:
			return a["Name"].nocasecmp_to(b["Name"]) < 0
		return a["__priority"] < b["__priority"]
	)
	return out
func _format_list_row_label(r: Dictionary) -> String:
	if _current_mode_buy:
		if _current_shop_name == "Weapons":
			return "[%s] [%s] - %s  (Qty %d) - %d" % [ r.get("Rarity"),r.get("Type"), r.get("Weapon"), r.get("Quantity", 1), r.get("Value", 0)]
		elif _current_shop_name == "Artifacts":
			return "%s — %s  (Qty %d) - %d" % [r.get("Artifact_Set"), r.get("Type"), r.get("Quantity", 1), r.get("Value", 0)]
		else:
			return "%s  (Qty %d) - %d" % [r.get("Name"), r.get("Quantity", 0), r.get("Value", 0)]
	else:
		# SELL MODE
		var tbl = r.get("__table", "")
		if tbl == "Character_Weapons":
			var rarity = r.get("Rarity", "?")
			return "[%s] %s" % [rarity, r.get("Name")]
		elif tbl == "Character_Artifacts":
			return "%s" % [r.get("Name")]
		else:
			# items
			return "%s  (You: x%d)" % [r.get("Name"), r.get("Quantity", 0)]
func _on_item_selected(index: int) -> void:
	_selected_index = index
	var rows = []
	if _current_mode_buy:
		rows = Market.Get_Shop(_current_shop_name)
	else:
		rows = _gather_sell_inventory_rows()

	if index < 0 or index >= rows.size():
		_reset_details()
		return

	_selected_entry = rows[index].duplicate(true)
	_show_details(_selected_entry)


func _show_details(r: Dictionary) -> void:
	if _current_mode_buy:
		if _current_shop_name == "Weapons":
			NameLabel.text = "%s [%s]" % [r.get("Weapon"), r.get("Rarity")]
			InfoText.text = _weapon_info_text(r)
			Quantity.min_value = 1
			Quantity.max_value = r.get("Quantity", 1)
			Quantity.value = 1
		elif _current_shop_name == "Artifacts":
			NameLabel.text = "%s — %s" % [r.get("Artifact_Set"), r.get("Type")]
			InfoText.text = _artifact_info_text(r)
			Quantity.min_value = 1
			Quantity.max_value = r.get("Quantity", 1)
			Quantity.value = 1
		else:
			NameLabel.text = r.get("Name")
			InfoText.text = _item_info_text(r)
			Quantity.min_value = 1
			Quantity.max_value = r.get("Quantity", 0)
			Quantity.value = 1
	else:
		NameLabel.text = r.get("Name")
		InfoText.text = _sell_info_text(r)
		Quantity.min_value = 1
		var maxq = 1
		if r.get("__table", "") == "Character_Items":
			maxq = int(r.get("Quantity", 0) if r.get("Quantity") != null else 0)
			if maxq < 1:
				maxq = 1
		Quantity.max_value = maxq
		Quantity.value = 1

	_update_price_preview()
func _on_quantity_changed(_value: float) -> void:
	_update_price_preview()

func _update_price_preview() -> void:
	if _selected_index < 0:
		PricePreview.text = ""
		return

	var qty = int(Quantity.value)
	var unit_base = int(_selected_entry.get("Value", 0))
	var luck = Market.Get_Daily_Luck()

	if _current_mode_buy:
		var unit_effective = Market._buy_price_with_luck(unit_base, luck)
		var total = unit_effective * qty
		PricePreview.text = "Unit: %d  |  Total: %d" % [unit_effective, total]
	else:
		var total_gain = Market.Price_Sell_Preview(_selected_entry, qty)
		var rate_text = _format_percent(Market._sell_rate_with_luck(luck))
		PricePreview.text = "Rate: %s  |  Offer: %d" % [rate_text, total_gain]

func _format_percent(x: float) -> String:
	return "%d%%" % int(round(x * 100.0))

func _on_confirm() -> void:
	if _selected_index < 0 and _selected_entry.is_empty():
		return

	var qty = int(Quantity.value)

	if _current_mode_buy:
		var ok = Market.Buy_Commit(_current_shop_name, _selected_index, qty)
		if ok:
			_items_clear_and_reload()
			_clear_selection_after_mutation()
	else:
		var gain = Market.Sell_Commit(_selected_entry, qty)
		_remove_sold_from_inventory(_selected_entry, qty)
		_add_mora(gain)
		_items_clear_and_reload()
		_clear_selection_after_mutation()
		# Add 'gain' to your wallet system here if applicable

func _clear_selection_after_mutation() -> void:
	_selected_index = -1
	_selected_entry = {}

	# Godot 4.4.1 ItemList uses deselect_all(); add a safe fallback
	if Items.has_method("deselect_all"):
		Items.deselect_all()
	else:
		var sel: PackedInt32Array = Items.get_selected_items()
		for i in sel:
			if Items.has_method("deselect"):
				Items.deselect(i)
			elif Items.has_method("unselect"):
				Items.unselect(i)

	_reset_details()


func _add_mora(value):
	var new_value = 0
	var party_record_id = Global.Current_Party.get("id")
	var original_mora = Global.Current_Party.get("Mora")
	new_value = (original_mora+value)
	Global.Update_Records([{
			"table": "Party",
			"record_id": int(party_record_id),
			"field": "Mora",
			"value": int(new_value)}])



func _remove_sold_from_inventory(row: Dictionary, qty: int) -> void:
	var tbl = row.get("__table", "Character_Items")
	if tbl == "Character_Items":
		for id in Global.CHARACTER_ITEMS.keys():
			var r: Dictionary = Global.CHARACTER_ITEMS[id]
			if r.get("Owner") == row.get("Owner") and r.get("Name") == row.get("Name"):
				var current_qty = 0
				if "Quantity" in r and r["Quantity"] != null:
					current_qty = int(r["Quantity"])
				var new_qty = max(0, current_qty - qty)
				r["Quantity"] = new_qty
				var updates = [{
					"table": "Character_Items",
					"record_id": int(id),
					"field": "Quantity",
					"value": new_qty
				}]
				Global.Update_Records(updates)
				break
	elif tbl == "Character_Weapons":
		for id in Global.CHARACTER_WEAPONS.keys():
			var w: Dictionary = Global.CHARACTER_WEAPONS[id]
			if w.get("Owner") == row.get("Owner") and (w.get("Weapon") == row.get("Weapon") or w.get("Weapon") == row.get("Name")):
				var current_qty = 0
				if "Quantity" in w and w["Quantity"] != null:
					current_qty = int(w["Quantity"])
				var new_qty = max(0, current_qty - qty)
				w["Quantity"] = new_qty
				var updates = [{
					"table": "Character_Weapons",
					"record_id": int(id),
					"field": "Quantity",
					"value":  new_qty # clear owner to remove from inventory
				}]
				Global.Update_Records(updates)
				break
	elif tbl == "Character_Artifacts":
		for id in Global.CHARACTER_ARTIFACTS.keys():
			var a: Dictionary = Global.CHARACTER_ARTIFACTS[id]
			var label = "%s — %s" % [a.get("Artifact_Set", a.get("Set", "")), a.get("Type", "")]
			if a.get("Owner") == row.get("Owner") and (row.get("Name") == label):
				var updates = [{
					"table": "Character_Artifacts",
					"record_id": int(id),
					"Column": "Owner",
					"Values": ""  # clear owner
				}]
				Global.Update_Records(updates)
				break

func _reset_details() -> void:
	NameLabel.text = ""
	InfoText.text = ""
	Quantity.min_value = 0
	Quantity.max_value = 0
	Quantity.value = 0
	PricePreview.text = ""
	_selected_index = -1
	_selected_entry = {}

# --------------------------
# Info text helpers
# --------------------------
func _weapon_info_text(r: Dictionary) -> String:
	var hyphen = r.get("Weapon").to_lower().replace(" ","-")+".png"
	Icon.texture = load("res://UI/Weapon Icons/"+hyphen)
	var lines: Array = []
	lines.append("Region: %s" % r.get("Region"))
	lines.append("Type: %s" % r.get("Type"))
	if r.get("Effect") != null:
		lines.append("Effect: %s" % r.get("Effect"))
	lines.append("Stats:")
	lines.append(" - %s: %s" % [r.get("Stat_1_Type"), str(r.get("Stat_1_Value"))])
	if r.get("Stat_2_Type") != null:
		lines.append(" - %s: %s" % [r.get("Stat_2_Type"), str(r.get("Stat_2_Value"))])
	if r.get("Stat_3_Type") != null:
		lines.append(" - %s: %s" % [r.get("Stat_3_Type"), str(r.get("Stat_3_Value"))])
	lines.append("Listed Value: %d" % r.get("Value", 0))
	lines.append("Your luck may change the final price.")
	return String("\n").join(lines)

func _artifact_info_text(r: Dictionary) -> String:
	var type_short
	match r.get("Type"):
		"Flower of Life":
			type_short = "flower"
		"Feather of Death":
			type_short = "plume"
		"Sands of Time":
			type_short = "sands"
		"Goblet of Space":
			type_short = "goblet"
		"Circlet of Principles":
			type_short = "circlet"
	var hyphen = str(r.get("Artifact_Set").to_lower().replace(" ","-")+"-"+type_short+".png")
	Icon.texture = load("res://UI/Artifact Icons/"+hyphen)
	var lines: Array = []
	lines.append("Set: %s" % r.get("Artifact_Set"))
	lines.append("Type: %s" % r.get("Type"))
	lines.append("Stats:")
	lines.append(" - %s: %s" % [r.get("Stat_1_Type"), str(r.get("Stat_1_Value"))])
	if r.get("Stat_2_Type") != null:
		lines.append(" - %s: %s" % [r.get("Stat_2_Type"), str(r.get("Stat_2_Value"))])
	lines.append("Rarity: %s" % str(r.get("Rarity")))
	lines.append("Listed Value: %d" % r.get("Value", 0))
	lines.append("Your luck may change the final price.")
	return String("\n").join(lines)

func _item_info_text(r: Dictionary) -> String:
	var lines: Array = []
	var hyphen = r.get("Name").to_lower().replace(" ","-")+".png"
	Icon.texture = load("res://UI/Item Icons/"+hyphen)
	lines.append("Type: %s" % r.get("Type"))
	lines.append("Rarity: %s" % r.get("Rarity"))
	lines.append("Region: %s" % r.get("Region"))
	var desc = r.get("Description", null)
	if desc != null:
		lines.append("")
		lines.append(desc)
	lines.append("")
	lines.append("Listed Value: %d" % r.get("Value", 0))
	lines.append("Your luck may change the final price.")
	return String("\n").join(lines)

func _sell_info_text(r: Dictionary) -> String:
	var lines: Array = []
	lines.append("You own: x%d" % r.get("Quantity", 0))
	lines.append("Base Value: %d" % r.get("Value", 0))
	if r.get("__table") == "Character_Weapons":
		var hyphen = r.get("Name").to_lower().replace(" ","-")+".png"
		Icon.texture = load("res://UI/Weapon Icons/"+hyphen)
		var t = Global.CHARACTER_WEAPONS[r.get("__record_id")]
		lines.append("Region: %s" % t.get("Region"))
		lines.append("Type: %s" % t.get("Type"))
		if t.get("Effect") != null:
			lines.append("Effect: %s" % t.get("Effect"))
		lines.append("Stats:")
		lines.append(" - %s: %s" % [t.get("Stat_1_Type"), str(t.get("Stat_1_Value"))])
		if r.get("Stat_2_Type") != null:
			lines.append(" - %s: %s" % [t.get("Stat_2_Type"), str(t.get("Stat_2_Value"))])
		if t.get("Stat_3_Type") != null:
			lines.append(" - %s: %s" % [t.get("Stat_3_Type"), str(t.get("Stat_3_Value"))])
	elif r.get("__table") == "Character_Artifacts":
		var t = Global.CHARACTER_ARTIFACTS[r.get("__record_id")]
		lines.append("Set: %s" % t.get("Artifact_Set"))
		lines.append("Type: %s" % t.get("Type"))
		lines.append("Stats:")
		lines.append(" - %s: %s" % [t.get("Stat_1_Type"), str(t.get("Stat_1_Value"))])
		if t.get("Stat_2_Type") != null:
			lines.append(" - %s: %s" % [t.get("Stat_2_Type"), str(t.get("Stat_2_Value"))])
		var type_short
		match t.get("Type"):
			"Flower of Life":
				type_short = "flower"
			"Feather of Death":
				type_short = "plume"
			"Sands of Time":
				type_short = "sands"
			"Goblet of Space":
				type_short = "goblet"
			"Circlet of Principles":
				type_short = "circlet"
		var hyphen = str(r.get("Artifact_Set").to_lower().replace(" ","-")+"-"+type_short+".png")
		Icon.texture = load("res://UI/Artifact Icons/"+hyphen)
	else:
		var t = Global.CHARACTER_ITEMS[r.get("__record_id")]
		var hyphen = r.get("Name").to_lower().replace(" ","-")+".png"
		if t.get("Type") == "Consumable":
			Icon.texture = load("res://UI/Food Icons/"+hyphen)
		else:
			Icon.texture = load("res://UI/Item Icons/"+hyphen)
		
	lines.append("Sell rate is affected by daily luck.")
	return String("\n").join(lines)


func _on_button_pressed() -> void:
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()
	pass # Replace with function body.
