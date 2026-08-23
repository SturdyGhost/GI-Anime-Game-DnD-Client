extends Control

# ============================================================
#  PlayerInventory — full-screen, dark-themed, programmatic UI
# ============================================================

# ---------- palette ----------
const BG = Color(0.102, 0.122, 0.169)
const PANEL = Color(0.133, 0.157, 0.22)
const CARD = Color(0.165, 0.192, 0.27)
const INSET = Color(0.086, 0.106, 0.149)
const HOVER = Color(0.188, 0.227, 0.322)
const BORDER = Color(0.227, 0.259, 0.376)
const BORDER_FOCUS = Color(0.353, 0.478, 0.71)
const TEXT = Color(0.941, 0.949, 0.973)
const SEC = Color(0.69, 0.722, 0.8)
const MUTED = Color(0.471, 0.51, 0.627)
const ACCENT = Color(0.788, 0.659, 0.298)
const GREEN = Color(0.292, 0.855, 0.498)
const RED = Color(0.937, 0.267, 0.267)

const RARITY_COLORS = {
	"common":    Color(0.7, 0.7, 0.7),
	"uncommon":  Color(0.29, 0.85, 0.5),
	"rare":      Color(0.35, 0.55, 0.95),
	"epic":      Color(0.65, 0.35, 0.9),
	"legendary": Color(0.95, 0.65, 0.15),
	"mythic":    Color(0.95, 0.25, 0.25),
}
const RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

# Type chips built dynamically from actual item data (not hardcoded)
var TYPE_CHIPS = ["All"]
const RARITY_CHIPS = ["Any Rarity", "Common", "Uncommon", "Rare", "Epic", "Legendary"]

# ---------- data ----------
var _all_items_for_owner: Array = []
var _filtered_ids: Array = []
var _selected_item = null
var _items_by_key: Dictionary = {}

# ---------- ui refs (built in _ready) ----------
var _bg_panel: Panel
var _close_btn: Button
var _search_box: LineEdit
var _type_chip_container: HFlowContainer
var _rarity_chip_container: HFlowContainer
var _item_scroll: ScrollContainer
var _item_list_vbox: VBoxContainer
var _detail_panel: PanelContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_badges_hbox: HBoxContainer
var _detail_qty_label: Label
var _detail_desc: RichTextLabel
var _player_dropdown: OptionButton
var _give_amount: SpinBox
var _give_button: Button
var _detail_placeholder: Label
var _split: HSplitContainer

var _type_chips: Array = []   # [{btn: Button, label: String}]
var _rarity_chips: Array = [] # [{btn: Button, label: String}]

var _active_types: Array = ["All"]
var _active_rarities: Array = ["Any Rarity"]

# Receiver names that are companions (vs players) — routes gives through the
# owned-item-move path instead of the peer-acked player transfer.
var _companion_receivers: Dictionary = {}

# ---------- bulk transfer tab ----------
var _bulk_type_container: HFlowContainer
var _bulk_list: ItemList
var _bulk_player_dropdown: OptionButton
var _bulk_transfer_btn: Button
var _bulk_type_chips: Array = []
var _bulk_active_types: Array = ["All"]

# ============================================================
#  READY — build entire UI tree
# ============================================================
func _ready() -> void:
	_build_ui()
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	_load_owner_items()
	_populate_player_dropdown()
	_apply_filters_and_search()
	# Bulk transfer tab (populated after items are loaded)
	_build_bulk_type_chips()
	_populate_bulk_dropdown()
	_refresh_bulk_list()
	_split.dragged.connect(func(_ofs): _save_layout())
	_load_layout.call_deferred()

