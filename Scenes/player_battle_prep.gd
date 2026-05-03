extends Control

# =============================================================================
# Player Battle Prep — full-screen scene, all UI programmatic
# =============================================================================

# ---- Theme constants (matching weapon_detail_scene / stat_summary) ----
# Lighter blue palette matching weapon/artifact scenes
const BG_COLOR         = Color(0.102, 0.122, 0.169)
const PANEL_COLOR      = Color(0.133, 0.157, 0.22)
const HEADER_COLOR     = Color(0.09, 0.11, 0.155)
const ACCENT_GOLD      = Color(0.788, 0.659, 0.298)
const ACCENT_GOLD_DIM  = Color(0.541, 0.455, 0.259)
const TEXT_COLOR        = Color(0.96, 0.96, 0.98)
const TEXT_DIM          = Color(0.58, 0.62, 0.71)
const GREEN_COLOR      = Color(0.292, 0.855, 0.498)
const RED_COLOR        = Color(0.937, 0.267, 0.267)
const ROW_EVEN         = Color(0.133, 0.157, 0.22)
const ROW_ODD          = Color(0.102, 0.122, 0.169)
const BG_HOVER         = Color(0.19, 0.22, 0.30)
const CARD_COLOR       = Color(0.165, 0.192, 0.27)
const CARD_BORDER      = Color(0.22, 0.25, 0.33)
const HP_BAR_BG        = Color(0.15, 0.17, 0.22)
const HP_BAR_FILL      = Color(0.292, 0.855, 0.498)
const HP_BAR_LOW       = Color(0.937, 0.267, 0.267)
const SIDEBAR_COLOR    = Color(0.09, 0.11, 0.155)

const FONT_SIZE        = 15
const FONT_SIZE_HEADER = 17
const FONT_SIZE_TITLE  = 24
const FONT_SIZE_SMALL  = 13
const SIDEBAR_WIDTH    = 280

# ---- Node refs (built in _ready) ----
var _bg: Panel
var _main_hbox: HBoxContainer
var _left_scroll: ScrollContainer
var _left_vbox: VBoxContainer
var _right_panel: PanelContainer
var _right_vbox: VBoxContainer

# Turn order panel (reuse existing TurnOrderPanel.gd)
var _turn_order_panel: Panel

# Food confirm modal
var _modal_overlay: ColorRect
var _modal_panel: PanelContainer
var _modal_current_buff_label: Label
var _modal_new_buff_label: Label
var _modal_cancel_btn: Button
var _modal_apply_btn: Button
var _pending_food_item: Dictionary = {}  # item dict for the food being confirmed
var _pending_food_owner: String = ""

# Ready tracking
var _ready_toggles: Dictionary = {}   # player_name -> Button
var _consumable_dropdowns: Dictionary = {}  # player_name -> OptionButton
var _confirm_buttons: Dictionary = {}  # player_name -> Button
var _ready_badge_label: Label


func _ready() -> void:
	# Reset Current_Turn to first party member
	var party_members: Array = []
	for c in Global.PartyCharacters:
		party_members.append(c)
	for c in Global.PartyCompanions:
		party_members.append(c)
	if party_members.size() > 0:
		var updates = [{
			"table": "Party",
			"record_id": int(Global.Current_Party.get("id", 0)),
			"field": "Current_Turn",
			"value": party_members[0]
		}]
		Global.Update_Records(updates)

	# Generate challenge quest if host and none active
	if NetworkManager.is_host and Global.active_challenge_quest.is_empty():
		var quest = ChallengeQuestGenerator.generate()
		Global.active_challenge_quest = quest.to_dict()
		NetworkManager.broadcast_table_update("Party")

	_build_ui()
	_populate_player_cards()
	_populate_turn_order()
	_populate_food_buff()
	_update_ready_badge()

	# Connect live refresh
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)


func _process(_delta: float) -> void:
	var dm = Global.Current_Party.get("Dungeon_Master", "")
	var dm_id = Global.CHARACTERS_NAME.get(dm, "")
	if dm_id != "" and Global.CHARACTERS.get(dm_id, {}).get("Ready") == true:
		get_tree().change_scene_to_file("res://Scenes/BattleScene.tscn")


var _syncing_turn_order: bool = false

func _on_data_load_complete() -> void:
	_refresh_ready_states()
	_update_ready_badge()
	# Sync turn order from server if someone else changed it
	if not _syncing_turn_order:
		_sync_turn_order_from_server()
	# Refresh food buff display (just update text, don't rebuild)
	_refresh_food_buff_display()


func _sync_turn_order_from_server() -> void:
	var server_order = Global.Current_Party.get("Turn_Order", [])
	if not server_order is Array or server_order.is_empty():
		return
	# Only rebuild if the order actually changed from what we have
	if server_order == _turn_order:
		return
	_turn_order = []
	for m in server_order:
		_turn_order.append(m)
	_rebuild_turn_rows()


