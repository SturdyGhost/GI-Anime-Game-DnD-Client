extends Control

# =============================================================================
# Weapon Detail Scene — full rewrite
# =============================================================================

# ---- Theme palette ----
# Lighter blue palette — no near-black backgrounds
const BG_DEEP   = Color(0.102, 0.122, 0.169)
const BG_PANEL  = Color(0.133, 0.157, 0.22)
const BG_CARD   = Color(0.165, 0.192, 0.27)
const BG_INSET  = Color(0.09, 0.11, 0.155)
const BG_HOVER  = Color(0.19, 0.22, 0.30)
const BORDER    = Color(0.22, 0.25, 0.33)
const TEXT      = Color(0.96, 0.96, 0.98)
const TEXT_SEC  = Color(0.78, 0.80, 0.87)
const TEXT_MUT  = Color(0.58, 0.62, 0.71)
const ACCENT    = Color(0.788, 0.659, 0.298)
const GREEN     = Color(0.292, 0.855, 0.498)
const RED       = Color(0.937, 0.267, 0.267)

const FONT_BODY   = 15
const FONT_HEADER = 18
const FONT_TITLE  = 20
const FONT_MIN    = 14
const ROW_H       = 34
const MARGIN      = 40

# ---- Column definitions ----
const COLUMNS = [
	{"key": "Name",       "label": "Name",       "ratio": 0.15, "filter": "text"},
	{"key": "Type",       "label": "Type",       "ratio": 0.08, "filter": "check"},
	{"key": "Region",     "label": "Region",     "ratio": 0.09, "filter": "check"},
	{"key": "Refinement", "label": "Refine",     "ratio": 0.06, "filter": "text"},
	{"key": "Stat1",      "label": "Stat 1",     "ratio": 0.10, "filter": "check"},
	{"key": "Stat2",      "label": "Stat 2",     "ratio": 0.10, "filter": "check"},
	{"key": "Stat3",      "label": "Stat 3",     "ratio": 0.10, "filter": "check"},
	{"key": "Effect",     "label": "Effect",     "ratio": 0.18, "filter": "text"},
	{"key": "Equipped",   "label": "Equipped",   "ratio": 0.06, "filter": "check"},
]

# ---- State ----
var selected_weapon: Dictionary = {}
var equipped_weapon: Dictionary = {}
var weapon_rows: Array = []
var current_sort_key: String = ""
var sort_ascending: bool = true
var search_text: String = ""
var column_filters: Dictionary = {}
var _confirm_locked = false

# ---- Nodes ----
var search_bar: LineEdit
var header_hbox: HBoxContainer
var scroll_container: ScrollContainer
var row_vbox: VBoxContainer
var error_label: Label
var card_equipped: PanelContainer
var card_selected: PanelContainer
var receiver_option: OptionButton
var give_btn: Button
var equip_btn: Button
var exit_btn: Button
var close_btn: Button
var _main_split: VSplitContainer

# Filter popover
var active_popover: PanelContainer = null
var active_popover_key: String = ""

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	_init_filters()
	_build_ui()
	_populate_weapons()
	_populate_receivers()
	_refresh_previews()
	_load_split_layout.call_deferred()

func _init_filters() -> void:
	for col in COLUMNS:
		if col.filter == "text":
			column_filters[col.key] = {"active": false, "value": ""}
		else:
			column_filters[col.key] = {"active": false, "value": {}}