# ============================================================
#  BUILD UI
# ============================================================
func _build_ui() -> void:
	# --- full-screen bg ---
	_bg_panel = Panel.new()
	_bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = BG
	_bg_panel.add_theme_stylebox_override("panel", bg_sb)
	add_child(_bg_panel)

	# --- outer margin ---
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(outer_vbox)

	# --- header row ---
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = "Inventory"
	title_lbl.add_theme_color_override("font_color", TEXT)
	title_lbl.add_theme_font_size_override("font_size", 60)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	_close_btn = Button.new()
	_close_btn.text = "  X  "
	_style_button(_close_btn, CARD, TEXT)
	_close_btn.pressed.connect(_on_exit_button_pressed)
	header.add_child(_close_btn)

	# spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	outer_vbox.add_child(spacer)

	# --- tabs: Inventory (existing) + Bulk Transfer (new) ---
	var tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(tabs)

	# --- split container (Inventory tab) ---
	_split = HSplitContainer.new()
	_split.name = "Inventory"
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.split_offset = 380
	tabs.add_child(_split)
	_build_bulk_tab(tabs)

	# ===== LEFT PANE =====
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(180, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_sb = StyleBoxFlat.new()
	left_sb.bg_color = PANEL
	left_sb.set_corner_radius_all(8)
	left_sb.set_content_margin_all(16)
	left_panel.add_theme_stylebox_override("panel", left_sb)
	_split.add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 12)
	left_panel.add_child(left_vbox)

	# search input
	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search items..."
	_search_box.custom_minimum_size = Vector2(0, 40)
	_style_line_edit(_search_box)
	_search_box.text_changed.connect(func(_t): _apply_filters_and_search())
	left_vbox.add_child(_search_box)

	# type chips label + row
	var type_label = _make_section_label("Type")
	left_vbox.add_child(type_label)

	_type_chip_container = HFlowContainer.new()
	_type_chip_container.add_theme_constant_override("h_separation", 4)
	_type_chip_container.add_theme_constant_override("v_separation", 4)
	left_vbox.add_child(_type_chip_container)
	_build_type_chips()

	# rarity chips label + row
	var rarity_label = _make_section_label("Rarity")
	left_vbox.add_child(rarity_label)

	_rarity_chip_container = HFlowContainer.new()
	_rarity_chip_container.add_theme_constant_override("h_separation", 4)
	_rarity_chip_container.add_theme_constant_override("v_separation", 4)
	left_vbox.add_child(_rarity_chip_container)
	_build_rarity_chips()

	# scrollable item list
	_item_scroll = ScrollContainer.new()
	_item_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(_item_scroll)

	_item_list_vbox = VBoxContainer.new()
	_item_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list_vbox.add_theme_constant_override("separation", 4)
	_item_scroll.add_child(_item_list_vbox)

	# ===== RIGHT PANE =====
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(300, 0)
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_sb = StyleBoxFlat.new()
	right_sb.bg_color = PANEL
	right_sb.set_corner_radius_all(8)
	right_sb.set_content_margin_all(24)
	_detail_panel.add_theme_stylebox_override("panel", right_sb)
	_split.add_child(_detail_panel)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(detail_vbox)

	# placeholder (shown when nothing selected)
	_detail_placeholder = Label.new()
	_detail_placeholder.text = "Select an item to view details"
	_detail_placeholder.add_theme_color_override("font_color", MUTED)
	_detail_placeholder.add_theme_font_size_override("font_size", 48)
	_detail_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(_detail_placeholder)

	# --- icon + name row ---
	var icon_name_hbox = HBoxContainer.new()
	icon_name_hbox.add_theme_constant_override("separation", 16)
	detail_vbox.add_child(icon_name_hbox)

	var icon_bg = PanelContainer.new()
	icon_bg.custom_minimum_size = Vector2(64, 64)
	var icon_sb = StyleBoxFlat.new()
	icon_sb.bg_color = INSET
	icon_sb.set_corner_radius_all(8)
	icon_bg.add_theme_stylebox_override("panel", icon_sb)
	icon_name_hbox.add_child(icon_bg)

	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(256, 256)
	_detail_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_bg.add_child(_detail_icon)

	var name_col = VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 6)
	icon_name_hbox.add_child(name_col)

	_detail_name = Label.new()
	_detail_name.add_theme_color_override("font_color", TEXT)
	_detail_name.add_theme_font_size_override("font_size", 52)
	name_col.add_child(_detail_name)

	_detail_badges_hbox = HBoxContainer.new()
	_detail_badges_hbox.add_theme_constant_override("separation", 8)
	name_col.add_child(_detail_badges_hbox)

	# quantity
	_detail_qty_label = Label.new()
	_detail_qty_label.add_theme_color_override("font_color", ACCENT)
	_detail_qty_label.add_theme_font_size_override("font_size", 63)
	detail_vbox.add_child(_detail_qty_label)

	# separator 1
	detail_vbox.add_child(_make_separator())

	# description
	_detail_desc = RichTextLabel.new()
	_detail_desc.bbcode_enabled = true
	_detail_desc.fit_content = true
	_detail_desc.scroll_active = false
	_detail_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_desc.add_theme_color_override("default_color", SEC)
	_detail_desc.add_theme_font_size_override("normal_font_size", 50)
	detail_vbox.add_child(_detail_desc)

	# separator 2
	detail_vbox.add_child(_make_separator())

	# give section label
	var give_label = _make_section_label("Give to Player")
	detail_vbox.add_child(give_label)

	var give_row = HBoxContainer.new()
	give_row.add_theme_constant_override("separation", 8)
	detail_vbox.add_child(give_row)

	_player_dropdown = OptionButton.new()
	_player_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_dropdown.custom_minimum_size = Vector2(0, 36)
	_style_option_button(_player_dropdown)
	give_row.add_child(_player_dropdown)

	_give_amount = SpinBox.new()
	_give_amount.min_value = 1
	_give_amount.max_value = 1
	_give_amount.value = 1
	_give_amount.custom_minimum_size = Vector2(80, 36)
	give_row.add_child(_give_amount)

	_give_button = Button.new()
	_give_button.text = "Give"
	_give_button.custom_minimum_size = Vector2(80, 36)
	_style_button(_give_button, INSET, ACCENT)
	_give_button.pressed.connect(_on_give_button_pressed)
	give_row.add_child(_give_button)

	# bottom spacer to push content up
	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(bottom_spacer)

	_clear_detail()