func _refresh_food_buff_display() -> void:
	var buff_card = _right_vbox.get_node_or_null("FoodBuffCard")
	if buff_card == null:
		return
	var name_lbl = buff_card.find_child("BuffName", true, false)
	var detail_lbl = buff_card.find_child("BuffDetail", true, false)
	var buff = Global.Current_Party.get("Active_Food_Buff", "None")
	var battles = Global.Current_Party.get("Buff_Battles_Left", 0)
	if name_lbl:
		name_lbl.text = str(buff) if buff != null and str(buff) != "None" else "None"
	if detail_lbl:
		if buff != null and str(buff) != "None":
			detail_lbl.text = "Battles remaining: " + str(battles)
		else:
			detail_lbl.text = "No active buff"


# =============================================================================
# UI BUILD
# =============================================================================

func _build_ui() -> void:
	# Background panel
	_bg = Panel.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = BG_COLOR
	_bg.add_theme_stylebox_override("panel", bg_sb)
	add_child(_bg)

	# Main HBox
	_main_hbox = HBoxContainer.new()
	_main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_hbox.add_theme_constant_override("separation", 0)
	add_child(_main_hbox)

	# ---- LEFT: scrollable player cards ----
	_left_scroll = ScrollContainer.new()
	_left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_hbox.add_child(_left_scroll)

	_left_vbox = VBoxContainer.new()
	_left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_vbox.add_theme_constant_override("separation", 12)
	# Padding
	var left_margin = MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 20)
	left_margin.add_theme_constant_override("margin_right", 12)
	left_margin.add_theme_constant_override("margin_top", 16)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	_left_scroll.add_child(left_margin)
	left_margin.add_child(_left_vbox)

	# Title
	var title = Label.new()
	title.text = "Battle Preparation"
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	_left_vbox.add_child(title)

	# ---- RIGHT: sidebar ----
	_right_panel = PanelContainer.new()
	_right_panel.custom_minimum_size.x = SIDEBAR_WIDTH
	_right_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sidebar_sb = StyleBoxFlat.new()
	sidebar_sb.bg_color = SIDEBAR_COLOR
	sidebar_sb.border_width_left = 1
	sidebar_sb.border_color = CARD_BORDER
	_right_panel.add_theme_stylebox_override("panel", sidebar_sb)
	_main_hbox.add_child(_right_panel)

	var right_margin = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 12)
	right_margin.add_theme_constant_override("margin_right", 12)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	_right_panel.add_child(right_margin)

	_right_vbox = VBoxContainer.new()
	_right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_vbox.add_theme_constant_override("separation", 16)
	right_margin.add_child(_right_vbox)

	# Build food confirm modal (hidden)
	_build_food_modal()

	# Exit button (top-right, back to player hub)
	var exit_btn = Button.new()
	exit_btn.text = "Back to Hub"
	exit_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	exit_btn.offset_left = -130
	exit_btn.offset_top = 12
	exit_btn.offset_right = -12
	exit_btn.offset_bottom = 44
	exit_btn.z_index = 10
	exit_btn.add_theme_font_size_override("font_size", 14)
	exit_btn.add_theme_color_override("font_color", TEXT_COLOR)
	var exit_sb = StyleBoxFlat.new()
	exit_sb.bg_color = CARD_COLOR
	exit_sb.border_color = CARD_BORDER
	exit_sb.set_border_width_all(1)
	exit_sb.set_corner_radius_all(4)
	exit_sb.content_margin_left = 12
	exit_sb.content_margin_right = 12
	exit_sb.content_margin_top = 6
	exit_sb.content_margin_bottom = 6
	exit_btn.add_theme_stylebox_override("normal", exit_sb)
	var exit_hover = exit_sb.duplicate()
	exit_hover.bg_color = BG_HOVER
	exit_btn.add_theme_stylebox_override("hover", exit_hover)
	exit_btn.pressed.connect(_go_back_to_hub)
	add_child(exit_btn)


func _go_back_to_hub() -> void:
	if Global.ACTIVE_USER_TYPE == "Player":
		get_tree().change_scene_to_file("res://Scenes/player_hub.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/DMHub.tscn")


# =============================================================================
# PLAYER CARDS (LEFT)
# =============================================================================

func _populate_player_cards() -> void:
	for player_name in Global.PartyCharacters:
		var card = _build_player_card(player_name)
		_left_vbox.add_child(card)


