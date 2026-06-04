extends Control

# ── Theme constants ───────────────────────────────────────────────────────────
const BG_DEEP   = Color(0.039, 0.051, 0.075)
const BG_PANEL  = Color(0.071, 0.086, 0.118)
const BG_CARD   = Color(0.102, 0.122, 0.169)
const BG_INSET  = Color(0.055, 0.067, 0.098)
const BG_HOVER  = Color(0.133, 0.157, 0.22)
const BORDER    = Color(0.165, 0.188, 0.251)
const TEXT_PRI  = Color(0.941, 0.949, 0.973)
const TEXT_SEC  = Color(0.69, 0.722, 0.8)
const TEXT_MUT  = Color(0.533, 0.573, 0.659)
const ACCENT    = Color(0.788, 0.659, 0.298)
const GREEN     = Color(0.292, 0.855, 0.498)

const SIDEBAR_W = 260
const FONT_SM   = 40
const FONT_MD   = 48
const FONT_LG   = 56
const FONT_XL   = 64

const ELEMENT_COLORS = {
	"Wind": Color("b4fcd4"),
	"Earth": Color("f4d563"),
	"Electric": Color("d092fc"),
	"Nature": Color("b1ea29"),
	"Water": Color("00c0fe"),
	"Fire": Color("ffa971"),
	"Nod Krai": Color("252525"),
	"Ice": Color("ccffff"),
}

const CONSTELLATION_COLORS = {
	"Weak": Color("e0e0e0"),
	"Medium": Color("4374b6"),
	"Strong": Color("fdd22e"),
}

# ── State ─────────────────────────────────────────────────────────────────────
var _current_tab = 0  # 0=Abilities, 1=Constellations, 2=Talents
var _constellation_sub = "Weak"
var _portrait_grid_visible = false
var _tab_buttons: Array[Button] = []
var _right_content: VBoxContainer
var _portrait_rect: TextureRect
var _portrait_grid_container: Control
var _stats_container: VBoxContainer

## Optional override. When set (non-empty) the profile renders the named
## party member's data instead of the active user's. Set by _open_ally_modal
## immediately after instantiate(), before add_child triggers _ready.
var target_name: String = ""

func _viewing_name() -> String:
	return target_name if target_name != "" else Global.ACTIVE_USER_NAME

func _viewing_record_id() -> int:
	if target_name == "":
		return Global.ACTIVE_USER_RECORD_ID
	return _get_record_id_for(target_name)

func _is_ally_view() -> bool:
	return target_name != "" and target_name != Global.ACTIVE_USER_NAME

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()


func _close() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()


# ═════════════════════════════════════════════════════════════════════════════
#  BUILD UI
# ═════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# Full-screen dark overlay
	var bg = ColorRect.new()
	bg.color = BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main HBox
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.set("theme_override_constants/separation", 0)
	add_child(hbox)

	# ── LEFT SIDEBAR ──────────────────────────────────────────────────────────
	var sidebar = _build_sidebar()
	hbox.add_child(sidebar)

	# Vertical divider
	var divider = ColorRect.new()
	divider.custom_minimum_size.x = 1
	divider.color = BORDER
	hbox.add_child(divider)

	# ── RIGHT PANEL ───────────────────────────────────────────────────────────
	var right = _build_right_panel()
	hbox.add_child(right)

	# ── EXIT BUTTON (added last so it renders on top of everything) ────────
	var exit_btn = Button.new()
	exit_btn.text = "Close"
	exit_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	exit_btn.offset_left = -100
	exit_btn.offset_top = 10
	exit_btn.offset_right = -10
	exit_btn.offset_bottom = 44
	exit_btn.z_index = 10
	_style_button(exit_btn, Color(0.6, 0.2, 0.2))
	exit_btn.add_theme_font_size_override("font_size", 25)
	exit_btn.add_theme_color_override("font_color", Color(0.95, 0.6, 0.6))
	exit_btn.pressed.connect(_close)
	add_child(exit_btn)


