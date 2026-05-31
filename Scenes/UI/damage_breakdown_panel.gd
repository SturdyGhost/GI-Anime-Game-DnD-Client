extends PanelContainer
## Post-turn damage breakdown panel.
## Shows what the system calculated as possible outcomes for each target.
## Purely informational — actual damage dealt is what the DM entered.

signal panel_closed

var _turn_input: Dictionary = {}
var _vbox: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.065, 0.082, 0.122, 0.95)
	bg.set_content_margin_all(16)
	add_theme_stylebox_override("panel", bg)
	_build_ui()

func setup(turn_input: Dictionary) -> void:
	_turn_input = turn_input
	_build_breakdown()

func _build_ui() -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_vbox)

func _build_breakdown() -> void:
	# Clear previous
	for child in _vbox.get_children():
		child.queue_free()

	var battler_name: String = str(_turn_input.get("battler_name", ""))
	var attack_used: String = str(_turn_input.get("attack_used", "None"))
	var attack_roll: int = int(_turn_input.get("attack_roll", 0))
	var critical_hit: bool = _turn_input.get("critical_hit", false)
	var targets: Array = _turn_input.get("targets", [])

	# Top bar with close button
	var top_bar = HBoxContainer.new()
	_vbox.add_child(top_bar)
	var title = Label.new()
	title.text = "Turn Results — %s" % battler_name
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.788, 0.659, 0.298))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)
	var close_btn = Button.new()
	close_btn.text = "X  Close"
	close_btn.pressed.connect(func(): panel_closed.emit(); queue_free())
	top_bar.add_child(close_btn)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "%s  |  Attack Roll: %d  |  %s" % [
		attack_used,
		attack_roll,
		"CRIT!" if critical_hit else "%d Hit(s)" % (int(targets[0].get("hits", 1)) if targets.size() > 0 else 1)
	]
	subtitle.add_theme_font_size_override("font_size", 25)
	subtitle.add_theme_color_override("font_color", Color(0.545, 0.576, 0.690))
	_vbox.add_child(subtitle)

	# Get effect modifiers for this battler
	var flat_mod := 0.0
	var mult_mod := 1.0
	if Global.effect_processor:
		var ctx := {"attack_type": attack_used, "is_crit": critical_hit}
		flat_mod = Global.effect_processor.sum_flat_damage(battler_name, "ON_HIT", ctx)
		mult_mod = Global.effect_processor.damage_multiplier(battler_name, "ON_HIT", ctx)
		if critical_hit:
			flat_mod += Global.effect_processor.sum_flat_damage(battler_name, "ON_CRIT", ctx)
			mult_mod *= Global.effect_processor.damage_multiplier(battler_name, "ON_CRIT", ctx)

	# Per-target breakdown
	for t in targets:
		_add_target_breakdown(t, attack_roll, flat_mod, mult_mod)

	# Footer disclaimer
	var footer = Label.new()
	footer.text = "Showing calculated possible outcomes — actual damage dealt is what was entered"
	footer.add_theme_font_size_override("font_size", 20)
	footer.add_theme_color_override("font_color", Color(0.478, 0.514, 0.627))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(footer)


