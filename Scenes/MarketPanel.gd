extends Control

# ── Palette ──────────────────────────────────────────────────────────
const BG_DEEP    = Color(0.039, 0.051, 0.075)
const BG_PANEL   = Color(0.071, 0.086, 0.118)
const BG_CARD    = Color(0.102, 0.122, 0.169)
const BG_INSET   = Color(0.055, 0.067, 0.098)
const BG_HOVER   = Color(0.133, 0.157, 0.22)
const BORDER     = Color(0.165, 0.188, 0.251)
const TEXT       = Color(0.941, 0.949, 0.973)
const TEXT_SEC   = Color(0.69, 0.722, 0.8)
const TEXT_MUT   = Color(0.533, 0.573, 0.659)
const ACCENT     = Color(0.788, 0.659, 0.298)
const ACCENT_DIM = Color(0.541, 0.455, 0.259)
const GOLD       = Color(1.0, 0.843, 0.0)
const GREEN      = Color(0.298, 0.788, 0.384)
const RED        = Color(0.886, 0.314, 0.314)

const RARITY_COLORS = {
	"Common":    Color(0.7, 0.7, 0.7),
	"Uncommon":  Color(0.42, 0.72, 0.42),
	"Rare":      Color(0.35, 0.55, 0.85),
	"Epic":      Color(0.65, 0.35, 0.85),
	"Legendary": Color(0.92, 0.68, 0.20),
}

const SHOP_CATEGORIES = [
	{"name": "Weapons",        "icon": "Weapons"},
	{"name": "Artifacts",      "icon": "Artifacts"},
	{"name": "Consumables",    "icon": "Consumables"},
	{"name": "Elemental_Gems", "icon": "Gems"},
	{"name": "Blacksmith",     "icon": "Blacksmith"},
	{"name": "Artisan",        "icon": "Artisan"},
]

const SHOP_DISPLAY_NAMES = {
	"Weapons": "Weapons",
	"Artifacts": "Artifacts",
	"Consumables": "Consumables",
	"Elemental_Gems": "Gems",
	"Blacksmith": "Blacksmith",
	"Artisan": "Artisan",
}

const CATEGORY_ICONS = {
	"Weapons": "",
	"Artifacts": "",
	"Consumables": "",
	"Gems": "",
	"Blacksmith": "",
	"Artisan": "",
}

# ── State ────────────────────────────────────────────────────────────
var _buy_mode = true
var _current_shop = "Weapons"
var _selected_index = -1
var _selected_entry = {}
var _cached_rows = []
var _search_text = ""

# ── Node refs (set in _ready) ───────────────────────────────────────
var _root_panel: PanelContainer
var _mora_label: Label
var _tab_buy: Button
var _tab_sell: Button
var _sidebar: VBoxContainer
var _sidebar_buttons = []
var _search_bar: LineEdit
var _item_scroll: ScrollContainer
var _item_list_vbox: VBoxContainer
var _preview_panel: PanelContainer
var _inner_split: HSplitContainer
var _outer_split: HSplitContainer
var _preview_vbox: VBoxContainer
var _preview_icon: TextureRect
var _preview_name: Label
var _preview_badges: HBoxContainer
var _preview_stats_grid: VBoxContainer
var _preview_effect: Label
var _preview_luck_note: Label
var _preview_qty_spin: SpinBox
var _preview_total_label: Label
var _preview_confirm_btn: Button
var _selected_row_node: Control = null

# ═════════════════════════════════════════════════════════════════════
#  BUILD UI
# ═════════════════════════════════════════════════════════════════════
func _ready() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)

	# Full-screen dark backdrop
	var bg = ColorRect.new()
	bg.color = BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Root panel
	_root_panel = PanelContainer.new()
	_root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root_sb = _flat(BG_DEEP)
	root_sb.content_margin_left = 0
	root_sb.content_margin_right = 0
	root_sb.content_margin_top = 0
	root_sb.content_margin_bottom = 0
	_root_panel.add_theme_stylebox_override("panel", root_sb)
	add_child(_root_panel)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	_root_panel.add_child(outer_vbox)

	# ── Header ───────────────────────────────────────────────────────
	var header = _build_header()
	outer_vbox.add_child(header)

	# ── Tab bar ──────────────────────────────────────────────────────
	var tab_bar = _build_tab_bar()
	outer_vbox.add_child(tab_bar)

	# ── Body (3-col / 2-col) ────────────────────────────────────────
	_outer_split = _build_body()
	_outer_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(_outer_split)

	# Connect split dragged signals for persistence
	_outer_split.dragged.connect(func(_ofs): _save_layout())
	_inner_split.dragged.connect(func(_ofs): _save_layout())
	_load_layout.call_deferred()

	# ── Initial state ───────────────────────────────────────────────
	_set_mode_buy(true)
	_refresh_mora()

