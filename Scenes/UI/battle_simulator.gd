extends PanelContainer
## Battle Simulator — full-screen sandbox for running bulk simulated battles.

signal panel_closed

# --- Theme colours ---
const BG_COLOR       := Color(0.102, 0.122, 0.169)
const CARD_BG        := Color(0.118, 0.141, 0.176)
const CARD_BORDER    := Color(0.165, 0.188, 0.282)
const GOLD           := Color(0.788, 0.659, 0.298)
const GREEN          := Color(0.292, 0.855, 0.498)
const RED            := Color(0.937, 0.267, 0.267)
const BLUE           := Color(0.353, 0.478, 0.710)
const MUTED          := Color(0.478, 0.514, 0.627)
const TEXT_COLOR     := Color(0.941, 0.949, 0.973)

# Damage bar palette
const BAR_COLORS := [
	Color(0.353, 0.478, 0.710), Color(0.788, 0.659, 0.298),
	Color(0.292, 0.855, 0.498), Color(0.937, 0.267, 0.267),
	Color(0.608, 0.392, 0.714), Color(0.259, 0.710, 0.710),
]

# --- Setup state ---
var _selected_enemies: Array = []   # [{enemy_id, enemy_name, count}]
var _kit_combos: Array = []         # [{element, weapon_type}]
var _selected_kit_idx: int = -1
var _companion_ids: Array = []
var _weapon_ids: Array = []
var _artifact_slots: Dictionary = {}  # type → {ids: [], selected_idx: int}
var _player_dmg_mod: float = 1.0
var _enemy_dmg_mod: float = 1.0
var _battle_count: int = 1000

# --- UI refs ---
var _enemy_list_vbox: VBoxContainer
var _enemy_search: LineEdit
var _enemy_dropdown: OptionButton
var _add_enemy_btn: Button
var _kit_dropdown: OptionButton
var _companion_dropdown: OptionButton
var _weapon_dropdown: OptionButton
var _artifact_dropdowns: Dictionary = {}  # type → OptionButton
var _battle_spin: SpinBox
var _player_dmg_slider: HSlider
var _player_dmg_label: Label
var _enemy_dmg_slider: HSlider
var _enemy_dmg_label: Label
var _run_btn: Button
var _stop_btn: Button
var _progress_bar: ProgressBar

# Results panel refs
var _results_scroll: ScrollContainer
var _results_vbox: VBoxContainer
var _win_rate_label: Label
var _wipe_rate_label: Label
var _avg_rounds_label: Label
var _damage_dist_container: VBoxContainer
var _party_table: VBoxContainer
var _ability_battler_dropdown: OptionButton
var _ability_table: VBoxContainer
var _stats_grid: GridContainer

var _runner: BattleSimBulkRunner = null
var _last_results: Dictionary = {}

# ── Artifact slot types (canonical order) ──
const ARTIFACT_TYPES := ["Flower of Life", "Feather of Death", "Sands of Time", "Goblet of Space", "Circlet of Principles"]

# ═══════════════════════════════════════════
#  Lifecycle
# ═══════════════════════════════════════════

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL

	# Panel background
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = BG_COLOR
	add_theme_stylebox_override("panel", bg_sb)

	_build_ui()
	_populate_dropdowns()


# ═══════════════════════════════════════════
#  UI Construction
# ═══════════════════════════════════════════

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Title bar ──
	var title_bar := _make_hbox(8)
	title_bar.add_theme_constant_override("separation", 12)
	root.add_child(title_bar)

	var title_lbl := _lbl("Battle Simulator", 22, GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "X  Close"
	close_btn.pressed.connect(func(): panel_closed.emit(); queue_free())
	_style_button(close_btn, Color(0.6, 0.2, 0.2, 0.8))
	title_bar.add_child(close_btn)

	# ── Main split ──
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 340
	root.add_child(split)

	# Left panel (setup)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size.x = 340
	left_scroll.size_flags_horizontal = Control.SIZE_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_scroll)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_vbox)

	_build_encounter_setup(left_vbox)
	_build_loadout_overrides(left_vbox)
	_build_sim_config_ui(left_vbox)

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

	# ── Progress bar (bottom) ──
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