func _add_target_breakdown(target: Dictionary, attack_roll: int, flat_mod: float, mult_mod: float) -> void:
	var target_name: String = str(target.get("name", "Unknown"))
	var defense_roll: int = int(target.get("defense_roll", 0))
	var hits: int = maxi(int(target.get("hits", 1)), 1)
	var actual_damage: int = int(target.get("raw_damage", 0))
	var attack_type: String = str(target.get("attack_type", "Damage"))

	var diff := attack_roll - defense_roll
	var dice := DiceRoller.difference_to_damage_dice(diff)

	# Header card
	var header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", _make_header_style())
	_vbox.add_child(header)

	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 4)
	header.add_child(header_vbox)

	# Target name
	var name_label = Label.new()
	name_label.text = target_name
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(0.788, 0.659, 0.298))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(name_label)

	# Roll info
	var dice_str := ""
	if dice.is_empty():
		dice_str = "MISS"
	else:
		var parts: Array = []
		for d in dice:
			parts.append("D%d" % d)
		dice_str = "+".join(parts)

	var roll_info = Label.new()
	roll_info.text = "Defense Roll: %d  |  Difference: %d  |  %s" % [defense_roll, diff, dice_str]
	roll_info.add_theme_font_size_override("font_size", 22)
	roll_info.add_theme_color_override("font_color", Color(0.478, 0.514, 0.627))
	roll_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(roll_info)

	# Actual damage — big number
	var dmg_label = Label.new()
	if attack_type == "Healed":
		dmg_label.text = str(actual_damage)
		dmg_label.add_theme_color_override("font_color", Color(0.292, 0.855, 0.498))
	else:
		dmg_label.text = str(actual_damage)
		dmg_label.add_theme_color_override("font_color", Color(0.937, 0.267, 0.267))
	dmg_label.add_theme_font_size_override("font_size", 86)
	dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(dmg_label)

	var type_label = Label.new()
	type_label.text = attack_type.to_upper() + " DEALT"
	type_label.add_theme_font_size_override("font_size", 22)
	type_label.add_theme_color_override("font_color", Color(0.545, 0.576, 0.690))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(type_label)

	# Modifier summary
	var mod_hbox = HBoxContainer.new()
	mod_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mod_hbox.add_theme_constant_override("separation", 24)
	header_vbox.add_child(mod_hbox)
	_add_mod_item(mod_hbox, "+%.0f" % flat_mod, "Flat Mod")
	_add_mod_item(mod_hbox, "x%.1f" % mult_mod, "Mult Mod")
	_add_mod_item(mod_hbox, "%d Hit(s)" % hits, "Hits")

	# If miss, no roll table
	if dice.is_empty():
		return

	# Roll breakdown table
	var table_panel = PanelContainer.new()
	table_panel.add_theme_stylebox_override("panel", _make_table_style())
	_vbox.add_child(table_panel)

	var table_vbox = VBoxContainer.new()
	table_panel.add_child(table_vbox)

	# Table header
	var header_row = _make_table_row(["Damage Roll", "+ Mods", "x Mods", "Final Damage"], true)
	table_vbox.add_child(header_row)

	# Calculate all possible outcomes
	var possible := DiceRoller.all_possible_damages(diff, hits, flat_mod, mult_mod)

	# Find estimated actual roll (which possible outcome is closest to actual damage)
	var estimated_roll_idx := -1
	var min_diff_to_actual := 99999
	for i in range(possible.size()):
		var d := absi(possible[i]["damage"] - actual_damage)
		if d < min_diff_to_actual:
			min_diff_to_actual = d
			estimated_roll_idx = i

	# Add rows
	for i in range(possible.size()):
		var p: Dictionary = possible[i]
		var roll_val: int = p["roll"]
		var final_dmg: int = p["damage"]
		var after_flat := roll_val + int(flat_mod)
		var is_estimated := (i == estimated_roll_idx)

		var roll_text := str(roll_val)
		if is_estimated:
			roll_text += "  EST."

		var row = _make_table_row([
			roll_text,
			"%d + %d" % [roll_val, int(flat_mod)],
			"x %.1f" % mult_mod,
			str(final_dmg),
		], false, is_estimated)
		table_vbox.add_child(row)


func _add_mod_item(parent: Control, value_text: String, label_text: String) -> void:
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(vb)
	var val = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 25)
	val.add_theme_color_override("font_color", Color(0.941, 0.949, 0.973))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(val)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.478, 0.514, 0.627))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)


func _make_table_row(cells: Array, is_header: bool, is_highlighted: bool = false) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for i in range(cells.size()):
		var cell = Label.new()
		cell.text = str(cells[i])
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_header:
			cell.add_theme_font_size_override("font_size", 20)
			cell.add_theme_color_override("font_color", Color(0.545, 0.576, 0.690))
		elif is_highlighted:
			cell.add_theme_font_size_override("font_size", 25)
			cell.add_theme_color_override("font_color", Color(0.292, 0.855, 0.498))
		else:
			cell.add_theme_font_size_override("font_size", 23)
			cell.add_theme_color_override("font_color", Color(0.941, 0.949, 0.973))
		row.add_child(cell)
	return row


func _make_header_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.118, 0.141, 0.176)
	s.border_color = Color(0.165, 0.188, 0.282)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(16)
	return s


func _make_table_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.102, 0.122, 0.169)
	s.border_color = Color(0.165, 0.188, 0.282)
	s.set_border_width_all(1)
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.set_content_margin_all(8)
	return s
