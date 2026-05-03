extends Panel

# ── Theme Constants (matches party_card.gd) ──────────────────────────────────
const COLOR_BG = Color(0.102, 0.122, 0.169)
const COLOR_BG_DARKER = Color(0.075, 0.090, 0.130)
const COLOR_BORDER = Color(0.165, 0.188, 0.251)
const COLOR_BORDER_ACTIVE = Color(0.292, 0.855, 0.498)  # green for active
const COLOR_BORDER_UNLOCKED = Color(0.788, 0.659, 0.298)  # gold
const COLOR_TEXT_PRIMARY = Color(0.941, 0.949, 0.973)
const COLOR_TEXT_MUTED = Color(0.533, 0.573, 0.659)
const COLOR_TEXT_DIM = Color(0.35, 0.38, 0.44)
const COLOR_GREEN = Color(0.133, 0.773, 0.369)
const COLOR_YELLOW = Color(0.918, 0.702, 0.031)
const COLOR_RED = Color(0.937, 0.267, 0.267)
const COLOR_ACCENT = Color(0.29, 0.56, 0.89)
const COLOR_CARD = Color(0.13, 0.15, 0.21)
const COLOR_CARD_HOVER = Color(0.16, 0.19, 0.26)
const COLOR_OVERLAY = Color(0.0, 0.0, 0.0, 0.6)
const COLOR_BADGE_GREEN = Color(0.08, 0.55, 0.25)
const COLOR_BADGE_YELLOW = Color(0.60, 0.48, 0.05)
const COLOR_BADGE_RED = Color(0.55, 0.12, 0.12)
const COLOR_BADGE_GRAY = Color(0.25, 0.27, 0.32)

const FONT_SIZE_TITLE = 24
const FONT_SIZE_NAME = 20
const FONT_SIZE_BODY = 18
const FONT_SIZE_SMALL = 16
const FONT_SIZE_BADGE = 16
const FONT_SIZE_HEADER = 20

const LEFT_WIDTH = 320
const CARD_HEIGHT = 72
const CORNER_RADIUS = 6

# ── Filter enum ──────────────────────────────────────────────────────────────
enum Filter { ALL, MET, UNLOCKED, ACTIVE }

# ── State ────────────────────────────────────────────────────────────────────
var _selected_companion_id: Variant = null
var _current_filter: int = Filter.ALL
var _search_text: String = ""

# ── Node refs (built in _ready) ─────────────────────────────────────────────
var _search_input: LineEdit
var _filter_container: HBoxContainer
var _filter_buttons: Array[Button] = []
var _companion_list_container: VBoxContainer
var _companion_scroll: ScrollContainer
var _detail_panel: PanelContainer
var _detail_container: VBoxContainer
var _main_split: HSplitContainer
var _profile_split: VSplitContainer


func _ready() -> void:
	_apply_root_style()
	_build_ui()
	_select_initial_companion()
	_refresh_list()
	_refresh_detail()
	_load_split_layout.call_deferred()


# ── Root Style ───────────────────────────────────────────────────────────────

func _apply_root_style() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_OVERLAY
	add_theme_stylebox_override("panel", sb)


