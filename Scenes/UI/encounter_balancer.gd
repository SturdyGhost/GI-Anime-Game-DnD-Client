extends PanelContainer
## Encounter Balancer — DM tool for tuning enemy stats against difficulty tier profiles.

signal panel_closed

# --- Theme colours (shared with battle simulator) ---
const BG_COLOR       := Color(0.102, 0.122, 0.169)
const CARD_BG        := Color(0.118, 0.141, 0.176)
const CARD_BORDER    := Color(0.165, 0.188, 0.282)
const GOLD           := Color(0.788, 0.659, 0.298)
const GREEN          := Color(0.292, 0.855, 0.498)
const RED            := Color(0.937, 0.267, 0.267)
const YELLOW         := Color(0.937, 0.835, 0.267)
const BLUE           := Color(0.353, 0.478, 0.710)
const MUTED          := Color(0.478, 0.514, 0.627)
const TEXT_COLOR     := Color(0.941, 0.949, 0.973)

const BAR_COLORS := [
	Color(0.353, 0.478, 0.710), Color(0.788, 0.659, 0.298),
	Color(0.292, 0.855, 0.498), Color(0.937, 0.267, 0.267),
	Color(0.608, 0.392, 0.714), Color(0.259, 0.710, 0.710),
]

# --- State ---
var _selected_enemy_id: int = -1
var _enemy_count: int = 1
var _selected_tier: String = "Boss"
var _player_dmg_mod: float = 1.0
var _enemy_dmg_mod: float = 1.0
var _battle_count: int = 1000

# --- UI refs (left panel) ---
var _enemy_dropdown: OptionButton
var _enemy_search: LineEdit
var _enemy_count_spin: SpinBox
var _enemy_info_vbox: VBoxContainer
var _tier_buttons: Dictionary = {}  # tier_name → Button
var _profile_display: VBoxContainer
var _battle_spin: SpinBox
var _player_dmg_slider: HSlider
var _player_dmg_label: Label
var _enemy_dmg_slider: HSlider
var _enemy_dmg_label: Label
var _run_btn: Button
var _stop_btn: Button

# --- UI refs (right panel) ---
var _results_scroll: ScrollContainer
var _results_vbox: VBoxContainer
var _verdict_label: Label
var _verdict_panel: PanelContainer
var _win_rate_label: Label
var _wipe_rate_label: Label
var _avg_rounds_label: Label
var _comparison_vbox: VBoxContainer
var _suggestions_vbox: VBoxContainer
var _party_table: VBoxContainer
var _progress_bar: ProgressBar

var _runner: BattleSimBulkRunner = null
var _last_results: Dictionary = {}


# ===============================================
#  Lifecycle
# ===============================================

func _ready() -> void:
	# Force panel to fill the entire window
	var vp_size := get_viewport_rect().size
	if vp_size.x < 100:
		vp_size = Vector2(1920, 1080)
	custom_minimum_size = vp_size
	size = vp_size
	position = Vector2.ZERO

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = BG_COLOR
	add_theme_stylebox_override("panel", bg_sb)

	_build_ui()
	_populate_enemies()
	_select_tier("Boss")


# ===============================================
#  UI Construction
# ===============================================

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# -- Title bar --
	var title_bar := _make_hbox(8)
	title_bar.add_theme_constant_override("separation", 12)
	root.add_child(title_bar)

	var title_lbl := _lbl("Encounter Balancer", 22, GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "X  Close"
	close_btn.pressed.connect(func(): panel_closed.emit(); queue_free())
	_style_button(close_btn, Color(0.6, 0.2, 0.2, 0.8))
	title_bar.add_child(close_btn)

	# -- Main split --
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 380
	root.add_child(split)

	# Left panel (setup)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 850
	left_scroll.size_flags_horizontal = Control.SIZE_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_scroll)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_vbox)

	_build_enemy_config(left_vbox)
	_build_tier_selector(left_vbox)
	_build_sim_config(left_vbox)

	# Right panel (results)
	_results_scroll = ScrollContainer.new()
	_results_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_results_scroll)

	_results_vbox = VBoxContainer.new()
	_results_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_vbox.add_theme_constant_override("separation", 10)
	_results_scroll.add_child(_results_vbox)

	_build_results_panel(_results_vbox)

	# -- Progress bar (bottom) --
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 20
	_progress_bar.value = 0
	_progress_bar.visible = false
	var pb_sb := StyleBoxFlat.new()
	pb_sb.bg_color = CARD_BG
	_progress_bar.add_theme_stylebox_override("background", pb_sb)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = GOLD
	_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	root.add_child(_progress_bar)


