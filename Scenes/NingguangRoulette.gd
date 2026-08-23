extends Control
## Ningguang's Wheel of Fortune — Genshin-themed American roulette.
##
## Ruleset (standard American wheel, 5.26% house edge):
##   • 38 pockets: 0, 00, and 1–36
##   • Straight-up (single number) pays 35:1
##   • Dozens (1st/2nd/3rd 12) and Columns pay 2:1
##   • Red/Black, Even/Odd, 1–18 / 19–36 pay 1:1 (all lose on 0 and 00)
##
## Place any number of chips across the board, then spin. Mora is deducted as you
## place chips; "Undo" / "Clear" refund unspun bets. The green felt + gold/jade
## styling matches Ningguang's Golden Parlor (she also runs the slots).

signal game_finished(score: int)

# ── Wheel definition ──────────────────────────────────────────────────────────
# Instead of red/black, the 36 numbers are split evenly across the four core
# elements (9 each). 0 and 00 stay green (the house). Element bets pay 3:1, which
# keeps the same 5.26% house edge as the rest of the American wheel.
const POCKET_00: int = 37          # internal id for the "00" pocket
const NUM_POCKETS: int = 38        # 0, 00, 1–36

# Element membership (must stay in sync with RouletteWheel.gd).
const PYRO_NUMBERS: Array    = [1, 5, 9, 14, 18, 21, 25, 30, 34]
const HYDRO_NUMBERS: Array   = [2, 6, 10, 13, 17, 22, 26, 29, 33]
const ELECTRO_NUMBERS: Array = [3, 7, 12, 16, 19, 23, 27, 32, 36]
const CRYO_NUMBERS: Array    = [4, 8, 11, 15, 20, 24, 28, 31, 35]
const ELEM_KEYS: Array  = ["pyro", "hydro", "electro", "cryo"]
const ELEM_NAMES: Array = ["Pyro", "Hydro", "Electro", "Cryo"]
const ELEM_ICONS: Array = [
	"res://UI/Element Icons/Fire.png",
	"res://UI/Element Icons/Water.png",
	"res://UI/Element Icons/Electric.png",
	"res://UI/Element Icons/Ice.png",
]
# Muted "felt" tones for the number/element cells (white text reads on all four).
const ELEM_CELL: Array = [
	Color(0.55, 0.16, 0.12),   # Pyro
	Color(0.13, 0.30, 0.58),   # Hydro
	Color(0.36, 0.20, 0.52),   # Electro
	Color(0.16, 0.42, 0.50),   # Cryo
]
# Vivid element accents for borders/highlights.
const ELEM_VIVID: Array = [
	Color(0.95, 0.40, 0.30),   # Pyro
	Color(0.35, 0.62, 1.00),   # Hydro
	Color(0.74, 0.48, 0.96),   # Electro
	Color(0.55, 0.88, 0.95),   # Cryo
]

const CHIP_TIERS: Array = [50, 100, 250, 500]
const WheelScript = preload("res://Scenes/RouletteWheel.gd")

# ── Palette (Liyue gold / jade on green felt) ─────────────────────────────────
const COL_GREEN := Color(0.15, 0.62, 0.40)
const COL_GOLD  := Color(1.00, 0.82, 0.35)
const COL_JADE  := Color(0.40, 0.82, 0.66)
const COL_FELT  := Color(0.07, 0.11, 0.09)

## Element index (0=Pyro 1=Hydro 2=Electro 3=Cryo) for a number, or -1 for 0/00.
func _element_index(n: int) -> int:
	if n in PYRO_NUMBERS: return 0
	if n in HYDRO_NUMBERS: return 1
	if n in ELECTRO_NUMBERS: return 2
	if n in CRYO_NUMBERS: return 3
	return -1

# ── Board cell geometry (sized ~33% larger for visibility) ────────────────────
const CELL_W: int = 74
const CELL_H: int = 67
const SEP: int = 5

# ── State ─────────────────────────────────────────────────────────────────────
var _phase: String = "bet"          # "bet" | "spin"
var _chips: Dictionary = {}         # bet_key -> total Mora staked
var _placements: Array = []         # ordered [{key, amount}] for Undo
var _round_bet: int = 0
var _chip_tier: int = 0
var _session_net: int = 0
var _session_best: int = 0
var _history: Array = []            # recent pocket ids, most-recent first
var _highlighted: String = ""