func _build_header() -> PanelContainer:
	var hdr_panel = PanelContainer.new()
	var hdr_sb = _flat(BG_PANEL)
	hdr_sb.content_margin_left = 24
	hdr_sb.content_margin_right = 24
	hdr_sb.content_margin_top = 12
	hdr_sb.content_margin_bottom = 12
	hdr_sb.border_color = BORDER
	hdr_sb.border_width_bottom = 1
	hdr_panel.add_theme_stylebox_override("panel", hdr_sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hdr_panel.add_child(hbox)

	var title = Label.new()
	title.text = "MARKET"
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 28)
	hbox.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Mora display
	var mora_hbox = HBoxContainer.new()
	mora_hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(mora_hbox)

	var mora_icon_lbl = Label.new()
	mora_icon_lbl.text = "Mora:"
	mora_icon_lbl.add_theme_color_override("font_color", GOLD)
	mora_icon_lbl.add_theme_font_size_override("font_size", 20)
	mora_hbox.add_child(mora_icon_lbl)

	_mora_label = Label.new()
	_mora_label.text = "0"
	_mora_label.add_theme_color_override("font_color", GOLD)
	_mora_label.add_theme_font_size_override("font_size", 20)
	mora_hbox.add_child(_mora_label)

	# Exit button
	var exit_btn = Button.new()
	exit_btn.text = "X"
	exit_btn.custom_minimum_size = Vector2(40, 40)
	exit_btn.add_theme_font_size_override("font_size", 18)
	exit_btn.add_theme_color_override("font_color", TEXT)
	var exit_sb_n = _flat(Color(0.6, 0.2, 0.2))
	exit_sb_n.set_corner_radius_all(6)
	exit_btn.add_theme_stylebox_override("normal", exit_sb_n)
	var exit_sb_h = _flat(Color(0.75, 0.25, 0.25))
	exit_sb_h.set_corner_radius_all(6)
	exit_btn.add_theme_stylebox_override("hover", exit_sb_h)
	var exit_sb_p = _flat(Color(0.5, 0.15, 0.15))
	exit_sb_p.set_corner_radius_all(6)
	exit_btn.add_theme_stylebox_override("pressed", exit_sb_p)
	exit_btn.pressed.connect(_on_exit_pressed)
	hbox.add_child(exit_btn)

	return hdr_panel

func _build_tab_bar() -> PanelContainer:
	var bar_panel = PanelContainer.new()
	var bar_sb = _flat(BG_PANEL)
	bar_sb.content_margin_left = 24
	bar_sb.content_margin_right = 24
	bar_sb.content_margin_top = 6
	bar_sb.content_margin_bottom = 6
	bar_sb.border_color = BORDER
	bar_sb.border_width_bottom = 1
	bar_panel.add_theme_stylebox_override("panel", bar_sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	bar_panel.add_child(hbox)

	_tab_buy = _make_tab_button("Buy")
	_tab_buy.pressed.connect(func(): _set_mode_buy(true))
	hbox.add_child(_tab_buy)

	_tab_sell = _make_tab_button("Sell")
	_tab_sell.pressed.connect(func(): _set_mode_buy(false))
	hbox.add_child(_tab_sell)

	return bar_panel

func _make_tab_button(label_text: String) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(100, 36)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", TEXT)
	var sb_n = _flat(BG_CARD)
	sb_n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb_n)
	var sb_h = _flat(BG_HOVER)
	sb_h.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p = _flat(ACCENT_DIM)
	sb_p.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", sb_p)
	return btn

func _build_body() -> HSplitContainer:
	var body = HSplitContainer.new()
	body.dragger_visibility = SplitContainer.DRAGGER_VISIBLE

	# ── Sidebar (categories) ────────────────────────────────────────
	_sidebar = VBoxContainer.new()
	_sidebar.custom_minimum_size = Vector2(200, 0)
	_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_panel = PanelContainer.new()
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_sb = _flat(BG_PANEL)
	side_sb.content_margin_left = 8
	side_sb.content_margin_right = 8
	side_sb.content_margin_top = 12
	side_sb.content_margin_bottom = 12
	side_sb.border_color = BORDER
	side_sb.border_width_right = 1
	side_panel.add_theme_stylebox_override("panel", side_sb)
	side_panel.add_child(_sidebar)
	body.add_child(side_panel)

	_sidebar.add_theme_constant_override("separation", 4)

	var side_title = Label.new()
	side_title.text = "Categories"
	side_title.add_theme_color_override("font_color", TEXT_SEC)
	side_title.add_theme_font_size_override("font_size", 14)
	_sidebar.add_child(side_title)

	for cat in SHOP_CATEGORIES:
		var btn = Button.new()
		btn.text = SHOP_DISPLAY_NAMES.get(cat["name"], cat["name"].replace("_", " "))
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", TEXT)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 36)
		var sb_n = _flat(Color.TRANSPARENT)
		sb_n.set_corner_radius_all(4)
		sb_n.content_margin_left = 8
		btn.add_theme_stylebox_override("normal", sb_n)
		var sb_h = _flat(BG_HOVER)
		sb_h.set_corner_radius_all(4)
		sb_h.content_margin_left = 8
		btn.add_theme_stylebox_override("hover", sb_h)
		var sb_p = _flat(ACCENT_DIM)
		sb_p.set_corner_radius_all(4)
		sb_p.content_margin_left = 8
		btn.add_theme_stylebox_override("pressed", sb_p)
		var cat_name = cat["name"]
		btn.pressed.connect(func(): _on_category_selected(cat_name))
		_sidebar.add_child(btn)
		_sidebar_buttons.append(btn)

	# ── Inner split: center (item list) + right (preview) ──────────
	_inner_split = HSplitContainer.new()
	_inner_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_inner_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_inner_split)

	# ── Center column (item list) ───────────────────────────────────
	var center_panel = PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var center_sb = _flat(BG_DEEP)
	center_sb.content_margin_left = 12
	center_sb.content_margin_right = 12
	center_sb.content_margin_top = 12
	center_sb.content_margin_bottom = 12
	center_panel.add_theme_stylebox_override("panel", center_sb)
	_inner_split.add_child(center_panel)

	var center_vbox = VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 8)
	center_panel.add_child(center_vbox)

	# Search bar
	_search_bar = LineEdit.new()
	_search_bar.placeholder_text = "Search items..."
	_search_bar.custom_minimum_size = Vector2(0, 36)
	_search_bar.add_theme_font_size_override("font_size", 14)
	_search_bar.add_theme_color_override("font_color", TEXT)
	_search_bar.add_theme_color_override("font_placeholder_color", TEXT_MUT)
	var search_sb = _flat(BG_CARD)
	search_sb.set_corner_radius_all(6)
	search_sb.content_margin_left = 10
	search_sb.content_margin_right = 10
	search_sb.border_color = BORDER
	search_sb.set_border_width_all(1)
	_search_bar.add_theme_stylebox_override("normal", search_sb)
	_search_bar.text_changed.connect(func(t): _search_text = t.strip_edges().to_lower(); _refresh_item_list())
	center_vbox.add_child(_search_bar)

	# Scrollable item list
	_item_scroll = ScrollContainer.new()
	_item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_vbox.add_child(_item_scroll)

	_item_list_vbox = VBoxContainer.new()
	_item_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list_vbox.add_theme_constant_override("separation", 4)
	_item_scroll.add_child(_item_list_vbox)

	# ── Right column (preview) ──────────────────────────────────────
	_preview_panel = PanelContainer.new()
	_preview_panel.custom_minimum_size = Vector2(320, 0)
	_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_sb = _flat(BG_PANEL)
	preview_sb.content_margin_left = 16
	preview_sb.content_margin_right = 16
	preview_sb.content_margin_top = 16
	preview_sb.content_margin_bottom = 16
	preview_sb.border_color = BORDER
	preview_sb.border_width_left = 1
	_preview_panel.add_theme_stylebox_override("panel", preview_sb)
	_inner_split.add_child(_preview_panel)

	_build_preview_contents()

	return body

