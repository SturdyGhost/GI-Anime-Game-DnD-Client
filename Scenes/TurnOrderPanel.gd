extends Panel

# Public API you set from PlayerHub:
# - party_record_id: which Party row to update
# - active_complete_party: the 4 names in order (strings)
@export var party_record_id: int = 0
var active_complete_party: Array = []  # ["Brian C.","Brian F.","Dylan","Yae Miko"]

@onready var OrderList: VBoxContainer = $OrderList
var _last_persisted_order: Array = []  # snapshot for Log old_values

# Internal working copy
var _order: Array = []  # same format as active_complete_party

func _ready() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	_set_order(active_complete_party)

func _on_data_load_complete():
	var DBFirst =  Global.Current_Party.get("First_Turn")
	var DBSecond = Global.Current_Party.get("Second_Turn")
	var DBThird = Global.Current_Party.get("Third_Turn")
	var DBFourth = Global.Current_Party.get("Fourth_Turn")
	
	if _order[0] != DBFirst or _order[1] != DBSecond or _order[2] != DBThird or _order[3] != DBFourth:
		_order = [DBFirst,DBSecond,DBThird,DBFourth]
		_rebuild_rows()


# Call this once you have the party names
func set_party(names: Array) -> void:
	_set_order(names)



# ----------------- UI Build -----------------

func _set_order(names: Array) -> void:
	_order = names.duplicate(true)
	_rebuild_rows()
	_persist_to_db()

func _rebuild_rows() -> void:
	# Clear
	for c in OrderList.get_children():
		c.queue_free()

	# Build rows
	for i in _order.size():
		var row := _make_row(_order[i], i)
		OrderList.add_child(row)

func _make_row(name: String, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_" + str(index)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 36

	# DRAG+DROP: attach lightweight row behavior
	row.set_script(preload("res://Scenes/TurnOrderRow.gd"))
	row.call("init_row", name, index)
	row.connect("reorder_requested", Callable(self, "_on_row_reorder_requested"))
	row.connect("bump_requested", Callable(self, "_on_row_bump_requested"))

	# Visuals
	var label := Label.new()
	label.name = "Name"
	label.text = name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var up := Button.new()
	up.text = "▲"
	up.custom_minimum_size = Vector2(36, 28)
	up.tooltip_text = "Move up"
	up.focus_mode = Control.FOCUS_NONE
	up.pressed.connect(func() -> void:
		_on_row_bump_requested(index, -1)
	)
	row.add_child(up)

	var down := Button.new()
	down.text = "▼"
	down.custom_minimum_size = Vector2(36, 28)
	down.tooltip_text = "Move down"
	down.focus_mode = Control.FOCUS_NONE
	down.pressed.connect(func() -> void:
		_on_row_bump_requested(index, 1)
	)
	row.add_child(down)

	return row

# ----------------- Reorder logic -----------------

func _on_row_reorder_requested(from_index: int, to_index: int) -> void:
	_move_inplace(_order,from_index,to_index)
	_rebuild_rows()
	_persist_to_db()
	

func _on_row_bump_requested(index: int, delta: int) -> void:
	var to_index = index + delta
	if to_index < 0:
		to_index = _order.size()-1
	if to_index > _order.size()-1:
		to_index = 0
	print("Move from:" + str(index) +" to: " + str(to_index))
	_on_row_reorder_requested(index, to_index)


func _move_inplace(arr: Array, from_index: int, to_index: int) -> void:
	var item = arr[from_index]
	arr.remove_at(from_index)         # returns void in Godot 4.x
	arr.insert(to_index, item)
# ----------------- Persistence -----------------

func _order_value_at(i: int) -> String:
	if i >= 0 and i < _order.size():
		return String(_order[i])
	return ""

func _persist_to_db() -> void:
	# Build old/new for logging
	var prev_first = ""
	var prev_second = ""
	var prev_third = ""
	var prev_fourth = ""
	if _last_persisted_order.size() > 0:
		prev_first = String(_last_persisted_order[0])
	if _last_persisted_order.size() > 1:
		prev_second = String(_last_persisted_order[1])
	if _last_persisted_order.size() > 2:
		prev_third = String(_last_persisted_order[2])
	if _last_persisted_order.size() > 3:
		prev_fourth = String(_last_persisted_order[3])

	var cur_first  = _order_value_at(0)
	var cur_second = _order_value_at(1)
	var cur_third  = _order_value_at(2)
	var cur_fourth = _order_value_at(3)

	# Prepare Update_Records payload (single Array argument; each entry has the 4 required keys)
	var updates: Array = [
		{"table": "Party", "record_id": party_record_id, "field": "First_Turn",  "value": cur_first},
		{"table": "Party", "record_id": party_record_id, "field": "Second_Turn", "value": cur_second},
		{"table": "Party", "record_id": party_record_id, "field": "Third_Turn",  "value": cur_third},
		{"table": "Party", "record_id": party_record_id, "field": "Fourth_Turn", "value": cur_fourth}
	]

	# Update DB
	if party_record_id != 0:
		# Adjust to your Update_Records signature if needed (pk field default is "id" per your config)
		Global.Update_Records(updates)
		# Log it (per your preference to log confirm actions)
		# Build logs
		var old_vals: Dictionary = {
			"First_turn": prev_first,
			"Second_turn": prev_second,
			"Third_turn": prev_third,
			"Fourth_turn": prev_fourth
		}
		var new_vals: Dictionary = {
			"First_turn": cur_first,
			"Second_turn": cur_second,
			"Third_turn": cur_third,
			"Fourth_turn": cur_fourth
		}
		var meta: Dictionary = {
			"source": "PlayerHub/TurnOrderPanel",
			"order": _order.duplicate(true)
		}
		Global.Log(
			"TurnOrder",
			"Updated party turn order",
			"Party",
			str(party_record_id),
			old_vals,
			new_vals,
			meta,
			"success",
			"audit"
		)
		# Update snapshot for next diff
	_last_persisted_order = [cur_first, cur_second, cur_third, cur_fourth]

# --------------- Public accessors ---------------

func get_current_order() -> Array:
	return _order.duplicate()
