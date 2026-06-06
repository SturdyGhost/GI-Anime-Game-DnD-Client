extends Control

# =============================================================================
#  Preloads
# =============================================================================

# Target rows are now built programmatically (no external scene needed)

# =============================================================================
#  Theme Colors
# =============================================================================

const BG_DEEP = Color(0.039, 0.051, 0.075)
const BG_PANEL = Color(0.071, 0.086, 0.118)
const BG_CARD = Color(0.102, 0.122, 0.169)
const BORDER_SUBTLE = Color(0.165, 0.188, 0.251)
const TEXT_PRIMARY = Color(0.941, 0.949, 0.973)
const TEXT_SECONDARY = Color(0.69, 0.722, 0.8)
const TEXT_MUTED = Color(0.533, 0.573, 0.659)
const ACCENT = Color(0.788, 0.659, 0.298)
const COL_CURRENT = Color(0.886, 0.761, 0.564, 0.28)
const COL_NEXT = Color(0.545, 0.827, 0.867, 0.18)

# =============================================================================
#  Node References (set in _build_ui)
# =============================================================================

var _background: TextureRect
var _turn_list: ItemList
var _round_label: Label
var _turn_badge: Label
var _enemy_grid: HFlowContainer
var _action_dock: PanelContainer
var _attack_select: OptionButton
var _target_list: ItemList
var _results_container: VBoxContainer
var _attack_roll_spin: SpinBox
var _tiles_moved_spin: SpinBox
var _burst_gained_spin: SpinBox
var _passive_stacks_spin: SpinBox
var _crit_toggle: CheckButton
var _item_select: OptionButton
var _item_desc: Label
var _item_target_select: OptionButton
var _food_buff_label: Label
var _burst_count_label: Label
var _end_turn_btn: Button
var _party_list: VBoxContainer
var _stun_overlay: ColorRect
var _stun_title: Label
var _stun_text: Label
var _stun_btn: Button
var _audio: AudioStreamPlayer
var _ability_info_box: HFlowContainer
var _attack_tab: VBoxContainer
var _effects_tab: VBoxContainer
var _stats_tab: VBoxContainer
var _tab_btn_attack: Button
var _tab_btn_effects: Button
var _tab_btn_stats: Button
var _my_stats_container: VBoxContainer
var _my_effects_container: VBoxContainer
var _center_split: VSplitContainer
var _outer_split: HSplitContainer
var _inner_split: HSplitContainer
var _party_split: VSplitContainer
var _info_split: VSplitContainer
var _dock_split: VSplitContainer
var _attack_hsplit_l: HSplitContainer
var _attack_hsplit_r: HSplitContainer
var _target_vsplit: VSplitContainer

const LAYOUT_SAVE_PATH = "user://battle_layout.cfg"

# =============================================================================
#  State
# =============================================================================

var Original_Order: Array = []
var Current_Turn = null
var Turn_Type: String = ""
var battle_id = null
var turn_no: int = 0
var music_files: Array = []
var music_index: int = -1
var _battle_ending = false
var _battle_logger: BattleLogger = null
var _last_logged_turn: String = ""
var _battle_ending_summary_shown: bool = false

# Focus alert state
var _focus_alert_pending: bool = false
var _focus_alert_turn: String = ""
var _focus_alert_mouse_pos: Vector2 = Vector2.ZERO


# =============================================================================
#  Lifecycle
# =============================================================================

func _ready():
	_build_ui()
	_apply_tooltip_theme()

	# Host-authoritative turn resolution: the host's NetworkManager finds this
	# scene via the group to run client-submitted turns (request_process_turn).
	add_to_group("battle_scene")

	# Connect signals
	Global.connect("data_load_complete", _on_data_load_complete)
	tree_exiting.connect(_disconnect_signals)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_stun_btn.pressed.connect(_on_stun_confirm)
	# multi_selected fires for shift+click range; gui_input handles single left-click toggle
	_target_list.multi_selected.connect(_on_target_multi_selected)
	_target_list.gui_input.connect(_on_target_list_input)
	_tab_btn_attack.pressed.connect(func(): _switch_tab("attack"))
	_tab_btn_effects.pressed.connect(func(): _switch_tab("effects"))
	_tab_btn_stats.pressed.connect(func(): _switch_tab("stats"))
	_item_select.item_selected.connect(_on_item_selected)
	_audio.finished.connect(_on_audio_finished)
	if NetworkManager.is_host:
		NetworkManager.combat_log_received.connect(_on_combat_log_received)
	else:
		NetworkManager.damage_breakdown_received.connect(_on_damage_breakdown_received)
		NetworkManager.battle_summary_received.connect(_on_battle_summary_received)
		# Client shell: render the host's authoritative battle view from broadcasts,
		# and ask for a fresh snapshot now that we've entered the scene.
		NetworkManager.battle_state_received.connect(_on_battle_state_received)
		NetworkManager.request_battle_state.rpc_id(1)

	# Connect split container dragged signals to save layout
	_outer_split.dragged.connect(func(_ofs): _save_layout())
	_inner_split.dragged.connect(func(_ofs): _save_layout())
	_center_split.dragged.connect(func(_ofs): _save_layout())
	_party_split.dragged.connect(func(_ofs): _save_layout())
	_info_split.dragged.connect(func(_ofs): _save_layout())
	_dock_split.dragged.connect(func(_ofs): _save_layout())
	_attack_hsplit_l.dragged.connect(func(_ofs): _save_layout())
	_attack_hsplit_r.dragged.connect(func(_ofs): _save_layout())
	_target_vsplit.dragged.connect(func(_ofs): _save_layout())

	# Restore saved layout (must happen after _build_ui and after a frame for sizing)
	_load_layout.call_deferred()

	# Setup
	_setup_turn_order()
	_build_battlers()
	_refresh_all()
	_update_dock_visibility()
	_set_background()
	_start_music()
	Toast.notify("Battle started", Toast.WARNING)


func _disconnect_signals():
	var h = Callable(self, "_on_data_load_complete")
	if Global.is_connected("data_load_complete", h):
		Global.disconnect("data_load_complete", h)
	if NetworkManager.combat_log_received.is_connected(_on_combat_log_received):
		NetworkManager.combat_log_received.disconnect(_on_combat_log_received)
	if NetworkManager.damage_breakdown_received.is_connected(_on_damage_breakdown_received):
		NetworkManager.damage_breakdown_received.disconnect(_on_damage_breakdown_received)
	if NetworkManager.battle_summary_received.is_connected(_on_battle_summary_received):
		NetworkManager.battle_summary_received.disconnect(_on_battle_summary_received)
	if NetworkManager.battle_state_received.is_connected(_on_battle_state_received):
		NetworkManager.battle_state_received.disconnect(_on_battle_state_received)
	# Leaving the battle: drop the authoritative view so non-battle screens fall
	# back to table-derived data.
	BattleManager.clear_state()


# =============================================================================
#  UI Construction Helpers
# =============================================================================

const BG_INSET = Color(0.055, 0.067, 0.098)
const BG_HOVER = Color(0.133, 0.157, 0.22)
const BORDER_FOCUS = Color(0.29, 0.435, 0.647)
const HP_GREEN = Color(0.133, 0.773, 0.369)

# ── Reusable style factories ──

func _sb(bg: Color, border = BORDER_SUBTLE, bw = 1, radius = 6, margins = Vector4(8, 4, 8, 4)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margins.x
	s.content_margin_top = margins.y
	s.content_margin_right = margins.z
	s.content_margin_bottom = margins.w
	return s

func _lbl(text: String, size: int = 14, color: Color = TEXT_PRIMARY, bold = false) -> Label:
	var l = Label.new()
	l.text = text
	var settings_script = preload("res://Scenes/settings_popup.gd")
	l.add_theme_font_size_override("font_size", settings_script.scaled_font(size))
	l.add_theme_color_override("font_color", color)
	return l

func _section_label(text: String) -> Label:
	var l = _lbl(text, 32, TEXT_MUTED)
	l.uppercase = true
	return l

func _style_button(btn: Button, bg = BG_CARD, border = BORDER_SUBTLE, text_color = TEXT_PRIMARY) -> void:
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _sb(bg, border, 1, 4, Vector4(12, 6, 12, 6)))
	btn.add_theme_stylebox_override("hover", _sb(BG_HOVER, BORDER_FOCUS, 1, 4, Vector4(12, 6, 12, 6)))
	btn.add_theme_stylebox_override("pressed", _sb(BG_INSET, ACCENT, 1, 4, Vector4(12, 6, 12, 6)))
	btn.add_theme_stylebox_override("focus", _sb(bg, BORDER_FOCUS, 1, 4, Vector4(12, 6, 12, 6)))
	btn.add_theme_stylebox_override("disabled", _sb(BG_INSET, BORDER_SUBTLE, 1, 4, Vector4(12, 6, 12, 6)))
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)

func _style_option(opt: OptionButton) -> void:
	# Don't let a long item name dictate the control's width. Fill the column
	# and clip the selected text with an ellipsis instead (full text on hover).
	opt.fit_to_longest_item = false
	opt.clip_text = true
	opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 40)
	opt.add_theme_color_override("font_color", TEXT_PRIMARY)
	opt.add_theme_stylebox_override("normal", _sb(BG_INSET, BORDER_SUBTLE, 1, 4, Vector4(8, 4, 8, 4)))
	opt.add_theme_stylebox_override("hover", _sb(BG_HOVER, BORDER_FOCUS, 1, 4, Vector4(8, 4, 8, 4)))
	opt.add_theme_stylebox_override("pressed", _sb(BG_INSET, ACCENT, 1, 4, Vector4(8, 4, 8, 4)))
	opt.add_theme_stylebox_override("focus", _sb(BG_INSET, BORDER_FOCUS, 1, 4, Vector4(8, 4, 8, 4)))

func _style_itemlist(il: ItemList) -> void:
	# Clip long entries with an ellipsis rather than growing the list's width.
	il.auto_width = false
	il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	il.add_theme_font_size_override("font_size", 40)
	il.add_theme_color_override("font_color", TEXT_PRIMARY)
	il.add_theme_color_override("font_selected_color", ACCENT)
	il.add_theme_stylebox_override("panel", _sb(BG_INSET, BORDER_SUBTLE, 1, 4, Vector4(4, 4, 4, 4)))
	il.add_theme_stylebox_override("selected", _sb(Color(0.102, 0.122, 0.169), ACCENT, 1, 2, Vector4(4, 2, 4, 2)))
	il.add_theme_stylebox_override("selected_focus", _sb(Color(0.102, 0.122, 0.169), ACCENT, 1, 2, Vector4(4, 2, 4, 2)))

func _make_spinbox(prefix_text: String, max_val: int = 100) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl = _lbl(prefix_text, 32, TEXT_SECONDARY)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var spin = SpinBox.new()
	spin.max_value = max_val
	spin.min_value = 0
	spin.value = 0
	spin.custom_minimum_size.x = 70
	spin.add_theme_font_size_override("font_size", 40)
	# Style the internal LineEdit
	var le_style = _sb(BG_INSET, BORDER_SUBTLE, 1, 4, Vector4(6, 2, 6, 2))
	spin.get_line_edit().add_theme_stylebox_override("normal", le_style)
	spin.get_line_edit().add_theme_stylebox_override("focus", _sb(BG_INSET, ACCENT, 1, 4, Vector4(6, 2, 6, 2)))
	spin.get_line_edit().add_theme_color_override("font_color", TEXT_PRIMARY)
	spin.get_line_edit().add_theme_font_size_override("font_size", 40)
	row.add_child(spin)
	return row

func _get_spin(row: HBoxContainer) -> SpinBox:
	for c in row.get_children():
		if c is SpinBox:
			return c
	return null

func _apply_tooltip_theme() -> void:
	var tt_panel = StyleBoxFlat.new()
	tt_panel.bg_color = Color(0.05, 0.06, 0.08, 0.97)
	tt_panel.border_color = Color(0.25, 0.28, 0.35)
	tt_panel.set_border_width_all(1)
	tt_panel.set_corner_radius_all(4)
	tt_panel.content_margin_left = 8
	tt_panel.content_margin_right = 8
	tt_panel.content_margin_top = 6
	tt_panel.content_margin_bottom = 6

	var t = Theme.new()
	t.set_stylebox("panel", "TooltipPanel", tt_panel)
	# Scale tooltip font with user's font scale setting (default 26 at 100%)
	var font_scale = 1.0
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		font_scale = cfg.get_value("ui", "font_scale", 100.0) / 100.0
	t.set_font_size("font_size", "TooltipLabel", int(26 * font_scale))
	t.set_color("font_color", "TooltipLabel", Color(0.88, 0.9, 0.95))
	self.theme = t