func _build_player_card(player_name: String) -> PanelContainer:
	var pid = Global.CHARACTERS_NAME.get(player_name, "")
	var pdata: Dictionary = Global.CHARACTERS.get(pid, {})

	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = CARD_COLOR
	card_sb.border_width_bottom = 1
	card_sb.border_width_top = 1
	card_sb.border_width_left = 1
	card_sb.border_width_right = 1
	card_sb.border_color = CARD_BORDER
	card_sb.corner_radius_top_left = 6
	card_sb.corner_radius_top_right = 6
	card_sb.corner_radius_bottom_left = 6
	card_sb.corner_radius_bottom_right = 6
	card_sb.content_margin_left = 16
	card_sb.content_margin_right = 16
	card_sb.content_margin_top = 12
	card_sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# ---- Top row: portrait + info + ready toggle ----
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	# Portrait
	var portrait = _make_portrait(player_name, pdata, Vector2(56, 56))
	top_row.add_child(portrait)

	# Info column
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	top_row.add_child(info_vbox)

	# Name
	var name_label = Label.new()
	name_label.text = player_name
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	name_label.add_theme_color_override("font_color", ACCENT_GOLD)
	info_vbox.add_child(name_label)

	# Element + Weapon type
	var element = pdata.get("Element", "?")
	var weapon_type = _get_equipped_weapon_type(player_name)
	var subtext = Label.new()
	subtext.text = element + "  |  " + weapon_type
	subtext.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	subtext.add_theme_color_override("font_color", TEXT_DIM)
	info_vbox.add_child(subtext)

	# HP bar
	var hp_row = _build_hp_bar(pdata)
	info_vbox.add_child(hp_row)

	# Ready toggle — only enabled for the current player
	var is_me = (player_name == Global.ACTIVE_USER_NAME)
	var ready_btn = Button.new()
	ready_btn.toggle_mode = true
	ready_btn.text = "Ready"
	ready_btn.custom_minimum_size = Vector2(90, 36)
	ready_btn.button_pressed = pdata.get("Ready", false) == true
	_style_ready_button(ready_btn)
	if is_me:
		ready_btn.pressed.connect(_on_ready_toggled.bind(player_name, ready_btn))
	else:
		ready_btn.disabled = true
		ready_btn.tooltip_text = "Only %s can toggle their ready status" % player_name
	top_row.add_child(ready_btn)
	_ready_toggles[player_name] = ready_btn

	# ---- Consumable row (only interactive for current player) ----
	var consumable_row = HBoxContainer.new()
	consumable_row.add_theme_constant_override("separation", 8)
	vbox.add_child(consumable_row)

	var consumable_label = Label.new()
	consumable_label.text = "Use Consumable:"
	consumable_label.add_theme_font_size_override("font_size", FONT_SIZE)
	consumable_label.add_theme_color_override("font_color", TEXT_COLOR)
	consumable_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	consumable_row.add_child(consumable_label)

	var dropdown = OptionButton.new()
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dropdown.custom_minimum_size.y = 32
	dropdown.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	dropdown.add_theme_color_override("font_color", TEXT_COLOR)
	if is_me:
		_populate_consumable_dropdown(dropdown, player_name)
	else:
		dropdown.add_item("---", 0)
		dropdown.disabled = true
	consumable_row.add_child(dropdown)
	_consumable_dropdowns[player_name] = dropdown

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm Use"
	confirm_btn.custom_minimum_size = Vector2(100, 32)
	confirm_btn.disabled = true
	_style_button(confirm_btn)
	if is_me:
		confirm_btn.pressed.connect(_on_confirm_food.bind(player_name))
	else:
		confirm_btn.disabled = true
	consumable_row.add_child(confirm_btn)
	_confirm_buttons[player_name] = confirm_btn

	if is_me:
		dropdown.item_selected.connect(_on_consumable_selected.bind(player_name))

	# ---- Companions sub-section ----
	var companions = _get_active_companions(player_name)
	if companions.size() > 0:
		var comp_header = Label.new()
		comp_header.text = "Companions"
		comp_header.add_theme_font_size_override("font_size", FONT_SIZE)
		comp_header.add_theme_color_override("font_color", ACCENT_GOLD_DIM)
		vbox.add_child(comp_header)

		var comp_row = HBoxContainer.new()
		comp_row.add_theme_constant_override("separation", 12)
		vbox.add_child(comp_row)

		for cdata in companions:
			var comp_card = _build_companion_chip(cdata)
			comp_row.add_child(comp_card)

	return card


func _build_companion_chip(cdata: Dictionary) -> HBoxContainer:
	var chip = HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)

	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(32, 32)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cname = cdata.get("Name", "")
	var hyphen = cname.to_lower().replace(" ", "-")
	var path = "res://UI/Character Portaits/ui-avataricon-" + hyphen + ".png"
	if ResourceLoader.exists(path):
		portrait.texture = load(path)
	chip.add_child(portrait)

	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	chip.add_child(info)

	var nlbl = Label.new()
	nlbl.text = cname
	nlbl.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	nlbl.add_theme_color_override("font_color", TEXT_COLOR)
	info.add_child(nlbl)

	var elbl = Label.new()
	elbl.text = cdata.get("Element", "")
	elbl.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	elbl.add_theme_color_override("font_color", TEXT_DIM)
	info.add_child(elbl)

	return chip


