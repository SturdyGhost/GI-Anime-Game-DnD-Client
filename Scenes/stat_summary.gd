extends Control

var SelectedStat: String = ""

var Sources: Dictionary = {}

# Live, temporary spinbox state
var _init_skill: int = 0
var _init_base: int = 0
var _curr_skill: int = 0
var _curr_base: int = 0
var _unspent_skill: int = 0
var _unspent_base: int = 0
var current_stat_key: String
var total_value: float = 0.0

# Override values (kept as floats; empty/invalid input = 0.0)
var AddEdit: float = 0.0
var MultEdit: float = 0.0
var RollAddEdit: float = 0.0
var RollMultEdit: float = 0.0
var DmgAddEdit: float = 0.0
var DmgMultEdit: float = 0.0
var _orig_vals: Dictionary
var updates: Array = []
var new_vals 

@onready var TotalAmountLabel = $TotalAmountLabel

# Onready refs to the LineEdits so we can connect signals
@onready var AddedEditNode      : LineEdit = $OverridesMargin/OverridesGrid/AddedEdit
@onready var MultEditNode       : LineEdit = $OverridesMargin/OverridesGrid/MultEdit
@onready var RollAddedEditNode  : LineEdit = $OverridesMargin/OverridesGrid/RollAddedEdit
@onready var RollMultEditNode   : LineEdit = $OverridesMargin/OverridesGrid/RollMultEdit
@onready var DmgAddedEditNode   : LineEdit = $OverridesMargin/OverridesGrid/DmgAddedEdit
@onready var DmgMultEditNode    : LineEdit = $OverridesMargin/OverridesGrid/DmgMultEdit

const BREAKDOWN_ITEM_SCENE = preload("res://Scenes/StatBreakdownItem.tscn")

func _ready() -> void:
	_orig_vals = _build_values_snapshot()
	if not $RowPoints/SkillPts.value_changed.is_connected(_on_skill_spin_changed):
		$RowPoints/SkillPts.value_changed.connect(_on_skill_spin_changed)
	if not $RowPoints/StatPts.value_changed.is_connected(_on_base_spin_changed):
		$RowPoints/StatPts.value_changed.connect(_on_base_spin_changed)

	# Wire override fields (text change + submit + focus exit) -> update variables
	_connect_override_field(AddedEditNode,      "_on_override_changed", "Add")
	_connect_override_field(MultEditNode,       "_on_override_changed", "Mult")
	_connect_override_field(RollAddedEditNode,  "_on_override_changed", "RollAdd")
	_connect_override_field(RollMultEditNode,   "_on_override_changed", "RollMult")
	_connect_override_field(DmgAddedEditNode,   "_on_override_changed", "DmgAdd")
	_connect_override_field(DmgMultEditNode,    "_on_override_changed", "DmgMult")

func _build_values_snapshot() -> Dictionary:
	return {
		"skill":           int(_curr_skill),
		"base":            int(_curr_base),
		"unspent_skill":   int(_unspent_skill),
		"unspent_base":    int(_unspent_base),
		"add":             roundf(AddEdit * 1000.0) / 1000.0,
		"mult":            roundf(MultEdit * 1000.0) / 1000.0,
		"radd":            roundf(RollAddEdit * 1000.0) / 1000.0,
		"rmult":           roundf(RollMultEdit * 1000.0) / 1000.0,
		"dadd":            roundf(DmgAddEdit * 1000.0) / 1000.0,
		"dmult":           roundf(DmgMultEdit * 1000.0) / 1000.0,
	}

func _process(delta: float) -> void:
	# This mirrors your running total preview based on point deltas
	TotalAmountLabel.text = str((total_value
		+ ((_curr_skill - _init_skill) * Global.scaling[SelectedStat])
		+ ((_curr_base  - _init_base)  * Global.scaling[SelectedStat])
		+ AddEdit)*(1+MultEdit))