# ═════════════════════════════════════════════════════════════════════════════
#  LEFT SIDEBAR
# ═════════════════════════════════════════════════════════════════════════════
func _build_sidebar() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = SIDEBAR_W
	panel.size_flags_horizontal = Control.SIZE_FILL
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	panel.add_theme_stylebox_override("panel", sb)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.set("theme_override_constants/separation", 12)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_child(vbox)
	scroll.add_child(margin)

	var char_data = _get_character_data_for(_viewing_name())

	# Portrait
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(120, 120)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	_portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var portrait_val: String = str(char_data.get("Portrait", ""))
	if portrait_val != "":
		var portrait_path = "res://UI/Emotes/%s" % portrait_val
		if ResourceLoader.exists(portrait_path):
			_portrait_rect.texture = load(portrait_path)
	var portrait_btn = Button.new()
	portrait_btn.flat = true
	portrait_btn.custom_minimum_size = Vector2(120, 120)
	portrait_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_btn.pressed.connect(_toggle_portrait_grid)
	var portrait_stack = Control.new()
	portrait_stack.custom_minimum_size = Vector2(120, 120)
	portrait_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_stack.add_child(_portrait_rect)
	portrait_stack.add_child(portrait_btn)
	vbox.add_child(portrait_stack)

	# Name
	var name_label = _make_label(char_data.get("Name", "Unknown"), FONT_XL, TEXT_PRI)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level
	var level_label = _make_label("Level %s" % str(char_data.get("Level", "?")), FONT_MD, TEXT_SEC)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	# Element + Weapon badges
	var badge_row = HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.set("theme_override_constants/separation", 8)
	var element: String = char_data.get("Element", "")
	if element != "":
		badge_row.add_child(_make_badge(element, ELEMENT_COLORS.get(element, TEXT_SEC)))
	var weapon_type = _get_equipped_weapon_type_for(_viewing_name())
	if weapon_type != "":
		badge_row.add_child(_make_badge(weapon_type, TEXT_SEC))
	vbox.add_child(badge_row)

	# Change Portrait button — hidden in ally view (can't edit someone else's portrait)
	if not _is_ally_view():
		var change_btn = Button.new()
		change_btn.text = "Change Portrait"
		change_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(change_btn, BG_CARD)
		change_btn.add_theme_font_size_override("font_size", FONT_SM)
		change_btn.pressed.connect(_toggle_portrait_grid)
		vbox.add_child(change_btn)

		# Portrait grid (hidden initially)
		_portrait_grid_container = VBoxContainer.new()
		_portrait_grid_container.visible = false
		_portrait_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_build_portrait_grid(_portrait_grid_container)
		vbox.add_child(_portrait_grid_container)

	# Separator
	vbox.add_child(_make_separator())

	# Quick Stats
	var stats_title = _make_label("Quick Stats", FONT_MD, ACCENT)
	vbox.add_child(stats_title)
	_stats_container = VBoxContainer.new()
	_stats_container.set("theme_override_constants/separation", 4)
	_populate_stats(_stats_container)
	vbox.add_child(_stats_container)

	# Party Members list — only on the active user's own profile, to avoid
	# nested-window recursion and unnecessary noise on the ally view.
	if not _is_ally_view():
		vbox.add_child(_make_separator())
		var party_title = _make_label("View Party Member Kits", FONT_MD, ACCENT)
		vbox.add_child(party_title)
		for member_name in Global.PartyCharacters:
			if member_name == Global.ACTIVE_USER_NAME:
				continue
			var btn = Button.new()
			btn.text = member_name
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_button(btn, BG_CARD)
			btn.add_theme_font_size_override("font_size", FONT_SM)
			btn.pressed.connect(_open_ally_modal.bind(member_name))
			vbox.add_child(btn)

	return panel


# ═════════════════════════════════════════════════════════════════════════════
#  RIGHT PANEL
# ═════════════════════════════════════════════════════════════════════════════
func _build_right_panel() -> VBoxContainer:
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.set("theme_override_constants/separation", 0)

	# Tab bar
	var tab_bar = HBoxContainer.new()
	tab_bar.set("theme_override_constants/separation", 0)
	var tab_bg = PanelContainer.new()
	tab_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tab_sb = StyleBoxFlat.new()
	tab_sb.bg_color = BG_INSET
	tab_sb.content_margin_left = 8
	tab_sb.content_margin_right = 100  # leave space for Close button
	tab_sb.content_margin_top = 6
	tab_sb.content_margin_bottom = 6
	tab_bg.add_theme_stylebox_override("panel", tab_sb)
	tab_bg.add_child(tab_bar)
	right.add_child(tab_bg)

	var tabs = ["My Abilities", "Constellations", "Talents"]
	_tab_buttons.clear()
	for i in tabs.size():
		var btn = Button.new()
		btn.text = tabs[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == _current_tab)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", FONT_MD)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_style_tab_button(btn, i == _current_tab)
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	# Content area
	_right_content = VBoxContainer.new()
	_right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_right_content)

	_refresh_right_content()
	return right


