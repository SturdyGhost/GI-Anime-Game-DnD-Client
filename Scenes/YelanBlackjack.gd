extends Control
## Yelan's Table — Genshin-themed Blackjack, played by real casino rules.
##
## Ruleset (≈0.5% house edge with basic strategy):
##   • 6-deck shoe, reshuffled at ~25% penetration
##   • Blackjack (natural 21) pays 3:2
##   • Dealer stands on all 17s (S17)
##   • Double down on any first two cards (incl. after a split)
##   • Split pairs up to 4 hands; split Aces get one card each and stand
##   • Insurance offered when the dealer shows an Ace (pays 2:1)
##
## Cards use the four elements as suits (Pyro/Hydro/Cryo/Electro). Face cards are
## Genshin nobility: Jack = Venti, Queen = Furina, King = Zhongli.

signal game_finished(score: int)

# ── Deck definition ───────────────────────────────────────────────────────────
const SUITS: Array = [
	{"name": "Pyro",    "icon": "res://UI/Element Icons/Fire.png",     "color": Color(0.95, 0.40, 0.30)},
	{"name": "Hydro",   "icon": "res://UI/Element Icons/Water.png",    "color": Color(0.35, 0.62, 1.00)},
	{"name": "Cryo",    "icon": "res://UI/Element Icons/Ice.png",      "color": Color(0.55, 0.88, 0.95)},
	{"name": "Electro", "icon": "res://UI/Element Icons/Electric.png", "color": Color(0.74, 0.48, 0.96)},
]
const RANKS: Array = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
# Face cards → Genshin characters (avatar art in the misspelled "Portaits" dir).
const FACES: Dictionary = {
	"J": {"name": "Venti",   "art": "res://UI/Character Portaits/ui-avataricon-venti.png"},
	"Q": {"name": "Furina",  "art": "res://UI/Character Portaits/ui-avataricon-furina.png"},
	"K": {"name": "Zhongli", "art": "res://UI/Character Portaits/ui-avataricon-zhongli.png"},
}

const BET_TIERS: Array = [50, 100, 250, 500]
const NUM_DECKS: int = 6
const RESHUFFLE_AT: int = 78          # reshuffle when fewer than this remain (~25% of 312)
const DEALER_STANDS_ON: int = 17      # S17 — dealer stands on all 17s
const MAX_HANDS: int = 4

# ── State ─────────────────────────────────────────────────────────────────────
var _shoe: Array = []
var _hands: Array = []          # array of hand dicts (see _new_hand)
var _active_hand: int = 0
var _dealer_hand: Array = []
var _dealer_revealed: bool = false
var _phase: String = "bet"      # "bet" | "insurance" | "player" | "resolving"
var _bet_tier: int = 0
var _insurance_bet: int = 0
var _session_net: int = 0
var _session_best: int = 0
var _round_start_net: int = 0

# ── UI refs ───────────────────────────────────────────────────────────────────
var _mora_label: Label
var _dealer_box: HBoxContainer
var _player_hands_box: HBoxContainer
var _dealer_value_label: Label
var _bet_buttons: Array = []
var _deal_btn: Button
var _hit_btn: Button
var _stand_btn: Button
var _double_btn: Button
var _split_btn: Button
var _ins_yes_btn: Button
var _ins_no_btn: Button
var _ins_row: HBoxContainer
var _result_label: Label
var _session_label: Label

func _new_hand(bet: int) -> Dictionary:
	return {"cards": [], "bet": bet, "done": false, "doubled": false, "from_split": false, "split_aces": false, "result": ""}