# -- Enemy Configuration card --

func _build_enemy_config(parent: VBoxContainer) -> void:
	var card := _make_card("Enemy Configuration")
	parent.add_child(card)
	var vbox: VBoxContainer = card.get_child(0)

	# Search filter
	_enemy_search = LineEdit.new()
	_enemy_search.placeholder_text = "Filter enemies..."
	_enemy_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_search.text_changed.connect(_on_enemy_search_changed)
	vbox.add_child(_enemy_search)

	# Enemy selector
	_enemy_dropdown = OptionButton.new()
	_enemy_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_dropdown.add_theme_color_override("font_color", TEXT_COLOR)
	_enemy_dropdown.item_selected.connect(_on_enemy_selected)
	vbox.add_child(_enemy_dropdown)

	# Count in encounter
	var count_row := _make_hbox(4)
	vbox.add_child(count_row)
	count_row.add_child(_lbl("Count in encounter:", 13, TEXT_COLOR))
	_enemy_count_spin = SpinBox.new()
	_enemy_count_spin.min_value = 1
	_enemy_count_spin.max_value = 10
	_enemy_count_spin.value = 1
	_enemy_count_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_count_spin.value_changed.connect(func(v):
		_enemy_count = int(v)
		_update_profile_display()
	)
	count_row.add_child(_enemy_count_spin)

	# Enemy info area (stats + abilities)
	_enemy_info_vbox = VBoxContainer.new()
	_enemy_info_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_enemy_info_vbox)


# -- Tier selector card --

func _build_tier_selector(parent: VBoxContainer) -> void:
	var card := _make_card("Target Difficulty Tier")
	parent.add_child(card)
	var vbox: VBoxContainer = card.get_child(0)

	# Tier button bar
	var btn_row := _make_hbox(4)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_row)

	for tier_name in TierProfiles.get_all_tiers():
		var btn := Button.new()
		btn.text = tier_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		_style_button(btn, Color(0.18, 0.20, 0.28, 0.9))
		btn.pressed.connect(_select_tier.bind(tier_name))
		btn_row.add_child(btn)
		_tier_buttons[tier_name] = btn

	# Profile display
	_profile_display = VBoxContainer.new()
	_profile_display.add_theme_constant_override("separation", 4)
	vbox.add_child(_profile_display)


# -- Simulation config card --

