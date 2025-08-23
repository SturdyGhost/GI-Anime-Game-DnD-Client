extends Node

# --------------------------
# Config
# --------------------------
const BASE_SELL_RATE = 0.40
const SELL_RATE_MIN = 0.15
const SELL_RATE_MAX = 0.50
const PRICE_VARIANCE_PCT = 0.02

const LEGENDARY_WEAPON_COUNT = 2
const EPIC_WEAPON_COUNT = 4
const ARTIFACT_COUNT = 10

const ARTIFACT_TYPES = [
	"Flower of Life",
	"Feather of Death",
	"Sands of Time",
	"Goblet of Space",
	"Circlet of Principles"
]

const STAT_BASE_CHOICES = ["Attack", "Defense", "Health", "Elemental_Mastery"]

const SANDS_EXTRA = {"Energy_Recharge": 0.12}
const GOBLET_EXTRA = {"Universal_Added_Damage_Bonus": 0.10}
const CIRCLET_EXTRA = {"Critical_Damage": 0.10}

const MAG_BUCKETS = [
	{"range": Vector2(0.1, 1.0), "p": 0.40},
	{"range": Vector2(1.0, 1.5), "p": 0.30},
	{"range": Vector2(1.5, 2.0), "p": 0.20},
	{"range": Vector2(2.0, 2.5), "p": 0.10}
]

const STAT_NEGATIVE_P = 0.60
const TWO_STAT_ARTIFACT_P = 0.15
const ARTIFACT_BASE_PRICE_1 = 150
const ARTIFACT_BASE_PRICE_2 = 300

const WEAPON_RARITY_BASE_PRICE = {
	"Common": 75,
	"Uncommon": 500,
	"Rare": 1000,
	"Epic": 2000,
	"Legendary": 4000
}

const REGION_MARKUP_MIN = 0.25
const REGION_MARKUP_MAX = 0.75

enum ShopKind { WEAPONS, ARTIFACTS, CONSUMABLES, ELEMENTAL_GEMS, ARTISAN, BLACKSMITH }

var Stock = {
	"Weapons": [],
	"Artifacts": [],
	"Consumables": [],
	"Elemental_Gems": [],
	"Artisan": [],
	"Blacksmith": []
}

var _rng: RandomNumberGenerator
var _daily_luck: int = 100  # set this from your game each day

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

# --------------------------
# Luck API
# --------------------------
func Set_Daily_Luck(luck_value: int) -> void:
	_daily_luck = luck_value

func Get_Daily_Luck() -> int:
	return _daily_luck

# Sell: base 0.60, +0.01 / 4 luck > 60 (cap 0.70), -0.01 / 2 luck < 50 (floor 0.35)
func _sell_rate_with_luck(luck_value: int) -> float:
	var rate = BASE_SELL_RATE
	if luck_value > 60:
		var steps_up = int(floor(float(luck_value - 60) / 4.0))
		rate += 0.01 * float(steps_up)
	elif luck_value < 50:
		var steps_down = int(floor(float(50 - luck_value) / 2.0))
		rate -= 0.01 * float(steps_down)
	return clamp(rate, SELL_RATE_MIN, SELL_RATE_MAX)

# Buy: +/−1% per step (−1% per 5 above 50; +1% per 2 below 50)
func _buy_price_with_luck(base_value: float, luck_value: int) -> int:
	var multiplier = 1.0
	if luck_value > 50:
		var steps_disc = int(floor(float(luck_value - 50) / 5.0))
		multiplier -= 0.01 * float(steps_disc)
	elif luck_value < 50:
		var steps_mark = int(floor(float(50 - luck_value) / 2.0))
		multiplier += 0.01 * float(steps_mark)
	var out_val = int(round(base_value * multiplier))
	if out_val < 1:
		out_val = 1
	return out_val

# --------------------------
# Public API
# --------------------------
func Refresh_Stock(current_region: String) -> void:
	Stock["Weapons"] = []
	Stock["Artifacts"] = []
	Stock["Consumables"] = []
	Stock["Elemental_Gems"] = []
	Stock["Artisan"] = []
	Stock["Blacksmith"] = []

	_generate_weapons(current_region)
	_generate_artifacts(current_region)
	_generate_consumables(current_region)
	_generate_elemental_gems(current_region)
	_generate_artisan(current_region)
	_generate_blacksmith(current_region)
	_sort_all_shops()
	Apply_Price_Variance()