func _build_hp_bar(pdata: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var current_hp = int(pdata.get("Current_Health", 0))
	var max_hp = int(pdata.get("Max_Health", 1))
	var ratio = float(current_hp) / float(max(max_hp, 1))

	# Bar background
	var bar_bg = Panel.new()
	bar_bg.custom_minimum_size = Vector2(120, 14)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = HP_BAR_BG
	bg_sb.corner_radius_top_left = 3
	bg_sb.corner_radius_top_right = 3
	bg_sb.corner_radius_bottom_left = 3
	bg_sb.corner_radius_bottom_right = 3
	bar_bg.add_theme_stylebox_override("panel", bg_sb)
	row.add_child(bar_bg)

	# Bar fill
	var bar_fill = Panel.new()
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.anchor_right = clampf(ratio, 0.0, 1.0)
	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = HP_BAR_FILL if ratio > 0.3 else HP_BAR_LOW
	fill_sb.corner_radius_top_left = 3
	fill_sb.corner_radius_top_right = 3
	fill_sb.corner_radius_bottom_left = 3
	fill_sb.corner_radius_bottom_right = 3
	bar_fill.add_theme_stylebox_override("panel", fill_sb)
	bar_bg.add_child(bar_fill)

	# HP numbers
	var hp_label = Label.new()
	hp_label.text = str(current_hp) + " / " + str(max_hp)
	hp_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	hp_label.add_theme_color_override("font_color", TEXT_COLOR)
	hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hp_label)

	return row


func _make_portrait(char_name: String, pdata: Dictionary, size: Vector2) -> TextureRect:
	var tex = TextureRect.new()
	tex.custom_minimum_size = size
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var portrait_file = pdata.get("Portrait", "")
	if portrait_file != "" and portrait_file != "null":
		var path = "res://UI/Emotes/" + str(portrait_file)
		if ResourceLoader.exists(path):
			tex.texture = load(path)
	return tex


# =============================================================================
# RIGHT SIDEBAR
# =============================================================================

var _turn_order: Array = []
var _turn_order_container: VBoxContainer

func _populate_turn_order() -> void:
	_build_challenge_section(_right_vbox)

	var header = Label.new()
	header.text = "Turn Order"
	header.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	header.add_theme_color_override("font_color", ACCENT_GOLD)
	_right_vbox.add_child(header)

	# Build turn order list inline (not using TurnOrderPanel to avoid sizing issues)
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD_COLOR
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)
	_right_vbox.add_child(card)

	_turn_order_container = VBoxContainer.new()
	_turn_order_container.add_theme_constant_override("separation", 3)
	card.add_child(_turn_order_container)

	# Build the order
	_turn_order = _get_initial_order()
	_rebuild_turn_rows()
	_persist_turn_order()


func _get_initial_order() -> Array:
	var existing = Global.Current_Party.get("Turn_Order", [])
	var all_members: Array = []
	for c in Global.PartyCharacters:
		all_members.append(c)
	# Include ALL active companions (both player-chosen and DM-set)
	for c in Global.PartyCompanions:
		if not all_members.has(c):
			all_members.append(c)
	for comp in Global.COMPANIONS.values():
		if comp.get("Active", false) == true:
			var comp_name = str(comp.get("Name", ""))
			if comp_name != "" and not all_members.has(comp_name):
				all_members.append(comp_name)

	if existing is Array and existing.size() > 0:
		var result: Array = []
		for m in existing:
			if all_members.has(m):
				result.append(m)
		for m in all_members:
			if not result.has(m):
				result.append(m)
		if result.size() > 0:
			return result

	return all_members