# ── Build UI ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Margin around everything
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	# Main panel with dark bg
	var main_panel = PanelContainer.new()
	var main_sb = StyleBoxFlat.new()
	main_sb.bg_color = COLOR_BG
	main_sb.border_color = COLOR_BORDER
	main_sb.border_width_left = 1
	main_sb.border_width_right = 1
	main_sb.border_width_top = 1
	main_sb.border_width_bottom = 1
	main_sb.corner_radius_top_left = 8
	main_sb.corner_radius_top_right = 8
	main_sb.corner_radius_bottom_left = 8
	main_sb.corner_radius_bottom_right = 8
	main_panel.add_theme_stylebox_override("panel", main_sb)
	margin.add_child(main_panel)

	var inner_margin = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 0)
	inner_margin.add_theme_constant_override("margin_right", 0)
	inner_margin.add_theme_constant_override("margin_top", 0)
	inner_margin.add_theme_constant_override("margin_bottom", 0)
	main_panel.add_child(inner_margin)

	# HSplitContainer: left list | right detail (resizable)
	_main_split = HSplitContainer.new()
	_main_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_main_split.dragged.connect(func(_ofs): _save_split_layout())
	inner_margin.add_child(_main_split)

	# ── LEFT PANEL ───────────────────────────────────────────────────────
	var left = _build_left_panel()
	left.custom_minimum_size.x = LEFT_WIDTH
	left.size_flags_horizontal = Control.SIZE_FILL
	_main_split.add_child(left)

	# ── RIGHT PANEL ──────────────────────────────────────────────────────
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_sb = StyleBoxFlat.new()
	detail_sb.bg_color = COLOR_BG_DARKER
	_detail_panel.add_theme_stylebox_override("panel", detail_sb)
	_main_split.add_child(_detail_panel)

	# Close button (top right, added to root so it's above everything)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	close_btn.add_theme_color_override("font_color", Color(0.95, 0.6, 0.6))
	close_btn.add_theme_stylebox_override("normal", _make_flat_button_sb(COLOR_CARD))
	close_btn.add_theme_stylebox_override("hover", _make_flat_button_sb(COLOR_CARD_HOVER))
	close_btn.add_theme_stylebox_override("pressed", _make_flat_button_sb(COLOR_BG_DARKER))
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -100
	close_btn.offset_top = 10
	close_btn.offset_right = -10
	close_btn.offset_bottom = 44
	close_btn.z_index = 10
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)


func _build_left_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Padding inside left panel
	var pad = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(pad)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	pad.add_child(inner)

	# Title
	var title = Label.new()
	title.text = "Companions"
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	inner.add_child(title)

	# Search
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search companions..."
	_search_input.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	_search_input.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_search_input.add_theme_color_override("font_placeholder_color", COLOR_TEXT_MUTED)
	var search_sb = StyleBoxFlat.new()
	search_sb.bg_color = COLOR_BG_DARKER
	search_sb.border_color = COLOR_BORDER
	search_sb.set_border_width_all(1)
	search_sb.set_corner_radius_all(4)
	search_sb.content_margin_left = 10
	search_sb.content_margin_right = 10
	search_sb.content_margin_top = 6
	search_sb.content_margin_bottom = 6
	_search_input.add_theme_stylebox_override("normal", search_sb)
	var search_focus = search_sb.duplicate()
	search_focus.border_color = COLOR_ACCENT
	_search_input.add_theme_stylebox_override("focus", search_focus)
	_search_input.text_changed.connect(_on_search_changed)
	inner.add_child(_search_input)

	# Filter chips
	_filter_container = HBoxContainer.new()
	_filter_container.add_theme_constant_override("separation", 4)
	var filter_labels = ["All", "Met", "Unlocked", "Active"]
	for i in range(filter_labels.size()):
		var btn = Button.new()
		btn.text = filter_labels[i]
		btn.add_theme_font_size_override("font_size", FONT_SIZE_BADGE)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_filter_pressed.bind(i))
		_style_filter_button(btn, i == 0)
		_filter_buttons.append(btn)
		_filter_container.add_child(btn)
	inner.add_child(_filter_container)

	# Scroll for companion list
	_companion_scroll = ScrollContainer.new()
	_companion_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_companion_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_companion_scroll)

	_companion_list_container = VBoxContainer.new()
	_companion_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_companion_list_container.add_theme_constant_override("separation", 4)
	_companion_scroll.add_child(_companion_list_container)

	return vbox


# ── Refresh List ─────────────────────────────────────────────────────────────

func _refresh_list() -> void:
	# Clear existing
	for c in _companion_list_container.get_children():
		c.queue_free()

	var companions = _get_sorted_companions()

	for comp in companions:
		var name_str: String = str(comp.get("Name", ""))
		var met: bool = (comp.get("Met", false) == true)
		var unlocked: bool = (comp.get("Unlocked", false) == true)
		var is_active: bool = (comp.get("Active", false) == true)
		var player_chosen: bool = (comp.get("Player_Chosen", false) == true)
		var dm_set: bool = is_active and not player_chosen  # DM forced this companion active
		var comp_id = comp.get("id")

		# Apply filter
		if not _passes_filter(met, unlocked, is_active):
			continue
		if _search_text != "" and name_str.to_lower().find(_search_text.to_lower()) == -1:
			continue

		var card = _build_companion_card(comp_id, name_str, comp, met, unlocked, is_active, dm_set)
		_companion_list_container.add_child(card)


