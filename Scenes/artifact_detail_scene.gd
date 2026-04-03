extends Control

# =============================================================================
# Artifact Detail Scene — fully programmatic dark-themed UI
# =============================================================================

const ARTIFACT_TABLE = "Character_Artifacts"

const TYPE_MAP = {
	"Flower":  "Flower of Life",
	"Feather": "Feather of Death",
	"Sands":   "Sands of Time",
	"Goblet":  "Goblet of Space",
	"Circlet": "Circlet of Principles",
}

const SLOT_TYPES = ["Flower of Life", "Feather of Death", "Sands of Time", "Goblet of Space", "Circlet of Principles"]
const SLOT_SHORT = ["Flower", "Feather", "Sands", "Goblet", "Circlet"]

const COLUMNS = [
	{"key": "Name",       "label": "Name",      "width": 0.14, "filter": "text"},
	{"key": "SetName",    "label": "Set",        "width": 0.12, "filter": "check"},
	{"key": "Stat1",      "label": "Stat 1",     "width": 0.10, "filter": "check"},
	{"key": "Stat1Value", "label": "Val",        "width": 0.05, "filter": "text"},
	{"key": "Stat2",      "label": "Stat 2",     "width": 0.10, "filter": "check"},
	{"key": "Stat2Value", "label": "Val",        "width": 0.05, "filter": "text"},
	{"key": "TwoPiece",   "label": "2pc Bonus",  "width": 0.17, "filter": "text"},
	{"key": "FourPiece",  "label": "4pc Bonus",  "width": 0.17, "filter": "text"},
	{"key": "Equipped",   "label": "Equipped",   "width": 0.06, "filter": "check"},
]

# ---- Theme colors ----
# Lighter blue palette — matching weapon scene
const BG_DEEP    = Color(0.102, 0.122, 0.169)
const BG_PANEL   = Color(0.133, 0.157, 0.22)
const BG_CARD    = Color(0.165, 0.192, 0.27)
const BG_INSET   = Color(0.09, 0.11, 0.155)
const BG_HOVER   = Color(0.19, 0.22, 0.30)
const BORDER     = Color(0.22, 0.25, 0.33)
const TEXT       = Color(0.96, 0.96, 0.98)
const TEXT_SEC   = Color(0.78, 0.80, 0.87)
const TEXT_MUT   = Color(0.58, 0.62, 0.71)
const ACCENT     = Color(0.788, 0.659, 0.298)
const ACCENT_DIM = Color(0.541, 0.455, 0.259)
const GREEN      = Color(0.292, 0.855, 0.498)
const RED        = Color(0.937, 0.267, 0.267)

const ROW_EVEN   = Color(0.133, 0.157, 0.22)
const ROW_ODD    = Color(0.102, 0.122, 0.169)

const FONT_BODY  = 15
const FONT_HDR   = 18
const FONT_TITLE = 20
const FONT_PREV  = 15
const ROW_HEIGHT = 36
const HEADER_HEIGHT = 38
const PREVIEW_H  = 450
const FOOTER_H   = 48

# ---- State ----
var _slot_type: String = ""
var _rows: Array = []
var _selected_row: Dictionary = {}
var _original_row: Dictionary = {}
var _confirm_locked = false

var search_query: String = ""
var current_sort_column: String = "Name"
var sort_ascending: bool = true
var column_filters: Dictionary = {}

# Row tracking: Array of {data, panel, cells, plain, row_bg}
var artifact_rows: Array = []

# ---- Node refs (built in _ready) ----
var bg_panel: Panel
var search_bar: LineEdit
var search_debounce: Timer
var header_container: HBoxContainer
var scroll_container: ScrollContainer
var row_vbox: VBoxContainer
var error_label: Label
var current_preview: Panel
var selected_preview: Panel
var _main_split: VSplitContainer
var receiver_option: OptionButton
var give_btn: Button
var unequip_btn: Button
var equip_btn: Button
var exit_btn: Button
var slot_chip_container: HBoxContainer
var slot_chips: Dictionary = {}
var title_label: Label

# Filter popover state
var active_popover: PanelContainer = null
var active_popover_column: String = ""

# =============================================================================
# ENTRY POINTS
# =============================================================================
func open_for_slot(short_name: String) -> void:
	_slot_type = TYPE_MAP.get(short_name, short_name)
	_activate_chip_for_type(_slot_type)
	_rebuild_and_refresh()

func open_for_type(full_name: String) -> void:
	_slot_type = full_name
	_activate_chip_for_type(_slot_type)
	_rebuild_and_refresh()

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	_init_filters()
	_build_ui()
	_populate_artifact_list()
	_populate_receivers()
	_update_current_preview()
	_load_split_layout.call_deferred()

func _init_filters() -> void:
	for col in COLUMNS:
		column_filters[col.key] = {"active": false, "value": "" if col.filter == "text" else {}}