func _on_tab_pressed(idx: int) -> void:
	_current_tab = idx
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == idx)
		_style_tab_button(_tab_buttons[i], i == idx)
	_refresh_right_content()


func _refresh_right_content() -> void:
	for c in _right_content.get_children():
		c.queue_free()
	match _current_tab:
		0: _build_abilities_tab(_right_content, _viewing_name(), _viewing_record_id())
		1: _build_constellations_tab(_right_content, _viewing_name())
		2: _build_talents_tab(_right_content, _viewing_name())


# ═════════════════════════════════════════════════════════════════════════════
#  ABILITIES TAB
# ═════════════════════════════════════════════════════════════════════════════
func _build_abilities_tab(parent: Control, player_name: String, record_id: int) -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.set("theme_override_constants/h_separation", 12)
	grid.set("theme_override_constants/v_separation", 12)
	margin.add_child(grid)

	# Determine equipped weapon type and character element
	var weapon_type = _get_equipped_weapon_type_for(player_name)
	var char_element = _get_character_element(player_name)

	# Collect active abilities for this character
	var ability_order = ["Basic Attack", "Charged Attack", "Skill", "Burst", "Passive"]
	var sorted_abilities: Array[Dictionary] = []

	for ab in Global.ACTIVE_ABILITIES.values():
		var eid = ab.get("Entity_ID")
		if eid == null:
			continue
		if int(eid) != record_id or ab.get("Entity_Type") != "Character":
			continue
		if ab.get("Element") != char_element:
			continue
		if ab.get("Weapon_Type") != weapon_type:
			continue
		var aid = ab.get("Ability_ID")
		if aid == null:
			continue
		var ability_data: Dictionary = Global.ABILITIES.get(str(int(aid)), {})
		if ability_data.is_empty():
			continue
		var merged = {}
		merged.merge(ability_data)
		merged["Ability_Type"] = ab.get("Ability_Type", "")
		sorted_abilities.append(merged)

	# Sort by ability_order
	sorted_abilities.sort_custom(func(a, b):
		var ai = ability_order.find(a.get("Ability_Type", ""))
		var bi = ability_order.find(b.get("Ability_Type", ""))
		if ai == -1: ai = 99
		if bi == -1: bi = 99
		return ai < bi
	)

	if sorted_abilities.is_empty():
		var empty = _make_label("No abilities found for %s %s." % [char_element, weapon_type], FONT_MD, TEXT_MUT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		grid.add_child(empty)
		return

	for ab_data in sorted_abilities:
		var card = _build_ability_card(ab_data)
		grid.add_child(card)


func _build_ability_card(data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_CARD
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 6)
	card.add_child(vbox)

	# Header row: name + type badge
	var header = HBoxContainer.new()
	header.set("theme_override_constants/separation", 8)
	var ab_name: String = data.get("name", "Unknown")
	header.add_child(_make_label(ab_name, FONT_LG, TEXT_PRI))
	var ab_type: String = data.get("Ability_Type", "")
	if ab_type != "":
		header.add_child(_make_badge(ab_type, ACCENT))
	vbox.add_child(header)

	# Stats row
	var stats_row = HBoxContainer.new()
	stats_row.set("theme_override_constants/separation", 16)

	var cd = data.get("cooldown", 0)
	if cd != null and int(cd) > 0:
		stats_row.add_child(_make_stat_pair("CD", str(cd)))
	var charge = data.get("charge_cost", 0)
	if charge != null and int(charge) > 0:
		stats_row.add_child(_make_stat_pair("Charge", str(charge)))
	var dice_count = data.get("dice_count", 0)
	var dice_die = data.get("dice_die", 0)
	if dice_count != null and dice_die != null and int(dice_count) > 0:
		var dice_str = "%dd%d" % [int(dice_count), int(dice_die)]
		var dice_flat = data.get("dice_flat", 0)
		if dice_flat != null and int(dice_flat) != 0:
			dice_str += "+%d" % int(dice_flat)
		stats_row.add_child(_make_stat_pair("Dice", dice_str))
	var rng = data.get("targeting_length", 0)
	if rng != null and int(rng) > 0:
		stats_row.add_child(_make_stat_pair("Range", str(rng)))
	var mvmt = data.get("movement", 0)
	if mvmt != null and int(mvmt) > 0:
		stats_row.add_child(_make_stat_pair("Move", str(mvmt)))
	if stats_row.get_child_count() > 0:
		vbox.add_child(stats_row)

	# Description
	var desc_text: String = data.get("description", "")
	if desc_text != "":
		var desc = RichTextLabel.new()
		desc.bbcode_enabled = true
		desc.fit_content = true
		desc.scroll_active = false
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.add_theme_font_size_override("normal_font_size", FONT_SM)
		desc.add_theme_color_override("default_color", TEXT_SEC)
		desc.text = System.db_richtext_to_bbcode(desc_text)
		vbox.add_child(desc)

	return card


# ═════════════════════════════════════════════════════════════════════════════
#  CONSTELLATIONS TAB
# ═════════════════════════════════════════════════════════════════════════════
func _build_constellations_tab(parent: Control, player_name: String) -> void:
	var outer = VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.set("theme_override_constants/separation", 0)
	parent.add_child(outer)

	# Sub-tab bar: Weak / Medium / Strong
	var sub_bar = HBoxContainer.new()
	sub_bar.set("theme_override_constants/separation", 0)
	var sub_bg = PanelContainer.new()
	sub_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sub_sb = StyleBoxFlat.new()
	sub_sb.bg_color = BG_INSET
	sub_sb.content_margin_left = 16
	sub_sb.content_margin_right = 16
	sub_sb.content_margin_top = 4
	sub_sb.content_margin_bottom = 4
	sub_bg.add_theme_stylebox_override("panel", sub_sb)
	sub_bg.add_child(sub_bar)
	outer.add_child(sub_bg)

	# Content container that gets rebuilt when tier changes
	var content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(content_container)

	var active_tier = {"value": _constellation_sub}
	var sub_buttons: Array[Button] = []

	# Function to rebuild content for a given tier
	var rebuild_content = func():
		for c in content_container.get_children():
			c.queue_free()
		_populate_constellation_content(content_container, player_name, active_tier["value"])

	for tier in ["Weak", "Medium", "Strong"]:
		var btn = Button.new()
		btn.text = tier
		btn.toggle_mode = true
		btn.button_pressed = (tier == _constellation_sub)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", FONT_SM)
		var tier_color = CONSTELLATION_COLORS.get(tier, TEXT_SEC)
		_style_button(btn, BG_CARD if tier != _constellation_sub else BG_HOVER)
		btn.add_theme_color_override("font_color", tier_color)
		btn.pressed.connect(func():
			active_tier["value"] = tier
			_constellation_sub = tier
			for b in sub_buttons:
				b.button_pressed = (b.text == tier)
				_style_button(b, BG_HOVER if b.text == tier else BG_CARD)
			rebuild_content.call()
		)
		sub_bar.add_child(btn)
		sub_buttons.append(btn)

	# Build initial content
	_populate_constellation_content(content_container, player_name, active_tier["value"])


func _populate_constellation_content(container: Control, player_name: String, tier: String) -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.set("theme_override_constants/separation", 10)
	margin.add_child(vbox)

	var found = false
	for constellation in Global.CONSTELLATIONS.values():
		if constellation.get("Name") != player_name:
			continue
		if constellation.get("Tier") != tier:
			continue
		found = true
		var card = _build_constellation_card(constellation)
		vbox.add_child(card)

	if not found:
		vbox.add_child(_make_label("No %s constellations." % tier, FONT_MD, TEXT_MUT))


func _build_constellation_card(data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_CARD
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 6)
	card.add_child(vbox)

	# Header: name + unlocked badge
	var header = HBoxContainer.new()
	header.set("theme_override_constants/separation", 8)
	var c_name: String = data.get("Constellation", "Unknown")
	# Use first line or truncated text as title
	var title_text = c_name.get_slice("\n", 0).strip_edges()
	if title_text.length() > 60:
		title_text = title_text.left(57) + "..."
	header.add_child(_make_label(data.get("Tier", ""), FONT_MD, CONSTELLATION_COLORS.get(data.get("Tier", ""), TEXT_SEC)))
	var chosen_val = data.get("Chosen", false)
	var chosen = (chosen_val == true or str(chosen_val).to_lower() == "true")
	if chosen:
		header.add_child(_make_badge("Unlocked", GREEN))
	else:
		header.add_child(_make_badge("Locked", TEXT_MUT))
	vbox.add_child(header)

	# Description
	var desc = RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("normal_font_size", FONT_SM)
	desc.add_theme_color_override("default_color", TEXT_SEC)
	desc.text = System.db_richtext_to_bbcode(c_name)
	vbox.add_child(desc)

	return card


# ═════════════════════════════════════════════════════════════════════════════
#  TALENTS TAB
# ═════════════════════════════════════════════════════════════════════════════
func _build_talents_tab(parent: Control, player_name: String) -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.set("theme_override_constants/separation", 10)
	margin.add_child(vbox)

	# Get player's current element to filter talents
	var player_element = ""
	var pid = Global.CHARACTERS_NAME.get(player_name, "")
	if pid != "":
		player_element = str(Global.CHARACTERS.get(pid, {}).get("Element", ""))

	var found = false
	for talent in Global.TALENTS.values():
		if talent.get("Name") != player_name:
			continue
		var talent_chosen = talent.get("Chosen", false)
		if not (talent_chosen == true or str(talent_chosen).to_lower() == "true"):
			continue
		# Only show talents matching the player's current element
		var talent_elem = str(talent.get("Element", ""))
		if player_element != "" and talent_elem != "" and talent_elem != player_element:
			continue
		found = true
		var card = _build_talent_card(talent)
		vbox.add_child(card)

	if not found:
		vbox.add_child(_make_label("No talents for current element.", FONT_MD, TEXT_MUT))


func _build_talent_card(data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_CARD
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 6)
	card.add_child(vbox)

	# Header: element badge
	var header = HBoxContainer.new()
	header.set("theme_override_constants/separation", 8)
	var elem: String = data.get("Element", "")
	if elem != "":
		header.add_child(_make_badge(elem, ELEMENT_COLORS.get(elem, TEXT_SEC)))
	vbox.add_child(header)

	# Description
	var talent_text: String = data.get("Talent", "")
	if talent_text != "":
		var desc = RichTextLabel.new()
		desc.bbcode_enabled = true
		desc.fit_content = true
		desc.scroll_active = false
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.add_theme_font_size_override("normal_font_size", FONT_SM)
		desc.add_theme_color_override("default_color", TEXT_SEC)
		desc.text = System.db_richtext_to_bbcode(talent_text)
		vbox.add_child(desc)

	return card


# ═════════════════════════════════════════════════════════════════════════════
#  PORTRAIT GRID
# ═════════════════════════════════════════════════════════════════════════════
func _toggle_portrait_grid() -> void:
	# Open as a centered popup overlay with large thumbnails
	var overlay = ColorRect.new()
	overlay.name = "PortraitOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 20
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 12)
	panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)
	header.add_child(_make_label("Choose Portrait", FONT_LG, ACCENT))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_btn = Button.new()
	close_btn.text = "Cancel"
	_style_button(close_btn, BG_CARD)
	close_btn.pressed.connect(func(): overlay.queue_free())
	header.add_child(close_btn)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.set("theme_override_constants/h_separation", 10)
	grid.set("theme_override_constants/v_separation", 10)
	scroll.add_child(grid)

	var dir = DirAccess.open("res://UI/Emotes/")
	if dir == null:
		grid.add_child(_make_label("No portraits found.", FONT_MD, TEXT_MUT))
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg")) and not file_name.ends_with(".import"):
			var full_path = "res://UI/Emotes/" + file_name
			if ResourceLoader.exists(full_path):
				var tex = load(full_path) as Texture2D
				if tex:
					var btn = TextureButton.new()
					btn.texture_normal = tex
					btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
					btn.ignore_texture_size = true
					btn.custom_minimum_size = Vector2(96, 96)
					btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					btn.pressed.connect(func():
						_on_portrait_selected(full_path)
						overlay.queue_free()
					)
					grid.add_child(btn)
		file_name = dir.get_next()
	dir.list_dir_end()