func _passes_filter(met: bool, unlocked: bool, active: bool) -> bool:
	match _current_filter:
		Filter.ALL:
			return true
		Filter.MET:
			return met
		Filter.UNLOCKED:
			return unlocked
		Filter.ACTIVE:
			return active
	return true


func _get_sorted_companions() -> Array:
	var all: Array = []
	var seen_names = {}
	for comp in Global.COMPANIONS.values():
		var n = str(comp.get("Name", ""))
		if n == "" or seen_names.has(n):
			continue
		seen_names[n] = true
		all.append(comp)
	# Sort: active first, then unlocked, then met, then unknown
	all.sort_custom(func(a, b):
		var sa = _sort_score(a)
		var sb2 = _sort_score(b)
		if sa != sb2:
			return sa > sb2
		return str(a.get("Name", "")) < str(b.get("Name", ""))
	)
	return all


func _sort_score(comp: Dictionary) -> int:
	var is_active = comp.get("Active", false) == true
	var player_chosen = comp.get("Player_Chosen", false) == true
	if is_active and not player_chosen:
		return 4  # DM-set always-active — top priority
	if is_active and player_chosen:
		return 3
	if comp.get("Unlocked", false) == true:
		return 2
	if comp.get("Met", false) == true:
		return 1
	return 0


func _build_companion_card(comp_id: Variant, name_str: String, comp: Dictionary,
		met: bool, unlocked: bool, active: bool, dm_set: bool = false) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size.y = CARD_HEIGHT

	var is_selected = (comp_id == _selected_companion_id)

	# Card style
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_HOVER if is_selected else COLOR_CARD
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8

	if active:
		sb.border_color = COLOR_BORDER_ACTIVE
		sb.set_border_width_all(2)
	elif is_selected:
		sb.border_color = COLOR_ACCENT
		sb.set_border_width_all(1)
	else:
		sb.border_color = COLOR_BORDER
		sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb)

	# Opacity
	if not met:
		card.modulate.a = 0.4
	elif not unlocked:
		card.modulate.a = 0.7

	# Content layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Left info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	# Name
	var lbl_name = Label.new()
	lbl_name.text = name_str if met else name_str
	lbl_name.add_theme_font_size_override("font_size", FONT_SIZE_NAME)
	lbl_name.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	info_vbox.add_child(lbl_name)

	# Element / Weapon / Owner line
	var detail_lbl = Label.new()
	if met:
		var elem = str(comp.get("Element", ""))
		var weap = str(comp.get("Weapon", ""))
		var owner = str(comp.get("Owner", ""))
		var detail_parts = []
		if elem != "":
			detail_parts.append(elem)
		if weap != "":
			detail_parts.append(weap)
		if owner != "":
			detail_parts.append(owner)
		detail_lbl.text = "  |  ".join(detail_parts)
	else:
		detail_lbl.text = "???  |  ???"
	detail_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	detail_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	info_vbox.add_child(detail_lbl)

	# Badges row
	var badge_row = HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 4)
	info_vbox.add_child(badge_row)

	if not met:
		badge_row.add_child(_make_badge("Not Met", COLOR_BADGE_GRAY))
	elif not unlocked:
		badge_row.add_child(_make_badge("Locked", COLOR_BADGE_RED))
		badge_row.add_child(_make_badge("Met", COLOR_BADGE_GRAY))
	elif dm_set:
		badge_row.add_child(_make_badge("Always Active", Color(0.4, 0.6, 0.9)))
		badge_row.add_child(_make_badge("DM Set", COLOR_BADGE_GRAY))
	elif active:
		badge_row.add_child(_make_badge("Active", COLOR_BADGE_GREEN))
		badge_row.add_child(_make_badge("Chosen", COLOR_BADGE_YELLOW))
	else:
		badge_row.add_child(_make_badge("Inactive", COLOR_BADGE_GRAY))
		badge_row.add_child(_make_badge("Unlocked", COLOR_BADGE_YELLOW))

	# Click handler
	var click = Button.new()
	click.flat = true
	click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	click.pressed.connect(_on_companion_selected.bind(comp_id))
	card.add_child(click)

	return card


