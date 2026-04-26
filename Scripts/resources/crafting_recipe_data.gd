class_name CraftingRecipeData extends Resource

@export var id: int
@export var product: String
@export var region: String
@export var description: String
@export var role: String
@export var output_quantity: int = 1

## One recipe per line. Multiple lines = alternative recipes (pick one).
## Format: "15x Fungal Spores + 10x Padisarah + 10x Iron Chunk"
##   +  separates required ingredients (all needed)
##   or separates alternatives within a slot (pick one)
##   [brackets] match by item TYPE instead of name: "10x [Ore]"
## Examples:
##   One recipe, one ingredient:      6x Rukkhashava Mushrooms
##   Two alternative recipes:         3x 2-Star Gem
##                                    1x 4-Star Gem
##   Multi-ingredient recipe:         15x Fungal Spores + 10x Padisarah + 10x Iron
##   Slot with options:               1x Iron + 2x Coal or 3x Steel
@export_multiline var recipe_text: String = ""

# Legacy fields — auto-converted on load
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
	# Legacy JSON → convert to recipe_text
	var json_str = _s(d.get("Recipes_JSON", ""))
	if json_str != "" and json_str != "[]":
		r.recipe_text = _json_to_text(json_str)
	# Legacy single-material
	r.material = _s(d.get("Material"))
	r.quantity = _i(d.get("Quantity"))
	if r.recipe_text.strip_edges() == "" and r.material != "":
		r.recipe_text = "%dx %s" % [r.quantity, r.material]
	return r

static func _json_to_text(json_str: String) -> String:
	var parsed = JSON.parse_string(json_str)
	if not parsed is Array:
		return ""
	var lines: PackedStringArray = []
	for recipe in parsed:
		var parts: Array = []
		for slot in recipe.get("slots", []):
			var options = slot.get("options", [])
			if options.size() == 1:
				parts.append("%dx %s" % [int(options[0].get("quantity", 1)), str(options[0].get("material", "?"))])
			elif options.size() > 1:
				var opt_strs: Array = []
				for o in options:
					opt_strs.append("%dx %s" % [int(o.get("quantity", 1)), str(o.get("material", "?"))])
				parts.append(" or ".join(opt_strs))
		lines.append(" + ".join(parts))
	return "\n".join(lines)

## Parse recipe_text into the dict format used by CraftingMenu.
func get_recipes() -> Array:
	var text = recipe_text.strip_edges()
	if text != "":
		var out: Array = []
		for line in text.split("\n"):
			line = line.strip_edges()
			if line != "":
				out.append(_parse_line(line))
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

static func _parse_line(line: String) -> Dictionary:
	var slots: Array = []
	var slot_parts = line.split(" + ")
	for part in slot_parts:
		var options: Array = []
		var opt_parts = part.split(" or ")
		for opt_str in opt_parts:
			opt_str = opt_str.strip_edges()
			var parsed_opt = _parse_option(opt_str)
			if not parsed_opt.is_empty():
				options.append(parsed_opt)
		if options.size() > 0:
			slots.append({"options": options})
	return {"slots": slots}

static func _parse_option(s: String) -> Dictionary:
	var x_pos = s.find("x ")
	if x_pos <= 0:
		if s.strip_edges() != "":
			return {"material": s.strip_edges(), "quantity": 1, "match_type": false}
		return {}
	var qty_str = s.substr(0, x_pos).strip_edges()
	var mat = s.substr(x_pos + 2).strip_edges()
	var qty = int(qty_str) if qty_str.is_valid_int() else 1
	var is_type = mat.begins_with("[") and mat.ends_with("]")
	if is_type:
		mat = mat.substr(1, mat.length() - 2)
	return {"material": mat, "quantity": qty, "match_type": is_type}
