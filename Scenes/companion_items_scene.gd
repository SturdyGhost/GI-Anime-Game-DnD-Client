extends Control

# =============================================================================
# Companion Items Scene — view a companion's held items and give/take them.
# Items move via NetworkManager.request_owned_item_move (host-authoritative),
# which only permits the active player to shuffle items between themselves and
# companions they own.
# =============================================================================

# ---- Theme palette (matches the gear detail scenes) ----
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

const FONT_BODY  = 30
const FONT_HDR   = 36
const FONT_TITLE = 48
const MARGIN     = 60

# ---- State ----
var _companion: String = ""

# ---- Nodes ----
var _title_label: Label
var _held_list: ItemList   # items the companion holds
var _mine_list: ItemList   # the active player's items
var _amount: SpinBox
var _give_btn: Button
var _take_btn: Button

# =============================================================================
func _ready() -> void:
	# Bare Control.new() roots start at 0x0 — fill the parent so the UI shows.
	custom_minimum_size = Vector2(2560, 1440)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not Global.is_connected("data_load_complete", Callable(self, "_refresh")):
		Global.connect("data_load_complete", Callable(self, "_refresh"))
	if not NetworkManager.is_connected("transfer_result", Callable(self, "_on_transfer_result")):
		NetworkManager.connect("transfer_result", Callable(self, "_on_transfer_result"))
	_refresh()

## Entry point — scope the screen to a companion.
func open_for_companion(companion_name: String) -> void:
	_companion = companion_name
	_refresh()