func _make_badge(text: String, bg_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", sb)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_BADGE)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	panel.add_child(lbl)
	return panel


# ── Detail Panel ─────────────────────────────────────────────────────────────

func _refresh_detail() -> void:
	# Clear existing detail content
	for c in _detail_panel.get_children():
		c.queue_free()

	if _selected_companion_id == null:
		_show_empty_detail("Select a companion from the list.")
		return

	var comp = _get_companion_by_id(_selected_companion_id)
	if comp.is_empty():
		_show_empty_detail("Companion data not found.")
		return

	var name_str = str(comp.get("Name", ""))
	var met: bool = (comp.get("Met", false) == true)
	var unlocked: bool = (comp.get("Unlocked", false) == true)
	var is_active: bool = (comp.get("Active", false) == true)
	var player_chosen: bool = (comp.get("Player_Chosen", false) == true)
	var dm_set: bool = is_active and not player_chosen
	var active: bool = is_active and player_chosen

	if not met:
		_show_not_met_detail(name_str)
		return

	# Full profile for met companions
	_show_full_profile(comp, name_str, met, unlocked, active, dm_set)


func _show_empty_detail(msg: String) -> void:
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(center)

	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	center.add_child(lbl)


func _show_not_met_detail(name_str: String) -> void:
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(center)

	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD
	sb.border_color = COLOR_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon_lbl = Label.new()
	icon_lbl.text = "?"
	icon_lbl.add_theme_font_size_override("font_size", 48)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_lbl)

	var msg = Label.new()
	msg.text = "You haven't met %s yet." % name_str
	msg.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	msg.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var hint = Label.new()
	hint.text = "Continue exploring to find this companion."
	hint.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


