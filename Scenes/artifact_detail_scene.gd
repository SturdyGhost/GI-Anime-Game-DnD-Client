extends Control

# Point this to your ArtifactListItem.tscn
@export var RowScene: PackedScene = preload("res://Scenes/artifact_list_item.tscn")

const ARTIFACT_TABLE := "Character_Artifacts"

@onready var SearchBar: LineEdit       = $VBoxContainer/SearchBar
@onready var SearchDebounce: Timer     = $SearchDebounce
@onready var HeaderRow: Control        = $VBoxContainer/ArtifactHeaderRow
@onready var ListParent: VBoxContainer = $VBoxContainer/ArtifactListContainer/ArtifactListContainer
@onready var ConfirmButton: Button     = $VBoxContainer/ConfirmButton
@onready var ExitButton: Button        = $ExitButton
@onready var CurrentArtifactPreview = $CurrentArtifactPreview
@onready var SelectedArtifactPreview = $SelectedArtifactPreview

var previouslogslot
var currentlogslot

var selected_artifact: Dictionary = {}   # current selection


# Header buttons -> sort keys (must match your header child names)
const HEADER_TO_KEY := {
	"NameButton":        "Name",
	"TypeButton":        "Type",
	"Stat1Button":       "Stat1",
	"Stat1ValueButton":  "Stat1Value",
	"Stat2Button":       "Stat2",
	"Stat2ValueButton":  "Stat2Value",
	"2PieceSetButton":   "TwoPiece",
	"4PieceSetButton":   "FourPiece",
	"EquippedButton":    "Equipped",
}

# Short -> full type names
const TYPE_MAP := {
	"Flower":  "Flower of Life",
	"Feather": "Feather of Death",
	"Sands":   "Sands of Time",
	"Goblet":  "Goblet of Space",
	"Circlet": "Circlet of Principles",
}

var _slot_type: String = ""
var _rows: Array = []                 # Array<Dictionary>
var _sort_key: String = "Name"
var _sort_asc: bool = true

func _ready() -> void:
	# signals
	SearchBar.text_changed.connect(_on_search_changed)
	SearchDebounce.timeout.connect(_on_search_timeout)
	for child in HeaderRow.get_children():
		if child is Button:
			var key = HEADER_TO_KEY.get(child.name, "")
			if key != "":
				child.pressed.connect(Callable(self, "_on_header_pressed").bind(key))
	# optional initial paint (empty until open_for_* is called)
	_refresh_list()
	

# --- call one of these from your hub ---
func open_for_slot(short_name: String) -> void:
	_slot_type = TYPE_MAP.get(short_name, short_name)
	_build_rows()
	_refresh_list()

func open_for_type(full_name: String) -> void:
	_slot_type = full_name
	_build_rows()
	_refresh_list()

# ---------- build data ----------
func _build_rows() -> void:
	_rows.clear()
	var owner = Global.ACTIVE_USER_NAME

	# Index set bonuses once: {set_name: text}
	var two_by_set := {}
	var four_by_set := {}
	for rid in Global.ARTIFACTS.keys():
		var r: Dictionary = Global.ARTIFACTS[rid]
		var set_name := str(r.get("Artifact_Set", ""))
		var bonus := int(_num(r.get("Bonus_Type", 0)))
		var effect := str(r.get("Effect", ""))
		if bonus == 2:
			two_by_set[set_name] = effect
		elif bonus == 4:
			four_by_set[set_name] = effect

	for record_id in Global.CHARACTER_ARTIFACTS.keys():
		var a: Dictionary = Global.CHARACTER_ARTIFACTS[record_id]
		if str(a.get("Owner","")) != owner:
			continue
		if str(a.get("Type","")) != _slot_type:
			continue

		var set_name := str(a.get("Artifact_Set",""))

		# --- handle missing second stat cleanly ---
		var s2_type_raw = a.get("Stat_2_Type", null)
		var s2_val_raw  = a.get("Stat_2_Value", null)
		var has_s2 = (s2_type_raw != null) and (s2_val_raw != null)
		var s2_type  = str(s2_type_raw) if has_s2 else ""
		var s2_value = _num(s2_val_raw)  if has_s2 else null

		_rows.append({
			"RecordID":   record_id,
			"Name":       set_name,
			"Type":       str(a.get("Type","")),
			"Stat1":      str(a.get("Stat_1_Type","")),
			"Stat1Value": _num(a.get("Stat_1_Value", 0.0)),
			"Stat2":      s2_type,      # "" when missing
			"Stat2Value": s2_value,     # null when missing
			"TwoPiece":   str(two_by_set.get(set_name, "")),
			"FourPiece":  str(four_by_set.get(set_name, "")),
			"Equipped":   a.get("Equipped"),
			"Rarity":     int(_num(a.get("Rarity",0))),
		})

	_rows.sort_custom(Callable(self, "_compare_rows"))