func _build_preview_contents() -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_preview_panel.add_child(scroll)

	_preview_vbox = VBoxContainer.new()
	_preview_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_preview_vbox)

	# Icon
	_preview_icon = TextureRect.new()
	_preview_icon.custom_minimum_size = Vector2(0, 200)
	_preview_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_icon.visible = false
	_preview_vbox.add_child(_preview_icon)

	# Name
	_preview_name = Label.new()
	_preview_name.text = "Select an item"
	_preview_name.add_theme_color_override("font_color", TEXT)
	_preview_name.add_theme_font_size_override("font_size", 20)
	_preview_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_vbox.add_child(_preview_name)

	# Badges row
	_preview_badges = HBoxContainer.new()
	_preview_badges.add_theme_constant_override("separation", 6)
	_preview_badges.visible = false
	_preview_vbox.add_child(_preview_badges)

	# Stats grid
	_preview_stats_grid = VBoxContainer.new()
	_preview_stats_grid.add_theme_constant_override("separation", 4)
	_preview_stats_grid.visible = false
	_preview_vbox.add_child(_preview_stats_grid)

	# Effect
	_preview_effect = Label.new()
	_preview_effect.add_theme_color_override("font_color", TEXT_SEC)
	_preview_effect.add_theme_font_size_override("font_size", 14)
	_preview_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_effect.visible = false
	_preview_vbox.add_child(_preview_effect)

	# Luck note
	_preview_luck_note = Label.new()
	_preview_luck_note.add_theme_font_size_override("font_size", 14)
	_preview_luck_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_luck_note.visible = false
	_preview_vbox.add_child(_preview_luck_note)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	_preview_vbox.add_child(sep)

	# Quantity row
	var qty_hbox = HBoxContainer.new()
	qty_hbox.add_theme_constant_override("separation", 8)
	_preview_vbox.add_child(qty_hbox)

	var qty_label = Label.new()
	qty_label.text = "Qty:"
	qty_label.add_theme_color_override("font_color", TEXT_SEC)
	qty_label.add_theme_font_size_override("font_size", 14)
	qty_hbox.add_child(qty_label)

	_preview_qty_spin = SpinBox.new()
	_preview_qty_spin.min_value = 0
	_preview_qty_spin.max_value = 0
	_preview_qty_spin.value = 0
	_preview_qty_spin.custom_minimum_size = Vector2(80, 0)
	_preview_qty_spin.add_theme_font_size_override("font_size", 14)
	_preview_qty_spin.value_changed.connect(_on_quantity_changed)
	qty_hbox.add_child(_preview_qty_spin)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_hbox.add_child(spacer)

	# Total cost display
	_preview_total_label = Label.new()
	_preview_total_label.text = ""
	_preview_total_label.add_theme_color_override("font_color", GOLD)
	_preview_total_label.add_theme_font_size_override("font_size", 16)
	_preview_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_preview_vbox.add_child(_preview_total_label)

	# Confirm button
	_preview_confirm_btn = Button.new()
	_preview_confirm_btn.text = "Select an item first"
	_preview_confirm_btn.custom_minimum_size = Vector2(0, 44)
	_preview_confirm_btn.add_theme_font_size_override("font_size", 16)
	_preview_confirm_btn.add_theme_color_override("font_color", TEXT)
	_preview_confirm_btn.disabled = true
	var btn_sb_n = _flat(ACCENT)
	btn_sb_n.set_corner_radius_all(6)
	_preview_confirm_btn.add_theme_stylebox_override("normal", btn_sb_n)
	var btn_sb_h = _flat(ACCENT.lightened(0.15))
	btn_sb_h.set_corner_radius_all(6)
	_preview_confirm_btn.add_theme_stylebox_override("hover", btn_sb_h)
	var btn_sb_p = _flat(ACCENT.darkened(0.15))
	btn_sb_p.set_corner_radius_all(6)
	_preview_confirm_btn.add_theme_stylebox_override("pressed", btn_sb_p)
	var btn_sb_d = _flat(BG_CARD)
	btn_sb_d.set_corner_radius_all(6)
	_preview_confirm_btn.add_theme_stylebox_override("disabled", btn_sb_d)
	_preview_confirm_btn.add_theme_color_override("font_disabled_color", TEXT_MUT)
	_preview_confirm_btn.pressed.connect(_on_confirm_pressed)
	_preview_vbox.add_child(_preview_confirm_btn)


# ═════════════════════════════════════════════════════════════════════
#  MODE / TAB SWITCHING
# ═════════════════════════════════════════════════════════════════════
func _set_mode_buy(is_buy: bool) -> void:
	_buy_mode = is_buy
	_update_tab_visuals()

	# Sidebar visible only in buy mode
	_sidebar.get_parent().visible = is_buy

	if is_buy:
		_on_category_selected(_current_shop)
	else:
		_clear_selection()
		_refresh_item_list()

