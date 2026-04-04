extends Control

signal game_finished(score: int)

# ── Element symbols ──────────────────────────────────────────────────────────
const ELEMENTS: Array = [
	{"name": "Anemo", "icon": "res://UI/Element Icons/Wind.png", "weight": 20},
	{"name": "Geo", "icon": "res://UI/Element Icons/Earth.png", "weight": 20},
	{"name": "Pyro", "icon": "res://UI/Element Icons/Fire.png", "weight": 15},
	{"name": "Electro", "icon": "res://UI/Element Icons/Electric.png", "weight": 15},
	{"name": "Cryo", "icon": "res://UI/Element Icons/Ice.png", "weight": 10},
	{"name": "Dendro", "icon": "res://UI/Element Icons/Nature.png", "weight": 10},
	{"name": "Hydro", "icon": "res://UI/Element Icons/Water.png", "weight": 5},
]

# Base payout per 3-match on a line (at tier 3 / 8 lines)
const PAYOUTS_3: Dictionary = {
	"Anemo": 140, "Geo": 140,
	"Pyro": 325, "Electro": 325,
	"Cryo": 700, "Dendro": 700,
	"Hydro": 2300,
}
const PAYOUT_2: int = 30  # any 2-match on a line

# Tier multipliers: fewer lines = higher per-line payout
# Targets: tier 1 ~80% return, tier 2 ~95%, tier 3 ~103%
const TIER_MULTIPLIERS: Array = [2.1, 1.65, 1.0]

# Paylines: each is an array of [col, row] positions
const PAYLINES_TIER_1: Array = [  # 50 Mora — middle row
	[[0,1], [1,1], [2,1]],
]
const PAYLINES_TIER_2: Array = [  # 100 Mora — all horizontal
	[[0,0], [1,0], [2,0]],
	[[0,1], [1,1], [2,1]],
	[[0,2], [1,2], [2,2]],
]
const PAYLINES_TIER_3: Array = [  # 150 Mora — all 8 lines
	[[0,0], [1,0], [2,0]],
	[[0,1], [1,1], [2,1]],
	[[0,2], [1,2], [2,2]],
	[[0,0], [0,1], [0,2]],
	[[1,0], [1,1], [1,2]],
	[[2,0], [2,1], [2,2]],
	[[0,0], [1,1], [2,2]],
	[[0,2], [1,1], [2,0]],
]

const BET_TIERS: Array = [50, 100, 150]

# ── State ────────────────────────────────────────────────────────────────────
var _grid: Array = []  # 3x3 array of element names (result)
var _grid_icons: Array = []  # 3x3 array of TextureRect nodes
var _spinning: bool = false
var _bet_tier: int = 0  # index into BET_TIERS
var _session_winnings: int = 0  # total mora won this session (for score)
var _session_spent: int = 0     # total mora bet this session
var _total_weight: int = 0
var _grid_cells: Array = []     # 3x3 array of PanelContainer cell nodes
var _payline_overlay: Control    # overlay for drawing payline indicators
var _payline_lines: Array = []   # Line2D nodes for paylines

var _payout_value_labels: Dictionary = {}  # element_name -> Label (payout values)
var _payout_2_label: Label  # 2-match payout label

# ── UI references ────────────────────────────────────────────────────────────
var _mora_label: Label
var _bet_labels: Array = []  # Array of Button nodes
var _spin_btn: Button
var _result_label: Label
var _payout_label: Label

func _ready() -> void:
	# Calculate total weight
	for e in ELEMENTS:
		_total_weight += e["weight"]

	# Initialize grid
	_grid = []
	_grid_icons = []
	_grid_cells = []
	for col in 3:
		_grid.append(["", "", ""])
		_grid_icons.append([null, null, null])
		_grid_cells.append([null, null, null])

	_build_ui()