func _ready() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
		preload("res://Scenes/settings_popup.gd").load_and_apply_sfx_volume()
	_build_ui()
	_refresh_controls()

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.08, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var frame = PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.border_color = Color(0.25, 0.78, 0.78, 0.55)
	fsb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", fsb)
	add_child(frame)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title = Label.new()
	title.text = "Yelan's Table — 21"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 0.85))
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "\"Care to make this a little more... interesting?\""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.7, 0.7))
	vbox.add_child(subtitle)

	_mora_label = Label.new()
	_mora_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mora_label.add_theme_font_size_override("font_size", 38)
	_mora_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(_mora_label)

	# Dealer
	vbox.add_child(_make_header("Yelan", Color(0.35, 0.85, 0.85)))
	_dealer_value_label = _make_value_label()
	vbox.add_child(_dealer_value_label)
	_dealer_box = _make_card_row()
	vbox.add_child(_dealer_box)

	vbox.add_child(HSeparator.new())

	# Player (one column per hand)
	vbox.add_child(_make_header("You", Color(0.7, 0.85, 1.0)))
	_player_hands_box = HBoxContainer.new()
	_player_hands_box.add_theme_constant_override("separation", 22)
	_player_hands_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_hands_box.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(_player_hands_box)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 38)
	_result_label.custom_minimum_size = Vector2(0, 46)
	vbox.add_child(_result_label)

	# Insurance prompt (hidden unless dealer shows an Ace)
	_ins_row = HBoxContainer.new()
	_ins_row.add_theme_constant_override("separation", 14)
	_ins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ins_lbl = Label.new()
	ins_lbl.text = "Dealer shows an Ace — Insurance?"
	ins_lbl.add_theme_font_size_override("font_size", 30)
	ins_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	_ins_row.add_child(ins_lbl)
	_ins_yes_btn = Button.new()
	_ins_yes_btn.custom_minimum_size = Vector2(150, 50)
	_ins_yes_btn.pressed.connect(_on_insurance.bind(true))
	_ins_row.add_child(_ins_yes_btn)
	_ins_no_btn = Button.new()
	_ins_no_btn.text = "No"
	_ins_no_btn.custom_minimum_size = Vector2(120, 50)
	_ins_no_btn.pressed.connect(_on_insurance.bind(false))
	_ins_row.add_child(_ins_no_btn)
	vbox.add_child(_ins_row)

	# Bet selector
	var bet_row = HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 12)
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var bet_lbl = Label.new()
	bet_lbl.text = "Wager:"
	bet_lbl.add_theme_font_size_override("font_size", 30)
	bet_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.8))
	bet_row.add_child(bet_lbl)
	for i in BET_TIERS.size():
		var b = Button.new()
		b.text = "%d" % BET_TIERS[i]
		b.custom_minimum_size = Vector2(110, 42)
		b.pressed.connect(_on_set_bet.bind(i))
		_bet_buttons.append(b)
		bet_row.add_child(b)
	vbox.add_child(bet_row)

	# Actions
	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_deal_btn   = _make_action_btn("Deal", _on_deal)
	_hit_btn    = _make_action_btn("Hit", _on_hit)
	_stand_btn  = _make_action_btn("Stand", _on_stand)
	_double_btn = _make_action_btn("Double", _on_double)
	_split_btn  = _make_action_btn("Split", _on_split)
	for b in [_deal_btn, _hit_btn, _stand_btn, _double_btn, _split_btn]:
		action_row.add_child(b)
	vbox.add_child(action_row)

	var note = Label.new()
	note.text = "6 decks · Blackjack pays 3:2 · Dealer stands on 17 · Double / Split / Insurance"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(0.5, 0.55, 0.55))
	vbox.add_child(note)

	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 24)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_session_label = Label.new()
	_session_label.text = "Session: 0 Mora"
	_session_label.add_theme_font_size_override("font_size", 28)
	_session_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bottom.add_child(_session_label)
	var leave = Button.new()
	leave.text = "Leave Table"
	leave.pressed.connect(_on_close)
	bottom.add_child(leave)
	vbox.add_child(bottom)

	_update_mora_display()
	_update_bet_highlight()
	_render()

func _make_action_btn(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 56)
	b.add_theme_font_size_override("font_size", 32)
	b.pressed.connect(cb)
	return b

func _make_header(text: String, col: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", col)
	return l

func _make_value_label() -> Label:
	var l = Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	return l

func _make_card_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, 166)
	return row