# ============================================================
#  CHIP BUILDERS
# ============================================================
func _build_type_chips() -> void:
	_type_chips.clear()
	# Build type list dynamically from the player's actual item types
	TYPE_CHIPS = ["All"]
	var seen = {}
	for item in Global.CHARACTER_ITEMS.values():
		if str(item.get("Owner", "")).strip_edges().to_lower() != Global.ACTIVE_USER_NAME.strip_edges().to_lower():
			continue
		var t = str(item.get("Type", "")).strip_edges()
		if t != "" and not seen.has(t):
			seen[t] = true
			TYPE_CHIPS.append(t)
	TYPE_CHIPS.sort()
	# Move "All" back to front
	TYPE_CHIPS.erase("All")
	TYPE_CHIPS.insert(0, "All")

	for chip_label in TYPE_CHIPS:
		var btn = Button.new()
		btn.text = chip_label
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_type_chip_pressed.bind(chip_label))
		_type_chip_container.add_child(btn)
		_type_chips.append({"btn": btn, "label": chip_label})
	_refresh_type_chip_styles()

func _build_rarity_chips() -> void:
	_rarity_chips.clear()
	for chip_label in RARITY_CHIPS:
		var btn = Button.new()
		btn.text = chip_label
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_rarity_chip_pressed.bind(chip_label))
		_rarity_chip_container.add_child(btn)
		_rarity_chips.append({"btn": btn, "label": chip_label})
	_refresh_rarity_chip_styles()

# ============================================================
#  BULK TRANSFER TAB
# ============================================================
func _build_bulk_tab(tabs: TabContainer) -> void:
	var panel = PanelContainer.new()
	panel.name = "Bulk Transfer"
	var sb = StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	tabs.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	vbox.add_child(_make_section_label("Bulk Transfer — sends the FULL stack of each selected item"))

	vbox.add_child(_make_section_label("Filter by Type"))
	_bulk_type_container = HFlowContainer.new()
	_bulk_type_container.add_theme_constant_override("h_separation", 4)
	_bulk_type_container.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_bulk_type_container)

	var sel_row = HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 8)
	vbox.add_child(sel_row)
	var sel_all = Button.new()
	sel_all.text = "Select All"
	_style_button(sel_all, CARD, TEXT)
	sel_all.pressed.connect(_bulk_select_all)
	sel_row.add_child(sel_all)
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	_style_button(clear_btn, CARD, TEXT)
	clear_btn.pressed.connect(func(): _bulk_list.deselect_all(); _update_bulk_transfer_button())
	sel_row.add_child(clear_btn)

	_bulk_list = ItemList.new()
	_bulk_list.select_mode = ItemList.SELECT_MULTI
	_bulk_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bulk_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bulk_list.add_theme_font_size_override("font_size", 32)
	# Plain left-click toggles/adds to the selection (no shift/ctrl needed).
	_bulk_list.gui_input.connect(_on_bulk_list_input)
	_bulk_list.multi_selected.connect(func(_i, _s): _update_bulk_transfer_button())
	vbox.add_child(_bulk_list)

	var send_row = HBoxContainer.new()
	send_row.add_theme_constant_override("separation", 8)
	vbox.add_child(send_row)
	var to_lbl = Label.new()
	to_lbl.text = "To:"
	to_lbl.add_theme_color_override("font_color", TEXT)
	send_row.add_child(to_lbl)
	_bulk_player_dropdown = OptionButton.new()
	_style_option_button(_bulk_player_dropdown)
	_bulk_player_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_row.add_child(_bulk_player_dropdown)
	_bulk_transfer_btn = Button.new()
	_bulk_transfer_btn.text = "Transfer Selected"
	# Match the regular tab's Give button styling exactly.
	_style_button(_bulk_transfer_btn, INSET, ACCENT)
	_bulk_transfer_btn.disabled = true  # enabled once at least one item is selected
	_bulk_transfer_btn.pressed.connect(_on_bulk_transfer_pressed)
	send_row.add_child(_bulk_transfer_btn)

## Build the bulk type-filter chips from the owner's actual item types.
func _build_bulk_type_chips() -> void:
	if _bulk_type_container == null:
		return
	for c in _bulk_type_container.get_children():
		c.queue_free()
	_bulk_type_chips.clear()
	var types: Array = ["All"]
	for it in _all_items_for_owner:
		var t = str(it.get("type", ""))
		if t != "" and not types.has(t):
			types.append(t)
	for t in types:
		var chip = Button.new()
		chip.text = t
		chip.custom_minimum_size = Vector2(0, 32)
		_style_chip(chip, t in _bulk_active_types)
		chip.pressed.connect(_on_bulk_type_chip_pressed.bind(t))
		_bulk_type_container.add_child(chip)
		_bulk_type_chips.append({"btn": chip, "label": t})