func _show_full_profile(comp: Dictionary, name_str: String, met: bool,
		unlocked: bool, active: bool, dm_set: bool = false) -> void:
	# Main profile split: top (name + portrait/lore) vs bottom (abilities + button)
	_profile_split = VSplitContainer.new()
	_profile_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_profile_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_profile_split.dragged.connect(func(_ofs): _save_split_layout())
	_detail_panel.add_child(_profile_split)

	# Top section (scrollable): name + portrait + lore
	var top_scroll = ScrollContainer.new()
	top_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_profile_split.add_child(top_scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	top_scroll.add_child(vbox)

	# Store reference so abilities section can go to bottom split
	var _bottom_vbox = VBoxContainer.new()
	_bottom_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_vbox.add_theme_constant_override("separation", 10)

	# Top padding
	var pad_top = MarginContainer.new()
	pad_top.add_theme_constant_override("margin_left", 24)
	pad_top.add_theme_constant_override("margin_right", 24)
	pad_top.add_theme_constant_override("margin_top", 20)
	pad_top.add_theme_constant_override("margin_bottom", 0)
	vbox.add_child(pad_top)

	var header_content = VBoxContainer.new()
	header_content.add_theme_constant_override("separation", 12)
	pad_top.add_child(header_content)

	# ── NAME + BADGES ROW (top, full width) ─────────────────────────────
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	header_content.add_child(name_row)

	var lbl_name = Label.new()
	lbl_name.text = name_str
	lbl_name.add_theme_font_size_override("font_size", 26)
	lbl_name.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_row.add_child(lbl_name)

	var elem = str(comp.get("Element", ""))
	var weap = str(comp.get("Weapon", ""))
	var region = str(comp.get("Region", ""))
	var owner = str(comp.get("Owner", ""))
	if elem != "":
		name_row.add_child(_make_badge(elem, _element_color(elem)))
	if weap != "":
		name_row.add_child(_make_badge(weap, COLOR_BADGE_GRAY))
	if region != "":
		name_row.add_child(_make_badge(region, COLOR_BADGE_GRAY))
	if owner != "":
		name_row.add_child(_make_badge(owner, Color(0.25, 0.45, 0.35)))

	# Status + HP row
	var status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	header_content.add_child(status_row)

	if dm_set:
		status_row.add_child(_make_badge("Always Active", Color(0.4, 0.6, 0.9)))
	elif active:
		status_row.add_child(_make_badge("Active", COLOR_BADGE_GREEN))
	elif unlocked:
		status_row.add_child(_make_badge("Unlocked", COLOR_BADGE_YELLOW))
	else:
		status_row.add_child(_make_badge("Locked", COLOR_BADGE_RED))

	var hp_cur = comp.get("Current_Health", comp.get("HP", null))
	var hp_max = comp.get("Max_Health", comp.get("Max_HP", null))
	if hp_cur != null and hp_max != null:
		var hp_lbl = Label.new()
		hp_lbl.text = "HP: %s / %s" % [str(hp_cur), str(hp_max)]
		hp_lbl.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
		hp_lbl.add_theme_color_override("font_color", COLOR_GREEN)
		status_row.add_child(hp_lbl)

	# ── PORTRAIT (large) + LORE (scrollable) side by side ────────────────
	var portrait_lore_row = HBoxContainer.new()
	portrait_lore_row.add_theme_constant_override("separation", 20)
	portrait_lore_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var portrait_lore_pad = MarginContainer.new()
	portrait_lore_pad.add_theme_constant_override("margin_left", 24)
	portrait_lore_pad.add_theme_constant_override("margin_right", 24)
	portrait_lore_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_lore_pad.add_child(portrait_lore_row)
	vbox.add_child(portrait_lore_pad)

	# Large portrait
	var portrait_frame = PanelContainer.new()
	var pf_sb = StyleBoxFlat.new()
	pf_sb.bg_color = COLOR_CARD
	pf_sb.border_color = COLOR_BORDER
	pf_sb.set_border_width_all(2)
	pf_sb.set_corner_radius_all(8)
	portrait_frame.add_theme_stylebox_override("panel", pf_sb)
	portrait_frame.custom_minimum_size = Vector2(560, 560)
	portrait_lore_row.add_child(portrait_frame)

	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(260, 260)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_load_portrait(portrait, name_str)
	portrait_frame.add_child(portrait)

	# Lore in a scroll container next to the portrait
	var lore_text = str(comp.get("Lore", ""))
	var lore_col = VBoxContainer.new()
	lore_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_col.add_theme_constant_override("separation", 6)
	portrait_lore_row.add_child(lore_col)

	var lore_title = Label.new()
	lore_title.text = "Lore"
	lore_title.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	lore_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	lore_col.add_child(lore_title)

	var lore_scroll = ScrollContainer.new()
	lore_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lore_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lore_scroll.custom_minimum_size.y = 200
	lore_col.add_child(lore_scroll)

	if lore_text != "":
		var lore_body = RichTextLabel.new()
		lore_body.bbcode_enabled = true
		lore_body.fit_content = true
		lore_body.scroll_active = false
		lore_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lore_body.add_theme_font_size_override("normal_font_size", FONT_SIZE_BODY)
		lore_body.add_theme_color_override("default_color", COLOR_TEXT_MUTED)
		lore_body.text = lore_text
		lore_scroll.add_child(lore_body)
	else:
		var no_lore = Label.new()
		no_lore.text = "No lore available."
		no_lore.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
		no_lore.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		lore_scroll.add_child(no_lore)

	# Add bottom section to the split
	_profile_split.add_child(_bottom_vbox)

	# ── ABILITIES (in bottom split section) ──────────────────────────────
	var abilities_pad = MarginContainer.new()
	abilities_pad.add_theme_constant_override("margin_left", 24)
	abilities_pad.add_theme_constant_override("margin_right", 24)
	_bottom_vbox.add_child(abilities_pad)

	var abilities_section = VBoxContainer.new()
	abilities_section.add_theme_constant_override("separation", 10)
	abilities_pad.add_child(abilities_section)

	var abilities_title = Label.new()
	abilities_title.text = "Abilities"
	abilities_title.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	abilities_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	abilities_section.add_child(abilities_title)

	var abilities = _get_companion_abilities(comp)
	var ability_types = ["ChargedAttack", "Skill", "Burst"]
	var ability_labels = ["Charged Attack", "Skill", "Burst"]

	var abilities_grid = HBoxContainer.new()
	abilities_grid.add_theme_constant_override("separation", 10)
	abilities_section.add_child(abilities_grid)

	for i in range(ability_types.size()):
		var ab_type = ability_types[i]
		var ab_label = ability_labels[i]
		var ab_data: Dictionary = abilities.get(ab_type, {})
		var ab_card = _build_ability_card(ab_label, ab_type, ab_data)
		ab_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		abilities_grid.add_child(ab_card)

	# ── Use Button ───────────────────────────────────────────────────────
	var btn_pad = MarginContainer.new()
	btn_pad.add_theme_constant_override("margin_left", 24)
	btn_pad.add_theme_constant_override("margin_right", 24)
	btn_pad.add_theme_constant_override("margin_top", 4)
	btn_pad.add_theme_constant_override("margin_bottom", 24)
	_bottom_vbox.add_child(btn_pad)

	var use_btn = Button.new()
	use_btn.custom_minimum_size.y = 44

	if dm_set:
		use_btn.text = "Always Active (DM Set)"
		use_btn.disabled = true
		var btn_sb = _make_flat_button_sb(Color(0.2, 0.35, 0.55))
		btn_sb.content_margin_top = 10
		btn_sb.content_margin_bottom = 10
		use_btn.add_theme_stylebox_override("normal", btn_sb)
		use_btn.add_theme_stylebox_override("disabled", btn_sb)
	elif active:
		use_btn.text = "Using This Companion"
		use_btn.disabled = true
		var btn_sb = _make_flat_button_sb(COLOR_BADGE_GREEN)
		btn_sb.content_margin_top = 10
		btn_sb.content_margin_bottom = 10
		use_btn.add_theme_stylebox_override("normal", btn_sb)
		use_btn.add_theme_stylebox_override("disabled", btn_sb)
	elif unlocked:
		use_btn.text = "Use This Companion"
		use_btn.disabled = false
		var btn_sb = _make_flat_button_sb(COLOR_ACCENT)
		btn_sb.content_margin_top = 10
		btn_sb.content_margin_bottom = 10
		use_btn.add_theme_stylebox_override("normal", btn_sb)
		var hover_sb = _make_flat_button_sb(COLOR_ACCENT.lightened(0.15))
		hover_sb.content_margin_top = 10
		hover_sb.content_margin_bottom = 10
		use_btn.add_theme_stylebox_override("hover", hover_sb)
		var pressed_sb = _make_flat_button_sb(COLOR_ACCENT.darkened(0.1))
		pressed_sb.content_margin_top = 10
		pressed_sb.content_margin_bottom = 10
		use_btn.add_theme_stylebox_override("pressed", pressed_sb)
	else:
		use_btn.text = "Locked"
		use_btn.disabled = true
		var btn_sb = _make_flat_button_sb(COLOR_BADGE_GRAY)
		btn_sb.content_margin_top = 10
		btn_sb.content_margin_bottom = 10
		use_btn.add_theme_stylebox_override("normal", btn_sb)
		use_btn.add_theme_stylebox_override("disabled", btn_sb)

	use_btn.add_theme_font_size_override("font_size", FONT_SIZE_NAME)
	use_btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	use_btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_MUTED)
	use_btn.pressed.connect(_on_use_companion)
	btn_pad.add_child(use_btn)