# ── Card node ─────────────────────────────────────────────────────────────────
func _make_card_node(card: Dictionary, hidden: bool = false) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(112, 160)
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)

	if hidden:
		sb.bg_color = Color(0.06, 0.16, 0.18)
		sb.border_color = Color(0.25, 0.78, 0.78, 0.85)
		panel.add_theme_stylebox_override("panel", sb)
		var cc = CenterContainer.new()
		var mark = Label.new()
		mark.text = "❖"
		mark.add_theme_font_size_override("font_size", 58)
		mark.add_theme_color_override("font_color", Color(0.3, 0.8, 0.8))
		cc.add_child(mark)
		panel.add_child(cc)
		return panel

	sb.bg_color = Color(0.97, 0.96, 0.92)
	sb.border_color = Color(0.7, 0.72, 0.75)
	panel.add_theme_stylebox_override("panel", sb)

	var rank := str(card.get("rank", "?"))
	var suit := _suit_def(str(card.get("element", "")))
	var col: Color = suit.get("color", Color.BLACK)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)

	# Top row: rank + small suit element icon
	var top = HBoxContainer.new()
	var rl = Label.new()
	rl.text = rank
	rl.add_theme_font_size_override("font_size", 28)
	rl.add_theme_color_override("font_color", col)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rl)
	var suit_icon = TextureRect.new()
	if ResourceLoader.exists(str(suit.get("icon", ""))):
		suit_icon.texture = load(str(suit.get("icon", "")))
	suit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	suit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	suit_icon.custom_minimum_size = Vector2(26, 26)
	top.add_child(suit_icon)
	v.add_child(top)

	# Center: character avatar for face cards, else the suit element icon big
	var center_img = TextureRect.new()
	center_img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	center_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center_img.custom_minimum_size = Vector2(72, 72)
	center_img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if FACES.has(rank):
		var art := str(FACES[rank]["art"])
		if ResourceLoader.exists(art):
			center_img.texture = load(art)
	else:
		if ResourceLoader.exists(str(suit.get("icon", ""))):
			center_img.texture = load(str(suit.get("icon", "")))
	v.add_child(center_img)

	# Face cards get a tiny name caption; pips/ace get the rank again
	var bot = Label.new()
	if FACES.has(rank):
		bot.text = str(FACES[rank]["name"])
		bot.add_theme_font_size_override("font_size", 20)
	else:
		bot.text = rank
		bot.add_theme_font_size_override("font_size", 28)
	bot.add_theme_color_override("font_color", col)
	bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(bot)

	panel.add_child(v)
	return panel

func _suit_def(elem: String) -> Dictionary:
	for s in SUITS:
		if s["name"] == elem:
			return s
	return SUITS[0]

# ── Shoe / values ─────────────────────────────────────────────────────────────
func _build_shoe() -> void:
	_shoe.clear()
	for d in NUM_DECKS:
		for s in SUITS:
			for r in RANKS:
				_shoe.append({"rank": r, "element": s["name"]})
	_shoe.shuffle()

func _draw_card() -> Dictionary:
	if _shoe.size() < RESHUFFLE_AT:
		_build_shoe()
	return _shoe.pop_back()

func _card_value(rank: String) -> int:
	if rank == "A":
		return 11
	if rank == "K" or rank == "Q" or rank == "J":
		return 10
	return int(rank)

func _hand_value(hand: Array) -> int:
	var total := 0
	var aces := 0
	for c in hand:
		var r := str(c.get("rank", ""))
		total += _card_value(r)
		if r == "A":
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total

func _is_pair(hand: Dictionary) -> bool:
	var cards: Array = hand["cards"]
	if cards.size() != 2:
		return false
	return _card_value(str(cards[0].rank)) == _card_value(str(cards[1].rank))

# ── Render ────────────────────────────────────────────────────────────────────
func _render() -> void:
	for c in _dealer_box.get_children():
		c.queue_free()
	for i in _dealer_hand.size():
		var hidden := (i == 1 and not _dealer_revealed)
		_dealer_box.add_child(_make_card_node(_dealer_hand[i], hidden))
	_dealer_value_label.text = _dealer_value_text()

	for c in _player_hands_box.get_children():
		c.queue_free()
	for i in _hands.size():
		_player_hands_box.add_child(_make_hand_column(i))

func _make_hand_column(i: int) -> Control:
	var hand: Dictionary = _hands[i]
	var wrap = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	var active := (i == _active_hand and _phase == "player")
	sb.border_color = Color(0.4, 0.95, 0.95, 0.9) if active else Color(0, 0, 0, 0)
	wrap.add_theme_stylebox_override("panel", sb)

	var col_v = VBoxContainer.new()
	col_v.add_theme_constant_override("separation", 4)

	var cards_row = _make_card_row()
	for card in hand["cards"]:
		cards_row.add_child(_make_card_node(card))
	col_v.add_child(cards_row)

	var caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 24)
	caption.text = _hand_caption(hand)
	caption.add_theme_color_override("font_color", _hand_caption_color(hand))
	col_v.add_child(caption)

	wrap.add_child(col_v)
	return wrap