func _build_sim_config(parent: VBoxContainer) -> void:
	var card := _make_card("Simulation Config")
	parent.add_child(card)
	var vbox: VBoxContainer = card.get_child(0)

	# Battle count
	var bc_row := _make_hbox(4)
	vbox.add_child(bc_row)
	bc_row.add_child(_lbl("Battles:", 14, TEXT_COLOR))
	_battle_spin = SpinBox.new()
	_battle_spin.min_value = 10
	_battle_spin.max_value = 10000
	_battle_spin.step = 10
	_battle_spin.value = 1000
	_battle_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_spin.value_changed.connect(func(v): _battle_count = int(v))
	bc_row.add_child(_battle_spin)

	# Player damage modifier
	vbox.add_child(_lbl("Player Damage Modifier", 13, MUTED))
	var pd_row := _make_hbox(4)
	vbox.add_child(pd_row)
	_player_dmg_slider = HSlider.new()
	_player_dmg_slider.min_value = 0.1
	_player_dmg_slider.max_value = 5.0
	_player_dmg_slider.step = 0.05
	_player_dmg_slider.value = 1.0
	_player_dmg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pd_row.add_child(_player_dmg_slider)
	_player_dmg_label = _lbl("1.00x", 13, TEXT_COLOR)
	_player_dmg_label.custom_minimum_size.x = 44
	pd_row.add_child(_player_dmg_label)
	_player_dmg_slider.value_changed.connect(func(v):
		_player_dmg_mod = v
		_player_dmg_label.text = "%.2fx" % v
	)

	# Enemy damage modifier
	vbox.add_child(_lbl("Enemy Damage Modifier", 13, MUTED))
	var ed_row := _make_hbox(4)
	vbox.add_child(ed_row)
	_enemy_dmg_slider = HSlider.new()
	_enemy_dmg_slider.min_value = 0.1
	_enemy_dmg_slider.max_value = 5.0
	_enemy_dmg_slider.step = 0.05
	_enemy_dmg_slider.value = 1.0
	_enemy_dmg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed_row.add_child(_enemy_dmg_slider)
	_enemy_dmg_label = _lbl("1.00x", 13, TEXT_COLOR)
	_enemy_dmg_label.custom_minimum_size.x = 44
	ed_row.add_child(_enemy_dmg_label)
	_enemy_dmg_slider.value_changed.connect(func(v):
		_enemy_dmg_mod = v
		_enemy_dmg_label.text = "%.2fx" % v
	)

	# Buttons
	var btn_row := _make_hbox(8)
	vbox.add_child(btn_row)

	_run_btn = Button.new()
	_run_btn.text = "Run Simulation"
	_run_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_run_btn, Color(0.15, 0.4, 0.15, 0.9))
	_run_btn.pressed.connect(_on_run_simulation)
	btn_row.add_child(_run_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.disabled = true
	_style_button(_stop_btn, Color(0.5, 0.15, 0.15, 0.9))
	_stop_btn.pressed.connect(_on_stop_simulation)
	btn_row.add_child(_stop_btn)


# -- Results panel --

func _build_results_panel(parent: VBoxContainer) -> void:
	# Verdict banner
	_verdict_panel = PanelContainer.new()
	_verdict_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var verdict_sb := StyleBoxFlat.new()
	verdict_sb.bg_color = CARD_BG
	verdict_sb.border_color = MUTED
	verdict_sb.set_border_width_all(2)
	verdict_sb.set_corner_radius_all(6)
	verdict_sb.content_margin_left = 12
	verdict_sb.content_margin_right = 12
	verdict_sb.content_margin_top = 10
	verdict_sb.content_margin_bottom = 10
	_verdict_panel.add_theme_stylebox_override("panel", verdict_sb)
	parent.add_child(_verdict_panel)

	_verdict_label = _lbl("Run a simulation to see results", 16, MUTED)
	_verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict_panel.add_child(_verdict_label)

	# Summary stat boxes
	var summary_card := _make_card("Summary")
	parent.add_child(summary_card)
	var sum_vbox: VBoxContainer = summary_card.get_child(0)

	var sum_row := _make_hbox(12)
	sum_vbox.add_child(sum_row)

	var wr_box := _make_stat_box("Win Rate", "--")
	sum_row.add_child(wr_box)
	_win_rate_label = wr_box.get_child(1)

	var wipe_box := _make_stat_box("Total Wipes", "--")
	sum_row.add_child(wipe_box)
	_wipe_rate_label = wipe_box.get_child(1)

	var round_box := _make_stat_box("Avg Rounds", "--")
	sum_row.add_child(round_box)
	_avg_rounds_label = round_box.get_child(1)

	# Profile Comparison
	var comp_card := _make_card("Profile Comparison")
	parent.add_child(comp_card)
	_comparison_vbox = comp_card.get_child(0)

	# Advisory Suggestions
	var adv_card := _make_card("Advisory Suggestions")
	parent.add_child(adv_card)
	_suggestions_vbox = adv_card.get_child(0)

	# Advisory badge
	var badge_row := _make_hbox(4)
	_suggestions_vbox.add_child(badge_row)
	var badge := _lbl("Advisory Only", 11, GOLD)
	var badge_pc := PanelContainer.new()
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.788, 0.659, 0.298, 0.15)
	badge_sb.set_corner_radius_all(4)
	badge_sb.content_margin_left = 6
	badge_sb.content_margin_right = 6
	badge_sb.content_margin_top = 2
	badge_sb.content_margin_bottom = 2
	badge_pc.add_theme_stylebox_override("panel", badge_sb)
	badge_pc.add_child(badge)
	badge_row.add_child(badge_pc)

	# Party Performance table
	var perf_card := _make_card("Party Performance")
	parent.add_child(perf_card)
	_party_table = perf_card.get_child(0)


# ===============================================
#  Dropdown population
# ===============================================