# ── Ability Card ─────────────────────────────────────────────────────────────

func _build_ability_card(label: String, ab_type: String, data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD
	sb.border_color = COLOR_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Header row: name + type badge
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var title = Label.new()
	title.text = str(data.get("name", label)) if not data.is_empty() else label
	title.add_theme_font_size_override("font_size", FONT_SIZE_NAME)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var type_color = COLOR_BADGE_GRAY
	match ab_type:
		"ChargedAttack": type_color = COLOR_BADGE_YELLOW
		"Skill": type_color = Color(0.15, 0.35, 0.55)
		"Burst": type_color = Color(0.45, 0.15, 0.50)
	header.add_child(_make_badge(label, type_color))

	# Stats row
	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 12)
	vbox.add_child(stats_row)

	if data.is_empty():
		var no_data = Label.new()
		no_data.text = "No data available"
		no_data.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
		no_data.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		stats_row.add_child(no_data)
	else:
		var dice_val = data.get("dice", data.get("Dice", ""))
		var cd_val = data.get("cooldown", data.get("Cooldown", ""))
		var charge_val = data.get("charge_cost", data.get("Charge_Cost", ""))

		if str(dice_val) != "":
			stats_row.add_child(_make_stat_label("Dice", str(dice_val)))
		if str(cd_val) != "" and str(cd_val) != "0":
			stats_row.add_child(_make_stat_label("CD", str(cd_val)))
		if str(charge_val) != "" and str(charge_val) != "0":
			stats_row.add_child(_make_stat_label("Charge", str(charge_val)))

	# Description
	var desc_text = str(data.get("description", data.get("Description", "")))
	if desc_text != "":
		var desc = RichTextLabel.new()
		desc.bbcode_enabled = true
		desc.fit_content = true
		desc.scroll_active = false
		desc.custom_minimum_size.y = 40
		desc.add_theme_font_size_override("normal_font_size", FONT_SIZE_SMALL)
		desc.add_theme_color_override("default_color", COLOR_TEXT_MUTED)
		desc.text = desc_text
		vbox.add_child(desc)

	return card