func Get_Shop(shop_name: String) -> Array:
	if not (shop_name in Stock):
		return []
	return Stock[shop_name]

func Price_Sell_Preview(item_entry: Dictionary, qty: int) -> int:
	var unit_value = int(item_entry.get("Value"))
	var rate = _sell_rate_with_luck(_daily_luck)
	rate += randf_range(-0.02,0.02)
	var total = int(round(unit_value * rate * max(qty, 0)))
	return max(total, 0)

# --------------------------
# BUY COMMIT (DB)
# --------------------------
func Buy_Commit(shop_name: String, entry_index: int, quantity: int) -> bool:
	if not (shop_name in Stock):
		return false
	var items: Array = Stock[shop_name]
	if entry_index < 0 or entry_index >= items.size():
		return false

	var entry: Dictionary = items[entry_index]
	var max_qty: int = int(entry.get("Quantity", 0))
	var buy_qty: int = clamp(quantity, 0, max_qty)
	if buy_qty <= 0:
		return false

	# Artifacts are typically singletons
	if shop_name == "Artifacts":
		buy_qty = min(buy_qty, 1)

	# --- Compute unit price by type ---
	var unit_price: int = 0
	if shop_name == "Weapons":
		# Match preview: use precomputed entry value and apply buy luck modifier
		var base_val: int = int(entry.get("Value", 0))
		unit_price = _buy_price_with_luck(base_val, _daily_luck)
	elif shop_name == "Artifacts":
		unit_price = int(_price_artifact(entry))
	else:
		var base_val: int = int(entry.get("Value", 0))
		if base_val <= 0:
			base_val = int(_lookup_item_value(entry.get("Name")))
		unit_price = int(round(_apply_region_markup(float(base_val), entry.get("Region"), Global.Current_Region)))

	var total_cost: int = unit_price * buy_qty

	# --- Mora check ---
	var original_mora: int = int(Global.Current_Party.get("Mora", 0))
	if original_mora < total_cost:
		return false

	# --- Deduct Mora via Update_Records (and mirror locally for UI) ---
	var new_mora: int = original_mora - total_cost
	var party_record_id = Global.Current_Party.get("id")
	var updates_deduct = [{
		"table": "Party",            # Adjust if your table name differs
		"record_id": int(party_record_id),  # Must be the Party's record id
		"field": "Mora",
		"value": int(new_mora)
	}]
	Global.Update_Records(updates_deduct)
	Global.Current_Party["Mora"] = new_mora  # keep UI in sync

	# --- Perform inventory commit ---
	var ok: bool = false
	if shop_name == "Weapons":
		ok = _commit_buy_weapon(entry, buy_qty)
	elif shop_name == "Artifacts":
		ok = _commit_buy_artifact(entry)
	else:
		ok = _commit_buy_item(entry, buy_qty)

	# --- Adjust shop stock or refund Mora on failure ---
	if ok:
		entry["Quantity"] = max(0, int(entry.get("Quantity", 0)) - buy_qty)
		if entry["Quantity"] <= 0:
			items.remove_at(entry_index)
	else:
		# Refund Mora via Update_Records (and mirror locally)
		var updates_refund = [{
			"table": "Party",
			"record_id": int(party_record_id),
			"field": "Mora",
			"value": int(original_mora)
		}]
		Global.Update_Records(updates_refund)
		Global.Current_Party["Mora"] = original_mora

	return ok

# --------------------------
# SELL COMMIT (DB)
# --------------------------
func Sell_Commit(inventory_row: Dictionary, sell_qty: int) -> int:
	var unit_value = int(inventory_row.get("Value"))
	var qty = sell_qty
	var rate = _sell_rate_with_luck(_daily_luck)
	rate += randf_range(-0.02,0.02)
	return int(round(unit_value * rate * qty))