# ── Encounter setup card ──

func _build_encounter_setup(parent: VBoxContainer) -> void:
	var card := _make_card("Encounter Setup")
	parent.add_child(card)
	var vbox: VBoxContainer = card.get_child(0)

	# Enemy search + add
	var add_row := _make_hbox(4)
	vbox.add_child(add_row)

	_enemy_dropdown = OptionButton.new()
	_enemy_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_dropdown.add_theme_color_override("font_color", TEXT_COLOR)
	add_row.add_child(_enemy_dropdown)

	_add_enemy_btn = Button.new()
	_add_enemy_btn.text = "Add"
	_style_button(_add_enemy_btn, Color(0.2, 0.35, 0.2, 0.9))
	_add_enemy_btn.pressed.connect(_on_add_enemy)
	add_row.add_child(_add_enemy_btn)

	# Search filter
	_enemy_search = LineEdit.new()
	_enemy_search.placeholder_text = "Filter enemies..."
	_enemy_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_search.text_changed.connect(_on_enemy_search_changed)
	vbox.add_child(_enemy_search)

	# Enemy list
	_enemy_list_vbox = VBoxContainer.new()
	_enemy_list_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_enemy_list_vbox)

# ── Loadout overrides card ──

func _build_loadout_overrides(parent: VBoxContainer) -> void:
	var card := _make_card("Loadout Overrides")
	parent.add_child(card)
	var vbox: VBoxContainer = card.get_child(0)

	# Kit selection
	vbox.add_child(_lbl("Kit (Element + Weapon)", 13, MUTED))
	_kit_dropdown = OptionButton.new()
	_kit_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_dropdown.item_selected.connect(_on_kit_changed)
	vbox.add_child(_kit_dropdown)

	# Companion
	vbox.add_child(_lbl("Companion", 13, MUTED))
	_companion_dropdown = OptionButton.new()
	_companion_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_companion_dropdown)

	# Weapon
	vbox.add_child(_lbl("Weapon", 13, MUTED))
	_weapon_dropdown = OptionButton.new()
	_weapon_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_weapon_dropdown)

	# Artifact slots
	vbox.add_child(_lbl("Artifacts", 13, MUTED))
	for art_type in ARTIFACT_TYPES:
		var row := _make_hbox(4)
		vbox.add_child(row)
		var type_lbl := _lbl(art_type, 12, TEXT_COLOR)
		type_lbl.custom_minimum_size.x = 130
		row.add_child(type_lbl)
		var dd := OptionButton.new()
		dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(dd)
		_artifact_dropdowns[art_type] = dd

	# Food buff — placeholder dropdown (no GameDB food table)
	vbox.add_child(_lbl("Food Buff", 13, MUTED))
	var food_dd := OptionButton.new()
	food_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_dd.add_item("None")
	# Populate from Character_Items owned by this player
	var items_dict: Dictionary = Global._synced.get("Character_Items", {})
	for rid in items_dict:
		var it: Dictionary = items_dict[rid]
		if it.get("Owner") == Global.ACTIVE_USER_NAME:
			var iname: String = str(it.get("Name", it.get("Item_Name", "Unknown")))
			food_dd.add_item(iname)
	vbox.add_child(food_dd)
	_artifact_dropdowns["Food"] = food_dd  # stash for easy retrieval

# ── Simulation config card ──

func _build_sim_config_ui(parent: VBoxContainer) -> void:
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
	_player_dmg_slider.min_value = 0.5
	_player_dmg_slider.max_value = 1.5
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
	_enemy_dmg_slider.min_value = 0.5
	_enemy_dmg_slider.max_value = 1.5
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

# ── Results panel ──