# =============================================================================
# UI CONSTRUCTION
# =============================================================================
func _build_ui() -> void:
	# Background
	bg_panel = Panel.new()
	bg_panel.set_anchors_preset(PRESET_FULL_RECT)
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = BG_DEEP
	bg_panel.add_theme_stylebox_override("panel", bg_sb)
	add_child(bg_panel)

	# Main layout with 40px margins
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	main_vbox.set_anchor_and_offset(SIDE_RIGHT, 1, -40)
	main_vbox.set_anchor_and_offset(SIDE_TOP, 0, 40)
	main_vbox.set_anchor_and_offset(SIDE_BOTTOM, 1, -40)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# -- Title row --
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(title_row)

	title_label = Label.new()
	title_label.text = "ARTIFACTS"
	title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	title_label.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(title_label)

	var title_spacer = Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_spacer)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(36, 36)
	_style_button(close_btn)
	close_btn.pressed.connect(_on_exit_button_pressed)
	title_row.add_child(close_btn)

	# -- Search + slot chips row --
	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 12)
	main_vbox.add_child(filter_row)

	search_bar = LineEdit.new()
	search_bar.placeholder_text = "Search artifacts..."
	search_bar.custom_minimum_size.x = 300
	search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(search_bar)
	search_bar.text_changed.connect(_on_search_changed)
	filter_row.add_child(search_bar)

	# Slot chips
	slot_chip_container = HBoxContainer.new()
	slot_chip_container.add_theme_constant_override("separation", 6)
	slot_chip_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	filter_row.add_child(slot_chip_container)

	for i in SLOT_TYPES.size():
		var short = SLOT_SHORT[i]
		var full = SLOT_TYPES[i]
		var chip = Button.new()
		chip.text = short
		chip.toggle_mode = true
		chip.custom_minimum_size = Vector2(90, 30)
		chip.add_theme_font_size_override("font_size", FONT_PREV)
		_style_chip(chip, false)
		chip.pressed.connect(_on_slot_chip_pressed.bind(full, chip))
		slot_chip_container.add_child(chip)
		slot_chips[full] = chip

	# Search debounce timer
	search_debounce = Timer.new()
	search_debounce.one_shot = true
	search_debounce.wait_time = 0.3
	search_debounce.timeout.connect(_apply_all_filters)
	add_child(search_debounce)

	# -- Table + Preview in resizable split --
	_main_split = VSplitContainer.new()
	_main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_main_split.dragged.connect(func(_ofs): _save_split_layout())
	main_vbox.add_child(_main_split)

	# Top: table
	var table_section = VBoxContainer.new()
	table_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_split.add_child(table_section)

	header_container = HBoxContainer.new()
	header_container.custom_minimum_size.y = HEADER_HEIGHT
	header_container.add_theme_constant_override("separation", 0)
	table_section.add_child(header_container)
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

	# Bottom: preview cards
	var preview_row = HBoxContainer.new()
	preview_row.custom_minimum_size.y = 140
	preview_row.add_theme_constant_override("separation", 16)
	preview_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_split.add_child(preview_row)

	current_preview = _build_preview_card("Currently Equipped")
	current_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(current_preview)

	selected_preview = _build_preview_card("Selected Artifact")
	selected_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(selected_preview)

	# -- Footer --
	var footer = HBoxContainer.new()
	footer.custom_minimum_size.y = FOOTER_H
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(footer)

	var give_label = Label.new()
	give_label.text = "Give Selected To:"
	give_label.add_theme_font_size_override("font_size", FONT_BODY)
	give_label.add_theme_color_override("font_color", TEXT)
	give_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(give_label)

	receiver_option = OptionButton.new()
	receiver_option.custom_minimum_size.x = 200
	_style_option_button(receiver_option)
	footer.add_child(receiver_option)

	give_btn = Button.new()
	give_btn.text = "Give"
	give_btn.custom_minimum_size.x = 100
	_style_button(give_btn)
	give_btn.pressed.connect(_on_give_confirm_button_pressed)
	footer.add_child(give_btn)

	var footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	unequip_btn = Button.new()
	unequip_btn.text = "Unequip"
	unequip_btn.custom_minimum_size.x = 120
	_style_button(unequip_btn)
	unequip_btn.pressed.connect(_on_unequip_pressed)
	footer.add_child(unequip_btn)

	exit_btn = Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size.x = 100
	_style_button(exit_btn)
	exit_btn.pressed.connect(_on_exit_button_pressed)
	footer.add_child(exit_btn)

	equip_btn = Button.new()
	equip_btn.text = "Equip Selected"
	equip_btn.custom_minimum_size.x = 160
	_style_button(equip_btn, false)
	equip_btn.pressed.connect(_on_confirm_button_pressed)
	footer.add_child(equip_btn)

# =============================================================================
# HEADER ROW
# =============================================================================
func _build_header_row() -> void:
	for col in COLUMNS:
		var btn = Button.new()
		btn.text = col.label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_stretch_ratio = col.width
		btn.custom_minimum_size.y = HEADER_HEIGHT
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		var sb_normal = StyleBoxFlat.new()
		sb_normal.bg_color = BG_INSET
		sb_normal.border_width_bottom = 2
		sb_normal.border_color = ACCENT_DIM
		sb_normal.content_margin_left = 6
		sb_normal.content_margin_right = 6
		btn.add_theme_stylebox_override("normal", sb_normal)

		var sb_hover = sb_normal.duplicate()
		sb_hover.bg_color = BG_INSET.lightened(0.15)
		btn.add_theme_stylebox_override("hover", sb_hover)

		var sb_pressed = sb_normal.duplicate()
		sb_pressed.bg_color = BG_INSET.lightened(0.25)
		btn.add_theme_stylebox_override("pressed", sb_pressed)

		btn.add_theme_color_override("font_color", ACCENT)
		btn.add_theme_color_override("font_hover_color", ACCENT)
		btn.add_theme_color_override("font_pressed_color", ACCENT)
		btn.add_theme_font_size_override("font_size", FONT_HDR)

		var col_key = col.key
		btn.pressed.connect(_on_header_clicked.bind(col_key))
		btn.gui_input.connect(_on_header_gui_input.bind(col_key, btn))
		header_container.add_child(btn)

func _on_header_gui_input(event: InputEvent, col_key: String, btn: Button) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_toggle_filter_popover(col_key, btn)
		btn.accept_event()

func _on_header_clicked(col_key: String) -> void:
	if current_sort_column == col_key:
		sort_ascending = not sort_ascending
	else:
		current_sort_column = col_key
		sort_ascending = true

	artifact_rows.sort_custom(_compare_rows)

	for row in artifact_rows:
		row_vbox.remove_child(row.panel)
	for i in range(artifact_rows.size()):
		row_vbox.add_child(artifact_rows[i].panel)
		var new_bg = ROW_EVEN if i % 2 == 0 else ROW_ODD
		artifact_rows[i].row_bg = new_bg
		var is_selected = (artifact_rows[i].data_key == _selected_row.get("RecordID", ""))
		var sb: StyleBoxFlat = artifact_rows[i].panel.get_theme_stylebox("panel").duplicate()
		sb.bg_color = ROW_EVEN if is_selected else new_bg
		sb.border_color = ACCENT if is_selected else Color.TRANSPARENT
		sb.border_width_left = 3 if is_selected else 0
		artifact_rows[i].panel.add_theme_stylebox_override("panel", sb)

	_update_header_labels()

func _update_header_labels() -> void:
	for i in range(COLUMNS.size()):
		var btn: Button = header_container.get_child(i)
		var col = COLUMNS[i]
		var arrow = ""
		if current_sort_column == col.key:
			arrow = " ^" if sort_ascending else " v"
		var filter_indicator = ""
		if column_filters.has(col.key) and column_filters[col.key].active:
			filter_indicator = " *"
		btn.text = col.label + arrow + filter_indicator