func _tab_button(text: String, is_active = false) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_color_override("font_color", ACCENT if is_active else TEXT_MUTED)
	btn.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	# Underline effect via bottom border
	var normal_sb = StyleBoxFlat.new()
	normal_sb.bg_color = Color.TRANSPARENT
	normal_sb.border_color = ACCENT if is_active else Color.TRANSPARENT
	normal_sb.border_width_bottom = 2 if is_active else 0
	normal_sb.content_margin_left = 16
	normal_sb.content_margin_right = 16
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", normal_sb)
	var hover_sb = normal_sb.duplicate()
	hover_sb.bg_color = BG_CARD
	btn.add_theme_stylebox_override("hover", hover_sb)
	return btn


# =============================================================================
#  _build_ui — Programmatic UI Construction
# =============================================================================

func _build_ui():
	# ── Background ──
	_background = TextureRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.modulate = Color(0.3, 0.3, 0.3, 0.4)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	# ── Deep background fill ──
	var bg_fill = ColorRect.new()
	bg_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_fill.color = BG_DEEP
	bg_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_fill)
	move_child(bg_fill, 0)

	# ── Main 3-column layout (resizable via HSplitContainers) ──
	_outer_split = HSplitContainer.new()
	_outer_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outer_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	add_child(_outer_split)

	# We nest two HSplitContainers: [Turn | [Center | Party]]
	# so both dividers are draggable
	var layout = _outer_split  # reference for turn panel

	# ═══════════════════════════════════════════════════════════
	#  LEFT: Turn Order (190px)
	# ═══════════════════════════════════════════════════════════
	var turn_panel = PanelContainer.new()
	turn_panel.custom_minimum_size.x = 190
	turn_panel.add_theme_stylebox_override("panel", _sb(BG_PANEL, BORDER_SUBTLE, 0, 0, Vector4(6, 4, 6, 4)))
	layout.add_child(turn_panel)

	var turn_vbox = VBoxContainer.new()
	turn_vbox.add_theme_constant_override("separation", 2)
	turn_panel.add_child(turn_vbox)

	var turn_header = HBoxContainer.new()
	turn_vbox.add_child(turn_header)
	var tt = _lbl("TURN ORDER", 13, TEXT_MUTED)
	tt.uppercase = true
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_header.add_child(tt)
	_round_label = _lbl("R1", 13, TEXT_MUTED)
	turn_header.add_child(_round_label)

	# Separator line
	var turn_sep = HSeparator.new()
	turn_sep.add_theme_stylebox_override("separator", _sb(BORDER_SUBTLE, Color.TRANSPARENT, 0, 0, Vector4(0, 1, 0, 1)))
	turn_vbox.add_child(turn_sep)

	_turn_list = ItemList.new()
	_turn_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_itemlist(_turn_list)
	_turn_list.add_theme_stylebox_override("panel", _sb(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, Vector4(2, 2, 2, 2)))
	turn_vbox.add_child(_turn_list)

	# DM Hub button (always visible, outside the action dock)
	if Global.ACTIVE_USER_TYPE == "Dungeon Master":
		var dm_btn = Button.new()
		dm_btn.text = "DM HUB"
		dm_btn.custom_minimum_size = Vector2(0, 30)
		dm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dm_normal = _sb(Color(0.4, 0.2, 0.6, 0.15), Color(0.6, 0.35, 0.85), 1, 6, Vector4(16, 6, 16, 6))
		dm_btn.add_theme_stylebox_override("normal", dm_normal)
		var dm_hover = _sb(Color(0.4, 0.2, 0.6, 0.3), Color(0.6, 0.35, 0.85), 1, 6, Vector4(16, 6, 16, 6))
		dm_btn.add_theme_stylebox_override("hover", dm_hover)
		dm_btn.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95))
		dm_btn.add_theme_font_size_override("font_size", 40)
		dm_btn.pressed.connect(_on_dm_hub_pressed)
		turn_vbox.add_child(dm_btn)

	# Inner split: center + party (second draggable divider)
	_inner_split = HSplitContainer.new()
	_inner_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	layout.add_child(_inner_split)

	# ═══════════════════════════════════════════════════════════
	#  CENTER: Enemies + Action Dock (resizable split)
	# ═══════════════════════════════════════════════════════════
	var center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	_inner_split.add_child(center)

	# ── Global bar (turn badge) ──
	var top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _sb(BG_PANEL, BORDER_SUBTLE, 0, 0, Vector4(12, 4, 12, 4)))
	center.add_child(top_bar)
	var top_sep = HSeparator.new()
	top_sep.add_theme_stylebox_override("separator", _sb(BORDER_SUBTLE, Color.TRANSPARENT, 0, 0, Vector4(0, 1, 0, 0)))
	center.add_child(top_sep)

	_turn_badge = _lbl("", 15, TEXT_PRIMARY)
	_turn_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(_turn_badge)

	# ── VSplitContainer: drag to resize enemy area vs action dock ──
	_center_split = VSplitContainer.new()
	_center_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	center.add_child(_center_split)

	# Top half: enemy arena
	var enemy_scroll = ScrollContainer.new()
	enemy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_center_split.add_child(enemy_scroll)

	var enemy_pad = MarginContainer.new()
	enemy_pad.add_theme_constant_override("margin_left", 12)
	enemy_pad.add_theme_constant_override("margin_right", 12)
	enemy_pad.add_theme_constant_override("margin_top", 8)
	enemy_pad.add_theme_constant_override("margin_bottom", 8)
	enemy_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_scroll.add_child(enemy_pad)

	_enemy_grid = HFlowContainer.new()
	_enemy_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_grid.add_theme_constant_override("h_separation", 8)
	_enemy_grid.add_theme_constant_override("v_separation", 8)
	enemy_pad.add_child(_enemy_grid)

	# Bottom half: action dock
	_action_dock = PanelContainer.new()
	_action_dock.add_theme_stylebox_override("panel", _sb(BG_PANEL, Color.TRANSPARENT, 0, 0, Vector4(8, 0, 8, 4)))
	_action_dock.visible = false
	_center_split.add_child(_action_dock)

	var dock_outer = VBoxContainer.new()
	dock_outer.add_theme_constant_override("separation", 2)
	_action_dock.add_child(dock_outer)

	# ── Dock tab bar (fixed at top, not in split) ──
	var dock_tabs = HBoxContainer.new()
	dock_tabs.add_theme_constant_override("separation", 0)
	dock_outer.add_child(dock_tabs)

	_tab_btn_attack = _tab_button("TURN ACTIONS", true)
	dock_tabs.add_child(_tab_btn_attack)
	_tab_btn_effects = _tab_button("EFFECTS")
	dock_tabs.add_child(_tab_btn_effects)
	_tab_btn_stats = _tab_button("STATS")
	dock_tabs.add_child(_tab_btn_stats)

	var tab_sep = HSeparator.new()
	tab_sep.add_theme_stylebox_override("separator", _sb(BORDER_SUBTLE, Color.TRANSPARENT, 0, 0, Vector4(0, 1, 0, 0)))
	dock_outer.add_child(tab_sep)

	# ── Dock body + bottom bar in a VSplit (resizable) ──
	_dock_split = VSplitContainer.new()
	_dock_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_dock_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_outer.add_child(_dock_split)

	# Top of split: scrollable content
	var dock_scroll = ScrollContainer.new()
	dock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_scroll.custom_minimum_size.y = 150
	_dock_split.add_child(dock_scroll)

	var dock_content = VBoxContainer.new()
	dock_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_scroll.add_child(dock_content)

	# ── ATTACK TAB (3-column HSplitContainer, all resizable) ──
	var attack_wrapper = VBoxContainer.new()
	attack_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attack_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_content.add_child(attack_wrapper)
	# Store reference so tab switching works
	_attack_tab = attack_wrapper

	_attack_hsplit_l = HSplitContainer.new()
	_attack_hsplit_l.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_attack_hsplit_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_hsplit_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attack_wrapper.add_child(_attack_hsplit_l)

	# Left: ability select
	var ability_col = VBoxContainer.new()
	ability_col.custom_minimum_size.x = 160
	ability_col.add_theme_constant_override("separation", 4)
	ability_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attack_hsplit_l.add_child(ability_col)

	ability_col.add_child(_section_label("Attack"))
	_attack_select = OptionButton.new()
	_attack_select.custom_minimum_size.x = 150
	_style_option(_attack_select)
	_attack_select.item_selected.connect(_on_attack_option_changed)
	ability_col.add_child(_attack_select)

	# Element + stat chip row below dropdown
	_ability_info_box = HFlowContainer.new()
	_ability_info_box.add_theme_constant_override("h_separation", 6)
	_ability_info_box.add_theme_constant_override("v_separation", 4)
	_ability_info_box.visible = false
	ability_col.add_child(_ability_info_box)

	# Right side of left split: center + right in another HSplit
	_attack_hsplit_r = HSplitContainer.new()
	_attack_hsplit_r.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_attack_hsplit_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_hsplit_r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attack_hsplit_l.add_child(_attack_hsplit_r)

	# Center: targets + results (in a VSplit so target list vs results are resizable)
	_target_vsplit = VSplitContainer.new()
	_target_vsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_target_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_hsplit_r.add_child(_target_vsplit)

	# Top of target split: target selection
	var target_top = VBoxContainer.new()
	target_top.add_theme_constant_override("separation", 4)
	_target_vsplit.add_child(target_top)

	target_top.add_child(_section_label("Select Targets"))
	_target_list = ItemList.new()
	_target_list.select_mode = ItemList.SELECT_MULTI
	_target_list.custom_minimum_size.y = 60
	_target_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_itemlist(_target_list)
	target_top.add_child(_target_list)

	# Bottom of target split: results (target rows) — fills all remaining space
	var target_bottom = VBoxContainer.new()
	target_bottom.add_theme_constant_override("separation", 2)
	target_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target_bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_vsplit.add_child(target_bottom)

	target_bottom.add_child(_section_label("Results"))
	var results_scroll = ScrollContainer.new()
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_bottom.add_child(results_scroll)

	_results_container = VBoxContainer.new()
	_results_container.add_theme_constant_override("separation", 4)
	_results_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.add_child(_results_container)

	# Right: turn data + items
	var right_col = VBoxContainer.new()
	right_col.custom_minimum_size.x = 190
	right_col.add_theme_constant_override("separation", 3)
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attack_hsplit_r.add_child(right_col)

	# Roll panel card
	var roll_card = PanelContainer.new()
	roll_card.add_theme_stylebox_override("panel", _sb(BG_CARD, BORDER_SUBTLE, 1, 6, Vector4(8, 6, 8, 6)))
	right_col.add_child(roll_card)

	var roll_vbox = VBoxContainer.new()
	roll_vbox.add_theme_constant_override("separation", 3)
	roll_card.add_child(roll_vbox)

	roll_vbox.add_child(_section_label("Turn Data"))

	var ar_row = _make_spinbox("Attack Roll")
	roll_vbox.add_child(ar_row)
	_attack_roll_spin = _get_spin(ar_row)

	var tm_row = _make_spinbox("Tiles Moved", 20)
	roll_vbox.add_child(tm_row)
	_tiles_moved_spin = _get_spin(tm_row)

	var bg_row = _make_spinbox("Burst Gained", 20)
	roll_vbox.add_child(bg_row)
	_burst_gained_spin = _get_spin(bg_row)

	var ps_row = _make_spinbox("Passive Stacks", 50)
	roll_vbox.add_child(ps_row)
	_passive_stacks_spin = _get_spin(ps_row)

	_crit_toggle = CheckButton.new()
	_crit_toggle.text = "Critical Hit"
	_crit_toggle.add_theme_font_size_override("font_size", 40)
	_crit_toggle.add_theme_color_override("font_color", TEXT_PRIMARY)
	roll_vbox.add_child(_crit_toggle)

	# Item use card
	var item_card = PanelContainer.new()
	item_card.add_theme_stylebox_override("panel", _sb(BG_CARD, BORDER_SUBTLE, 1, 6, Vector4(8, 6, 8, 6)))
	right_col.add_child(item_card)

	var item_vbox = VBoxContainer.new()
	item_vbox.add_theme_constant_override("separation", 3)
	item_card.add_child(item_vbox)

	item_vbox.add_child(_section_label("Use Item"))

	_item_select = OptionButton.new()
	_item_select.custom_minimum_size.x = 180
	_style_option(_item_select)
	item_vbox.add_child(_item_select)

	_item_desc = _lbl("No item selected", 13, TEXT_MUTED)
	_item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_item_desc.custom_minimum_size.x = 170
	item_vbox.add_child(_item_desc)

	item_vbox.add_child(_section_label("Target"))

	_item_target_select = OptionButton.new()
	_item_target_select.custom_minimum_size.x = 180
	_style_option(_item_target_select)
	item_vbox.add_child(_item_target_select)

	# ── EFFECTS TAB (hidden by default) ──
	_effects_tab = VBoxContainer.new()
	_effects_tab.visible = false
	_effects_tab.add_theme_constant_override("separation", 4)
	dock_content.add_child(_effects_tab)

	# ── STATS TAB (hidden by default) ──
	_stats_tab = VBoxContainer.new()
	_stats_tab.visible = false
	_stats_tab.add_theme_constant_override("separation", 4)
	dock_content.add_child(_stats_tab)

	# ── Bottom bar (in dock_split so resizable against content above) ──
	var bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 10)
	_dock_split.add_child(bottom_bar)

	_food_buff_label = _lbl("No buff", 13, Color(0.292, 0.855, 0.498))
	_food_buff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_food_buff_label.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom_bar.add_child(_food_buff_label)

	var burst_hbox = HBoxContainer.new()
	burst_hbox.add_theme_constant_override("separation", 6)
	bottom_bar.add_child(burst_hbox)
	burst_hbox.add_child(_lbl("Burst", 18, TEXT_SECONDARY))
	_burst_count_label = _lbl("0 / 0", 18, ACCENT)
	burst_hbox.add_child(_burst_count_label)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "END TURN"
	_end_turn_btn.custom_minimum_size = Vector2(120, 30)
	_style_button(_end_turn_btn, Color.TRANSPARENT, ACCENT, ACCENT)
	var et_normal = _sb(Color(0.788, 0.659, 0.298, 0.1), ACCENT, 2, 6, Vector4(20, 6, 20, 6))
	_end_turn_btn.add_theme_stylebox_override("normal", et_normal)
	var et_hover = _sb(Color(0.788, 0.659, 0.298, 0.2), ACCENT, 2, 6, Vector4(20, 6, 20, 6))
	_end_turn_btn.add_theme_stylebox_override("hover", et_hover)
	_end_turn_btn.add_theme_color_override("font_color", ACCENT)
	_end_turn_btn.add_theme_font_size_override("font_size", 40)
	bottom_bar.add_child(_end_turn_btn)

	# ═══════════════════════════════════════════════════════════
	#  RIGHT: Party Sidebar (260px min, resizable)
	# ═══════════════════════════════════════════════════════════
	var party_panel = PanelContainer.new()
	party_panel.custom_minimum_size.x = 220
	party_panel.add_theme_stylebox_override("panel", _sb(BG_PANEL, Color.TRANSPARENT, 0, 0, Vector4(6, 4, 6, 4)))
	_inner_split.add_child(party_panel)

	# Party sidebar uses a VSplitContainer so cards vs stats/effects are resizable
	_party_split = VSplitContainer.new()
	_party_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_party_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_panel.add_child(_party_split)

	# ── Top: Party cards ──
	var party_top = VBoxContainer.new()
	party_top.add_theme_constant_override("separation", 2)
	party_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_split.add_child(party_top)

	var party_title = _lbl("PARTY", 13, TEXT_MUTED)
	party_title.uppercase = true
	party_top.add_child(party_title)

	var party_scroll = ScrollContainer.new()
	party_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	party_top.add_child(party_scroll)

	_party_list = VBoxContainer.new()
	_party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_list.add_theme_constant_override("separation", 4)
	party_scroll.add_child(_party_list)

	# ── Bottom: Stats + Effects (resizable via inner VSplit) ──
	_info_split = VSplitContainer.new()
	_info_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_info_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_split.custom_minimum_size.y = 120
	_party_split.add_child(_info_split)

	# Stats section
	var stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 2)
	_info_split.add_child(stats_box)

	# Challenge quest tag (small, with tooltip for full text)
	var quest = Global.active_challenge_quest
	if not quest.is_empty():
		var quest_text_raw = str(quest.get("challenge_text", ""))
		# Strip BBCode for tooltip
		var tooltip_text = quest_text_raw
		var strip_regex = RegEx.new()
		strip_regex.compile("\\[.*?\\]")
		tooltip_text = strip_regex.sub(tooltip_text, "", true)
		var giver = str(quest.get("quest_giver_name", ""))
		var personality = str(quest.get("quest_giver_personality", ""))
		if giver != "":
			tooltip_text += "\n%s (%s)" % [giver, personality]

		var quest_tag = Label.new()
		quest_tag.text = "CHALLENGE QUEST"
		quest_tag.add_theme_font_size_override("font_size", 36)
		quest_tag.add_theme_color_override("font_color", Color(0.788, 0.659, 0.298))
		quest_tag.tooltip_text = tooltip_text
		quest_tag.mouse_filter = Control.MOUSE_FILTER_STOP
		stats_box.add_child(quest_tag)

	var my_stats_title = _lbl("MY STATS", 13, TEXT_MUTED)
	my_stats_title.uppercase = true
	stats_box.add_child(my_stats_title)

	var my_stats_scroll = ScrollContainer.new()
	my_stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	my_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_box.add_child(my_stats_scroll)

	_my_stats_container = VBoxContainer.new()
	_my_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_my_stats_container.add_theme_constant_override("separation", 2)
	my_stats_scroll.add_child(_my_stats_container)

	# Effects section
	var fx_box = VBoxContainer.new()
	fx_box.add_theme_constant_override("separation", 2)
	_info_split.add_child(fx_box)

	var my_fx_title = _lbl("MY EFFECTS", 13, TEXT_MUTED)
	my_fx_title.uppercase = true
	fx_box.add_child(my_fx_title)

	var my_fx_scroll = ScrollContainer.new()
	my_fx_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	my_fx_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fx_box.add_child(my_fx_scroll)

	_my_effects_container = VBoxContainer.new()
	_my_effects_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_my_effects_container.add_theme_constant_override("separation", 2)
	my_fx_scroll.add_child(_my_effects_container)

	# ═══════════════════════════════════════════════════════════
	#  Stun Overlay
	# ═══════════════════════════════════════════════════════════
	_stun_overlay = ColorRect.new()
	_stun_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stun_overlay.color = Color(0.024, 0.031, 0.055, 0.85)
	_stun_overlay.visible = false
	_stun_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_stun_overlay)

	var stun_center = CenterContainer.new()
	stun_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stun_overlay.add_child(stun_center)

	var stun_card = PanelContainer.new()
	stun_card.custom_minimum_size = Vector2(400, 180)
	stun_card.add_theme_stylebox_override("panel", _sb(BG_PANEL, BORDER_SUBTLE, 1, 8, Vector4(32, 20, 32, 20)))
	stun_center.add_child(stun_card)

	var stun_vbox = VBoxContainer.new()
	stun_vbox.add_theme_constant_override("separation", 12)
	stun_card.add_child(stun_vbox)

	_stun_title = _lbl("Turn Skipped!", 20, TEXT_PRIMARY)
	_stun_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stun_vbox.add_child(_stun_title)

	_stun_text = _lbl("Stunned — cannot act this turn", 15, TEXT_SECONDARY)
	_stun_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stun_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	stun_vbox.add_child(_stun_text)

	_stun_btn = Button.new()
	_stun_btn.text = "Continue →"
	_stun_btn.custom_minimum_size = Vector2(140, 34)
	_stun_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(_stun_btn, BG_CARD, BORDER_SUBTLE)
	stun_vbox.add_child(_stun_btn)

	# ═══════════════════════════════════════════════════════════
	#  Audio
	# ═══════════════════════════════════════════════════════════
	_audio = AudioStreamPlayer.new()
	add_child(_audio)


