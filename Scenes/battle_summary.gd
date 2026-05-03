class_name BattleSummary
extends Control
## Full-screen overlay that displays aggregated battle statistics when a battle
## ends. All UI is built programmatically in show_summary().


signal continue_pressed


# ── Theme colours ────────────────────────────────────────────────────────────

const COL_BG        = Color(0.039, 0.051, 0.075, 0.95)
const COL_PANEL     = Color(0.071, 0.086, 0.118)
const COL_CARD      = Color(0.102, 0.122, 0.169)
const COL_TEXT       = Color(0.941, 0.949, 0.973)
const COL_TEXT_SEC   = Color(0.69, 0.722, 0.8)
const COL_TEXT_MUTED = Color(0.533, 0.573, 0.659)
const COL_ACCENT     = Color(0.788, 0.659, 0.298)
const COL_GREEN      = Color(0.292, 0.855, 0.498)
const COL_RED        = Color(0.937, 0.267, 0.267)


func show_summary(summary: Dictionary) -> void:
	# Ensure full-screen
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark overlay background
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Centre container
	var centre = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(centre)

	# Main panel — fills most of the screen
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 850)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = COL_PANEL
	panel_sb.corner_radius_top_left = 8
	panel_sb.corner_radius_top_right = 8
	panel_sb.corner_radius_bottom_left = 8
	panel_sb.corner_radius_bottom_right = 8
	panel_sb.content_margin_left = 24
	panel_sb.content_margin_right = 24
	panel_sb.content_margin_top = 20
	panel_sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_sb)
	centre.add_child(panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	# ── Title ────────────────────────────────────────────────────────────────
	var title = _label("BATTLE SUMMARY", 20, COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	# ── Duration line ────────────────────────────────────────────────────────
	var total_turns: int = int(summary.get("total_turns", 0))
	var dur_sec: float = summary.get("duration_seconds", 0.0)
	var dur_text: String = "Battle lasted %d turn%s (%s)" % [
		total_turns,
		"" if total_turns == 1 else "s",
		_format_duration(dur_sec),
	]
	var dur_label = _label(dur_text, 14, COL_TEXT_MUTED)
	dur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(dur_label)

	root_vbox.add_child(_separator())

	# ── Scrollable combatant cards (largest section) ────────────────────────
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 3.0
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var cards_vbox = VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(cards_vbox)

	# Determine highest damage dealer for bold highlight
	var combatants: Dictionary = summary.get("combatants", {})
	var highest_dmg: int = 0
	var highest_name: String = ""
	for cname in combatants:
		var c: Dictionary = combatants[cname]
		# Highlight highest damage dealer among non-enemies
		if str(c.get("type", "")) == "Enemy":
			continue
		var dealt: int = int(c.get("total_damage_dealt", 0))
		if dealt > highest_dmg:
			highest_dmg = dealt
			highest_name = cname

	# Show player characters and companions first
	for cname in combatants:
		var c: Dictionary = combatants[cname]
		var ctype: String = str(c.get("type", "Unknown"))
		if ctype == "Enemy":
			continue
		_build_combatant_card(cards_vbox, cname, c, ctype, cname == highest_name)

	# Then show enemies
	var has_enemies = false
	for cname in combatants:
		var c: Dictionary = combatants[cname]
		var ctype: String = str(c.get("type", "Unknown"))
		if ctype != "Enemy":
			continue
		if not has_enemies:
			has_enemies = true
			cards_vbox.add_child(_separator())
			var enemy_header = _label("ENEMIES", 14, COL_TEXT_MUTED)
			enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cards_vbox.add_child(enemy_header)
		_build_combatant_card(cards_vbox, cname, c, ctype, false)

	root_vbox.add_child(_separator())

	# ── Totals ───────────────────────────────────────────────────────────────
	var total_dmg_label = _label(
		"Total Party Damage: %s" % _comma(int(summary.get("total_damage", 0))),
		15, COL_ACCENT
	)
	total_dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(total_dmg_label)

	var total_kills_label = _label(
		"Total Kills: %s" % str(int(summary.get("total_kills", 0))),
		14, COL_GREEN
	)
	total_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(total_kills_label)

	# ── Challenge result ─────────────────────────────────────────────────────
	var challenge_text: String = str(summary.get("challenge_quest", ""))
	if challenge_text != "":
		root_vbox.add_child(_separator())
		var completed: bool = summary.get("challenge_completed", false)
		var status_text = "CHALLENGE COMPLETE!" if completed else "Challenge Failed"
		var status_color = COL_GREEN if completed else COL_RED
		var status_label = _label(status_text, 16, status_color)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_vbox.add_child(status_label)
		var challenge_desc = RichTextLabel.new()
		challenge_desc.bbcode_enabled = true
		challenge_desc.fit_content = true
		challenge_desc.scroll_active = false
		challenge_desc.text = "[center]%s[/center]" % challenge_text
		challenge_desc.add_theme_font_size_override("normal_font_size", 14)
		challenge_desc.add_theme_color_override("default_color", COL_TEXT)
		root_vbox.add_child(challenge_desc)
		var quest_full: Dictionary = summary.get("challenge_quest_full", {})
		var giver = str(quest_full.get("quest_giver_name", ""))
		var personality = str(quest_full.get("quest_giver_personality", ""))
		var multiplier = float(quest_full.get("reward_multiplier", 1.0))
		if giver != "":
			var giver_desc = _label("%s (%s) — x%.0f%% bonus loot" % [giver, personality, multiplier * 100], 12, COL_TEXT_MUTED)
			giver_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			root_vbox.add_child(giver_desc)

	# ── Loot section ─────────────────────────────────────────────────────────
	var player_loot: Dictionary = summary.get("player_loot", {})
	if not player_loot.is_empty():
		root_vbox.add_child(_separator())

		var loot_tier_name: String = str(summary.get("loot_tier", ""))
		var loot_header = _label("BATTLE LOOT" + ("  —  " + loot_tier_name if loot_tier_name != "" and loot_tier_name != "Nothing" else ""), 16, COL_ACCENT)
		loot_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_vbox.add_child(loot_header)

		# Show loot for current player only (each player sees their own)
		var my_name: String = Global.ACTIVE_USER_NAME
		var my_loot: Dictionary = player_loot.get(my_name, {})
		if my_loot.is_empty():
			var no_loot = _label("No loot earned", 14, COL_TEXT_MUTED)
			no_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			root_vbox.add_child(no_loot)
		else:
			var loot_grid = GridContainer.new()
			loot_grid.columns = 4
			loot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			loot_grid.add_theme_constant_override("h_separation", 16)
			loot_grid.add_theme_constant_override("v_separation", 4)
			root_vbox.add_child(loot_grid)

			var sorted_mats = my_loot.keys()
			sorted_mats.sort()
			for mat_name in sorted_mats:
				var qty: int = int(my_loot[mat_name])
				var name_lbl = _label(mat_name, 14, COL_TEXT)
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				loot_grid.add_child(name_lbl)
				var qty_lbl = _label("x%d" % qty, 14, COL_GREEN)
				loot_grid.add_child(qty_lbl)

	# ── Expedition returns ───────────────────────────────────────────────────
	# Read from summary dict (broadcast to all clients) with Global fallback for host
	var exp_results: Array = summary.get("expedition_results", [])
	if exp_results.is_empty():
		var global_results = Global.get("_expedition_results")
		if global_results is Array:
			exp_results = global_results
	if exp_results.size() > 0:
		root_vbox.add_child(_separator())
		var exp_header = _label("EXPEDITION RETURNS", 16, Color(0.6, 0.85, 0.5))
		exp_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_vbox.add_child(exp_header)

		var exp_scroll = ScrollContainer.new()
		exp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		exp_scroll.size_flags_stretch_ratio = 1.0
		exp_scroll.custom_minimum_size.y = 100
		exp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		root_vbox.add_child(exp_scroll)

		var exp_vbox = VBoxContainer.new()
		exp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		exp_vbox.add_theme_constant_override("separation", 4)
		exp_scroll.add_child(exp_vbox)

		for result in exp_results:
			var comp_name: String = str(result.get("companion", ""))
			var owner_name: String = str(result.get("owner", ""))
			var exp_name: String = str(result.get("expedition", ""))
			var loot: Dictionary = result.get("loot", {})
			var failed: bool = result.get("failed", false)
			var bonus_total: float = result.get("bonus_total", 1.0)
			var bonus_list: Array = result.get("bonuses", [])

			var result_lbl: Label
			if failed or loot.is_empty():
				result_lbl = _label("%s returned empty-handed from %s" % [comp_name, exp_name], 14, COL_RED)
			else:
				var items_arr: Array = []
				for k in loot:
					items_arr.append("%s x%d" % [k, loot[k]])
				var loot_text = "%s from %s: %s" % [comp_name, exp_name, ", ".join(items_arr)]
				if owner_name != "":
					loot_text += "  ->  %s" % owner_name
				result_lbl = _label(loot_text, 14, COL_TEXT)
			result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			exp_vbox.add_child(result_lbl)

			# Bonus breakdown
			if bonus_list.size() > 0:
				var bonus_text = "  Bonus x%.0f%% — %s" % [bonus_total * 100, ", ".join(bonus_list)]
				var bonus_lbl = _label(bonus_text, 11, COL_TEXT_MUTED)
				bonus_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				exp_vbox.add_child(bonus_lbl)
			elif bonus_total == 1.0:
				var no_bonus_lbl = _label("  No bonuses (base rate)", 11, COL_TEXT_MUTED)
				exp_vbox.add_child(no_bonus_lbl)

	root_vbox.add_child(_separator())

	# ── Continue button ──────────────────────────────────────────────────────
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(btn_row)

	var btn = Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(160, 40)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0, 0, 0, 0)
	btn_normal.border_color = COL_ACCENT
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", btn_normal)
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.15)
	btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.25)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	btn.add_theme_color_override("font_color", COL_ACCENT)
	btn.add_theme_color_override("font_hover_color", COL_ACCENT)
	btn.add_theme_color_override("font_pressed_color", COL_ACCENT)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(_on_continue)
	btn_row.add_child(btn)