# =============================================================================
# FILTER POPOVERS
# =============================================================================
func _toggle_filter_popover(col_key: String, anchor_btn: Button) -> void:
	if active_popover != null:
		_close_popover()
		if active_popover_column == col_key:
			return

	active_popover_column = col_key
	var col_def: Dictionary = {}
	for c in COLUMNS:
		if c.key == col_key:
			col_def = c
			break

	var popover = PanelContainer.new()
	var pop_sb = StyleBoxFlat.new()
	pop_sb.bg_color = BG_PANEL
	pop_sb.border_color = ACCENT_DIM
	pop_sb.set_border_width_all(1)
	pop_sb.set_corner_radius_all(4)
	pop_sb.set_content_margin_all(8)
	popover.add_theme_stylebox_override("panel", pop_sb)
	popover.z_index = 100

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	popover.add_child(vbox)

	var filter_title = Label.new()
	filter_title.text = "Filter: " + col_def.get("label", col_key)
	filter_title.add_theme_font_size_override("font_size", FONT_BODY)
	filter_title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(filter_title)

	if col_def.filter == "text":
		var le = LineEdit.new()
		le.placeholder_text = "Type to filter..."
		le.custom_minimum_size.x = 180
		_style_line_edit(le)
		var existing: String = column_filters[col_key].value if column_filters.has(col_key) else ""
		le.text = existing
		le.text_changed.connect(_on_column_text_filter_changed.bind(col_key))
		vbox.add_child(le)
		le.grab_focus.call_deferred()
	else:
		var unique_values: Array = _collect_unique_values(col_key)
		var existing_checks: Dictionary = column_filters[col_key].value if column_filters.has(col_key) else {}

		if unique_values.size() > 0:
			var scroll = ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(200, min(unique_values.size() * 30, 250))
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			vbox.add_child(scroll)

			var check_vbox = VBoxContainer.new()
			check_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check_vbox.add_theme_constant_override("separation", 2)
			scroll.add_child(check_vbox)

			for val in unique_values:
				var cb = CheckBox.new()
				cb.text = str(val) if str(val) != "" else "(empty)"
				cb.button_pressed = existing_checks.get(str(val), true)
				cb.add_theme_color_override("font_color", TEXT)
				cb.add_theme_font_size_override("font_size", FONT_BODY)
				var val_str = str(val)
				cb.toggled.connect(_on_column_check_filter_toggled.bind(col_key, val_str))
				check_vbox.add_child(cb)

		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 4)
		vbox.add_child(btn_row)
		var all_btn = Button.new()
		all_btn.text = "All"
		_style_button_small(all_btn)
		all_btn.pressed.connect(_on_filter_select_all.bind(col_key, true))
		btn_row.add_child(all_btn)
		var none_btn = Button.new()
		none_btn.text = "None"
		_style_button_small(none_btn)
		none_btn.pressed.connect(_on_filter_select_all.bind(col_key, false))
		btn_row.add_child(none_btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear Filter"
	_style_button_small(clear_btn)
	clear_btn.pressed.connect(_on_clear_column_filter.bind(col_key))
	vbox.add_child(clear_btn)

	add_child(popover)
	active_popover = popover

	await get_tree().process_frame
	var btn_rect = anchor_btn.get_global_rect()
	var my_rect = get_global_rect()
	popover.position = Vector2(
		btn_rect.position.x - my_rect.position.x,
		btn_rect.position.y - my_rect.position.y + btn_rect.size.y + 2
	)
	if popover.position.x + popover.size.x > size.x - 10:
		popover.position.x = size.x - popover.size.x - 10

func _close_popover() -> void:
	if active_popover != null and is_instance_valid(active_popover):
		active_popover.queue_free()
	active_popover = null
	active_popover_column = ""

func _input(event: InputEvent) -> void:
	if active_popover == null or not is_instance_valid(active_popover):
		return
	if event is InputEventMouseButton and event.pressed:
		var pop_rect = active_popover.get_global_rect()
		var click_pos: Vector2 = event.global_position
		if not pop_rect.has_point(click_pos):
			_close_popover()

func _collect_unique_values(col_key: String) -> Array:
	var vals: Array = []
	for row in artifact_rows:
		var v: String = str(row.plain.get(col_key, ""))
		if not vals.has(v):
			vals.append(v)
	vals.sort()
	return vals

func _on_column_text_filter_changed(new_text: String, col_key: String) -> void:
	var trimmed = new_text.strip_edges()
	column_filters[col_key].value = trimmed
	column_filters[col_key].active = trimmed != ""
	_apply_all_filters()
	_update_header_labels()

func _on_column_check_filter_toggled(pressed: bool, col_key: String, val: String) -> void:
	column_filters[col_key].value[val] = pressed
	var any_unchecked = false
	for k in column_filters[col_key].value:
		if not column_filters[col_key].value[k]:
			any_unchecked = true
			break
	column_filters[col_key].active = any_unchecked
	_apply_all_filters()
	_update_header_labels()

func _on_filter_select_all(col_key: String, select: bool) -> void:
	for k in column_filters[col_key].value:
		column_filters[col_key].value[k] = select
	column_filters[col_key].active = not select
	if active_popover != null and is_instance_valid(active_popover):
		var scroll = _find_child_of_type(active_popover, "ScrollContainer")
		if scroll:
			var check_vbox2 = scroll.get_child(0) if scroll.get_child_count() > 0 else null
			if check_vbox2:
				for child in check_vbox2.get_children():
					if child is CheckBox:
						child.set_pressed_no_signal(select)
	_apply_all_filters()
	_update_header_labels()

func _find_child_of_type(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.get_class() == type_name:
			return child
		var found = _find_child_of_type(child, type_name)
		if found:
			return found
	return null

func _on_clear_column_filter(col_key: String) -> void:
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
	_apply_all_filters()
	_update_header_labels()

# =============================================================================
# PREVIEW CARD BUILDER
# =============================================================================
func _build_preview_card(title_text: String) -> Panel:
	var card = Panel.new()
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = BG_PANEL
	card_sb.border_color = BORDER
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(6)
	card_sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_sb)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(info_vbox)

	var title = Label.new()
	title.name = "Title"
	title.text = title_text
	title.add_theme_font_size_override("font_size", FONT_HDR)
	title.add_theme_color_override("font_color", ACCENT)
	info_vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	info_vbox.add_child(sep)

	var name_label = Label.new()
	name_label.name = "ArtifactName"
	name_label.text = "---"
	name_label.add_theme_font_size_override("font_size", FONT_TITLE)
	name_label.add_theme_color_override("font_color", TEXT)
	info_vbox.add_child(name_label)

	var detail_row = HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 20)
	info_vbox.add_child(detail_row)

	var set_label = Label.new()
	set_label.name = "SetName"
	set_label.text = ""
	set_label.add_theme_font_size_override("font_size", FONT_PREV)
	set_label.add_theme_color_override("font_color", TEXT_MUT)
	detail_row.add_child(set_label)

	var slot_label = Label.new()
	slot_label.name = "SlotType"
	slot_label.text = ""
	slot_label.add_theme_font_size_override("font_size", FONT_PREV)
	slot_label.add_theme_color_override("font_color", TEXT_MUT)
	detail_row.add_child(slot_label)

	# Stat lines
	for i in range(1, 3):
		var stat_label = Label.new()
		stat_label.name = "Stat%d" % i
		stat_label.text = ""
		stat_label.add_theme_font_size_override("font_size", FONT_BODY)
		stat_label.add_theme_color_override("font_color", TEXT)
		info_vbox.add_child(stat_label)

	# 2pc bonus
	var pc2_lbl = Label.new()
	pc2_lbl.text = "2-Piece Set Bonus:"
	pc2_lbl.add_theme_font_size_override("font_size", 13)
	pc2_lbl.add_theme_color_override("font_color", TEXT_MUT)
	info_vbox.add_child(pc2_lbl)

	var pc2 = RichTextLabel.new()
	pc2.name = "TwoPiece"
	pc2.bbcode_enabled = true
	pc2.fit_content = true
	pc2.scroll_active = false
	pc2.custom_minimum_size.y = 30
	pc2.add_theme_font_size_override("normal_font_size", FONT_PREV)
	pc2.add_theme_color_override("default_color", ACCENT)
	info_vbox.add_child(pc2)

	# 4pc bonus
	var pc4_lbl = Label.new()
	pc4_lbl.text = "4-Piece Set Bonus:"
	pc4_lbl.add_theme_font_size_override("font_size", 13)
	pc4_lbl.add_theme_color_override("font_color", TEXT_MUT)
	info_vbox.add_child(pc4_lbl)

	var pc4 = RichTextLabel.new()
	pc4.name = "FourPiece"
	pc4.bbcode_enabled = true
	pc4.fit_content = true
	pc4.scroll_active = false
	pc4.custom_minimum_size.y = 30
	pc4.add_theme_font_size_override("normal_font_size", FONT_PREV)
	pc4.add_theme_color_override("default_color", TEXT_SEC)
	info_vbox.add_child(pc4)

	# Set bonus preview (shows gained/lost set bonuses when swapping)
	var set_bonus_preview = VBoxContainer.new()
	set_bonus_preview.name = "SetBonusPreview"
	set_bonus_preview.add_theme_constant_override("separation", 3)
	info_vbox.add_child(set_bonus_preview)

	# Stats comparison grid
	var stats_grid = GridContainer.new()
	stats_grid.name = "StatsGrid"
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 12)
	stats_grid.add_theme_constant_override("v_separation", 2)
	info_vbox.add_child(stats_grid)

	var stat_names = ["Health", "Attack", "Defense", "Elemental Mastery", "Energy Recharge", "Critical Damage"]
	for sn in stat_names:
		var sn_label = Label.new()
		sn_label.text = sn + ":"
		sn_label.add_theme_font_size_override("font_size", FONT_PREV)
		sn_label.add_theme_color_override("font_color", TEXT_MUT)
		stats_grid.add_child(sn_label)
		var sv_label = Label.new()
		sv_label.name = sn.replace(" ", "_") + "_Value"
		sv_label.text = "---"
		sv_label.add_theme_font_size_override("font_size", FONT_PREV)
		sv_label.add_theme_color_override("font_color", TEXT)
		stats_grid.add_child(sv_label)

	return card

