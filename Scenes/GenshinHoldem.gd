extends Control
## Genshin Texas Hold'em — a faithful no-limit Hold'em table against AI companions.
##
## Rules implemented: 2 hole cards + 5 community (flop/turn/river), small & big
## blinds, dealer button rotation, fold/check/call/raise/all-in, no-limit betting
## with min-raise enforcement, full 7-card best-hand evaluation, and proper side
## pots for all-ins. Cards use the four elements as suits; J/Q/K are Venti /
## Furina / Zhongli.
##
## Opponents are drawn ONLY from companions the party has actually Met, but the
## flavour/taunt library below covers every character so any met companion fits.

signal game_finished(score: int)

# ── Deck (shared theme with the blackjack table) ──────────────────────────────
const SUITS: Array = [
	{"name": "Pyro",    "icon": "res://UI/Element Icons/Fire.png",     "color": Color(0.95, 0.40, 0.30)},
	{"name": "Hydro",   "icon": "res://UI/Element Icons/Water.png",    "color": Color(0.35, 0.62, 1.00)},
	{"name": "Cryo",    "icon": "res://UI/Element Icons/Ice.png",      "color": Color(0.55, 0.88, 0.95)},
	{"name": "Electro", "icon": "res://UI/Element Icons/Electric.png", "color": Color(0.74, 0.48, 0.96)},
]
const RANKS: Array = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const FACES: Dictionary = {
	"J": "res://UI/Character Portaits/ui-avataricon-venti.png",
	"Q": "res://UI/Character Portaits/ui-avataricon-furina.png",
	"K": "res://UI/Character Portaits/ui-avataricon-zhongli.png",
}

const SMALL_BLIND := 10
const BIG_BLIND := 20
const BUYINS := [500, 1000, 2500]
const HAND_NAMES := ["High Card", "Pair", "Two Pair", "Three of a Kind", "Straight",
	"Flush", "Full House", "Four of a Kind", "Straight Flush"]

# ── Palette ───────────────────────────────────────────────────────────────────
const FELT     := Color(0.05, 0.13, 0.10)
const BG_DEEP  := Color(0.04, 0.06, 0.07)
const SEAT_BG  := Color(0.12, 0.15, 0.18)
const SEAT_ON  := Color(0.18, 0.24, 0.22)
const BORDER   := Color(0.25, 0.35, 0.33)
const TEXT     := Color(0.95, 0.96, 0.98)
const TEXT_MUT := Color(0.62, 0.66, 0.70)
const ACCENT   := Color(0.85, 0.72, 0.35)
const GREEN    := Color(0.35, 0.90, 0.50)
const RED      := Color(0.93, 0.35, 0.35)

# ── State ─────────────────────────────────────────────────────────────────────
var _players: Array = []        # seat dicts; index 0 is the human
var _deck: Array = []
var _community: Array = []
var _dealer: int = 0
var _current_bet: int = 0
var _min_raise: int = BIG_BLIND
var _buyin: int = 1000
var _hands_played: int = 0
var _in_hand: bool = false
var _overlay: Control
var _time_scale: float = 1.0  # test hook: scales all pacing pauses
var _cashed_out: bool = false

# human turn handshake
signal _human_done
var _human_result: Dictionary = {}

# ── UI refs ───────────────────────────────────────────────────────────────────
var _seats_box: HBoxContainer
var _community_box: HBoxContainer
var _pot_label: Label
var _player_cards_box: HBoxContainer
var _player_stack_label: Label
var _status_label: Label
var _action_bar: HBoxContainer
var _fold_btn: Button
var _call_btn: Button
var _raise_btn: Button
var _allin_btn: Button
var _raise_slider: HSlider
var _raise_amt_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(2560, 1440)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
		preload("res://Scenes/settings_popup.gd").load_and_apply_sfx_volume()
	_build_ui()
	_show_intro()

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  HAND EVALUATION (pure)                                                    ║
# ╚══════════════════════════════════════════════════════════════════════════╝
func _rank_val(r: String) -> int:
	match r:
		"J": return 11
		"Q": return 12
		"K": return 13
		"A": return 14
		_: return int(r)

## Evaluate exactly 5 cards → comparable score array [category, tiebreakers...].
func _eval5(cards: Array) -> Array:
	var vals: Array = []
	var suit_counts: Dictionary = {}
	var rank_counts: Dictionary = {}
	for c in cards:
		var v: int = _rank_val(str(c.get("rank", "")))
		vals.append(v)
		var s: String = str(c.get("element", ""))
		suit_counts[s] = int(suit_counts.get(s, 0)) + 1
		rank_counts[v] = int(rank_counts.get(v, 0)) + 1
	vals.sort()
	vals.reverse()  # high → low

	var is_flush: bool = suit_counts.size() == 1
	var uniq: Array = []
	for v in vals:
		if not uniq.has(v):
			uniq.append(v)
	var straight_high: int = 0
	if uniq.size() == 5 and int(uniq[0]) - int(uniq[4]) == 4:
		straight_high = int(uniq[0])
	if uniq.size() == 5 and uniq[0] == 14 and uniq[1] == 5 and uniq[4] == 2:
		straight_high = 5  # wheel A-2-3-4-5
	var is_straight: bool = straight_high > 0

	var groups: Array = []   # [count, rankvalue]
	for v in rank_counts:
		groups.append([int(rank_counts[v]), int(v)])
	groups.sort_custom(func(a, b): return (a[0] > b[0]) if a[0] != b[0] else (a[1] > b[1]))

	if is_straight and is_flush:
		return [8, straight_high]
	if int(groups[0][0]) == 4:
		return [7, int(groups[0][1]), int(groups[1][1])]
	if int(groups[0][0]) == 3 and int(groups[1][0]) == 2:
		return [6, int(groups[0][1]), int(groups[1][1])]
	if is_flush:
		var f: Array = [5]
		f.append_array(vals)
		return f
	if is_straight:
		return [4, straight_high]
	if int(groups[0][0]) == 3:
		return [3, int(groups[0][1]), int(groups[1][1]), int(groups[2][1])]
	if int(groups[0][0]) == 2 and int(groups[1][0]) == 2:
		return [2, int(groups[0][1]), int(groups[1][1]), int(groups[2][1])]
	if int(groups[0][0]) == 2:
		return [1, int(groups[0][1]), int(groups[1][1]), int(groups[2][1]), int(groups[3][1])]
	var h: Array = [0]
	h.append_array(vals)
	return h

## Best 5-of-7 evaluation.
func _eval_best(seven: Array) -> Array:
	var best: Array = []
	var n: int = seven.size()
	for a in range(n):
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					for e in range(d + 1, n):
						var ev: Array = _eval5([seven[a], seven[b], seven[c], seven[d], seven[e]])
						if best.is_empty() or _cmp(ev, best) > 0:
							best = ev
	return best