func update_stat_summary(stat) -> void:
	SelectedStat = stat
	$Title.text = stat + " Stat Summary"
	var breakdown_container: Node = $BreakdownContainer
	_clear_children(breakdown_container)
	Sources.clear()

	# --- Resolve active character data ---
	var char_name: String = Global.ACTIVE_USER_NAME
	var char_data: Dictionary = Global.CHARACTERS[Global.CHARACTERS_NAME[char_name]]

	# Snapshot incoming values for temporary editing
	_init_skill = int(char_data.get("%s_Skill_Points" % SelectedStat, 0))
	_init_base  = int(char_data.get("%s_Base_Points"  % SelectedStat, 0))
	_curr_skill = _init_skill
	_curr_base  = _init_base
	_unspent_skill = int(char_data.get("Unspent_Skill_Points", 0))
	_unspent_base  = int(char_data.get("Unspent_Base_Points", 0))

	# --- Update headers/labels ---
	_update_unspent_labels()

	$RowPoints/SkillPts.value = _curr_skill
	$RowPoints/StatPts.value  = _curr_base

	# Configure spinboxes according to live caps
	_configure_skill_spinbox()
	_configure_base_spinbox()

	# --- Overrides UI (load stored text) ---
	AddedEditNode.text     = _to_text(char_data.get("%s_Manual_Added_Amount_Override"         % SelectedStat, null))
	MultEditNode.text      = _to_text(char_data.get("%s_Manual_Multiplier_Amount_Override"    % SelectedStat, null))
	RollAddedEditNode.text = _to_text(char_data.get("%s_Manual_Roll_Added_Amount_Override"    % SelectedStat, null))
	RollMultEditNode.text  = _to_text(char_data.get("%s_Manual_Roll_Multiplier_Amount_Override"% SelectedStat, null))
	DmgAddedEditNode.text  = _to_text(char_data.get("%s_Manual_Damage_Added_Amount_Override"  % SelectedStat, null))
	DmgMultEditNode.text   = _to_text(char_data.get("%s_Manual_Damage_Multiplier_Amount_Override"% SelectedStat, null))

	# Sync variables from the freshly loaded fields
	_sync_override_vars_from_fields()

	# --- Total label from Global.Current_{Stat} ---
	current_stat_key = "Current_%s" % SelectedStat
	total_value = float(Global.get(current_stat_key))
	$TotalAmountLabel.text = str(total_value)

	# --- Base & Skill points (apply scaling) ---
	var scaling_value: float = float(Global.scaling.get(SelectedStat, 1.0))
	var base_pts_val: float  = float(_init_base)  * scaling_value
	var skill_pts_val: float = float(_init_skill) * scaling_value

	if base_pts_val != 0.0:
		Sources["Base Stat Points"] = base_pts_val
	if skill_pts_val != 0.0:
		Sources["Skill Stat Points"] = skill_pts_val

	# --- Artifact direct stats ---
	_add_artifact_direct_stats(char_name)

	# --- Artifact set bonuses ---
	_add_artifact_set_bonuses(char_data)

	# --- Weapon stats ---
	_add_weapon_stats(char_name)

	# --- Populate breakdown list ---
	for src_key in Sources.keys():
		var item = BREAKDOWN_ITEM_SCENE.instantiate()
		item.get_node("GridContainer/SourceLabel").text = src_key + ":"
		var amt_label = item.get_node("GridContainer/AmountLabel")
		amt_label.text = str(Sources[src_key])
		amt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		$BreakdownContainer.add_child(item)


# =========================
# SpinBox logic
# =========================

func _configure_skill_spinbox() -> void:
	var sb: SpinBox = $RowPoints/SkillPts
	sb.step = 1
	sb.min_value = _init_skill
	sb.max_value = _curr_skill + _unspent_skill
	sb.editable = true

func _configure_base_spinbox() -> void:
	var sb: SpinBox = $RowPoints/StatPts
	sb.step = 1
	sb.min_value = _init_base
	sb.max_value = _curr_base + _unspent_base
	sb.editable = true

func _on_skill_spin_changed(value: float) -> void:
	var new_val = int(round(value))
	var delta = new_val - _curr_skill
	if delta == 0:
		return

	if delta > 0:
		var spend = min(delta, _unspent_skill)
		_unspent_skill -= spend
		_curr_skill += spend
	else:
		var refund_cap = _curr_skill - _init_skill
		var refund = min(-delta, refund_cap)
		_unspent_skill += refund
		_curr_skill -= refund

	$RowPoints/SkillPts.value = _curr_skill
	_configure_skill_spinbox()
	_update_unspent_labels()

func _on_base_spin_changed(value: float) -> void:
	var new_val = int(round(value))
	var delta = new_val - _curr_base
	if delta == 0:
		return

	if delta > 0:
		var spend = min(delta, _unspent_base)
		_unspent_base -= spend
		_curr_base += spend
	else:
		var refund_cap = _curr_base - _init_base
		var refund = min(-delta, refund_cap)
		_unspent_base += refund
		_curr_base -= refund

	$RowPoints/StatPts.value = _curr_base
	_configure_base_spinbox()
	_update_unspent_labels()

func _update_unspent_labels() -> void:
	$UnspentSkillPointsLabel.text = "Unspent Skill Points: " + str(_unspent_skill)
	$UnspentSkillPointsLabel2.text = "Unspent Base Points: " + str(_unspent_base)


# =========================
# Overrides: wiring + handlers
# =========================