func _rebuild_turn_rows() -> void:
	for c in _turn_order_container.get_children():
		c.queue_free()

	for i in _turn_order.size():
		var name_str = _turn_order[i]
		var is_companion = Global.PartyCompanions.has(name_str)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Row background
		var row_bg = PanelContainer.new()
		var row_sb = StyleBoxFlat.new()
		row_sb.bg_color = BG_COLOR if i % 2 == 0 else PANEL_COLOR
		row_sb.set_corner_radius_all(3)
		row_sb.content_margin_left = 6
		row_sb.content_margin_right = 4
		row_sb.content_margin_top = 3
		row_sb.content_margin_bottom = 3
		row_bg.add_theme_stylebox_override("panel", row_sb)
		row_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_turn_order_container.add_child(row_bg)

		var inner = HBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		row_bg.add_child(inner)

		# Number
		var num = Label.new()
		num.text = str(i + 1) + "."
		num.add_theme_font_size_override("font_size", 14)
		num.add_theme_color_override("font_color", TEXT_DIM)
		num.custom_minimum_size.x = 20
		inner.add_child(num)

		# Name
		var lbl = Label.new()
		lbl.text = name_str
		if is_companion:
			lbl.text += " (comp)"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", TEXT_COLOR)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		inner.add_child(lbl)

		# Up button
		var up_btn = Button.new()
		up_btn.text = "▲"
		up_btn.custom_minimum_size = Vector2(28, 24)
		up_btn.add_theme_font_size_override("font_size", 12)
		_style_small_btn(up_btn)
		up_btn.pressed.connect(_move_turn_order.bind(i, -1))
		inner.add_child(up_btn)

		# Down button
		var dn_btn = Button.new()
		dn_btn.text = "▼"
		dn_btn.custom_minimum_size = Vector2(28, 24)
		dn_btn.add_theme_font_size_override("font_size", 12)
		_style_small_btn(dn_btn)
		dn_btn.pressed.connect(_move_turn_order.bind(i, 1))
		inner.add_child(dn_btn)


func _style_small_btn(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", sb)
	var hover = sb.duplicate()
	hover.bg_color = BG_HOVER
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", TEXT_COLOR)


func _move_turn_order(from_idx: int, delta: int) -> void:
	var to_idx = from_idx + delta
	if to_idx < 0:
		to_idx = _turn_order.size() - 1
	elif to_idx >= _turn_order.size():
		to_idx = 0
	var item = _turn_order[from_idx]
	_turn_order.remove_at(from_idx)
	_turn_order.insert(to_idx, item)
	_rebuild_turn_rows()
	_persist_turn_order()


func _persist_turn_order() -> void:
	var party_id = int(Global.Current_Party.get("id", 0))
	if party_id == 0 or _turn_order.is_empty():
		return
	_syncing_turn_order = true
	Global.Update_Records([
		{"table": "Party", "record_id": party_id, "field": "Turn_Order", "value": _turn_order},
		{"table": "Party", "record_id": party_id, "field": "Current_Turn", "value": _turn_order[0]}
	])
	# Reset flag after a frame to allow the data_load_complete from our own update to pass
	get_tree().create_timer(0.5).timeout.connect(func(): _syncing_turn_order = false)


func _build_challenge_section(parent: VBoxContainer) -> void:
	var quest = Global.active_challenge_quest
	if quest.is_empty():
		return

	var header = Label.new()
	header.text = "CHALLENGE QUEST"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", ACCENT_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(header)

	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = PANEL_COLOR
	sb.border_color = ACCENT_GOLD_DIM
	sb.border_width_left = 2
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var giver_name = str(quest.get("quest_giver_name", ""))
	var personality = str(quest.get("quest_giver_personality", ""))
	var giver_label = Label.new()
	giver_label.text = "%s (%s)" % [giver_name, personality]
	giver_label.add_theme_font_size_override("font_size", 13)
	giver_label.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(giver_label)

	var challenge_label = RichTextLabel.new()
	challenge_label.bbcode_enabled = true
	challenge_label.fit_content = true
	challenge_label.scroll_active = false
	challenge_label.text = str(quest.get("challenge_text", ""))
	challenge_label.add_theme_font_size_override("normal_font_size", 15)
	challenge_label.add_theme_color_override("default_color", TEXT_COLOR)
	vbox.add_child(challenge_label)

	# DM override controls (Task 10)
	if Global.ACTIVE_USER_TYPE == "Dungeon Master":
		var override_btn = Button.new()
		override_btn.text = "Reroll Challenge"
		override_btn.custom_minimum_size = Vector2(0, 32)
		override_btn.add_theme_font_size_override("font_size", 13)
		override_btn.pressed.connect(_reroll_challenge)
		vbox.add_child(override_btn)

		var edit_btn = Button.new()
		edit_btn.text = "Edit Challenge"
		edit_btn.custom_minimum_size = Vector2(0, 32)
		edit_btn.add_theme_font_size_override("font_size", 13)
		edit_btn.pressed.connect(_edit_challenge)
		vbox.add_child(edit_btn)


func _reroll_challenge() -> void:
	var quest = ChallengeQuestGenerator.generate()
	Global.active_challenge_quest = quest.to_dict()
	NetworkManager.broadcast_table_update("Party")
	_build_ui()


func _edit_challenge() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Edit Challenge"
	var input = LineEdit.new()
	input.text = str(Global.active_challenge_quest.get("challenge_text", ""))
	input.placeholder_text = "Enter custom challenge..."
	input.custom_minimum_size = Vector2(400, 36)
	dialog.add_child(input)
	dialog.confirmed.connect(func():
		var q = Global.active_challenge_quest.duplicate()
		q["challenge_text"] = input.text
		Global.active_challenge_quest = q
		NetworkManager.broadcast_table_update("Party")
		dialog.queue_free()
		_build_ui()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(450, 150))


func _populate_food_buff() -> void:
	# Remove previous food buff card if refreshing
	var existing = _right_vbox.get_node_or_null("FoodBuffCard")
	if existing:
		existing.queue_free()
		await get_tree().process_frame

	# Section header
	if not _right_vbox.get_node_or_null("FoodBuffHeader"):
		var header = Label.new()
		header.name = "FoodBuffHeader"
		header.text = "Party Food Buff"
		header.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
		header.add_theme_color_override("font_color", ACCENT_GOLD)
		_right_vbox.add_child(header)

	var card = PanelContainer.new()
	card.name = "FoodBuffCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = CARD_COLOR
	card_sb.corner_radius_top_left = 4
	card_sb.corner_radius_top_right = 4
	card_sb.corner_radius_bottom_left = 4
	card_sb.corner_radius_bottom_right = 4
	card_sb.content_margin_left = 10
	card_sb.content_margin_right = 10
	card_sb.content_margin_top = 8
	card_sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_sb)
	_right_vbox.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var buff_name = str(Global.Current_Party.get("Active_Food_Buff", "None"))
	if buff_name == "" or buff_name == "null":
		buff_name = "None"
	var battles_left = Global.Current_Party.get("Buff_Battles_Left", 0)

	var buff_label = Label.new()
	buff_label.name = "BuffName"
	buff_label.text = buff_name
	buff_label.add_theme_font_size_override("font_size", FONT_SIZE)
	buff_label.add_theme_color_override("font_color", TEXT_COLOR)
	buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(buff_label)

	var battles_label = Label.new()
	battles_label.name = "BuffDetail"
	battles_label.text = "Battles remaining: " + str(battles_left)
	battles_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	battles_label.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(battles_label)

	# ---- Status / ready badge ----
	if not _right_vbox.get_node_or_null("StatusSection"):
		var sep = HSeparator.new()
		sep.name = "StatusSep"
		sep.add_theme_constant_override("separation", 12)
		_right_vbox.add_child(sep)

		var status_vbox = VBoxContainer.new()
		status_vbox.name = "StatusSection"
		status_vbox.add_theme_constant_override("separation", 6)
		_right_vbox.add_child(status_vbox)

		var waiting_label = Label.new()
		waiting_label.text = "Waiting for DM..."
		waiting_label.add_theme_font_size_override("font_size", FONT_SIZE)
		waiting_label.add_theme_color_override("font_color", TEXT_DIM)
		status_vbox.add_child(waiting_label)

		_ready_badge_label = Label.new()
		_ready_badge_label.add_theme_font_size_override("font_size", FONT_SIZE)
		_ready_badge_label.add_theme_color_override("font_color", GREEN_COLOR)
		status_vbox.add_child(_ready_badge_label)
		_update_ready_badge()


