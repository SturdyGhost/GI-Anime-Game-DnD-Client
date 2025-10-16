extends HBoxContainer

signal reorder_requested(from_index: int, to_index: int)
signal bump_requested(index: int, delta: int)

var _index: int = -1
var _name: String = ""

func init_row(name: String, index: int) -> void:
	_name = name
	_index = index
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	focus_mode = Control.FOCUS_NONE

func get_drag_data(at_position: Vector2) -> Variant:
	var preview = Label.new()
	preview.text = _name
	preview.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	set_drag_preview(preview)
	return {"from_index": _index}

func can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("from_index"):
		return false
	return true

func drop_data(at_position: Vector2, data: Variant) -> void:
	var from_index = int(data["from_index"])
	emit_signal("reorder_requested", from_index, _index)