func _cmp(a: Array, b: Array) -> int:
	var n: int = min(a.size(), b.size())
	for i in range(n):
		if int(a[i]) > int(b[i]): return 1
		if int(a[i]) < int(b[i]): return -1
	if a.size() > b.size(): return 1
	if a.size() < b.size(): return -1
	return 0

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  DECK / DEAL                                                               ║
# ╚══════════════════════════════════════════════════════════════════════════╝
func _build_deck() -> void:
	_deck.clear()
	for s in SUITS:
		for r in RANKS:
			_deck.append({"rank": r, "element": s["name"]})
	_deck.shuffle()

func _draw_card() -> Dictionary:
	if _deck.is_empty():
		_build_deck()
	return _deck.pop_back()

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  GAME FLOW                                                                 ║
# ╚══════════════════════════════════════════════════════════════════════════╝
func _seat(name: String, is_human: bool) -> Dictionary:
	return {
		"name": name, "is_human": is_human, "stack": _buyin,
		"hole": [], "bet": 0, "committed": 0,
		"folded": false, "all_in": false, "acted": false, "busted": false,
		"say": "", "last_action": "",
	}

func _begin_game(opponents: Array) -> void:
	_players = [_seat("You", true)]
	for nm in opponents:
		_players.append(_seat(nm, false))
	_dealer = _players.size() - 1  # so the human takes the first small blind cycle
	_hands_played = 0
	_cashed_out = false
	_start_hand()

## Pay the human's remaining chips back to party Mora (1 chip = 1 Mora) and
## record the result. Idempotent — only the first call this game pays out.
func _cash_out() -> void:
	if _cashed_out:
		return
	_cashed_out = true
	var stack: int = int(_players[0].stack) if not _players.is_empty() else 0
	if stack > 0:
		_set_mora(_mora() + stack)
	var net: int = stack - _buyin
	var score: int = max(0, net)
	if score > 0 and not Global.ACTIVE_USER_NAME.is_empty():
		Global.Insert("Minigames_Results",
			["Player", "Minigame", "Score", "Date"],
			[Global.ACTIVE_USER_NAME, "Genshin Hold'em", score,
			 Time.get_datetime_string_from_system()])
	game_finished.emit(score)

func _active_seats() -> Array:
	var out: Array = []
	for i in range(_players.size()):
		if not _players[i].busted:
			out.append(i)
	return out

func _next_active(from: int) -> int:
	var n: int = _players.size()
	for step in range(1, n + 1):
		var i: int = (from + step) % n
		if not _players[i].busted:
			return i
	return from

func _start_hand() -> void:
	# Eliminate anyone who can't post.
	for p in _players:
		if p.stack <= 0:
			p.busted = true
	var live: Array = _active_seats()
	if _players[0].busted or live.size() < 2:
		_game_over()
		return

	_in_hand = true
	_hands_played += 1
	_build_deck()
	_community = []
	_current_bet = 0
	_min_raise = BIG_BLIND
	for p in _players:
		p.hole = []
		p.bet = 0
		p.committed = 0
		p.folded = p.busted
		p.all_in = false
		p.acted = false
		p.last_action = ""

	# Move the button to the next live seat.
	_dealer = _next_active(_dealer)

	# Blinds.
	var sb_i: int = _next_active(_dealer)
	var bb_i: int = _next_active(sb_i)
	_post_blind(sb_i, SMALL_BLIND)
	_post_blind(bb_i, BIG_BLIND)
	_current_bet = BIG_BLIND
	_min_raise = BIG_BLIND

	# Deal hole cards.
	for p in _players:
		if not p.busted:
			p.hole = [_draw_card(), _draw_card()]
	_status_label.text = "Hand %d — blinds %d/%d" % [_hands_played, SMALL_BLIND, BIG_BLIND]
	_render()
	await _pause(0.5)

	# Preflop: action starts left of the big blind.
	var done: bool = await _betting_round(_next_active(bb_i))
	if not done:
		await _deal_street(3, "the flop")
		if not await _betting_round(_next_active(_dealer)):
			if not await _deal_street(1, "the turn"):
				pass
			if not await _betting_round(_next_active(_dealer)):
				await _deal_street(1, "the river")
				await _betting_round(_next_active(_dealer))
	await _showdown()
	_finish_hand()

func _post_blind(i: int, amount: int) -> void:
	var p: Dictionary = _players[i]
	var put: int = min(amount, int(p.stack))
	p.stack -= put
	p.bet += put
	p.committed += put
	if p.stack == 0:
		p.all_in = true

## Deal `count` community cards. Returns true if the hand is already decided
## (everyone but one folded) so callers can skip remaining betting.
func _deal_street(count: int, label: String) -> bool:
	if _hand_decided():
		return true
	for i in range(count):
		_community.append(_draw_card())
	for p in _players:
		p.acted = false
		p.bet = 0
	_current_bet = 0
	_min_raise = BIG_BLIND
	_status_label.text = "Dealing %s..." % label
	_sfx_deal()
	_render()
	await _pause(0.7)
	return false

func _hand_decided() -> bool:
	var alive: int = 0
	for p in _players:
		if not p.folded and not p.busted:
			alive += 1
	return alive <= 1

## Runs one betting round. Returns true if the hand ended (all but one folded).
func _betting_round(start: int) -> bool:
	var idx: int = start
	while true:
		if _hand_decided():
			return true
		if _round_settled():
			return false
		var p: Dictionary = _players[idx]
		if not p.folded and not p.busted and not p.all_in and (not p.acted or int(p.bet) < _current_bet):
			await _take_action(idx)
		idx = _next_active(idx)
	return false  # unreachable; satisfies static return-path analysis

func _round_settled() -> bool:
	for p in _players:
		if p.folded or p.busted or p.all_in:
			continue
		if not p.acted or int(p.bet) < _current_bet:
			return false
	return true

func _take_action(idx: int) -> void:
	var p: Dictionary = _players[idx]
	var res: Dictionary
	if p.is_human:
		res = await _human_turn(idx)
	else:
		_status_label.text = "%s is thinking..." % p.name
		_render()
		await _pause(randf_range(0.5, 1.1))
		res = _ai_choose(idx)
	_apply_action(idx, res)
	_render()
	await _pause(0.25)