# =============================================================================
# UI CONSTRUCTION
# =============================================================================
func _build_ui() -> void:
	# Full-screen background
	var bg = Panel.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _flat(BG_DEEP))
	add_child(bg)

	# Main margin container
	var outer = MarginContainer.new()
	outer.set_anchors_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", MARGIN)
	outer.add_theme_constant_override("margin_right", MARGIN)
	outer.add_theme_constant_override("margin_top", MARGIN)
	outer.add_theme_constant_override("margin_bottom", MARGIN)
	add_child(outer)

	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 10)
	outer.add_child(main_vbox)

	# ---- 1. Title bar ----
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(title_row)

	var title_label = Label.new()
	title_label.text = "WEAPONS"
	title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	title_label.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(title_label)

	var title_spacer = Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_spacer)

	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(36, 36)
	_style_btn(close_btn, false)
	close_btn.pressed.connect(_close_scene)
	title_row.add_child(close_btn)

	# ---- 2. Search bar ----
	search_bar = LineEdit.new()
	search_bar.placeholder_text = "Search weapons..."
	search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(search_bar)
	search_bar.text_changed.connect(_on_search_changed)
	main_vbox.add_child(search_bar)

	# ---- 3. Table + Preview in resizable split ----
	_main_split = VSplitContainer.new()
	_main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_main_split.dragged.connect(func(_ofs): _save_split_layout())
	main_vbox.add_child(_main_split)

	# Top half: table
	var table_section = VBoxContainer.new()
	table_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_split.add_child(table_section)

	header_hbox = HBoxContainer.new()
	header_hbox.custom_minimum_size.y = 38
	header_hbox.add_theme_constant_override("separation", 0)
	table_section.add_child(header_hbox)
	_build_header_row()

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_section.add_child(scroll_container)

	row_vbox = VBoxContainer.new()
	row_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.add_theme_constant_override("separation", 0)
	scroll_container.add_child(row_vbox)

	error_label = Label.new()
	error_label.add_theme_color_override("font_color", RED)
	error_label.add_theme_font_size_override("font_size", FONT_BODY)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	table_section.add_child(error_label)

	# Bottom half: preview cards
	var card_row = HBoxContainer.new()
	card_row.custom_minimum_size.y = 160
	card_row.add_theme_constant_override("separation", 16)
	card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_split.add_child(card_row)

	card_equipped = _build_card("Currently Equipped")
	card_equipped.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.add_child(card_equipped)

	card_selected = _build_card("Selected")
	card_selected.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.add_child(card_selected)

	# ---- 5. Footer ----
	var footer = HBoxContainer.new()
	footer.custom_minimum_size.y = 48
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(footer)

	# Give section
	var give_label = Label.new()
	give_label.text = "Give to:"
	give_label.add_theme_font_size_override("font_size", FONT_BODY)
	give_label.add_theme_color_override("font_color", TEXT)
	give_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(give_label)

	receiver_option = OptionButton.new()
	receiver_option.custom_minimum_size.x = 180
	_style_option_button(receiver_option)
	footer.add_child(receiver_option)

	give_btn = Button.new()
	give_btn.text = "Give"
	give_btn.custom_minimum_size.x = 90
	_style_btn(give_btn, false)
	give_btn.pressed.connect(_on_give_pressed)
	footer.add_child(give_btn)

	# Spacer between give and equip sections
	var footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	exit_btn = Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size.x = 90
	_style_btn(exit_btn, false)
	exit_btn.pressed.connect(_close_scene)
	footer.add_child(exit_btn)

	equip_btn = Button.new()
	equip_btn.text = "Equip Selected"
	equip_btn.custom_minimum_size.x = 150
	_style_btn(equip_btn, false)
	equip_btn.pressed.connect(_on_equip_pressed)
	footer.add_child(equip_btn)

# =============================================================================
# HEADER ROW
# =============================================================================
func _build_header_row() -> void:
	for child in header_hbox.get_children():
		child.queue_free()
	for col in COLUMNS:
		var btn = Button.new()
		btn.text = col.label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_stretch_ratio = col.ratio
		btn.custom_minimum_size.y = 38
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		var sb_n = _flat(BG_INSET)
		sb_n.border_width_bottom = 2
		sb_n.border_color = BORDER
		sb_n.content_margin_left = 6
		sb_n.content_margin_right = 6
		btn.add_theme_stylebox_override("normal", sb_n)
		var sb_h = sb_n.duplicate()
		sb_h.bg_color = BG_HOVER
		btn.add_theme_stylebox_override("hover", sb_h)
		var sb_p = sb_n.duplicate()
		sb_p.bg_color = BG_HOVER.lightened(0.1)
		btn.add_theme_stylebox_override("pressed", sb_p)
		btn.add_theme_color_override("font_color", ACCENT)
		btn.add_theme_color_override("font_hover_color", ACCENT)
		btn.add_theme_color_override("font_pressed_color", ACCENT)
		btn.add_theme_font_size_override("font_size", FONT_HEADER)

		var col_key = col.key
		btn.pressed.connect(_on_header_sort.bind(col_key))
		btn.gui_input.connect(_on_header_right_click.bind(col_key, btn))
		header_hbox.add_child(btn)

func _refresh_header_labels() -> void:
	for i in range(COLUMNS.size()):
		var btn: Button = header_hbox.get_child(i)
		var col = COLUMNS[i]
		var suffix = ""
		if current_sort_key == col.key:
			suffix += " ^" if sort_ascending else " v"
		if column_filters.has(col.key) and column_filters[col.key].active:
			suffix += " *"
		btn.text = col.label + suffix

func _on_header_sort(col_key: String) -> void:
	if current_sort_key == col_key:
		sort_ascending = not sort_ascending
	else:
		current_sort_key = col_key
		sort_ascending = true
	_sort_rows()
	_refresh_header_labels()

func _on_header_right_click(event: InputEvent, col_key: String, btn: Button) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_toggle_filter_popover(col_key, btn)
		btn.accept_event()