func _update_tab_visuals() -> void:
	var active_sb = _flat(ACCENT)
	active_sb.set_corner_radius_all(6)
	var inactive_sb = _flat(BG_CARD)
	inactive_sb.set_corner_radius_all(6)

	if _buy_mode:
		_tab_buy.add_theme_stylebox_override("normal", active_sb)
		_tab_buy.add_theme_color_override("font_color", TEXT)
		_tab_sell.add_theme_stylebox_override("normal", inactive_sb)
		_tab_sell.add_theme_color_override("font_color", TEXT)
	else:
		_tab_sell.add_theme_stylebox_override("normal", active_sb)
		_tab_sell.add_theme_color_override("font_color", TEXT)
		_tab_buy.add_theme_stylebox_override("normal", inactive_sb)
		_tab_buy.add_theme_color_override("font_color", TEXT)

func _update_sidebar_highlight() -> void:
	for i in range(SHOP_CATEGORIES.size()):
		var btn = _sidebar_buttons[i]
		var cat_name = SHOP_CATEGORIES[i]["name"]
		if cat_name == _current_shop:
			var sb = _flat(ACCENT_DIM)
			sb.set_corner_radius_all(4)
			sb.content_margin_left = 8
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_color_override("font_color", ACCENT)
		else:
			var sb = _flat(Color.TRANSPARENT)
			sb.set_corner_radius_all(4)
			sb.content_margin_left = 8
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_color_override("font_color", TEXT)


# ═════════════════════════════════════════════════════════════════════
#  DATA EVENTS
# ═════════════════════════════════════════════════════════════════════
func _on_data_load_complete() -> void:
	_refresh_mora()
	_clear_selection()
	_refresh_item_list()

func _on_category_selected(cat_name: String) -> void:
	_current_shop = cat_name
	_update_sidebar_highlight()
	_clear_selection()
	_refresh_item_list()

func _refresh_mora() -> void:
	var mora = int(Global.Current_Party.get("Mora", 0))
	_mora_label.text = _format_number(mora)


# ═════════════════════════════════════════════════════════════════════
#  ITEM LIST
# ═════════════════════════════════════════════════════════════════════
func _refresh_item_list() -> void:
	# Clear old rows
	for c in _item_list_vbox.get_children():
		c.queue_free()

	# Gather rows
	var rows = []
	if _buy_mode:
		rows = Market.Get_Shop(_current_shop)
		# Filter zero-qty
		var filtered = []
		for r in rows:
			var rq = 1
			if r.has("Quantity") and r["Quantity"] != null:
				rq = int(r["Quantity"])
			if rq > 0:
				filtered.append(r)
		rows = filtered
	else:
		rows = _gather_sell_inventory_rows()

	# Apply search filter
	if _search_text != "":
		var filtered = []
		for r in rows:
			var name_str = _get_row_display_name(r).to_lower()
			if name_str.find(_search_text) >= 0:
				filtered.append(r)
		rows = filtered

	_cached_rows = rows

	if rows.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No items available"
		empty_lbl.add_theme_color_override("font_color", TEXT_MUT)
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_item_list_vbox.add_child(empty_lbl)
		return

	for i in range(rows.size()):
		var row = rows[i]
		var row_node = _build_item_row(row, i)
		_item_list_vbox.add_child(row_node)

