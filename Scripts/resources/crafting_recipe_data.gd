class_name CraftingRecipeData extends Resource

@export var id: int
@export var product: String
@export var region: String
@export var description: String
@export var role: String
@export var output_quantity: int = 1

## Alternative recipes — player picks ONE recipe, but must fill ALL slots in it.
## Each slot can accept one of several material options.
@export var recipes: Array[CraftingRecipeEntry] = []

# Legacy fields — auto-converted to recipes on load if recipes array is empty
@export var recipes_json: String = ""
@export var material: String = ""
@export var quantity: int = 0

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> CraftingRecipeData:
	var r = CraftingRecipeData.new()
	r.id = _i(d.get("id"))
	r.product = _s(d.get("Product"))
	r.region = _s(d.get("Region"))
	r.description = _s(d.get("Description"))
	r.role = _s(d.get("Role"))
	r.output_quantity = _i(d.get("Output_Quantity", 1))
	if r.output_quantity < 1:
		r.output_quantity = 1
	# Legacy JSON format — parse into typed resources
	var json_str = _s(d.get("Recipes_JSON", ""))
	if json_str != "" and json_str != "[]":
		r.recipes = _parse_json_to_resources(json_str)
	# Legacy single-material format
	r.material = _s(d.get("Material"))
	r.quantity = _i(d.get("Quantity"))
	if r.recipes.is_empty() and r.material != "":
		var opt = CraftingMaterialOption.new()
		opt.material = r.material
		opt.quantity = r.quantity
		var slot = CraftingSlot.new()
		slot.options = [opt]
		var entry = CraftingRecipeEntry.new()
		entry.slots = [slot]
		r.recipes = [entry]
	return r

## Convert recipes_json string to typed resource array.
static func _parse_json_to_resources(json_str: String) -> Array[CraftingRecipeEntry]:
	var parsed = JSON.parse_string(json_str)
	if not parsed is Array:
		return []
	var result: Array[CraftingRecipeEntry] = []
	for recipe_dict in parsed:
		var entry = CraftingRecipeEntry.new()
		for slot_dict in recipe_dict.get("slots", []):
			var slot = CraftingSlot.new()
			for opt_dict in slot_dict.get("options", []):
				var opt = CraftingMaterialOption.new()
				opt.material = str(opt_dict.get("material", ""))
				opt.quantity = int(opt_dict.get("quantity", 1))
				slot.options.append(opt)
			entry.slots.append(slot)
		result.append(entry)
	return result

## Get recipes as an Array of Dictionaries (for code that expects the old dict format).
func get_recipes() -> Array:
	# Convert typed resources to dicts for backwards compat with CraftingMenu
	if recipes.size() > 0:
		var out: Array = []
		for entry in recipes:
			var slots_arr: Array = []
			for slot in entry.slots:
				var opts_arr: Array = []
				for opt in slot.options:
					opts_arr.append({"material": opt.material, "quantity": opt.quantity})
				slots_arr.append({"options": opts_arr})
			out.append({"slots": slots_arr})
		return out
	# Fallback: try JSON
	if recipes_json != "" and recipes_json != "[]":
		var parsed = JSON.parse_string(recipes_json)
		if parsed is Array:
			return parsed
	# Fallback: legacy single-material
	if material != "" and quantity > 0:
		return [{"slots": [{"options": [{"material": material, "quantity": quantity}]}]}]
	return []
