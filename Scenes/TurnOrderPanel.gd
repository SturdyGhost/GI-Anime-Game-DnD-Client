extends Panel
var raw
var db_order
# Public API you set from PlayerHub:
# - party_record_id: which Party row to update
# - active_complete_party: the 4 names in order (strings)
@export var party_record_id: int = 0
var active_complete_party: Array = []  # ["Brian C.","Brian F.","Dylan","Yae Miko"]

@onready var OrderList = $OrderList
var _last_persisted_order: Array = []  # snapshot for Log old_values


func _ready() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	

func _on_data_load_complete():
	raw = Global.Current_Party.get("Turn_Order")
	db_order = JSON.parse_string(str(raw))

	# Optional: de-dup and strip empties just in case
	db_order = db_order.filter(func(n): return typeof(n) == TYPE_STRING and n.strip_edges() != "")
	db_order = db_order.duplicate(true)
	_set_order(db_order)


# Call this once you have the party names
func set_party(names: Array) -> void:
	_set_order(names)



# ----------------- UI Build -----------------

func _set_order(names: Array) -> void:
	db_order = names.duplicate(true)
	_rebuild_rows()
	if Global.Current_Party.get("Turn_Order")!= db_order:
		_persist_to_db()

func _rebuild_rows() -> void:
	# Clear
	for c in OrderList.get_children():
		c.queue_free()

	# Build rows
	for i in db_order.size():
		var row := _make_row(db_order[i], i)
		OrderList.add_child(row)

func _make_row(name: String, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_" + str(index)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 0

	# DRAG+DROP: attach lightweight row behavior
	row.set_script(preload("res://Scenes/TurnOrderRow.gd"))
	row.call("init_row", name, index)
	row.connect("reorder_requested", Callable(self, "_on_row_reorder_requested"))
	row.connect("bump_requested", Callable(self, "_on_row_bump_requested"))

	# Visuals
	var label := Label.new()
	label.name = "Name"
	label.text = name
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(400,28)
	label.size_flags_horizontal = Control.SIZE_EXPAND
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
	_move_inplace(db_order,from_index,to_index)
	_rebuild_rows()
	_persist_to_db()
	

func _on_row_bump_requested(index: int, delta: int) -> void:
	var to_index = index + delta
	if to_index < 0:
		to_index = db_order.size()-1
	if to_index > db_order.size()-1:
		to_index = 0
	print("Move from:" + str(index) +" to: " + str(to_index))
	_on_row_reorder_requested(index, to_index)


func _move_inplace(arr: Array, from_index: int, to_index: int) -> void:
	var item = arr[from_index]
	arr.remove_at(from_index)         # returns void in Godot 4.x
	arr.insert(to_index, item)
# ----------------- Persistence -----------------

func _order_value_at(i: int) -> String:
	if i >= 0 and i < db_order.size():
		return String(db_order[i])
	return ""

func _persist_to_db() -> void:
	# ---- Build old/new for logging ----
	var prev_order: Array = []
	if _last_persisted_order is Array:
		prev_order = _last_persisted_order.duplicate(true)

	var cur_order: Array = []
	# Ensure _order is a clean Array of strings
	for i in db_order.size():
		var v = db_order[i]
		if typeof(v) == TYPE_STRING:
			cur_order.append(v)
		else:
			cur_order.append(String(v))

	# ---- Prepare Update_Records payload ----
	# Single field now: Turn_Order (send as an Array; your Flask/Noco stack will JSON-encode this)
	var updates: Array = [
		{"table": "Party", "record_id": party_record_id, "field": "Turn_Order", "value": db_order},
		{"table": "Party", "record_id": party_record_id, "field": "Current_Turn", "value": db_order[0]}
	]

	# ---- Update DB ----
	if party_record_id != 0:
		Global.Update_Records(updates)

		# ---- Log it ----
		var old_vals: Dictionary = {"Turn_Order": prev_order}
		var new_vals: Dictionary = {"Turn_Order": cur_order}
		var meta: Dictionary = {
			"source": "PlayerHub/TurnOrderPanel",
			"order_len": cur_order.size()
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

		# Snapshot for next diff
	_last_persisted_order = cur_order.duplicate(true)

# --------------- Public accessors ---------------

func get_current_order() -> Array:
	return db_order.duplicate()