# --------------------------
# Generation: Weapons
# --------------------------
func _generate_weapons(current_region: String) -> void:
	var wep_list: Array = []
	for id in Global.WEAPONS.keys():
		var w: Dictionary = Global.WEAPONS[id]
		wep_list.append(w)

	var legendary_pool: Array = []
	var epic_pool: Array = []
	var other_rarity_pool = []
	for w in wep_list:
		if w.get("Rarity") == "Legendary":
			legendary_pool.append(w)
		elif w.get("Rarity") == "Epic":
			epic_pool.append(w)
		else:
			other_rarity_pool.append(w)

	legendary_pool.shuffle()
	epic_pool.shuffle()

	var chosen: Array = []
	for i in range(min(LEGENDARY_WEAPON_COUNT, legendary_pool.size())):
		chosen.append(legendary_pool[i])
	for i in range(min(EPIC_WEAPON_COUNT, epic_pool.size())):
		chosen.append(epic_pool[i])
	for i in other_rarity_pool.size():
		chosen.append(other_rarity_pool[i])

	for w in chosen:
		var entry = {
			"Owner": Global.ACTIVE_USER_NAME,
			"Weapon": w.get("Name"),
			"Rarity": w.get("Rarity"),
			"Region": w.get("Region"),
			"Type": w.get("Weapon_Type"),
			"Effect": w.get("Effect"),
			"Stat_1_Type": w.get("Stat_1_Type"),
			"Stat_2_Type": w.get("Stat_2_Type"),
			"Stat_3_Type": w.get("Stat_3_Type"),
			"Stat_1_Value": w.get("Stat_1_Value"),
			"Stat_2_Value": w.get("Stat_2_Value"),
			"Stat_3_Value": w.get("Stat_3_Value"),
			"Quantity": 1
		}
		entry["Value"] = _price_weapon(w, current_region)
		Stock["Weapons"].append(entry)

func _price_weapon(w: Dictionary, current_region: String) -> int:
	var weapon_name = w.get("Name")
	var craftable = false
	var craft_cost = 0.0
	for recipe_id in Global.CRAFTING_RECIPES.keys():
		var r: Dictionary = Global.CRAFTING_RECIPES[recipe_id]
		if r.get("Product") == weapon_name:
			craftable = true
			var item_name2 =  r.get("Material")
			var qty2 = int(r.get("Quantity", r.get("Qty", 0)))
			if item_name2 != null and item_name2 != "":
				var unit_val2 = _lookup_item_value(item_name2)
				craft_cost += float(unit_val2 * qty2)

	var base_price = 0.0
	if craftable == true:
		base_price = craft_cost * 1.5
	else:
		var rarity = w.get("Rarity")
		base_price = float(WEAPON_RARITY_BASE_PRICE.get(rarity, 75))

	base_price = _apply_region_markup(base_price, w.get("Region"), current_region)
	return int(round(base_price))

# --------------------------
# Generation: Artifacts
# --------------------------
func _generate_artifacts(_current_region: String) -> void:
	var sets: Array = []
	for k in Global.ARTIFACTS.keys():
		var a: Dictionary = Global.ARTIFACTS[k]
		var set_name = a.get("Artifact_Set")
		if set_name != null and not (set_name in sets):
			sets.append(set_name)
	if sets.is_empty():
		sets = ["Wanderer's Troupe", "Gladiator's Finale", "Noblesse Oblige", "Crimson Witch of Flames"]

	var required_types: Array = ARTIFACT_TYPES.duplicate()
	required_types.shuffle()

	var artifacts: Array = []
	for t in required_types:
		var entry = _build_artifact_entry(t, sets)
		entry["Value"] = _price_artifact(entry)
		entry["Quantity"] = 1
		artifacts.append(entry)

	while artifacts.size() < ARTIFACT_COUNT:
		var t2 = ARTIFACT_TYPES[_rng.randi_range(0, ARTIFACT_TYPES.size() - 1)]
		var e2 = _build_artifact_entry(t2, sets)
		e2["Value"] = _price_artifact(e2)
		e2["Quantity"] = 1
		artifacts.append(e2)

	Stock["Artifacts"] = artifacts

func _build_artifact_entry(artifact_type: String, sets: Array) -> Dictionary:
	var pick_set = sets[_rng.randi_range(0, sets.size() - 1)]
	var has_two_stats = _rng.randf() < TWO_STAT_ARTIFACT_P

	var stat_types: Array = _pick_artifact_stat_types(artifact_type, has_two_stats)

	var stat_1_val = _roll_artifact_stat_value()
	var stat_2_val = null
	if has_two_stats:
		stat_2_val = _roll_artifact_stat_value()

	return {
		"Owner": Global.ACTIVE_USER_NAME,
		"Artifact_Set": pick_set,
		"Type": artifact_type,
		"Stat_1_Type": stat_types[0],
		"Stat_2_Type": stat_types[1] if has_two_stats else null,
		"Stat_1_Value": stat_1_val,
		"Stat_2_Value": stat_2_val if has_two_stats else null,
		"Rarity": 5
	}