func _build_results_panel(parent: VBoxContainer) -> void:
	# Summary row
	var summary_card := _make_card("Summary")
	parent.add_child(summary_card)
	var sum_vbox: VBoxContainer = summary_card.get_child(0)

	var sum_row := _make_hbox(12)
	sum_vbox.add_child(sum_row)

	# Win Rate box
	var wr_box := _make_stat_box("Win Rate", "--")
	sum_row.add_child(wr_box)
	_win_rate_label = wr_box.get_child(1)

	# Wipe Rate box
	var wipe_box := _make_stat_box("Total Wipes", "--")
	sum_row.add_child(wipe_box)
	_wipe_rate_label = wipe_box.get_child(1)

	# Avg Rounds box
	var round_box := _make_stat_box("Avg Rounds", "--")
	sum_row.add_child(round_box)
	_avg_rounds_label = round_box.get_child(1)

	# Damage distribution
	var dist_card := _make_card("Damage Distribution")
	parent.add_child(dist_card)
	_damage_dist_container = dist_card.get_child(0)

	# Party Performance table
	var perf_card := _make_card("Party Performance")
	parent.add_child(perf_card)
	_party_table = perf_card.get_child(0)

	# Ability Breakdown
	var abil_card := _make_card("Ability Breakdown")
	parent.add_child(abil_card)
	var abil_vbox: VBoxContainer = abil_card.get_child(0)

	_ability_battler_dropdown = OptionButton.new()
	_ability_battler_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_battler_dropdown.item_selected.connect(_on_ability_battler_selected)
	abil_vbox.add_child(_ability_battler_dropdown)

	_ability_table = VBoxContainer.new()
	_ability_table.add_theme_constant_override("separation", 2)
	abil_vbox.add_child(_ability_table)

	# Battle Statistics
	var stats_card := _make_card("Battle Statistics")
	parent.add_child(stats_card)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 16)
	_stats_grid.add_theme_constant_override("v_separation", 6)
	stats_card.get_child(0).add_child(_stats_grid)

# ═══════════════════════════════════════════
#  Dropdown population
# ═══════════════════════════════════════════

func _populate_dropdowns() -> void:
	_populate_enemies()
	_populate_kits()
	_populate_companions()
	_populate_weapons()
	_populate_artifacts()


func _populate_enemies(filter: String = "") -> void:
	_enemy_dropdown.clear()
	var lower_filter := filter.to_lower()
	for eid in GameDB.enemies:
		var e: EnemyData = GameDB.enemies[eid]
		if lower_filter != "" and e.name.to_lower().find(lower_filter) == -1:
			continue
		_enemy_dropdown.add_item("%s  [%s]" % [e.name, e.tier])
		_enemy_dropdown.set_item_metadata(_enemy_dropdown.item_count - 1, eid)


func _populate_kits() -> void:
	_kit_dropdown.clear()
	_kit_combos.clear()
	_kit_dropdown.add_item("Current (no override)")
	for a in GameDB.abilities_by_entity.values():
		if a.entity_type == "Character" and a.entity_id == Global.ACTIVE_USER_RECORD_ID:
			var combo := {"element": a.kit_element, "weapon_type": a.weapon_type}
			if not _kit_combos.has(combo):
				_kit_combos.append(combo)
				_kit_dropdown.add_item("%s / %s" % [a.kit_element, a.weapon_type])


func _populate_companions() -> void:
	_companion_dropdown.clear()
	_companion_ids.clear()
	_companion_dropdown.add_item("Current (no override)")
	for rid in Global._synced.get("Companions", {}):
		var c: Dictionary = Global._synced["Companions"][rid]
		if c.get("Owner") == Global.ACTIVE_USER_NAME:
			_companion_ids.append(rid)
			_companion_dropdown.add_item(str(c.get("Name", "Companion %s" % rid)))


func _populate_weapons(filter_type: String = "") -> void:
	_weapon_dropdown.clear()
	_weapon_ids.clear()
	_weapon_dropdown.add_item("Current (no override)")
	for rid in Global._synced.get("Character_Weapons", {}):
		var w: Dictionary = Global._synced["Character_Weapons"][rid]
		if w.get("Owner") == Global.ACTIVE_USER_NAME:
			if filter_type != "" and str(w.get("Type", "")) != filter_type:
				continue
			_weapon_ids.append(rid)
			var wname: String = str(w.get("Name", "Weapon %s" % rid))
			var wtype: String = str(w.get("Type", ""))
			_weapon_dropdown.add_item("%s (%s)" % [wname, wtype])