func _build_ui() -> void:
	# Full-screen background
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.02, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Gold border frame
	var frame = PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.border_color = Color(0.85, 0.7, 0.3, 0.6)
	fsb.set_border_width_all(3)
	fsb.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fsb)
	add_child(frame)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "Ninguang's Golden Parlor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	main_vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "\"Every Mora counts... especially mine.\""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.6, 0.35))
	main_vbox.add_child(subtitle)

	# Mora display
	_mora_label = Label.new()
	_mora_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mora_label.add_theme_font_size_override("font_size", 24)
	_mora_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_update_mora_display()
	main_vbox.add_child(_mora_label)

	# Content: payout table on left, grid in center, info on right
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 40)
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(content_hbox)

	# Payout table
	content_hbox.add_child(_build_payout_table())

	# Reel grid
	content_hbox.add_child(_build_reel_grid())

	# Right side info panel
	content_hbox.add_child(_build_info_panel())

	# Bet selection
	var bet_hbox = HBoxContainer.new()
	bet_hbox.add_theme_constant_override("separation", 16)
	bet_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var bet_label = Label.new()
	bet_label.text = "Bet:"
	bet_label.add_theme_font_size_override("font_size", 20)
	bet_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
	bet_hbox.add_child(bet_label)

	for i in BET_TIERS.size():
		var btn = Button.new()
		var lines_text = ""
		match i:
			0: lines_text = "1 Line"
			1: lines_text = "3 Lines"
			2: lines_text = "8 Lines"
		btn.text = "%d Mora (%s)" % [BET_TIERS[i], lines_text]
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_set_bet_tier.bind(i))
		_bet_labels.append(btn)
		bet_hbox.add_child(btn)

	main_vbox.add_child(bet_hbox)
	_update_bet_highlight()

	# Spin button
	_spin_btn = Button.new()
	_spin_btn.text = "SPIN"
	_spin_btn.custom_minimum_size = Vector2(300, 60)
	_spin_btn.add_theme_font_size_override("font_size", 28)
	_spin_btn.pressed.connect(_on_spin)
	main_vbox.add_child(_spin_btn)

	# Result label
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 26)
	_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_result_label.text = ""
	main_vbox.add_child(_result_label)

	# Bottom row: session winnings + close
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 20)
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	_payout_label = Label.new()
	_payout_label.text = "Session: 0 Mora"
	_payout_label.add_theme_font_size_override("font_size", 18)
	_payout_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bottom_hbox.add_child(_payout_label)

	var close_btn = Button.new()
	close_btn.text = "Leave Table"
	close_btn.pressed.connect(_on_close)
	bottom_hbox.add_child(close_btn)

	main_vbox.add_child(bottom_hbox)
	_update_cell_highlights()

func _build_payout_table() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size = Vector2(220, 0)

	var header = Label.new()
	header.text = "Payouts"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Ordered from jackpot to common
	var order = ["Hydro", "Dendro", "Cryo", "Electro", "Pyro", "Geo", "Anemo"]
	for elem_name in order:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl = Label.new()
		lbl.text = "%s x3" % elem_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 15)
		var base_payout = PAYOUTS_3[elem_name]
		var color = Color(0.7, 0.7, 0.7)
		if base_payout >= 2000:
			color = Color(0.3, 0.7, 1.0)
		elif base_payout >= 700:
			color = Color(0.8, 0.5, 1.0)
		elif base_payout >= 300:
			color = Color(1.0, 0.6, 0.3)
		lbl.add_theme_color_override("font_color", color)
		row.add_child(lbl)
		var val = Label.new()
		val.text = "%d" % int(round(base_payout * TIER_MULTIPLIERS[_bet_tier]))
		val.add_theme_font_size_override("font_size", 15)
		val.add_theme_color_override("font_color", color)
		_payout_value_labels[elem_name] = val
		row.add_child(val)
		vbox.add_child(row)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	_payout_2_label = Label.new()
	_payout_2_label.text = "Any x2 = %d" % int(round(PAYOUT_2 * TIER_MULTIPLIERS[_bet_tier]))
	_payout_2_label.add_theme_font_size_override("font_size", 14)
	_payout_2_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_payout_2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_payout_2_label)

	return vbox

func _build_reel_grid() -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 1.0)
	sb.border_color = Color(0.85, 0.7, 0.3, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	for row in 3:
		for col in 3:
			var cell = PanelContainer.new()
			cell.custom_minimum_size = Vector2(120, 120)
			var csb = StyleBoxFlat.new()
			csb.bg_color = Color(0.1, 0.08, 0.05, 1.0)
			csb.border_color = Color(0.5, 0.4, 0.2, 0.5)
			csb.set_border_width_all(1)
			csb.set_corner_radius_all(4)
			cell.add_theme_stylebox_override("panel", csb)

			var tex_rect = TextureRect.new()
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(80, 80)
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			cell.add_child(tex_rect)

			_grid_icons[col][row] = tex_rect
			_grid_cells[col][row] = cell
			grid.add_child(cell)

	panel.add_child(grid)

	# Overlay for drawing payline indicators on top of the grid
	_payline_overlay = Control.new()
	_payline_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_payline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_payline_overlay)

	return panel