func _apply_action(idx: int, res: Dictionary) -> void:
	var p: Dictionary = _players[idx]
	var action: String = str(res.get("action", "fold"))
	var call_amt: int = _current_bet - int(p.bet)
	match action:
		"fold":
			p.folded = true
			p.last_action = "Fold"
			_sfx_fold()
		"check":
			p.last_action = "Check"
		"call":
			var pay: int = min(call_amt, int(p.stack))
			p.stack -= pay
			p.bet += pay
			p.committed += pay
			if p.stack == 0:
				p.all_in = true
				p.last_action = "All-in"
			else:
				p.last_action = "Call %d" % int(p.bet)
			_sfx_chip()
		"raise", "allin":
			var target: int = int(res.get("to", _current_bet + _min_raise))
			if action == "allin":
				target = int(p.bet) + int(p.stack)
			target = clamp(target, _current_bet + 1, int(p.bet) + int(p.stack))
			var add: int = target - int(p.bet)
			p.stack -= add
			p.committed += add
			var raise_size: int = target - _current_bet
			if raise_size >= _min_raise:
				_min_raise = raise_size
			p.bet = target
			_current_bet = target
			if p.stack == 0:
				p.all_in = true
				p.last_action = "All-in %d" % target
			else:
				p.last_action = "Raise to %d" % target
			# A raise reopens the action for everyone else.
			for q in _players:
				if q != p and not q.folded and not q.busted and not q.all_in:
					q.acted = false
			_sfx_chip()
			if not p.is_human and randf() < 0.5:
				_say(idx, _line(p.name, "raise"))
	p.acted = true

# ── Human input ───────────────────────────────────────────────────────────────
func _human_turn(idx: int) -> Dictionary:
	var p: Dictionary = _players[idx]
	var call_amt: int = _current_bet - int(p.bet)
	_status_label.text = "Your move."
	_action_bar.visible = true
	_fold_btn.disabled = false
	if call_amt <= 0:
		_call_btn.text = "Check"
	else:
		_call_btn.text = "Call %d" % min(call_amt, int(p.stack))
	_call_btn.disabled = false
	# Raise slider: from a legal min-raise up to all-in.
	var min_to: int = _current_bet + _min_raise
	var max_to: int = int(p.bet) + int(p.stack)
	if min_to >= max_to:
		# Not enough to make a full raise — only all-in remains as an aggressive move.
		_raise_btn.disabled = true
		_raise_slider.editable = false
		_raise_slider.min_value = max_to
		_raise_slider.max_value = max_to
		_raise_slider.value = max_to
	else:
		_raise_btn.disabled = false
		_raise_slider.editable = true
		_raise_slider.min_value = min_to
		_raise_slider.max_value = max_to
		_raise_slider.value = min_to
	_allin_btn.disabled = int(p.stack) <= 0
	_update_raise_label()
	_render()

	await _human_done
	_action_bar.visible = false
	return _human_result

func _on_fold() -> void:
	_human_result = {"action": "fold"}
	emit_signal("_human_done")

func _on_call() -> void:
	var p: Dictionary = _players[0]
	_human_result = {"action": ("check" if _current_bet - int(p.bet) <= 0 else "call")}
	emit_signal("_human_done")

func _on_raise() -> void:
	_human_result = {"action": "raise", "to": int(_raise_slider.value)}
	emit_signal("_human_done")

func _on_allin() -> void:
	_human_result = {"action": "allin"}
	emit_signal("_human_done")

func _update_raise_label() -> void:
	if _raise_amt_label:
		_raise_amt_label.text = "Raise to %d" % int(_raise_slider.value)

# ── AI ────────────────────────────────────────────────────────────────────────
## Every AI is a strong, numbers-aware player: it estimates the actual probability
## its hand is best (Monte-Carlo equity vs the live opponents), compares against
## true pot odds, value-bets/raises strong holdings, folds dominated hands fast,
## and bluffs only when fold-equity makes it +EV. Persona only shifts the LEAN:
##   tight  → demands more equity to continue (plays fewer hands)
##   aggr   → prefers raising over calling, sizes bigger, bluffs more
func _ai_choose(idx: int) -> Dictionary:
	var p: Dictionary = _players[idx]
	var persona: Dictionary = _persona(p.name)
	var aggr: float = persona.get("aggr", 0.55)
	var bluff_rate: float = persona.get("bluff", 0.40)
	var tight: float = persona.get("tight", 0.50)

	var opp: int = _count_opponents(idx)
	if opp <= 0:
		return {"action": "check"}
	var iters: int = clamp(int(720.0 / float(opp + 1)), 70, 200)
	var eq: float = _equity(p.hole, _community, opp, iters)   # P(win at showdown)

	var call_amt: int = _current_bet - int(p.bet)
	var pot: int = _pot_total()
	var street: int = _community.size()   # 0 pre, 3 flop, 4 turn, 5 river

	# Fold equity is high heads-up, ~nil multiway → bluffs only when they fold.
	var fold_equity: float = clamp(1.0 - 0.42 * opp, 0.0, 1.0)
	var want_bluff: bool = street >= 3 and eq < 0.50 and randf() < bluff_rate * fold_equity

	if call_amt <= 0:
		# Nothing to call: value-bet good equity, occasionally bluff, else check.
		var value_thresh: float = clamp(0.55 + 0.04 * opp - aggr * 0.12, 0.40, 0.85)
		if eq >= value_thresh:
			var f: float = lerp(0.5, 1.0, clamp((eq - 0.5) / 0.5, 0.0, 1.0)) * lerp(0.8, 1.15, aggr)
			return {"action": "raise", "to": _raise_to_frac(idx, f)}
		if want_bluff:
			return {"action": "raise", "to": _raise_to_frac(idx, lerp(0.45, 0.7, aggr))}
		return {"action": "check"}

	# Facing a bet — compare equity to genuine pot odds, with a tightness margin.
	var pot_odds: float = float(call_amt) / float(pot + call_amt)
	var need: float = pot_odds * (1.0 + tight * 0.30)
	var raise_thresh: float = clamp(0.62 + 0.03 * opp - aggr * 0.10, 0.50, 0.85)

	# Value raise with strong equity (aggressive players do it more, bigger).
	if eq >= raise_thresh and randf() < (0.45 + aggr * 0.50):
		var fr: float = lerp(0.6, 1.0, clamp((eq - 0.5) / 0.4, 0.0, 1.0)) * lerp(0.85, 1.15, aggr)
		return {"action": "raise", "to": _raise_to_frac(idx, fr)}
	# Semi-bluff / bluff raise when there's fold equity and it isn't too pricey.
	if want_bluff and call_amt < int(pot * 0.6) and randf() < 0.5:
		return {"action": "raise", "to": _raise_to_frac(idx, 0.6)}
	# Call when the price is right.
	if eq >= need:
		if call_amt >= int(p.stack):
			# Calling commits the stack — need real equity to stack off.
			return {"action": "call"} if eq >= max(0.45, pot_odds * 1.05) else {"action": "fold"}
		return {"action": "call"}
	# Not getting the price → fold fast. Loose players occasionally float cheaply.
	if call_amt <= BIG_BLIND and tight < 0.45 and eq > pot_odds * 0.85 and randf() < 0.35:
		return {"action": "call"}
	return {"action": "fold"}