func _populate_enemies(filter: String = "") -> void:
	_enemy_dropdown.clear()
	var lower_filter := filter.to_lower()
	for eid in GameDB.enemies:
		var e: EnemyData = GameDB.enemies[eid]
		if lower_filter != "" and e.name.to_lower().find(lower_filter) == -1:
			continue
		_enemy_dropdown.add_item("%s  [%s]" % [e.name, e.tier])
		_enemy_dropdown.set_item_metadata(_enemy_dropdown.item_count - 1, eid)
	if _enemy_dropdown.item_count > 0:
		_on_enemy_selected(0)


# ===============================================
#  Callbacks
# ===============================================

func _on_enemy_search_changed(text: String) -> void:
	_populate_enemies(text)


func _on_enemy_selected(idx: int) -> void:
	if idx < 0 or idx >= _enemy_dropdown.item_count:
		return
	_selected_enemy_id = _enemy_dropdown.get_item_metadata(idx)
	_update_enemy_info()


func _select_tier(tier_name: String) -> void:
	_selected_tier = tier_name
	# Update button states
	for tn in _tier_buttons:
		var btn: Button = _tier_buttons[tn]
		btn.button_pressed = (tn == tier_name)
		if tn == tier_name:
			_style_button(btn, Color(0.788, 0.659, 0.298, 0.3))
		else:
			_style_button(btn, Color(0.18, 0.20, 0.28, 0.9))
	_update_profile_display()


func _update_enemy_info() -> void:
	# Clear existing info
	for c in _enemy_info_vbox.get_children():
		c.queue_free()

	if _selected_enemy_id < 0:
		return

	var e: EnemyData = GameDB.enemies.get(_selected_enemy_id)
	if e == null:
		return

	# Show enemy stats
	_enemy_info_vbox.add_child(_lbl("--- Enemy Stats ---", 13, GOLD))

	var stats := [
		["Tier", e.tier],
		["Phase 1 HP", str(e.phase1_hp)],
		["HP per Phase", str(e.hp_per_phase) if e.hp_per_phase > 0 else "N/A"],
		["Phases", str(e.phase_count)],
		["Size", str(e.size_tiles) + " tiles"],
		["Turn Structure", e.turn_structure if e.turn_structure != "" else "Standard"],
	]
	if e.phase2_hp > 0:
		stats.append(["Phase 2 HP", str(e.phase2_hp)])
	if e.phase3_hp > 0:
		stats.append(["Phase 3 HP", str(e.phase3_hp)])
	if e.phase4_hp > 0:
		stats.append(["Phase 4 HP", str(e.phase4_hp)])

	for s in stats:
		var row := _make_hbox(4)
		_enemy_info_vbox.add_child(row)
		var key_lbl := _lbl(s[0] + ":", 12, MUTED)
		key_lbl.custom_minimum_size.x = 120
		row.add_child(key_lbl)
		row.add_child(_lbl(s[1], 12, TEXT_COLOR))

	# Show abilities
	var abilities: Array = []
	for a in GameDB.abilities_by_entity.values():
		if a.entity_type == "Enemy" and a.entity_id == _selected_enemy_id:
			abilities.append(a)

	if abilities.size() > 0:
		_enemy_info_vbox.add_child(_lbl("--- Abilities ---", 13, GOLD))
		for ab in abilities:
			var ab_text := "%s  (%dd%d" % [ab.name, ab.dice_count, ab.dice_die]
			if ab.dice_flat != 0:
				ab_text += "+%d" % ab.dice_flat
			ab_text += ")"
			if ab.element != "":
				ab_text += "  [%s]" % ab.element
			_enemy_info_vbox.add_child(_lbl(ab_text, 11, TEXT_COLOR))


func _update_profile_display() -> void:
	for c in _profile_display.get_children():
		c.queue_free()

	var profile := TierProfiles.get_profile(_selected_tier)
	profile = TierProfiles.scale_profile(profile, _enemy_count)

	_profile_display.add_child(_lbl(profile.get("description", ""), 12, MUTED))

	var targets := [
		["Target Win Rate", "%.0f%%" % float(profile.get("win_rate", 0))],
		["Target Wipe Rate", "%.0f%%" % float(profile.get("wipe_rate", 0))],
		["Revives Needed", "%.0f%%" % float(profile.get("revives_needed_rate", 0))],
		["Perma-Death Rate", "%.0f%%" % float(profile.get("perma_death_rate", 0))],
		["Expected Rounds", "%d-%d" % [profile.get("rounds_per_enemy", [0, 0])[0], profile.get("rounds_per_enemy", [0, 0])[1]]],
	]

	for t in targets:
		var row := _make_hbox(4)
		_profile_display.add_child(row)
		var key_lbl := _lbl(t[0] + ":", 12, MUTED)
		key_lbl.custom_minimum_size.x = 140
		row.add_child(key_lbl)
		row.add_child(_lbl(t[1], 12, GOLD))


