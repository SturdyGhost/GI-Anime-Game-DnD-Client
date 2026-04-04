extends Control

# ── Colors ──────────────────────────────────────────────────────────────────
const BG = Color(0.102, 0.122, 0.169)
const PANEL = Color(0.133, 0.157, 0.22)
const CARD = Color(0.165, 0.192, 0.27)
const INSET = Color(0.086, 0.106, 0.149)
const HOVER = Color(0.188, 0.227, 0.322)
const BORDER = Color(0.227, 0.259, 0.376)
const TEXT = Color(0.941, 0.949, 0.973)
const SEC = Color(0.69, 0.722, 0.8)
const MUTED = Color(0.471, 0.51, 0.627)
const ACCENT = Color(0.788, 0.659, 0.298)
const GREEN = Color(0.292, 0.855, 0.498)
const RED = Color(0.937, 0.267, 0.267)
const PURPLE = Color(0.659, 0.341, 0.969)

# ── State ───────────────────────────────────────────────────────────────────
var d4_input: LineEdit
var d12_input: LineEdit
var confirm_button: Button
var constellation_dropdown: OptionButton
var result_cards_grid: GridContainer
var result_cards: Array = []
var summary_label: Label
var results_section: VBoxContainer
var has_constellation: bool = false

# ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	randomize()
	_build_ui()
	_constellation_check()
	_populate_material_dropdown(Global.Current_Region)

# ── UI Construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen background
	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main vertical layout
	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	bg.add_child(root_vbox)

	# ── Header ──
	var header = _build_header()
	root_vbox.add_child(header)

	# ── Content area (scrollable) ──
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var content_margin = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 40)
	content_margin.add_theme_constant_override("margin_right", 40)
	content_margin.add_theme_constant_override("margin_top", 24)
	content_margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(content_margin)

	# Two-column grid
	var columns = HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	content_margin.add_child(columns)

	# Left card
	var left_card = _build_left_card()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_card.size_flags_stretch_ratio = 1.0
	columns.add_child(left_card)

	# Right card
	var right_card = _build_right_card()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.size_flags_stretch_ratio = 1.0
	columns.add_child(right_card)

func _build_header() -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = BORDER
	sb.border_width_bottom = 1
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	var region_text = str(Global.Current_Region) if Global.Current_Region else "Unknown"
	var title = Label.new()
	title.text = "GATHERING  —  %s" % region_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	var exit_btn = Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size = Vector2(80, 36)
	_style_button(exit_btn, RED, Color(0.7, 0.15, 0.15))
	exit_btn.pressed.connect(_on_exit_pressed)
	hbox.add_child(exit_btn)

	return panel

func _build_left_card() -> PanelContainer:
	var card = _make_card_panel()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)

	# Section title
	var section_title = Label.new()
	section_title.text = "Roll Your Dice"
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", TEXT)
	vbox.add_child(section_title)

	# Dice inputs row
	var dice_row = HBoxContainer.new()
	dice_row.add_theme_constant_override("separation", 24)
	dice_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(dice_row)

	# D4 input group
	var d4_group = _build_dice_group("D4", "D4 — Cache Selection", "Roll 1-4")
	d4_input = d4_group.get_meta("input")
	d4_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_row.add_child(d4_group)

	# D12 input group
	var d12_group = _build_dice_group("D12", "D12 — Material Quantity", "Avg per material")
	d12_input = d12_group.get_meta("input")
	d12_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_row.add_child(d12_group)

	# Separator
	vbox.add_child(_make_separator())

	# Constellation override section
	var const_panel = _build_constellation_section()
	vbox.add_child(const_panel)

	# Separator
	vbox.add_child(_make_separator())

	# Confirm button
	confirm_button = Button.new()
	confirm_button.text = "Confirm Gathering"
	confirm_button.custom_minimum_size = Vector2(0, 48)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(confirm_button, ACCENT, Color(0.65, 0.54, 0.2))
	confirm_button.pressed.connect(_on_confirm_pressed)
	vbox.add_child(confirm_button)

	return card