func _on_continue() -> void:
	continue_pressed.emit()
	queue_free()


# ── Card builder ─────────────────────────────────────────────────────────────


func _build_combatant_card(parent: Control, cname: String, data: Dictionary,
		ctype: String, is_top_damage: bool) -> void:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = COL_CARD
	card_sb.corner_radius_top_left = 6
	card_sb.corner_radius_top_right = 6
	card_sb.corner_radius_bottom_left = 6
	card_sb.corner_radius_bottom_right = 6
	card_sb.content_margin_left = 16
	card_sb.content_margin_right = 16
	card_sb.content_margin_top = 12
	card_sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_sb)
	parent.add_child(card)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	card.add_child(hbox)

	# Left side: name + type
	var name_vbox = VBoxContainer.new()
	name_vbox.custom_minimum_size.x = 160
	name_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(name_vbox)

	var name_label = _label(cname, 16, COL_TEXT)
	if is_top_damage:
		name_label.add_theme_color_override("font_color", COL_ACCENT)
	name_vbox.add_child(name_label)

	var type_label = _label(ctype, 13, COL_TEXT_MUTED)
	name_vbox.add_child(type_label)

	# Right side: stats grid (4 columns: label, value, label, value)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	hbox.add_child(grid)

	var dmg_dealt: int = int(data.get("total_damage_dealt", 0))
	var dmg_recv: int = int(data.get("total_damage_received", 0))
	var heal_done: int = int(data.get("total_healing_done", 0))
	var kills: int = int(data.get("kills", 0))
	var crits: int = int(data.get("crits", 0))
	var tiles: int = int(data.get("tiles_moved", 0))
	var avg_turn: float = data.get("avg_damage_per_turn", 0.0)
	var items_dict: Dictionary = data.get("items_used", {})
	var items_count: int = 0
	for k in items_dict:
		items_count += int(items_dict[k])

	var avg_atk_roll: float = data.get("avg_attack_roll", 0.0)
	var avg_def_roll: float = data.get("avg_defense_roll", 0.0)

	_stat_row(grid, "Damage Dealt", _comma(dmg_dealt), COL_GREEN)
	_stat_row(grid, "Damage Taken", _comma(dmg_recv), COL_RED)
	_stat_row(grid, "Healing Done", _comma(heal_done), COL_GREEN if heal_done > 0 else COL_TEXT)
	_stat_row(grid, "Kills", str(kills), COL_GREEN if kills > 0 else COL_TEXT)
	_stat_row(grid, "Crits", str(crits), COL_ACCENT if crits > 0 else COL_TEXT)
	_stat_row(grid, "Tiles Moved", str(tiles), COL_TEXT)
	_stat_row(grid, "Avg Dmg/Turn", "%.1f" % avg_turn, COL_TEXT_SEC)
	_stat_row(grid, "Avg Atk Roll", "%.1f" % avg_atk_roll if avg_atk_roll > 0 else "—", COL_TEXT_SEC)
	var times_attacked: int = int(data.get("times_attacked", 0))
	_stat_row(grid, "Avg Def Roll", "%.1f" % avg_def_roll if avg_def_roll > 0 else "—", COL_TEXT_SEC)
	_stat_row(grid, "Times Attacked", str(times_attacked), COL_RED if times_attacked > 0 else COL_TEXT)
	_stat_row(grid, "Items Used", str(items_count), COL_TEXT)


func _stat_row(grid: GridContainer, label_text: String, value_text: String,
		value_color: Color = COL_TEXT) -> void:
	var lbl = _label(label_text, 14, COL_TEXT_SEC)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(lbl)

	var val = _label(value_text, 14, value_color)
	grid.add_child(val)


# ── Helpers ──────────────────────────────────────────────────────────────────


func _label(text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(size, 13))
	l.add_theme_color_override("font_color", color)
	return l


func _separator() -> HSeparator:
	var sep = HSeparator.new()
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = Color(1, 1, 1, 0.08)
	sep_sb.content_margin_top = 1
	sep_sb.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	return sep


static func _comma(n: int) -> String:
	var s: String = str(absi(n))
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	if n < 0:
		result = "-" + result
	return result


static func _format_duration(seconds: float) -> String:
	var total: int = int(seconds)
	var mins: int = total / 60
	var secs: int = total % 60
	if mins > 0:
		return "%dm %ds" % [mins, secs]
	return "%ds" % secs