func _build_item_row(r: Dictionary, idx: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 48)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = _flat(BG_CARD)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Icon area
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex = _try_load_icon(r)
	if icon_tex:
		icon_rect.texture = icon_tex
	hbox.add_child(icon_rect)

	# Name + type/rarity
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = _get_row_display_name(r)
	name_lbl.add_theme_color_override("font_color", TEXT)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_vbox.add_child(name_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = _get_row_subtitle(r)
	sub_lbl.add_theme_color_override("font_color", TEXT_MUT)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(sub_lbl)

	# Price
	if _buy_mode:
		var price_lbl = Label.new()
		var base_val = int(r.get("Value", 0))
		var luck = Market.Get_Daily_Luck()
		var eff_price = Market._buy_price_with_luck(base_val, luck)
		price_lbl.text = str(eff_price) + " Mora"
		price_lbl.add_theme_color_override("font_color", ACCENT)
		price_lbl.add_theme_font_size_override("font_size", 14)
		hbox.add_child(price_lbl)

	# Stock / owned qty
	var qty_lbl = Label.new()
	if _buy_mode:
		var qty = int(r.get("Quantity", 0))
		qty_lbl.text = "x" + str(qty)
	else:
		var qty = int(r.get("Quantity", 0))
		qty_lbl.text = "Own: x" + str(qty)
	qty_lbl.add_theme_color_override("font_color", TEXT_SEC)
	qty_lbl.add_theme_font_size_override("font_size", 14)
	qty_lbl.custom_minimum_size = Vector2(60, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(qty_lbl)

	# Click handler via button overlay
	var click_btn = Button.new()
	click_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent_sb = StyleBoxEmpty.new()
	click_btn.add_theme_stylebox_override("normal", transparent_sb)
	click_btn.add_theme_stylebox_override("hover", transparent_sb)
	click_btn.add_theme_stylebox_override("pressed", transparent_sb)
	click_btn.add_theme_stylebox_override("focus", transparent_sb)
	click_btn.pressed.connect(func(): _on_row_clicked(idx, panel))
	panel.add_child(click_btn)

	return panel


# ═════════════════════════════════════════════════════════════════════
#  SELECTION & PREVIEW
# ═════════════════════════════════════════════════════════════════════
func _on_row_clicked(idx: int, row_node: Control) -> void:
	# Deselect old
	if _selected_row_node != null and is_instance_valid(_selected_row_node):
		var old_sb = _flat(BG_CARD)
		old_sb.set_corner_radius_all(4)
		old_sb.content_margin_left = 12
		old_sb.content_margin_right = 12
		old_sb.content_margin_top = 6
		old_sb.content_margin_bottom = 6
		old_sb.border_color = BORDER
		old_sb.set_border_width_all(1)
		_selected_row_node.add_theme_stylebox_override("panel", old_sb)

	_selected_index = idx
	_selected_row_node = row_node

	# Highlight new
	var sel_sb = _flat(BG_HOVER)
	sel_sb.set_corner_radius_all(4)
	sel_sb.content_margin_left = 12
	sel_sb.content_margin_right = 12
	sel_sb.content_margin_top = 6
	sel_sb.content_margin_bottom = 6
	sel_sb.border_color = ACCENT
	sel_sb.set_border_width_all(2)
	row_node.add_theme_stylebox_override("panel", sel_sb)

	if idx >= 0 and idx < _cached_rows.size():
		_selected_entry = _cached_rows[idx].duplicate(true)
		_show_preview(_selected_entry)

func _clear_selection() -> void:
	_selected_index = -1
	_selected_entry = {}
	_selected_row_node = null
	_reset_preview()

func _reset_preview() -> void:
	_preview_name.text = "Select an item"
	_preview_icon.visible = false
	_preview_badges.visible = false
	_preview_stats_grid.visible = false
	_preview_effect.visible = false
	_preview_luck_note.visible = false
	_preview_total_label.text = ""
	_preview_qty_spin.min_value = 0
	_preview_qty_spin.max_value = 0
	_preview_qty_spin.value = 0
	_preview_confirm_btn.text = "Select an item first"
	_preview_confirm_btn.disabled = true

func _show_preview(r: Dictionary) -> void:
	# Icon
	var tex = _try_load_icon(r)
	if tex:
		_preview_icon.texture = tex
		_preview_icon.visible = true
	else:
		_preview_icon.visible = false

	# Name
	_preview_name.text = _get_row_display_name(r)

	# Badges
	_build_badges(r)
	_preview_badges.visible = true

	# Stats grid
	_build_stats_grid(r)
	_preview_stats_grid.visible = true

	# Effect
	var effect_text = r.get("Effect", null)
	if effect_text != null and str(effect_text) != "":
		_preview_effect.text = "Effect: " + str(effect_text)
		_preview_effect.visible = true
	else:
		_preview_effect.visible = false

	# Luck modifier note
	_update_luck_note(r)

	# Quantity
	var max_qty = 1
	if _buy_mode:
		max_qty = int(r.get("Quantity", 1))
	else:
		if r.get("__table", "") == "Character_Items":
			max_qty = int(r.get("Quantity", 1))
		elif r.get("__table", "") == "Character_Weapons":
			max_qty = int(r.get("Quantity", 1))
		else:
			max_qty = 1
	_preview_qty_spin.min_value = 1
	_preview_qty_spin.max_value = max(max_qty, 1)
	_preview_qty_spin.value = 1

	_preview_confirm_btn.disabled = false
	_update_price_display()

func _build_badges(r: Dictionary) -> void:
	# Clear old badges
	for c in _preview_badges.get_children():
		c.queue_free()

	var has_badges = false

	# Rarity badge
	var rarity = str(r.get("Rarity", ""))
	if rarity != "" and rarity != "null":
		var badge = _make_badge(rarity, RARITY_COLORS.get(rarity, TEXT_SEC))
		_preview_badges.add_child(badge)
		has_badges = true

	# Type badge
	var type_str = str(r.get("Type", ""))
	if type_str != "" and type_str != "null":
		var badge = _make_badge(type_str, TEXT_SEC)
		_preview_badges.add_child(badge)
		has_badges = true

	# Region badge
	var region = str(r.get("Region", ""))
	if region != "" and region != "null":
		var badge = _make_badge(region, TEXT_MUT)
		_preview_badges.add_child(badge)
		has_badges = true

	_preview_badges.visible = has_badges

func _make_badge(text: String, color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = _flat(color.darkened(0.7))
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.border_color = color.darkened(0.3)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 14)
	panel.add_child(lbl)
	return panel

func _build_stats_grid(r: Dictionary) -> void:
	for c in _preview_stats_grid.get_children():
		c.queue_free()

	var has_stats = false

	# Stat 1
	if r.get("Stat_1_Type") != null and str(r.get("Stat_1_Type")) != "":
		_add_stat_row(str(r.get("Stat_1_Type")), str(r.get("Stat_1_Value")))
		has_stats = true
	if r.get("Stat_2_Type") != null and str(r.get("Stat_2_Type")) != "":
		_add_stat_row(str(r.get("Stat_2_Type")), str(r.get("Stat_2_Value")))
		has_stats = true
	if r.get("Stat_3_Type") != null and str(r.get("Stat_3_Type")) != "":
		_add_stat_row(str(r.get("Stat_3_Type")), str(r.get("Stat_3_Value")))
		has_stats = true

	# Description for items
	var desc = r.get("Description", null)
	if desc != null and str(desc) != "" and str(desc) != "null":
		_add_stat_row("Description", str(desc))
		has_stats = true

	_preview_stats_grid.visible = has_stats

func _add_stat_row(stat_name: String, stat_val: String) -> void:
	var lbl = Label.new()
	lbl.text = stat_name.replace("_", " ") + ": " + stat_val
	lbl.add_theme_color_override("font_color", TEXT)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_stats_grid.add_child(lbl)

func _update_luck_note(r: Dictionary) -> void:
	var luck = Market.Get_Daily_Luck()
	var note_text = ""
	var note_color = TEXT_MUT

	if _buy_mode:
		var base = int(r.get("Value", 0))
		var effective = Market._buy_price_with_luck(base, luck)
		var diff = effective - base
		if diff < 0:
			note_text = "Luck discount: %d off per unit" % abs(diff)
			note_color = GREEN
		elif diff > 0:
			note_text = "Luck markup: +%d per unit" % diff
			note_color = RED
		else:
			note_text = "No luck modifier today"
			note_color = TEXT_MUT
	else:
		var rate = Market._sell_rate_with_luck(luck)
		var pct = int(round(rate * 100.0))
		if luck > 60:
			note_text = "Sell rate: %d%% (luck bonus)" % pct
			note_color = GREEN
		elif luck < 50:
			note_text = "Sell rate: %d%% (luck penalty)" % pct
			note_color = RED
		else:
			note_text = "Sell rate: %d%%" % pct
			note_color = TEXT_MUT

	_preview_luck_note.text = note_text
	_preview_luck_note.add_theme_color_override("font_color", note_color)
	_preview_luck_note.visible = true
	_preview_luck_note.visible = true


# ═════════════════════════════════════════════════════════════════════
#  PRICE DISPLAY
# ═════════════════════════════════════════════════════════════════════
func _on_quantity_changed(_value: float) -> void:
	_update_price_display()

func _update_price_display() -> void:
	if _selected_index < 0 or _selected_entry.is_empty():
		_preview_total_label.text = ""
		_preview_confirm_btn.text = "Select an item first"
		_preview_confirm_btn.disabled = true
		return

	var qty = int(_preview_qty_spin.value)
	var unit_base = int(_selected_entry.get("Value", 0))
	var luck = Market.Get_Daily_Luck()

	if _buy_mode:
		var unit_price = Market._buy_price_with_luck(unit_base, luck)
		var total = unit_price * qty
		_preview_total_label.text = "Total: %s Mora" % _format_number(total)
		_preview_confirm_btn.text = "Buy for %s Mora" % _format_number(total)
		_preview_confirm_btn.disabled = false
	else:
		var total_gain = Market.Price_Sell_Preview(_selected_entry, qty)
		_preview_total_label.text = "You receive: %s Mora" % _format_number(total_gain)
		_preview_confirm_btn.text = "Sell for %s Mora" % _format_number(total_gain)
		_preview_confirm_btn.disabled = false


# ═════════════════════════════════════════════════════════════════════
#  CONFIRM / BUY / SELL
# ═════════════════════════════════════════════════════════════════════
func _on_confirm_pressed() -> void:
	if _selected_index < 0 or _selected_entry.is_empty():
		return

	var qty = int(_preview_qty_spin.value)
	var action_text = ""

	if _buy_mode:
		var unit_base = int(_selected_entry.get("Value", 0))
		var luck = Market.Get_Daily_Luck()
		var unit_price = Market._buy_price_with_luck(unit_base, luck)
		var total = unit_price * qty
		action_text = "Buy %d x %s for %s Mora?" % [qty, _get_row_display_name(_selected_entry), _format_number(total)]
	else:
		var total_gain = Market.Price_Sell_Preview(_selected_entry, qty)
		action_text = "Sell %d x %s for %s Mora?" % [qty, _get_row_display_name(_selected_entry), _format_number(total_gain)]

	_show_confirm_popup("Confirm Transaction", action_text, func():
		if _buy_mode:
			_execute_buy(qty)
		else:
			_execute_sell(qty)
	)

func _execute_buy(qty: int) -> void:
	var ok = Market.Buy_Commit(_current_shop, _selected_index, qty)
	if ok:
		_refresh_mora()
		_clear_selection()
		_refresh_item_list()
	else:
		_show_error("Purchase failed. Check your Mora balance.")

func _execute_sell(qty: int) -> void:
	var gain = Market.Sell_Commit(_selected_entry, qty)
	_log_sell_item(_selected_entry, qty, gain)
	_remove_sold_from_inventory(_selected_entry, qty)
	_add_mora(gain)
	_refresh_mora()
	_clear_selection()
	_refresh_item_list()

func _show_error(msg: String) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 60
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 140)
	var sb = _flat(BG_PANEL)
	sb.border_color = RED
	sb.set_border_width_all(2)
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

	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", RED)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(0, 36)
	ok_btn.add_theme_font_size_override("font_size", 14)
	var ok_sb = _flat(BG_CARD)
	ok_sb.set_corner_radius_all(6)
	ok_btn.add_theme_stylebox_override("normal", ok_sb)
	ok_btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(ok_btn)


# ═════════════════════════════════════════════════════════════════════
#  CONFIRMATION POPUP
# ═════════════════════════════════════════════════════════════════════
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
	panel.custom_minimum_size = Vector2(420, 180)
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
	title_lbl.add_theme_color_override("font_color", ACCENT)
	title_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_lbl)

	var msg_lbl = Label.new()
	msg_lbl.text = message
	msg_lbl.add_theme_color_override("font_color", TEXT)
	msg_lbl.add_theme_font_size_override("font_size", 16)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_lbl)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	var cancel_sb = _flat(BG_CARD)
	cancel_sb.set_corner_radius_all(6)
	cancel_btn.add_theme_stylebox_override("normal", cancel_sb)
	cancel_btn.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(100, 36)
	confirm_btn.add_theme_font_size_override("font_size", 14)
	confirm_btn.add_theme_color_override("font_color", TEXT)
	var confirm_sb = _flat(ACCENT)
	confirm_sb.set_corner_radius_all(6)
	confirm_btn.add_theme_stylebox_override("normal", confirm_sb)
	var confirm_sb_h = _flat(ACCENT.lightened(0.15))
	confirm_sb_h.set_corner_radius_all(6)
	confirm_btn.add_theme_stylebox_override("hover", confirm_sb_h)
	confirm_btn.pressed.connect(func():
		overlay.queue_free()
		on_confirm.call()
	)
	btn_row.add_child(confirm_btn)