func _on_bulk_type_chip_pressed(chip_label: String) -> void:
	if chip_label == "All":
		_bulk_active_types = ["All"]
	else:
		if "All" in _bulk_active_types:
			_bulk_active_types.erase("All")
		if chip_label in _bulk_active_types:
			_bulk_active_types.erase(chip_label)
		else:
			_bulk_active_types.append(chip_label)
		if _bulk_active_types.is_empty():
			_bulk_active_types = ["All"]
	for entry in _bulk_type_chips:
		_style_chip(entry["btn"], entry["label"] in _bulk_active_types)
	_refresh_bulk_list()

## Populate the multi-select list with the owner's items matching the type filter.
func _refresh_bulk_list() -> void:
	if _bulk_list == null:
		return
	_bulk_list.clear()
	var filter_all: bool = "All" in _bulk_active_types
	for it in _all_items_for_owner:
		if int(it.get("qty", 0)) <= 0:
			continue
		if not filter_all and not (str(it.get("type", "")) in _bulk_active_types):
			continue
		var idx = _bulk_list.add_item("%s   x%d   (%s)" % [it.get("name", ""), int(it.get("qty", 0)), it.get("type", "")])
		_bulk_list.set_item_metadata(idx, str(it.get("name", "")))
	# Re-applying the filter clears selection, so the transfer button resets too.
	_update_bulk_transfer_button()

func _bulk_select_all() -> void:
	if _bulk_list == null:
		return
	for i in range(_bulk_list.item_count):
		_bulk_list.select(i, false)
	_update_bulk_transfer_button()

## Plain left-click toggles an item in/out of the multi-selection without clearing
## the rest (so users don't need shift/ctrl). Shift+click still does range select.
func _on_bulk_list_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT):
			return  # let the default range-select handle shift+click
		var idx = _bulk_list.get_item_at_position(event.position, true)
		if idx < 0:
			return
		if _bulk_list.is_selected(idx):
			_bulk_list.deselect(idx)
		else:
			_bulk_list.select(idx, false)  # false = add to selection, don't clear others
		_update_bulk_transfer_button()
		_bulk_list.accept_event()  # suppress default single-select

## Enable Transfer Selected only when at least one item is selected.
func _update_bulk_transfer_button() -> void:
	if _bulk_transfer_btn == null:
		return
	_bulk_transfer_btn.disabled = _bulk_list == null or _bulk_list.get_selected_items().is_empty()

func _populate_bulk_dropdown() -> void:
	if _bulk_player_dropdown == null:
		return
	_bulk_player_dropdown.clear()
	for pname in Global.CHARACTERS_NAME.keys():
		if pname != Global.ACTIVE_USER_NAME and pname != "Chase":
			_bulk_player_dropdown.add_item(pname)
	for cname in _eligible_companion_names():
		_bulk_player_dropdown.add_item(cname)
		_companion_receivers[cname] = true

## Unlocked companions the active player owns — eligible item recipients.
func _eligible_companion_names() -> Array:
	var out: Array = []
	for c in Global.COMPANIONS.values():
		var cname := str(c.get("Name", ""))
		if cname == "" or out.has(cname):
			continue
		if str(c.get("Owner", "")) != Global.ACTIVE_USER_NAME:
			continue
		if not c.get("Unlocked", false):
			continue
		out.append(cname)
	return out

func _on_bulk_transfer_pressed() -> void:
	if _bulk_player_dropdown == null or _bulk_player_dropdown.selected < 0:
		Toast.notify("Pick a recipient", Toast.WARNING)
		return
	var receiver: String = _bulk_player_dropdown.get_item_text(_bulk_player_dropdown.selected)
	var names: Array = []
	for i in _bulk_list.get_selected_items():
		var n = str(_bulk_list.get_item_metadata(i))
		if n != "" and not names.has(n):
			names.append(n)
	if names.is_empty():
		Toast.notify("Select at least one item", Toast.WARNING)
		return

	var popup = AcceptDialog.new()
	popup.title = "Confirm Bulk Transfer"
	popup.dialog_text = "Send the full stack of %d item(s) to %s?" % [names.size(), receiver]
	popup.ok_button_text = "Transfer"
	popup.add_cancel_button("Cancel")
	popup.confirmed.connect(func():
		var my_peer: int = multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
		if _companion_receivers.has(receiver):
			# Companion recipient: move each full stack via the owned-item path.
			for nm in names:
				var full_qty := 0
				for it in Global.CHARACTER_ITEMS.values():
					if it.get("Owner") == Global.ACTIVE_USER_NAME and it.get("Name") == nm:
						full_qty = int(it.get("Quantity", 0))
						break
				if full_qty <= 0:
					continue
				var c_id: String = "%d-%d-%s-citem" % [my_peer, Time.get_ticks_msec(), nm]
				NetworkManager.request_owned_item_move(c_id, Global.ACTIVE_USER_NAME, receiver, nm, full_qty)
		else:
			var corr_id: String = "%d-%d-bulk" % [my_peer, Time.get_ticks_msec()]
			NetworkManager.request_bulk_item_transfer(corr_id, receiver, names)
		popup.queue_free()
	)
	popup.canceled.connect(func(): popup.queue_free())
	add_child(popup)
	popup.popup_centered()