func _populate_artifacts() -> void:
	for art_type in ARTIFACT_TYPES:
		var dd: OptionButton = _artifact_dropdowns[art_type]
		dd.clear()
		dd.add_item("Current (no override)")
		_artifact_slots[art_type] = {"ids": [], "selected_idx": 0}
		for rid in Global._synced.get("Character_Artifacts", {}):
			var a: Dictionary = Global._synced["Character_Artifacts"][rid]
			if a.get("Owner") == Global.ACTIVE_USER_NAME and str(a.get("Type", "")) == art_type:
				_artifact_slots[art_type]["ids"].append(rid)
				var aname: String = str(a.get("Name", a.get("Set_Name", "Artifact")))
				dd.add_item(aname)


# ═══════════════════════════════════════════
#  Callbacks
# ═══════════════════════════════════════════

func _on_enemy_search_changed(text: String) -> void:
	_populate_enemies(text)


func _on_add_enemy() -> void:
	if _enemy_dropdown.selected < 0:
		return
	var eid = _enemy_dropdown.get_item_metadata(_enemy_dropdown.selected)
	var e: EnemyData = GameDB.enemies.get(eid)
	if e == null:
		return

	# Check if already added
	for entry in _selected_enemies:
		if entry["enemy_id"] == eid:
			entry["count"] += 1
			_rebuild_enemy_list()
			return

	_selected_enemies.append({"enemy_id": eid, "enemy_name": e.name, "tier": e.tier, "count": 1})
	_rebuild_enemy_list()


func _rebuild_enemy_list() -> void:
	for c in _enemy_list_vbox.get_children():
		c.queue_free()

	for i in range(_selected_enemies.size()):
		var entry: Dictionary = _selected_enemies[i]
		var row := _make_hbox(4)
		_enemy_list_vbox.add_child(row)

		var name_lbl := _lbl("%s [%s]" % [entry["enemy_name"], entry["tier"]], 13, TEXT_COLOR)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 10
		spin.value = entry["count"]
		spin.custom_minimum_size.x = 60
		var idx := i
		spin.value_changed.connect(func(v): _selected_enemies[idx]["count"] = int(v))
		row.add_child(spin)

		var rm_btn := Button.new()
		rm_btn.text = "X"
		rm_btn.custom_minimum_size = Vector2(28, 28)
		_style_button(rm_btn, Color(0.5, 0.15, 0.15, 0.9))
		rm_btn.pressed.connect(func():
			_selected_enemies.remove_at(idx)
			_rebuild_enemy_list()
		)
		row.add_child(rm_btn)


func _on_kit_changed(idx: int) -> void:
	_selected_kit_idx = idx - 1  # 0 = "Current (no override)" → -1
	if _selected_kit_idx >= 0 and _selected_kit_idx < _kit_combos.size():
		var wt: String = _kit_combos[_selected_kit_idx]["weapon_type"]
		_populate_weapons(wt)
	else:
		_populate_weapons()


func _on_run_simulation() -> void:
	if _selected_enemies.is_empty():
		Toast.notify("Add at least one enemy first!")
		return

	_run_btn.disabled = true
	_stop_btn.disabled = false
	_progress_bar.visible = true
	_progress_bar.value = 0

	var config := _build_sim_config()
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


# ═══════════════════════════════════════════
#  Config builder
# ═══════════════════════════════════════════

func _build_sim_config() -> Dictionary:
	var party := []
	for pname in Global.PartyCharacters:
		var rid = Global.CHARACTERS_NAME.get(pname, "")
		if rid == "":
			continue
		var char_data: Dictionary = Global.CHARACTERS.get(rid, {}).duplicate(true)
		var is_active: bool = (pname == Global.ACTIVE_USER_NAME)
		party.append({
			"name": pname,
			"character_data": char_data,
			"weapon_override": _get_weapon_override() if is_active else _get_current_weapon(pname),
			"artifact_overrides": _get_artifact_overrides() if is_active else _get_current_artifacts(pname),
			"companion_override": _get_companion_override() if is_active else _get_current_companion(pname),
			"kit_override": _get_kit_override() if is_active else null,
			"food_buff": _get_food_buff() if is_active else "None",
		})

	return {
		"party": party,
		"enemies": _selected_enemies,
		"damage_modifier_players": _player_dmg_mod,
		"damage_modifier_enemies": _enemy_dmg_mod,
		"arena_size": 20,
	}