# ═════════════════════════════════════════════════════════════════════
#  SELL INVENTORY GATHERING
# ═════════════════════════════════════════════════════════════════════
func _gather_sell_inventory_rows() -> Array:
	var out = []

	# Items
	for id in Global.CHARACTER_ITEMS.keys():
		var row = Global.CHARACTER_ITEMS[id]
		if row.get("Owner") == Global.ACTIVE_USER_NAME:
			var qty = 0
			if "Quantity" in row and row["Quantity"] != null:
				qty = int(row["Quantity"])
			if qty <= 0:
				continue
			var item_name = row.get("Name")
			var value = row.get("Value", null)
			if value == null or int(value) == 0:
				value = _get_item_value_by_name(item_name)
			var entry = row.duplicate(true)
			entry["Quantity"] = qty
			entry["Name"] = item_name
			entry["Value"] = int(value)
			entry["__table"] = "Character_Items"
			entry["__record_id"] = id
			entry["__priority"] = 0
			out.append(entry)

	# Weapons
	if "CHARACTER_WEAPONS" in Global and Global.CHARACTER_WEAPONS != null:
		for wid in Global.CHARACTER_WEAPONS.keys():
			var w = Global.CHARACTER_WEAPONS[wid]
			if w.get("Owner") == Global.ACTIVE_USER_NAME and w.get("Quantity") > 0:
				var equipped = bool(w.get("Equipped", false) if w.get("Equipped") != null else false)
				if equipped:
					continue
				var name_w = w.get("Weapon", w.get("Name", "Weapon"))
				var value_w = int(w.get("Value", 0))
				if value_w == 0:
					value_w = _weapon_base_value_safe(w)
				var entry_w = w.duplicate(true)
				entry_w["Name"] = name_w
				entry_w["Quantity"] = w.get("Quantity")
				entry_w["Value"] = int(value_w)
				entry_w["__table"] = "Character_Weapons"
				entry_w["__record_id"] = wid
				entry_w["__priority"] = 1
				out.append(entry_w)

	# Artifacts
	if "CHARACTER_ARTIFACTS" in Global and Global.CHARACTER_ARTIFACTS != null:
		for aid in Global.CHARACTER_ARTIFACTS.keys():
			var a = Global.CHARACTER_ARTIFACTS[aid]
			if a.get("Owner") == Global.ACTIVE_USER_NAME:
				var equipped_a = bool(a.get("Equipped", false) if a.get("Equipped") != null else false)
				if equipped_a:
					continue
				var set_name = a.get("Artifact_Set", a.get("Set", "Artifact"))
				var type_name = a.get("Type", "")
				var label = "%s - %s" % [set_name, type_name] if type_name != "" else set_name
				var value_a = int(a.get("Value", 0))
				if value_a == 0:
					value_a = Market._price_artifact(a)
				var entry_a = a.duplicate(true)
				entry_a["Name"] = label
				entry_a["Quantity"] = 1
				entry_a["Value"] = int(value_a)
				entry_a["__table"] = "Character_Artifacts"
				entry_a["__record_id"] = aid
				entry_a["__priority"] = 2
				out.append(entry_a)

	out.sort_custom(func(a, b):
		if a["__priority"] == b["__priority"]:
			return a["Name"].nocasecmp_to(b["Name"]) < 0
		return a["__priority"] < b["__priority"]
	)
	return out