# ── UI refs ───────────────────────────────────────────────────────────────────
var _mora_label: Label
var _wheel: Control
var _msg_label: Label
var _session_label: Label
var _history_box: HBoxContainer
var _spin_btn: Button
var _undo_btn: Button
var _clear_btn: Button
var _chip_buttons: Array = []
var _total_label: Label
var _cells: Dictionary = {}         # key -> {btn, chip, sb}

func _ready() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
		preload("res://Scenes/settings_popup.gd").load_and_apply_sfx_volume()
	_build_ui()
	_refresh_controls()

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.05, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.55)
	fsb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", fsb)
	add_child(frame)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Ningguang's Wheel of Fortune"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 74)
	title.add_theme_color_override("font_color", COL_GOLD)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "\"Mora makes the world turn. Shall we see which way it spins?\""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 32)
	subtitle.add_theme_color_override("font_color", COL_JADE)
	vbox.add_child(subtitle)

	_mora_label = Label.new()
	_mora_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mora_label.add_theme_font_size_override("font_size", 48)
	_mora_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(_mora_label)

	# Two columns: the big wheel on the left, every betting choice on the right.
	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 48)
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER

	# ── Left: the spinning wheel + outcome message + recent history ──
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER

	_wheel = WheelScript.new()
	_wheel.custom_minimum_size = Vector2(1040, 1040)
	_wheel.tick.connect(_sfx_tick)
	left_col.add_child(_wheel)

	_msg_label = Label.new()
	_msg_label.text = "Place your chips."
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 43)
	_msg_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_msg_label.custom_minimum_size = Vector2(1040, 58)
	left_col.add_child(_msg_label)

	var hist_lbl := Label.new()
	hist_lbl.text = "Recent"
	hist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hist_lbl.add_theme_font_size_override("font_size", 24)
	hist_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	left_col.add_child(hist_lbl)

	_history_box = HBoxContainer.new()
	_history_box.add_theme_constant_override("separation", 6)
	_history_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_history_box.custom_minimum_size = Vector2(1040, 44)
	left_col.add_child(_history_box)

	main_row.add_child(left_col)

	# ── Right: the betting board and all controls ──
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 18)
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER

	right_col.add_child(_build_board())

	# Chip-denomination selector.
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 12)
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var chip_lbl := Label.new()
	chip_lbl.text = "Chip:"
	chip_lbl.add_theme_font_size_override("font_size", 37)
	chip_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	chip_row.add_child(chip_lbl)
	for i in CHIP_TIERS.size():
		var b := Button.new()
		b.text = "%d" % CHIP_TIERS[i]
		b.custom_minimum_size = Vector2(146, 59)
		b.add_theme_font_size_override("font_size", 35)
		b.pressed.connect(_on_set_chip.bind(i))
		_chip_buttons.append(b)
		chip_row.add_child(b)
	right_col.add_child(chip_row)

	# Actions + running total.
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 21)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_spin_btn = _make_action_btn("Spin", _on_spin, Vector2(253, 75))
	_undo_btn = _make_action_btn("Undo", _on_undo, Vector2(186, 75))
	_clear_btn = _make_action_btn("Clear", _on_clear, Vector2(186, 75))
	action_row.add_child(_spin_btn)
	action_row.add_child(_undo_btn)
	action_row.add_child(_clear_btn)
	_total_label = Label.new()
	_total_label.text = "Total Bet: 0"
	_total_label.add_theme_font_size_override("font_size", 37)
	_total_label.add_theme_color_override("font_color", COL_GOLD)
	_total_label.custom_minimum_size = Vector2(293, 0)
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_row.add_child(_total_label)
	right_col.add_child(action_row)

	var note := Label.new()
	note.text = "American wheel · Straight-up 35:1 · Dozen/Column 2:1 · Element 3:1 · Even-money 1:1"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 29)
	note.add_theme_color_override("font_color", Color(0.5, 0.55, 0.52))
	right_col.add_child(note)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 32)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_session_label = Label.new()
	_session_label.text = "Session: 0 Mora"
	_session_label.add_theme_font_size_override("font_size", 37)
	_session_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bottom.add_child(_session_label)
	var leave := Button.new()
	leave.text = "Leave Table"
	leave.add_theme_font_size_override("font_size", 37)
	leave.custom_minimum_size = Vector2(0, 64)
	leave.pressed.connect(_on_close)
	bottom.add_child(leave)
	right_col.add_child(bottom)

	main_row.add_child(right_col)
	vbox.add_child(main_row)

	_update_mora_display()
	_update_chip_highlight()
	_refresh_history()

