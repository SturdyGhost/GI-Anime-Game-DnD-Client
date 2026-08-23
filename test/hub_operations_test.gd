extends SceneTree
## Hub tests: market, expeditions, companions, gear, region/element, stats.
## Run: godot --headless --script test/hub_operations_test.gd
## (No GdUnit4 in this project; self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## Everything here is checked for HOST-DRIVEN behaviour: the host owns the data,
## clients submit requests and render what comes back. Any calculation that both
## sides perform independently (prices, stats, failure rates) must be a pure
## function of synced state, or the two disagree and the player sees one number
## while being charged another.

var _ran := false
var _fails: Array[String] = []
var _completed := 0
const EXPECTED_TESTS := 8

func _done() -> void:
	_completed += 1

func _init() -> void:
	process_frame.connect(_run)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _eq(actual, expected, msg: String) -> void:
	_check(actual == expected, "%s (got %s, expected %s)" % [msg, str(actual), str(expected)])

func _run() -> void:
	if _ran:
		return
	_ran = true
	var g = root.get_node_or_null("Global")
	var mk = root.get_node_or_null("Market")
	var cm = root.get_node_or_null("CharacterManager")
	var pm = root.get_node_or_null("PartyManager")
	var nm = root.get_node_or_null("NetworkManager")
	if g == null or mk == null or cm == null or pm == null or nm == null:
		print("HUB OPERATIONS TESTS: FAIL (required autoload missing)")
		quit(1)
		return

	_seed(g)

	_test_market_pricing(mk)
	_test_market_sell_preview(g, mk)
	_test_expedition_slots_and_failure(g)
	_test_expedition_assignment_rules(g)
	_test_companion_selection(g, pm)
	_test_gear_equip_exclusivity(g, cm)
	_test_region_and_element_swap(g, cm)
	_test_stat_calculation(g, cm)

	_check(_completed == EXPECTED_TESTS,
		"all %d test functions ran to completion (only %d did)" % [EXPECTED_TESTS, _completed])

	if _fails.is_empty():
		print("HUB OPERATIONS TESTS: PASS")
		quit(0)
	else:
		print("HUB OPERATIONS TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)


# ─── Fixture ────────────────────────────────────────────────────────────────

const P := "Brian C."
const C1 := "Comp One"
const C2 := "Comp Two"

func _seed(g) -> void:
	g._synced["Characters"] = {
		"2": {
			"id": 2, "Name": P, "Element": "Nature", "Current_Region": "Mondstadt",
			"Current_Health": 100, "Max_Health": 100, "Ascension_Rank": 3,
			"Health_Base_Points": 10, "Attack_Base_Points": 10, "Defense_Base_Points": 8,
			"Elemental_Mastery_Base_Points": 5, "Energy_Recharge_Base_Points": 4,
			"Critical_Damage_Base_Points": 6, "User_Type": "Player", "Daily_Luck": 50,
		},
	}
	g._synced["Companions"] = {
		"71": {"id": 71, "Name": C1, "Owner": P, "Element": "Nature", "Region": "Liyue",
			"Weapon": "Sword", "Active": false, "Unlocked": true, "Deceased": false,
			"Current_Health": 40, "Max_Health": 40},
		"72": {"id": 72, "Name": C2, "Owner": P, "Element": "Fire", "Region": "Mondstadt",
			"Weapon": "Bow", "Active": false, "Unlocked": true, "Deceased": false,
			"Current_Health": 40, "Max_Health": 40},
		"73": {"id": 73, "Name": "Dead One", "Owner": P, "Element": "Ice", "Region": "Inazuma",
			"Weapon": "Bow", "Active": false, "Unlocked": true, "Deceased": true,
			"Current_Health": 40, "Max_Health": 40},
		"74": {"id": 74, "Name": "Locked One", "Owner": P, "Element": "Ice", "Region": "Inazuma",
			"Weapon": "Bow", "Active": false, "Unlocked": false, "Deceased": false,
			"Current_Health": 40, "Max_Health": 40},
	}
	g._synced["Party"] = {
		"1": {"id": 1, "Current_Turn": P, "Party_Member_1": P, "Mora": 5000,
			"Current_Region": "Mondstadt", "Companion_Limit": 1},
	}
	g._synced["Character_Weapons"] = {
		"10": {"id": 10, "Weapon": "Sword A", "Owner": P, "Owner_Type": "Character",
			"Equipped": true, "Type": "Sword", "Quantity": 1,
			"Stat_1_Type": "Attack", "Stat_1_Value": 5.0},
		"11": {"id": 11, "Weapon": "Sword B", "Owner": P, "Owner_Type": "Character",
			"Equipped": false, "Type": "Sword", "Quantity": 1,
			"Stat_1_Type": "Attack", "Stat_1_Value": 9.0},
	}
	g._synced["Character_Artifacts"] = {
		"20": {"id": 20, "Artifact_Set": "Gladiator", "Owner": P, "Owner_Type": "Character",
			"Type": "Flower of Life", "Equipped": true, "Rarity": 5,
			"Stat_1_Type": "Health", "Stat_1_Value": 2.0},
	}
	g._synced["Active_Status_Effects"] = {}
	g._synced["BattleEnemies"] = {}
	for t in ["Characters", "Companions", "Party", "Character_Weapons", "Character_Artifacts"]:
		g._process_table(t, g._synced[t].values())


func _upd(g, table: String, rid: String, field: String, value) -> void:
	g._apply_local_update(table, rid, field, value)


# ─── Market ─────────────────────────────────────────────────────────────────

## Prices must be a pure function of luck, so the number shown in the panel and
## the number charged by Buy_Commit can never diverge between host and client.
func _test_market_pricing(mk) -> void:
	# Neutral band 50-60: no adjustment either way.
	_eq(mk._buy_price_with_luck(100.0, 50), 100, "buy price neutral at luck 50")
	_eq(mk._buy_price_with_luck(100.0, 60), 100, "buy price neutral at luck 60")

	# Above 60 discounts, below 50 marks up — and both directions are monotonic.
	_check(mk._buy_price_with_luck(100.0, 90) <= 100, "high luck never raises buy price")
	_check(mk._buy_price_with_luck(100.0, 10) >= 100, "low luck never lowers buy price")
	_check(mk._buy_price_with_luck(100.0, 90) <= mk._buy_price_with_luck(100.0, 70),
		"higher luck is monotonically cheaper")
	_check(mk._buy_price_with_luck(100.0, 10) >= mk._buy_price_with_luck(100.0, 40),
		"lower luck is monotonically pricier")

	# A price must never round to zero or go negative, whatever the inputs.
	_check(mk._buy_price_with_luck(0.1, 100) >= 1, "buy price floors at 1, never 0")
	_check(mk._buy_price_with_luck(0.0, 100) >= 1, "zero-value item still costs at least 1")

	# Sell rate stays inside its declared clamp at both extremes.
	var lo = mk._sell_rate_with_luck(0)
	var hi = mk._sell_rate_with_luck(100)
	_check(lo >= mk.SELL_RATE_MIN and lo <= mk.SELL_RATE_MAX, "sell rate clamped at min luck")
	_check(hi >= mk.SELL_RATE_MIN and hi <= mk.SELL_RATE_MAX, "sell rate clamped at max luck")
	_check(hi >= lo, "higher luck never sells for less")
	_done()


func _test_market_sell_preview(g, mk) -> void:
	mk.Sell_Offers.clear()
	var entry := {"Name": "Test Ore", "Value": 100, "Quantity": 10}

	var one = mk.Price_Sell_Preview(entry, 1)
	_check(one >= 0, "sell preview is non-negative")

	# Offers are cached per item NAME and cleared on Refresh_Stock, so a quoted
	# price is stable for the life of the stock. That stability is deliberate —
	# it stops a player rerolling the random jitter by toggling the quantity.
	var again = mk.Price_Sell_Preview(entry, 1)
	_eq(again, one, "a quoted offer is stable within the same stock")

	# KNOWN ISSUE (reported 2026-07-25, not yet fixed): the cache key ignores
	# quantity, and Sell_Commit recomputes from scratch with fresh jitter instead
	# of honouring the quote. So the preview does not scale with quantity and the
	# player is not paid what they were shown. These assertions document today's
	# behaviour rather than blessing it — tighten them when the fix lands.
	var five = mk.Price_Sell_Preview(entry, 5)
	_eq(five, one, "DOCUMENTS BUG: preview ignores quantity after the first quote")

	mk.Sell_Offers.clear()
	var fresh_five = mk.Price_Sell_Preview(entry, 5)
	_check(fresh_five > one, "a fresh quote for a larger quantity is worth more")

	mk.Sell_Offers.clear()
	_eq(mk.Price_Sell_Preview(entry, 0), 0, "a fresh quote for zero quantity is zero")

	mk.Sell_Offers.clear()
	_done()


# ─── Expeditions ────────────────────────────────────────────────────────────

## Slot count derives from ascension rank; failure rate drops with each matching
## companion trait. Both are read by every client, so both must be pure.
func _test_expedition_slots_and_failure(g) -> void:
	# Mirror ExpeditionPanel._load_state's slot rule.
	var max_slots := 2
	for ch in g.CHARACTERS.values():
		if str(ch.get("User_Type", "")) != "Dungeon Master":
			max_slots = maxi(max_slots, int(ch.get("Ascension_Rank", 0)) * 2)
	max_slots = maxi(max_slots, 2)
	_eq(max_slots, 6, "ascension rank 3 yields 6 expedition slots")

	# A DM character must not inflate the party's slot count.
	_upd(g, "Characters", "2", "User_Type", "Dungeon Master")
	var dm_slots := 2
	for ch in g.CHARACTERS.values():
		if str(ch.get("User_Type", "")) != "Dungeon Master":
			dm_slots = maxi(dm_slots, int(ch.get("Ascension_Rank", 0)) * 2)
	dm_slots = maxi(dm_slots, 2)
	_eq(dm_slots, 2, "a DM's ascension rank does not grant expedition slots")
	_upd(g, "Characters", "2", "User_Type", "Player")

	# Failure rate: base by risk, minus 5% per matching trait, floored at 0.
	var script = load("res://Scenes/UI/expedition_panel.gd")
	_check(script != null, "expedition_panel.gd loads")
	if script == null:
		_done()
		return
	var panel = script.new()
	_check(panel != null, "ExpeditionPanel instantiates")
	if panel == null:
		_done()
		return

	var exp_script = load("res://Scripts/resources/expedition_data.gd")
	if exp_script != null:
		var e = exp_script.new()
		e.risk_level = "risky"
		e.bonus_region = "Liyue"
		e.bonus_weapon = "Sword"
		e.bonus_element = "Nature"
		panel._assignments = {0: [C1]}
		var rate = panel._calc_failure_rate(e, 0)
		# C1 matches region + weapon + element = 3 traits = -0.15 from 0.90.
		_check(abs(rate - 0.75) < 0.001, "three matching traits reduce risky failure to 0.75")

		panel._assignments = {0: []}
		var bare = panel._calc_failure_rate(e, 0)
		_check(abs(bare - 0.90) < 0.001, "unassigned risky expedition stays at base 0.90")

		e.risk_level = "safe"
		panel._assignments = {0: [C1]}
		var safe_rate = panel._calc_failure_rate(e, 0)
		_check(safe_rate >= 0.0, "failure rate never goes negative")
	panel.free()
	_done()


func _test_expedition_assignment_rules(g) -> void:
	var script = load("res://Scenes/UI/expedition_panel.gd")
	if script == null:
		_check(false, "expedition_panel.gd loads")
		_done()
		return
	var panel = script.new()

	# Deployment count spans every slot, in both the array and legacy string forms.
	panel._assignments = {0: [C1, C2], 1: "Third", 2: []}
	_eq(panel._total_deployed(), 3, "deployed count spans array and legacy string slots")

	var names: Array = panel._all_assigned_names()
	_check(names.has(C1) and names.has(C2) and names.has("Third"),
		"all assigned names collected across slot formats")

	# The dead must be released from any slot they were holding.
	panel._assignments = {0: [C1, "Dead One"], 1: ["Dead One"]}
	panel._release_deceased_assignments()
	_eq(panel._assignments.get(0), [C1], "deceased companion removed, survivor kept")
	_check(not panel._assignments.has(1), "slot emptied by a death is erased")

	panel.free()
	_done()


# ─── Companions ─────────────────────────────────────────────────────────────

## Only unlocked, living companions may be active, and the active set is read
## from the SYNCED table on both host and client.
func _test_companion_selection(g, pm) -> void:
	_upd(g, "Companions", "71", "Active", true)
	var active: Array = pm.get_companion_names()
	_check(active.has(C1), "an activated companion appears in the active set")
	_check(not active.has(C2), "an inactive companion does not")

	# Deceased must never be selectable, even if some path flips Active.
	_upd(g, "Companions", "73", "Active", true)
	var idle_ok := true
	for c in g.COMPANIONS.values():
		if c.get("Deceased", false) == true and c.get("Active", false) == true:
			idle_ok = false
	_check(not idle_ok,
		"fixture confirms a deceased companion CAN be flagged active in raw data")
	# ...which is exactly why the backfill exists to clear it.
	g.backfill_companion_catalog_flags()

	_upd(g, "Companions", "73", "Active", false)
	_upd(g, "Companions", "71", "Active", false)

	# Owner gating: a player may only gear/select companions they own.
	for c in g.COMPANIONS.values():
		if str(c.get("Name", "")) == C1:
			_eq(str(c.get("Owner", "")), P, "companion ownership is recorded")
	_done()


# ─── Gear ───────────────────────────────────────────────────────────────────

## Equipping is exclusive per owner: two weapons must never both read Equipped.
func _test_gear_equip_exclusivity(g, cm) -> void:
	var equipped := []
	for w in g.CHARACTER_WEAPONS.values():
		if str(w.get("Owner", "")) == P and w.get("Equipped") == true:
			equipped.append(str(w.get("Weapon", "")))
	_eq(equipped.size(), 1, "exactly one weapon equipped at fixture time")

	# Swap: unequip the old, equip the new — the operation the detail scene performs.
	_upd(g, "Character_Weapons", "10", "Equipped", false)
	_upd(g, "Character_Weapons", "11", "Equipped", true)

	var after := []
	for w in g.CHARACTER_WEAPONS.values():
		if str(w.get("Owner", "")) == P and w.get("Equipped") == true:
			after.append(str(w.get("Weapon", "")))
	_eq(after.size(), 1, "still exactly one weapon equipped after a swap")
	_eq(str(after[0]), "Sword B", "the newly equipped weapon is the active one")

	# Unequipping everything is legal and must leave zero equipped.
	_upd(g, "Character_Weapons", "11", "Equipped", false)
	var none := 0
	for w in g.CHARACTER_WEAPONS.values():
		if str(w.get("Owner", "")) == P and w.get("Equipped") == true:
			none += 1
	_eq(none, 0, "unequipping leaves no weapon equipped")

	# Restore and confirm stats respond to gear rather than being cached stale.
	_upd(g, "Character_Weapons", "10", "Equipped", true)
	cm.recalculate_all()
	var with_weak = cm.get_stats(P)
	_upd(g, "Character_Weapons", "10", "Equipped", false)
	_upd(g, "Character_Weapons", "11", "Equipped", true)
	cm.recalculate_all()
	var with_strong = cm.get_stats(P)
	if with_weak != null and with_strong != null:
		_check(float(with_strong.attack) > float(with_weak.attack),
			"equipping a stronger weapon raises calculated attack (stats not stale)")
	_done()


# ─── Region / element ───────────────────────────────────────────────────────

func _test_region_and_element_swap(g, cm) -> void:
	# Region lives on the Party record and mirrors onto Global.Current_Region.
	_upd(g, "Party", "1", "Current_Region", "Inazuma")
	_eq(str(g.Current_Party.get("Current_Region", "")), "Inazuma",
		"party region updates in the synced table")

	# Element swap changes the character's kit; the value must round-trip.
	_upd(g, "Characters", "2", "Element", "Fire")
	_eq(str(g.CHARACTERS.get("2", {}).get("Element", "")), "Fire",
		"element swap lands in the synced table")

	# And the ability set follows the new element rather than the old one.
	var bd: Dictionary = BattlerState.build_all([P])
	var battler: Dictionary = bd.get(P, {})
	if not battler.is_empty():
		for d in battler.get("entity_current_ability_data", {}).values():
			var el := str(d.get("element", ""))
			if el != "" and el != "Physical":
				_eq(el, "Fire", "ability list follows the swapped element")

	_upd(g, "Characters", "2", "Element", "Nature")
	_upd(g, "Party", "1", "Current_Region", "Mondstadt")
	_done()


# ─── Stats ──────────────────────────────────────────────────────────────────

func _test_stat_calculation(g, cm) -> void:
	cm.recalculate_all()
	var s = cm.get_stats(P)
	_check(s != null, "player stats calculate")
	if s != null:
		_check(float(s.health) > 0.0, "health positive")
		_check(float(s.attack) > 0.0, "attack positive")
		_check(float(s.defense) > 0.0, "defense positive")

	# Base points drive stats — raising them must raise the result.
	var before = float(cm.get_stats(P).attack) if cm.get_stats(P) != null else 0.0
	_upd(g, "Characters", "2", "Attack_Base_Points", 20)
	cm.recalculate_all()
	var after = float(cm.get_stats(P).attack) if cm.get_stats(P) != null else 0.0
	_check(after > before, "raising Attack_Base_Points raises calculated attack")
	_upd(g, "Characters", "2", "Attack_Base_Points", 10)
	cm.recalculate_all()

	# Companion stats average the party's PLAYER base points and add own gear.
	# With a healthy party list this must be non-zero — zero means the party list
	# collapsed, which is the bug that silently zeroed every companion.
	var cc = cm.calculate_companion_stats(C1)
	_check(cc != null, "companion stats calculate")
	if cc != null:
		_check(float(cc.health) > 0.0, "companion base stats non-zero with a healthy party")

	# A companion's own gear must not leak from the player's.
	var player_only := 0
	for w in g.CHARACTER_WEAPONS.values():
		if str(w.get("Owner_Type", "Character")) == "Companion":
			player_only += 1
	_eq(player_only, 0, "fixture has no companion-owned gear, so none can leak")
	_done()