func _on_type_chip_pressed(chip_label: String) -> void:
	if chip_label == "All":
		_active_types = ["All"]
	else:
		if "All" in _active_types:
			_active_types.erase("All")
		if chip_label in _active_types:
			_active_types.erase(chip_label)
		else:
			_active_types.append(chip_label)
		if _active_types.is_empty():
			_active_types = ["All"]
	_refresh_type_chip_styles()
	_apply_filters_and_search()

func _on_rarity_chip_pressed(chip_label: String) -> void:
	if chip_label == "Any Rarity":
		_active_rarities = ["Any Rarity"]
	else:
		if "Any Rarity" in _active_rarities:
			_active_rarities.erase("Any Rarity")
		if chip_label in _active_rarities:
			_active_rarities.erase(chip_label)
		else:
			_active_rarities.append(chip_label)
		if _active_rarities.is_empty():
			_active_rarities = ["Any Rarity"]
	_refresh_rarity_chip_styles()
	_apply_filters_and_search()

func _refresh_type_chip_styles() -> void:
	for entry in _type_chips:
		var active = entry["label"] in _active_types
		_style_chip(entry["btn"], active)

func _refresh_rarity_chip_styles() -> void:
	for entry in _rarity_chips:
		var lbl = entry["label"]
		var active = lbl in _active_rarities
		var color = ACCENT if active else BORDER
		if lbl != "Any Rarity":
			var rar_key = lbl.to_lower()
			if rar_key in RARITY_COLORS:
				color = RARITY_COLORS[rar_key] if active else RARITY_COLORS[rar_key].darkened(0.5)
		_style_chip(entry["btn"], active, color)

# ============================================================
#  STYLING HELPERS
# ============================================================
func _style_chip(btn: Button, active: bool, accent_color: Color = ACCENT) -> void:
	var sb = StyleBoxFlat.new()
	if active:
		sb.bg_color = accent_color.darkened(0.6)
		sb.border_color = accent_color
		sb.set_border_width_all(1)
	else:
		sb.bg_color = CARD
		sb.border_color = BORDER
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	var hover_sb = sb.duplicate()
	hover_sb.bg_color = hover_sb.bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_color_override("font_color", TEXT if active else SEC)
	btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", TEXT)
	btn.add_theme_font_size_override("font_size", 48)

func _style_button(btn: Button, bg_color: Color, text_color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var hover_sb = sb.duplicate()
	hover_sb.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_sb)
	var press_sb = sb.duplicate()
	press_sb.bg_color = bg_color.lightened(0.25)
	btn.add_theme_stylebox_override("pressed", press_sb)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_font_size_override("font_size", 48)

func _style_line_edit(le: LineEdit) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = INSET
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	le.add_theme_stylebox_override("normal", sb)
	var focus_sb = sb.duplicate()
	focus_sb.border_color = BORDER_FOCUS
	le.add_theme_stylebox_override("focus", focus_sb)
	le.add_theme_color_override("font_color", TEXT)
	le.add_theme_color_override("font_placeholder_color", MUTED)
	le.add_theme_font_size_override("font_size", 48)

func _style_option_button(ob: OptionButton) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = INSET
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	ob.add_theme_stylebox_override("normal", sb)
	ob.add_theme_color_override("font_color", TEXT)
	ob.add_theme_font_size_override("font_size", 48)

func _make_section_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", MUTED)
	lbl.add_theme_font_size_override("font_size", 48)
	return lbl

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = BORDER
	sb.set_content_margin_all(0)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sb)
	sep.add_theme_constant_override("separation", 8)
	return sep

func _make_badge(text: String, color: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.65)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	pc.add_theme_stylebox_override("panel", sb)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 48)
	pc.add_child(lbl)
	return pc

# ============================================================
#  DATA LOADING
# ============================================================
func _key_str(k) -> String:
	if typeof(k) == TYPE_FLOAT:
		var i = int(round(k))
		return str(i) if is_equal_approx(float(i), k) else str(k)
	return str(k)

func _to_int_or_zero(v) -> int:
	if v == null:
		return 0
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT:
		return int(round(v))
	var s: String = str(v).strip_edges()
	if s == "":
		return 0
	s = s.replace(",", "")
	if s.begins_with("x") or s.begins_with("X"):
		s = s.substr(1, s.length() - 1)
	return int(s) if s.is_valid_int() else 0