# ═════════════════════════════════════════════════════════════════════
#  SELL LOGIC (preserved from original)
# ═════════════════════════════════════════════════════════════════════
func _log_sell_item(entry: Dictionary, qty: int, gain) -> void:
	var old_values = {
		"Owner": entry.get("Owner"),
		"Name": entry.get("Name"),
	}
	var new_values = {
		"Owner": entry.get("Owner"),
		"Name": entry.get("Name"),
		"Log": str(qty) + " of this item removed for: " + str(gain)
	}
	var metadata = {
		"market_action": "sell",
		"entity": "item",
		"delta_qty": -int(qty),
		"Type": entry.get("__table"),
		"Mora Gained": gain
	}
	Global.Log(
		"market",
		"sell_item",
		"Character_Items",
		str(int(entry.get("id"))),
		old_values,
		new_values,
		metadata,
		"success",
		"audit"
	)

func _add_mora(value) -> void:
	var party_record_id = Global.Current_Party.get("id")
	var original_mora = Global.Current_Party.get("Mora")
	var new_value = (original_mora + value)
	Global.Update_Records([{
		"table": "Party",
		"record_id": int(party_record_id),
		"field": "Mora",
		"value": int(new_value)
	}])

func _remove_sold_from_inventory(row: Dictionary, qty: int) -> void:
	var tbl = row.get("__table", "Character_Items")
	if tbl == "Character_Items":
		for id in Global.CHARACTER_ITEMS.keys():
			var r = Global.CHARACTER_ITEMS[id]
			if str(r.get("id")) == str(row.get("__record_id")):
				var current_qty = int(r["Quantity"])
				var new_qty = max(0, current_qty - qty)
				r["Quantity"] = new_qty
				Global.Update_Records([{
					"table": "Character_Items",
					"record_id": int(id),
					"field": "Quantity",
					"value": new_qty
				}])
				break
	elif tbl == "Character_Weapons":
		for id in Global.CHARACTER_WEAPONS.keys():
			var w = Global.CHARACTER_WEAPONS[id]
			if str(w.get("id")) == str(row.get("__record_id")):
				var current_qty = int(w["Quantity"])
				var new_qty = max(0, current_qty - qty)
				w["Quantity"] = new_qty
				Global.Update_Records([{
					"table": "Character_Weapons",
					"record_id": int(id),
					"field": "Quantity",
					"value": new_qty
				}])
				break
	elif tbl == "Character_Artifacts":
		Global.Remove_Record("Character_Artifacts", int(row.get("__record_id")))
	Global.Refresh_Data(Global.watched_tables)


# ═════════════════════════════════════════════════════════════════════
#  VALUE HELPERS (preserved from original)
# ═════════════════════════════════════════════════════════════════════
func _get_item_value_by_name(item_name: String) -> int:
	if Market.has_method("_lookup_item_value"):
		return int(Market._lookup_item_value(item_name))
	return 0