func _build_dice_group(dice_name: String, label_text: String, subtitle_text: String) -> VBoxContainer:
	var group = VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	group.alignment = BoxContainer.ALIGNMENT_CENTER

	# Dice input
	var input = LineEdit.new()
	input.custom_minimum_size = Vector2(70, 50)
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.placeholder_text = dice_name
	input.max_length = 2

	var input_sb = StyleBoxFlat.new()
	input_sb.bg_color = INSET
	input_sb.border_color = BORDER
	input_sb.set_border_width_all(2)
	input_sb.set_corner_radius_all(8)
	input_sb.content_margin_left = 8
	input_sb.content_margin_right = 8
	input_sb.content_margin_top = 6
	input_sb.content_margin_bottom = 6
	input.add_theme_stylebox_override("normal", input_sb)

	var focus_sb = input_sb.duplicate()
	focus_sb.border_color = ACCENT
	input.add_theme_stylebox_override("focus", focus_sb)

	input.add_theme_font_size_override("font_size", 24)
	input.add_theme_color_override("font_color", ACCENT)
	input.add_theme_color_override("font_placeholder_color", MUTED)
	input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	group.add_child(input)

	# Label
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", TEXT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(lbl)

	# Subtitle
	var sub = Label.new()
	sub.text = subtitle_text
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(sub)

	group.set_meta("input", input)
	return group

func _build_constellation_section() -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = INSET
	sb.border_color = PURPLE
	sb.border_width_left = 3
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var star_lbl = Label.new()
	star_lbl.text = "*"
	star_lbl.add_theme_font_size_override("font_size", 18)
	star_lbl.add_theme_color_override("font_color", PURPLE)
	title_row.add_child(star_lbl)

	var title = Label.new()
	title.text = "Constellation Override"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", PURPLE)
	title_row.add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Choose your material cache instead of rolling D4"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", SEC)
	vbox.add_child(sub)

	# Dropdown
	constellation_dropdown = OptionButton.new()
	constellation_dropdown.disabled = true
	constellation_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	constellation_dropdown.custom_minimum_size = Vector2(0, 36)

	var dd_sb = StyleBoxFlat.new()
	dd_sb.bg_color = CARD
	dd_sb.border_color = BORDER
	dd_sb.set_border_width_all(1)
	dd_sb.set_corner_radius_all(6)
	dd_sb.content_margin_left = 12
	dd_sb.content_margin_right = 12
	dd_sb.content_margin_top = 6
	dd_sb.content_margin_bottom = 6
	constellation_dropdown.add_theme_stylebox_override("normal", dd_sb)

	constellation_dropdown.add_theme_font_size_override("font_size", 14)
	constellation_dropdown.add_theme_color_override("font_color", TEXT)
	vbox.add_child(constellation_dropdown)

	return panel

func _build_right_card() -> PanelContainer:
	var card = _make_card_panel()

	results_section = VBoxContainer.new()
	results_section.add_theme_constant_override("separation", 20)
	card.add_child(results_section)

	# Section title
	var section_title = Label.new()
	section_title.text = "Materials Received"
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", TEXT)
	results_section.add_child(section_title)

	# 2x2 grid for result cards
	result_cards_grid = GridContainer.new()
	result_cards_grid.columns = 2
	result_cards_grid.add_theme_constant_override("h_separation", 16)
	result_cards_grid.add_theme_constant_override("v_separation", 16)
	result_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_section.add_child(result_cards_grid)

	# Pre-create 4 result card slots (hidden)
	for i in 4:
		var rc = _make_result_card()
		rc.visible = false
		result_cards_grid.add_child(rc)
		result_cards.append(rc)

	# Separator
	results_section.add_child(_make_separator())

	# Summary
	summary_label = Label.new()
	summary_label.text = ""
	summary_label.add_theme_font_size_override("font_size", 14)
	summary_label.add_theme_color_override("font_color", MUTED)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_section.add_child(summary_label)

	return card

func _make_result_card() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb = StyleBoxFlat.new()
	sb.bg_color = INSET
	sb.border_color = GREEN
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Quantity label
	var qty_lbl = Label.new()
	qty_lbl.name = "QtyLabel"
	qty_lbl.text = "0"
	qty_lbl.add_theme_font_size_override("font_size", 22)
	qty_lbl.add_theme_color_override("font_color", GREEN)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(qty_lbl)

	# Material name label
	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = ""
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", SEC)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	return panel

func _make_card_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	return panel

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	var line = sep.get_theme_stylebox("separator") as StyleBoxLine
	line.color = BORDER
	line.thickness = 1
	return sep

func _style_button(btn: Button, bg_color: Color, hover_color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)

	var hov = normal.duplicate()
	hov.bg_color = hover_color
	btn.add_theme_stylebox_override("hover", hov)

	var pressed = normal.duplicate()
	pressed.bg_color = hover_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", TEXT)

# ── Data Logic ──────────────────────────────────────────────────────────────

