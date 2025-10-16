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