func _on_run_simulation() -> void:
	if _selected_enemy_id < 0:
		return

	_run_btn.disabled = true
	_stop_btn.disabled = false
	_progress_bar.visible = true
	_progress_bar.value = 0

	var config := _build_config()
	_runner = BattleSimBulkRunner.new()
	add_child(_runner)
	_runner.simulation_progress.connect(_on_sim_progress)
	_runner.simulation_complete.connect(_on_sim_complete)
	_runner.run(config, _battle_count)


func _on_stop_simulation() -> void:
	if _runner != null:
		_runner.cancel()
	_stop_btn.disabled = true


func _on_sim_progress(completed: int, total: int) -> void:
	_progress_bar.value = float(completed) / float(total) * 100.0


func _on_sim_complete(results: Dictionary) -> void:
	_last_results = results
	_run_btn.disabled = false
	_stop_btn.disabled = true
	_progress_bar.visible = false

	if _runner != null:
		_runner.queue_free()
		_runner = null

	_display_results(results)


# ===============================================
#  Config builder (uses current party as-is)
# ===============================================

func _build_config() -> Dictionary:
	var party := []
	for pname in Global.PartyCharacters:
		var rid = Global.CHARACTERS_NAME.get(pname, "")
		if rid == "":
			continue
		var char_data: Dictionary = Global.CHARACTERS.get(rid, {}).duplicate(true)
		party.append({
			"name": pname,
			"character_data": char_data,
			"weapon_override": _get_equipped_weapon(pname),
			"artifact_overrides": _get_equipped_artifacts(pname),
			"companion_override": _get_equipped_companion(pname),
			"kit_override": null,
			"food_buff": "None",
		})
	return {
		"party": party,
		"enemies": [{"enemy_id": _selected_enemy_id, "count": _enemy_count}],
		"damage_modifier_players": _player_dmg_mod,
		"damage_modifier_enemies": _enemy_dmg_mod,
		"arena_size": 20,
	}


func _get_equipped_weapon(player_name: String):
	for rid in Global._synced.get("Character_Weapons", {}):
		var w: Dictionary = Global._synced["Character_Weapons"][rid]
		if w.get("Owner") == player_name and w.get("Equipped") == true:
			return w
	return null


func _get_equipped_artifacts(player_name: String) -> Array:
	var arts: Array = []
	for rid in Global._synced.get("Character_Artifacts", {}):
		var a: Dictionary = Global._synced["Character_Artifacts"][rid]
		if a.get("Owner") == player_name and a.get("Equipped") == true:
			arts.append(a)
	return arts


func _get_equipped_companion(player_name: String):
	for rid in Global._synced.get("Companions", {}):
		var c: Dictionary = Global._synced["Companions"][rid]
		if c.get("Owner") == player_name and c.get("Active") == true:
			return c
	return null


# ===============================================
#  Results display
# ===============================================

func _display_results(r: Dictionary) -> void:
	var n: float = maxf(float(r.get("battles_run", 1)), 1.0)

	# Get current tier profile (scaled for enemy count)
	var profile := TierProfiles.get_profile(_selected_tier)
	profile = TierProfiles.scale_profile(profile, _enemy_count)

	# Run advisor
	var analysis: Dictionary = BalanceAdvisor.analyze(r, profile)

	# Verdict banner
	_verdict_label.text = analysis.get("verdict", "")
	var verdict_level: String = analysis.get("verdict_level", "balanced")
	var verdict_color: Color
	match verdict_level:
		"too_easy":
			verdict_color = YELLOW
		"too_hard":
			verdict_color = RED
		_:
			verdict_color = GREEN
	_verdict_label.add_theme_color_override("font_color", verdict_color)
	# Update border color on verdict panel
	var vp_sb := _verdict_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	vp_sb.border_color = verdict_color
	_verdict_panel.add_theme_stylebox_override("panel", vp_sb)

	# Summary stats
	var wr: float = r.get("win_rate", 0.0)
	_win_rate_label.text = "%.1f%%" % wr
	_win_rate_label.add_theme_color_override("font_color", GREEN if wr >= 50.0 else RED)

	var wipe: float = r.get("wipe_rate", 0.0)
	_wipe_rate_label.text = "%.1f%%" % wipe
	_wipe_rate_label.add_theme_color_override("font_color", RED if wipe > 25.0 else GREEN)

	var avg_r: float = r.get("avg_rounds", 0.0)
	_avg_rounds_label.text = "%.1f" % avg_r
	_avg_rounds_label.add_theme_color_override("font_color", TEXT_COLOR)

	# Profile comparison bars
	_display_comparison(r, profile, n)

	# Advisory suggestions
	_display_suggestions(analysis)

	# Party performance
	_display_party_performance(r.get("per_battler", {}), n)