# =============================================================================
# TABLE ROWS
# =============================================================================
func _populate_weapons() -> void:
	for c in row_vbox.get_children():
		c.queue_free()
	weapon_rows.clear()
	selected_weapon = {}
	equipped_weapon = {}

	for data in Global.CHARACTER_WEAPONS.values():
		if data.get("Owner") == Global.ACTIVE_USER_NAME and data.get("Quantity", 0) > 0:
			_add_row(data)
			if data.get("Equipped", false):
				equipped_weapon = data

	_apply_filters()
	_refresh_previews()

func _row_plain(data: Dictionary) -> Dictionary:
	return {
		"Name": str(data.get("Weapon", "Unnamed")),
		"Type": str(data.get("Type", "")),
		"Region": str(data.get("Region", "")),
		"Refinement": str(data.get("Refinement", 1)),
		"Stat1": _safe_str(data.get("Stat_1_Type")),
		"Stat2": _safe_str(data.get("Stat_2_Type")),
		"Stat3": _safe_str(data.get("Stat_3_Type")),
		"Effect": str(data.get("Effect", "")),
		"Equipped": "Yes" if data.get("Equipped", false) else "No",
	}

func _add_row(data: Dictionary) -> void:
	var plain = _row_plain(data)

	# Seed check-filter unique values
	for col in COLUMNS:
		if col.filter == "check":
			var v = plain.get(col.key, "")
			if not column_filters[col.key].value.has(v):
				column_filters[col.key].value[v] = true

	var idx = weapon_rows.size()
	var row_bg = BG_CARD if idx % 2 == 0 else BG_PANEL

	var row_panel = Panel.new()
	row_panel.custom_minimum_size.y = ROW_H
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = _flat(row_bg)
	sb.border_width_left = 3
	sb.border_color = Color.TRANSPARENT
	sb.content_margin_left = 3
	row_panel.add_theme_stylebox_override("panel", sb)
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	row_panel.gui_input.connect(_on_row_click.bind(idx))
	row_panel.mouse_entered.connect(_on_row_enter.bind(idx))
	row_panel.mouse_exited.connect(_on_row_exit.bind(idx))

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_panel.add_child(hbox)

	var cells: Dictionary = {}
	for col in COLUMNS:
		var margin = MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.size_flags_stretch_ratio = col.ratio
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 4)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var cell = Label.new()
		cell.text = plain.get(col.key, "")
		cell.clip_text = true
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_font_size_override("font_size", FONT_BODY)
		cell.add_theme_color_override("font_color", TEXT)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(cell)
		hbox.add_child(margin)
		cells[col.key] = cell

	row_vbox.add_child(row_panel)
	weapon_rows.append({"data": data, "panel": row_panel, "cells": cells, "plain": plain, "row_bg": row_bg})

