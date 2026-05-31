extends Control

# ── Theme colors ────────────────────────────────────────────────────────────
const BG_DEEP   = Color(0.039, 0.051, 0.075)
const BG_PANEL  = Color(0.071, 0.086, 0.118)
const BG_CARD   = Color(0.102, 0.122, 0.169)
const BG_INSET  = Color(0.055, 0.067, 0.098)
const BORDER    = Color(0.165, 0.188, 0.251)
const TEXT      = Color(0.941, 0.949, 0.973)
const TEXT_SEC  = Color(0.69, 0.722, 0.8)
const TEXT_MUTED = Color(0.533, 0.573, 0.659)
const ACCENT    = Color(0.788, 0.659, 0.298)

const FONT_SM  = 40
const FONT_MD  = 45
const FONT_LG  = 52
const FONT_XL  = 62
const FONT_XXL = 72

# ── State ───────────────────────────────────────────────────────────────────
var SelectedStat: String = ""
var Sources: Dictionary = {}

var _init_skill: int = 0
var _init_base: int = 0
var _curr_skill: int = 0
var _curr_base: int = 0
var _unspent_skill: int = 0
var _unspent_base: int = 0
var current_stat_key: String
var _split_left: HSplitContainer
var _split_right: HSplitContainer
var total_value: float = 0.0

var AddEdit: float = 0.0
var MultEdit: float = 0.0
var RollAddEdit: float = 0.0
var RollMultEdit: float = 0.0
var DmgAddEdit: float = 0.0
var DmgMultEdit: float = 0.0
var _orig_vals: Dictionary
var updates: Array = []
var new_vals

# ── Node references (built programmatically) ───────────────────────────────
var _title_label: Label
var _sources_container: VBoxContainer
var _skill_spin: SpinBox
var _base_spin: SpinBox
var _unspent_skill_label: Label
var _unspent_base_label: Label
var _total_label: Label
var _dice_label: Label

var _add_edit: LineEdit
var _mult_edit: LineEdit
var _roll_add_edit: LineEdit
var _roll_mult_edit: LineEdit
var _dmg_add_edit: LineEdit
var _dmg_mult_edit: LineEdit

var _ui_built = false


# ── Lifecycle ───────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _ui_built or _total_label == null:
		return
	var scaling = EntityStats.SCALING.get(SelectedStat.to_lower().replace(" ", "_"), 1.0)
	var preview = (total_value \
		+ ((_curr_skill - _init_skill) * scaling) \
		+ ((_curr_base  - _init_base)  * scaling) \
		+ AddEdit) * (1.0 + MultEdit)
	_total_label.text = str(snapped(preview, 0.01))
	# Update dice badge
	if _dice_label:
		_dice_label.text = _get_dice_string(preview)


# ── Public API ──────────────────────────────────────────────────────────────

func update_stat_summary(stat) -> void:
	SelectedStat = stat
	if not _ui_built:
		_build_ui()
		_load_split_layout.call_deferred()
	_populate_data()