func _get_kit_override():
	if _selected_kit_idx < 0 or _selected_kit_idx >= _kit_combos.size():
		return null
	return _kit_combos[_selected_kit_idx]


func _get_weapon_override():
	var idx := _weapon_dropdown.selected - 1
	if idx < 0 or idx >= _weapon_ids.size():
		return null
	var rid = _weapon_ids[idx]
	return Global._synced.get("Character_Weapons", {}).get(rid)


func _get_companion_override():
	var idx := _companion_dropdown.selected - 1
	if idx < 0 or idx >= _companion_ids.size():
		return null
	var rid = _companion_ids[idx]
	return Global._synced.get("Companions", {}).get(rid)


func _get_artifact_overrides() -> Dictionary:
	var overrides := {}
	for art_type in ARTIFACT_TYPES:
		var dd: OptionButton = _artifact_dropdowns[art_type]
		var idx := dd.selected - 1
		var ids: Array = _artifact_slots.get(art_type, {}).get("ids", [])
		if idx >= 0 and idx < ids.size():
			var rid = ids[idx]
			overrides[art_type] = Global._synced.get("Character_Artifacts", {}).get(rid)
	return overrides


func _get_food_buff() -> String:
	var dd: OptionButton = _artifact_dropdowns.get("Food")
	if dd == null or dd.selected <= 0:
		return "None"
	return dd.get_item_text(dd.selected)


func _get_current_weapon(player_name: String):
	for rid in Global._synced.get("Character_Weapons", {}):
		var w: Dictionary = Global._synced["Character_Weapons"][rid]
		if w.get("Owner") == player_name and w.get("Equipped") == true:
			return w
	return null


func _get_current_companion(player_name: String):
	for rid in Global._synced.get("Companions", {}):
		var c: Dictionary = Global._synced["Companions"][rid]
		if c.get("Owner") == player_name and c.get("Active") == true:
			return c
	return null


func _get_current_artifacts(player_name: String) -> Dictionary:
	var arts := {}
	for rid in Global._synced.get("Character_Artifacts", {}):
		var a: Dictionary = Global._synced["Character_Artifacts"][rid]
		if a.get("Owner") == player_name and a.get("Equipped") == true:
			var atype: String = str(a.get("Type", ""))
			if atype != "":
				arts[atype] = a
	return arts


# ═══════════════════════════════════════════
#  Results display
# ═══════════════════════════════════════════

func _display_results(r: Dictionary) -> void:
	var n: float = maxf(float(r.get("battles_run", 1)), 1.0)

	# Summary
	var wr: float = r.get("win_rate", 0.0)
	_win_rate_label.text = "%.1f%%" % wr
	_win_rate_label.add_theme_color_override("font_color", GREEN if wr >= 50.0 else RED)

	var wipe: float = r.get("wipe_rate", 0.0)
	_wipe_rate_label.text = "%.1f%%" % wipe
	_wipe_rate_label.add_theme_color_override("font_color", RED if wipe > 25.0 else GREEN)

	var avg_r: float = r.get("avg_rounds", 0.0)
	_avg_rounds_label.text = "%.1f" % avg_r
	_avg_rounds_label.add_theme_color_override("font_color", TEXT_COLOR)

	# Damage distribution
	_display_damage_distribution(r.get("damage_distribution", {}))

	# Party performance
	_display_party_performance(r.get("per_battler", {}), n)

	# Ability breakdown dropdown
	_ability_battler_dropdown.clear()
	var battler_names: Array = r.get("per_battler", {}).keys()
	for bname in battler_names:
		_ability_battler_dropdown.add_item(bname)
	if battler_names.size() > 0:
		_on_ability_battler_selected(0)

	# Battle statistics grid
	_display_battle_stats(r, n)