func _weapon_base_value_from_recipes(weapon_name: String) -> int:
	if "CRAFTING_RECIPES" in Global and Global.CRAFTING_RECIPES != null:
		for rid in Global.CRAFTING_RECIPES.keys():
			var rec = Global.CRAFTING_RECIPES[rid]
			if rec.get("Weapon") == weapon_name:
				var mats = rec.get("Materials", [])
				var total = 0
				for m in mats:
					var iname = m.get("Item")
					var iqty = int(m.get("Qty", 1))
					total += _get_item_value_by_name(iname) * iqty
				return int(total * 2)
	return -1

func _weapon_base_value_safe(w: Dictionary) -> int:
	if Market.has_method("_lookup_weapon_value"):
		return int(Market._lookup_weapon_value(w))
	if Market.has_method("Lookup_Weapon_Value"):
		return int(Market.Lookup_Weapon_Value(w))
	if Market.has_method("Get_Weapon_Value"):
		return int(Market.Get_Weapon_Value(w))
	var nm = w.get("Weapon", w.get("Name", ""))
	var via_recipe = _weapon_base_value_from_recipes(nm)
	if via_recipe >= 0:
		return via_recipe
	var rarity = str(w.get("Rarity", "")).to_lower()
	var rarity_map = {
		"common": 75,
		"uncommon": 500,
		"rare": 850,
		"epic": 3000,
		"legendary": 6000
	}
	if rarity in rarity_map:
		return int(rarity_map[rarity])
	return int(w.get("Value", 0))


# ═════════════════════════════════════════════════════════════════════
#  DISPLAY HELPERS
# ═════════════════════════════════════════════════════════════════════
func _get_row_display_name(r: Dictionary) -> String:
	if _buy_mode:
		if _current_shop == "Weapons":
			return str(r.get("Weapon", r.get("Name", "?")))
		elif _current_shop == "Artifacts":
			return "%s - %s" % [r.get("Artifact_Set", "?"), r.get("Type", "?")]
		else:
			return str(r.get("Name", "?"))
	else:
		return str(r.get("Name", "?"))

func _get_row_subtitle(r: Dictionary) -> String:
	if _buy_mode:
		if _current_shop == "Weapons":
			return "%s / %s" % [str(r.get("Rarity", "")), str(r.get("Type", ""))]
		elif _current_shop == "Artifacts":
			return str(r.get("Rarity", ""))
		else:
			var parts = []
			if r.get("Type") != null and str(r.get("Type")) != "":
				parts.append(str(r.get("Type")))
			if r.get("Rarity") != null and str(r.get("Rarity")) != "":
				parts.append(str(r.get("Rarity")))
			return " / ".join(parts) if parts.size() > 0 else ""
	else:
		var tbl = r.get("__table", "")
		if tbl == "Character_Weapons":
			return str(r.get("Rarity", ""))
		elif tbl == "Character_Artifacts":
			return "Artifact"
		else:
			return str(r.get("Type", ""))

func _try_load_icon(r: Dictionary) -> Texture2D:
	var path = ""
	if _buy_mode:
		if _current_shop == "Weapons":
			var hyphen = str(r.get("Weapon", "")).to_lower().replace(" ", "-") + ".png"
			path = "res://UI/Weapon Icons/" + hyphen
		elif _current_shop == "Artifacts":
			var type_short = _artifact_type_short(str(r.get("Type", "")))
			var hyphen = str(r.get("Artifact_Set", "")).to_lower().replace(" ", "-") + "-" + type_short + ".png"
			path = "res://UI/Artifact Icons/" + hyphen
		else:
			var hyphen = str(r.get("Name", "")).to_lower().replace(" ", "-") + ".png"
			path = "res://UI/Item Icons/" + hyphen
	else:
		var tbl = r.get("__table", "")
		if tbl == "Character_Weapons":
			var hyphen = str(r.get("Name", "")).to_lower().replace(" ", "-") + ".png"
			path = "res://UI/Weapon Icons/" + hyphen
		elif tbl == "Character_Artifacts":
			var set_name = r.get("Artifact_Set", r.get("Set", ""))
			var type_short = _artifact_type_short(str(r.get("Type", "")))
			var hyphen = str(set_name).to_lower().replace(" ", "-") + "-" + type_short + ".png"
			path = "res://UI/Artifact Icons/" + hyphen
		else:
			var hyphen = str(r.get("Name", "")).to_lower().replace(" ", "-") + ".png"
			# Check if consumable
			var item_type = r.get("Type", "")
			if item_type == "Consumable":
				path = "res://UI/Food Icons/" + hyphen
			else:
				path = "res://UI/Item Icons/" + hyphen

	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

func _artifact_type_short(type_name: String) -> String:
	match type_name:
		"Flower of Life":
			return "flower"
		"Feather of Death":
			return "plume"
		"Sands of Time":
			return "sands"
		"Goblet of Space":
			return "goblet"
		"Circlet of Principles":
			return "circlet"
	return "flower"

func _format_number(n: int) -> String:
	var s = str(abs(n))
	var result = ""
	var count = 0
	var i = s.length() - 1
	while i >= 0:
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
		i -= 1
	if n < 0:
		result = "-" + result
	return result


# ═════════════════════════════════════════════════════════════════════
#  EXIT
# ═════════════════════════════════════════════════════════════════════
func _on_exit_pressed() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()


# ═════════════════════════════════════════════════════════════════════
#  STYLEBOX HELPER
# ═════════════════════════════════════════════════════════════════════
func _flat(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	return sb



func _save_layout() -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://ui_settings.cfg")
	cfg.set_value("market_layout", "outer_split", _outer_split.split_offset)
	cfg.set_value("market_layout", "inner_split", _inner_split.split_offset)
	cfg.save("user://ui_settings.cfg")

func _load_layout() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		if cfg.has_section_key("market_layout", "outer_split"):
			_outer_split.split_offset = cfg.get_value("market_layout", "outer_split", 0)
		if cfg.has_section_key("market_layout", "inner_split"):
			_inner_split.split_offset = cfg.get_value("market_layout", "inner_split", 0)