# =============================================================================
# FOOD CONFIRM MODAL
# =============================================================================

func _build_food_modal() -> void:
	_modal_overlay = ColorRect.new()
	_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.color = Color(0, 0, 0, 0.6)
	_modal_overlay.visible = false
	_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal_overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.add_child(center)

	_modal_panel = PanelContainer.new()
	_modal_panel.custom_minimum_size = Vector2(420, 220)
	var sb = StyleBoxFlat.new()
	sb.bg_color = PANEL_COLOR
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = ACCENT_GOLD_DIM
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_modal_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_modal_panel)

	var mvbox = VBoxContainer.new()
	mvbox.add_theme_constant_override("separation", 12)
	_modal_panel.add_child(mvbox)

	var title = Label.new()
	title.text = "Apply Food Buff"
	title.add_theme_font_size_override("font_size", FONT_SIZE_HEADER)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvbox.add_child(title)

	# Current -> New
	var arrow_row = HBoxContainer.new()
	arrow_row.add_theme_constant_override("separation", 10)
	arrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mvbox.add_child(arrow_row)

	_modal_current_buff_label = Label.new()
	_modal_current_buff_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_modal_current_buff_label.add_theme_color_override("font_color", TEXT_DIM)
	arrow_row.add_child(_modal_current_buff_label)

	var arrow = Label.new()
	arrow.text = " -> "
	arrow.add_theme_font_size_override("font_size", FONT_SIZE)
	arrow.add_theme_color_override("font_color", ACCENT_GOLD)
	arrow_row.add_child(arrow)

	_modal_new_buff_label = Label.new()
	_modal_new_buff_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_modal_new_buff_label.add_theme_color_override("font_color", GREEN_COLOR)
	arrow_row.add_child(_modal_new_buff_label)

	var warning = Label.new()
	warning.text = "This will replace the current party food buff for everyone."
	warning.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	warning.add_theme_color_override("font_color", TEXT_DIM)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD
	mvbox.add_child(warning)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mvbox.add_child(btn_row)

	_modal_cancel_btn = Button.new()
	_modal_cancel_btn.text = "Cancel"
	_modal_cancel_btn.custom_minimum_size = Vector2(100, 36)
	_style_button(_modal_cancel_btn)
	_modal_cancel_btn.pressed.connect(_on_modal_cancel)
	btn_row.add_child(_modal_cancel_btn)

	_modal_apply_btn = Button.new()
	_modal_apply_btn.text = "Apply Buff"
	_modal_apply_btn.custom_minimum_size = Vector2(120, 36)
	_style_button_accent(_modal_apply_btn)
	_modal_apply_btn.pressed.connect(_on_modal_apply)
	btn_row.add_child(_modal_apply_btn)