func _display_damage_distribution(dist: Dictionary) -> void:
	# Clear old bars (keep the header — the first child is the card's VBox, keep title label only)
	var children := _damage_dist_container.get_children()
	for i in range(children.size()):
		if children[i] is Label:
			continue  # keep headers already part of card
		children[i].queue_free()

	var color_i := 0
	for bname in dist:
		var pct: float = dist[bname]
		var bar_row := _make_hbox(4)
		_damage_dist_container.add_child(bar_row)

		var name_lbl := _lbl(bname, 12, TEXT_COLOR)
		name_lbl.custom_minimum_size.x = 100
		bar_row.add_child(name_lbl)

		# Bar background
		var bar_bg := PanelContainer.new()
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_bg.custom_minimum_size.y = 18
		var bg_sb := StyleBoxFlat.new()
		bg_sb.bg_color = CARD_BORDER
		bg_sb.set_corner_radius_all(3)
		bar_bg.add_theme_stylebox_override("panel", bg_sb)
		bar_row.add_child(bar_bg)

		# Bar fill
		var bar_fill := ColorRect.new()
		bar_fill.color = BAR_COLORS[color_i % BAR_COLORS.size()]
		bar_fill.custom_minimum_size = Vector2(maxf(pct / 100.0 * 200.0, 2.0), 14)
		bar_bg.add_child(bar_fill)

		var pct_lbl := _lbl("%.1f%%" % pct, 12, MUTED)
		pct_lbl.custom_minimum_size.x = 50
		bar_row.add_child(pct_lbl)

		color_i += 1


func _display_party_performance(per_battler: Dictionary, n: float) -> void:
	# Clear existing rows
	for c in _party_table.get_children():
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

		# Name
		var nl := _lbl(bname, 12, TEXT_COLOR)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(nl)

		# Values with arrows
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


func _on_ability_battler_selected(idx: int) -> void:
	# Clear table
	for c in _ability_table.get_children():
		c.queue_free()

	if _last_results.is_empty():
		return

	var bname: String = _ability_battler_dropdown.get_item_text(idx)
	var per_b: Dictionary = _last_results.get("per_battler", {})
	if not per_b.has(bname):
		return

	var abilities: Dictionary = per_b[bname].get("abilities", {})

	# Header
	var hdr := _make_hbox(4)
	_ability_table.add_child(hdr)
	for h in ["Ability", "Avg Uses", "Avg Dmg/Use", "Total Dmg"]:
		var lbl := _lbl(h, 12, GOLD)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_child(lbl)

	for ab_name in abilities:
		var ab: Dictionary = abilities[ab_name]
		var row := _make_hbox(4)
		_ability_table.add_child(row)

		var name_lbl := _lbl(ab_name, 11, TEXT_COLOR)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(name_lbl)

		for val in [ab.get("avg_uses", 0.0), ab.get("avg_damage", 0.0), float(ab.get("total_damage", 0))]:
			var vl := _lbl("%.1f" % val, 11, TEXT_COLOR)
			vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(vl)


func _display_battle_stats(r: Dictionary, n: float) -> void:
	# Clear grid
	for c in _stats_grid.get_children():
		c.queue_free()

	var stats := [
		["Min Rounds", str(r.get("min_rounds", 0))],
		["Max Rounds", str(r.get("max_rounds", 0))],
		["Zero Deaths %", "%.1f%%" % (float(r.get("battles_with_zero_deaths", 0)) / n * 100.0)],
		["Full Wipe %", "%.1f%%" % (float(r.get("total_wipes", 0)) / n * 100.0)],
		["Perma-Death %", "%.1f%%" % (float(r.get("battles_with_perma_death", 0)) / n * 100.0)],
		["Battles Run", str(r.get("battles_run", 0))],
		["Total Wins", str(r.get("wins", 0))],
		["Total Losses", str(r.get("losses", 0))],
	]

	for s in stats:
		var key_lbl := _lbl(s[0], 12, MUTED)
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats_grid.add_child(key_lbl)
		var val_lbl := _lbl(s[1], 12, TEXT_COLOR)
		_stats_grid.add_child(val_lbl)


# ═══════════════════════════════════════════
#  UI helpers
# ═══════════════════════════════════════════

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
	# Returns a VBoxContainer with child(0) = title label, child(1) = value label
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