func _build_board() -> Control:
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", SEP)

	# Top: [0 / 00] | 3×12 number grid | column (2:1) buttons.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", SEP)

	var zeros := VBoxContainer.new()
	zeros.add_theme_constant_override("separation", SEP)
	var zh := int((CELL_H * 3 + SEP * 2 - SEP) / 2.0)
	zeros.add_child(_make_cell("straight:0", "0", COL_GREEN, Color.WHITE, CELL_W, zh, 35))
	zeros.add_child(_make_cell("straight:00", "00", COL_GREEN, Color.WHITE, CELL_W, zh, 32))
	top.add_child(zeros)

	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", SEP)
	grid.add_theme_constant_override("v_separation", SEP)
	# Rows top→bottom: (3,6,…36), (2,5,…35), (1,4,…34) — the standard table layout.
	for r in [range(3, 37, 3), range(2, 37, 3), range(1, 37, 3)]:
		for n in r:
			var bg: Color = ELEM_CELL[_element_index(n)]
			grid.add_child(_make_cell("straight:%d" % n, str(n), bg, Color.WHITE, CELL_W, CELL_H, 29))
	top.add_child(grid)

	# Column bets align with their row: top row = n%3==0, mid = n%3==2, bottom = n%3==1.
	var cols := VBoxContainer.new()
	cols.add_theme_constant_override("separation", SEP)
	cols.add_child(_make_cell("col:0", "2:1", COL_FELT, COL_GOLD, CELL_W, CELL_H, 24))
	cols.add_child(_make_cell("col:2", "2:1", COL_FELT, COL_GOLD, CELL_W, CELL_H, 24))
	cols.add_child(_make_cell("col:1", "2:1", COL_FELT, COL_GOLD, CELL_W, CELL_H, 24))
	top.add_child(cols)
	board.add_child(top)

	var indent := CELL_W + SEP   # line dozens/even-money rows up under the number grid

	# Dozens — each spans 4 number columns.
	var dozen_row := HBoxContainer.new()
	dozen_row.add_theme_constant_override("separation", SEP)
	dozen_row.add_child(_spacer(indent))
	var dozen_w := CELL_W * 4 + SEP * 3
	dozen_row.add_child(_make_cell("dozen:1", "1st 12", COL_FELT, COL_GOLD, dozen_w, CELL_H, 27))
	dozen_row.add_child(_make_cell("dozen:2", "2nd 12", COL_FELT, COL_GOLD, dozen_w, CELL_H, 27))
	dozen_row.add_child(_make_cell("dozen:3", "3rd 12", COL_FELT, COL_GOLD, dozen_w, CELL_H, 27))
	board.add_child(dozen_row)

	# Element bets (replaces RED/BLACK) — each spans 3 number columns, pays 3:1.
	var trio_w := CELL_W * 3 + SEP * 2
	var elem_row := HBoxContainer.new()
	elem_row.add_theme_constant_override("separation", SEP)
	elem_row.add_child(_spacer(indent))
	for ei in 4:
		elem_row.add_child(_make_cell("elem:%s" % ELEM_KEYS[ei], ELEM_NAMES[ei],
			ELEM_CELL[ei], Color.WHITE, trio_w, CELL_H, 27, ELEM_ICONS[ei], ELEM_VIVID[ei]))
	board.add_child(elem_row)

	# Even-money — each spans 3 number columns.
	var even_row := HBoxContainer.new()
	even_row.add_theme_constant_override("separation", SEP)
	even_row.add_child(_spacer(indent))
	even_row.add_child(_make_cell("low",  "1–18",  COL_FELT, COL_GOLD, trio_w, CELL_H, 27))
	even_row.add_child(_make_cell("even", "EVEN",  COL_FELT, COL_GOLD, trio_w, CELL_H, 27))
	even_row.add_child(_make_cell("odd",  "ODD",   COL_FELT, COL_GOLD, trio_w, CELL_H, 27))
	even_row.add_child(_make_cell("high", "19–36", COL_FELT, COL_GOLD, trio_w, CELL_H, 27))
	board.add_child(even_row)

	return board