# =============================================================================
# CONSUMABLE LOGIC
# =============================================================================

func _populate_consumable_dropdown(dropdown: OptionButton, player_name: String) -> void:
	dropdown.clear()
	dropdown.add_item("None", 0)

	var idx = 1
	for item_id in Global.CHARACTER_ITEMS:
		var item: Dictionary = Global.CHARACTER_ITEMS[item_id]
		if item.get("Owner", "") != player_name:
			continue
		if item.get("Type", "") != "Consumable":
			continue
		var qty = int(item.get("Quantity", 0))
		if qty <= 0:
			continue
		var item_name_str = str(item.get("Name", item.get("Item", "")))
		# Only show pre-battle food items — ones whose description mentions "battle(s)"
		# These are party-wide buffs like "Increases ATK for 3 battles"
		var desc = _get_item_description(item_name_str)
		var desc_lower = desc.to_lower()
		if desc_lower.contains("material"):
			continue
		if not desc_lower.contains("battle"):
			continue  # Skip items that don't mention battles — those are in-battle consumables
		var display = item_name_str + " (x" + str(qty) + ")"
		if desc != "":
			display += " -- " + desc
		dropdown.add_item(display, idx)
		dropdown.set_item_metadata(idx, {
			"item_id": item_id,
			"item_name": item_name_str,
			"owner": player_name,
			"quantity": qty,
			"description": desc,
		})
		idx += 1


func _get_item_description(item_name: String) -> String:
	for it in Global.ITEMS.values():
		if it.get("Item", "") == item_name:
			return str(it.get("Description", ""))
	return ""


func _on_consumable_selected(index: int, player_name: String) -> void:
	var btn = _confirm_buttons.get(player_name)
	if btn:
		btn.disabled = (index == 0)


func _on_confirm_food(player_name: String) -> void:
	var dropdown = _consumable_dropdowns.get(player_name)
	if not dropdown:
		return
	var selected_idx = dropdown.selected
	if selected_idx <= 0:
		return
	var meta = dropdown.get_item_metadata(selected_idx)
	if not meta:
		return

	_pending_food_item = meta
	_pending_food_owner = player_name

	# Populate modal
	var current_buff = str(Global.Current_Party.get("Active_Food_Buff", "None"))
	if current_buff == "" or current_buff == "null":
		current_buff = "None"
	_modal_current_buff_label.text = current_buff
	_modal_new_buff_label.text = str(meta.get("item_name", ""))

	_modal_overlay.visible = true


func _on_modal_cancel() -> void:
	_modal_overlay.visible = false
	_pending_food_item = {}
	_pending_food_owner = ""


func _on_modal_apply() -> void:
	_modal_overlay.visible = false
	if _pending_food_item.is_empty():
		return

	var item_name = _pending_food_item.get("item_name", "")
	var item_id = _pending_food_item.get("item_id", "")
	var qty = int(_pending_food_item.get("quantity", 0))

	# Look up buff duration from ITEMS definition, default to 3
	var buff_duration = 3
	for it in Global.ITEMS.values():
		if it.get("Item", "") == item_name:
			var bd = int(it.get("Buff_Duration", 3))
			if bd > 0:
				buff_duration = bd
			break

	var party_id = int(Global.Current_Party.get("id", 0))
	var updates: Array = [
		{"table": "Party", "record_id": party_id, "field": "Active_Food_Buff", "value": item_name},
		{"table": "Party", "record_id": party_id, "field": "Buff_Battles_Left", "value": buff_duration},
	]
	# Decrement quantity
	if item_id != "":
		var new_qty = max(qty - 1, 0)
		updates.append({
			"table": "Character_Items",
			"record_id": int(item_id),
			"field": "Quantity",
			"value": new_qty,
		})
	Global.Update_Records(updates)

	# Refresh dropdown for this player
	var dropdown = _consumable_dropdowns.get(_pending_food_owner)
	if dropdown:
		_populate_consumable_dropdown(dropdown, _pending_food_owner)
		var confirm_btn = _confirm_buttons.get(_pending_food_owner)
		if confirm_btn:
			confirm_btn.disabled = true

	_pending_food_item = {}
	_pending_food_owner = ""
	_populate_food_buff()