func _build_portrait_grid(container: Control) -> void:
	# Placeholder — actual grid is built in popup overlay
	pass


func _on_portrait_selected(path: String) -> void:
	# Update portrait texture
	if ResourceLoader.exists(path):
		_portrait_rect.texture = load(path)

	# Save just the filename (e.g. "BrianF.png"), not the full path
	var filename = path.get_file()
	var char_data = _get_my_character_data()
	var record_id = char_data.get("id", 0)
	if record_id != 0:
		Global.Update_Records([{
			"table": "Characters",
			"record_id": int(record_id),
			"field": "Portrait",
			"value": filename
		}])

	# Hide the grid
	_portrait_grid_visible = false
	_portrait_grid_container.visible = false


# ═════════════════════════════════════════════════════════════════════════════
#  ALLY KIT VIEW
# ═════════════════════════════════════════════════════════════════════════════
## Open the ally's profile in its own fullscreen Window, using the same scene
## as the active user's profile but with target_name set to the ally. Mirrors
## the Window-wrapping pattern in player_hub._open_character_profile so the
## ally view gets the same layout, close button, and tab content as the
## first-person view.
func _open_ally_modal(ally_name: String) -> void:
	var s: PackedScene = preload("res://Scenes/character_profile.tscn")
	var dlg = s.instantiate()
	# Set target BEFORE add_child so _ready() sees it during _build_ui().
	dlg.target_name = ally_name
	var win := Window.new()
	win.title = ally_name
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO
	win.close_requested.connect(func(): win.queue_free())
	win.add_child(dlg)
	add_child(win)
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)


