extends Control

@onready var EnemyContainer = $EnemyGridContainer
@onready var TurnContainer = $TurnOrderHboxContainer
@onready var EnemyCard = preload("res://Scenes/enemy_card_compact.tscn")

var original_turn_order = []
var current_turn_order = []




func _ready() -> void:
	for entry in Global.BATTLEENEMIES.values():
		var scene = EnemyCard.instantiate()
		EnemyContainer.add_child(scene)
		scene.setup_from_name(entry.get("EnemyName")) 



# From PlayerHub (players choose order):
var players_order = [
	[1, "Brian C."],
	[2, "Brian F."],
	[3, "Dylan"],
	[1001, "Yae Miko"],
]

# From DMHub (after adding enemies):
var enemies_tail = [
	[11, "Ruin Guard 1"],
	[12, "Ruin Guard 2"],
	[13, "Ruin Guard 3"],
	[14, "Ruin Guard 4"],
]

# Start battle
#init_turn_orders(players_order, enemies_tail)

# On each turn:
#var actor = Global.pop_next_actor()
# ... actor acts ...
#reset_round_if_needed()

# On death:
#mark_dead([12, "Ruin Guard 2"])

# On revive later:
#revive([12, "Ruin Guard 2"])




func _on_minimize_button_pressed() -> void:
	self.visible = false
	get_parent().RestoreBattle.visible = true
	pass # Replace with function body.

# ---------- Identity helpers ----------
func _pair_key(p: Array) -> String:
	# p = [id, "Name"]; normalize to a stable key (case-insensitive name)
	return str(p[0]) + "|" + String(p[1]).strip_edges().to_lower()

func _same_pair(a: Array, b: Array) -> bool:
	return _pair_key(a) == _pair_key(b)

# ---------- Turn order state ----------
var ORIGINAL_TURN_ORDER: Array = []           # [[id,"Name"], ...]
var CURRENT_OVERALL_TURN_ORDER: Array = []    # [[id,"Name"], ...]
var CURRENT_REMAINING_TURN_ORDER: Array = []  # [[id,"Name"], ...]

# Bookkeeping for deterministic revive placement
var _ORIG_INDEX_BY_KEY: Dictionary = {}       # key -> index in ORIGINAL
var _ORIG_PAIR_BY_KEY: Dictionary = {}        # key -> canonical original pair
var _DEAD_KEYS: Dictionary = {}               # set-like {key:true}

# ---------- Initialize orders ----------
func init_turn_orders(player_pairs: Array, enemy_pairs: Array) -> void:
	ORIGINAL_TURN_ORDER = player_pairs.duplicate(true)
	for e in enemy_pairs:
		ORIGINAL_TURN_ORDER.append(e)

	# Build maps
	_ORIG_INDEX_BY_KEY.clear()
	_ORIG_PAIR_BY_KEY.clear()
	for i in ORIGINAL_TURN_ORDER.size():
		var key = _pair_key(ORIGINAL_TURN_ORDER[i])
		_ORIG_INDEX_BY_KEY[key] = i
		_ORIG_PAIR_BY_KEY[key] = ORIGINAL_TURN_ORDER[i]

	CURRENT_OVERALL_TURN_ORDER = ORIGINAL_TURN_ORDER.duplicate(true)
	CURRENT_REMAINING_TURN_ORDER = ORIGINAL_TURN_ORDER.duplicate(true)
	_DEAD_KEYS.clear()

# ---------- Progress a single actor ----------
func pop_next_actor() -> Array:
	if CURRENT_REMAINING_TURN_ORDER.is_empty():
		return []
	return CURRENT_REMAINING_TURN_ORDER.pop_front()

# ---------- End-of-round refill ----------
func reset_round_if_needed() -> void:
	if CURRENT_REMAINING_TURN_ORDER.is_empty():
		CURRENT_REMAINING_TURN_ORDER = CURRENT_OVERALL_TURN_ORDER.duplicate(true)

# ---------- Death handling ----------
func mark_dead(pair: Array) -> void:
	var key = _pair_key(pair)
	_DEAD_KEYS[key] = true
	_remove_by_key(CURRENT_OVERALL_TURN_ORDER, key)
	_remove_by_key(CURRENT_REMAINING_TURN_ORDER, key)

func _remove_by_key(arr: Array, key: String) -> void:
	for i in arr.size():
		if _pair_key(arr[i]) == key:
			arr.remove_at(i)
			return

# ---------- Revive handling ----------
func revive(pair: Array) -> void:
	var key = _pair_key(pair)
	# Use the original canonical pair in case the passed-in label formatting differs
	var orig_pair = _ORIG_PAIR_BY_KEY.get(key, [])
	if orig_pair.is_empty():
		# Not in ORIGINAL; nothing to do (or choose to append at end)
		return

	_DEAD_KEYS.erase(key)

	# Insert back into OVERALL if missing
	if not _contains_key(CURRENT_OVERALL_TURN_ORDER, key):
		var idx_overall = _insert_index_by_original(CURRENT_OVERALL_TURN_ORDER, key)
		CURRENT_OVERALL_TURN_ORDER.insert(idx_overall, orig_pair)

	# Insert into REMAINING only if their original slot is still upcoming this round
	if CURRENT_REMAINING_TURN_ORDER.is_empty():
		return  # will appear next round
	var my_orig = int(_ORIG_INDEX_BY_KEY.get(key, -1))
	if my_orig == -1:
		return

	var min_remaining_orig = _min_original_index(CURRENT_REMAINING_TURN_ORDER)
	if my_orig >= min_remaining_orig:
		if not _contains_key(CURRENT_REMAINING_TURN_ORDER, key):
			var idx_remaining = _insert_index_by_original(CURRENT_REMAINING_TURN_ORDER, key)
			CURRENT_REMAINING_TURN_ORDER.insert(idx_remaining, orig_pair)
	# else: their slot already passed this round—wait for the next refill

func _contains_key(arr: Array, key: String) -> bool:
	for p in arr:
		if _pair_key(p) == key:
			return true
	return false

func _insert_index_by_original(arr: Array, key: String) -> int:
	var my_orig = int(_ORIG_INDEX_BY_KEY.get(key, -1))
	var i = 0
	for p in arr:
		var oi = int(_ORIG_INDEX_BY_KEY.get(_pair_key(p), -1))
		if oi > my_orig:
			break
		i += 1
	return i

func _min_original_index(arr: Array) -> int:
	if arr.is_empty():
		return 999999
	var best = 999999
	for p in arr:
		var oi = int(_ORIG_INDEX_BY_KEY.get(_pair_key(p), 999999))
		if oi < best:
			best = oi
	return best
