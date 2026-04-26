@tool
extends EditorScript
## Reads each .tres file as raw text, extracts recipes_json,
## converts to recipe_lines, and rewrites the file directly.
## No ResourceSaver — just text manipulation.

const RECIPE_DIR := "res://data/resources/crafting_recipes/"

func _run() -> void:
	var global_path = ProjectSettings.globalize_path(RECIPE_DIR)
	var dir = DirAccess.open(RECIPE_DIR)
	if dir == null:
		print("ERROR: Cannot open ", RECIPE_DIR)
		return

	var count := 0
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") and not fname.begins_with("_"):
			var path = global_path + fname
			if _process_file(path, fname):
				count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	print("Done. Rewrote %d recipe files. Restart Godot to reload." % count)


func _process_file(abs_path: String, fname: String) -> bool:
	var file = FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		# Try with res:// path
		file = FileAccess.open(RECIPE_DIR + fname, FileAccess.READ)
		if file == null:
			print("  SKIP: cannot open %s" % fname)
			return false
	var text = file.get_as_text()
	file.close()

	# Extract recipes_json value
	var json_start = text.find('recipes_json = "')
	if json_start == -1:
		return false
	json_start += 'recipes_json = "'.length()

	# Find the closing quote (handle escaped quotes)
	var json_end = json_start
	while json_end < text.length():
		if text[json_end] == '\\' and json_end + 1 < text.length():
			json_end += 2
			continue
		if text[json_end] == '"':
			break
		json_end += 1

	var raw_json = text.substr(json_start, json_end - json_start)
	# Unescape
	raw_json = raw_json.replace('\\"', '"').replace('\\\\', '\\')

	if raw_json == "" or raw_json == "[]":
		return false

	# Parse JSON
	var parsed = JSON.parse_string(raw_json)
	if not parsed is Array or parsed.is_empty():
		print("  WARN: %s — JSON parse failed" % fname)
		return false

	# Convert to recipe lines
	var lines: PackedStringArray = []
	for recipe in parsed:
		var line = _recipe_to_line(recipe)
		if line != "":
			lines.append(line)

	if lines.is_empty():
		return false

	# Build the PackedStringArray string for .tres
	var escaped_lines: Array = []
	for line in lines:
		escaped_lines.append('"' + line.replace('\\', '\\\\').replace('"', '\\"') + '"')
	var packed_str = "PackedStringArray(%s)" % ", ".join(escaped_lines)

	# Replace recipes_json line with empty and add/replace recipe_lines
	# Find and replace the recipes_json line
	var rj_line_start = text.find("recipes_json = ")
	var rj_line_end = text.find("\n", rj_line_start)
	if rj_line_end == -1:
		rj_line_end = text.length()
	text = text.substr(0, rj_line_start) + 'recipes_json = ""' + text.substr(rj_line_end)

	# Find and replace recipe_lines line if it exists
	var rl_line_start = text.find("recipe_lines = ")
	if rl_line_start != -1:
		var rl_line_end = text.find("\n", rl_line_start)
		if rl_line_end == -1:
			rl_line_end = text.length()
		text = text.substr(0, rl_line_start) + "recipe_lines = " + packed_str + text.substr(rl_line_end)
	else:
		# Insert before recipes_json line
		var insert_pos = text.find('recipes_json = ""')
		text = text.substr(0, insert_pos) + "recipe_lines = " + packed_str + "\n" + text.substr(insert_pos)

	# Write back
	var out = FileAccess.open(abs_path, FileAccess.WRITE)
	if out == null:
		out = FileAccess.open(RECIPE_DIR + fname, FileAccess.WRITE)
		if out == null:
			print("  ERROR: cannot write %s" % fname)
			return false
	out.store_string(text)
	out.close()

	# Extract product name for logging
	var prod_start = text.find('product = "') + 'product = "'.length()
	var prod_end = text.find('"', prod_start)
	var product = text.substr(prod_start, prod_end - prod_start)
	print("  %s → %s" % [product, str(lines)])
	return true


func _recipe_to_line(recipe) -> String:
	if not recipe is Dictionary:
		return ""
	var slots = recipe.get("slots", [])
	if not slots is Array:
		return ""
	var parts: Array = []
	for slot in slots:
		if not slot is Dictionary:
			continue
		var options = slot.get("options", [])
		if not options is Array or options.is_empty():
			continue
		if options.size() == 1:
			var o = options[0]
			parts.append("%dx %s" % [int(o.get("quantity", 1)), str(o.get("material", "?"))])
		else:
			var opt_strs: Array = []
			for o in options:
				opt_strs.append("%dx %s" % [int(o.get("quantity", 1)), str(o.get("material", "?"))])
			parts.append(" or ".join(opt_strs))
	if parts.is_empty():
		return ""
	return " + ".join(parts)