# ═════════════════════════════════════════════════════════════════════════════
#  DATA HELPERS
# ═════════════════════════════════════════════════════════════════════════════
func _get_my_character_data() -> Dictionary:
	return _get_character_data_for(Global.ACTIVE_USER_NAME)


func _get_character_data_for(player_name: String) -> Dictionary:
	var char_id_str: String = Global.CHARACTERS_NAME.get(player_name, "")
	if char_id_str != "":
		return Global.CHARACTERS.get(char_id_str, {})
	# Fallback: search by name
	for c in Global.CHARACTERS.values():
		if c.get("Name") == player_name:
			return c
	return {}


func _get_record_id_for(player_name: String) -> int:
	var data = _get_character_data_for(player_name)
	var rid = data.get("id", 0)
	return int(rid) if rid != null else 0


func _get_character_element(player_name: String) -> String:
	return _get_character_data_for(player_name).get("Element", "")


func _get_equipped_weapon_type() -> String:
	return _get_equipped_weapon_type_for(Global.ACTIVE_USER_NAME)


func _get_equipped_weapon_type_for(player_name: String) -> String:
	for weapon in Global.CHARACTER_WEAPONS.values():
		if weapon.get("Owner") == player_name and weapon.get("Equipped") == true:
			return weapon.get("Type", "")
	return ""


