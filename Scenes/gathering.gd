extends Control

# ---------- Node refs ----------
@onready var D4Label: Label = $D4Label
@onready var D4Input = $D4Label/D4Input
@onready var D12Label: Label = $D12Label
@onready var D12Input = $D12Label/D12Input
@onready var ConfirmButton: Button = $ConfirmButton
@onready var ExitButton: Button = $ExitButton
@onready var ChooseMaterialOption: OptionButton = $ChooseMaterialOption

@onready var MaterialsReceivedLabel: Label = $MaterialsReceivedLabel
@onready var Material1Label: Label = $MaterialsReceivedLabel/VBoxContainer/Material1Label
@onready var Material2Label: Label = $MaterialsReceivedLabel/VBoxContainer/Material2Label
@onready var Material3Label: Label = $MaterialsReceivedLabel/VBoxContainer/Material3Label
@onready var Material4Label: Label = $MaterialsReceivedLabel/VBoxContainer/Material4Label

# ---------- Config: table/field names (change if yours differ) ----------
const ITEMS_TABLE_NAME: String = "CHARACTER_ITEMS"
const FIELD_CHARACTER: String = "Character"   # character record id
const FIELD_ITEM: String = "Item"             # material name
const FIELD_QTY: String = "Quantity"          # integer

var mats: Array
var d4_roll: int
var d12_roll: int

func _ready() -> void:
	randomize()
	_clear_material_labels()
	constellation_check()
	_populate_material_dropdown_for_region(Global.Current_Region)
	
	ConfirmButton.pressed.connect(_on_confirm_pressed)
	ExitButton.pressed.connect(_on_exit_pressed)

func constellation_check():
	for constellation in Global.CONSTELLATIONS.values():
		if constellation.get("Name") == Global.ACTIVE_USER_NAME and constellation.get("Chosen") == true:
			if constellation.get("Constellation") == "When gathering materials, you may choose which material cache you go to rather than rolling for it.":
				ChooseMaterialOption.disabled = false

# Build a unique, sorted list of materials for the current region
func _populate_material_dropdown_for_region(region: String) -> void:
	ChooseMaterialOption.clear()
	var uniques: = {}
	for rec_id in Global.MATERIAL_CACHES.keys():
		var rec: Dictionary = Global.MATERIAL_CACHES[rec_id]
		if str(rec.get("Region", "")) != str(region):
			continue
		mats = _parse_materials(rec.get("Materials", []))
		for m in mats:
			uniques[m] = true
	var sorted_mats: Array = uniques.keys()
	sorted_mats.sort_custom(func(a, b): return str(a) < str(b))
	for i in sorted_mats.size():
		ChooseMaterialOption.add_item(str(sorted_mats[i]), i)

#Process Materials String into proper array.
func _parse_materials(val) -> Array:
	if typeof(val) == TYPE_ARRAY:
		return val
	if typeof(val) == TYPE_STRING:
		var txt: String = val.strip_edges()
		# Remove brackets if present
		if txt.begins_with("[") and txt.ends_with("]"):
			txt = txt.substr(1, txt.length() - 2)
		# Split on commas, trim spaces
		var arr: Array = []
		for part in txt.split(","):
			var clean = part.strip_edges()
			if clean != "":
				arr.append(clean)
		return arr
	return []

# Confirm button flow
func _on_confirm_pressed() -> void:
	_clear_material_labels()
	var region: String = str(Global.Current_Region)
	if D4Input.text != "":
		d4_roll = _to_int_safely(D4Input.text, 1)
	if D12Input.text != "":
		d12_roll = _to_int_safely(D12Input.text, 1)
	if d4_roll < 1 or d4_roll > 4:
		MaterialsReceivedLabel.text = "Invalid D4 roll. Enter 1–4."
		return
	if d12_roll < 1:
		MaterialsReceivedLabel.text = "Invalid D12 roll."
		return

	# Pick cache by rule (ChooseMaterialOption enabled overrides D4)
	var cache: Dictionary = {}
	if ChooseMaterialOption.disabled == false:
		var selected_text: String = ChooseMaterialOption.get_item_text(ChooseMaterialOption.selected) if ChooseMaterialOption.item_count > 0 else ""
		cache = _find_cache_by_material(region, selected_text)
		if cache.is_empty():
			MaterialsReceivedLabel.text = "No cache in %s containing %s." % [region, selected_text]
			return
	else:
		cache = _find_cache_by_roll(region, d4_roll)
		if cache.is_empty():
			MaterialsReceivedLabel.text = "No cache in %s for roll %d." % [region, d4_roll]
			return

	var materials = _parse_materials(cache.get("Materials", []))
	if materials.is_empty():
		MaterialsReceivedLabel.text = "Selected cache has no materials."
		return

	var target_avg: int = ceili(float(d12_roll))
	var quantities: Array = _generate_spread_counts(target_avg, materials.size())

	# Apply to inventory
	var updated_pairs: Array = []
	for i in materials.size():
		var mat_name: String = str(materials[i])
		var qty: int = int(quantities[i])
		if qty < 1:
			qty = 1
		_upsert_character_item(mat_name, qty)
		updated_pairs.append([mat_name, qty])

	# Update labels (supports up to 4 entries)
	_write_material_labels(updated_pairs)

	# Feedback label
	var sum_qty: int = 0
	for p in updated_pairs:
		sum_qty += int(p[1])
	var avg_result: float = float(sum_qty) / float(max(1, updated_pairs.size()))
	MaterialsReceivedLabel.text = "Added materials (avg ≈ %.1f, target %d)." % [avg_result, target_avg]

 # Correct Global.Log call
	Global.Log(
		"Gathering",                         # category
		"Confirm",                           # action
		"Region",                            # related_type
		region,                              # related_id
		{},                                  # old_values (not applicable here)
		{},                                  # new_values (we're adding new items, no single row)
		{                                    # metadata
			"D4": d4_roll,
			"D12": d12_roll,
			"UsedMaterialOverride": ChooseMaterialOption.disabled == false,
			"Results": updated_pairs
		},
		"success",                           # result
		"audit"                              # severity
	)