# ── UI Construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	_ui_built = true

	# Full-screen semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Full-screen panel with margins
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 40
	panel.offset_right = -40
	panel.offset_bottom = -40
	_apply_panel_style(panel, BG_DEEP, BORDER, 12)
	add_child(panel)

	var outer_margin = MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 24)
	outer_margin.add_theme_constant_override("margin_right", 24)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(outer_margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	outer_margin.add_child(root_vbox)

	# ── Title bar ───────────────────────────────────────────────────────────
	var title_bar = HBoxContainer.new()
	root_vbox.add_child(title_bar)

	_title_label = _make_label("Stat Summary", FONT_XXL, ACCENT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_title_label)

	var close_btn = _make_button("X", 40, 36)
	close_btn.pressed.connect(_on_exit_button_pressed)
	title_bar.add_child(close_btn)

	# Separator
	root_vbox.add_child(_make_separator())

	# ── 3-Column layout (resizable via nested HSplitContainers) ──────────
	_split_left = HSplitContainer.new()
	_split_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_left.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_split_left.dragged.connect(func(_ofs): _save_split_layout())
	root_vbox.add_child(_split_left)

	# LEFT column — Stat Sources
	var left_card = _make_card()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_card.custom_minimum_size.x = 200
	_split_left.add_child(left_card)
	_build_left_column(left_card)

	# Right side: another split for center + right
	_split_right = HSplitContainer.new()
	_split_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_right.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_split_right.dragged.connect(func(_ofs): _save_split_layout())
	_split_left.add_child(_split_right)

	# CENTER column — Point Allocation
	var center_card = _make_card()
	center_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_card.custom_minimum_size.x = 200
	_split_right.add_child(center_card)
	_build_center_column(center_card)

	# RIGHT column — DM Overrides
	var right_card = _make_card()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.custom_minimum_size.x = 200
	_split_right.add_child(right_card)
	_build_right_column(right_card)

	# ── Bottom bar — Total + Dice + Buttons ─────────────────────────────────
	root_vbox.add_child(_make_separator())
	_build_bottom_bar(root_vbox)


func _build_left_column(parent: PanelContainer) -> void:
	var margin = _make_card_margin()
	parent.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	vbox.add_child(_make_label("Stat Sources", FONT_LG, ACCENT))
	vbox.add_child(_make_separator())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_sources_container = VBoxContainer.new()
	_sources_container.add_theme_constant_override("separation", 4)
	_sources_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sources_container)


func _build_center_column(parent: PanelContainer) -> void:
	var margin = _make_card_margin()
	parent.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	vbox.add_child(_make_label("Point Allocation", FONT_LG, ACCENT))
	vbox.add_child(_make_separator())

	# Skill Points
	vbox.add_child(_make_label("Skill Points", FONT_MD, TEXT_SEC))
	_skill_spin = _make_spinbox()
	vbox.add_child(_skill_spin)
	_unspent_skill_label = _make_label("Unspent: 0", FONT_SM, TEXT_MUTED)
	vbox.add_child(_unspent_skill_label)

	vbox.add_child(_make_spacer(8))

	# Base Points
	vbox.add_child(_make_label("Base Points", FONT_MD, TEXT_SEC))
	_base_spin = _make_spinbox()
	vbox.add_child(_base_spin)
	_unspent_base_label = _make_label("Unspent: 0", FONT_SM, TEXT_MUTED)
	vbox.add_child(_unspent_base_label)

	# Connect signals
	_skill_spin.value_changed.connect(_on_skill_spin_changed)
	_base_spin.value_changed.connect(_on_base_spin_changed)


func _build_right_column(parent: PanelContainer) -> void:
	var margin = _make_card_margin()
	parent.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	vbox.add_child(_make_label("DM Overrides", FONT_LG, ACCENT))
	vbox.add_child(_make_separator())

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	_add_edit      = _add_override_row(grid, "Added Amount",      "e.g. 10",   "Add")
	_mult_edit     = _add_override_row(grid, "Multiplier",        "e.g. 0.25", "Mult")
	_roll_add_edit = _add_override_row(grid, "Roll Added",        "e.g. 3",    "RollAdd")
	_roll_mult_edit= _add_override_row(grid, "Roll Multiplier",   "e.g. 0.10", "RollMult")
	_dmg_add_edit  = _add_override_row(grid, "Damage Added",      "e.g. 5",    "DmgAdd")
	_dmg_mult_edit = _add_override_row(grid, "Damage Multiplier", "e.g. 0.50", "DmgMult")