func _on_row_click(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_row(idx)

func _on_row_enter(idx: int) -> void:
	var row = weapon_rows[idx]
	var sb = row.panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sb.bg_color = BG_HOVER
	row.panel.add_theme_stylebox_override("panel", sb)

func _on_row_exit(idx: int) -> void:
	var row = weapon_rows[idx]
	var is_sel = (row.data == selected_weapon)
	var sb = row.panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sb.bg_color = BG_CARD if is_sel else row.row_bg
	sb.border_color = ACCENT if is_sel else Color.TRANSPARENT
	row.panel.add_theme_stylebox_override("panel", sb)

func _select_row(idx: int) -> void:
	selected_weapon = weapon_rows[idx].data
	for i in range(weapon_rows.size()):
		var row = weapon_rows[i]
		var is_sel = (i == idx)
		var sb = row.panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		sb.bg_color = BG_CARD if is_sel else row.row_bg
		sb.border_color = ACCENT if is_sel else Color.TRANSPARENT
		sb.border_width_left = 3
		row.panel.add_theme_stylebox_override("panel", sb)
	_update_selected_preview()

# =============================================================================
# SEARCH + FILTER
# =============================================================================
func _on_search_changed(new_text: String) -> void:
	search_text = new_text.strip_edges()
	_apply_filters()

func _apply_filters() -> void:
	var tokens = search_text.to_lower().split(" ", false)
	for row in weapon_rows:
		var show = true
		# Search bar
		if not tokens.is_empty():
			var blob = ""
			for col in COLUMNS:
				blob += str(row.plain.get(col.key, "")) + "|"
			blob = blob.to_lower()
			for t in tokens:
				if t != "" and blob.findn(t) == -1:
					show = false
					break
		# Column filters
		if show:
			for col in COLUMNS:
				var f = column_filters.get(col.key)
				if f == null or not f.active:
					continue
				var cell_val = str(row.plain.get(col.key, ""))
				if col.filter == "text":
					if f.value != "" and cell_val.to_lower().findn(f.value.to_lower()) == -1:
						show = false
						break
				else:
					if f.value.has(cell_val) and not f.value[cell_val]:
						show = false
						break
		row.panel.visible = show

# =============================================================================
# SORTING
# =============================================================================
func _sort_rows() -> void:
	if current_sort_key == "":
		return
	weapon_rows.sort_custom(_compare_rows)
	for i in range(weapon_rows.size()):
		row_vbox.move_child(weapon_rows[i].panel, i)

func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	var av = str(a.plain.get(current_sort_key, ""))
	var bv = str(b.plain.get(current_sort_key, ""))
	# Try numeric
	if av.is_valid_float() and bv.is_valid_float():
		var af = float(av)
		var bf = float(bv)
		return af < bf if sort_ascending else af > bf
	var cmp = av.nocasecmp_to(bv)
	return cmp < 0 if sort_ascending else cmp > 0

# =============================================================================
# FILTER POPOVERS
# =============================================================================
func _toggle_filter_popover(col_key: String, anchor: Button) -> void:
	if active_popover != null:
		_close_popover()
		if active_popover_key == col_key:
			return
	active_popover_key = col_key

	var col_def: Dictionary = {}
	for c in COLUMNS:
		if c.key == col_key:
			col_def = c
			break

	var popover = PanelContainer.new()
	var psb = _flat(BG_PANEL)
	psb.border_color = BORDER
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(6)
	psb.content_margin_left = 10
	psb.content_margin_right = 10
	psb.content_margin_top = 10
	psb.content_margin_bottom = 10
	popover.add_theme_stylebox_override("panel", psb)
	popover.z_index = 100

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	popover.add_child(vbox)

	var ftitle = Label.new()
	ftitle.text = "Filter: " + col_def.get("label", col_key)
	ftitle.add_theme_font_size_override("font_size", FONT_BODY)
	ftitle.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(ftitle)

	if col_def.filter == "text":
		var le = LineEdit.new()
		le.placeholder_text = "Type to filter..."
		le.custom_minimum_size.x = 180
		_style_line_edit(le)
		le.text = column_filters[col_key].value if column_filters.has(col_key) else ""
		le.text_changed.connect(_on_col_text_filter.bind(col_key))
		vbox.add_child(le)
		le.grab_focus.call_deferred()
	else:
		var unique = _collect_unique(col_key)
		var existing = column_filters[col_key].value if column_filters.has(col_key) else {}
		if unique.size() > 0:
			var sc = ScrollContainer.new()
			sc.custom_minimum_size = Vector2(200, min(unique.size() * 30, 250))
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			vbox.add_child(sc)
			var cvbox = VBoxContainer.new()
			cvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cvbox.add_theme_constant_override("separation", 2)
			sc.add_child(cvbox)
			for val in unique:
				var cb = CheckBox.new()
				cb.text = val if val != "" else "(empty)"
				cb.button_pressed = existing.get(val, true)
				cb.add_theme_color_override("font_color", TEXT)
				cb.add_theme_font_size_override("font_size", FONT_BODY)
				cb.toggled.connect(_on_col_check_toggled.bind(col_key, val))
				cvbox.add_child(cb)
		var brow = HBoxContainer.new()
		brow.add_theme_constant_override("separation", 4)
		vbox.add_child(brow)
		var all_b = Button.new()
		all_b.text = "All"
		_style_btn_sm(all_b)
		all_b.pressed.connect(_on_filter_all.bind(col_key, true))
		brow.add_child(all_b)
		var none_b = Button.new()
		none_b.text = "None"
		_style_btn_sm(none_b)
		none_b.pressed.connect(_on_filter_all.bind(col_key, false))
		brow.add_child(none_b)

	var clear_b = Button.new()
	clear_b.text = "Clear Filter"
	_style_btn_sm(clear_b)
	clear_b.pressed.connect(_on_clear_filter.bind(col_key))
	vbox.add_child(clear_b)

	add_child(popover)
	active_popover = popover

	await get_tree().process_frame
	var br = anchor.get_global_rect()
	var mr = get_global_rect()
	popover.position = Vector2(br.position.x - mr.position.x, br.position.y - mr.position.y + br.size.y + 2)
	if popover.position.x + popover.size.x > size.x - 10:
		popover.position.x = size.x - popover.size.x - 10

func _close_popover() -> void:
	if active_popover != null and is_instance_valid(active_popover):
		active_popover.queue_free()
	active_popover = null
	active_popover_key = ""

func _input(event: InputEvent) -> void:
	if active_popover == null or not is_instance_valid(active_popover):
		return
	if event is InputEventMouseButton and event.pressed:
		var pr = active_popover.get_global_rect()
		if not pr.has_point(event.global_position):
			_close_popover()

func _collect_unique(col_key: String) -> Array:
	var vals: Array = []
	for row in weapon_rows:
		var v = str(row.plain.get(col_key, ""))
		if not vals.has(v):
			vals.append(v)
	vals.sort()
	return vals

func _on_col_text_filter(new_text: String, col_key: String) -> void:
	var trimmed = new_text.strip_edges()
	column_filters[col_key].value = trimmed
	column_filters[col_key].active = trimmed != ""
	_apply_filters()
	_refresh_header_labels()

func _on_col_check_toggled(pressed: bool, col_key: String, val: String) -> void:
	column_filters[col_key].value[val] = pressed
	var any_off = false
	for k in column_filters[col_key].value:
		if not column_filters[col_key].value[k]:
			any_off = true
			break
	column_filters[col_key].active = any_off
	_apply_filters()
	_refresh_header_labels()

func _on_filter_all(col_key: String, select: bool) -> void:
	for k in column_filters[col_key].value:
		column_filters[col_key].value[k] = select
	column_filters[col_key].active = not select
	# Update checkboxes in popover
	if active_popover != null and is_instance_valid(active_popover):
		var sc = _find_typed(active_popover, "ScrollContainer")
		if sc and sc.get_child_count() > 0:
			for child in sc.get_child(0).get_children():
				if child is CheckBox:
					child.set_pressed_no_signal(select)
	_apply_filters()
	_refresh_header_labels()

func _on_clear_filter(col_key: String) -> void:
	var col_def: Dictionary = {}
	for c in COLUMNS:
		if c.key == col_key:
			col_def = c
			break
	if col_def.filter == "text":
		column_filters[col_key].value = ""
	else:
		for k in column_filters[col_key].value:
			column_filters[col_key].value[k] = true
	column_filters[col_key].active = false
	_close_popover()
	_apply_filters()
	_refresh_header_labels()

func _find_typed(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.get_class() == type_name:
			return child
		var found = _find_typed(child, type_name)
		if found:
			return found
	return null

# =============================================================================
# PREVIEW CARDS
# =============================================================================
func _build_card(title_text: String) -> PanelContainer:
	var card = PanelContainer.new()
	var csb = _flat(BG_CARD)
	csb.border_color = BORDER
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 16
	csb.content_margin_right = 16
	csb.content_margin_top = 12
	csb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", csb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title = Label.new()
	title.name = "CardTitle"
	title.text = title_text
	title.add_theme_font_size_override("font_size", FONT_HEADER)
	title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(title)

	var name_lbl = Label.new()
	name_lbl.name = "WeaponName"
	name_lbl.text = "---"
	name_lbl.add_theme_font_size_override("font_size", FONT_HEADER)
	name_lbl.add_theme_color_override("font_color", TEXT)
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.name = "WeaponType"
	type_lbl.text = ""
	type_lbl.add_theme_font_size_override("font_size", FONT_MIN)
	type_lbl.add_theme_color_override("font_color", TEXT_MUT)
	vbox.add_child(type_lbl)

	var refine_lbl = Label.new()
	refine_lbl.name = "WeaponRefine"
	refine_lbl.text = ""
	refine_lbl.add_theme_font_size_override("font_size", FONT_MIN)
	refine_lbl.add_theme_color_override("font_color", TEXT_SEC)
	vbox.add_child(refine_lbl)

	var sep = HSeparator.new()
	var sep_sb = StyleBoxLine.new()
	sep_sb.color = BORDER
	sep.add_theme_stylebox_override("separator", sep_sb)
	vbox.add_child(sep)

	for i in range(1, 4):
		var sl = Label.new()
		sl.name = "Stat%d" % i
		sl.text = ""
		sl.add_theme_font_size_override("font_size", FONT_BODY)
		sl.add_theme_color_override("font_color", TEXT)
		vbox.add_child(sl)

	var effect_lbl = RichTextLabel.new()
	effect_lbl.name = "EffectText"
	effect_lbl.bbcode_enabled = true
	effect_lbl.fit_content = true
	effect_lbl.scroll_active = false
	effect_lbl.custom_minimum_size.y = 30
	effect_lbl.add_theme_font_size_override("normal_font_size", FONT_MIN)
	effect_lbl.add_theme_color_override("default_color", TEXT_MUT)
	vbox.add_child(effect_lbl)

	# Container for character stat comparison (populated when a weapon is selected)
	var stat_comp = VBoxContainer.new()
	stat_comp.name = "StatComparison"
	stat_comp.add_theme_constant_override("separation", 2)
	vbox.add_child(stat_comp)

	return card

func _refresh_previews() -> void:
	_update_equipped_preview()
	_update_selected_preview()

func _update_equipped_preview() -> void:
	_fill_card(card_equipped, equipped_weapon, false)

func _update_selected_preview() -> void:
	_fill_card(card_selected, selected_weapon, true)
	_update_stat_comparison()

func _fill_card(card: PanelContainer, weapon: Dictionary, show_diff: bool) -> void:
	var name_lbl: Label = card.find_child("WeaponName", true, false)
	var type_lbl: Label = card.find_child("WeaponType", true, false)
	var refine_lbl: Label = card.find_child("WeaponRefine", true, false)
	var effect_lbl: RichTextLabel = card.find_child("EffectText", true, false)

	if weapon.is_empty():
		if name_lbl:
			name_lbl.text = "---"
		if type_lbl:
			type_lbl.text = ""
		if refine_lbl:
			refine_lbl.text = ""
		if effect_lbl:
			effect_lbl.text = ""
		for i in range(1, 4):
			var sl: Label = card.find_child("Stat%d" % i, true, false)
			if sl:
				sl.text = ""
				sl.add_theme_color_override("font_color", TEXT)
		return

	if name_lbl:
		name_lbl.text = str(weapon.get("Weapon", "Unknown"))
	if type_lbl:
		type_lbl.text = str(weapon.get("Type", "")) + "  |  " + str(weapon.get("Region", ""))
	if refine_lbl:
		refine_lbl.text = "Refinement " + str(weapon.get("Refinement", 1))
	if effect_lbl:
		effect_lbl.text = str(weapon.get("Effect", ""))

	# Stats with optional diff coloring
	for i in range(1, 4):
		var sl: Label = card.find_child("Stat%d" % i, true, false)
		if sl == null:
			continue
		var st = weapon.get("Stat_%d_Type" % i)
		var sv = weapon.get("Stat_%d_Value" % i, 0)
		if st == null or str(st) == "":
			sl.text = ""
			sl.add_theme_color_override("font_color", TEXT)
			continue

		if show_diff and not equipped_weapon.is_empty():
			# Find this stat on the equipped weapon
			var eq_val = _get_weapon_stat_value(equipped_weapon, str(st))
			var diff = int(sv) - int(eq_val)
			if diff > 0:
				sl.text = str(st) + ": " + str(sv) + "  (+" + str(diff) + ")"
				sl.add_theme_color_override("font_color", GREEN)
			elif diff < 0:
				sl.text = str(st) + ": " + str(sv) + "  (" + str(diff) + ")"
				sl.add_theme_color_override("font_color", RED)
			else:
				sl.text = str(st) + ": " + str(sv)
				sl.add_theme_color_override("font_color", TEXT)
		else:
			sl.text = str(st) + ": " + str(sv)
			sl.add_theme_color_override("font_color", TEXT)

func _get_weapon_stat_value(weapon: Dictionary, stat_type: String) -> int:
	for i in range(1, 4):
		var st = weapon.get("Stat_%d_Type" % i)
		if st != null and str(st) == stat_type:
			return int(weapon.get("Stat_%d_Value" % i, 0))
	return 0

func _update_stat_comparison() -> void:
	# Show how overall character stats would change with the selected weapon
	var comp_container = card_selected.find_child("StatComparison", true, false)
	if comp_container == null:
		return
	for c in comp_container.get_children():
		c.queue_free()

	if selected_weapon.is_empty() or equipped_weapon.is_empty():
		return

	# Calculate stat differences: for each stat type on either weapon,
	# compute the net change to the character's total
	var stat_changes = {}
	for i in range(1, 4):
		var eq_type = equipped_weapon.get("Stat_%d_Type" % i)
		var eq_raw = equipped_weapon.get("Stat_%d_Value" % i, 0)
		var eq_val = int(eq_raw) if eq_raw != null else 0
		if eq_type != null and str(eq_type) != "":
			stat_changes[str(eq_type)] = stat_changes.get(str(eq_type), 0) - eq_val

		var sel_type = selected_weapon.get("Stat_%d_Type" % i)
		var sel_raw = selected_weapon.get("Stat_%d_Value" % i, 0)
		var sel_val = int(sel_raw) if sel_raw != null else 0
		if sel_type != null and str(sel_type) != "":
			stat_changes[str(sel_type)] = stat_changes.get(str(sel_type), 0) + sel_val

	# Get current character stats for reference
	CharacterManager.recalculate_all()
	var calc = CharacterManager.get_stats(Global.ACTIVE_USER_NAME)

	# Map stat types to display names and current values
	var stat_map = {
		"Health": ["HP", int(calc.health) if calc else 0],
		"Attack": ["ATK", int(calc.attack) if calc else 0],
		"Defense": ["DEF", int(calc.defense) if calc else 0],
		"Elemental_Mastery": ["EM", int(calc.elemental_mastery) if calc else 0],
		"Energy_Recharge": ["ER", int(calc.energy_recharge) if calc else 0],
		"Critical_Damage": ["Crit", int(calc.critical_damage) if calc else 0],
	}

	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _flat(BORDER))
	comp_container.add_child(sep)

	var title = Label.new()
	title.text = "Character Stats If Equipped"
	title.add_theme_font_size_override("font_size", FONT_MIN)
	title.add_theme_color_override("font_color", TEXT_MUT)
	comp_container.add_child(title)

	for stat_key in stat_map:
		var display_name = stat_map[stat_key][0]
		var current_val = stat_map[stat_key][1]
		var diff = stat_changes.get(stat_key, 0)
		var new_val = current_val + diff

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		comp_container.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = display_name
		name_lbl.add_theme_font_size_override("font_size", FONT_MIN)
		name_lbl.add_theme_color_override("font_color", TEXT_MUT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var val_lbl = Label.new()
		val_lbl.add_theme_font_size_override("font_size", FONT_MIN)
		if diff > 0:
			val_lbl.text = "%d → %d (+%d)" % [current_val, new_val, diff]
			val_lbl.add_theme_color_override("font_color", GREEN)
		elif diff < 0:
			val_lbl.text = "%d → %d (%d)" % [current_val, new_val, diff]
			val_lbl.add_theme_color_override("font_color", RED)
		else:
			val_lbl.text = str(current_val)
			val_lbl.add_theme_color_override("font_color", TEXT)
		row.add_child(val_lbl)

# =============================================================================
# RECEIVERS (Give weapon)
# =============================================================================
func _populate_receivers() -> void:
	receiver_option.clear()
	receiver_option.add_item("Nobody")
	for character in Global.PartyCharacters:
		if character != Global.ACTIVE_USER_NAME:
			receiver_option.add_item(character)

# =============================================================================
# EQUIP
# =============================================================================
func _on_equip_pressed() -> void:
	if _confirm_locked:
		return
	_confirm_locked = true

	if selected_weapon.is_empty():
		_show_error("No weapon selected.")
		_confirm_locked = false
		return

	var wtype = selected_weapon.get("Type")
	var char_id = Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]
	var element = Global.CHARACTERS[char_id].get("Element", null)

	var ability_count = 0
	for ability in Global.ACTIVE_ABILITIES.values():
		if ability.get("Weapon_Type") == wtype and ability.get("Element") == element and ability.get("Entity_Type") == "Character" and ability.get("Entity_ID") == Global.ACTIVE_USER_RECORD_ID:
			ability_count += 1

	if ability_count < 1:
		_show_error("There is no valid kit that fits that element and weapon type. Please choose a valid weapon type or update your element.")
		_confirm_locked = false
		return

	error_label.text = ""

	var owner = Global.ACTIVE_USER_NAME
	var target_weapon_name = selected_weapon.get("Weapon")

	var equipped_ids: Array = []
	var target_id: String = ""

	for rec_id in Global.CHARACTER_WEAPONS.keys():
		var cw = Global.CHARACTER_WEAPONS[rec_id]
		if cw.get("Owner") != owner:
			continue
		if cw.get("Equipped", false) == true:
			equipped_ids.append(rec_id)
		if cw.get("Weapon") == target_weapon_name:
			target_id = rec_id

	# Already the only equipped — just close
	if equipped_ids.size() == 1 and equipped_ids[0] == target_id:
		_close_scene()
		_confirm_locked = false
		return

	var old_name = str(equipped_weapon.get("Weapon", equipped_weapon.get("Name", "None")))
	var new_name = str(selected_weapon.get("Weapon", selected_weapon.get("Name", "Unknown")))
	_show_confirm_popup(
		"Equip Weapon",
		"Replace %s with %s?" % [old_name, new_name],
		func():
			var updates: Array = []
			for rec_id in equipped_ids:
				if rec_id == target_id:
					continue
				updates.append({"table": "Character_Weapons", "record_id": int(rec_id), "field": "Equipped", "value": false})
				Global.CHARACTER_WEAPONS[rec_id]["Equipped"] = false
			if target_id != "":
				updates.append({"table": "Character_Weapons", "record_id": int(target_id), "field": "Equipped", "value": true})
				Global.CHARACTER_WEAPONS[target_id]["Equipped"] = true
			Global.Update_Records(updates)
			_do_post_equip(target_id)
	)
	_confirm_locked = false
	return  # The rest happens in the confirm callback

func _do_post_equip(target_id: String) -> void:
	Global.Log(
		"equipment",
		"equip_weapon",
		"Weapon",
		target_id,
		{"type": equipped_weapon.get("Type", ""), "previous": equipped_weapon},
		{"type": selected_weapon.get("Type", ""), "current": selected_weapon}
	)

	await get_tree().create_timer(0.1).timeout
	_confirm_locked = false
	Global.calculate_all_stats()
	_close_scene()

# =============================================================================
# GIVE
# =============================================================================
func _on_give_pressed() -> void:
	if receiver_option.get_selected_id() <= 0:
		return
	if selected_weapon.is_empty() or selected_weapon == equipped_weapon:
		return
	var weapon_name = str(selected_weapon.get("Weapon", selected_weapon.get("Name", "Unknown")))
	var target_name = receiver_option.get_item_text(receiver_option.get_selected_id())
	_show_confirm_popup(
		"Give Weapon",
		"Give %s to %s? This cannot be undone." % [weapon_name, target_name],
		func():
			var updates: Array = []
			updates.append({
				"table": "Character_Weapons",
				"record_id": int(selected_weapon.get("id", 0)),
				"field": "Owner",
				"value": target_name
			})
			Global.Update_Records(updates)
			_close_scene()
	)


func _show_confirm_popup(title: String, message: String, on_confirm: Callable) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 180)
	var sb = _flat(BG_PANEL)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", ACCENT)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var msg_lbl = Label.new()
	msg_lbl.text = message
	msg_lbl.add_theme_font_size_override("font_size", 15)
	msg_lbl.add_theme_color_override("font_color", TEXT)
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(msg_lbl)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size.x = 100
	_style_btn(cancel_btn, false)
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size.x = 100
	_style_btn(confirm_btn, false)
	confirm_btn.add_theme_color_override("font_color", Color(0.937, 0.267, 0.267))
	confirm_btn.pressed.connect(func():
		overlay.queue_free()
		on_confirm.call()
	)
	btn_row.add_child(confirm_btn)