# =============================================================================
# READY LOGIC
# =============================================================================

func _on_ready_toggled(player_name: String, btn: Button) -> void:
	var pid = Global.CHARACTERS_NAME.get(player_name, "")
	if pid == "":
		return
	var new_val = btn.button_pressed
	_style_ready_button(btn)
	var updates = [{
		"table": "Characters",
		"record_id": int(pid),
		"field": "Ready",
		"value": new_val,
	}]
	Global.Update_Records(updates)
	_update_ready_badge()


func _refresh_ready_states() -> void:
	for player_name in _ready_toggles:
		var btn: Button = _ready_toggles[player_name]
		var pid = Global.CHARACTERS_NAME.get(player_name, "")
		var pdata = Global.CHARACTERS.get(pid, {})
		var is_ready = pdata.get("Ready", false) == true
		btn.set_pressed_no_signal(is_ready)
		_style_ready_button(btn)


func _update_ready_badge() -> void:
	if _ready_badge_label == null:
		return
	var total = Global.PartyCharacters.size()
	var ready_count = 0
	for player_name in Global.PartyCharacters:
		var pid = Global.CHARACTERS_NAME.get(player_name, "")
		var pdata = Global.CHARACTERS.get(pid, {})
		if pdata.get("Ready", false) == true:
			ready_count += 1
	_ready_badge_label.text = str(ready_count) + "/" + str(total) + " Ready"


# =============================================================================
# HELPERS
# =============================================================================

func _get_equipped_weapon_type(player_name: String) -> String:
	for w in Global.CHARACTER_WEAPONS.values():
		if w.get("Owner", "") == player_name and w.get("Equipped", false) == true:
			return str(w.get("Type", "Unknown"))
	return "No Weapon"


func _get_active_companions(player_name: String) -> Array:
	var result: Array = []
	for cid in Global.COMPANIONS:
		var c: Dictionary = Global.COMPANIONS[cid]
		if c.get("Owner", "") == player_name and c.get("Active", false) == true:
			result.append(c)
	return result


# =============================================================================
# STYLING
# =============================================================================

func _style_ready_button(btn: Button) -> void:
	var sb_normal = StyleBoxFlat.new()
	sb_normal.corner_radius_top_left = 4
	sb_normal.corner_radius_top_right = 4
	sb_normal.corner_radius_bottom_left = 4
	sb_normal.corner_radius_bottom_right = 4
	sb_normal.content_margin_left = 10
	sb_normal.content_margin_right = 10
	sb_normal.content_margin_top = 4
	sb_normal.content_margin_bottom = 4

	if btn.button_pressed:
		sb_normal.bg_color = Color("1a3d1a")
		sb_normal.border_width_bottom = 2
		sb_normal.border_width_top = 2
		sb_normal.border_width_left = 2
		sb_normal.border_width_right = 2
		sb_normal.border_color = GREEN_COLOR
		btn.add_theme_color_override("font_color", GREEN_COLOR)
		btn.add_theme_color_override("font_hover_color", GREEN_COLOR)
		btn.add_theme_color_override("font_pressed_color", GREEN_COLOR)
	else:
		sb_normal.bg_color = CARD_COLOR
		sb_normal.border_width_bottom = 1
		sb_normal.border_width_top = 1
		sb_normal.border_width_left = 1
		sb_normal.border_width_right = 1
		sb_normal.border_color = CARD_BORDER
		btn.add_theme_color_override("font_color", TEXT_DIM)
		btn.add_theme_color_override("font_hover_color", TEXT_COLOR)
		btn.add_theme_color_override("font_pressed_color", GREEN_COLOR)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_normal)
	btn.add_theme_stylebox_override("pressed", sb_normal)
	btn.add_theme_font_size_override("font_size", FONT_SIZE)


func _style_button(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD_COLOR
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_width_bottom = 1
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = CARD_BORDER
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color("2a3f55")
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)

	var sb_disabled = sb.duplicate()
	sb_disabled.bg_color = Color("151a24")
	sb_disabled.border_color = Color("1e2838")
	btn.add_theme_stylebox_override("disabled", sb_disabled)

	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", ACCENT_GOLD)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)
	btn.add_theme_font_size_override("font_size", FONT_SIZE)


func _style_button_accent(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("1a3d1a")
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = GREEN_COLOR
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color("255a25")
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)

	btn.add_theme_color_override("font_color", GREEN_COLOR)
	btn.add_theme_color_override("font_hover_color", Color("66ff88"))
	btn.add_theme_font_size_override("font_size", FONT_SIZE)