func _build_bottom_bar(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(hbox)

	hbox.add_child(_make_label("Total:", FONT_XL, ACCENT))

	_total_label = _make_label("0", FONT_XL, TEXT)
	hbox.add_child(_total_label)

	# Dice badge
	var dice_badge = PanelContainer.new()
	_apply_panel_style(dice_badge, BG_CARD, BORDER, 6)
	hbox.add_child(dice_badge)

	var dice_margin = MarginContainer.new()
	dice_margin.add_theme_constant_override("margin_left", 10)
	dice_margin.add_theme_constant_override("margin_right", 10)
	dice_margin.add_theme_constant_override("margin_top", 4)
	dice_margin.add_theme_constant_override("margin_bottom", 4)
	dice_badge.add_child(dice_margin)

	_dice_label = _make_label("D4", FONT_MD, ACCENT)
	dice_margin.add_child(_dice_label)

	# Spacer to push buttons right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var cancel_btn = _make_button("Cancel", 100, 38)
	cancel_btn.pressed.connect(_on_exit_button_pressed)
	hbox.add_child(cancel_btn)

	var confirm_btn = _make_button("Confirm", 100, 38)
	# Give confirm a slightly different accent style
	var confirm_style = _make_stylebox(Color(0.15, 0.18, 0.25), ACCENT, 6)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	var confirm_hover = _make_stylebox(Color(0.18, 0.22, 0.30), ACCENT, 6)
	confirm_btn.add_theme_stylebox_override("hover", confirm_hover)
	confirm_btn.pressed.connect(_on_confirm_button_pressed)
	hbox.add_child(confirm_btn)


# ── Populate data ───────────────────────────────────────────────────────────

func _populate_data() -> void:
	_title_label.text = SelectedStat.replace("_", " ") + " Summary"

	# Clear sources
	_clear_children(_sources_container)
	Sources.clear()

	# Resolve active character
	var char_name: String = Global.ACTIVE_USER_NAME
	var _cid = Global.CHARACTERS_NAME.get(char_name, "")
	var char_data: Dictionary = Global.CHARACTERS.get(_cid, {})

	# Snapshot point values
	_init_skill = int(char_data.get("%s_Skill_Points" % SelectedStat, 0))
	_init_base  = int(char_data.get("%s_Base_Points"  % SelectedStat, 0))
	_curr_skill = _init_skill
	_curr_base  = _init_base
	_unspent_skill = int(char_data.get("Unspent_Skill_Points", 0))
	_unspent_base  = int(char_data.get("Unspent_Base_Points", 0))

	# Update spinboxes
	_skill_spin.value = _curr_skill
	_base_spin.value  = _curr_base
	_configure_skill_spinbox()
	_configure_base_spinbox()
	_update_unspent_labels()

	# Load override fields
	_add_edit.text      = _to_text(char_data.get("%s_Manual_Added_Amount_Override"            % SelectedStat, null))
	_mult_edit.text     = _to_text(char_data.get("%s_Manual_Multiplier_Amount_Override"       % SelectedStat, null))
	_roll_add_edit.text = _to_text(char_data.get("%s_Manual_Roll_Added_Amount_Override"       % SelectedStat, null))
	_roll_mult_edit.text= _to_text(char_data.get("%s_Manual_Roll_Multiplier_Amount_Override"  % SelectedStat, null))
	_dmg_add_edit.text  = _to_text(char_data.get("%s_Manual_Damage_Added_Amount_Override"     % SelectedStat, null))
	_dmg_mult_edit.text = _to_text(char_data.get("%s_Manual_Damage_Multiplier_Amount_Override"% SelectedStat, null))
	_sync_override_vars_from_fields()

	# Total from Global
	current_stat_key = "Current_%s" % SelectedStat
	total_value = float(Global.get(current_stat_key))

	# Build sources
	var scaling_value: float = float(EntityStats.SCALING.get(SelectedStat.to_lower().replace(" ", "_"), 1.0))
	var base_pts_val: float  = float(_init_base)  * scaling_value
	var skill_pts_val: float = float(_init_skill) * scaling_value

	if base_pts_val != 0.0:
		Sources["Base Stat Points"] = base_pts_val
	if skill_pts_val != 0.0:
		Sources["Skill Stat Points"] = skill_pts_val

	_add_artifact_direct_stats(char_name)
	_add_artifact_set_bonuses(char_data)

	var weapon_data = null
	var weapon_info = null
	for weapon in Global.CHARACTER_WEAPONS.values():
		if weapon.get("Owner") == Global.ACTIVE_USER_NAME and weapon.get("Equipped") == true:
			weapon_info = weapon
			weapon_data = Global.WEAPONS[Global.WEAPONS_NAME[weapon.get("Weapon")]]

	if weapon_data != null and weapon_data.get("Stat_Modifier") != null:
		_add_weapon_effect_bonuses(weapon_data)

	_add_weapon_stats(char_name)

	# Populate source rows
	for src_key in Sources.keys():
		_add_source_row(src_key, Sources[src_key])

	if Sources.is_empty():
		var empty_lbl = _make_label("No contributions", FONT_SM, TEXT_MUTED)
		_sources_container.add_child(empty_lbl)

	# Snapshot original values
	_orig_vals = _build_values_snapshot()


func _add_source_row(source_name: String, value) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl = _make_label(source_name, FONT_SM, TEXT_SEC)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var val_lbl = _make_label(str(value), FONT_SM, TEXT)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	_sources_container.add_child(row)


# ── SpinBox logic ───────────────────────────────────────────────────────────

func _configure_skill_spinbox() -> void:
	_skill_spin.step = 1
	_skill_spin.min_value = _init_skill
	_skill_spin.max_value = _curr_skill + _unspent_skill
	_skill_spin.editable = true

func _configure_base_spinbox() -> void:
	_base_spin.step = 1
	_base_spin.min_value = _init_base
	_base_spin.max_value = _curr_base + _unspent_base
	_base_spin.editable = true

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
	_skill_spin.value = _curr_skill
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
	_base_spin.value = _curr_base
	_configure_base_spinbox()
	_update_unspent_labels()

func _update_unspent_labels() -> void:
	_unspent_skill_label.text = "Unspent: " + str(_unspent_skill)
	_unspent_base_label.text  = "Unspent: " + str(_unspent_base)


# ── Override fields ─────────────────────────────────────────────────────────

func _add_override_row(grid: GridContainer, label_text: String, placeholder: String, key: String) -> LineEdit:
	var lbl = _make_label(label_text, FONT_SM, TEXT_SEC)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(lbl)

	var le = LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(90, 30)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(le)
	grid.add_child(le)

	le.text_changed.connect(Callable(self, "_on_override_changed").bind(key))
	le.text_submitted.connect(Callable(self, "_on_override_submitted").bind(key))
	le.focus_exited.connect(Callable(self, "_on_override_focus_exited").bind(key))
	return le

func _on_override_changed(new_text: String, key: String) -> void:
	_set_override_var(key, _parse_number(new_text))

func _on_override_submitted(new_text: String, key: String) -> void:
	_set_override_var(key, _parse_number(new_text))

func _on_override_focus_exited(key: String) -> void:
	var txt = _get_override_node_text(key)
	_set_override_var(key, _parse_number(txt))

func _get_override_node_text(key: String) -> String:
	match key:
		"Add":     return _add_edit.text
		"Mult":    return _mult_edit.text
		"RollAdd": return _roll_add_edit.text
		"RollMult":return _roll_mult_edit.text
		"DmgAdd":  return _dmg_add_edit.text
		_:         return _dmg_mult_edit.text

func _set_override_var(key: String, v: float) -> void:
	match key:
		"Add":      AddEdit = v
		"Mult":     MultEdit = v
		"RollAdd":  RollAddEdit = v
		"RollMult": RollMultEdit = v
		"DmgAdd":   DmgAddEdit = v
		"DmgMult":  DmgMultEdit = v

func _sync_override_vars_from_fields() -> void:
	AddEdit      = _parse_number(_add_edit.text)
	MultEdit     = _parse_number(_mult_edit.text)
	RollAddEdit  = _parse_number(_roll_add_edit.text)
	RollMultEdit = _parse_number(_roll_mult_edit.text)
	DmgAddEdit   = _parse_number(_dmg_add_edit.text)
	DmgMultEdit  = _parse_number(_dmg_mult_edit.text)

func _parse_number(s: String) -> float:
	var t = s.strip_edges()
	if t == "":
		return 0.0
	if t.begins_with("."):
		t = "0" + t
	return t.to_float()


# ── Data sources ────────────────────────────────────────────────────────────

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
			var cond_field = art_info.get("Condition", null)
			var has_condition = cond_field != null and str(cond_field) != ""
			var condition_ok = true
			if has_condition:
				var expected = art_info.get("Condition_Value", null)
				var actual = char_data.get(cond_field, null)
				condition_ok = actual != null and expected != null and actual == expected
			if not condition_ok:
				continue
			var mod_key = str(art_info.get("Stat_Modifier", ""))
			if mod_key == "":
				continue
			var target_key = "%s_Added_Stat_Bonus" % SelectedStat
			if mod_key != target_key:
				continue
			var bonus_val = float(art_info.get("Stat_Modifier_Value", 0.0))
			if bonus_val == 0.0:
				continue
			var src_key = "%s %s-Piece Set Bonus" % [set_name, needed]
			Sources[src_key] = Sources.get(src_key, 0.0) + bonus_val

func _add_weapon_effect_bonuses(weapon_data: Dictionary) -> void:
	var stat = weapon_data.get("Stat_Modifier")
	var value = weapon_data.get("Stat_Modifier_Value")
	var added = "%s_Added_Stat_Bonus" % SelectedStat
	var multiplier = "%s_Multiplier_Stat_Bonus" % SelectedStat
	if stat.contains(SelectedStat):
		match stat:
			added:
				Sources["Weapon Effect"] = Sources.get("Weapon Effect", 0.0) + value
			multiplier:
				Sources["Weapon Effect"] = "x" + str(Sources.get("Weapon Effect", 1.0) + value)

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


# ── Dice notation ───────────────────────────────────────────────────────────

const DICE_SET = [4, 6, 8, 10, 12, 20]

func _get_dice_string(stat_val: float) -> String:
	var s = int(stat_val)
	if s < 4:
		return "D4"
	if s >= 24:
		var remainder = s - 20
		var bonus = 4
		for i in range(DICE_SET.size() - 1, -1, -1):
			if DICE_SET[i] <= remainder:
				bonus = DICE_SET[i]
				break
		return "D20 + D%d" % bonus
	for i in range(DICE_SET.size() - 1, -1, -1):
		if DICE_SET[i] <= s:
			return "D%d" % DICE_SET[i]
	return "D4"


# ── Utils + Confirm ─────────────────────────────────────────────────────────

func _build_values_snapshot() -> Dictionary:
	return {
		"skill":         int(_curr_skill),
		"base":          int(_curr_base),
		"unspent_skill": int(_unspent_skill),
		"unspent_base":  int(_unspent_base),
		"add":           roundf(AddEdit * 1000.0) / 1000.0,
		"mult":          roundf(MultEdit * 1000.0) / 1000.0,
		"radd":          roundf(RollAddEdit * 1000.0) / 1000.0,
		"rmult":         roundf(RollMultEdit * 1000.0) / 1000.0,
		"dadd":          roundf(DmgAddEdit * 1000.0) / 1000.0,
		"dmult":         roundf(DmgMultEdit * 1000.0) / 1000.0,
	}

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

func _queue_update(char_id, field: String, value) -> void:
	updates.append({
		"table": "Characters",
		"record_id": int(char_id),
		"field": field,
		"value": value
	})

func _on_exit_button_pressed() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

func _on_confirm_button_pressed() -> void:
	new_vals = _build_values_snapshot()
	var char_id = Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]

	updates = []
	_queue_update(char_id, "%s_Skill_Points" % SelectedStat, int(_curr_skill))
	_queue_update(char_id, "%s_Base_Points"  % SelectedStat, int(_curr_base))
	_queue_update(char_id, "Unspent_Skill_Points", int(_unspent_skill))
	_queue_update(char_id, "Unspent_Base_Points",  int(_unspent_base))
	_queue_update(char_id, "%s_Manual_Added_Amount_Override"            % SelectedStat, float(AddEdit))
	_queue_update(char_id, "%s_Manual_Multiplier_Amount_Override"       % SelectedStat, float(MultEdit))
	_queue_update(char_id, "%s_Manual_Roll_Added_Amount_Override"       % SelectedStat, float(RollAddEdit))
	_queue_update(char_id, "%s_Manual_Roll_Multiplier_Amount_Override"  % SelectedStat, float(RollMultEdit))
	_queue_update(char_id, "%s_Manual_Damage_Added_Amount_Override"     % SelectedStat, float(DmgAddEdit))
	_queue_update(char_id, "%s_Manual_Damage_Multiplier_Amount_Override"% SelectedStat, float(DmgMultEdit))

	Global.Update_Records(updates)

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

	Global.calculate_all_stats()
	get_parent().get_parent().set_ui()

	Global.Log(
		"character",
		"%s Changed" % SelectedStat,
		"Stats",
		str(SelectedStat),
		_orig_vals,
		new_vals
	)

	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()