# =============================================================================
# EXIT / ERROR
# =============================================================================
func _close_scene() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

func _show_error(msg: String) -> void:
	error_label.text = msg

func show_error(msg: String) -> void:
	_show_error(msg)

# =============================================================================
# STYLING HELPERS
# =============================================================================
func _flat(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	return sb

func _style_line_edit(le: LineEdit) -> void:
	var sb = _flat(BG_INSET)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	le.add_theme_stylebox_override("normal", sb)
	var sbf = sb.duplicate()
	sbf.border_color = ACCENT
	le.add_theme_stylebox_override("focus", sbf)
	le.add_theme_color_override("font_color", TEXT)
	le.add_theme_color_override("font_placeholder_color", TEXT_MUT)
	le.add_theme_font_size_override("font_size", FONT_BODY)

func _style_btn(btn: Button, primary: bool) -> void:
	if primary:
		# Accent outline button (not filled gold — gold border + gold text on transparent)
		var sb = _flat(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.1))
		sb.border_color = ACCENT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", sb)
		var sbh = sb.duplicate()
		sbh.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2)
		btn.add_theme_stylebox_override("hover", sbh)
		btn.add_theme_color_override("font_color", ACCENT)
		btn.add_theme_color_override("font_hover_color", ACCENT)
	else:
		# Normal button — visible bg with light text
		var sb = _flat(BG_CARD)
		sb.border_color = BORDER
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", sb)
		var sbh = sb.duplicate()
		sbh.bg_color = BG_HOVER
		btn.add_theme_stylebox_override("hover", sbh)
		btn.add_theme_color_override("font_color", TEXT)
		btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_font_size_override("font_size", FONT_BODY)

func _style_btn_sm(btn: Button) -> void:
	var sb = _flat(BG_INSET)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", sb)
	var sbh = sb.duplicate()
	sbh.bg_color = BG_HOVER
	btn.add_theme_stylebox_override("hover", sbh)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_font_size_override("font_size", FONT_MIN)

func _style_option_button(ob: OptionButton) -> void:
	var sb = _flat(BG_INSET)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	ob.add_theme_stylebox_override("normal", sb)
	ob.add_theme_color_override("font_color", TEXT)
	ob.add_theme_font_size_override("font_size", FONT_BODY)

func _safe_str(value) -> String:
	if value == null:
		return ""
	return str(value)


# ── Split layout persistence ──
func _save_split_layout() -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://ui_settings.cfg")
	cfg.set_value("weapon_layout", "main_split", _main_split.split_offset)
	cfg.save("user://ui_settings.cfg")

func _load_split_layout() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		if cfg.has_section_key("weapon_layout", "main_split"):
			_main_split.split_offset = cfg.get_value("weapon_layout", "main_split", 0)