func _display_comparison(r: Dictionary, profile: Dictionary, n: float) -> void:
	# Clear existing bars (keep the title label)
	var children := _comparison_vbox.get_children()
	for i in range(children.size()):
		if children[i] is Label and children[i].text == "Profile Comparison":
			continue
		children[i].queue_free()

	var perma_death_rate := float(r.get("battles_with_perma_death", 0)) / n * 100.0
	var zero_death_pct := float(r.get("battles_with_zero_deaths", 0)) / n * 100.0

	var metrics := [
		{"label": "Win Rate", "actual": r.get("win_rate", 0.0), "target": profile.get("win_rate", 75.0)},
		{"label": "Wipe Rate", "actual": r.get("wipe_rate", 0.0), "target": profile.get("wipe_rate", 25.0)},
		{"label": "Perma-Deaths", "actual": perma_death_rate, "target": profile.get("perma_death_rate", 25.0)},
		{"label": "Clean Wins", "actual": zero_death_pct, "target": 100.0 - float(profile.get("revives_needed_rate", 50.0))},
	]

	for m in metrics:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_comparison_vbox.add_child(row)

		# Label row
		var label_row := _make_hbox(4)
		row.add_child(label_row)
		var name_lbl := _lbl(m["label"], 12, TEXT_COLOR)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_row.add_child(name_lbl)
		var val_lbl := _lbl("%.1f%% (target: %.0f%%)" % [m["actual"], m["target"]], 12, MUTED)
		label_row.add_child(val_lbl)

		# Bar with target marker
		var bar_container := Control.new()
		bar_container.custom_minimum_size = Vector2(0, 20)
		bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar_container)

		# Background
		var bar_bg := ColorRect.new()
		bar_bg.color = CARD_BORDER
		bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar_container.add_child(bar_bg)

		# Fill (actual value)
		var bar_fill := ColorRect.new()
		var actual_pct: float = clampf(float(m["actual"]) / 100.0, 0.0, 1.0)
		bar_fill.color = BLUE
		bar_fill.anchor_right = actual_pct
		bar_fill.anchor_bottom = 1.0
		bar_container.add_child(bar_fill)

		# Target marker (gold vertical line)
		var target_pct: float = clampf(float(m["target"]) / 100.0, 0.0, 1.0)
		var marker := ColorRect.new()
		marker.color = GOLD
		marker.anchor_left = target_pct
		marker.anchor_right = target_pct + 0.005
		marker.anchor_bottom = 1.0
		marker.custom_minimum_size.x = 3
		bar_container.add_child(marker)


func _display_suggestions(analysis: Dictionary) -> void:
	# Clear existing suggestion cards (keep title label + badge)
	var children := _suggestions_vbox.get_children()
	for i in range(children.size()):
		var child := children[i]
		# Keep the first two children (title label from _make_card + badge row)
		if i < 2:
			continue
		child.queue_free()

	var suggestions: Array = analysis.get("suggestions", [])
	for sug in suggestions:
		var sug_card := PanelContainer.new()
		sug_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sug_sb := StyleBoxFlat.new()
		sug_sb.bg_color = Color(0.14, 0.16, 0.22)
		sug_sb.border_color = CARD_BORDER
		sug_sb.set_border_width_all(1)
		sug_sb.set_corner_radius_all(4)
		sug_sb.content_margin_left = 10
		sug_sb.content_margin_right = 10
		sug_sb.content_margin_top = 8
		sug_sb.content_margin_bottom = 8
		sug_card.add_theme_stylebox_override("panel", sug_sb)
		_suggestions_vbox.add_child(sug_card)

		var sug_vbox := VBoxContainer.new()
		sug_vbox.add_theme_constant_override("separation", 4)
		sug_card.add_child(sug_vbox)

		var title_lbl := _lbl(str(sug.get("title", "")), 14, GOLD)
		sug_vbox.add_child(title_lbl)

		var desc_lbl := _lbl(str(sug.get("description", "")), 12, TEXT_COLOR)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sug_vbox.add_child(desc_lbl)