func _hand_caption(hand: Dictionary) -> String:
	var v := _hand_value(hand["cards"])
	var s := ""
	if v > 21:
		s = "%d — Bust" % v
	elif v == 21 and hand["cards"].size() == 2 and not hand["from_split"]:
		s = "Blackjack!"
	else:
		s = str(v)
	s += "   ·   %d" % int(hand["bet"])
	if hand["doubled"]:
		s += " (2x)"
	match str(hand.get("result", "")):
		"blackjack", "win": s += "  ✓"
		"lose": s += "  ✗"
		"push": s += "  ="
	return s

func _hand_caption_color(hand: Dictionary) -> Color:
	match str(hand.get("result", "")):
		"blackjack", "win": return Color(0.4, 1.0, 0.5)
		"lose": return Color(1.0, 0.45, 0.45)
		"push": return Color(0.8, 0.8, 0.6)
	if _hand_value(hand["cards"]) > 21:
		return Color(1.0, 0.45, 0.45)
	return Color(0.85, 0.85, 0.85)

func _dealer_value_text() -> String:
	if _dealer_hand.is_empty():
		return ""
	if not _dealer_revealed:
		return str(_hand_value([_dealer_hand[0]]))
	var v := _hand_value(_dealer_hand)
	if v > 21:
		return "%d — Bust" % v
	if v == 21 and _dealer_hand.size() == 2:
		return "Blackjack!"
	return str(v)

# ── Controls ──────────────────────────────────────────────────────────────────
func _refresh_controls() -> void:
	var betting := _phase == "bet"
	var playing := _phase == "player"
	var insuring := _phase == "insurance"

	for b in _bet_buttons:
		b.disabled = not betting
	_deal_btn.disabled = not betting

	_ins_row.visible = insuring
	if insuring:
		var cost := int(_hands[0]["bet"] / 2)
		_ins_yes_btn.text = "Yes (%d)" % cost
		_ins_yes_btn.disabled = _mora() < cost

	if playing:
		var hand: Dictionary = _hands[_active_hand]
		var two: bool = hand["cards"].size() == 2
		_hit_btn.disabled = hand["split_aces"]
		_stand_btn.disabled = false
		_double_btn.disabled = not (two and not hand["split_aces"] and _mora() >= int(hand["bet"]))
		_split_btn.disabled = not (two and not hand["split_aces"] and _is_pair(hand) \
			and _hands.size() < MAX_HANDS and _mora() >= int(hand["bet"]))
	else:
		_hit_btn.disabled = true
		_stand_btn.disabled = true
		_double_btn.disabled = true
		_split_btn.disabled = true

func _on_set_bet(i: int) -> void:
	if _phase != "bet":
		return
	_bet_tier = i
	_update_bet_highlight()

func _update_bet_highlight() -> void:
	for i in _bet_buttons.size():
		var b: Button = _bet_buttons[i]
		if i == _bet_tier:
			b.add_theme_color_override("font_color", Color(0.4, 0.95, 0.95))
		else:
			b.remove_theme_color_override("font_color")

# ── Round flow ────────────────────────────────────────────────────────────────
func _on_deal() -> void:
	if _phase != "bet":
		return
	var bet: int = BET_TIERS[_bet_tier]
	if _mora() < bet:
		_show_result("Not enough Mora!", Color(1, 0.35, 0.35))
		return

	_round_start_net = _session_net
	_insurance_bet = 0
	_dealer_revealed = false
	_result_label.text = ""
	_active_hand = 0

	_set_mora(_mora() - bet)
	_session_net -= bet
	var hand := _new_hand(bet)
	_hands = [hand]
	_dealer_hand = []

	_phase = "resolving"
	_refresh_controls()
	hand["cards"].append(_draw_card()); _render(); _sfx_flip(); await _pause(0.22)
	_dealer_hand.append(_draw_card()); _render(); _sfx_flip(); await _pause(0.22)
	hand["cards"].append(_draw_card()); _render(); _sfx_flip(); await _pause(0.22)
	_dealer_hand.append(_draw_card()); _render(); _sfx_flip(); await _pause(0.22)

	# Insurance offered when the dealer's up-card is an Ace.
	if str(_dealer_hand[0].rank) == "A":
		_phase = "insurance"
		_refresh_controls()
		return
	await _post_deal_checks()