# =============================================================================
# UI
# =============================================================================
func _build_ui() -> void:
	var bg = Panel.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _flat(BG_DEEP))
	add_child(bg)

	var outer = MarginContainer.new()
	outer.set_anchors_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", MARGIN)
	outer.add_theme_constant_override("margin_right", MARGIN)
	outer.add_theme_constant_override("margin_top", MARGIN)
	outer.add_theme_constant_override("margin_bottom", MARGIN)
	add_child(outer)

	var main = VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	outer.add_child(main)

	# Title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	main.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "ITEMS"
	_title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	_title_label.add_theme_color_override("font_color", ACCENT)
	title_row.add_child(_title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(36, 36)
	_style_btn(close_btn)
	close_btn.pressed.connect(_close_scene)
	title_row.add_child(close_btn)

	# Two lists side by side
	var lists_row = HBoxContainer.new()
	lists_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists_row.add_theme_constant_override("separation", 16)
	main.add_child(lists_row)

	var held_col = _build_list_column("Held by Companion")
	held_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists_row.add_child(held_col)
	_held_list = held_col.get_meta("list")

	var mine_col = _build_list_column("Your Items")
	mine_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists_row.add_child(mine_col)
	_mine_list = mine_col.get_meta("list")

	# Footer: amount + give/take
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(footer)

	var amt_lbl = Label.new()
	amt_lbl.text = "Amount:"
	amt_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	amt_lbl.add_theme_color_override("font_color", TEXT)
	amt_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(amt_lbl)

	_amount = SpinBox.new()
	_amount.min_value = 1
	_amount.max_value = 999
	_amount.value = 1
	_amount.custom_minimum_size.x = 120
	footer.add_child(_amount)

	# Button order and arrows follow the two list columns: "Held by Companion" is
	# the LEFT column, "Your Items" the RIGHT. So Give (Your Items -> Companion)
	# sits left pointing left, and Take (Companion -> Your Items) sits right
	# pointing right — each arrow aims at the column the items land in.
	_give_btn = Button.new()
	_give_btn.text = "← Give to Companion"
	_give_btn.custom_minimum_size.x = 260
	_style_btn(_give_btn, true)
	_give_btn.pressed.connect(_on_give_pressed)
	footer.add_child(_give_btn)

	_take_btn = Button.new()
	_take_btn.text = "Take from Companion →"
	_take_btn.custom_minimum_size.x = 260
	_style_btn(_take_btn)
	_take_btn.pressed.connect(_on_take_pressed)
	footer.add_child(_take_btn)

func _build_list_column(header: String) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var lbl = Label.new()
	lbl.name = "Header"
	lbl.text = header
	lbl.add_theme_font_size_override("font_size", FONT_HDR)
	lbl.add_theme_color_override("font_color", TEXT_SEC)
	col.add_child(lbl)

	var card = PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var csb = _flat(BG_PANEL)
	csb.border_color = BORDER
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(6)
	csb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", csb)
	col.add_child(card)

	var list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("font_size", FONT_BODY)
	list.add_theme_color_override("font_color", TEXT)
	list.add_theme_stylebox_override("panel", _flat(BG_INSET))
	card.add_child(list)

	col.set_meta("list", list)
	col.set_meta("header_label", lbl)
	return col

# =============================================================================
# Data
# =============================================================================
func _refresh(_a = null) -> void:
	if _title_label == null:
		return
	_title_label.text = "ITEMS — " + _companion if _companion != "" else "ITEMS"

	# Update column headers with names
	var held_col := _held_list.get_parent().get_parent() if _held_list else null
	if held_col and held_col.has_meta("header_label"):
		held_col.get_meta("header_label").text = "Held by %s" % _companion
	var mine_col := _mine_list.get_parent().get_parent() if _mine_list else null
	if mine_col and mine_col.has_meta("header_label"):
		mine_col.get_meta("header_label").text = "%s's Items" % Global.ACTIVE_USER_NAME

	_populate_list(_held_list, _companion)
	_populate_list(_mine_list, Global.ACTIVE_USER_NAME)

func _populate_list(list: ItemList, owner: String) -> void:
	if list == null:
		return
	list.clear()
	if owner == "":
		return
	for it in Global.CHARACTER_ITEMS.values():
		if str(it.get("Owner", "")) != owner:
			continue
		if int(it.get("Quantity", 0)) <= 0:
			continue
		var nm := str(it.get("Name", ""))
		var qty := int(it.get("Quantity", 0))
		var typ := str(it.get("Type", ""))
		var idx := list.add_item("%s   x%d   (%s)" % [nm, qty, typ])
		list.set_item_metadata(idx, {"name": nm, "qty": qty})

func _selected(list: ItemList) -> Dictionary:
	if list == null:
		return {}
	var sel := list.get_selected_items()
	if sel.is_empty():
		return {}
	return list.get_item_metadata(sel[0])

# =============================================================================
# Actions
# =============================================================================
func _on_give_pressed() -> void:
	if _companion == "":
		return
	var meta := _selected(_mine_list)
	if meta.is_empty():
		Toast.notify("Select one of your items to give", Toast.WARNING)
		return
	_do_move(Global.ACTIVE_USER_NAME, _companion, meta)

func _on_take_pressed() -> void:
	if _companion == "":
		return
	var meta := _selected(_held_list)
	if meta.is_empty():
		Toast.notify("Select an item the companion holds", Toast.WARNING)
		return
	_do_move(_companion, Global.ACTIVE_USER_NAME, meta)

func _do_move(from_owner: String, to_owner: String, meta: Dictionary) -> void:
	var item_name := str(meta.get("name", ""))
	var available := int(meta.get("qty", 0))
	var qty := int(_amount.value)
	if qty > available:
		qty = available
	if qty <= 0:
		return
	var my_peer: int = multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0
	var corr_id: String = "%d-%d-citem" % [my_peer, Time.get_ticks_msec()]
	NetworkManager.request_owned_item_move(corr_id, from_owner, to_owner, item_name, qty)

func _on_transfer_result(_corr_id: String, _success: bool, _message: String) -> void:
	_refresh()

# =============================================================================
# Exit / styling
# =============================================================================
func _close_scene() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

func _flat(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	return sb

func _style_btn(btn: Button, primary: bool = false) -> void:
	var sb = _flat(ACCENT if primary else BG_INSET)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var hover = sb.duplicate()
	hover.bg_color = sb.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	# Primary buttons keep the accent fill but use the normal light body text —
	# the old BG_DEEP-on-ACCENT inversion read as black text and looked broken
	# next to every other button in the app (dark fill + ACCENT text).
	btn.add_theme_color_override("font_color", TEXT if primary else ACCENT)
	btn.add_theme_color_override("font_hover_color", TEXT if primary else ACCENT)
	btn.add_theme_font_size_override("font_size", FONT_BODY)