func _display_party_performance(per_battler: Dictionary, n: float) -> void:
	for c in _party_table.get_children():
		if c is Label and c.text == "Party Performance":
			continue
		c.queue_free()

	var headers := ["Battler", "Avg Dmg", "Avg Taken", "Absorbed", "Downs", "Deaths", "Revives", "Crits"]
	var header_row := _make_hbox(2)
	_party_table.add_child(header_row)
	for h in headers:
		var lbl := _lbl(h, 12, GOLD)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_row.add_child(lbl)

	# Compute averages for arrows
	var totals := {"avg_dmg": 0.0, "avg_taken": 0.0, "absorbed": 0.0, "downs": 0, "deaths": 0, "revives": 0, "crits": 0}
	var count := per_battler.size()
	for bname in per_battler:
		var b: Dictionary = per_battler[bname]
		totals["avg_dmg"]  += b.get("avg_damage_dealt", 0.0)
		totals["avg_taken"] += b.get("avg_damage_taken", 0.0)
		totals["absorbed"] += b.get("avg_damage_absorbed", 0.0)
		totals["downs"]    += int(b.get("total_downs", 0))
		totals["deaths"]   += int(b.get("total_deaths", 0))
		totals["revives"]  += int(b.get("total_revives_given", 0))
		totals["crits"]    += int(b.get("total_crits", 0))

	var avgs := {}
	if count > 0:
		for k in totals:
			avgs[k] = totals[k] / float(count)

	for bname in per_battler:
		var b: Dictionary = per_battler[bname]
		var row := _make_hbox(2)
		_party_table.add_child(row)

		var nl := _lbl(bname, 12, TEXT_COLOR)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(nl)

		var vals := [
			{"val": b.get("avg_damage_dealt", 0.0), "avg": avgs.get("avg_dmg", 0.0), "fmt": "%.0f", "higher_good": true},
			{"val": b.get("avg_damage_taken", 0.0), "avg": avgs.get("avg_taken", 0.0), "fmt": "%.0f", "higher_good": false},
			{"val": b.get("avg_damage_absorbed", 0.0), "avg": avgs.get("absorbed", 0.0), "fmt": "%.0f", "higher_good": true},
			{"val": float(b.get("total_downs", 0)), "avg": avgs.get("downs", 0.0), "fmt": "%.0f", "higher_good": false},
			{"val": float(b.get("total_deaths", 0)), "avg": avgs.get("deaths", 0.0), "fmt": "%.0f", "higher_good": false},
			{"val": float(b.get("total_revives_given", 0)), "avg": avgs.get("revives", 0.0), "fmt": "%.0f", "higher_good": true},
			{"val": float(b.get("total_crits", 0)), "avg": avgs.get("crits", 0.0), "fmt": "%.0f", "higher_good": true},
		]

		for v in vals:
			var text: String = v["fmt"] % v["val"]
			var arrow := ""
			var col := TEXT_COLOR
			if v["val"] > v["avg"] * 1.01:
				arrow = " ^"
				col = GREEN if v["higher_good"] else RED
			elif v["val"] < v["avg"] * 0.99:
				arrow = " v"
				col = RED if v["higher_good"] else GREEN
			var vl := _lbl(text + arrow, 12, col)
			vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(vl)


# ===============================================
#  UI helpers (same pattern as battle simulator)
# ===============================================

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_hbox(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _make_card(title: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	if title != "":
		var lbl := _lbl(title, 15, GOLD)
		vbox.add_child(lbl)

	return pc


func _make_stat_box(title: String, value_text: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_lbl := _lbl(title, 12, MUTED)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title_lbl)

	var val_lbl := _lbl(value_text, 22, TEXT_COLOR)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(val_lbl)

	return vb


func _style_button(btn: Button, bg_color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.set_corner_radius_all(4)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", 14)