func _pick_artifact_stat_types(artifact_type: String, two_stats: bool) -> Array:
	var choices: Array = []
	var weights: Array = []

	# Pick which extra set (if any) applies to this artifact type
	var extra_map: Dictionary = {}
	if artifact_type == "Sands of Time":
		extra_map = SANDS_EXTRA
	elif artifact_type == "Goblet of Space":
		extra_map = GOBLET_EXTRA
	elif artifact_type == "Circlet of Principles":
		extra_map = CIRCLET_EXTRA

	# Sum of all extra probabilities (supports >1 extra in the future)
	var extra_total = 0.0
	for k in extra_map.keys():
		extra_total += float(extra_map[k])

	# Distribute remaining probability evenly among the 4 base stats
	var base_share = max(0.0, 1.0 - extra_total)
	var base_each = base_share / float(STAT_BASE_CHOICES.size())

	# Add base stats
	var i = 0
	while i < STAT_BASE_CHOICES.size():
		var s = STAT_BASE_CHOICES[i]
		choices.append(s)
		weights.append(base_each)
		i += 1

	# Add extras using their exact probabilities
	for k in extra_map.keys():
		choices.append(k)
		weights.append(float(extra_map[k]))

	# Now pick 1 or 2 stats with this normalized distribution
	var pick1 = _weighted_pick(choices, weights)
	var out: Array = [pick1]
	if two_stats:
		var pick2 = _weighted_pick(choices, weights)
		out.append(pick2)
	return out

func _roll_artifact_stat_value() -> float:
	var sign = -1.0 if _rng.randf() < STAT_NEGATIVE_P else 1.0
	# bucket pick
	var r = _rng.randf()
	var accum = 0.0
	var chosen: Dictionary = MAG_BUCKETS[0]
	for b in MAG_BUCKETS:
		accum += b["p"]
		if r <= accum:
			chosen = b
			break
	var lo = chosen["range"].x
	var hi = chosen["range"].y
	var mag = _rng.randf_range(lo, hi)
	var snap = snappedf(mag, 0.1)  # 1 decimal
	return snap * sign

func _price_artifact(a: Dictionary) -> int:
	var two_stats = a.get("Stat_2_Type") != null

	var s1 = float(a.get("Stat_1_Value", 0.0))
	var s2_exists = a.get("Stat_2_Value") != null
	var s2 = 0.0
	if s2_exists:
		s2 = float(a.get("Stat_2_Value"))

	# 1) Base price with special rule: if two stats AND both negative -> halve base before other math
	var base_price = float(ARTIFACT_BASE_PRICE_2 if two_stats else ARTIFACT_BASE_PRICE_1)
	if two_stats and s2_exists:
		if s1 < 0.0 and s2 < 0.0:
			base_price = base_price * 0.25
		elif s1 < 0.0 and s2 >0.0 or s1 > 0.0 and s2 < 0.0:
			base_price = base_price * 0.50

	var v_total = base_price

	# Normal add/sub + high positive (>1.7) multiplier per stat
	if s1 >= 0.0:
		v_total += (s1 * 30.0)
		if s1 >= 1.5:
			v_total *= (1.0 + (s1 / 1.5))
	else:
		v_total -= (abs(s1) * 30.0)

	if s2_exists:
		if s2 >= 0.0:
			v_total += (s2 * 30.0)
			if s2 >= 1.5:
				v_total *= (1.0 + (s2 / 1.5))
		else:
			v_total -= (abs(s2) * 30.0)

	# 2) Rare stat adjustments (apply after normal pricing)
	var rare_types = ["Energy_Recharge", "Universal_Added_Damage_Bonus", "Critical_Damage"]
	var t1 = a.get("Stat_1_Type")
	if t1 in rare_types:
		if s1 > 0.0:
			v_total = v_total * 2.5
		elif s1 < 0.0:
			v_total = v_total / 2.5

	if s2_exists:
		var t2 = a.get("Stat_2_Type")
		if t2 in rare_types:
			if s2 > 0.0:
				v_total = v_total * 2.5
			elif s2 < 0.0:
				v_total = v_total / 2.5

	return int(clamp(round(v_total), 1, 999999))


