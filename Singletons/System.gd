extends Node

func refresh(node: Node) -> void:
	if node == null:
		push_error("System.refresh(): Node is null.")
		return

	var path: String = node.scene_file_path
	if path.is_empty():
		push_warning("System.refresh(): Node has no scene_file_path; cannot reload.")
		return

	var packed: PackedScene = load(path)
	if packed == null:
		push_error("System.refresh(): Failed to load scene " + path)
		return

	var new_node: Node = packed.instantiate()
	new_node.name = node.name

	# Defer replacement to avoid modifying the tree during signal calls
	_replace_with(node,new_node)


# Internal helper used by call_deferred
func _replace_with(old_node: Node, new_node: Node) -> void:
	print ("Replacing node: ", old_node, " With: ", new_node)
	if old_node == null:
		return

	var parent: Node = old_node.get_parent()
	if parent == null:
		push_error("System.refresh(): Node has no parent; cannot replace.")
		return

	var idx: int = old_node.get_index()
	parent.add_child(new_node)
	parent.move_child(new_node, idx)
	old_node.queue_free()


func db_richtext_to_bbcode(raw: String) -> String:
	var s := raw

	# Normalize line breaks and <br>
	s = s.replace("\r\n", "\n").replace("\r", "\n")
	s = s.replace("<br/>", "\n").replace("<br />", "\n").replace("<br>", "\n")

	var lines := s.split("\n")
	var out_lines: Array[String] = []

	for line in lines:
		var trimmed := line.strip_edges()

		# Headers (### biggest, ## medium, # small)
		if trimmed.begins_with("### "):
			var header_text := _inline_markdown_to_visible_style(trimmed.substr(4))
			out_lines.append("[font_size=40]%s[/font_size]" % header_text)
			continue
		if trimmed.begins_with("## "):
			var header_text := _inline_markdown_to_visible_style(trimmed.substr(3))
			out_lines.append("[font_size=30]%s[/font_size]" % header_text)
			continue
		if trimmed.begins_with("# "):
			var header_text := _inline_markdown_to_visible_style(trimmed.substr(2))
			out_lines.append("[font_size=20]%s[/font_size]" % header_text)
			continue

		# Bullets "- "
		if trimmed.begins_with("- "):
			var item_text := _inline_markdown_to_visible_style(trimmed.substr(2))
			out_lines.append("[indent][indent]• %s[/indent][/indent]" % item_text)
			continue


		out_lines.append(_inline_markdown_to_visible_style(line))

	return "\n".join(out_lines)+"\n\n\n\n"


func _inline_markdown_to_visible_style(s: String) -> String:
	# Replaces:
	# **bold**   -> ⟦[u]bold[/u]⟧   (underline via BBCode)
	# *italics*  -> “italics”
	#
	# Uses toggles like markdown, closes gracefully if unmatched.

	var out := ""
	var i := 0
	var bold_open := false
	var ital_open := false

	while i < s.length():
		# Bold: **
		if i + 1 < s.length() and s[i] == "*" and s[i + 1] == "*":
			if not bold_open:
				out += "⟦[u]"
			else:
				out += "[/u]⟧"
			bold_open = not bold_open
			i += 2
			continue

		# Italics: *
		if s[i] == "*":
			out += "“" if not ital_open else "”"
			ital_open = not ital_open
			i += 1
			continue

		out += s[i]
		i += 1

	# Close any unclosed toggles
	if bold_open:
		out += "[/u]⟧"
	if ital_open:
		out += "”"

	return out