func _load_owner_items() -> void:
	_all_items_for_owner.clear()
	_items_by_key.clear()

	var owner: String = str(Global.ACTIVE_USER_NAME).strip_edges().to_lower()
	if owner == "":
		return

	var src: Dictionary = Global.CHARACTER_ITEMS
	for rid in src.keys():
		var row_raw = src[rid]
		if typeof(row_raw) != TYPE_DICTIONARY:
			continue

		var row_owner: String = str(row_raw.get("Owner", "")).strip_edges().to_lower()
		if row_owner != owner:
			continue

		var item_name: String = str(row_raw.get("Name", ""))
		var type_val: String = str(row_raw.get("Type", ""))
		var rarity_val: String = str(row_raw.get("Rarity", ""))
		var qty: int = _to_int_or_zero(row_raw.get("Quantity", row_raw.get("Qty", row_raw.get("Count", null))))
		var desc_text: String = str(row_raw.get("Description", ""))

		var key = _key_str(rid)
		_items_by_key[key] = row_raw

		_all_items_for_owner.append({
			"id": key, "row": row_raw,
			"lc_name": item_name.to_lower(), "lc_type": type_val.to_lower(),
			"lc_desc": desc_text.to_lower(),
			"qty": qty,
			"name": item_name, "type": type_val, "rarity": rarity_val, "desc": desc_text
		})

func _on_data_load_complete():
	var scene = preload("res://Scenes/PlayerInventory.tscn")
	var new_inventory = scene.instantiate()
	get_parent().add_child(new_inventory)
	self.queue_free()

# ============================================================
#  FILTERING + SEARCH
# ============================================================
func _apply_filters_and_search() -> void:
	# Clear existing item rows
	for child in _item_list_vbox.get_children():
		child.queue_free()
	_filtered_ids.clear()

	var q: String = _search_box.text.strip_edges().to_lower()

	var filter_all_types = "All" in _active_types
	var filter_any_rarity = "Any Rarity" in _active_rarities

	var visible_items = []
	for it in _all_items_for_owner:
		# type filter
		if not filter_all_types:
			var match_type = false
			for t in _active_types:
				if it["lc_type"] == t.to_lower():
					match_type = true
					break
			if not match_type:
				continue

		# rarity filter
		if not filter_any_rarity:
			var match_rar = false
			for r in _active_rarities:
				if str(it["rarity"]).to_lower() == r.to_lower():
					match_rar = true
					break
			if not match_rar:
				continue

		# search
		if q != "":
			var hit = it["lc_name"].find(q) != -1 \
				or it["lc_type"].find(q) != -1 \
				or it["lc_desc"].find(q) != -1
			if not hit:
				continue

		visible_items.append(it)

	# sort alphabetically
	visible_items.sort_custom(func(a, b):
		return str(a["name"]).to_lower() < str(b["name"]).to_lower()
	)

	# build item rows
	for it in visible_items:
		_filtered_ids.append(it["id"])
		_add_item_row(it)

	_clear_detail()

func _add_item_row(it: Dictionary) -> void:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 48)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_sb = StyleBoxFlat.new()
	row_sb.bg_color = CARD
	row_sb.set_corner_radius_all(6)
	row_sb.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", row_sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hbox)

	# icon placeholder (colored square)
	var icon_holder = PanelContainer.new()
	icon_holder.custom_minimum_size = Vector2(40, 40)
	var icon_sb = StyleBoxFlat.new()
	var rar_key = str(it["rarity"]).to_lower()
	icon_sb.bg_color = RARITY_COLORS.get(rar_key, INSET)
	icon_sb.set_corner_radius_all(6)
	icon_holder.add_theme_stylebox_override("panel", icon_sb)
	hbox.add_child(icon_holder)

	# try loading actual icon
	var icon_tex = TextureRect.new()
	icon_tex.custom_minimum_size = Vector2(36, 36)
	icon_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hyphenname = str(it["name"]).to_lower().replace(" ", "-")
	var icon_path = ""
	if str(it["type"]) == "Consumable":
		icon_path = "res://UI/Food Icons/" + hyphenname + ".png"
	else:
		icon_path = "res://UI/Item Icons/" + hyphenname + ".png"
	if ResourceLoader.exists(icon_path):
		icon_tex.texture = load(icon_path)
	icon_holder.add_child(icon_tex)

	# name + type column
	var text_col = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	hbox.add_child(text_col)

	var name_lbl = Label.new()
	name_lbl.text = str(it["name"])
	name_lbl.add_theme_color_override("font_color", TEXT)
	name_lbl.add_theme_font_size_override("font_size", 52)
	text_col.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = str(it["type"])
	type_lbl.add_theme_color_override("font_color", MUTED)
	type_lbl.add_theme_font_size_override("font_size", 48)
	text_col.add_child(type_lbl)

	# quantity badge
	var qty_badge = PanelContainer.new()
	var qty_sb = StyleBoxFlat.new()
	qty_sb.bg_color = INSET
	qty_sb.set_corner_radius_all(10)
	qty_sb.set_content_margin_all(2)
	qty_sb.content_margin_left = 10
	qty_sb.content_margin_right = 10
	qty_badge.add_theme_stylebox_override("panel", qty_sb)
	qty_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(qty_badge)

	var qty_lbl = Label.new()
	qty_lbl.text = "x" + str(it["qty"])
	qty_lbl.add_theme_color_override("font_color", SEC)
	qty_lbl.add_theme_font_size_override("font_size", 48)
	qty_badge.add_child(qty_lbl)

	# click handling via gui_input
	var item_id = it["id"]
	row.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_item(item_id, row)
	)
	row.mouse_entered.connect(func():
		if row.get_meta("selected", false):
			return
		var hover_style = row_sb.duplicate()
		hover_style.bg_color = HOVER
		row.add_theme_stylebox_override("panel", hover_style)
	)
	row.mouse_exited.connect(func():
		if row.get_meta("selected", false):
			return
		row.add_theme_stylebox_override("panel", row_sb)
	)
	row.set_meta("base_style", row_sb)

	_item_list_vbox.add_child(row)