# --------------------------
# Generation: Consumables
# --------------------------
func _generate_consumables(current_region: String) -> void:
	var items_current: Array = []
	var items_other: Array = []

	for id in Global.ITEMS.keys():
		var it: Dictionary = Global.ITEMS[id]
		if it.get("Type") == "Consumable":
			if it.get("Region") == current_region:
				items_current.append(it)
			else:
				items_other.append(it)

	for it in items_current:
		var entry = _build_store_item_from_item(it, current_region)
		entry["Quantity"] = _rng.randi_range(1, 4)
		Stock["Consumables"].append(entry)

	var pick_count = clamp(_rng.randi_range(1, 3), 0, items_other.size())
	items_other.shuffle()
	for i in range(pick_count):
		var entry2 = _build_store_item_from_item(items_other[i], current_region)
		entry2["Quantity"] = _rng.randi_range(1, 3)
		Stock["Consumables"].append(entry2)

# --------------------------
# Generation: Elemental Gems
# --------------------------
func _generate_elemental_gems(current_region: String) -> void:
	var gem_items: Array = []
	for id in Global.ITEMS.keys():
		var it: Dictionary = Global.ITEMS[id]
		var t = String(it.get("Type", ""))
		if t.ends_with("Star Gem"):
			gem_items.append(it)

	var by_star = {
		"1-Star Gem": [],
		"2-Star Gem": [],
		"3-Star Gem": [],
		"4-Star Gem": []
	}
	for it in gem_items:
		var t2 = it.get("Type")
		if t2 in by_star:
			by_star[t2].append(it)

	for it in by_star["1-Star Gem"]:
		var e1 = _build_store_item_from_item(it, current_region)
		e1["Quantity"] = _rng.randi_range(6, 12)
		Stock["Elemental_Gems"].append(e1)

	for it in by_star["2-Star Gem"]:
		var e2 = _build_store_item_from_item(it, current_region)
		e2["Quantity"] = _rng.randi_range(2, 5)
		Stock["Elemental_Gems"].append(e2)

	for it in by_star["3-Star Gem"]:
		var e3 = _build_store_item_from_item(it, current_region)
		e3["Quantity"] = _rng.randi_range(0, 2)
		if e3["Quantity"] > 0:
			Stock["Elemental_Gems"].append(e3)

	for it in by_star["4-Star Gem"]:
		var e4 = _build_store_item_from_item(it, current_region)
		var qty4 = 0
		if _rng.randf() < 0.15:
			qty4 = 1
		e4["Quantity"] = qty4
		if qty4 > 0:
			Stock["Elemental_Gems"].append(e4)

# --------------------------
# Generation: Artisan / Blacksmith
# --------------------------
func _generate_artisan(current_region: String) -> void:
	var wanted_types = ["Grains","Fruit","Vegetables","Beans","Herbs","Meat","Fish","Spices","Sugar"]
	_add_items_by_types_to_shop("Artisan", wanted_types, current_region)

func _generate_blacksmith(current_region: String) -> void:
	var wanted_types = ["Ore","Leather","Supplementary Ore","Lumber","Magical","Alloy"]
	_add_items_by_types_to_shop("Blacksmith", wanted_types, current_region)

	# Billets rare
	var billets: Array = []
	for id in Global.ITEMS.keys():
		var it: Dictionary = Global.ITEMS[id]
		if it.get("Type") == "Billet":
			billets.append(it)
	billets.shuffle()
	for b in billets:
		if _rng.randf() < 0.20:
			var e = _build_store_item_from_item(b, current_region)
			e["Quantity"] = 1
			Stock["Blacksmith"].append(e)

# --------------------------
# Helpers
# --------------------------
func _add_items_by_types_to_shop(shop_name: String, type_list: Array, current_region: String) -> void:
	for id in Global.ITEMS.keys():
		var it: Dictionary = Global.ITEMS[id]
		if it.get("Type") in type_list:
			var entry = _build_store_item_from_item(it, current_region)
			entry["Quantity"] = _rng.randi_range(5, 15)
			Stock[shop_name].append(entry)

func _build_store_item_from_item(it: Dictionary, current_region: String) -> Dictionary:
	var item_name = it.get("Item")
	var base_value = _lookup_item_value(item_name)
	var region = it.get("Region")
	var priced = _apply_region_markup(float(base_value), region, current_region)
	return {
		"Owner": Global.ACTIVE_USER_NAME,
		"Name": item_name,
		"Type": it.get("Type"),
		"Rarity": it.get("Rarity"),
		"Region": region,
		"Quantity": 0,
		"Description": it.get("Description", null),
		"Value": int(round(priced))
	}