func _populate_stats(container: VBoxContainer) -> void:
	var stats = CharacterManager.get_stats(_viewing_name())
	if stats == null:
		container.add_child(_make_label("No stats available.", FONT_SM, TEXT_MUT))
		return

	var pairs = [
		["HP", "%.0f" % stats.health],
		["ATK", "%.0f" % stats.attack],
		["DEF", "%.0f" % stats.defense],
		["EM", "%.0f" % stats.elemental_mastery],
		["Crit DMG", "%.0f%%" % (stats.critical_damage * 100.0)],
		["ER", "%.0f%%" % (stats.energy_recharge * 100.0)],
	]
	for pair in pairs:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_make_label(pair[0], FONT_SM, TEXT_MUT))
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		row.add_child(_make_label(pair[1], FONT_SM, TEXT_PRI))
		container.add_child(row)


# ═════════════════════════════════════════════════════════════════════════════
#  UI HELPERS
# ═════════════════════════════════════════════════════════════════════════════
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_badge(text: String, color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.2)
	sb.border_color = Color(color, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", sb)

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_SM)
	lbl.add_theme_color_override("font_color", color)
	panel.add_child(lbl)
	return panel


func _make_stat_pair(label_text: String, value_text: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.set("theme_override_constants/separation", 4)
	hbox.add_child(_make_label(label_text + ":", FONT_SM, TEXT_MUT))
	hbox.add_child(_make_label(value_text, FONT_SM, TEXT_PRI))
	return hbox


func _make_separator() -> ColorRect:
	var sep = ColorRect.new()
	sep.color = BORDER
	sep.custom_minimum_size.y = 1
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sep


func _style_button(btn: Button, bg_color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.set_corner_radius_all(4)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = bg_color.lightened(0.25)
	pressed.set_corner_radius_all(4)
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	pressed.content_margin_top = 6
	pressed.content_margin_bottom = 6
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", TEXT_PRI)
	btn.add_theme_color_override("font_hover_color", TEXT_PRI)
	btn.add_theme_color_override("font_pressed_color", TEXT_PRI)


func _style_tab_button(btn: Button, active: bool) -> void:
	var bg = BG_CARD if active else BG_INSET
	_style_button(btn, bg)
	if active:
		var sb: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if sb:
			sb.border_color = ACCENT
			sb.border_width_bottom = 2
	btn.add_theme_color_override("font_color", TEXT_PRI if active else TEXT_MUT)
	btn.add_theme_color_override("font_hover_color", TEXT_PRI)