func _on_exit_pressed() -> void:
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

# ---- Helpers ----

func _find_cache_by_roll(region: String, roll: int) -> Dictionary:
	for rec_id in Global.MATERIAL_CACHES.keys():
		var rec: Dictionary = Global.MATERIAL_CACHES[rec_id]
		if str(rec.get("Region", "")) == str(region) and int(rec.get("Roll", 0)) == roll:
			return rec
	return {}

func _find_cache_by_material(region: String, material: String) -> Dictionary:
	if material == "":
		return {}
	for rec_id in Global.MATERIAL_CACHES.keys():
		var rec: Dictionary = Global.MATERIAL_CACHES[rec_id]
		if str(rec.get("Region", "")) != str(region):
			continue
		mats = _parse_materials(rec.get("Materials", []))
		if material in mats:
			return rec
	return {}

# Generate per-material counts with small variance around target_avg.
# Ensures min 1 each and keeps overall average ≈ target_avg (rounded up).
func _generate_spread_counts(target_avg: int, count: int) -> Array:
	if count <= 0:
		return []
	var base: int = max(1, target_avg)
	var nums: Array = []
	# First pass: ±1 variance
	for i in count:
		var delta: int = randi_range(-1, 1)
		var v: int = max(1, base + delta)
		nums.append(v)
	# Adjust total to match base * count as closely as possible
	var target_total: int = base * count
	var current_total: int = 0
	for n in nums:
		current_total += int(n)
	while current_total != target_total:
		if current_total < target_total:
			# add +1 to the smallest element (but keep variance)
			var idx_inc: int = _index_of_min(nums)
			nums[idx_inc] = int(nums[idx_inc]) + 1
			current_total += 1
		else:
			# subtract -1 from the largest element (min 1)
			var idx_dec: int = _index_of_max(nums)
			if int(nums[idx_dec]) > 1:
				nums[idx_dec] = int(nums[idx_dec]) - 1
				current_total -= 1
			else:
				break
	return nums

func _index_of_min(arr: Array) -> int:
	var idx: int = 0
	var best: int = int(arr[0])
	for i in arr.size():
		if int(arr[i]) < best:
			best = int(arr[i])
			idx = i
	return idx

func _index_of_max(arr: Array) -> int:
	var idx: int = 0
	var best: int = int(arr[0])
	for i in arr.size():
		if int(arr[i]) > best:
			best = int(arr[i])
			idx = i
	return idx

func _upsert_character_item(material_name: String, add_qty: int) -> void:
	var char_name: String = str(Global.ACTIVE_USER_NAME)
	var char_id = Global.CHARACTERS_NAME.get(char_name, null)  # record id per your model-set note
	if char_id == null:
		return

	# Search for existing item
	var existing_id: String = ""
	var existing_qty: int = 0
	for rec_id in Global.CHARACTER_ITEMS.keys():
		var rec: Dictionary = Global.CHARACTER_ITEMS[rec_id]
		if rec.get("Owner", null) == char_name and str(rec.get("Name", "")) == material_name:
			existing_id = rec_id
			existing_qty = int(rec.get("Quantity", 0))
			break

	if existing_id != "":
		var new_qty: int = existing_qty + add_qty
		Global.Update_Records([{"table": "Character_Items", "record_id": float(existing_id),"field":"Quantity","value": new_qty }])
	else:
		# ✔ Insert(table: String, columns: Array, values: Array)
		var Type
		var Rarity
		var Description
		for item in Global.ITEMS.values():
			if item.get("Item") == material_name:
				Type = item.get("Type")
				Rarity = item.get("Rarity")
				Description = item.get("Description")
		var columns: Array = ["Owner", "Name", "Quantity","Type","Rarity","Description"]
		var values: Array = [char_name, material_name, add_qty,Type,Rarity,Description]
		Global.Insert("Character_Items", columns, values)

func _write_material_labels(pairs: Array) -> void:
	# pairs: [ [name, qty], ... ]
	var labels: Array = [Material1Label, Material2Label, Material3Label, Material4Label]
	for i in labels.size():
		if i < pairs.size():
			var name_str: String = str(pairs[i][0])
			var qty_str: String = str(pairs[i][1])
			labels[i].visible = true
			labels[i].text = "%s x%s" % [name_str, qty_str]
		else:
			labels[i].visible = false
			labels[i].text = ""

func _clear_material_labels() -> void:
	Material1Label.text = ""
	Material2Label.text = ""
	Material3Label.text = ""
	Material4Label.text = ""
	Material1Label.visible = false
	Material2Label.visible = false
	Material3Label.visible = false
	Material4Label.visible = false

func _to_int_safely(s: String, default_value: int) -> int:
	var txt: String = s.strip_edges()
	if txt == "":
		return default_value
	var v: int = int(txt.to_int())
	return v