func _constellation_check() -> void:
	for constellation in Global.CONSTELLATIONS.values():
		if constellation.get("Name") == Global.ACTIVE_USER_NAME and constellation.get("Chosen") == true:
			if constellation.get("Constellation") == "When gathering materials, you may choose which material cache you go to rather than rolling for it.":
				constellation_dropdown.disabled = false
				has_constellation = true

func _populate_material_dropdown(region: String) -> void:
	constellation_dropdown.clear()
	var uniques = {}
	for rec_id in Global.MATERIAL_CACHES.keys():
		var rec = Global.MATERIAL_CACHES[rec_id]
		if str(rec.get("Region", "")) != str(region):
			continue
		var mats = _parse_materials(rec.get("Materials", []))
		for m in mats:
			uniques[m] = true
	var sorted_mats = uniques.keys()
	sorted_mats.sort_custom(func(a, b): return str(a) < str(b))
	for i in sorted_mats.size():
		constellation_dropdown.add_item(str(sorted_mats[i]), i)

func _parse_materials(val) -> Array:
	if typeof(val) == TYPE_ARRAY:
		return val
	if typeof(val) == TYPE_STRING:
		var txt = val.strip_edges()
		if txt.begins_with("[") and txt.ends_with("]"):
			txt = txt.substr(1, txt.length() - 2)
		var arr = []
		for part in txt.split(","):
			var clean = part.strip_edges()
			if clean != "":
				arr.append(clean)
		return arr
	return []

# ── Confirm Gathering ───────────────────────────────────────────────────────

func _on_confirm_pressed() -> void:
	_clear_results()

	var region = str(Global.Current_Region)
	var d4_roll = _to_int_safely(d4_input.text, 0)
	var d12_roll = _to_int_safely(d12_input.text, 0)

	if d4_roll < 1 or d4_roll > 4:
		if not has_constellation or constellation_dropdown.disabled:
			summary_label.text = "Invalid D4 roll. Enter 1-4."
			summary_label.add_theme_color_override("font_color", RED)
			return
	if d12_roll < 1:
		summary_label.text = "Invalid D12 roll. Enter a positive number."
		summary_label.add_theme_color_override("font_color", RED)
		return

	# Pick cache
	var cache = {}
	var used_override = false
	if not constellation_dropdown.disabled and constellation_dropdown.item_count > 0:
		var selected_text = constellation_dropdown.get_item_text(constellation_dropdown.selected)
		cache = _find_cache_by_material(region, selected_text)
		used_override = true
		if cache.is_empty():
			summary_label.text = "No cache in %s containing %s." % [region, selected_text]
			summary_label.add_theme_color_override("font_color", RED)
			return
	else:
		cache = _find_cache_by_roll(region, d4_roll)
		if cache.is_empty():
			summary_label.text = "No cache in %s for roll %d." % [region, d4_roll]
			summary_label.add_theme_color_override("font_color", RED)
			return

	var materials = _parse_materials(cache.get("Materials", []))
	if materials.is_empty():
		summary_label.text = "Selected cache has no materials."
		summary_label.add_theme_color_override("font_color", RED)
		return

	var target_avg = ceili(float(d12_roll))

	# Luck bonus/penalty on gathering yields
	var luck = Global.get_effective_luck(Global.ACTIVE_USER_NAME)
	if luck >= 85:
		target_avg += 2
	elif luck >= 70:
		target_avg += 1
	elif luck <= 10:
		target_avg = max(1, target_avg - 2)
	elif luck <= 25:
		target_avg = max(1, target_avg - 1)

	var quantities = _generate_spread_counts(target_avg, materials.size())

	# Apply to inventory and collect results
	var updated_pairs = []
	for i in materials.size():
		var mat_name = str(materials[i])
		var qty = int(quantities[i])
		if qty < 1:
			qty = 1
		_upsert_character_item(mat_name, qty)
		updated_pairs.append([mat_name, qty])

	# Show result cards
	_show_results(updated_pairs)

	# Summary
	var sum_qty = 0
	for p in updated_pairs:
		sum_qty += int(p[1])
	var avg_result = float(sum_qty) / float(max(1, updated_pairs.size()))
	var cache_roll = int(cache.get("Roll", d4_roll))
	summary_label.add_theme_color_override("font_color", MUTED)
	summary_label.text = "Gathered from Cache %d  ·  Avg ≈ %.1f per material  ·  Total: %d items" % [cache_roll, avg_result, sum_qty]

	# Log
	Global.Log(
		"Gathering",
		"Confirm",
		"Region",
		region,
		{"D4": d4_roll, "D12": d12_roll},
		{"Results": updated_pairs},
		{"UsedMaterialOverride": used_override},
		"success",
		"audit"
	)