# =============================================================================
# PREVIEW UPDATES
# =============================================================================
func _update_preview_card(card: Panel, data: Dictionary, is_current: bool) -> void:
	if data.is_empty():
		_clear_preview_card(card)
		if is_current:
			_fill_stats_current(card)
		return

	var name_label: Label = card.find_child("ArtifactName", true, false)
	var set_label: Label = card.find_child("SetName", true, false)
	var slot_label: Label = card.find_child("SlotType", true, false)

	if name_label:
		name_label.text = str(data.get("Name", "Unknown"))
	if set_label:
		set_label.text = "Set: " + str(data.get("SetName", ""))
	if slot_label:
		slot_label.text = "Slot: " + str(data.get("Type", ""))

	for i in range(1, 3):
		var stat_label: Label = card.find_child("Stat%d" % i, true, false)
		if stat_label:
			var st = data.get("Stat%d" % i, "")
			var sv = data.get("Stat%dValue" % i)
			if str(st) != "" and sv != null:
				stat_label.text = str(st) + ": " + _fmt_num(sv)
			else:
				stat_label.text = ""

	var pc2: RichTextLabel = card.find_child("TwoPiece", true, false)
	if pc2:
		var two = str(data.get("TwoPiece", ""))
		pc2.text = "[color=#c9a84c]2pc:[/color] " + two if two != "" else ""

	var pc4: RichTextLabel = card.find_child("FourPiece", true, false)
	if pc4:
		var four = str(data.get("FourPiece", ""))
		pc4.text = "[color=#8892a8]4pc:[/color] " + four if four != "" else ""

	var stats_grid: GridContainer = card.find_child("StatsGrid", true, false)
	if stats_grid == null:
		return

	if is_current:
		_fill_stats_current(card)
	else:
		_fill_stats_comparison(card, data)

func _fill_stats_current(card: Panel) -> void:
	var stats = {
		"Health": Global.Current_Health,
		"Attack": Global.Current_Attack,
		"Defense": Global.Current_Defense,
		"Elemental_Mastery": Global.Current_Elemental_Mastery,
		"Energy_Recharge": Global.Current_Energy_Recharge,
		"Critical_Damage": Global.Current_Critical_Damage,
	}
	var stats_grid: GridContainer = card.find_child("StatsGrid", true, false)
	if stats_grid == null:
		return
	for key in stats:
		var lbl: Label = stats_grid.find_child(key + "_Value", true, false)
		if lbl:
			lbl.text = str(stats[key])
			lbl.add_theme_color_override("font_color", TEXT)