## Monte-Carlo estimate of P(this hand wins at showdown) vs `opp` random hands.
func _equity(hole: Array, community: Array, opp: int, iters: int) -> float:
	if opp <= 0:
		return 1.0
	var used: Dictionary = {}
	for c in hole:
		used[_card_key(c)] = true
	for c in community:
		used[_card_key(c)] = true
	var deck: Array = []
	for s in SUITS:
		for r in RANKS:
			var card: Dictionary = {"rank": r, "element": str(s["name"])}
			if not used.has(_card_key(card)):
				deck.append(card)
	var need_board: int = 5 - community.size()
	var score: float = 0.0
	for it in range(iters):
		deck.shuffle()
		var di: int = 0
		var board: Array = community.duplicate()
		for b in range(need_board):
			board.append(deck[di]); di += 1
		var my: Array = _eval_best(hole + board)
		var lost: bool = false
		var tied: int = 0
		for o in range(opp):
			var oe: Array = _eval_best([deck[di], deck[di + 1]] + board)
			di += 2
			var cm: int = _cmp(my, oe)
			if cm < 0:
				lost = true
				break
			elif cm == 0:
				tied += 1
		if lost:
			continue
		score += 1.0 if tied == 0 else 1.0 / float(tied + 1)
	return score / float(iters)

func _card_key(c: Dictionary) -> String:
	return "%s-%s" % [str(c.get("rank", "")), str(c.get("element", ""))]

func _count_opponents(idx: int) -> int:
	var n: int = 0
	for i in range(_players.size()):
		if i == idx:
			continue
		if not _players[i].folded and not _players[i].busted:
			n += 1
	return n

## Raise/bet TO a target ≈ `frac` of the pot on top of the current bet, clamped
## to a legal min-raise and the player's stack.
func _raise_to_frac(idx: int, frac: float) -> int:
	var p: Dictionary = _players[idx]
	var base: int = max(_pot_total(), BIG_BLIND)
	var bump: int = max(_min_raise, int(round(base * frac)))
	var target: int = _current_bet + bump
	return clamp(target, _current_bet + _min_raise, int(p.bet) + int(p.stack))

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  SHOWDOWN + SIDE POTS                                                      ║
# ╚══════════════════════════════════════════════════════════════════════════╝
func _pot_total() -> int:
	var t: int = 0
	for p in _players:
		t += int(p.committed)
	return t

func _showdown() -> void:
	# Win by everyone folding.
	var contenders: Array = []
	for i in range(_players.size()):
		if not _players[i].folded and not _players[i].busted:
			contenders.append(i)

	if contenders.size() == 1:
		var w: int = contenders[0]
		var amt: int = _pot_total()
		_players[w].stack += amt
		if not _players[w].is_human:
			_say(w, _line(_players[w].name, "win"))
		_status_label.text = "%s wins %d (everyone folded)" % [_players[w].name, amt]
		_render()
		await _pause(1.4)
		return

	# Reveal and evaluate.
	var evals: Dictionary = {}   # seat → score array
	for i in contenders:
		var seven: Array = []
		seven.append_array(_players[i].hole)
		seven.append_array(_community)
		evals[i] = _eval_best(seven)
	_render(true)  # reveal hole cards

	# Build side pots from per-player committed amounts.
	var winners_all: Dictionary = {}   # seat → total won
	var levels: Array = []
	for p in _players:
		var c: int = int(p.committed)
		if c > 0 and not levels.has(c):
			levels.append(c)
	levels.sort()
	var prev: int = 0
	for lvl in levels:
		var pot_amt: int = 0
		for p in _players:
			pot_amt += clamp(int(p.committed) - prev, 0, lvl - prev)
		# Eligible = contenders who committed at least this level.
		var elig: Array = []
		for i in contenders:
			if int(_players[i].committed) >= lvl:
				elig.append(i)
		if not elig.is_empty() and pot_amt > 0:
			var best: Array = []
			var winners: Array = []
			for i in elig:
				var ev: Array = evals[i]
				if best.is_empty() or _cmp(ev, best) > 0:
					best = ev
					winners = [i]
				elif _cmp(ev, best) == 0:
					winners.append(i)
			var share: int = int(pot_amt / float(winners.size()))
			var rem: int = pot_amt - share * winners.size()
			for wi in winners:
				var got: int = share + (1 if rem > 0 else 0)
				if rem > 0: rem -= 1
				_players[wi].stack += got
				winners_all[wi] = int(winners_all.get(wi, 0)) + got
		prev = lvl

	# Flavour: winners gloat, notable losers grumble.
	var best_seat: int = contenders[0]
	for i in contenders:
		if _cmp(evals[i], evals[best_seat]) > 0:
			best_seat = i
	var summary: Array = []
	for wi in winners_all:
		var nm: String = str(_players[wi].name)
		summary.append("%s wins %d (%s)" % [nm, int(winners_all[wi]), HAND_NAMES[int(evals[wi][0])]])
		if not _players[wi].is_human:
			_say(wi, _line(nm, "win"))
	for i in contenders:
		if not winners_all.has(i) and not _players[i].is_human and randf() < 0.6:
			_say(i, _line(str(_players[i].name), "lose"))
	_status_label.text = "  ·  ".join(summary)
	_sfx_win()
	_render(true)
	await _pause(2.4)

func _finish_hand() -> void:
	_in_hand = false
	for p in _players:
		if p.stack <= 0:
			p.busted = true
	if _players[0].busted or _active_seats().size() < 2:
		_game_over()
		return
	_render()
	await _pause(0.6)
	_start_hand()

