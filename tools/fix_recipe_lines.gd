@tool
extends EditorScript
## Run from Godot editor: File > Run Script
## Converts recipes_json → recipe_lines on all CraftingRecipeData resources,
## then re-saves so Godot writes proper PackedStringArray format.

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
				if res.recipe_lines.is_empty() and res.recipes_json != "" and res.recipes_json != "[]":
					res.recipe_lines = _json_to_lines(res.recipes_json)
					res.recipes_json = ""  # Clear JSON now that lines are set
					ResourceSaver.save(res, path)
					count += 1
					print("  %s → %s" % [res.product, res.recipe_lines])
		fname = dir.get_next()
	dir.list_dir_end()
	print("Done. Converted %d recipes from JSON to recipe_lines." % count)


func _json_to_lines(json_str: String) -> PackedStringArray:
	var parsed = JSON.parse_string(json_str)
	if not parsed is Array:
		return PackedStringArray()
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
		if parts.size() > 0:
			lines.append(" + ".join(parts))
	return lines