var _selected_row = null

func _select_item(item_id: String, row: PanelContainer) -> void:
	# deselect previous
	if _selected_row != null and is_instance_valid(_selected_row):
		_selected_row.set_meta("selected", false)
		var base = _selected_row.get_meta("base_style", null)
		if base:
			_selected_row.add_theme_stylebox_override("panel", base)

	# select new
	_selected_row = row
	row.set_meta("selected", true)
	var sel_sb = StyleBoxFlat.new()
	sel_sb.bg_color = CARD
	sel_sb.set_corner_radius_all(6)
	sel_sb.set_content_margin_all(8)
	sel_sb.border_color = ACCENT
	sel_sb.border_width_left = 3
	row.add_theme_stylebox_override("panel", sel_sb)

	_show_detail(item_id)

# ============================================================
#  DETAIL PANEL
# ============================================================
func _show_detail(rid) -> void:
	var row = _get_row_by_id(rid)
	if row.is_empty():
		_clear_detail()
		return

	_selected_item = row
	_detail_placeholder.visible = false

	var item_name: String = str(row.get("Name", ""))
	var qty: int = _to_int_or_zero(row.get("Quantity", 0))
	var type_val: String = str(row.get("Type", ""))
	var rarity_val: String = str(row.get("Rarity", ""))
	var desc_text: String = str(row.get("Description", "")) if row.get("Description") != null else ""

	_detail_name.text = item_name
	_detail_name.visible = true

	# badges
	for child in _detail_badges_hbox.get_children():
		child.queue_free()
	if type_val != "":
		_detail_badges_hbox.add_child(_make_badge(type_val, BORDER_FOCUS))
	if rarity_val != "":
		var rar_color = RARITY_COLORS.get(rarity_val.to_lower(), SEC)
		_detail_badges_hbox.add_child(_make_badge(rarity_val, rar_color))
	_detail_badges_hbox.visible = true

	_detail_qty_label.text = str(qty)
	_detail_qty_label.visible = true

	_detail_desc.text = desc_text
	_detail_desc.visible = true

	# icon
	var hyphenname = item_name.to_lower().replace(" ", "-")
	var icon_path = ""
	if type_val == "Consumable":
		icon_path = "res://UI/Food Icons/" + hyphenname + ".png"
	else:
		icon_path = "res://UI/Item Icons/" + hyphenname + ".png"
	if ResourceLoader.exists(icon_path):
		_detail_icon.texture = load(icon_path)
	else:
		_detail_icon.texture = null
	_detail_icon.visible = true
	_detail_icon.get_parent().visible = true

	# give section
	if _give_amount != null:
		_give_amount.min_value = 1
		_give_amount.max_value = max(1, qty + 1)
		_give_amount.value = min(1, qty) if qty > 0 else 1
	_give_button.disabled = qty <= 0
	_give_button.visible = true
	_give_amount.visible = true
	_player_dropdown.visible = true
	_player_dropdown.get_parent().visible = true
	# show give label (the one before give row)
	_set_detail_children_visible(true)

func _clear_detail() -> void:
	_selected_item = null
	_detail_placeholder.visible = true
	_detail_name.text = ""
	_detail_name.visible = false
	_detail_qty_label.text = ""
	_detail_qty_label.visible = false
	_detail_desc.text = ""
	_detail_desc.visible = false
	_detail_icon.texture = null
	_detail_icon.visible = false
	if _detail_icon.get_parent():
		_detail_icon.get_parent().visible = false
	for child in _detail_badges_hbox.get_children():
		child.queue_free()
	_detail_badges_hbox.visible = false
	_give_button.visible = false
	_give_amount.visible = false
	_player_dropdown.visible = false
	_player_dropdown.get_parent().visible = false
	_set_detail_children_visible(false)