func _make_cell(key: String, text: String, bg: Color, fg: Color, w: int, h: int, fsize: int,
		icon_path: String = "", accent: Color = Color(0, 0, 0, 0)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.text = text
	b.clip_text = true
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)

	# Optional element logo, sized to the cell height.
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(h * 0.62))
		b.add_theme_constant_override("h_separation", 10)

	var has_accent := accent.a > 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	sb.border_color = accent if has_accent else Color(0, 0, 0, 0.35)
	sb.set_border_width_all(2 if has_accent else 1)
	b.add_theme_stylebox_override("normal", sb)

	var hb := sb.duplicate()
	hb.bg_color = bg.lightened(0.12)
	hb.border_color = COL_GOLD
	hb.set_border_width_all(3 if has_accent else 2)
	b.add_theme_stylebox_override("hover", hb)

	var pb := sb.duplicate()
	pb.bg_color = bg.lightened(0.22)
	b.add_theme_stylebox_override("pressed", pb)
	b.add_theme_stylebox_override("disabled", sb)

	b.pressed.connect(_place_on.bind(key))

	# Chip-stack indicator overlaid at the cell's bottom edge (clicks pass through).
	var chip := Label.new()
	chip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	chip.add_theme_font_size_override("font_size", 23)
	chip.add_theme_color_override("font_color", COL_GOLD)
	chip.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	chip.add_theme_constant_override("outline_size", 7)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.visible = false
	b.add_child(chip)

	_cells[key] = {"btn": b, "chip": chip, "sb": sb}
	return b