func _lookup_item_value(item_name: String) -> int:
	for id in Global.ITEMS.keys():
		var it: Dictionary = Global.ITEMS[id]
		if it.get("Item") == item_name:
			return int(it.get("Value"))
	return 0

func _apply_region_markup(base_price: float, item_region: String, current_region: String) -> float:
	if item_region == null or current_region == null:
		return base_price
	if item_region == current_region:
		return base_price
	var pct = _rng.randf_range(REGION_MARKUP_MIN, REGION_MARKUP_MAX)
	return base_price * (1.0 + pct)

func _weighted_pick(items: Array, weights: Array) -> Variant:
	var total = 0.0
	for w in weights:
		total += float(w)
	var r = _rng.randf() * total
	var acc = 0.0
	for i in range(items.size()):
		acc += float(weights[i])
		if r <= acc:
			return items[i]
	return items[items.size() - 1]

# --------------------------
# DB commits (void → always return true after calling)
# --------------------------
# ---- Weapons
func _commit_buy_weapon(entry: Dictionary, qty: int) -> bool:
	var owner = entry.get("Owner")
	var weapon_name = entry.get("Weapon")
	var existing_id = _lookup_character_weapon(owner, weapon_name)

	if existing_id != null and (existing_id in Global.CHARACTER_WEAPONS):
		# increment Quantity
		var current_row: Dictionary = Global.CHARACTER_WEAPONS[existing_id]
		var original_qty = int(current_row.get("Quantity", 0))
		var updates = [{
			"table": "Character_Weapons",
			"record_id": int(existing_id),
			"field": "Quantity",
			"value": float(original_qty + qty)
		}]
		Global.Update_Records(updates)  # void
		return true
	else:
		# insert full row with Quantity
		var cols = [
			"Owner","Weapon","Rarity","Region","Type","Effect",
			"Stat_1_Type","Stat_2_Type","Stat_3_Type",
			"Stat_1_Value","Stat_2_Value","Stat_3_Value","Quantity"
		]
		var effect
		if entry.get("Effect") == null:
			effect = ""
		else:
			effect = entry.get("Effect")
		var vals = [
			entry.get("Owner"), entry.get("Weapon"), entry.get("Rarity"), entry.get("Region"),
			entry.get("Type"), effect,
			entry.get("Stat_1_Type"), entry.get("Stat_2_Type"), entry.get("Stat_3_Type"),
			entry.get("Stat_1_Value"), entry.get("Stat_2_Value"), entry.get("Stat_3_Value"),
			float(qty)
		]
		Global.Insert("Character_Weapons", cols, vals)  # void
		return true

# ---- Artifacts
func _commit_buy_artifact(entry: Dictionary) -> bool:
	var cols = [
		"Owner","Artifact_Set","Type",
		"Stat_1_Type","Stat_2_Type","Stat_1_Value","Stat_2_Value",
		"Rarity"
	]
	var vals = [
		entry.get("Owner"), entry.get("Artifact_Set"), entry.get("Type"),
		entry.get("Stat_1_Type"), entry.get("Stat_2_Type"),
		entry.get("Stat_1_Value"), entry.get("Stat_2_Value"),
		entry.get("Rarity")
	]
	Global.Insert("Character_Artifacts", cols, vals)  # void
	return true

# ---- Items (materials/consumables/etc.)
func _commit_buy_item(entry: Dictionary, qty: int) -> bool:
	var owner = entry.get("Owner")
	var name = entry.get("Name")
	var Type = entry.get("Type")
	var Rarity = entry.get("Rarity")
	var Description = entry.get("Description")
	var existing = _lookup_character_item(owner, name)

	if existing != null:
		var new_qty = int(existing.get("Quantity", 0)) + qty
		var updates = [{
			"table": "Character_Items",
			"record_id": int(existing.get("id")),
			"field": "Quantity",
			"value": int(new_qty)
		}]
		Global.Update_Records(updates)  # void
		return true
	else:
		var cols = ["Owner","Name","Quantity","Type","Description","Rarity"]
		var vals = [owner, name, int(qty),Type,Description,Rarity]
		Global.Insert("Character_Items", cols, vals)  # void
		return true

func _lookup_character_weapon(owner: String, weapon_name: String) -> Variant:
	for id in Global.CHARACTER_WEAPONS.keys():
		var row: Dictionary = Global.CHARACTER_WEAPONS[id]
		if row.get("Owner") == owner and row.get("Weapon") == weapon_name:
			return id
	return null