# ---------- list render ----------
func _refresh_list() -> void:
	if ListParent == null:
		return
	for c in ListParent.get_children():
		ListParent.remove_child(c)
		c.queue_free()

	var filtered := _apply_search(_rows)
	filtered.sort_custom(Callable(self, "_compare_rows"))

	if RowScene == null:
		var lbl := Label.new()
		lbl.text = "Assign RowScene (ArtifactListItem.tscn) in the Inspector."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ListParent.add_child(lbl)
		return

	for row in filtered:
		var item = RowScene.instantiate()
		ListParent.add_child(item)

		item.set_meta("row", row)

		var chk = item.get_node_or_null("EquipCheck") as CheckBox
		if chk:
			chk.pressed.connect(Callable(self, "_on_row_check_pressed").bind(item))

		item.call_deferred("set_data", row)
		item.call_deferred("set_highlight", SearchBar.text.strip_edges())  # ← add this

	# once all rows are ready, reflect initial "Equipped"
	call_deferred("_apply_initial_selection")

func _apply_initial_selection() -> void:
	# wait one frame so all call_deferred(set_data) have run
	await get_tree().process_frame
	selected_artifact.clear()
	var picked := false
	for item in ListParent.get_children():
		var row = item.get_meta("row") if item.has_meta("row") else {}
		var should_check := false
		if typeof(row) == TYPE_DICTIONARY:
			var eq = row.get("Equipped", null)
			should_check = (eq != null and bool(eq)) and not picked
		_set_item_checked(item, should_check)
		if should_check and typeof(row) == TYPE_DICTIONARY:
			selected_artifact = row.duplicate(true)
			picked = true
	SelectedArtifactPreview.original_artifact = selected_artifact
	CurrentArtifactPreview.set_stats(selected_artifact)
	SelectedArtifactPreview.set_stats(selected_artifact)


# ---------- checkbox handler ----------
func _on_row_check_pressed(item: Node) -> void:
	var chk = item.get_node_or_null("EquipCheck") as CheckBox
	var row = item.get_meta("row") if item.has_meta("row") else {}
	if chk == null or typeof(row) != TYPE_DICTIONARY:
		return
	var is_on = chk.button_pressed
	if is_on:
		selected_artifact = row.duplicate(true)
		# uncheck all others
		for other in ListParent.get_children():
			if other != item:
				_set_item_checked(other, false)
	else:
		# deselect if it was the selected one
		if not selected_artifact.is_empty() and selected_artifact.get("RecordID","") == row.get("RecordID",""):
			selected_artifact.clear()
	SelectedArtifactPreview.set_stats(selected_artifact)
	if selected_artifact == {}:
		print ("Artifact selected is empty")
	print (selected_artifact)


# ---------- search ----------
func _on_search_changed(_t: String) -> void:
	SearchDebounce.start()

func _on_search_timeout() -> void:
	_refresh_list()

func _apply_search(rows: Array) -> Array:
	var q := SearchBar.text.strip_edges().to_lower()
	if q == "":
		return rows
	var out: Array = []
	for r in rows:
		var hay = [
			str(r["Name"]),
			str(r["Type"]),
			str(r["Stat1"]),
			_fmt_num(r["Stat1Value"]),
			str(r["Stat2"]),
			_fmt_num(r["Stat2Value"]),
			str(r["TwoPiece"]),
			str(r["FourPiece"]),
		]
		var hit := false
		for h in hay:
			if h.to_lower().find(q) != -1:
				hit = true
				break
		if hit:
			out.append(r)
	return out

# ---------- sort ----------
func _on_header_pressed(key: String) -> void:
	if _sort_key == key:
		_sort_asc = not _sort_asc
	else:
		_sort_key = key
		_sort_asc = true
	_refresh_list()

func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	var av = _sort_value(a, _sort_key)
	var bv = _sort_value(b, _sort_key)
	return av < bv if _sort_asc else av > bv