func _set_detail_children_visible(vis: bool) -> void:
	# Show/hide everything except placeholder in the detail vbox
	var vbox = _detail_panel.get_child(0)
	for i in range(vbox.get_child_count()):
		var child = vbox.get_child(i)
		if child == _detail_placeholder:
			child.visible = not vis
		else:
			child.visible = vis

func _get_row_by_id(rid) -> Dictionary:
	return _items_by_key.get(_key_str(rid), {})

# ============================================================
#  GIVE SYSTEM
# ============================================================
func _populate_player_dropdown() -> void:
	if _player_dropdown == null:
		return
	_player_dropdown.clear()
	_companion_receivers.clear()
	for pname in Global.CHARACTERS_NAME.keys():
		if pname != Global.ACTIVE_USER_NAME and pname != "Chase":
			_player_dropdown.add_item(pname)
	for cname in _eligible_companion_names():
		_player_dropdown.add_item(cname)
		_companion_receivers[cname] = true

func _on_give_button_pressed() -> void:
	var idx = _player_dropdown.selected
	if idx < 0:
		return
	var target_name = _player_dropdown.get_item_text(idx)
	var amount = int(_give_amount.value) if _give_amount != null else 0
	var item_name = _detail_name.text
	if amount <= 0:
		return

	var popup = AcceptDialog.new()
	popup.title = "Confirm Give"
	popup.dialog_text = "Give %d x %s to %s?" % [amount, item_name, target_name]
	popup.ok_button_text = "Give"
	popup.add_cancel_button("Cancel")
	popup.confirmed.connect(func():
		transfer_item(Global.ACTIVE_USER_NAME, target_name, item_name, amount)
		popup.queue_free()
	)
	popup.canceled.connect(func(): popup.queue_free())
	add_child(popup)
	popup.popup_centered()

func transfer_item(giver, receiver, item_name, quantity):
	# All real work happens host-side via NetworkManager.request_item_transfer,
	# which validates, stages the receiver-side addition, awaits the receiver's
	# ack, then subtracts from the giver. This way the giver only loses items
	# after the receiver confirms receipt (or the host commits because the
	# receiver is offline — host holds them until reconnect).
	#
	# Client-side checks here are pure UX hints so obvious failures don't even
	# round-trip to the host. The host re-validates authoritatively.

	if str(giver).strip_edges() == "" or str(receiver).strip_edges() == "" or str(item_name).strip_edges() == "":
		Toast.notify("Invalid transfer", Toast.ERROR)
		return
	var qty: int = int(quantity)
	if qty <= 0:
		Toast.notify("Quantity must be at least 1", Toast.ERROR)
		return
	if str(giver) == str(receiver):
		Toast.notify("Cannot give to yourself", Toast.ERROR)
		return

	var sending_record = null
	for item in Global.CHARACTER_ITEMS.values():
		if item.get("Owner") == giver and item.get("Name") == item_name:
			sending_record = item
			break
	if sending_record == null:
		Toast.notify("You don't have %s" % item_name, Toast.ERROR)
		return
	var sender_qty: int = int(sending_record.get("Quantity", 0))
	if sender_qty < qty:
		Toast.notify("You only have %d %s" % [sender_qty, item_name], Toast.WARNING)
		return

	# Unique correlation ID — peer_id + monotonic ms timestamp.
	var my_peer: int = multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var corr_id: String = "%d-%d" % [my_peer, Time.get_ticks_msec()]

	# Log the attempt audit-style (success/fail Toast comes from NetworkManager).
	Global.Log(
		"inventory",
		"transfer_item_request",
		"Character_Items",
		corr_id,
		{ "giver": giver, "receiver": receiver, "item": item_name, "giver_qty_before": sender_qty },
		{ "giver": giver, "receiver": receiver, "item": item_name, "qty_attempted": qty },
		{ "entity": "item", "giver_item_id": str(int(sending_record.get("id", 0))) },
		"requested",
		"audit"
	)

	# Companions aren't peers — move via the owned-item path (no ack roundtrip).
	if _companion_receivers.has(receiver):
		NetworkManager.request_owned_item_move(corr_id, giver, receiver, item_name, qty)
	else:
		NetworkManager.request_item_transfer(corr_id, receiver, item_name, qty)

# ============================================================
#  CLOSE
# ============================================================
func _on_exit_button_pressed() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()



func _save_layout() -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://ui_settings.cfg")
	cfg.set_value("inventory_layout", "split", _split.split_offset)
	cfg.save("user://ui_settings.cfg")

func _load_layout() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		if cfg.has_section_key("inventory_layout", "split"):
			_split.split_offset = cfg.get_value("inventory_layout", "split", 0)