# =============================================================================
#  Turn Order Setup
# =============================================================================

func _setup_turn_order():
	Original_Order = Global.Current_Party.get("Turn_Order", []).duplicate()
	for e in Global.BATTLEENEMIES.values():
		var label = str(e.get("EnemyName")) + " " + str(e.get("id"))
		if not Original_Order.has(label):
			Original_Order.append(label)


# =============================================================================
#  Battler Building
# =============================================================================

func _build_battlers():
	if Original_Order.size() == 0:
		return

	# Client shells do NOT assemble battle state — they render the host's broadcast
	# snapshot (applied into BattleManager via _receive_battle_state). Only the
	# authoritative owner (host, or offline=self) builds battler_data.
	if not (NetworkManager.is_host or Global.is_offline):
		return

	var bd: Dictionary = BattlerState.build_all(Original_Order)
	for battler_name in bd:
		var entry: Dictionary = bd[battler_name]
		var max_bc = null
		for ability in entry.get("entity_current_ability_data", {}).values():
			var cost = ability.get("charge_cost", 0)
			if cost > 0:
				if max_bc == null or cost > max_bc:
					max_bc = cost
		entry["max_burst_charges"] = max_bc

	# Adopt the assembled view as authoritative (sets BattleManager.active so the
	# Global.BattlerData / Current_Battler_Data getters serve it).
	BattleManager.set_host_view(bd, str(Global.Current_Party.get("Current_Turn", "")), turn_no)

	if NetworkManager.is_host and Global.effect_processor == null:
		Global.start_battle_effects(BattleManager.battler_data)
		# Start battle logger
		if _battle_logger == null:
			_battle_logger = BattleLogger.new()
			if battle_id == null or battle_id == "":
				battle_id = str(Time.get_unix_time_from_system())
			_battle_logger.start_battle(str(battle_id))

	# Sync effects so all clients can see them immediately
	if NetworkManager.is_host and Global.effect_processor:
		Global.sync_active_effects()

	# Recalculate stats with effects and sync max/current health
	if NetworkManager.is_host:
		_sync_health_with_effects()
		# Broadcast the freshly-assembled authoritative view to client shells.
		NetworkManager.broadcast_battle_state()


# =============================================================================
#  Health Sync With Effects
# =============================================================================

func _sync_health_with_effects() -> void:
	# When effects change max HP (e.g. weapon passive +30% health),
	# adjust both Max_Health and Current_Health so the player gains/loses
	# the difference. This runs every data refresh on the host.
	CharacterManager.recalculate_all()
	var updates = []
	for pname in Global.PartyCharacters:
		var calc = CharacterManager.get_stats(pname)
		if calc == null:
			continue
		var cid = Global.CHARACTERS_NAME.get(pname, "")
		if cid == "":
			continue
		var data = Global.CHARACTERS.get(cid, {})
		var stored_max = int(data.get("Max_Health", 0))
		var calc_max = int(calc.health)
		if calc_max == stored_max or stored_max == 0:
			continue
		# Difference between what max should be and what's stored
		var diff = calc_max - stored_max
		var cur_hp = int(data.get("Current_Health", stored_max))
		var new_cur = cur_hp + diff
		# Clamp: don't go below 1 (if alive) or above new max
		if new_cur > calc_max:
			new_cur = calc_max
		if new_cur < 0:
			new_cur = 0
		updates.append({"table": "Characters", "record_id": int(cid), "field": "Max_Health", "value": calc_max})
		updates.append({"table": "Characters", "record_id": int(cid), "field": "Current_Health", "value": new_cur})
	if updates.size() > 0:
		Global.Update_Records(updates)


# =============================================================================
#  Data Sync Handler
# =============================================================================