func _game_over() -> void:
	_in_hand = false
	var net: int = int(_players[0].stack) - _buyin
	_cash_out()  # return remaining chips to Mora + record (idempotent)

	var v := _make_overlay()
	var title := Label.new()
	title.text = "CASHED OUT" if not _players[0].busted else "BUSTED OUT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", GREEN if net >= 0 else RED)
	v.add_child(title)
	var res := Label.new()
	res.text = "Net: %s%d Mora over %d hands" % ["+" if net >= 0 else "", net, _hands_played]
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res.add_theme_font_size_override("font_size", 40)
	res.add_theme_color_override("font_color", ACCENT)
	v.add_child(res)
	var again := Button.new()
	again.text = "Buy Back In"
	again.custom_minimum_size = Vector2(320, 64)
	again.add_theme_font_size_override("font_size", 34)
	again.pressed.connect(func():
		if _overlay: _overlay.queue_free()
		_overlay = null
		_show_intro())
	v.add_child(again)
	var leave := Button.new()
	leave.text = "Leave the Parlor"
	leave.custom_minimum_size = Vector2(280, 54)
	leave.pressed.connect(_on_close)
	v.add_child(leave)

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  UI                                                                        ║
# ╚══════════════════════════════════════════════════════════════════════════╝
func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	for m in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + m, 0)
	add_child(root)
	var pad = MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 40)
	add_child(pad)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)

	# Title row + leave
	var top = HBoxContainer.new()
	var title = Label.new()
	title.text = "Genshin Hold'em"
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var leave = Button.new()
	leave.text = "Leave Table"
	leave.pressed.connect(_on_close)
	top.add_child(leave)
	col.add_child(top)

	# Opponents
	_seats_box = HBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 14)
	_seats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_seats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_seats_box)

	# Felt centre: community + pot
	var felt = PanelContainer.new()
	var fsb = StyleBoxFlat.new()
	fsb.bg_color = FELT
	fsb.set_corner_radius_all(180)
	fsb.border_color = ACCENT.darkened(0.3)
	fsb.set_border_width_all(3)
	fsb.set_content_margin_all(24)
	felt.add_theme_stylebox_override("panel", fsb)
	felt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(felt)
	var feltv = VBoxContainer.new()
	feltv.alignment = BoxContainer.ALIGNMENT_CENTER
	feltv.add_theme_constant_override("separation", 16)
	felt.add_child(feltv)
	_pot_label = Label.new()
	_pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pot_label.add_theme_font_size_override("font_size", 40)
	_pot_label.add_theme_color_override("font_color", ACCENT)
	feltv.add_child(_pot_label)
	_community_box = HBoxContainer.new()
	_community_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_community_box.add_theme_constant_override("separation", 12)
	feltv.add_child(_community_box)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 28)
	_status_label.add_theme_color_override("font_color", TEXT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(1600, 0)
	feltv.add_child(_status_label)

	# Human seat
	var me = HBoxContainer.new()
	me.add_theme_constant_override("separation", 20)
	me.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(me)
	_player_cards_box = HBoxContainer.new()
	_player_cards_box.add_theme_constant_override("separation", 10)
	me.add_child(_player_cards_box)
	_player_stack_label = Label.new()
	_player_stack_label.add_theme_font_size_override("font_size", 34)
	_player_stack_label.add_theme_color_override("font_color", TEXT)
	me.add_child(_player_stack_label)

	# Action bar
	_action_bar = HBoxContainer.new()
	_action_bar.add_theme_constant_override("separation", 14)
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.visible = false
	col.add_child(_action_bar)
	_fold_btn = _mk_action("Fold", _on_fold)
	_action_bar.add_child(_fold_btn)
	_call_btn = _mk_action("Call", _on_call)
	_action_bar.add_child(_call_btn)
	var rv = VBoxContainer.new()
	_raise_amt_label = Label.new()
	_raise_amt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raise_amt_label.add_theme_font_size_override("font_size", 24)
	_raise_amt_label.add_theme_color_override("font_color", ACCENT)
	rv.add_child(_raise_amt_label)
	_raise_slider = HSlider.new()
	_raise_slider.custom_minimum_size = Vector2(360, 0)
	_raise_slider.step = 5
	_raise_slider.value_changed.connect(func(_v): _update_raise_label())
	rv.add_child(_raise_slider)
	_action_bar.add_child(rv)
	_raise_btn = _mk_action("Raise", _on_raise)
	_action_bar.add_child(_raise_btn)
	_allin_btn = _mk_action("All-In", _on_allin)
	_action_bar.add_child(_allin_btn)

func _mk_action(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 60)
	b.add_theme_font_size_override("font_size", 32)
	b.pressed.connect(cb)
	return b

func _render(reveal: bool = false) -> void:
	if _pot_label == null:
		return
	_pot_label.text = "Pot: %d" % _pot_total()
	if _player_stack_label:
		var me: Dictionary = _players[0] if not _players.is_empty() else {}
		_player_stack_label.text = "You — %d chips" % int(me.get("stack", 0))

	# community
	for c in _community_box.get_children():
		c.queue_free()
	for i in range(5):
		if i < _community.size():
			_community_box.add_child(_card_node(_community[i], 96, 134, false))
		else:
			_community_box.add_child(_card_node({}, 96, 134, true, true))

	# opponents
	for c in _seats_box.get_children():
		c.queue_free()
	for i in range(1, _players.size()):
		_seats_box.add_child(_seat_panel(i, reveal))

	# human cards
	for c in _player_cards_box.get_children():
		c.queue_free()
	if not _players.is_empty():
		for card in _players[0].hole:
			_player_cards_box.add_child(_card_node(card, 110, 154, false))

func _seat_panel(i: int, reveal: bool) -> Control:
	var p: Dictionary = _players[i]
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var sb = StyleBoxFlat.new()
	var is_turn: bool = _in_hand and not p.folded and not p.busted
	sb.bg_color = SEAT_BG
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT if (i == _dealer) else BORDER
	if p.folded or p.busted:
		panel.modulate = Color(1, 1, 1, 0.45)
	panel.add_theme_stylebox_override("panel", sb)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var head = HBoxContainer.new()
	var nm = Label.new()
	nm.text = str(p.name)
	nm.add_theme_font_size_override("font_size", 28)
	nm.add_theme_color_override("font_color", TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	if i == _dealer:
		var d = Label.new()
		d.text = "Ⓓ"
		d.add_theme_font_size_override("font_size", 28)
		d.add_theme_color_override("font_color", ACCENT)
		head.add_child(d)
	v.add_child(head)

	var stack = Label.new()
	stack.text = "Busted" if p.busted else "%d chips" % int(p.stack)
	stack.add_theme_font_size_override("font_size", 24)
	stack.add_theme_color_override("font_color", TEXT_MUT)
	v.add_child(stack)

	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	if not p.busted:
		var show: bool = reveal and not p.folded
		for card in p.hole:
			cards.add_child(_card_node(card, 62, 86, not show, true))
	v.add_child(cards)

	var act = Label.new()
	var act_txt: String = str(p.last_action)
	if int(p.bet) > 0:
		act_txt = ("%s · bet %d" % [act_txt, int(p.bet)]) if act_txt != "" else "bet %d" % int(p.bet)
	act.text = act_txt
	act.add_theme_font_size_override("font_size", 22)
	act.add_theme_color_override("font_color", GREEN if int(p.bet) > 0 else TEXT_MUT)
	v.add_child(act)

	if str(p.say) != "":
		var bubble = Label.new()
		bubble.text = "“%s”" % str(p.say)
		bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble.add_theme_font_size_override("font_size", 21)
		bubble.add_theme_color_override("font_color", ACCENT.lightened(0.1))
		v.add_child(bubble)
	return panel

func _card_node(card: Dictionary, w: float, h: float, hidden: bool, small: bool = false) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(4)
	if hidden or card.is_empty():
		sb.bg_color = Color(0.08, 0.14, 0.20) if hidden and not card.is_empty() else Color(0.06, 0.09, 0.10)
		sb.border_color = ACCENT.darkened(0.35) if hidden else BORDER
		panel.add_theme_stylebox_override("panel", sb)
		if hidden and not card.is_empty():
			var cc = CenterContainer.new()
			var mk = Label.new()
			mk.text = "❖"
			mk.add_theme_font_size_override("font_size", h * 0.4)
			mk.add_theme_color_override("font_color", ACCENT.darkened(0.1))
			cc.add_child(mk)
			panel.add_child(cc)
		return panel

	sb.bg_color = Color(0.97, 0.96, 0.92)
	sb.border_color = Color(0.7, 0.72, 0.75)
	panel.add_theme_stylebox_override("panel", sb)
	var rank: String = str(card.get("rank", "?"))
	var suit: Dictionary = _suit_def(str(card.get("element", "")))
	var col: Color = suit.get("color", Color.BLACK)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	var top = Label.new()
	top.text = rank
	top.add_theme_font_size_override("font_size", (h * 0.20))
	top.add_theme_color_override("font_color", col)
	vb.add_child(top)
	var img = TextureRect.new()
	var path: String = str(FACES[rank]) if FACES.has(rank) else str(suit.get("icon", ""))
	if ResourceLoader.exists(path):
		img.texture = load(path)
	img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(img)
	if not small:
		var bot = Label.new()
		bot.text = rank
		bot.add_theme_font_size_override("font_size", (h * 0.20))
		bot.add_theme_color_override("font_color", col)
		bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vb.add_child(bot)
	panel.add_child(vb)
	return panel

func _suit_def(elem: String) -> Dictionary:
	for s in SUITS:
		if s["name"] == elem:
			return s
	return SUITS[0]

# ── Intro / overlay ───────────────────────────────────────────────────────────
func _show_intro() -> void:
	var v := _make_overlay()
	var title := Label.new()
	title.text = "Genshin Hold'em"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", ACCENT)
	v.add_child(title)

	var opps := _gather_opponents()
	var who := Label.new()
	who.text = "Tonight's table: " + ", ".join(opps)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.custom_minimum_size = Vector2(1200, 0)
	who.add_theme_font_size_override("font_size", 32)
	who.add_theme_color_override("font_color", TEXT)
	v.add_child(who)

	var rules := Label.new()
	rules.text = "No-limit Texas Hold'em. Blinds %d/%d. Last one with chips wins.\nPick your buy-in (deducted from party Mora; cash out what's left)." % [SMALL_BLIND, BIG_BLIND]
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.add_theme_font_size_override("font_size", 28)
	rules.add_theme_color_override("font_color", TEXT_MUT)
	v.add_child(rules)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for amt in BUYINS:
		var b := Button.new()
		b.text = "Buy in %d" % amt
		b.custom_minimum_size = Vector2(240, 64)
		b.add_theme_font_size_override("font_size", 30)
		b.disabled = _mora() < amt
		b.pressed.connect(func():
			_buyin = amt
			_set_mora(_mora() - amt)
			if _overlay: _overlay.queue_free()
			_overlay = null
			_begin_game(opps))
		row.add_child(b)

	var leave := Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(200, 50)
	leave.pressed.connect(_on_close)
	v.add_child(leave)

func _make_overlay() -> VBoxContainer:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 26)
	center.add_child(v)
	add_child(o)
	_overlay = o
	return v

func _gather_opponents() -> Array:
	var met: Array = []
	for c in Global.COMPANIONS.values():
		if typeof(c) == TYPE_DICTIONARY and bool(c.get("Met", false)):
			var nm: String = str(c.get("Name", ""))
			if nm != "":
				met.append(nm)
	met.shuffle()
	var want: int = randi_range(4, 5)
	if met.size() > want:
		met = met.slice(0, want)
	if met.is_empty():
		met = ["Venti", "Klee", "Zhongli", "Yae Miko"]
	return met

# ── Mora / utility ────────────────────────────────────────────────────────────
func _mora() -> int:
	return int(Global.Current_Party.get("Mora", 0))

func _set_mora(amount: int) -> void:
	var party_id: int = int(Global.Current_Party.get("id", 0))
	Global.Update_Records([{"table": "Party", "record_id": party_id, "field": "Mora", "value": amount}])

func _pause(seconds: float) -> void:
	await get_tree().create_timer(max(0.001, seconds * _time_scale)).timeout

func _say(idx: int, text: String) -> void:
	if text == "":
		return
	_players[idx].say = text
	var p: Dictionary = _players[idx]
	get_tree().create_timer(3.6).timeout.connect(func():
		if is_instance_valid(self) and _players.has(p):
			p.say = ""
			_render())

## Refund the buy-in and abandon the table (used when a battle turn force-closes
## the game): the player gets their cost back instead of cashing out chips.
func wager_refund() -> void:
	if not _cashed_out:
		_set_mora(_mora() + _buyin)
		_cashed_out = true

func _on_close() -> void:
	# Cash out whatever the human still has in their stack (covers leaving the
	# table at any point — they get back exactly their remaining chip count).
	_cash_out()
	var win = get_parent()
	while win and not (win is Window):
		win = win.get_parent()
	if win and win is Window:
		win.queue_free()

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  FLAVOUR / TAUNTS — covers every character; opponents draw from this.      ║
# ╚══════════════════════════════════════════════════════════════════════════╝
func _line(name: String, kind: String) -> String:
	var p: Dictionary = _persona(name)
	var arr: Array = p.get(kind, [])
	if arr.is_empty():
		arr = _GENERIC.get(kind, [""])
	return str(arr[randi() % arr.size()])

const _GENERIC := {
	"win": ["A good hand. I'll take it.", "Luck favored me this round."],
	"lose": ["Well played.", "Hmph. Next hand, then."],
	"raise": ["I'll raise.", "Let's make it interesting."],
}

# aggr/bluff/tight ∈ [0,1] — the LEAN, not the skill. Every AI plays the numbers
# (equity vs pot odds); these just bias how loose and how aggressive they run:
#   tight high → folds more / plays fewer hands;  aggr high → raises & bluffs more.
# Archetypes: Klee = loose-aggressive, Kaeya = tight-aggressive, Jean = tight-passive, etc.
const _PERSONAS := {
	"Ayaka": {"aggr": 0.45, "bluff": 0.18, "tight": 0.66,
		"win": ["A graceful victory. Thank you for the lovely game.", "Oh my, did I win? How fortunate."],
		"lose": ["Well played. I yield this hand with grace.", "A loss met with composure is no loss at all."],
		"raise": ["I shall raise, if you'll permit me."]},
	"Tartaglia": {"aggr": 0.90, "bluff": 0.55, "tight": 0.20,
		"win": ["Hahaha! Now THAT'S a thrill!", "Come on, give me a real challenge!"],
		"lose": ["Oho, not bad! Let's go again!", "Losing only makes the next win sweeter."],
		"raise": ["All in on the fun — raise!", "Let's turn up the heat!"]},
	"Thoma": {"aggr": 0.48, "bluff": 0.32, "tight": 0.44,
		"win": ["Ah, sorry! Beginner's luck, I swear.", "Hey, a win's a win — drinks on me!"],
		"lose": ["No worries, that was a good one!", "Ha, you got me. Well done."],
		"raise": ["I'll bump it up a little."]},
	"Jean": {"aggr": 0.30, "bluff": 0.12, "tight": 0.72,
		"win": ["Efficiency wins. As expected.", "Forgive me, duty compels me to take this pot."],
		"lose": ["Acceptable. I will recalibrate.", "A fair result. I concede."],
		"raise": ["I raise. Let us be decisive."]},
	"Keqing": {"aggr": 0.74, "bluff": 0.40, "tight": 0.56,
		"win": ["Hard work beats luck. Every time.", "Hmph. Calculated."],
		"lose": ["Tch. A miscalculation. It won't happen twice.", "...Noted. I'll adjust."],
		"raise": ["I'm raising — keep up."]},
	"Albedo": {"aggr": 0.58, "bluff": 0.42, "tight": 0.62,
		"win": ["Fascinating. The data favored me.", "An interesting result. Noted."],
		"lose": ["Curious. I'll refine my model.", "A useful anomaly."],
		"raise": ["Let's test a hypothesis — raise."]},
	"Sangonomiya Kokomi": {"aggr": 0.60, "bluff": 0.50, "tight": 0.55,
		"win": ["Strategy prevails, as planned.", "Forgive me — the tides were with me."],
		"lose": ["A tactical retreat. The war isn't over.", "I'll revise the battle plan."],
		"raise": ["My strategy says... raise."]},
	"Mona": {"aggr": 0.66, "bluff": 0.52, "tight": 0.46,
		"win": ["The stars foretold this. Naturally.", "Hah! Your Mora is written in my fate!"],
		"lose": ["Impossible! The constellations lied!", "A-a temporary misreading of the heavens!"],
		"raise": ["The astrolabe demands a raise!"]},
	"Cyno": {"aggr": 0.60, "bluff": 0.25, "tight": 0.68,
		"win": ["Justice is served. ...Get it?", "The General Mahamatra collects his dues."],
		"lose": ["A fair verdict. I accept it.", "Hm. The evidence was against me."],
		"raise": ["I raise. That's not a joke."]},
	"Xingqiu": {"aggr": 0.60, "bluff": 0.55, "tight": 0.45,
		"win": ["Just like chapter twelve — a flawless reversal!", "Heh, you didn't see that coming?"],
		"lose": ["A worthy plot twist. I'll allow it.", "Even heroes have setbacks."],
		"raise": ["Allow me a dramatic raise."]},
	"Nahida": {"aggr": 0.55, "bluff": 0.35, "tight": 0.62,
		"win": ["Knowledge is its reward — but I'll take the Mora too.", "I learned a lot from that hand. Thank you."],
		"lose": ["Hee hee, you taught me something new!", "That's alright. Every game is a lesson."],
		"raise": ["I think... I'll raise."]},
	"Yae Miko": {"aggr": 0.76, "bluff": 0.68, "tight": 0.46,
		"win": ["Oh? Did you really think you could win against me?", "How adorable. Now hand over the Mora."],
		"lose": ["My, my. You're more fun than I expected.", "Heh. Enjoy it while it lasts, little one."],
		"raise": ["Let's make this interesting~ raise."]},
	"Shenhe": {"aggr": 0.46, "bluff": 0.18, "tight": 0.66,
		"win": ["...I win. Was that wrong?", "Cloud Retainer taught me well."],
		"lose": ["I see. I have more to learn.", "...Understood."],
		"raise": ["Raise. ...Is that acceptable?"]},
	"Venti": {"aggr": 0.60, "bluff": 0.60, "tight": 0.35,
		"win": ["Hehe~ a toast to my victory! Got any wine?", "The wind always blows my way~"],
		"lose": ["Aw, easy come, easy go! Let's sing about it.", "Hehe, no hard feelings, friend!"],
		"raise": ["I'll raise — for the ballad!"]},
	"Xiangling": {"aggr": 0.60, "bluff": 0.40, "tight": 0.45,
		"win": ["Yes! This pot's the secret ingredient!", "Winner winner — let's cook!"],
		"lose": ["Aw, overcooked that one. Next round!", "Back to the kitchen, I guess!"],
		"raise": ["Turning up the heat — raise!"]},
	"Razor": {"aggr": 0.65, "bluff": 0.15, "tight": 0.40,
		"win": ["Razor... win. Lupical proud.", "Razor strong. Cards weak."],
		"lose": ["Razor... lose. Razor try again.", "Grr. Not done yet."],
		"raise": ["Razor push more."]},
	"Kazuha": {"aggr": 0.58, "bluff": 0.45, "tight": 0.56,
		"win": ["Leaves fall, fortune turns — to me, this time.", "A fitting verse to end the hand."],
		"lose": ["Even the maple lets go of its leaves. Well played.", "The wind gives, the wind takes."],
		"raise": ["The wind rises — I raise."]},
	"Raiden Shogun": {"aggr": 0.68, "bluff": 0.25, "tight": 0.70,
		"win": ["This is the eternity I envisioned.", "Inevitability. Nothing more."],
		"lose": ["...An unforeseen variable. Noted.", "A momentary impermanence."],
		"raise": ["I declare a raise. It is absolute."]},
	"Collei": {"aggr": 0.35, "bluff": 0.25, "tight": 0.62,
		"win": ["Oh! I-I actually won? Thank you!", "Master Tighnari would be proud."],
		"lose": ["Aw... that's okay. I'm getting better!", "I'll do better next time!"],
		"raise": ["Um... I'll raise. I think."]},
	"Nilou": {"aggr": 0.50, "bluff": 0.35, "tight": 0.50,
		"win": ["Like a final pose — perfect!", "The dance favored me tonight."],
		"lose": ["A misstep, but the dance goes on.", "Graceful in defeat, too."],
		"raise": ["Let me twirl this up — raise."]},
	"Wanderer": {"aggr": 0.82, "bluff": 0.65, "tight": 0.42,
		"win": ["Pathetic. Was that your best?", "Of course I won. Did you expect otherwise?"],
		"lose": ["Tch. Don't get used to it, insect.", "A fluke. Nothing more."],
		"raise": ["Raise. Grovel accordingly."]},
	"Zhongli": {"aggr": 0.62, "bluff": 0.30, "tight": 0.74,
		"win": ["A contract is a contract. The pot is mine.", "Order is restored, as it should be."],
		"lose": ["Hm. It seems I've misjudged. Again.", "...I may need to borrow some Mora."],
		"raise": ["I raise. We shall settle this properly."]},
	"Kaeya": {"aggr": 0.75, "bluff": 0.55, "tight": 0.68,
		"win": ["Ah, were you watching? I do put on a show.", "Losing to me is practically an honor."],
		"lose": ["Well played. I'll let you have this one... for now.", "Heh. You're sharper than you look."],
		"raise": ["Let's spice things up — raise."]},
	"Klee": {"aggr": 0.85, "bluff": 0.62, "tight": 0.18,
		"win": ["Boom! Klee wins! Cards go kaboom too!", "Yay yay yay! Did you see that?!"],
		"lose": ["Awww... Dodoco says next time for sure!", "No fair! Hmph!"],
		"raise": ["Kaboom! Klee raises BIG!"]},
	"Yoimiya": {"aggr": 0.70, "bluff": 0.45, "tight": 0.40,
		"win": ["Yesss! Fireworks for everyone!", "Hot streak, baby — festival night!"],
		"lose": ["Aw man! Okay, lighting the next one!", "Ha! You got spark, I'll give you that."],
		"raise": ["Let's go out with a bang — raise!"]},
	"Hu Tao": {"aggr": 0.80, "bluff": 0.70, "tight": 0.30,
		"win": ["Hee hee! Business is booming — for me!", "I offer discounts on your funeral, you know."],
		"lose": ["Tsk, you got lucky. The reaper remembers.", "Booo. That's coming out of your eulogy."],
		"raise": ["Raise! Consider it a pre-paid arrangement."]},
	"Yun Jin": {"aggr": 0.48, "bluff": 0.32, "tight": 0.58,
		"win": ["A flawless performance, if I say so.", "The crowd would cheer for that one."],
		"lose": ["A humble bow — the stage is yours this time.", "Even the finest opera has quiet acts."],
		"raise": ["Allow me a dramatic crescendo — raise."]},
	"Yaoyao": {"aggr": 0.28, "bluff": 0.18, "tight": 0.66,
		"win": ["Yay! Yuegui's so happy for me!", "I won? Here, you can have a radish!"],
		"lose": ["Aw... it's okay! Friends first!", "That's alright, let's keep playing!"],
		"raise": ["Um, I'll raise, p-please be nice!"]},
	"Lisa": {"aggr": 0.60, "bluff": 0.55, "tight": 0.52,
		"win": ["My, my~ careless of you, cutie.", "Knowledge is power, darling. And power wins."],
		"lose": ["Oh dear, how careless of me. Tee-hee.", "Mm, you've earned a little reward."],
		"raise": ["Shall we raise the stakes, hm~?"]},
	"Baizhu": {"aggr": 0.56, "bluff": 0.48, "tight": 0.62,
		"win": ["A favorable prognosis — for me.", "Patience is its own remedy."],
		"lose": ["Hm. A symptom I'll need to treat.", "An ailment of fortune, nothing more."],
		"raise": ["Let's increase the dosage — raise."]},
	"Ganyu": {"aggr": 0.35, "bluff": 0.20, "tight": 0.70,
		"win": ["Oh! Um, thank you. I'll log this.", "S-sorry, I believe that's mine."],
		"lose": ["That's alright, back to work I suppose.", "Oh well. No time to dwell on it."],
		"raise": ["I'll... raise. Please excuse me."]},
	"Yelan": {"aggr": 0.80, "bluff": 0.65, "tight": 0.50,
		"win": ["Information is everything, sweetie. I had yours.", "Did you really think you could read me?"],
		"lose": ["Heh. Color me impressed. Don't expect it twice.", "Well now. You're full of surprises."],
		"raise": ["Let's see how brave you are — raise."]},
	"Dehya": {"aggr": 0.72, "bluff": 0.35, "tight": 0.44,
		"win": ["Mercenary's rule — always collect.", "Hah! That's how the Flame-Mane does it."],
		"lose": ["Tch. Lucky shot. I'll get it back.", "Fine. Round to you."],
		"raise": ["I'm raising. Don't back down now."]},
	"Alhaitham": {"aggr": 0.70, "bluff": 0.35, "tight": 0.72,
		"win": ["Logic dictated this outcome.", "I'd explain how I won, but you wouldn't follow."],
		"lose": ["An acceptable margin of error.", "Statistically, it happens."],
		"raise": ["Rationally speaking — raise."]},
	"Diluc": {"aggr": 0.66, "bluff": 0.28, "tight": 0.70,
		"win": ["I don't gamble. I invest. And I collect.", "Hmph. Expected."],
		"lose": ["...Take it. The Mora means little to me.", "A trivial loss."],
		"raise": ["I'll raise. Don't waste my time."]},
	"Eula": {"aggr": 0.80, "bluff": 0.45, "tight": 0.46,
		"win": ["This is my vengeance — served cold!", "Did you doubt the Spindrift Knight?"],
		"lose": ["Tch! Added to the list. I never forget.", "Enjoy it. Vengeance is patient."],
		"raise": ["Prepare yourself — I raise!"]},
	"Ayato": {"aggr": 0.72, "bluff": 0.55, "tight": 0.66,
		"win": ["All according to plan, naturally.", "You played well. I simply played better."],
		"lose": ["Oh? An unexpected move. Delightful.", "Hm. I'll have to recalculate."],
		"raise": ["Let's negotiate higher — raise."]},
	"Tighnari": {"aggr": 0.62, "bluff": 0.30, "tight": 0.68,
		"win": ["Observation and patience. Textbook.", "The odds were never in your favor."],
		"lose": ["Hmph. Statistically improbable, but fine.", "Noted. I'll account for it."],
		"raise": ["I'll raise. Don't do anything reckless."]},
	"Xiao": {"aggr": 0.66, "bluff": 0.25, "tight": 0.56,
		"win": ["...It's done. Don't make a fuss.", "A Yaksha does not lose."],
		"lose": ["...Hmph. Inconsequential.", "...This changes nothing."],
		"raise": ["Raise. Be silent."]},
	"Bennett": {"aggr": 0.55, "bluff": 0.35, "tight": 0.40,
		"win": ["Whoa, I actually won?! My luck's finally turning around!", "Yes! See, persistence pays off!"],
		"lose": ["Aw man, classic Bennett luck... but hey, no big deal!", "Haha, that's okay! Adventurers gotta keep going!"],
		"raise": ["Alright, going for it — raise! Fingers crossed!"]},
}

func _persona(name: String) -> Dictionary:
	if _PERSONAS.has(name):
		return _PERSONAS[name]
	return {"aggr": 0.55, "bluff": 0.40, "tight": 0.50}

# ── SFX ───────────────────────────────────────────────────────────────────────
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
	var pl := AudioStreamPlayer.new()
	pl.bus = "SFX"
	pl.stream = stream
	pl.volume_db = volume_db
	add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)

func _sfx_deal() -> void: _play_tone(520.0, 0.05, -8.0)
func _sfx_chip() -> void: _play_tone(720.0, 0.06, -6.0)
func _sfx_fold() -> void: _play_tone(300.0, 0.10, -8.0)
func _sfx_win() -> void:
	_play_tone(660.0, 0.12, -3.0)
	await _pause(0.1)
	_play_tone(880.0, 0.16, -3.0)