func _sort_value(r: Dictionary, key: String):
	match key:
		"Name":       return str(r["Name"]).to_lower()
		"Type":       return str(r["Type"]).to_lower()
		"Stat1":      return str(r["Stat1"]).to_lower()
		"Stat1Value": return _num(r["Stat1Value"])
		"Stat2":      return str(r["Stat2"]).to_lower()
		"Stat2Value": return _num(r["Stat2Value"])
		"TwoPiece":   return str(r["TwoPiece"]).to_lower()
		"FourPiece":  return str(r["FourPiece"]).to_lower()
		"Equipped":   return 0 if r["Equipped"] else 1
		_:            return str(r.get(key,"")).to_lower()

# ---------- helpers ----------
func _set_item_checked(item: Node, on: bool) -> void:
	var chk := item.get_node_or_null("EquipCheck") as CheckBox
	if chk:
		chk.button_pressed = on

func _num(v):
	var t := typeof(v)
	if t == TYPE_FLOAT or t == TYPE_INT:
		return v
	if t == TYPE_NIL:
		return 0.0
	return str(v).to_float()

func _fmt_num(v) -> String:
	return "%+0.2f" % _num(v)

# buttons
func _on_exit_button_pressed() -> void:
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

# replace your stub with this:
func _on_confirm_button_pressed() -> void:
	var owner = Global.ACTIVE_USER_NAME
	var slot  = _slot_type
	var updates: Array = []
	var previous_equipped: String = ""  # to store old artifact ID for logging

	# must have a picked row
	if selected_artifact.is_empty():
		for rid in Global.CHARACTER_ARTIFACTS.keys():
			var rec: Dictionary = Global.CHARACTER_ARTIFACTS[rid]
			if str(rec.get("Owner","")) != owner: continue
			if str(rec.get("Type",""))  != slot:  continue
			if rec.get("Equipped", false) == true:
				previous_equipped = str(rid)
			updates.append({
				"table": ARTIFACT_TABLE,
				"record_id": _id_num(rid),
				"field": "Equipped",
				"value": false
			})
		Global.Update_Records(updates)
		
		# Log unequip action
		if previous_equipped != "":
			Global.Log(
				"equipment",
				"unequip_artifact",
				"Artifact",
				previous_equipped,
				{"slot": slot, "previous": Global.CHARACTER_ARTIFACTS[previous_equipped]},
				{"slot": slot, "current": null}
			)
		var p := get_parent()
		if p is Window:
			p.queue_free()
		else:
			queue_free()
		return

	var selected_id: String = str(selected_artifact.get("RecordID", ""))
	if selected_id == "":
		return

	# Build updates:
	for rid in Global.CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = Global.CHARACTER_ARTIFACTS[rid]
		if str(rec.get("Owner","")) != owner: continue
		if str(rec.get("Type",""))  != slot:  continue
		if rec.get("Equipped", false) == true:
			previous_equipped = str(rid)
		if str(rid) == selected_id:
			continue  # do 'true' as the final op
		updates.append({
			"table": ARTIFACT_TABLE,
			"record_id": _id_num(rid),
			"field": "Equipped",
			"value": false
		})

	# finally, equip the selected one
	updates.append({
		"table": ARTIFACT_TABLE,
		"record_id": _id_num(selected_id),
		"field": "Equipped",
		"value": true
	})

	# Fire the batched update
	Global.Update_Records(updates)

	# Optimistic UI update
	for item in ListParent.get_children():
		_set_item_checked(item, false)
	for item in ListParent.get_children():
		if item.has_meta("row"):
			var row = item.get_meta("row")
			if typeof(row) == TYPE_DICTIONARY and str(row.get("RecordID","")) == selected_id:
				_set_item_checked(item, true)
				break
	if previous_equipped != null and previous_equipped != "":
		previouslogslot = {"slot": slot, "previous": Global.CHARACTER_ARTIFACTS[previous_equipped]}
	else:
		previouslogslot = {"slot": slot, "previous": null}
	
	if selected_id != null and selected_id != "":
		currentlogslot = {"slot": slot, "current": Global.CHARACTER_ARTIFACTS[selected_id]}
	else:
		currentlogslot = {"slot": slot, "previous": null}
	# Log equip change
	Global.Log(
		"equipment",
		"equip_artifact",
		"Artifact",
		selected_id,
		previouslogslot,
		currentlogslot
	)
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()


func _id_num(v) -> float:
	# Your API example used float(char_id). Assuming numeric record ids:
	# Convert safely from string/int to float. If your ids are non-numeric,
	# change the backend to accept strings and pass str(v) instead.
	return str(v).to_float()