func _fill_stats_comparison(card: Panel, data: Dictionary) -> void:
	var stat_keys = ["Health", "Attack", "Defense", "Elemental_Mastery", "Energy_Recharge", "Critical_Damage"]
	var current_vals = {
		"Health": Global.Current_Health,
		"Attack": Global.Current_Attack,
		"Defense": Global.Current_Defense,
		"Elemental_Mastery": Global.Current_Elemental_Mastery,
		"Energy_Recharge": Global.Current_Energy_Recharge,
		"Critical_Damage": Global.Current_Critical_Damage,
	}

	var new_vals = current_vals.duplicate()
	# Remove old artifact stats (if one is equipped — _original_row may be empty)
	if not _original_row.is_empty():
		_apply_artifact_stats(new_vals, _original_row, -1)
	# Add new artifact stats
	_apply_artifact_stats(new_vals, data, 1)

	var stats_grid: GridContainer = card.find_child("StatsGrid", true, false)
	if stats_grid == null:
		return

	for key in stat_keys:
		var lbl: Label = stats_grid.find_child(key + "_Value", true, false)
		if lbl:
			var nv = new_vals.get(key, 0)
			var cv = current_vals.get(key, 0)
			lbl.text = str(nv)
			if nv > cv:
				lbl.add_theme_color_override("font_color", GREEN)
			elif nv < cv:
				lbl.add_theme_color_override("font_color", RED)
			else:
				lbl.add_theme_color_override("font_color", TEXT)

	# Show set bonus changes
	_fill_set_bonus_preview(card, data)


func _fill_set_bonus_preview(card: Panel, new_artifact: Dictionary) -> void:
	var preview = card.find_child("SetBonusPreview", true, false)
	if preview == null:
		return
	for c in preview.get_children():
		c.queue_free()

	if _original_row.is_empty() and new_artifact.is_empty():
		return

	# Use Global.set_count which correctly reads Artifact_Set field
	var current_counts = Global.set_count.duplicate()

	# Calculate new counts: remove old artifact's set, add new artifact's set
	var new_counts = current_counts.duplicate()
	var old_set = str(_original_row.get("Artifact_Set", _original_row.get("SetName", _original_row.get("Set_Name", ""))))
	var new_set = str(new_artifact.get("Artifact_Set", new_artifact.get("SetName", new_artifact.get("Set_Name", ""))))
	if old_set != "":
		new_counts[old_set] = new_counts.get(old_set, 0) - 1
	if new_set != "":
		new_counts[new_set] = new_counts.get(new_set, 0) + 1

	# Check what bonuses change
	var changes = []
	var all_sets = {}
	for s in current_counts:
		all_sets[s] = true
	for s in new_counts:
		all_sets[s] = true

	for set_name in all_sets:
		var old_count = current_counts.get(set_name, 0)
		var new_count = new_counts.get(set_name, 0)
		# Check 2pc threshold
		if old_count < 2 and new_count >= 2:
			changes.append({"set": set_name, "pieces": 2, "gained": true})
		elif old_count >= 2 and new_count < 2:
			changes.append({"set": set_name, "pieces": 2, "gained": false})
		# Check 4pc threshold
		if old_count < 4 and new_count >= 4:
			changes.append({"set": set_name, "pieces": 4, "gained": true})
		elif old_count >= 4 and new_count < 4:
			changes.append({"set": set_name, "pieces": 4, "gained": false})

	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	preview.add_child(sep)

	var header = Label.new()
	header.text = "Set Bonuses"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", ACCENT)
	preview.add_child(header)

	# Show current set counts → new set counts for the new artifact's set
	if new_set != "":
		var old_ct = current_counts.get(new_set, 0)
		var new_ct = new_counts.get(new_set, 0)
		var count_lbl = Label.new()
		count_lbl.text = "%s: %d → %d pieces" % [new_set, old_ct, new_ct]
		count_lbl.add_theme_font_size_override("font_size", FONT_PREV)
		count_lbl.add_theme_color_override("font_color", GREEN if new_ct > old_ct else (RED if new_ct < old_ct else TEXT))
		preview.add_child(count_lbl)

	# Also show old set if it's different and losing pieces
	if old_set != "" and old_set != new_set:
		var old_ct2 = current_counts.get(old_set, 0)
		var new_ct2 = new_counts.get(old_set, 0)
		var count_lbl2 = Label.new()
		count_lbl2.text = "%s: %d → %d pieces" % [old_set, old_ct2, new_ct2]
		count_lbl2.add_theme_font_size_override("font_size", FONT_PREV)
		count_lbl2.add_theme_color_override("font_color", RED if new_ct2 < old_ct2 else TEXT)
		preview.add_child(count_lbl2)

	# Show specific bonus thresholds gained/lost
	if changes.is_empty():
		var no_change = Label.new()
		no_change.text = "No set bonus changes"
		no_change.add_theme_font_size_override("font_size", FONT_PREV)
		no_change.add_theme_color_override("font_color", TEXT_MUT)
		preview.add_child(no_change)
	else:
		for change in changes:
			var lbl = Label.new()
			lbl.add_theme_font_size_override("font_size", FONT_PREV)
			if change["gained"]:
				lbl.text = "▲ GAIN %dpc %s bonus" % [change["pieces"], change["set"]]
				lbl.add_theme_color_override("font_color", GREEN)
			else:
				lbl.text = "▼ LOSE %dpc %s bonus" % [change["pieces"], change["set"]]
				lbl.add_theme_color_override("font_color", RED)
			preview.add_child(lbl)


func _apply_artifact_stats(vals: Dictionary, artifact: Dictionary, sign: int) -> void:
	var stat_keys = ["Stat1", "Stat2"]
	var val_keys = ["Stat1Value", "Stat2Value"]
	for i in stat_keys.size():
		var stype = str(artifact.get(stat_keys[i], ""))
		var sval = artifact.get(val_keys[i])
		if stype != "" and sval != null and vals.has(stype):
			vals[stype] = vals[stype] + (_num(sval) * sign)

func _clear_preview_card(card: Panel) -> void:
	var name_label: Label = card.find_child("ArtifactName", true, false)
	if name_label:
		name_label.text = "---"
	var set_label: Label = card.find_child("SetName", true, false)
	if set_label:
		set_label.text = ""
	var slot_label: Label = card.find_child("SlotType", true, false)
	if slot_label:
		slot_label.text = ""
	for i in range(1, 3):
		var stat_label: Label = card.find_child("Stat%d" % i, true, false)
		if stat_label:
			stat_label.text = ""
	var pc2: RichTextLabel = card.find_child("TwoPiece", true, false)
	if pc2:
		pc2.text = ""
	var pc4: RichTextLabel = card.find_child("FourPiece", true, false)
	if pc4:
		pc4.text = ""
	var stats_grid: GridContainer = card.find_child("StatsGrid", true, false)
	if stats_grid:
		for child in stats_grid.get_children():
			if child is Label and child.name.ends_with("_Value"):
				child.text = "---"
				child.add_theme_color_override("font_color", TEXT)

func _update_current_preview() -> void:
	_update_preview_card(current_preview, _original_row, true)

func _update_selected_preview() -> void:
	_update_preview_card(selected_preview, _selected_row, false)