func _on_data_load_complete():
	if _battle_ending:
		return
	Current_Turn = Global.Current_Party.get("Current_Turn")
	_setup_turn_order()
	_build_battlers()
	_refresh_all()
	_update_dock_visibility()
	# Battle-end is host-authoritative. Clients learn of victory via
	# NetworkManager.battle_summary_received -> _on_battle_summary_received,
	# never by inspecting their own (potentially stale/empty) BATTLEENEMIES
	# or PartyCharacters dicts. Offline mode acts as its own authority.
	if NetworkManager.is_host or Global.is_offline:
		check_battle_end()
		# If the turn landed on a downed/killed battler, auto-skip their turn
		# (host-authoritative). _advance_turn picks the next living battler.
		if not _battle_ending and _is_battler_down(str(Current_Turn)):
			_advance_turn()


## Client shell: a fresh authoritative battle view arrived from the host. The
## snapshot is already applied into BattleManager (Global.BattlerData serves it);
## just re-render.
func _on_battle_state_received(_snapshot: Dictionary) -> void:
	if _battle_ending:
		return
	Current_Turn = Global.Current_Party.get("Current_Turn")
	_setup_turn_order()
	_refresh_all()
	_update_dock_visibility()


# =============================================================================
#  Dock Visibility
# =============================================================================

func _update_dock_visibility():
	Current_Turn = Global.Current_Party.get("Current_Turn")

	if Global.PartyCharacters.has(str(Current_Turn)):
		Turn_Type = "Character"
	elif Global.PartyCompanions.has(str(Current_Turn)):
		Turn_Type = "Companion"
	else:
		Turn_Type = "Enemy"

	var is_my_turn = (str(Current_Turn) == Global.ACTIVE_USER_NAME)
	var is_my_companion = false
	if Turn_Type == "Companion":
		var comp_id = Global.COMPANIONS_NAME.get(str(Current_Turn), "")
		var comp_data = Global.COMPANIONS.get(comp_id, {})
		is_my_companion = (comp_data.get("Owner", "") == Global.ACTIVE_USER_NAME)

	var should_show = false
	if NetworkManager.is_host:
		should_show = is_my_turn or is_my_companion or (Turn_Type == "Enemy")
	else:
		should_show = is_my_turn or is_my_companion

	if should_show and _is_stunned(str(Current_Turn)):
		_action_dock.visible = false
		_show_stun_overlay()
		return

	_stun_overlay.visible = false
	_action_dock.visible = should_show
	if should_show:
		_refresh_action_dock()
		_check_focus_alert()
	else:
		_focus_alert_pending = false
		_focus_alert_turn = ""

func _check_focus_alert() -> void:
	var turn_name = str(Current_Turn)
	# Reset guard if the turn changed
	if turn_name != _focus_alert_turn:
		_focus_alert_pending = false
		_focus_alert_turn = turn_name
	# Don't re-trigger for the same turn
	if _focus_alert_pending:
		return
	# Only act if window is not focused
	if get_window().has_focus():
		return
	_focus_alert_pending = true
	# Force window to maximized and foreground regardless of current state
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_request_attention()
	get_window().grab_focus()
	# Give the OS a moment to process the restore
	await get_tree().create_timer(0.3).timeout
	# Record mouse position and wait 5 seconds to see if they interact
	_focus_alert_mouse_pos = get_viewport().get_mouse_position()
	await get_tree().create_timer(5.0).timeout
	# If mouse hasn't moved, flash red
	var current_mouse = get_viewport().get_mouse_position()
	if current_mouse.distance_to(_focus_alert_mouse_pos) < 5.0:
		_flash_red()