func _lookup_character_item(owner: String, name: String) -> Variant:
	for id in Global.CHARACTER_ITEMS.keys():
		var row: Dictionary = Global.CHARACTER_ITEMS[id]
		if row.get("Owner") == owner and row.get("Name") == name:
			var out = row.duplicate()
			out["id"] = id
			return out
	return null

func _sort_all_shops() -> void:
	_sort_weapons()
	_sort_artifacts()
	_sort_shop_by_name("Consumables")
	_sort_shop_by_name("Elemental_Gems")
	_sort_shop_by_name("Artisan")
	_sort_shop_by_name("Blacksmith")

# ---------- Weapons: rarity desc, then name asc ----------
func _sort_weapons() -> void:
	var arr: Array = Stock["Weapons"]
	arr.sort_custom(Callable(self, "_cmp_weapon"))

func _cmp_weapon(a: Dictionary, b: Dictionary) -> bool:
	var ra = _rarity_rank(a.get("Rarity"))
	var rb = _rarity_rank(b.get("Rarity"))
	if ra != rb:
		# lower rank = rarer; rarer first
		return ra < rb

	# Next: alphabetical by weapon Type (e.g., Bow, Polearm, …), case-insensitive
	var ta = String(a.get("Type", "")).to_lower()
	var tb = String(b.get("Type", "")).to_lower()
	if ta != tb:
		# Empty types sort after non-empty
		if ta == "" and tb != "":
			return false
		if tb == "" and ta != "":
			return true
		return ta < tb

	# Finally: alphabetical by weapon name, case-insensitive
	var na = String(a.get("Weapon", a.get("Name", ""))).to_lower()
	var nb = String(b.get("Weapon", b.get("Name", ""))).to_lower()
	if na == nb:
		return false
	return na < nb

func _rarity_rank(r: Variant) -> int:
	var s = ""
	if r != null:
		s = String(r).to_lower()
	if s == "legendary":
		return 0
	if s == "epic":
		return 1
	if s == "rare":
		return 2
	if s == "uncommon":
		return 3
	if s == "common":
		return 4
	return 99  # unknown pushed to bottom

# ---------- Artifacts: alphabetical by "Artifact_Set - Type" ----------
func _sort_artifacts() -> void:
	var arr: Array = Stock["Artifacts"]
	arr.sort_custom(Callable(self, "_cmp_artifact"))

func _cmp_artifact(a: Dictionary, b: Dictionary) -> bool:
	var ka = (String(a.get("Artifact_Set", "")) + " - " + String(a.get("Type", ""))).to_lower()
	var kb = (String(b.get("Artifact_Set", "")) + " - " + String(b.get("Type", ""))).to_lower()
	if ka == kb:
		return false
	return ka < kb

# ---------- Generic: alphabetical by "Name" ----------
func _sort_shop_by_name(shop_name: String) -> void:
	var arr: Array = Stock[shop_name]
	arr.sort_custom(Callable(self, "_cmp_name"))

func _cmp_name(a: Dictionary, b: Dictionary) -> bool:
	var na = String(a.get("Name", "")).to_lower()
	var nb = String(b.get("Name", "")).to_lower()
	if na == nb:
		return false
	return na < nb

func Apply_Price_Variance(variance_pct: float = PRICE_VARIANCE_PCT) -> void:
	# Apply to every shop's entries
	_apply_variance_to_array(Stock["Weapons"], variance_pct)
	_apply_variance_to_array(Stock["Artifacts"], variance_pct)
	_apply_variance_to_array(Stock["Consumables"], variance_pct)
	_apply_variance_to_array(Stock["Elemental_Gems"], variance_pct)
	_apply_variance_to_array(Stock["Artisan"], variance_pct)
	_apply_variance_to_array(Stock["Blacksmith"], variance_pct)

func _apply_variance_to_array(arr: Array, variance_pct: float) -> void:
	var i = 0
	while i < arr.size():
		var entry: Dictionary = arr[i]
		var base_val = float(entry.get("Value", 0))
		if base_val > 0.0:
			var min_mult = 1.0 - variance_pct
			var max_mult = 1.0 + variance_pct
			var mult = _rng.randf_range(min_mult, max_mult)
			var new_val = int(round(base_val * mult))
			if new_val < 1:
				new_val = 1
			entry["Value"] = new_val
		i += 1