# =============================================================================
# ARTIFACT LIST / ROWS
# =============================================================================
func _build_data_rows() -> Array:
	var rows: Array = []
	var owner = Global.ACTIVE_USER_NAME

	# Index set bonuses from Global.ARTIFACTS
	var two_by_set = {}
	var four_by_set = {}
	for rid in Global.ARTIFACTS.keys():
		var r: Dictionary = Global.ARTIFACTS[rid]
		var set_name = str(r.get("Artifact_Set", ""))
		var bonus = int(_num(r.get("Bonus_Type", 0)))
		var effect = str(r.get("Effect", ""))
		if bonus == 2:
			two_by_set[set_name] = effect
		elif bonus == 4:
			four_by_set[set_name] = effect

	for record_id in Global.CHARACTER_ARTIFACTS.keys():
		var a: Dictionary = Global.CHARACTER_ARTIFACTS[record_id]
		if str(a.get("Owner", "")) != owner:
			continue
		if _slot_type != "" and str(a.get("Type", "")) != _slot_type:
			continue

		var set_name = str(a.get("Artifact_Set", ""))
		var s2_type_raw = a.get("Stat_2_Type", null)
		var s2_val_raw = a.get("Stat_2_Value", null)
		var has_s2 = (s2_type_raw != null) and (s2_val_raw != null)

		rows.append({
			"RecordID":   record_id,
			"Name":       set_name,
			"SetName":    set_name,
			"Type":       str(a.get("Type", "")),
			"Stat1":      str(a.get("Stat_1_Type", "")),
			"Stat1Value": _num(a.get("Stat_1_Value", 0.0)),
			"Stat2":      str(s2_type_raw) if has_s2 else "",
			"Stat2Value": _num(s2_val_raw) if has_s2 else null,
			"TwoPiece":   str(two_by_set.get(set_name, "")),
			"FourPiece":  str(four_by_set.get(set_name, "")),
			"Equipped":   a.get("Equipped"),
			"Rarity":     int(_num(a.get("Rarity", 0))),
		})

	return rows

func _populate_artifact_list() -> void:
	for c in row_vbox.get_children():
		c.queue_free()
	artifact_rows.clear()
	_selected_row = {}
	_original_row = {}

	var data_rows = _build_data_rows()
	for data in data_rows:
		_add_artifact_row(data)
		if data.get("Equipped") != null and bool(data.get("Equipped")):
			_selected_row = data.duplicate(true)
			_original_row = data.duplicate(true)

	_apply_all_filters()
	_update_current_preview()
	_update_selected_preview()

func _add_artifact_row(data: Dictionary) -> void:
	var plain = {
		"Name":       str(data.get("Name", "")),
		"SetName":    str(data.get("SetName", "")),
		"Stat1":      str(data.get("Stat1", "")),
		"Stat1Value": _fmt_num(data.get("Stat1Value")) if data.get("Stat1Value") != null else "",
		"Stat2":      str(data.get("Stat2", "")),
		"Stat2Value": _fmt_num(data.get("Stat2Value")) if data.get("Stat2Value") != null else "",
		"TwoPiece":   str(data.get("TwoPiece", "")),
		"FourPiece":  str(data.get("FourPiece", "")),
		"Equipped":   "Yes" if (data.get("Equipped") != null and bool(data.get("Equipped"))) else "",
	}

	# Initialize check filters for new unique values
	for col in COLUMNS:
		if col.filter == "check":
			var val_str: String = plain.get(col.key, "")
			if not column_filters[col.key].value.has(val_str):
				column_filters[col.key].value[val_str] = true

	var row_idx = artifact_rows.size()
	var row_panel = Panel.new()
	row_panel.custom_minimum_size.y = ROW_HEIGHT
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_bg = ROW_EVEN if row_idx % 2 == 0 else ROW_ODD
	var is_equipped = data.get("Equipped") != null and bool(data.get("Equipped"))
	var sb = StyleBoxFlat.new()
	sb.bg_color = row_bg
	sb.border_width_left = 3 if is_equipped else 0
	sb.border_color = ACCENT if is_equipped else Color.TRANSPARENT
	sb.content_margin_left = 3
	row_panel.add_theme_stylebox_override("panel", sb)
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	row_panel.gui_input.connect(_on_row_gui_input.bind(row_idx))
	row_panel.mouse_entered.connect(_on_row_mouse_entered.bind(row_panel, row_bg))
	row_panel.mouse_exited.connect(_on_row_mouse_exited.bind(row_panel, row_bg, row_idx))

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_panel.add_child(hbox)

	var cells: Dictionary = {}
	for col in COLUMNS:
		var cell = Label.new()
		cell.text = plain.get(col.key, "")
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_stretch_ratio = col.width
		cell.clip_text = true
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_font_size_override("font_size", FONT_BODY)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if col.key == "Equipped" and plain.get("Equipped") == "Yes":
			cell.add_theme_color_override("font_color", GREEN)
		else:
			cell.add_theme_color_override("font_color", TEXT)

		var cell_margin = MarginContainer.new()
		cell_margin.add_theme_constant_override("margin_left", 6)
		cell_margin.add_theme_constant_override("margin_right", 4)
		cell_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell_margin.size_flags_stretch_ratio = col.width
		cell_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell_margin.add_child(cell)
		hbox.add_child(cell_margin)
		cells[col.key] = cell

	row_vbox.add_child(row_panel)

	artifact_rows.append({
		"data": data,
		"data_key": str(data.get("RecordID", "")),
		"panel": row_panel,
		"cells": cells,
		"plain": plain,
		"row_bg": row_bg,
	})