func _connect_override_field(le: LineEdit, method_name: String, key: String) -> void:
	if not le.text_changed.is_connected(Callable(self, method_name).bind(key)):
		le.text_changed.connect(Callable(self, method_name).bind(key))
	if not le.text_submitted.is_connected(Callable(self, "_on_override_submitted").bind(key)):
		le.text_submitted.connect(Callable(self, "_on_override_submitted").bind(key))
	if not le.focus_exited.is_connected(Callable(self, "_on_override_focus_exited").bind(key)):
		le.focus_exited.connect(Callable(self, "_on_override_focus_exited").bind(key))

func _on_override_changed(new_text: String, key: String) -> void:
	_set_override_var(key, _parse_number(new_text))

func _on_override_submitted(new_text: String, key: String) -> void:
	_set_override_var(key, _parse_number(new_text))

func _on_override_focus_exited(key: String) -> void:
	# Re-parse on blur to be safe
	var txt = _get_override_node_text(key)
	_set_override_var(key, _parse_number(txt))

func _get_override_node_text(key: String) -> String:
	if key == "Add":
		return AddedEditNode.text
	if key == "Mult":
		return MultEditNode.text
	if key == "RollAdd":
		return RollAddedEditNode.text
	if key == "RollMult":
		return RollMultEditNode.text
	if key == "DmgAdd":
		return DmgAddedEditNode.text
	return DmgMultEditNode.text

func _set_override_var(key: String, v: float) -> void:
	if key == "Add":
		AddEdit = v
	elif key == "Mult":
		MultEdit = v
	elif key == "RollAdd":
		RollAddEdit = v
	elif key == "RollMult":
		RollMultEdit = v
	elif key == "DmgAdd":
		DmgAddEdit = v
	elif key == "DmgMult":
		DmgMultEdit = v

func _sync_override_vars_from_fields() -> void:
	AddEdit     = _parse_number(AddedEditNode.text)
	MultEdit    = _parse_number(MultEditNode.text)
	RollAddEdit = _parse_number(RollAddedEditNode.text)
	RollMultEdit= _parse_number(RollMultEditNode.text)
	DmgAddEdit  = _parse_number(DmgAddedEditNode.text)
	DmgMultEdit = _parse_number(DmgMultEditNode.text)

func _parse_number(s: String) -> float:
	var t = s.strip_edges()
	if t == "":
		return 0.0
	# Allow users to type things like ".5"
	if t.begins_with("."):
		t = "0" + t
	var v = t.to_float()
	# If it didn't parse (NaN), to_float returns 0.0 anyway; keep it simple.
	return v


# =========================
# Data sources
# =========================

func _add_artifact_direct_stats(char_name: String) -> void:
	if typeof(Global.CHARACTER_ARTIFACTS) != TYPE_DICTIONARY:
		return
	for art in Global.CHARACTER_ARTIFACTS.values():
		if typeof(art) != TYPE_DICTIONARY:
			continue
		if art.get("Owner") != char_name or not _is_equipped(art.get("Equipped")):
			continue
		var src_key: String = str(art.get("Type", "Artifact"))
		if art.get("Stat_1_Type") == SelectedStat:
			Sources[src_key] = Sources.get(src_key, 0.0) + float(art.get("Stat_1_Value", 0.0))
		if art.get("Stat_2_Type") == SelectedStat:
			Sources[src_key] = Sources.get(src_key, 0.0) + float(art.get("Stat_2_Value", 0.0))

func _add_artifact_set_bonuses(char_data: Dictionary) -> void:
	if typeof(Global.set_count) != TYPE_DICTIONARY:
		return
	if typeof(Global.ARTIFACTS) != TYPE_DICTIONARY:
		return

	for set_name in Global.set_count.keys():
		var pieces = int(Global.set_count.get(set_name, 0))
		if pieces < 2:
			continue

		for art_info in Global.ARTIFACTS.values():
			if typeof(art_info) != TYPE_DICTIONARY:
				continue
			if art_info.get("Artifact_Set") != set_name:
				continue

			var needed = int(art_info.get("Bonus_Type", 0))
			if pieces < needed:
				continue

			# Condition: null/empty treated as no condition
			var cond_field = art_info.get("Condition", null)
			var has_condition = cond_field != null and str(cond_field) != ""
			var condition_ok = true
			if has_condition:
				var expected = art_info.get("Condition_Value", null)
				var actual = char_data.get(cond_field, null)
				condition_ok = actual != null and expected != null and actual == expected
			if not condition_ok:
				continue

			# Stat_Modifier is a STRING like "Health_Added_Stat_Bonus"
			# Value lives in Stat_Modifier_Value
			var mod_key = str(art_info.get("Stat_Modifier", ""))
			if mod_key == "":
				continue
			var target_key = "%s_Added_Stat_Bonus" % SelectedStat
			if mod_key != target_key:
				continue

			var bonus_val = float(art_info.get("Stat_Modifier_Value", 0.0))
			if bonus_val == 0.0:
				continue

			var src_key = "%s %s-Piece Set Bonus" % [set_name, needed]  # e.g., "Gladiator 2"
			Sources[src_key] = Sources.get(src_key, 0.0) + bonus_val