func _build_info_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(220, 0)

	var header = Label.new()
	header.text = "Bet Tiers"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var tiers_info = [
		"50 Mora = Middle row",
		"100 Mora = All 3 rows",
		"150 Mora = All 8 lines",
	]
	for info in tiers_info:
		var lbl = Label.new()
		lbl.text = info
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

	return vbox

# ── Bet selection ────────────────────────────────────────────────────────────

func _set_bet_tier(tier_index: int) -> void:
	if _spinning:
		return
	_bet_tier = tier_index
	_update_bet_highlight()
	_update_cell_highlights()
	_update_payout_display()

func _update_payout_display() -> void:
	var mult = TIER_MULTIPLIERS[_bet_tier]
	for elem_name in _payout_value_labels:
		_payout_value_labels[elem_name].text = "%d" % int(round(PAYOUTS_3[elem_name] * mult))
	if _payout_2_label:
		_payout_2_label.text = "Any x2 = %d" % int(round(PAYOUT_2 * mult))

func _update_bet_highlight() -> void:
	for i in _bet_labels.size():
		var btn: Button = _bet_labels[i]
		if i == _bet_tier:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			btn.remove_theme_color_override("font_color")

func _update_cell_highlights() -> void:
	# Clear old payline indicators
	for line_node in _payline_lines:
		if is_instance_valid(line_node):
			line_node.queue_free()
	_payline_lines.clear()

	# We need to draw lines after the grid has laid out, so defer one frame
	_draw_paylines.call_deferred()

func _draw_paylines() -> void:
	if not is_instance_valid(_payline_overlay):
		return

	# Cell size + spacing from the grid
	var cell_size = 120.0
	var spacing = 8.0
	var margin = 12.0  # content margin of the panel
	var step = cell_size + spacing

	# Center of each cell relative to the overlay
	# Grid is row-major: row 0 col 0, row 0 col 1, row 0 col 2, row 1 col 0, ...
	# Cell center at (col, row) = margin + col*step + cell_size/2
	var centers: Array = []  # [col][row] = Vector2
	for col in 3:
		var col_centers = []
		for row in 3:
			col_centers.append(Vector2(
				margin + col * step + cell_size / 2.0,
				margin + row * step + cell_size / 2.0
			))
		centers.append(col_centers)

	# Define which paylines belong to which tier for color coding
	# Tier 1: middle horizontal (gold)
	# Tier 2: top + bottom horizontal (gold, slightly different shade)
	# Tier 3 extras: 3 vertical (cyan) + 2 diagonal (magenta)
	var gold = Color(0.95, 0.8, 0.2, 0.6)
	var cyan = Color(0.2, 0.85, 0.95, 0.6)
	var magenta = Color(0.9, 0.3, 0.8, 0.6)

	# Horizontal lines (tiers 1 and 2)
	if _bet_tier >= 0:
		# Middle row — always active
		_add_payline(centers[0][1], centers[2][1], gold)
	if _bet_tier >= 1:
		# Top and bottom rows
		_add_payline(centers[0][0], centers[2][0], gold)
		_add_payline(centers[0][2], centers[2][2], gold)
	if _bet_tier >= 2:
		# Vertical lines
		_add_payline(centers[0][0], centers[0][2], cyan)
		_add_payline(centers[1][0], centers[1][2], cyan)
		_add_payline(centers[2][0], centers[2][2], cyan)
		# Diagonal lines
		_add_payline(centers[0][0], centers[2][2], magenta)
		_add_payline(centers[0][2], centers[2][0], magenta)

func _add_payline(from: Vector2, to: Vector2, color: Color) -> void:
	var line = Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.default_color = color
	line.width = 3.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_payline_overlay.add_child(line)
	_payline_lines.append(line)

# ── Spin logic ───────────────────────────────────────────────────────────────