func _on_insurance(take: bool) -> void:
	if _phase != "insurance":
		return
	if take:
		var cost := int(_hands[0]["bet"] / 2)
		if _mora() >= cost:
			_insurance_bet = cost
			_set_mora(_mora() - cost)
			_session_net -= cost
	await _post_deal_checks()

## After the deal (and any insurance decision), the dealer peeks: if anyone has a
## natural the round resolves immediately, otherwise the player starts acting.
func _post_deal_checks() -> void:
	if _hand_value(_hands[0]["cards"]) == 21 or _hand_value(_dealer_hand) == 21:
		await _finish_round()
		return
	_phase = "player"
	_render()
	_refresh_controls()

func _on_hit() -> void:
	if _phase != "player":
		return
	var hand: Dictionary = _hands[_active_hand]
	hand["cards"].append(_draw_card())
	_sfx_flip()
	var v := _hand_value(hand["cards"])
	if v >= 21:
		hand["done"] = true
		await _advance_hand()
	else:
		_render()
		_refresh_controls()

func _on_stand() -> void:
	if _phase != "player":
		return
	_hands[_active_hand]["done"] = true
	await _advance_hand()

func _on_double() -> void:
	if _phase != "player":
		return
	var hand: Dictionary = _hands[_active_hand]
	if hand["cards"].size() != 2 or _mora() < int(hand["bet"]):
		return
	_set_mora(_mora() - int(hand["bet"]))
	_session_net -= int(hand["bet"])
	hand["bet"] = int(hand["bet"]) * 2
	hand["doubled"] = true
	hand["cards"].append(_draw_card())
	_sfx_flip()
	hand["done"] = true
	await _advance_hand()

func _on_split() -> void:
	if _phase != "player":
		return
	var hand: Dictionary = _hands[_active_hand]
	if not _is_pair(hand) or _hands.size() >= MAX_HANDS or _mora() < int(hand["bet"]):
		return
	var are_aces := str(hand["cards"][0].rank) == "A" and str(hand["cards"][1].rank) == "A"

	_set_mora(_mora() - int(hand["bet"]))
	_session_net -= int(hand["bet"])

	var new_hand := _new_hand(int(hand["bet"]))
	new_hand["from_split"] = true
	hand["from_split"] = true
	new_hand["cards"].append(hand["cards"].pop_back())
	hand["cards"].append(_draw_card())
	new_hand["cards"].append(_draw_card())
	_hands.insert(_active_hand + 1, new_hand)
	_sfx_flip()

	if are_aces:
		# Split aces: one card each (already dealt), then both stand.
		hand["split_aces"] = true
		new_hand["split_aces"] = true
		hand["done"] = true
		new_hand["done"] = true
		await _advance_hand()
		return

	_render()
	if _hand_value(hand["cards"]) == 21:
		hand["done"] = true
		await _advance_hand()
		return
	_refresh_controls()

## Move to the next hand that still needs play; if none remain, the dealer plays.
func _advance_hand() -> void:
	var next := _active_hand
	while next < _hands.size() and _hands[next]["done"]:
		next += 1
	if next >= _hands.size():
		await _finish_round()
		return
	_active_hand = next
	_render()
	if _hand_value(_hands[_active_hand]["cards"]) == 21:
		_hands[_active_hand]["done"] = true
		await _advance_hand()
		return
	_refresh_controls()