func _add_weapon_stats(char_name: String) -> void:
	if typeof(Global.CHARACTER_WEAPONS) != TYPE_DICTIONARY:
		return
	for weapon in Global.CHARACTER_WEAPONS.values():
		if typeof(weapon) != TYPE_DICTIONARY:
			continue
		if weapon.get("Owner") != char_name or not _is_equipped(weapon.get("Equipped")):
			continue
		var src_key: String = str(weapon.get("Weapon", "Weapon"))
		for i in range(1, 4):
			if weapon.get("Stat_%d_Type" % i) == SelectedStat:
				Sources[src_key] = Sources.get(src_key, 0.0) + float(weapon.get("Stat_%d_Value" % i, 0.0))


# =========================
# Utils + Confirm
# =========================

func _is_equipped(val) -> bool:
	if val == true:
		return true
	var s = str(val).to_lower()
	return s == "true" or s == "1" or s == "yes"

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _to_text(val) -> String:
	return "" if val == null else str(val)

# Helper: queue a single field update for the Characters table
func _queue_update(char_id, field: String, value) -> void:
	var rec: Dictionary = {
		"table": "Characters",
		"record_id": float(char_id),
		"field": field,
		"value": value
	}
	updates.append(rec)


func _on_exit_button_pressed() -> void:
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()
	pass # Replace with function body.


func _on_confirm_button_pressed() -> void:
	new_vals = _build_values_snapshot()
	var char_id = Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]

	# Build batch of updates (DB is the source of truth)
	updates = []
	# Points
	_queue_update(char_id, "%s_Skill_Points" % SelectedStat, int(_curr_skill))
	_queue_update(char_id, "%s_Base_Points"  % SelectedStat, int(_curr_base))
	_queue_update(char_id, "Unspent_Skill_Points", int(_unspent_skill))
	_queue_update(char_id, "Unspent_Base_Points",  int(_unspent_base))
	# Overrides
	_queue_update(char_id, "%s_Manual_Added_Amount_Override"            % SelectedStat, float(AddEdit))
	_queue_update(char_id, "%s_Manual_Multiplier_Amount_Override"       % SelectedStat, float(MultEdit))
	_queue_update(char_id, "%s_Manual_Roll_Added_Amount_Override"       % SelectedStat, float(RollAddEdit))
	_queue_update(char_id, "%s_Manual_Roll_Multiplier_Amount_Override"  % SelectedStat, float(RollMultEdit))
	_queue_update(char_id, "%s_Manual_Damage_Added_Amount_Override"     % SelectedStat, float(DmgAddEdit))
	_queue_update(char_id, "%s_Manual_Damage_Multiplier_Amount_Override"% SelectedStat, float(DmgMultEdit))

	# Write to DB
	Global.Update_Records(updates)

	# (Optional) mirror into in-memory cache so UI reflects saved values immediately
	var char_name: String = char_id
	var char_data: Dictionary = Global.CHARACTERS.get(char_name, {})
	char_data["%s_Skill_Points" % SelectedStat] = _curr_skill
	char_data["%s_Base_Points"  % SelectedStat] = _curr_base
	char_data["Unspent_Skill_Points"] = _unspent_skill
	char_data["Unspent_Base_Points"]  = _unspent_base
	char_data["%s_Manual_Added_Amount_Override"            % SelectedStat] = AddEdit
	char_data["%s_Manual_Multiplier_Amount_Override"       % SelectedStat] = MultEdit
	char_data["%s_Manual_Roll_Added_Amount_Override"       % SelectedStat] = RollAddEdit
	char_data["%s_Manual_Roll_Multiplier_Amount_Override"  % SelectedStat] = RollMultEdit
	char_data["%s_Manual_Damage_Added_Amount_Override"     % SelectedStat] = DmgAddEdit
	char_data["%s_Manual_Damage_Multiplier_Amount_Override"% SelectedStat] = DmgMultEdit
	Global.CHARACTERS[char_name] = char_data

	# Recalculate + log
	Global.calculate_all_stats()
	get_parent().get_parent().set_ui()
	
	Global.Log(
	"character",                     # category
	"%s Changed" % SelectedStat,     # action
	"Stats",                         # related_type
	str(SelectedStat),               # related_id (string is safest)
	_orig_vals,                      # old_values
	new_vals)                         # new_values

	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()
	pass # Replace with function body.