func _on_exit_pressed() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

# ── Result Display ──────────────────────────────────────────────────────────

func _show_results(pairs: Array) -> void:
	for i in result_cards.size():
		if i < pairs.size():
			var card = result_cards[i] as PanelContainer
			card.visible = true
			var qty_lbl = card.get_node("VBoxContainer/QtyLabel") as Label
			var name_lbl = card.get_node("VBoxContainer/NameLabel") as Label
			qty_lbl.text = "x%s" % str(pairs[i][1])
			name_lbl.text = str(pairs[i][0])
		else:
			result_cards[i].visible = false

func _clear_results() -> void:
	for card in result_cards:
		card.visible = false
	summary_label.text = ""

# ── Cache Lookup ────────────────────────────────────────────────────────────

func _find_cache_by_roll(region: String, roll: int) -> Dictionary:
	for rec_id in Global.MATERIAL_CACHES.keys():
		var rec = Global.MATERIAL_CACHES[rec_id]
		if str(rec.get("Region", "")) == str(region) and int(rec.get("Roll", 0)) == roll:
			return rec
	return {}

func _find_cache_by_material(region: String, material: String) -> Dictionary:
	if material == "":
		return {}
	for rec_id in Global.MATERIAL_CACHES.keys():
		var rec = Global.MATERIAL_CACHES[rec_id]
		if str(rec.get("Region", "")) != str(region):
			continue
		var mats = _parse_materials(rec.get("Materials", []))
		if material in mats:
			return rec
	return {}

# ── Spread Generation ──────────────────────────────────────────────────────

func _generate_spread_counts(target_avg: int, count: int) -> Array:
	if count <= 0:
		return []
	var base = max(1, target_avg)
	var nums = []
	for i in count:
		var delta = randi_range(-1, 1)
		var v = max(1, base + delta)
		nums.append(v)
	var target_total = base * count
	var current_total = 0
	for n in nums:
		current_total += int(n)
	while current_total != target_total:
		if current_total < target_total:
			var idx_inc = _index_of_min(nums)
			nums[idx_inc] = int(nums[idx_inc]) + 1
			current_total += 1
		else:
			var idx_dec = _index_of_max(nums)
			if int(nums[idx_dec]) > 1:
				nums[idx_dec] = int(nums[idx_dec]) - 1
				current_total -= 1
			else:
				break
	return nums

func _index_of_min(arr: Array) -> int:
	var idx = 0
	var best = int(arr[0])
	for i in arr.size():
		if int(arr[i]) < best:
			best = int(arr[i])
			idx = i
	return idx

func _index_of_max(arr: Array) -> int:
	var idx = 0
	var best = int(arr[0])
	for i in arr.size():
		if int(arr[i]) > best:
			best = int(arr[i])
			idx = i
	return idx

# ── Inventory Upsert ───────────────────────────────────────────────────────

func _upsert_character_item(material_name: String, add_qty: int) -> void:
	var char_name = str(Global.ACTIVE_USER_NAME)
	var char_id = Global.CHARACTERS_NAME.get(char_name, null)
	if char_id == null:
		return

	var existing_id = ""
	var existing_qty = 0
	for rec_id in Global.CHARACTER_ITEMS.keys():
		var rec = Global.CHARACTER_ITEMS[rec_id]
		if rec.get("Owner", null) == char_name and str(rec.get("Name", "")) == material_name:
			existing_id = rec_id
			existing_qty = int(rec.get("Quantity", 0))
			break

	if existing_id != "":
		var new_qty = existing_qty + add_qty
		Global.Update_Records([{"table": "Character_Items", "record_id": int(existing_id), "field": "Quantity", "value": new_qty}])
	else:
		var item_type = null
		var item_rarity = null
		var item_description = null
		for item in Global.ITEMS.values():
			if item.get("Item") == material_name:
				item_type = item.get("Type")
				item_rarity = item.get("Rarity")
				item_description = item.get("Description")
		var columns = ["Owner", "Name", "Quantity", "Type", "Rarity", "Description"]
		var values = [char_name, material_name, add_qty, item_type, item_rarity, item_description]
		Global.Insert("Character_Items", columns, values)

# ── Utility ─────────────────────────────────────────────────────────────────

func _to_int_safely(s: String, default_value: int) -> int:
	var txt = s.strip_edges()
	if txt == "":
		return default_value
	return int(txt.to_int())