func _on_row_gui_input(event: InputEvent, row_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_row(row_idx)

func _on_row_mouse_entered(row_panel: Panel, _base_color: Color) -> void:
	var sb: StyleBoxFlat = row_panel.get_theme_stylebox("panel").duplicate()
	sb.bg_color = BG_HOVER
	row_panel.add_theme_stylebox_override("panel", sb)

func _on_row_mouse_exited(row_panel: Panel, base_color: Color, row_idx: int) -> void:
	if row_idx >= artifact_rows.size():
		return
	var sb: StyleBoxFlat = row_panel.get_theme_stylebox("panel").duplicate()
	var is_selected = (artifact_rows[row_idx].data_key == str(_selected_row.get("RecordID", "")))
	sb.bg_color = ROW_EVEN if is_selected else base_color
	sb.border_color = ACCENT if is_selected else Color.TRANSPARENT
	sb.border_width_left = 3 if is_selected else 0
	row_panel.add_theme_stylebox_override("panel", sb)

func _select_row(row_idx: int) -> void:
	if row_idx >= artifact_rows.size():
		return
	_selected_row = artifact_rows[row_idx].data.duplicate(true)

	for i in range(artifact_rows.size()):
		var row = artifact_rows[i]
		var is_sel = (row.data_key == str(_selected_row.get("RecordID", "")))
		var sb: StyleBoxFlat = row.panel.get_theme_stylebox("panel").duplicate()
		if is_sel:
			sb.bg_color = ROW_EVEN
			sb.border_color = ACCENT
			sb.border_width_left = 3
		else:
			sb.bg_color = row.row_bg
			sb.border_color = Color.TRANSPARENT
			sb.border_width_left = 0
		row.panel.add_theme_stylebox_override("panel", sb)

	_update_selected_preview()

# =============================================================================
# SEARCH + FILTER
# =============================================================================
func _on_search_changed(new_text: String) -> void:
	search_query = new_text.strip_edges()
	if is_instance_valid(search_debounce):
		search_debounce.start()
	else:
		_apply_all_filters()

func _apply_all_filters() -> void:
	var tokens = search_query.to_lower().split(" ", false)

	for row in artifact_rows:
		var show = true

		if not tokens.is_empty():
			var blob: String = ""
			for col in COLUMNS:
				blob += str(row.plain.get(col.key, "")) + "|"
			blob = blob.to_lower()
			for t in tokens:
				if t != "" and blob.findn(t) == -1:
					show = false
					break

		if show:
			for col in COLUMNS:
				var f = column_filters.get(col.key)
				if f == null or not f.active:
					continue
				var cell_val: String = str(row.plain.get(col.key, ""))
				if col.filter == "text":
					if cell_val.to_lower().findn(f.value.to_lower()) == -1:
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
func _compare_rows(a: Dictionary, b: Dictionary) -> bool:
	var av = a.plain.get(current_sort_column, "")
	var bv = b.plain.get(current_sort_column, "")

	if str(av).is_valid_float() and str(bv).is_valid_float():
		var af = float(av)
		var bf = float(bv)
		return af < bf if sort_ascending else af > bf

	var cmp = str(av).nocasecmp_to(str(bv))
	return cmp < 0 if sort_ascending else cmp > 0

# =============================================================================
# SLOT CHIPS
# =============================================================================
func _on_slot_chip_pressed(full_type: String, btn: Button) -> void:
	if _slot_type == full_type:
		_slot_type = ""
		btn.button_pressed = false
		_style_chip(btn, false)
	else:
		_slot_type = full_type
		for key in slot_chips.keys():
			var chip: Button = slot_chips[key]
			var on = (key == full_type)
			chip.button_pressed = on
			_style_chip(chip, on)

	_rebuild_and_refresh()

func _activate_chip_for_type(full_type: String) -> void:
	for key in slot_chips.keys():
		var chip: Button = slot_chips[key]
		var on = (key == full_type)
		chip.button_pressed = on
		_style_chip(chip, on)

func _rebuild_and_refresh() -> void:
	_update_title()
	_populate_artifact_list()
	_populate_receivers()

func _update_title() -> void:
	if title_label == null:
		return
	if _slot_type == "":
		title_label.text = "ARTIFACTS"
	else:
		var short = ""
		for key in TYPE_MAP.keys():
			if TYPE_MAP[key] == _slot_type:
				short = key
				break
		if short != "":
			title_label.text = "ARTIFACTS \u2014 " + short
		else:
			title_label.text = "ARTIFACTS \u2014 " + _slot_type

# =============================================================================
# RECEIVERS (Give artifact)
# =============================================================================
func _populate_receivers() -> void:
	receiver_option.clear()
	receiver_option.add_item("Nobody")
	for character in Global.PartyCharacters:
		if character != Global.ACTIVE_USER_NAME:
			receiver_option.add_item(character)

# =============================================================================
# EQUIP / UNEQUIP / GIVE
# =============================================================================
func _on_confirm_button_pressed() -> void:
	if _confirm_locked:
		return

	if _selected_row.is_empty():
		error_label.text = "No artifact selected. Use Unequip to remove current artifact."
		return

	var sel_name = str(_selected_row.get("Name", "Unknown"))
	var old_name = str(_original_row.get("Name", "None")) if not _original_row.is_empty() else "None"
	_show_confirm_popup(
		"Equip Artifact",
		"Replace %s with %s?" % [old_name, sel_name],
		_do_equip_artifact
	)

func _do_equip_artifact() -> void:
	_confirm_locked = true
	error_label.text = ""

	var selected_id: String = str(_selected_row.get("RecordID", ""))
	if selected_id == "":
		_confirm_locked = false
		return

	var owner = Global.ACTIVE_USER_NAME
	var slot = str(_selected_row.get("Type", ""))
	var updates: Array = []
	var previous_equipped: String = ""

	# Unequip only same slot type
	for rid in Global.CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = Global.CHARACTER_ARTIFACTS[rid]
		if str(rec.get("Owner", "")) != owner:
			continue
		if str(rec.get("Type", "")) != slot:
			continue
		if rec.get("Equipped", false) == true:
			previous_equipped = str(rid)
		if str(rid) == selected_id:
			continue
		updates.append({
			"table": ARTIFACT_TABLE,
			"record_id": _id_num(rid),
			"field": "Equipped",
			"value": false
		})

	# Equip selected
	updates.append({
		"table": ARTIFACT_TABLE,
		"record_id": _id_num(selected_id),
		"field": "Equipped",
		"value": true
	})

	# Handle Universal_Added_Damage_Bonus
	var current_uadb = float(Global.CHARACTERS.get(str(Global.ACTIVE_USER_RECORD_ID), {}).get("Universal_Added_Damage_Bonus", 0))
	var changed = 0
	if _selected_row.get("Stat1") == "Universal_Added_Damage_Bonus":
		current_uadb += float(_selected_row.get("Stat1Value", 0))
		changed = 1
	elif _selected_row.get("Stat2") == "Universal_Added_Damage_Bonus":
		current_uadb += float(_selected_row.get("Stat2Value", 0))
		changed = 1
	if changed == 1:
		updates.append({
			"table": "Characters",
			"record_id": Global.ACTIVE_USER_RECORD_ID,
			"field": "Universal_Added_Damage_Bonus",
			"value": current_uadb
		})

	Global.Update_Records(updates)

	var previouslogslot
	if previous_equipped != null and previous_equipped != "":
		previouslogslot = {"slot": slot, "previous": Global.CHARACTER_ARTIFACTS.get(previous_equipped, {})}
	else:
		previouslogslot = {"slot": slot, "previous": null}

	var currentlogslot
	if selected_id != null and selected_id != "":
		currentlogslot = {"slot": slot, "current": Global.CHARACTER_ARTIFACTS.get(selected_id, {})}
	else:
		currentlogslot = {"slot": slot, "current": null}

	Global.Log(
		"equipment",
		"equip_artifact",
		"Artifact",
		selected_id,
		previouslogslot,
		currentlogslot
	)

	_confirm_locked = false
	_close_scene()

func _on_unequip_pressed() -> void:
	var old_name = str(_original_row.get("Name", "current artifact")) if not _original_row.is_empty() else "current artifact"
	_show_confirm_popup(
		"Unequip Artifact",
		"Remove %s from this slot?" % old_name,
		_do_unequip_artifact
	)

func _do_unequip_artifact() -> void:
	var owner = Global.ACTIVE_USER_NAME
	var slot = _slot_type
	var updates: Array = []
	var previous_equipped: String = ""

	for rid in Global.CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = Global.CHARACTER_ARTIFACTS[rid]
		if str(rec.get("Owner", "")) != owner:
			continue
		if slot != "" and str(rec.get("Type", "")) != slot:
			continue
		if rec.get("Equipped", false) == true:
			previous_equipped = str(rid)
			updates.append({
				"table": ARTIFACT_TABLE,
				"record_id": _id_num(rid),
				"field": "Equipped",
				"value": false
			})
			var current_uadb = float(Global.CHARACTERS.get(str(Global.ACTIVE_USER_RECORD_ID), {}).get("Universal_Added_Damage_Bonus", 0))
			var uadb_changed = 0
			if rec.get("Stat_1_Type") == "Universal_Added_Damage_Bonus":
				current_uadb -= float(rec.get("Stat_1_Value", 0))
				uadb_changed = 1
			if rec.get("Stat_2_Type") == "Universal_Added_Damage_Bonus":
				current_uadb -= float(rec.get("Stat_2_Value", 0))
				uadb_changed = 1
			if uadb_changed == 1:
				updates.append({
					"table": "Characters",
					"record_id": Global.ACTIVE_USER_RECORD_ID,
					"field": "Universal_Added_Damage_Bonus",
					"value": current_uadb
				})

	if updates.size() > 0:
		Global.Update_Records(updates)

	if previous_equipped != "":
		Global.Log(
			"equipment",
			"unequip_artifact",
			"Artifact",
			previous_equipped,
			{"slot": slot, "previous": Global.CHARACTER_ARTIFACTS.get(previous_equipped, {})},
			{"slot": slot, "current": null}
		)

	_close_scene()

func _on_give_confirm_button_pressed() -> void:
	if receiver_option.get_selected_id() <= 0:
		return
	if _selected_row.is_empty():
		return
	if _selected_row.get("RecordID") == _original_row.get("RecordID"):
		return

	var artifact_name = str(_selected_row.get("Name", "Unknown"))
	var receiver = receiver_option.get_item_text(receiver_option.get_selected_id())
	_show_confirm_popup(
		"Give Artifact",
		"Give %s to %s? This cannot be undone." % [artifact_name, receiver],
		func():
			var updates = []
			updates.append({
				"table": "Character_Artifacts",
				"record_id": int(_selected_row.get("RecordID", 0)),
				"field": "Owner",
				"value": receiver
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
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
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
	_style_button(cancel_btn)
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size.x = 100
	_style_button(confirm_btn)
	confirm_btn.add_theme_color_override("font_color", RED)
	confirm_btn.pressed.connect(func():
		overlay.queue_free()
		on_confirm.call()
	)
	btn_row.add_child(confirm_btn)

# =============================================================================
# EXIT
# =============================================================================
func _on_exit_button_pressed() -> void:
	_close_scene()

func _close_scene() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

# =============================================================================
# HELPERS
# =============================================================================
func _num(v):
	var t = typeof(v)
	if t == TYPE_FLOAT or t == TYPE_INT:
		return v
	if t == TYPE_NIL:
		return 0.0
	return str(v).to_float()

func _fmt_num(v) -> String:
	if v == null:
		return ""
	return "%+0.2f" % _num(v)

func _id_num(v) -> float:
	return str(v).to_float()

# =============================================================================
# STYLING
# =============================================================================
func _style_line_edit(le: LineEdit) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_INSET
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	le.add_theme_stylebox_override("normal", sb)
	var sb_focus = sb.duplicate()
	sb_focus.border_color = ACCENT
	le.add_theme_stylebox_override("focus", sb_focus)
	le.add_theme_color_override("font_color", TEXT)
	le.add_theme_color_override("font_placeholder_color", TEXT_MUT)
	le.add_theme_font_size_override("font_size", FONT_BODY)

func _style_button(btn: Button, is_primary: bool = false) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = ACCENT_DIM if is_primary else BG_INSET
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = sb.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed = sb.duplicate()
	sb_pressed.bg_color = sb.bg_color.lightened(0.25)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_color_override("font_color", ACCENT if not is_primary else TEXT)
	btn.add_theme_color_override("font_hover_color", ACCENT if not is_primary else TEXT)
	btn.add_theme_font_size_override("font_size", FONT_BODY)

func _style_button_small(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_INSET
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = sb.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_font_size_override("font_size", FONT_PREV)

func _style_chip(btn: Button, on: bool) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = ACCENT if on else BG_INSET
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)
	var hover = sb.duplicate()
	hover.bg_color = sb.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed = sb.duplicate()
	pressed.bg_color = ACCENT
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", BG_DEEP if on else TEXT_SEC)
	btn.add_theme_color_override("font_hover_color", BG_DEEP if on else TEXT)

func _style_option_button(ob: OptionButton) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_INSET
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	ob.add_theme_stylebox_override("normal", sb)
	var hover = sb.duplicate()
	hover.border_color = ACCENT
	ob.add_theme_stylebox_override("hover", hover)
	ob.add_theme_color_override("font_color", TEXT)
	ob.add_theme_color_override("font_hover_color", TEXT)
	ob.add_theme_font_size_override("font_size", FONT_BODY)


func _save_split_layout() -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://ui_settings.cfg")
	cfg.set_value("artifact_layout", "main_split", _main_split.split_offset)
	cfg.save("user://ui_settings.cfg")

func _load_split_layout() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		if cfg.has_section_key("artifact_layout", "main_split"):
			_main_split.split_offset = cfg.get_value("artifact_layout", "main_split", 0)