func _spacer(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c

func _make_action_btn(text: String, cb: Callable, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = sz
	b.add_theme_font_size_override("font_size", 43)
	b.pressed.connect(cb)
	return b

# ── Pocket helpers ────────────────────────────────────────────────────────────
func _pocket_text(id: int) -> String:
	if id == POCKET_00:
		return "00"
	return str(id)

func _pocket_color(id: int) -> Color:
	if id == 0 or id == POCKET_00:
		return COL_GREEN
	return ELEM_CELL[_element_index(id)]

# ── Chip placement ────────────────────────────────────────────────────────────
func _place_on(key: String) -> void:
	if _phase != "bet":
		return
	var amt: int = CHIP_TIERS[_chip_tier]
	if _mora() < amt:
		_flash("Not enough Mora!", Color(0.95, 0.35, 0.30))
		_sfx_deny()
		return
	_set_mora(_mora() - amt)
	_session_net -= amt
	_round_bet += amt
	_chips[key] = int(_chips.get(key, 0)) + amt
	_placements.append({"key": key, "amount": amt})
	_refresh_cell_chip(key)
	_update_total()
	_refresh_controls()
	_sfx_chip()

func _on_undo() -> void:
	if _phase != "bet" or _placements.is_empty():
		return
	var last: Dictionary = _placements.pop_back()
	var key: String = last["key"]
	var amt: int = int(last["amount"])
	_chips[key] = int(_chips.get(key, 0)) - amt
	if int(_chips[key]) <= 0:
		_chips.erase(key)
	_set_mora(_mora() + amt)
	_session_net += amt
	_round_bet -= amt
	_refresh_cell_chip(key)
	_update_total()
	_refresh_controls()
	_sfx_chip()

func _on_clear() -> void:
	if _phase != "bet" or _round_bet <= 0:
		return
	_set_mora(_mora() + _round_bet)
	_session_net += _round_bet
	_round_bet = 0
	var keys := _chips.keys()
	_chips.clear()
	_placements.clear()
	for k in keys:
		_refresh_cell_chip(k)
	_update_total()
	_refresh_controls()

func _refresh_cell_chip(key: String) -> void:
	if not _cells.has(key):
		return
	var chip: Label = _cells[key]["chip"]
	var amt := int(_chips.get(key, 0))
	if amt > 0:
		chip.text = _fmt_chip(amt)
		chip.visible = true
	else:
		chip.visible = false

func _fmt_chip(amt: int) -> String:
	if amt >= 1000:
		return "%.1fk" % (amt / 1000.0)
	return str(amt)

func _update_total() -> void:
	_total_label.text = "Total Bet: %d" % _round_bet

func _on_set_chip(i: int) -> void:
	if _phase != "bet":
		return
	_chip_tier = i
	_update_chip_highlight()

func _update_chip_highlight() -> void:
	for i in _chip_buttons.size():
		var b: Button = _chip_buttons[i]
		if i == _chip_tier:
			b.add_theme_color_override("font_color", COL_GOLD)
		else:
			b.remove_theme_color_override("font_color")

# ── Spin & resolution ─────────────────────────────────────────────────────────
func _on_spin() -> void:
	if _phase != "bet":
		return
	if _chips.is_empty():
		_flash("Place a bet first.", COL_GOLD)
		return
	_clear_highlight()
	_phase = "spin"
	_msg_label.text = "Round and round it goes…"
	_msg_label.add_theme_color_override("font_color", COL_JADE)
	_refresh_controls()

	var result := randi() % NUM_POCKETS
	_wheel.spin(result, 4.6)
	await _wheel.spin_complete
	if not is_inside_tree():
		return
	await _pause(0.35)
	_settle(result)

func _settle(result: int) -> void:
	_history.push_front(result)
	if _history.size() > 14:
		_history.resize(14)
	_refresh_history()

	_highlight_cell("straight:00" if result == POCKET_00 else "straight:%d" % result)

	var total_return := 0
	for key in _chips:
		if _bet_wins(str(key), result):
			total_return += int(_chips[key]) * (_bet_multiplier(str(key)) + 1)
	if total_return > 0:
		_set_mora(_mora() + total_return)
		_session_net += total_return

	var delta := total_return - _round_bet
	_announce(result, delta)

	var keys := _chips.keys()
	_round_bet = 0
	_chips.clear()
	_placements.clear()
	for k in keys:
		_refresh_cell_chip(k)
	_update_total()
	_update_session_display()

	_phase = "bet"
	_refresh_controls()

func _bet_wins(key: String, result: int) -> bool:
	var is_zero := (result == 0 or result == POCKET_00)
	var parts := key.split(":")
	match parts[0]:
		"straight":
			return parts[1] == _pocket_text(result)
		"dozen":
			if is_zero:
				return false
			var d := int(parts[1])
			return result >= (d - 1) * 12 + 1 and result <= d * 12
		"col":
			if is_zero:
				return false
			return result % 3 == int(parts[1])
		"elem":
			return not is_zero and ELEM_KEYS[_element_index(result)] == parts[1]
		"even":
			return not is_zero and result % 2 == 0
		"odd":
			return not is_zero and result % 2 == 1
		"low":
			return not is_zero and result >= 1 and result <= 18
		"high":
			return not is_zero and result >= 19 and result <= 36
	return false

func _bet_multiplier(key: String) -> int:
	var t := key.split(":")[0]
	if t == "straight":
		return 35
	if t == "dozen" or t == "col":
		return 2
	if t == "elem":
		return 3
	return 1

func _announce(result: int, delta: int) -> void:
	var ptext := _pocket_text(result)
	var label := "%s — %s" % [ptext, _pocket_descriptor(result)]
	if delta > 0:
		_msg_label.text = "%s.  You win +%d Mora!" % [label, delta]
		_msg_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		_sfx_win()
	elif delta == 0:
		_msg_label.text = "%s.  You break even." % label
		_msg_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
		_sfx_push()
	else:
		_msg_label.text = "%s.  Ningguang collects %d Mora." % [label, -delta]
		_msg_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		_sfx_lose()

func _pocket_descriptor(id: int) -> String:
	if id == 0 or id == POCKET_00:
		return "House"
	return ELEM_NAMES[_element_index(id)]

func _refresh_history() -> void:
	for c in _history_box.get_children():
		c.queue_free()
	for id in _history:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(30, 30)
		var sb := StyleBoxFlat.new()
		sb.bg_color = _pocket_color(id)
		sb.set_corner_radius_all(15)
		pip.add_theme_stylebox_override("panel", sb)
		var cc := CenterContainer.new()
		var l := Label.new()
		l.text = _pocket_text(id)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color.WHITE)
		cc.add_child(l)
		pip.add_child(cc)
		_history_box.add_child(pip)

func _highlight_cell(key: String) -> void:
	if not _cells.has(key):
		return
	var sb: StyleBoxFlat = _cells[key]["sb"]
	sb.border_color = COL_GOLD
	sb.set_border_width_all(4)
	_highlighted = key

func _clear_highlight() -> void:
	if _highlighted != "" and _cells.has(_highlighted):
		var sb: StyleBoxFlat = _cells[_highlighted]["sb"]
		sb.border_color = Color(0, 0, 0, 0.35)
		sb.set_border_width_all(1)
	_highlighted = ""

func _flash(text: String, col: Color) -> void:
	_msg_label.text = text
	_msg_label.add_theme_color_override("font_color", col)

# ── Controls ──────────────────────────────────────────────────────────────────
func _refresh_controls() -> void:
	var betting := _phase == "bet"
	for b in _chip_buttons:
		b.disabled = not betting
	_spin_btn.disabled = not betting or _chips.is_empty()
	_undo_btn.disabled = not betting or _placements.is_empty()
	_clear_btn.disabled = not betting or _round_bet <= 0
	for key in _cells:
		_cells[key]["btn"].disabled = not betting

func _update_session_display() -> void:
	_session_best = max(_session_best, _session_net)
	if _session_net >= 0:
		_session_label.text = "Session: +%d Mora" % _session_net
		_session_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	else:
		_session_label.text = "Session: %d Mora" % _session_net
		_session_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

# ── Mora helpers ──────────────────────────────────────────────────────────────
func _mora() -> int:
	return int(Global.Current_Party.get("Mora", 0))

func _set_mora(amount: int) -> void:
	var party_id := int(Global.Current_Party.get("id", 0))
	Global.Update_Records([{
		"table": "Party",
		"record_id": party_id,
		"field": "Mora",
		"value": amount,
	}])
	_update_mora_display()

func _update_mora_display() -> void:
	_mora_label.text = "Mora: %d" % _mora()

func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# ── SFX (procedural tones) ────────────────────────────────────────────────────
func _play_tone(freq: float, duration: float, volume_db: float = 0.0) -> void:
	var sample_rate := 44100
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var t := float(i) / sample_rate
		var envelope := exp(-3.0 * t / duration)
		var sample := sin(t * freq * TAU) * envelope * 0.6
		var s16 := int(clamp(sample * 32767.0, -32768, 32767))
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _sfx_chip() -> void:
	_play_tone(680.0, 0.05, -7.0)

func _sfx_deny() -> void:
	_play_tone(200.0, 0.14, -6.0)

func _sfx_tick() -> void:
	_play_tone(900.0, 0.03, -13.0)

func _sfx_win() -> void:
	_play_tone(660.0, 0.12, -2.0)
	await _pause(0.1)
	_play_tone(880.0, 0.12, -2.0)
	await _pause(0.1)
	_play_tone(1175.0, 0.2, -2.0)

func _sfx_push() -> void:
	_play_tone(500.0, 0.14, -6.0)

func _sfx_lose() -> void:
	_play_tone(360.0, 0.16, -7.0)
	await _pause(0.08)
	_play_tone(270.0, 0.22, -7.0)

# ── Close / save ──────────────────────────────────────────────────────────────

## Reverse this session's net Mora effect (used when a battle turn force-closes the
## game): the party's Mora ends up exactly as it was before they sat down.
func wager_refund() -> void:
	if _session_net != 0:
		_set_mora(_mora() - _session_net)
	_session_net = 0

func _on_close() -> void:
	if _session_best > 0 and not Global.ACTIVE_USER_NAME.is_empty():
		Global.Insert("Minigames_Results",
			["Player", "Minigame", "Score", "Date"],
			[Global.ACTIVE_USER_NAME, "Ningguang Roulette", _session_best,
			 Time.get_datetime_string_from_system()])

	game_finished.emit(max(0, _session_best))

	var win = get_parent()
	while win and not (win is Window):
		win = win.get_parent()
	if win and win is Window:
		win.queue_free()