# ── Widget factory helpers ──────────────────────────────────────────────────

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	var style = StyleBoxLine.new()
	style.color = BORDER
	style.thickness = 1
	sep.add_theme_stylebox_override("separator", style)
	return sep

func _make_spacer(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _make_card() -> PanelContainer:
	var card = PanelContainer.new()
	_apply_panel_style(card, BG_CARD, BORDER, 8)
	return card

func _make_card_margin() -> MarginContainer:
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	return m

func _make_stylebox(bg_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(6)
	return sb

func _apply_panel_style(panel: PanelContainer, bg_color: Color, border_color: Color, radius: int) -> void:
	var sb = _make_stylebox(bg_color, border_color, radius)
	panel.add_theme_stylebox_override("panel", sb)

func _make_button(text: String, min_w: int, min_h: int) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, min_h)
	btn.add_theme_font_size_override("font_size", FONT_MD)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", ACCENT)

	var normal_sb = _make_stylebox(BG_CARD, BORDER, 6)
	var hover_sb  = _make_stylebox(BG_PANEL, BORDER, 6)
	var pressed_sb = _make_stylebox(BG_INSET, BORDER, 6)
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", _make_stylebox(BG_CARD, ACCENT, 6))
	return btn

func _make_spinbox() -> SpinBox:
	var sb = SpinBox.new()
	sb.step = 1
	sb.min_value = 0
	sb.max_value = 99
	sb.alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb.custom_minimum_size = Vector2(0, 32)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	sb.add_theme_font_size_override("font_size", FONT_MD)
	sb.add_theme_color_override("font_color", TEXT)

	# Style the internal LineEdit
	var le: LineEdit = sb.get_line_edit()
	_style_line_edit(le)

	return sb

func _style_line_edit(le: LineEdit) -> void:
	le.add_theme_font_size_override("font_size", FONT_MD)
	le.add_theme_color_override("font_color", TEXT)
	le.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	le.add_theme_color_override("caret_color", ACCENT)
	le.add_theme_color_override("selection_color", Color(ACCENT, 0.3))

	var normal_sb = _make_stylebox(BG_INSET, BORDER, 4)
	normal_sb.set_content_margin_all(4)
	le.add_theme_stylebox_override("normal", normal_sb)

	var focus_sb = _make_stylebox(BG_INSET, ACCENT, 4)
	focus_sb.set_content_margin_all(4)
	le.add_theme_stylebox_override("focus", focus_sb)



func _save_split_layout() -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://ui_settings.cfg")
	cfg.set_value("stat_layout", "split_left", _split_left.split_offset)
	cfg.set_value("stat_layout", "split_right", _split_right.split_offset)
	cfg.save("user://ui_settings.cfg")

func _load_split_layout() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		if cfg.has_section_key("stat_layout", "split_left"):
			_split_left.split_offset = cfg.get_value("stat_layout", "split_left", 0)
		if cfg.has_section_key("stat_layout", "split_right"):
			_split_right.split_offset = cfg.get_value("stat_layout", "split_right", 0)