func _flash_red() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(1, 0, 0, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(overlay)
	var tween = create_tween()
	# Two quick red pulses
	tween.tween_property(overlay, "color:a", 0.3, 0.2)
	tween.tween_property(overlay, "color:a", 0.0, 0.2)
	tween.tween_interval(0.15)
	tween.tween_property(overlay, "color:a", 0.3, 0.2)
	tween.tween_property(overlay, "color:a", 0.0, 0.2)
	tween.tween_callback(overlay.queue_free)


# =============================================================================
#  Refresh All
# =============================================================================

func _refresh_all():
	_refresh_turn_list()
	_refresh_enemies()
	_refresh_party()
	_refresh_my_stats()
	_refresh_my_effects()
	_turn_badge.text = "%s's Turn" % str(Current_Turn) if Current_Turn else ""


# =============================================================================
#  Refresh Enemies
# =============================================================================

func _refresh_enemies():
	for c in _enemy_grid.get_children():
		c.queue_free()
	for e in Global.BATTLEENEMIES.values():
		var card = EnemyCard.new()
		_enemy_grid.add_child(card)
		card.set_data(str(e.get("id")))
		card.visible = not bool(e.get("Fog", false))
	# Normalize card widths after a frame so sizes are calculated
	call_deferred("_normalize_enemy_card_widths")

func _normalize_enemy_card_widths() -> void:
	var max_width: float = 0.0
	for c in _enemy_grid.get_children():
		if c is EnemyCard and c.visible:
			max_width = max(max_width, c.size.x)
	if max_width > 0.0:
		for c in _enemy_grid.get_children():
			if c is EnemyCard:
				c.custom_minimum_size.x = max_width


# =============================================================================
#  Refresh Party
# =============================================================================

func _refresh_party():
	for c in _party_list.get_children():
		c.queue_free()
	var current = str(Global.Current_Party.get("Current_Turn", ""))
	for member in Original_Order:
		var is_char = Global.PartyCharacters.has(member)
		var is_comp = Global.PartyCompanions.has(member)
		if not is_char and not is_comp:
			continue
		var card = PartyCard.new()
		_party_list.add_child(card)
		card.set_data(member, "Character" if is_char else "Companion")
		card.set_active_turn(member == current)


# =============================================================================
#  My Stats (always visible in party sidebar)
# =============================================================================

func _refresh_my_stats():
	for c in _my_stats_container.get_children():
		c.queue_free()

	var my_name = Global.ACTIVE_USER_NAME

	# Force recalculate so effect bonuses (weapon passives, artifact sets, etc.) are included
	CharacterManager.recalculate_all()

	# Use CharacterManager.get_stats() which includes base + gear + artifacts + effect bonuses
	var calc_stats = CharacterManager.get_stats(my_name)

	var cid = Global.CHARACTERS_NAME.get(my_name, "")
	var data = Global.CHARACTERS.get(cid, {}) if cid != "" else {}

	if calc_stats == null and data.is_empty():
		_my_stats_container.add_child(_lbl("No data", 13, TEXT_MUTED))
		return

	# Prefer calculated stats (includes effects), fall back to raw data
	var hp_cur = int(data.get("Current_Health", 0))
	# Use calculated health stat (includes effect bonuses like +30% HP from weapon)
	var hp_max = int(calc_stats.health) if calc_stats and calc_stats.health > 0 else int(data.get("Max_Health", 0))
	var atk = int(calc_stats.attack) if calc_stats else int(data.get("Attack", 0))
	var def_val = int(calc_stats.defense) if calc_stats else int(data.get("Defense", 0))
	var em = int(calc_stats.elemental_mastery) if calc_stats else int(data.get("Elemental_Mastery", 0))
	var cd = float(calc_stats.critical_damage) if calc_stats else float(data.get("Critical_Damage", 0))
	var er = float(calc_stats.energy_recharge) if calc_stats else float(data.get("Energy_Recharge", 0))
	var bc = int(data.get("Burst_Charges", 0))

	var stats_to_show = [
		["HP", "%d / %d" % [hp_cur, hp_max]],
		["ATK", str(atk)],
		["DEF", str(def_val)],
		["EM", str(em)],
		["Crit DMG", str(cd)],
		["ER", str(er)],
		["Burst", "%d / %d" % [bc, _get_max_burst_cost(my_name)]],
	]

	for stat in stats_to_show:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_lbl = _lbl(stat[0], 13, TEXT_MUTED)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		row.add_child(_lbl(stat[1], 13, TEXT_PRIMARY))
		_my_stats_container.add_child(row)

func _get_max_burst_cost(char_name: String) -> int:
	var bd = Global.BattlerData.get(char_name, {})
	var max_cost = 0
	for ability in bd.get("entity_current_ability_data", {}).values():
		var cost = ability.get("charge_cost", 0)
		if cost > max_cost:
			max_cost = cost
	return max_cost


# =============================================================================
#  My Effects (always visible in party sidebar)
# =============================================================================

func _refresh_my_effects():
	for c in _my_effects_container.get_children():
		c.queue_free()

	var my_name = Global.ACTIVE_USER_NAME
	var effects = Global.get_battler_effects(my_name)

	if effects.is_empty():
		_my_effects_container.add_child(_lbl("None", 13, TEXT_MUTED))
		return

	for fx in effects:
		var dur = fx.get("turns_remaining", 0)
		var dur_str = "perm" if dur == -1 else (str(dur) + " left" if dur > 0 else "expiring")
		var stacks_str = ""
		if fx.get("stacks", 0) > 0:
			stacks_str = " [%d/%d]" % [fx.get("stacks"), fx.get("max_stacks", 0)]
		var desc = fx.get("description", "")
		if desc == "":
			desc = "%s %s" % [fx.get("effect_type", ""), fx.get("effect_stat", "")]
		var etype = str(fx.get("effect_type", ""))
		var is_bad = etype in ["FLAT_DAMAGE", "DOT", "DOT_PER_ACTION", "SKIP_TURN", "STUN", "FREEZE", "ROOT", "BLIND", "SLOW", "DISARM", "FEAR", "ROLL_DISADVANTAGE", "RANDOM_TARGET"]
		var marker = "[-] " if is_bad else "[+] "
		var label_color = Color(0.937, 0.267, 0.267) if is_bad else Color(0.292, 0.855, 0.498)

		var name_text = "%s%s %s%s" % [marker, dur_str, fx.get("source_name", "?"), stacks_str]

		var lbl = _lbl(name_text, 13, label_color)
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS

		lbl.tooltip_text = "%s (%s)\n%s" % [
			fx.get("source_name", ""), fx.get("source_type", ""), _wrap_text(desc, 80)
		]
		_my_effects_container.add_child(lbl)


# =============================================================================
#  Refresh Turn List
# =============================================================================

func _refresh_turn_list():
	_turn_list.clear()
	var ordered = Original_Order.duplicate()
	var current = str(Global.Current_Party.get("Current_Turn", ""))

	# Rotate so current turn is first
	var idx = ordered.find(current)
	if idx >= 0:
		var rot = []
		for i in range(idx, ordered.size()):
			rot.append(ordered[i])
		for j in range(0, idx):
			rot.append(ordered[j])
		ordered = rot

	# Show up to 23 entries (wrapping around the order)
	var preview_len = min(23, ordered.size() * 2)
	for i in range(preview_len):
		var nm = str(ordered[i % ordered.size()])
		var prefix = ""
		if i == 0:
			prefix = "▶ "
		elif i == 1:
			prefix = "⟶ "
		var ii = _turn_list.add_item(prefix + nm)
		_turn_list.set_item_selectable(ii, false)
		if i >= ordered.size():
			_turn_list.set_item_disabled(ii, true)
		if i == 0:
			_turn_list.set_item_custom_bg_color(ii, COL_CURRENT)
		elif i == 1:
			_turn_list.set_item_custom_bg_color(ii, COL_NEXT)
	_turn_list.deselect_all()

	# Update round label
	var round_num = turn_no / max(Original_Order.size(), 1) + 1
	_round_label.text = "R%d" % round_num


# =============================================================================
#  Refresh Action Dock
# =============================================================================

func _refresh_action_dock():
	_setup_attacks()
	_setup_targets()
	_setup_items()
	_setup_effects_display()
	_setup_stats_display()
	_update_burst_display()
	_update_food_buff()
	_reset_inputs()


# =============================================================================
#  Attack Selection
# =============================================================================

func _setup_attacks():
	var popup: PopupMenu = _attack_select.get_popup()
	if _attack_select.has_selectable_items():
		_attack_select.clear()

	if Current_Turn == null or Global.BattlerData.size() == 0:
		return

	_attack_select.add_item("None")
	var none_index = _attack_select.get_item_count() - 1
	if popup:
		popup.set_item_tooltip(none_index, "No attack used this turn.")

	if not Global.BattlerData.has(Current_Turn):
		return

	var battler = Global.BattlerData[Current_Turn]
	for item in battler.get("entity_current_active_ability_data", {}).values():
		if item.get("Ability_Type") == "Passive":
			continue
		var raw_aid = item.get("Ability_ID")
		if raw_aid == null:
			continue
		var ability_id: int = int(raw_aid)
		var ability: AbilityData = GameDB.get_ability(ability_id)
		if ability == null:
			continue
		# Skip passives by ability_type field or zero weight (non-selectable)
		if ability.ability_type == "Passive" or ability.weight <= 0.0:
			continue
		# Skip abilities with no damage and targeting_type "none" (buff/passive abilities)
		if ability.dice_count == 0 and ability.dice_die == 0 and ability.targeting_type == "none":
			continue

		var cooldown = item.get("Ability_Cooldown", 0)
		var name_text: String = str(ability.name)
		var desc: String = str(ability.description)
		var charge_cost: int = ability.charge_cost if ability.charge_cost > 0 else 0

		desc = _wrap_text(desc, 100)

		if cooldown == 0 and charge_cost == 0:
			_attack_select.add_item(name_text)
		elif charge_cost > 0:
			var bc = battler.get("burst_charges", 0)
			if bc == null:
				bc = 0
			if int(bc) >= charge_cost:
				_attack_select.add_item(name_text)
			else:
				_attack_select.add_item(name_text + " - Not enough charges.")
		else:
			_attack_select.add_item(name_text + " - " + str(cooldown) + " Turns left.")

		var ability_idx = _attack_select.get_item_count() - 1
		if popup:
			popup.set_item_tooltip(ability_idx, desc)
		if _attack_select.get_item_text(ability_idx) != name_text:
			_attack_select.set_item_disabled(ability_idx, true)

	_on_attack_option_changed(0)

const ELEMENT_CHIP_COLORS = {
	"Physical": Color(0.65, 0.65, 0.65),
	"Fire": Color(0.9, 0.35, 0.2),
	"Water": Color(0.2, 0.5, 0.9),
	"Ice": Color(0.55, 0.82, 0.92),
	"Electric": Color(0.7, 0.45, 0.9),
	"Wind": Color(0.45, 0.82, 0.65),
	"Earth": Color(0.85, 0.72, 0.3),
	"Nature": Color(0.45, 0.78, 0.25),
}

func _on_attack_option_changed(_idx: int) -> void:
	for c in _ability_info_box.get_children():
		c.queue_free()
	_ability_info_box.visible = false

	if _attack_select.selected <= 0 or Current_Turn == null:
		return
	var selected_name = _attack_select.get_item_text(_attack_select.selected)
	if selected_name == "None":
		return

	# Find the matching ability
	var battler = Global.BattlerData.get(Current_Turn, {})
	var ability: AbilityData = null
	for item in battler.get("entity_current_active_ability_data", {}).values():
		var raw_aid = item.get("Ability_ID")
		if raw_aid == null:
			continue
		var a = GameDB.get_ability(int(raw_aid))
		if a != null and a.name == selected_name:
			ability = a
			break
	if ability == null:
		return

	# Element chip
	var elem = ability.element if ability.element != "" else "Physical"
	var elem_color = ELEMENT_CHIP_COLORS.get(elem, Color(0.5, 0.5, 0.5))
	_ability_info_box.add_child(_make_info_chip("Applied: " + elem, elem_color))

	# Stat chip
	var stat_text = "ATK" if elem == "Physical" else "EM"
	var stat_color = Color(0.85, 0.55, 0.35) if elem == "Physical" else Color(0.35, 0.75, 0.55)
	_ability_info_box.add_child(_make_info_chip("Roll: " + stat_text, stat_color))

	# Effects chip(s)
	var effect_parts = []
	if ability.effect_status > 0:
		var status_def = GameDB.status_effects.get(ability.effect_status, null)
		var status_name = status_def.name if status_def else "Status %d" % ability.effect_status
		var dur = ability.effect_status_duration_rounds
		var dur_text = " (%d rnd)" % dur if dur > 0 else ""
		effect_parts.append(status_name + dur_text)
	if ability.effect_immobilize:
		effect_parts.append("Immobilize")
	if ability.effect_mark_name != "":
		effect_parts.append(ability.effect_mark_name)
	for eff in ability.effects:
		if eff is GameEffect and eff.description != "":
			effect_parts.append(eff.description)

	if effect_parts.size() > 0:
		var fx_color = Color(0.75, 0.45, 0.45)
		for part in effect_parts:
			_ability_info_box.add_child(_make_info_chip(part, fx_color))

	_ability_info_box.visible = true

func _make_info_chip(text: String, color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.25)
	sb.border_color = Color(color, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", sb)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(color, 1.0).lightened(0.3))
	lbl.add_theme_font_size_override("font_size", 36)
	panel.add_child(lbl)
	return panel

# =============================================================================
#  Target Selection
# =============================================================================

func _setup_targets():
	_target_list.clear()
	var active_list = Global.Current_Party.get("Turn_Order", []).duplicate()
	for companion in Global.COMPANIONS.values():
		if companion.get("Active") == true and not active_list.has(companion.get("Name")):
			active_list.append(companion.get("Name"))
	for member in active_list:
		_target_list.add_item(member)
	for enemy in Global.BATTLEENEMIES.values():
		var enemy_label = str(enemy.get("EnemyName")) + " " + str(int(enemy.get("id", 0)))
		var found = false
		for i in range(_target_list.item_count):
			if _target_list.get_item_text(i) == enemy_label:
				found = true
				break
		if not found:
			_target_list.add_item(enemy_label)


# =============================================================================
#  Item Selection
# =============================================================================

func _setup_items():
	var popup: PopupMenu = _item_select.get_popup()
	if _item_select.has_selectable_items():
		_item_select.clear()

	if Current_Turn == null or Global.BattlerData.size() == 0:
		return

	_item_select.add_item("None")
	var none_index = _item_select.get_item_count() - 1
	if popup:
		popup.set_item_tooltip(none_index, "No item used this turn.")

	for item in Global.CHARACTER_ITEMS.values():
		if item.get("Owner") == str(Current_Turn):
			if item.get("Type") == "Consumable" and item.get("Quantity", 0) > 0:
				if not item.get("Description", "").to_lower().contains("battle") and not item.get("Description", "").to_lower().contains("material"):
					var name_text = str(item.get("Name"))
					_item_select.add_item(name_text)
					var desc = "Quantity - x" + str(item.get("Quantity")) + "\n\n" + "Description - " + str(item.get("Description", ""))
					desc = _wrap_text(desc, 100)
					var idx = _item_select.get_item_count() - 1
					if popup:
						popup.set_item_tooltip(idx, desc)

	_setup_item_targets()


func _setup_item_targets():
	var popup: PopupMenu = _item_target_select.get_popup()
	if _item_target_select.has_selectable_items():
		_item_target_select.clear()

	if Current_Turn == null or Global.BattlerData.size() == 0:
		return

	_item_target_select.add_item("None")
	var none_index = _item_target_select.get_item_count() - 1
	if popup:
		popup.set_item_tooltip(none_index, "No item target.")

	for item_name in Global.BattlerData.keys():
		_item_target_select.add_item(item_name)
		var idx = _item_target_select.get_item_count() - 1
		var desc = Global.BattlerData[item_name].get("type", "")
		if popup:
			popup.set_item_tooltip(idx, desc)


# =============================================================================
#  Effects Display
# =============================================================================

func _setup_effects_display():
	for c in _effects_tab.get_children():
		c.queue_free()

	var b_name = str(Current_Turn) if Current_Turn != null else ""
	var effects = Global.get_battler_effects(b_name)

	var entries: Array = []
	for fx in effects:
		var dur = fx.get("turns_remaining", 0)
		var dur_str = "perm" if dur == -1 else (str(dur) + " left" if dur > 0 else "expiring")

		var desc = fx.get("description", "")
		if desc == "":
			desc = "%s %s" % [fx.get("effect_type", ""), fx.get("effect_stat", "")]

		var stacks_str = ""
		if fx.get("stacks", 0) > 0:
			stacks_str = " [%d/%d]" % [fx.get("stacks"), fx.get("max_stacks", 0)]

		entries.append({
			"name": fx.get("source_name", "Unknown"),
			"duration": dur,
			"dur_str": dur_str,
			"description": desc,
			"source_type": fx.get("source_type", ""),
			"stacks_str": stacks_str,
			"effect_type": fx.get("effect_type", ""),
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = int(a.get("duration", 0))
		var db: int = int(b.get("duration", 0))
		if da != db:
			return da < db
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)

	if entries.size() == 0:
		var none_lbl = _lbl("No active effects", 13, TEXT_MUTED)
		_effects_tab.add_child(none_lbl)
		return

	for e in entries:
		var etype = str(e.get("effect_type", ""))
		var is_bad = etype in ["FLAT_DAMAGE", "DOT", "DOT_PER_ACTION", "SKIP_TURN", "STUN", "FREEZE", "ROOT", "BLIND", "SLOW", "DISARM", "FEAR", "ROLL_DISADVANTAGE", "RANDOM_TARGET"]
		var marker = "[-] " if is_bad else "[+] "
		var label_color = Color(0.937, 0.267, 0.267) if is_bad else Color(0.292, 0.855, 0.498)
		var lbl = _lbl("", 13, label_color)
		lbl.text = "%s%s - %s%s" % [marker, e.get("dur_str"), e.get("name"), e.get("stacks_str")]
		var desc_text = str(e.get("description", ""))
		lbl.tooltip_text = "%s (%s) %s%s\n%s" % [
			e.get("name"), e.get("source_type"), e.get("dur_str"),
			e.get("stacks_str"), _wrap_text(desc_text, 80)
		]
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		_effects_tab.add_child(lbl)


# =============================================================================
#  Stats Display
# =============================================================================

func _setup_stats_display():
	for c in _stats_tab.get_children():
		c.queue_free()

	var b_name = str(Current_Turn) if Current_Turn != null else ""
	if not Global.BattlerData.has(b_name):
		_stats_tab.add_child(_lbl("No stats available", 13, TEXT_MUTED))
		return

	var battler = Global.BattlerData[b_name]
	var entity = battler.get("entity_data", {})

	var stat_keys = ["ATK", "DEF", "Elemental_Mastery", "Speed", "Accuracy"]
	for stat_key in stat_keys:
		var val = entity.get(stat_key, "")
		if val == null:
			val = ""
		var lbl = _lbl("%s: %s" % [stat_key, str(val)], 13, TEXT_PRIMARY)
		_stats_tab.add_child(lbl)

	# Show HP
	var hp_cur = entity.get("Current_Health", 0)
	var hp_max = entity.get("Max_Health", 0)
	_stats_tab.add_child(_lbl("HP: %s / %s" % [str(hp_cur), str(hp_max)], 13, TEXT_PRIMARY))

	# Show burst charges
	var bc = battler.get("burst_charges", 0)
	var mbc = battler.get("max_burst_charges", 0)
	if bc == null:
		bc = 0
	if mbc == null:
		mbc = 0
	_stats_tab.add_child(_lbl("Burst: %d / %d" % [int(bc), int(mbc)], 13, TEXT_PRIMARY))


# =============================================================================
#  Tab Switching
# =============================================================================

func _switch_tab(tab_name: String):
	_attack_tab.visible = (tab_name == "attack")
	_effects_tab.visible = (tab_name == "effects")
	_stats_tab.visible = (tab_name == "stats")
	_restyle_tab(_tab_btn_attack, tab_name == "attack")
	_restyle_tab(_tab_btn_effects, tab_name == "effects")
	_restyle_tab(_tab_btn_stats, tab_name == "stats")

func _restyle_tab(btn: Button, active: bool) -> void:
	btn.add_theme_color_override("font_color", ACCENT if active else TEXT_MUTED)
	var s = StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = ACCENT if active else Color.TRANSPARENT
	s.border_width_bottom = 2 if active else 0
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", s)


# =============================================================================
#  End Turn
# =============================================================================

func _on_end_turn_pressed():
	var targets_input = []
	# Results are in an HFlowContainer inside _results_container
	for child in _results_container.get_children():
		if child is HFlowContainer:
			for card in child.get_children():
				if not card.has_meta("target_name"):
					continue
				var roll_spin: SpinBox = card.get_meta("roll_spin")
				var hits_spin: SpinBox = card.get_meta("hits_spin")
				var dmg_spin: SpinBox = card.get_meta("dmg_spin")
				var type_opt: OptionButton = card.get_meta("type_opt")
				var shield_check: CheckButton = card.get_meta("shield_check")
				targets_input.append({
					"name": card.get_meta("target_name"),
					"table": card.get_meta("target_table"),
					"record_id": card.get_meta("target_id"),
					"defense_roll": int(roll_spin.value),
					"hits": int(hits_spin.value),
					"raw_damage": int(dmg_spin.value),
					"attack_type": type_opt.get_item_text(type_opt.selected),
					"killed": false,
					"shield_hit": shield_check.button_pressed,
				})

	var input = {
		"battler_name": str(Current_Turn),
		"attack_used": _attack_select.get_item_text(_attack_select.selected) if _attack_select.selected >= 0 else "None",
		"attack_roll": int(_attack_roll_spin.value),
		"tiles_moved": int(_tiles_moved_spin.value),
		"burst_gained": int(_burst_gained_spin.value),
		"passive_stacks": int(_passive_stacks_spin.value),
		"critical_hit": _crit_toggle.button_pressed,
		"item_used": _item_select.get_item_text(_item_select.selected) if _item_select.selected >= 0 else "None",
		"item_target": _item_target_select.get_item_text(_item_target_select.selected) if _item_target_select.selected >= 0 else "None",
		"targets": targets_input,
		"battle_id": battle_id,
		"turn_no": turn_no,
	}

	# Host-authoritative: the host resolves the turn. Host/offline run it directly;
	# clients submit the raw input and the host resolves on their behalf.
	# SP→MP migration: the `else` branch replaces a local process_turn call with an
	# RPC to peer 1 (host); host_resolve_turn is the single resolution path.
	if NetworkManager.is_host or Global.is_offline:
		host_resolve_turn(input)
	else:
		NetworkManager.request_process_turn.rpc_id(1, JSON.stringify(input))


## Host-authoritative turn resolution. Runs ONLY on the host (directly for
## host-acted turns, or via NetworkManager.request_process_turn for client turns)
## and in offline mode. Clients never run combat logic.
func host_resolve_turn(input: Dictionary) -> void:
	var targets_input: Array = input.get("targets", [])
	var updates = TurnProcessor.process_turn(input)
	if updates.size() > 0:
		Global.Update_Records(updates)

	# Damage breakdown -> the acting player: send to their client, or show locally
	# if the host itself controls the battler (own character / companion / enemy).
	var battler_name: String = str(input.get("battler_name", ""))
	var acting_peer: int = _peer_for_battler(battler_name)
	if acting_peer > 1:
		NetworkManager._send_damage_breakdown.rpc_id(acting_peer, JSON.stringify(input))
	else:
		_show_damage_breakdown(input)

	# Detect kills from updates for the turn log: check both "Killed" field and HP
	# dropping to 0, excluding enemies that had a phase transition in this batch.
	var total_dmg = 0
	for t in targets_input:
		total_dmg += int(t.get("raw_damage", 0))
	var phase_transitioned_ids = {}
	for u in updates:
		if u.get("table") == "BattleEnemies" and u.get("field") == "Phase":
			phase_transitioned_ids[str(u.get("record_id", ""))] = true
	var killed_ids = {}
	for u in updates:
		var rid = str(u.get("record_id", ""))
		if rid in phase_transitioned_ids:
			continue
		if u.get("field") == "Killed" and u.get("value") == true:
			killed_ids[rid] = true
		if u.get("table") == "BattleEnemies" and u.get("field") == "Current_Health" and int(u.get("value", 1)) == 0:
			killed_ids[rid] = true
	var kills = []
	for kid in killed_ids:
		for e in Global.BATTLEENEMIES.values():
			if str(e.get("id")) == kid:
				kills.append(str(e.get("EnemyName", "")) + " " + kid)
				break
	var log_results = {"total_damage": total_dmg, "killed": kills, "reactions": []}
	if _battle_logger:
		_battle_logger.log_turn(input, log_results)

	_advance_turn()


## Returns the remote client peer id that owns `battler_name`, or -1 if the host
## itself controls it (its own character, a companion it owns, or an enemy).
func _peer_for_battler(battler_name: String) -> int:
	var bd = Global.BattlerData.get(battler_name, {})
	var b_type: String = str(bd.get("type", ""))
	if b_type == "Enemy":
		return -1
	var player_name: String = battler_name
	if b_type == "Companion":
		for c in Global.COMPANIONS.values():
			if c.get("Name") == battler_name:
				player_name = str(c.get("Owner", ""))
				break
	if player_name == Global.ACTIVE_USER_NAME:
		return -1
	for peer_id in NetworkManager.connected_players:
		var info: Dictionary = NetworkManager.connected_players[peer_id]
		if info.get("name") == player_name:
			return int(peer_id)
	return -1


func _show_damage_breakdown(input: Dictionary) -> void:
	var targets: Array = input.get("targets", [])
	if targets.is_empty():
		return

	var panel = preload("res://Scenes/UI/damage_breakdown_panel.tscn").instantiate()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.panel_closed.connect(func(): panel.queue_free())
	add_child(panel)
	panel.setup(input)

func _on_damage_breakdown_received(turn_input: Dictionary) -> void:
	_show_damage_breakdown(turn_input)


# =============================================================================
#  Advance Turn
# =============================================================================

func _advance_turn():
	# Advance from the turn-order DATA, not the UI. Next turn is the first entry
	# after current in Original_Order (wrapping) that ISN'T downed/killed — a
	# downed battler's turn is auto-skipped. Runs host-side only.
	if Original_Order.size() < 2:
		return
	var current = str(Global.Current_Party.get("Current_Turn", ""))
	var idx = Original_Order.find(current)
	if idx < 0:
		return
	var next_name = ""
	for step in range(1, Original_Order.size() + 1):
		var cand = str(Original_Order[(idx + step) % Original_Order.size()])
		if not _is_battler_down(cand):
			next_name = cand
			break
	if next_name == "":
		return  # everyone is down — battle end is handled by check_battle_end

	turn_no += 1
	var updates = [{
		"table": "Party",
		"record_id": int(Global.Current_Party.get("id", 0)),
		"field": "Current_Turn",
		"value": next_name
	}]
	Global.Update_Records(updates)


## True if a battler (by label) is downed/killed and should be skipped on its turn.
func _is_battler_down(label: String) -> bool:
	if Global.PartyCharacters.has(label):
		var cid = Global.CHARACTERS_NAME.get(label, "")
		return int(Global.CHARACTERS.get(cid, {}).get("Current_Health", 1)) <= 0
	if Global.PartyCompanions.has(label):
		var coid = Global.COMPANIONS_NAME.get(label, "")
		return int(Global.COMPANIONS.get(coid, {}).get("Current_Health", 1)) <= 0
	# Enemy: record id is the last space-separated token of the label.
	var parts = label.split(" ")
	if parts.size() == 0:
		return false
	var erec = Global.BATTLEENEMIES.get(str(parts[-1]), {})
	if erec.is_empty():
		return false
	return int(erec.get("Current_Health", 1)) <= 0 or bool(erec.get("Killed", false))


# =============================================================================
#  Target Selection Signal
# =============================================================================

func _on_target_list_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Find which item was clicked
		var idx = _target_list.get_item_at_position(event.position, true)
		if idx < 0:
			return
		if Input.is_key_pressed(KEY_SHIFT):
			return  # Let multi_selected handle shift+click range
		# Toggle: if already selected, deselect; otherwise add to selection
		if _target_list.is_selected(idx):
			_target_list.deselect(idx)
		else:
			_target_list.select(idx, false)  # false = don't clear others
		_rebuild_target_rows()
		_target_list.accept_event()  # Prevent default single-select behavior


func _on_target_multi_selected(_index: int, _selected: bool) -> void:
	_rebuild_target_rows()


func _rebuild_target_rows() -> void:
	for child in _results_container.get_children():
		child.queue_free()

	# Flow results cards left-to-right; wrap to a new row only when there's no
	# horizontal room. HFlowContainer's min width is its widest single card (not
	# N cards side-by-side), so the dock no longer balloons as targets are added.
	# Overflow scrolls vertically via the parent ScrollContainer.
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_container.add_child(flow)

	for item_idx in _target_list.get_selected_items():
		var target_name = _target_list.get_item_text(item_idx)

		# Resolve table/id/shield
		var t_table = ""
		var t_id = ""
		var has_shield = false
		if Global.PartyCharacters.has(target_name):
			t_table = "Characters"
			t_id = Global.CHARACTERS_NAME.get(target_name, "")
			has_shield = int(Global.CHARACTERS.get(t_id, {}).get("Shield_Health", 0)) > 0
		elif Global.PartyCompanions.has(target_name):
			t_table = "Companions"
			t_id = Global.COMPANIONS_NAME.get(target_name, "")
			has_shield = int(Global.COMPANIONS.get(t_id, {}).get("Shield_Health", 0)) > 0
		else:
			t_table = "BattleEnemies"
			var parts = target_name.split(" ")
			t_id = parts[-1]
			has_shield = int(Global.BATTLEENEMIES.get(t_id, {}).get("Shield_Health", 0)) > 0

		# Build compact card for this target. Fixed width so cards keep a
		# consistent size and the flow can compute how many fit per row.
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", _sb(BG_CARD, BORDER_SUBTLE, 1, 4, Vector4(6, 4, 6, 4)))
		card.custom_minimum_size.x = 240
		flow.add_child(card)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)

		# Target name header — clip long names so they don't widen the card
		# past its fixed width (full name shown on hover).
		var name_lbl = _lbl(target_name, 14, ACCENT)
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.tooltip_text = target_name
		vbox.add_child(name_lbl)

		# Use a compact GridContainer for the fields: 2 cols (label, input)
		var fields = GridContainer.new()
		fields.columns = 4  # label, input, label, input (2 pairs per row)
		fields.add_theme_constant_override("h_separation", 4)
		fields.add_theme_constant_override("v_separation", 2)
		vbox.add_child(fields)

		# Their Roll
		fields.add_child(_lbl("Roll", 13, TEXT_MUTED))
		var roll_spin = SpinBox.new()
		roll_spin.min_value = 0
		roll_spin.max_value = 100
		roll_spin.value = 0
		roll_spin.custom_minimum_size = Vector2(55, 0)
		roll_spin.add_theme_font_size_override("font_size", 36)
		fields.add_child(roll_spin)

		# Hits
		fields.add_child(_lbl("Hits", 13, TEXT_MUTED))
		var hits_spin = SpinBox.new()
		hits_spin.min_value = 0
		hits_spin.max_value = 20
		hits_spin.value = 1
		hits_spin.custom_minimum_size = Vector2(55, 0)
		hits_spin.add_theme_font_size_override("font_size", 36)
		fields.add_child(hits_spin)

		# Damage
		fields.add_child(_lbl("Dmg", 13, TEXT_MUTED))
		var dmg_spin = SpinBox.new()
		dmg_spin.min_value = 0
		dmg_spin.max_value = 9999
		dmg_spin.value = 0
		dmg_spin.custom_minimum_size = Vector2(55, 0)
		dmg_spin.add_theme_font_size_override("font_size", 36)
		fields.add_child(dmg_spin)

		# Type
		fields.add_child(_lbl("Type", 13, TEXT_MUTED))
		var type_opt = OptionButton.new()
		type_opt.add_item("Damage")
		type_opt.add_item("Healed")
		type_opt.add_item("Shielded")
		type_opt.custom_minimum_size = Vector2(55, 0)
		type_opt.add_theme_font_size_override("font_size", 36)
		fields.add_child(type_opt)

		# Hit Shield checkbox (below the grid)
		var shield_check = CheckButton.new()
		shield_check.text = "Hit Shield"
		shield_check.add_theme_font_size_override("font_size", 36)
		shield_check.add_theme_color_override("font_color", TEXT_PRIMARY if has_shield else TEXT_MUTED)
		shield_check.disabled = not has_shield
		vbox.add_child(shield_check)

		# Store metadata
		card.set_meta("target_name", target_name)
		card.set_meta("target_table", t_table)
		card.set_meta("target_id", t_id)
		card.set_meta("roll_spin", roll_spin)
		card.set_meta("hits_spin", hits_spin)
		card.set_meta("dmg_spin", dmg_spin)
		card.set_meta("type_opt", type_opt)
		card.set_meta("shield_check", shield_check)


# =============================================================================
#  Stun / Skip Turn
# =============================================================================

func _is_stunned(b_name: String) -> bool:
	var effects = Global.get_battler_effects(b_name)
	for fx in effects:
		if fx.get("effect_type") in ["SKIP_TURN", "FREEZE"]:
			return true
	return false


func _show_stun_overlay():
	_stun_title.text = "%s's turn is skipped!" % str(Current_Turn)
	_stun_text.text = "Stunned -- cannot act this turn"
	_stun_overlay.visible = true


func _on_stun_confirm():
	if NetworkManager.is_host:
		# Host can process cooldowns directly
		var updates = []
		TurnProcessor._process_cooldowns(str(Current_Turn), updates)
		if updates.size() > 0:
			Global.Update_Records(updates)
		if Global.effect_processor:
			Global.sync_active_effects()
	else:
		# Player client: ask host to process cooldowns for this stunned battler
		NetworkManager.host_combat_log({"type": "stun_skip", "battler": str(Current_Turn)})
	_stun_overlay.visible = false
	_advance_turn()


# =============================================================================
#  Battle End
# =============================================================================

func check_battle_end():
	if _battle_ending:
		return

	# Strict semantics: an empty side does NOT mean "all dead" — it means
	# we don't have data to judge. The battle ends only when there is at
	# least one entity on a side AND every entity on that side is at 0 HP
	# (Killed for enemies). Initializing both flags from .size() > 0
	# guards against vacuous-true triggers during any moment when
	# BATTLEENEMIES or PartyCharacters reads empty (sync race during
	# the first end-of-turn broadcast, BattleManager momentarily inactive,
	# stale clear between battles, etc.). Future Update_Records broadcasts
	# will re-fire this check once the data populates.
	var enemies: Array = Global.BATTLEENEMIES.values()
	var players: Array = Global.PartyCharacters

	var all_enemies_dead = enemies.size() > 0
	for enemy in enemies:
		if int(enemy.get("Current_Health", 1)) > 0 and not bool(enemy.get("Killed", false)):
			all_enemies_dead = false
			break

	var all_players_down = players.size() > 0
	for player_name in players:
		var char_id = Global.CHARACTERS_NAME.get(player_name, "")
		if int(Global.CHARACTERS.get(char_id, {}).get("Current_Health", 1)) > 0:
			all_players_down = false
			break

	if all_enemies_dead or all_players_down:
		_battle_ending = true
		if NetworkManager.is_host or Global.is_offline:
			# Wait briefly for any pending player turn log RPCs to arrive
			# (the killing blow's log may be in-flight from a player client)
			await get_tree().create_timer(1.0).timeout
			# Generate summary
			var summary = {}
			if _battle_logger:
				summary = _battle_logger.end_battle()

			# Snapshot enemies for loot calc before cleanup removes them
			var enemy_snapshot: Array = []
			for enemy in Global.BATTLEENEMIES.values():
				var enemy_name = str(enemy.get("EnemyName", enemy.get("Enemy_Name", enemy.get("Name", ""))))
				var enemy_def = GameDB.enemies_by_name.get(enemy_name, null)
				if enemy_def:
					enemy_snapshot.append({"tier": enemy_def.tier})
					print("Loot: enemy '%s' tier=%s" % [enemy_name, enemy_def.tier])
				else:
					enemy_snapshot.append({"tier": "common"})
					push_warning("Loot: enemy '%s' not found in GameDB — defaulting to common" % enemy_name)

			_host_battle_cleanup()
			_show_challenge_confirmation(summary, enemy_snapshot)
		else:
			# Wait for the host to send the battle summary RPC.
			# The DM may need time to confirm the challenge quest, so wait generously.
			# The summary RPC handler (_on_battle_summary_received) sets _battle_ending_summary_shown.
			for i in range(60):  # Up to 60 seconds
				await get_tree().create_timer(1.0).timeout
				if _battle_ending_summary_shown:
					break
			if not _battle_ending_summary_shown:
				_go_to_hub()


func _show_challenge_confirmation(summary: Dictionary, enemy_snapshot: Array) -> void:
	var quest = Global.active_challenge_quest
	if quest.is_empty():
		_finalize_battle_summary(summary, enemy_snapshot, false)
		return

	var popup = AcceptDialog.new()
	popup.title = "Challenge Quest"
	popup.dialog_text = "Challenge: %s\n\nQuest Giver: %s (%s)\n\nDid the party complete this challenge?" % [
		str(quest.get("challenge_text", "")),
		str(quest.get("quest_giver_name", "")),
		str(quest.get("quest_giver_personality", "")),
	]
	popup.ok_button_text = "Yes — Completed"
	popup.add_cancel_button("No — Failed")
	popup.confirmed.connect(func(): _finalize_battle_summary(summary, enemy_snapshot, true); popup.queue_free())
	popup.canceled.connect(func(): _finalize_battle_summary(summary, enemy_snapshot, false); popup.queue_free())
	add_child(popup)
	popup.popup_centered(Vector2(450, 250))


func _finalize_battle_summary(summary: Dictionary, enemy_snapshot: Array, challenge_completed: bool) -> void:
	var loot = LootGenerator.generate_all_loot(enemy_snapshot, Global.Current_Region)

	if challenge_completed and not Global.active_challenge_quest.is_empty():
		var multiplier: float = float(Global.active_challenge_quest.get("reward_multiplier", 1.0))
		var quest_loot = LootGenerator.generate_all_loot(enemy_snapshot, Global.Current_Region)
		for player_name in quest_loot:
			if player_name not in loot:
				loot[player_name] = {}
			for mat_name in quest_loot[player_name]:
				var bonus_qty: int = int(ceil(quest_loot[player_name][mat_name] * multiplier))
				loot[player_name][mat_name] = loot[player_name].get(mat_name, 0) + bonus_qty
		summary["challenge_completed"] = true
	else:
		summary["challenge_completed"] = false

	_persist_loot(loot)
	summary["player_loot"] = loot
	summary["difficulty_score"] = LootGenerator.calc_difficulty_score(enemy_snapshot)
	var tier_data = LootGenerator.get_loot_tier(summary["difficulty_score"])
	summary["loot_tier"] = tier_data["tier"] if tier_data else "Nothing"
	summary["challenge_quest"] = Global.active_challenge_quest.get("challenge_text", "")
	summary["challenge_quest_full"] = Global.active_challenge_quest.duplicate()

	# Clear current quest and generate a fresh one for next battle
	var next_quest = ChallengeQuestGenerator.generate()
	Global.active_challenge_quest = next_quest.to_dict()
	NetworkManager.broadcast_table_update("Party")

	# Process expedition returns so results show on summary screen
	_process_expedition_returns()
	# Include expedition results in the summary so all clients see them
	if Global._expedition_results.size() > 0:
		summary["expedition_results"] = Global._expedition_results

	# Force full table sync for loot tables so all clients have the latest items
	NetworkManager.broadcast_table_update("Character_Items")

	if not summary.is_empty():
		NetworkManager.broadcast_battle_summary(summary)
	_show_battle_summary(summary)


func _process_expedition_returns() -> void:
	# Load from Party record (synced) or Global fallback
	var party = Global.Current_Party
	var assignments = Global.get("_expedition_assignments")
	var pool = Global.get("_expedition_pool")

	if party:
		var assign_json = str(party.get("Expedition_Assignments", ""))
		if assign_json != "":
			var parsed = JSON.parse_string(assign_json)
			if parsed is Dictionary and not parsed.is_empty():
				assignments = parsed
		var pool_json = str(party.get("Expedition_Pool", ""))
		if pool_json != "":
			var parsed = JSON.parse_string(pool_json)
			if parsed is Array and parsed.size() > 0:
				pool = parsed

	if not assignments is Dictionary or assignments.is_empty():
		return
	if not pool is Array or pool.is_empty():
		return
	var results: Array = []
	for idx_key in assignments:
		var idx = int(idx_key)
		if idx >= pool.size():
			continue
		var exp = ExpeditionData.from_dict(pool[idx])
		# Assignments can be a single string (old format) or an array (new format)
		var assigned_val = assignments[idx_key]
		var comp_names: Array = []
		if assigned_val is Array:
			comp_names = assigned_val
		elif assigned_val is String and assigned_val != "":
			comp_names = [assigned_val]
		if comp_names.is_empty():
			continue

		# Resolve companion data dicts
		var comp_datas: Array = []
		var companion_labels: Array = []
		var owner_name: String = ""
		for comp_name in comp_names:
			for comp in Global.COMPANIONS.values():
				if str(comp.get("Name", "")) == comp_name:
					comp_datas.append(comp)
					companion_labels.append(comp_name)
					if owner_name == "":
						var o = comp.get("Owner")
						if o != null and str(o) != "" and str(o) != "null":
							owner_name = str(o)
					break
		# Fallback: if no companion has an owner, use the first player in party
		if owner_name == "" or owner_name == "null":
			for ch in Global.CHARACTERS.values():
				if str(ch.get("User_Type", ch.get("UserType", ""))) != "Dungeon Master":
					owner_name = str(ch.get("Name", ""))
					break
		if comp_datas.is_empty():
			continue

		var exp_loot = ExpeditionManager.process_multi_results(exp, comp_datas)
		var bonus_total: float = exp_loot.get("_bonus_total", 1.0)
		var bonus_list: Array = exp_loot.get("_bonuses", [])
		var failed: bool = exp_loot.get("_failed", false)
		var clean_loot: Dictionary = {}
		for k in exp_loot:
			if not str(k).begins_with("_"):
				clean_loot[k] = exp_loot[k]

		var result_entry = {
			"expedition": exp.expedition_name,
			"companion": ", ".join(companion_labels),
			"owner": owner_name,
			"loot": clean_loot,
			"failed": failed,
			"bonus_total": bonus_total,
			"bonuses": bonus_list,
		}
		results.append(result_entry)
		if not failed:
			for mat_name in clean_loot:
				_persist_expedition_item(owner_name if owner_name != "" else companion_labels[0], mat_name, clean_loot[mat_name])
	Global._expedition_results = results
	Global._expedition_assignments = {}

	# Generate a fresh expedition pool host-side so every player sees the same
	# list on returning to the hub (instead of each player rolling their own
	# when they first open the panel).
	var new_pool = ExpeditionManager.generate_pool(Global.Current_Region)
	var new_pool_dicts: Array = []
	for exp in new_pool:
		new_pool_dicts.append(exp.to_dict())
	Global._expedition_pool = new_pool_dicts

	# Persist to Party record (broadcasts to all clients via Update_Records).
	if party and party.get("id") != null:
		var party_id = int(party.get("id"))
		Global.Update_Records([
			{"table": "Party", "record_id": party_id, "field": "Expedition_Pool", "value": JSON.stringify(new_pool_dicts)},
			{"table": "Party", "record_id": party_id, "field": "Expedition_Assignments", "value": ""},
		])

func _persist_expedition_item(owner_name: String, mat_name: String, qty: int) -> void:
	if owner_name == "" or owner_name == "null":
		push_warning("Expedition: No owner for loot '%s' x%d — skipping" % [mat_name, qty])
		return
	if qty <= 0:
		return
	print("Expedition: Giving %s x%d to %s" % [mat_name, qty, owner_name])

	# Match existing item — same pattern as DMHub._process_items
	var found := false
	for record_id in Global.CHARACTER_ITEMS.keys():
		var rec: Dictionary = Global.CHARACTER_ITEMS[record_id]
		var rec_owner = str(rec.get("Owner", ""))
		var rec_name = str(rec.get("Name", ""))
		if rec_owner == owner_name and rec_name == mat_name:
			var old_qty: int = int(float(rec.get("Quantity", 0)))
			print("Expedition: Found existing record id=%s, old_qty=%d, new_qty=%d" % [record_id, old_qty, old_qty + qty])
			Global.Update_Records([{
				"table": "Character_Items",
				"record_id": int(record_id),
				"field": "Quantity",
				"value": old_qty + qty
			}])
			found = true
			break

	if found:
		return

	# New item — insert using same approach as DMHub
	var item_def = GameDB.items_by_name.get(mat_name, null)
	print("Expedition: No existing record, inserting new item (item_def found: %s)" % str(item_def != null))
	var columns := ["Owner", "Name", "Quantity", "Type", "Description", "Rarity"]
	var values := [
		owner_name,
		mat_name,
		qty,
		item_def.type if item_def else "Material",
		item_def.description if item_def else "",
		item_def.rarity if item_def else "Common",
	]
	print("Expedition: Insert columns=%s values=%s" % [str(columns), str(values)])
	Global.Insert("Character_Items", columns, values)


func _host_battle_cleanup() -> void:
	for enemy in Global.BATTLEENEMIES.values():
		Global._remove_record("BattleEnemies", str(int(enemy.get("id", 0))))
	DataStore.persist_table("BattleEnemies")

	var updates = []
	for ability in Global.ACTIVE_ABILITIES.values():
		if ability.get("Ability_Cooldown", 0) > 0:
			updates.append({"table": "Active_Abilities", "record_id": ability.get("id"), "field": "Ability_Cooldown", "value": 0})
	for char in Global.CHARACTERS.values():
		var cid = int(char.get("id", 0))
		updates.append({"table": "Characters", "record_id": cid, "field": "Ready", "value": false})
		updates.append({"table": "Characters", "record_id": cid, "field": "Applied_Element", "value": "None"})
		updates.append({"table": "Characters", "record_id": cid, "field": "Current_Health", "value": char.get("Max_Health", 0)})
		updates.append({"table": "Characters", "record_id": cid, "field": "Skipped", "value": false})
	for comp in Global.COMPANIONS.values():
		updates.append({"table": "Companions", "record_id": int(comp.get("id", 0)), "field": "Applied_Element", "value": "None"})

	var buff_left = int(Global.Current_Party.get("Buff_Battles_Left", 0))
	if buff_left - 1 <= 0:
		updates.append({"table": "Party", "record_id": Global.Current_Party.get("id"), "field": "Buff_Battles_Left", "value": 0})
		updates.append({"table": "Party", "record_id": Global.Current_Party.get("id"), "field": "Active_Food_Buff", "value": "None"})
	else:
		updates.append({"table": "Party", "record_id": Global.Current_Party.get("id"), "field": "Buff_Battles_Left", "value": buff_left - 1})

	if updates.size() > 0:
		Global.Update_Records(updates)

	_assign_fixed_roles()
	NetworkManager.broadcast_table_update("Characters")
	NetworkManager.broadcast_table_update("BattleEnemies")
	Global.end_battle_effects()
	# Don't call _go_to_hub() here — let the summary screen handle it


func _persist_loot(loot: Dictionary) -> void:
	for player_name in loot:
		var player_loot: Dictionary = loot[player_name]
		for mat_name in player_loot:
			_persist_expedition_item(player_name, mat_name, int(player_loot[mat_name]))


## Roles are fixed per player at the group's request — no rotation. Brian C.
## stays Artisan (crafting flow), Dylan stays Blacksmith, Brian F. stays Scout.
## Any new player not in this map gets no role until they're added.
const FIXED_ROLES := {
	"Brian C.": "Artisan",
	"Dylan": "Blacksmith",
	"Brian F.": "Scout",
}

func _assign_fixed_roles() -> void:
	var updates: Array = []
	for char in Global.CHARACTERS.values():
		if str(char.get("User_Type", "")) == "Dungeon Master":
			continue
		var pname: String = str(char.get("Name", ""))
		if not FIXED_ROLES.has(pname):
			continue
		updates.append({
			"table": "Characters",
			"record_id": int(char.get("id", 0)),
			"field": "Role",
			"value": FIXED_ROLES[pname],
		})
	if updates.size() > 0:
		Global.Update_Records(updates)


func _on_battle_summary_received(summary: Dictionary) -> void:
	# Client received battle summary from host — show it
	_show_battle_summary(summary)


func _on_combat_log_received(payload: Dictionary) -> void:
	if payload.get("type") == "turn_log":
		# Player turn log — feed to BattleLogger
		if _battle_logger:
			var input = payload.get("input", {})
			var results = payload.get("results", {})
			if not input.is_empty():
				_battle_logger.log_turn(input, results)
	elif payload.get("type") == "stun_skip":
		# Player's stunned battler — host processes cooldowns on their behalf
		var b_name = str(payload.get("battler", ""))
		if b_name != "" and Global.effect_processor:
			var updates = []
			TurnProcessor._process_cooldowns(b_name, updates)
			if updates.size() > 0:
				Global.Update_Records(updates)
			Global.sync_active_effects()
			print("[BattleScene] Host processed stun skip for %s" % b_name)


func _show_battle_summary(summary: Dictionary) -> void:
	if summary.is_empty():
		_go_to_hub()
		return
	_battle_ending_summary_shown = true
	var overlay = BattleSummary.new()
	add_child(overlay)
	overlay.show_summary(summary)
	overlay.continue_pressed.connect(_go_to_hub)


func _go_to_hub() -> void:
	Toast.notify("Battle ended -- returning to hub", Toast.SUCCESS)
	Global._returned_from_battle = true
	if Global.ACTIVE_USER_TYPE == "Player":
		get_tree().change_scene_to_file("res://Scenes/player_hub.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/DMHub.tscn")


# =============================================================================
#  Background
# =============================================================================

func _set_background():
	Global.Current_Region = Global.Current_Party.get("Current_Region", Global.Current_Region)
	var path = "res://Background Images/BattleScene/" + Global.Current_Region + ".png"
	if ResourceLoader.exists(path):
		_background.texture = load(path)


# =============================================================================
#  Music
# =============================================================================

func _start_music():
	_apply_saved_volume()
	_load_region_music(Global.Current_Region)
	_play_next_track()

func _apply_saved_volume() -> void:
	var cfg = ConfigFile.new()
	var vol = 0.0
	if cfg.load("user://audio_settings.cfg") == OK:
		vol = cfg.get_value("audio", "music_volume", 0.0)
	var bus_idx = AudioServer.get_bus_index("Master")
	if vol <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(vol / 100.0))


func _load_region_music(region: String) -> void:
	music_files.clear()
	var folder_path = "res://Background Music/%s/Battle HUB/" % region
	var dir = DirAccess.open(folder_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".import"):
			var new_file_name = file_name.left(file_name.length() - 7)
			music_files.append(folder_path + new_file_name)
		elif file_name.ends_with(".ogg") or file_name.ends_with(".mp3") or file_name.ends_with(".wav"):
			music_files.append(folder_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _play_next_track():
	if music_files.is_empty():
		return
	music_index = randi() % music_files.size()
	var stream_path = music_files[music_index]
	var stream = load(stream_path)
	if stream:
		_audio.stream = stream
		_audio.play()


func _on_audio_finished() -> void:
	_play_next_track()


# =============================================================================
#  Item Selection Handler
# =============================================================================

func _on_item_selected(index: int):
	var item_name = _item_select.get_item_text(index)
	if item_name == "None":
		_item_desc.text = "No item selected"
		return
	for item in Global.CHARACTER_ITEMS.values():
		if item.get("Name") == item_name and item.get("Owner") == str(Current_Turn):
			_item_desc.text = str(item.get("Description", ""))
			return


# =============================================================================
#  Burst / Food Buff Display
# =============================================================================

func _update_burst_display():
	if Global.Current_Battler_Data != null:
		var bc = Global.Current_Battler_Data.get("burst_charges", 0)
		var mbc = Global.Current_Battler_Data.get("max_burst_charges", 0)
		_burst_count_label.text = "%d / %d" % [int(bc) if bc != null else 0, int(mbc) if mbc != null else 0]
	else:
		_burst_count_label.text = "0 / 0"


func _update_food_buff():
	var buff = Global.Current_Party.get("Active_Food_Buff", "None")
	if buff != "None" and buff != null:
		_food_buff_label.text = str(buff)
		for item in Global.ITEMS.values():
			if item.get("Item") == buff:
				_food_buff_label.tooltip_text = str(item.get("Description", ""))
				return
	else:
		_food_buff_label.text = "No buff"
		_food_buff_label.tooltip_text = ""


# =============================================================================
#  Reset Inputs
# =============================================================================

func _reset_inputs():
	for child in _results_container.get_children():
		child.queue_free()
	_target_list.deselect_all()
	_attack_select.selected = 0 if _attack_select.item_count > 0 else -1
	for c in _ability_info_box.get_children():
		c.queue_free()
	_ability_info_box.visible = false
	_attack_roll_spin.value = 0
	_tiles_moved_spin.value = 0
	_burst_gained_spin.value = 0
	_passive_stacks_spin.value = 0
	_crit_toggle.button_pressed = false
	_item_select.selected = 0 if _item_select.item_count > 0 else -1
	_item_desc.text = "No item selected"


# =============================================================================
#  Utility
# =============================================================================

func _wrap_text(text: String, limit: int) -> String:
	var result = ""
	var start = 0
	while start < text.length():
		var end = min(start + limit, text.length())
		if end < text.length():
			var segment = text.substr(start, end - start)
			var space_index = segment.rfind(" ")
			if space_index != -1:
				end = start + space_index + 1
		result += text.substr(start, end - start).strip_edges()
		if end < text.length():
			result += "\n"
		start = end
	return result


# =============================================================================
#  DM Hub (mid-battle access)
# =============================================================================

var _dm_hub_window: Window = null

func _on_dm_hub_pressed() -> void:
	if _dm_hub_window != null and is_instance_valid(_dm_hub_window):
		_dm_hub_window.grab_focus()
		return
	_dm_hub_window = Window.new()
	_dm_hub_window.title = "DM Hub"
	var screen_size = DisplayServer.screen_get_size()
	_dm_hub_window.size = Vector2i(int(screen_size.x * 0.98), int(screen_size.y * 0.9))
	_dm_hub_window.transient = true
	_dm_hub_window.close_requested.connect(_on_dm_hub_closed)
	add_child(_dm_hub_window)
	var dm_scene = load("res://Scenes/DMHub.tscn")
	if dm_scene:
		var dm_instance = dm_scene.instantiate()
		_dm_hub_window.add_child(dm_instance)
	_dm_hub_window.popup_centered()

func _on_dm_hub_closed() -> void:
	if _dm_hub_window != null:
		_dm_hub_window.queue_free()
		_dm_hub_window = null
	# Refresh battle state after DM changes
	_refresh_enemies()
	_refresh_party()

# =============================================================================
#  Layout Persistence
# =============================================================================

func _save_layout() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("splits", "outer", _outer_split.split_offset)
	cfg.set_value("splits", "inner", _inner_split.split_offset)
	cfg.set_value("splits", "center", _center_split.split_offset)
	cfg.set_value("splits", "party", _party_split.split_offset)
	cfg.set_value("splits", "info", _info_split.split_offset)
	cfg.set_value("splits", "dock", _dock_split.split_offset)
	cfg.set_value("splits", "atk_h_l", _attack_hsplit_l.split_offset)
	cfg.set_value("splits", "atk_h_r", _attack_hsplit_r.split_offset)
	cfg.set_value("splits", "target_v", _target_vsplit.split_offset)
	cfg.save(LAYOUT_SAVE_PATH)


func _load_layout() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(LAYOUT_SAVE_PATH) != OK:
		return
	if cfg.has_section_key("splits", "outer"):
		_outer_split.split_offset = cfg.get_value("splits", "outer", 0)
	if cfg.has_section_key("splits", "inner"):
		_inner_split.split_offset = cfg.get_value("splits", "inner", 0)
	if cfg.has_section_key("splits", "center"):
		_center_split.split_offset = cfg.get_value("splits", "center", 0)
	if cfg.has_section_key("splits", "party"):
		_party_split.split_offset = cfg.get_value("splits", "party", 0)
	if cfg.has_section_key("splits", "info"):
		_info_split.split_offset = cfg.get_value("splits", "info", 0)
	if cfg.has_section_key("splits", "dock"):
		_dock_split.split_offset = cfg.get_value("splits", "dock", 0)
	if cfg.has_section_key("splits", "atk_h_l"):
		_attack_hsplit_l.split_offset = cfg.get_value("splits", "atk_h_l", 0)
	if cfg.has_section_key("splits", "atk_h_r"):
		_attack_hsplit_r.split_offset = cfg.get_value("splits", "atk_h_r", 0)
	if cfg.has_section_key("splits", "target_v"):
		_target_vsplit.split_offset = cfg.get_value("splits", "target_v", 0)