func _finish_round() -> void:
	_phase = "resolving"
	_refresh_controls()
	_dealer_revealed = true
	_render()
	await _pause(0.3)

	var dealer_natural := _hand_value(_dealer_hand) == 21 and _dealer_hand.size() == 2

	# Settle insurance first.
	if _insurance_bet > 0 and dealer_natural:
		var ins_credit := _insurance_bet * 3  # stake back + 2:1 profit
		_set_mora(_mora() + ins_credit)
		_session_net += ins_credit

	# Dealer draws only if a non-natural, non-busted player hand is live.
	var needs_dealer := false
	for h in _hands:
		var v := _hand_value(h["cards"])
		var is_nat: bool = v == 21 and h["cards"].size() == 2 and not h["from_split"]
		if v <= 21 and not is_nat:
			needs_dealer = true
	if needs_dealer and not dealer_natural:
		while _hand_value(_dealer_hand) < DEALER_STANDS_ON:
			await _pause(0.45)
			_dealer_hand.append(_draw_card())
			_render()
			_sfx_flip()
		await _pause(0.3)

	var dv := _hand_value(_dealer_hand)
	var round_credit := 0
	for h in _hands:
		var pv := _hand_value(h["cards"])
		var player_natural: bool = pv == 21 and h["cards"].size() == 2 and not h["from_split"]
		var outcome := _resolve_hand(pv, player_natural, dealer_natural, dv)
		h["result"] = outcome
		match outcome:
			"blackjack": round_credit += int(h["bet"]) + int(round(int(h["bet"]) * 1.5))
			"win": round_credit += int(h["bet"]) * 2
			"push": round_credit += int(h["bet"])
			"lose": round_credit += 0
	if round_credit > 0:
		_set_mora(_mora() + round_credit)
	_session_net += round_credit

	_render()
	_announce_round(dealer_natural)
	_update_session_display()
	_phase = "bet"
	_refresh_controls()

func _resolve_hand(pv: int, player_natural: bool, dealer_natural: bool, dv: int) -> String:
	if pv > 21:
		return "lose"
	if player_natural and dealer_natural:
		return "push"
	if player_natural:
		return "blackjack"
	if dealer_natural:
		return "lose"
	if dv > 21:
		return "win"
	if pv > dv:
		return "win"
	if pv < dv:
		return "lose"
	return "push"

func _announce_round(dealer_natural: bool) -> void:
	var delta := _session_net - _round_start_net
	if _hands.size() == 1 and str(_hands[0]["result"]) == "blackjack":
		_show_result("Blackjack! +%d Mora" % delta, Color(0.4, 1.0, 0.55))
		_sfx_win(true)
	elif delta > 0:
		_show_result("You win  +%d Mora" % delta, Color(0.4, 1.0, 0.5))
		_sfx_win(false)
	elif delta == 0:
		var txt := "Insurance saved you — push." if (_insurance_bet > 0 and dealer_natural) else "Push."
		_show_result(txt, Color(0.85, 0.8, 0.6))
		_sfx_push()
	else:
		_show_result("Yelan takes %d Mora." % (-delta), Color(1.0, 0.45, 0.45))
		_sfx_lose()

func _show_result(text: String, col: Color) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", col)

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

func _sfx_flip() -> void:
	_play_tone(520.0, 0.06, -6.0)

func _sfx_win(blackjack: bool) -> void:
	_play_tone(660.0, 0.12, -2.0)
	await _pause(0.1)
	_play_tone(880.0, 0.12, -2.0)
	if blackjack:
		await _pause(0.1)
		_play_tone(1175.0, 0.25, -2.0)

func _sfx_push() -> void:
	_play_tone(500.0, 0.14, -6.0)

func _sfx_lose() -> void:
	_play_tone(360.0, 0.16, -7.0)
	await _pause(0.08)
	_play_tone(270.0, 0.22, -7.0)

# ── Close / save ──────────────────────────────────────────────────────────────

## Reverse this session's net Mora effect (used when a battle turn force-closes
## the game): the party's Mora ends up exactly as it was before they sat down.
func wager_refund() -> void:
	if _session_net != 0:
		_set_mora(_mora() - _session_net)
	_session_net = 0

func _on_close() -> void:
	if _session_best > 0 and not Global.ACTIVE_USER_NAME.is_empty():
		Global.Insert("Minigames_Results",
			["Player", "Minigame", "Score", "Date"],
			[Global.ACTIVE_USER_NAME, "Yelan Blackjack", _session_best,
			 Time.get_datetime_string_from_system()])

	game_finished.emit(max(0, _session_best))

	var win = get_parent()
	while win and not (win is Window):
		win = win.get_parent()
	if win and win is Window:
		win.queue_free()