func _on_spin() -> void:
	if _spinning:
		return
	var bet = BET_TIERS[_bet_tier]
	var current_mora = int(Global.Current_Party.get("Mora", 0))
	if current_mora < bet:
		_result_label.text = "Not enough Mora!"
		_result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return

	_spinning = true
	_spin_btn.disabled = true
	_result_label.text = ""

	# Deduct bet
	_update_mora(current_mora - bet)
	_session_spent += bet

	# Generate final results
	for col in 3:
		for row in 3:
			_grid[col][row] = _pick_random_element()

	# Animate reels
	await _animate_reels()

	# Evaluate winnings (apply tier multiplier)
	var raw_winnings = _evaluate_winnings()
	var winnings = int(round(raw_winnings * TIER_MULTIPLIERS[_bet_tier]))
	if winnings > 0:
		var new_mora = int(Global.Current_Party.get("Mora", 0)) + winnings
		_update_mora(new_mora)
		_session_winnings += winnings
		_result_label.text = "Won %d Mora!" % winnings
		_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		_result_label.text = "No luck this time..."
		_result_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	var net = _session_winnings - _session_spent
	if net >= 0:
		_payout_label.text = "Session: +%d Mora" % net
		_payout_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		_payout_label.text = "Session: %d Mora" % net
		_payout_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_spinning = false
	_spin_btn.disabled = false

func _pick_random_element() -> String:
	var roll = randi() % _total_weight
	var cumulative = 0
	for e in ELEMENTS:
		cumulative += e["weight"]
		if roll < cumulative:
			return e["name"]
	return ELEMENTS[0]["name"]

func _get_element_icon(element_name: String) -> Texture2D:
	for e in ELEMENTS:
		if e["name"] == element_name:
			return load(e["icon"])
	return null

# ── Reel animation ───────────────────────────────────────────────────────────

func _animate_reels() -> void:
	# Animate each column stopping left to right
	for col in 3:
		# Rapid cycle through random symbols
		var cycles = 8 + col * 4  # more cycles for later columns
		for i in cycles:
			for row in 3:
				var rand_elem = ELEMENTS[randi() % ELEMENTS.size()]["name"]
				_grid_icons[col][row].texture = _get_element_icon(rand_elem)
			await get_tree().create_timer(0.06).timeout

		# Land on final result
		for row in 3:
			_grid_icons[col][row].texture = _get_element_icon(_grid[col][row])

		# Brief pause between columns stopping
		if col < 2:
			await get_tree().create_timer(0.3).timeout

# ── Winning evaluation ───────────────────────────────────────────────────────

func _evaluate_winnings() -> int:
	var active_paylines: Array
	match _bet_tier:
		0: active_paylines = PAYLINES_TIER_1
		1: active_paylines = PAYLINES_TIER_2
		2: active_paylines = PAYLINES_TIER_3
		_: active_paylines = PAYLINES_TIER_1

	var total = 0
	for line in active_paylines:
		var symbols = []
		for pos in line:
			symbols.append(_grid[pos[0]][pos[1]])

		# Check for 3-match
		if symbols[0] == symbols[1] and symbols[1] == symbols[2]:
			total += PAYOUTS_3.get(symbols[0], 0)
		# Check for 2-match (first two, last two, or first and last)
		elif symbols[0] == symbols[1] or symbols[1] == symbols[2] or symbols[0] == symbols[2]:
			total += PAYOUT_2

	return total

# ── Mora helpers ─────────────────────────────────────────────────────────────

func _update_mora(new_amount: int) -> void:
	var party_id = int(Global.Current_Party.get("id", 0))
	Global.Update_Records([{
		"table": "Party",
		"record_id": party_id,
		"field": "Mora",
		"value": new_amount,
	}])
	_update_mora_display()

func _update_mora_display() -> void:
	var mora = int(Global.Current_Party.get("Mora", 0))
	_mora_label.text = "Mora: %d" % mora

# ── Close / save ─────────────────────────────────────────────────────────────

func _on_close() -> void:
	# Save session result
	if _session_winnings > 0 and not Global.ACTIVE_USER_NAME.is_empty():
		Global.Insert("Minigames_Results",
			["Player", "Minigame", "Score", "Date"],
			[Global.ACTIVE_USER_NAME, "Ninguang Slots", _session_winnings,
			 Time.get_datetime_string_from_system()])

	game_finished.emit(_session_winnings)

	# Close the window
	var win = get_parent()
	while win and not (win is Window):
		win = win.get_parent()
	if win and win is Window:
		win.queue_free()
