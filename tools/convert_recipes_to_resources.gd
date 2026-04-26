@tool
extends EditorScript
## Run this from the Godot editor: File > Run Script
## Converts recipes_json strings in CraftingRecipeData .tres files
## into proper typed Resource arrays (CraftingRecipeEntry/CraftingSlot/CraftingMaterialOption)
## so they display nicely in the inspector.

const RECIPE_DIR := "res://data/resources/crafting_recipes/"

func _run() -> void:
	var dir = DirAccess.open(RECIPE_DIR)
	if dir == null:
		print("ERROR: Cannot open ", RECIPE_DIR)
		return

	var count := 0
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") and not fname.begins_with("_"):
			var path = RECIPE_DIR + fname
			var res = load(path)
			if res is CraftingRecipeData:
				if _convert_recipe(res):
					ResourceSaver.save(res, path)
					count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	print("Converted %d recipe files to typed resources." % count)


func _convert_recipe(r: CraftingRecipeData) -> bool:
	# Already has typed recipes — skip
	if r.recipes.size() > 0:
		return false

	# Try parsing from recipes_json
	if r.recipes_json != "" and r.recipes_json != "[]":
		var parsed = JSON.parse_string(r.recipes_json)
		if parsed is Array:
			r.recipes = _build_typed_recipes(parsed)
			r.recipes_json = ""  # Clear JSON now that we have typed resources
			return true

	# Try legacy single-material
	if r.material != "" and r.quantity > 0:
		var opt = CraftingMaterialOption.new()
		opt.material = r.material
		opt.quantity = r.quantity
		var slot = CraftingSlot.new()
		slot.options = [opt]
		var entry = CraftingRecipeEntry.new()
		entry.slots = [slot]
		r.recipes = [entry]
		r.recipes_json = ""
		r.material = ""
		r.quantity = 0
		return true

	return false


func _build_typed_recipes(parsed: Array) -> Array[CraftingRecipeEntry]:
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
