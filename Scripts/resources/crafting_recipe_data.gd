class_name CraftingRecipeData extends Resource

@export var id: int
@export var product: String
@export var region: String
@export var description: String
@export var role: String
@export var output_quantity: int = 1

## JSON string encoding the recipe structure:
## [
##   {
##     "slots": [
##       { "options": [ {"material": "Iron", "quantity": 1} ] },
##       { "options": [ {"material": "Coal", "quantity": 2}, {"material": "Steel", "quantity": 3} ] }
##     ]
##   }
## ]
## Each top-level entry is an alternative recipe. All slots in a recipe must be filled.
## Each slot can have multiple material options (player picks one).
@export var recipes_json: String = "[]"

# Legacy fields — kept for backwards compat during migration, ignored by new code
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
	# New format
	r.recipes_json = _s(d.get("Recipes_JSON", "[]"))
	# Legacy single-material format — auto-convert to new format if recipes_json empty
	r.material = _s(d.get("Material"))
	r.quantity = _i(d.get("Quantity"))
	if r.recipes_json == "[]" and r.material != "":
		r.recipes_json = JSON.stringify([{
			"slots": [{"options": [{"material": r.material, "quantity": r.quantity}]}]
		}])
	return r

## Parse recipes_json into an Array of recipe dicts.
func get_recipes() -> Array:
	var parsed = JSON.parse_string(recipes_json)
	if parsed is Array:
		return parsed
	# Fallback: legacy single-material
	if material != "" and quantity > 0:
		return [{"slots": [{"options": [{"material": material, "quantity": quantity}]}]}]
	return []

## Convenience: check if a recipe can be fulfilled given an inventory lookup function.
## inv_lookup: func(material_name: String) -> int (returns quantity owned)
func can_craft_recipe(recipe: Dictionary, craft_qty: int, inv_lookup: Callable) -> bool:
	for slot in recipe.get("slots", []):
		var any_option_works = false
		for option in slot.get("options", []):
			var need = int(option.get("quantity", 1)) * craft_qty
			var have = inv_lookup.call(str(option.get("material", "")))
			if have >= need:
				any_option_works = true
				break
		if not any_option_works:
			return false
	return true

## Check if ANY recipe is craftable.
func can_craft_any(craft_qty: int, inv_lookup: Callable) -> bool:
	for recipe in get_recipes():
		if can_craft_recipe(recipe, craft_qty, inv_lookup):
			return true
	return false