func _make_stat_label(label_text: String, value_text: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var lbl = Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	hbox.add_child(lbl)

	var val = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	val.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	hbox.add_child(val)

	return hbox


# ── Data Helpers ─────────────────────────────────────────────────────────────

func _get_companion_by_id(comp_id: Variant) -> Dictionary:
	for comp in Global.COMPANIONS.values():
		if comp.get("id") == comp_id:
			return comp
	return {}


func _get_companion_abilities(comp: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var comp_id = int(comp.get("id", -1))
	for ability in Global.ACTIVE_ABILITIES.values():
		if ability.get("Entity_Type") == "Companion" and int(ability.get("Entity_ID", 0)) == comp_id:
			var ab_type = str(ability.get("Ability_Type", ""))
			var ab_id = str(int(ability.get("Ability_ID", 0)))
			if Global.ABILITIES.has(ab_id):
				out[ab_type] = Global.ABILITIES[ab_id]
	return out


func _load_portrait(tex_rect: TextureRect, companion_name: String) -> void:
	# Try splash art first, then character portrait
	var hyphenname = companion_name.to_lower().replace(" ", "-")
	var splash_path = "res://UI/Splash Arts/" + hyphenname + ".png"
	if ResourceLoader.exists(splash_path):
		var tex = load(splash_path)
		if tex is Texture2D:
			tex_rect.texture = tex
			return
	# Fallback to Character Portraits
	var portrait_path = "res://UI/Character Portraits/" + companion_name + ".png"
	if ResourceLoader.exists(portrait_path):
		var tex = load(portrait_path)
		if tex is Texture2D:
			tex_rect.texture = tex
			return
	tex_rect.texture = null


func _select_initial_companion() -> void:
	# Select currently active/chosen companion first
	for comp in Global.COMPANIONS.values():
		if comp.get("Player_Chosen", false) == true:
			_selected_companion_id = comp.get("id")
			return
	# Fallback: first companion
	for comp in Global.COMPANIONS.values():
		_selected_companion_id = comp.get("id")
		return


func _find_active_party_row_id() -> Variant:
	var active_name = str(Global.ACTIVE_USER_NAME)
	for rid in Global.PARTY.keys():
		var row: Dictionary = Global.PARTY[rid]
		for k in row.keys():
			if str(k).begins_with("party_member_") and str(row[k]) == active_name:
				return rid
	for rid in Global.PARTY.keys():
		return rid
	return null


# ── Element Colors ───────────────────────────────────────────────────────────

func _element_color(element: String) -> Color:
	match element.to_lower():
		"pyro": return Color(0.60, 0.15, 0.08)
		"hydro": return Color(0.08, 0.30, 0.60)
		"anemo": return Color(0.20, 0.50, 0.40)
		"electro": return Color(0.40, 0.15, 0.55)
		"dendro": return Color(0.20, 0.50, 0.12)
		"cryo": return Color(0.15, 0.40, 0.55)
		"geo": return Color(0.55, 0.42, 0.10)
		_: return COLOR_BADGE_GRAY


# ── Callbacks ────────────────────────────────────────────────────────────────

func _on_search_changed(new_text: String) -> void:
	_search_text = new_text
	_refresh_list()


func _on_filter_pressed(index: int) -> void:
	_current_filter = index
	for i in range(_filter_buttons.size()):
		_filter_buttons[i].button_pressed = (i == index)
		_style_filter_button(_filter_buttons[i], i == index)
	_refresh_list()


func _on_companion_selected(comp_id: Variant) -> void:
	_selected_companion_id = comp_id
	_refresh_list()
	_refresh_detail()


func _on_use_companion() -> void:
	if _selected_companion_id == null:
		return
	var comp = _get_companion_by_id(_selected_companion_id)
	if comp.is_empty():
		return

	var new_name = str(comp.get("Name", ""))
	var unlocked = (comp.get("Unlocked", false) == true)
	if not unlocked:
		return

	# Already chosen?
	if comp.get("Player_Chosen", false) == true and comp.get("Active", false) == true:
		return

	var updates: Array = []
	var old_names: Array = []
	var new_names: Array = [new_name]
	var companion_limit: int = int(Global.Current_Party.get("Companion_Limit", 1))

	# Collect currently player-chosen companions (NOT DM-set ones)
	# DM-set = Active=true but Player_Chosen=false — never touch these
	var player_chosen: Array = []
	for c in Global.COMPANIONS.values():
		if c.get("Player_Chosen", false) == true and str(c.get("Name", "")) != new_name:
			player_chosen.append(c)

	# If adding this one would exceed the limit, drop the oldest player-chosen
	# (oldest = first in the array, which is insertion order)
	while player_chosen.size() >= companion_limit:
		var oldest = player_chosen.pop_front()
		updates.append({"table": "Companions", "record_id": int(oldest.get("id", 0)), "field": "Player_Chosen", "value": false})
		updates.append({"table": "Companions", "record_id": int(oldest.get("id", 0)), "field": "Active", "value": false})
		old_names.append(str(oldest.get("Name", "")))

	# Activate selected companion
	updates.append({"table": "Companions", "record_id": int(comp.get("id", 0)), "field": "Player_Chosen", "value": true})
	updates.append({"table": "Companions", "record_id": int(comp.get("id", 0)), "field": "Active", "value": true})

	if updates.size() > 0:
		Global.Update_Records(updates)

		var party_row_id = _find_active_party_row_id()
		var related_id_str = ""
		if party_row_id != null:
			related_id_str = str(party_row_id)

		var meta: Dictionary = {
			"source": "CompanionsOverview",
			"actor": str(Global.ACTIVE_USER_NAME),
			"from": old_names,
			"to": new_names
		}

		Global.Log(
			"Companion",
			"Changed companion for party",
			"Party",
			related_id_str,
			{},
			{},
			meta,
			"success",
			"audit"
		)

	_on_close()


func _on_close() -> void:
	if get_parent() is Window:
		get_parent().queue_free()
	else:
		get_parent().queue_free()


func _save_split_layout() -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://ui_settings.cfg")
	cfg.set_value("companion_layout", "main_split", _main_split.split_offset)
	if _profile_split:
		cfg.set_value("companion_layout", "profile_split", _profile_split.split_offset)
	cfg.save("user://ui_settings.cfg")

func _load_split_layout() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		if cfg.has_section_key("companion_layout", "main_split"):
			_main_split.split_offset = cfg.get_value("companion_layout", "main_split", 0)
		if _profile_split and cfg.has_section_key("companion_layout", "profile_split"):
			_profile_split.split_offset = cfg.get_value("companion_layout", "profile_split", 0)


# ── Style Helpers ────────────────────────────────────────────────────────────

func _style_filter_button(btn: Button, is_active: bool) -> void:
	if is_active:
		var sb = StyleBoxFlat.new()
		sb.bg_color = COLOR_ACCENT
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", COLOR_TEXT_PRIMARY)
	else:
		var sb = StyleBoxFlat.new()
		sb.bg_color = COLOR_CARD
		sb.border_color = COLOR_BORDER
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		var hover_sb = sb.duplicate()
		hover_sb.bg_color = COLOR_CARD_HOVER
		btn.add_theme_stylebox_override("hover", hover_sb)
		btn.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_MUTED)
		btn.add_theme_color_override("font_hover_color", COLOR_TEXT_PRIMARY)


func _make_flat_button_sb(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _make_flat_separator(color: Color, width: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_left = width / 2
	sb.content_margin_right = width / 2
	return sb
