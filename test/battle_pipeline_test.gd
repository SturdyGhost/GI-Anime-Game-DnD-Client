extends SceneTree
## End-to-end tests for the battle pipeline.
## Run: godot --headless --script test/battle_pipeline_test.gd
## (No GdUnit4 in this project; self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## This is the area that historically breaks most, so it gets the widest net:
## battler assembly, the ability list the dropdown renders from, effect display
## data, turn processing (damage, shields, KO, healing, elements), the active
## battler's stats, and the host/client dock-visibility rules.
##
## These run without a multiplayer peer, so `NetworkManager.is_host` is false by
## default — that is the CLIENT path. Tests that need host behaviour set the flag
## explicitly and restore it, which is also how we prove the host/client split is
## real rather than incidental.

var _ran := false
var _fails: Array[String] = []
## Number of test functions that ran to completion. An unresolved identifier
## aborts the enclosing function silently, so counting completions is the only
## way to distinguish "all assertions passed" from "no assertions ran".
var _completed := 0
const EXPECTED_TESTS := 16

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
	# Autoloads must be fetched from the tree: in a --script SceneTree run the
	# global class table is built before autoloads register, so bare identifiers
	# like GameDB fail to compile.
	var g = root.get_node_or_null("Global")
	var bm = root.get_node_or_null("BattleManager")
	var gdb = root.get_node_or_null("GameDB")
	var cm = root.get_node_or_null("CharacterManager")
	if g == null or bm == null or gdb == null or cm == null:
		print("BATTLE PIPELINE TESTS: FAIL (required autoload missing)")
		quit(1)
		return

	var TP = load("res://Scripts/battle/turn_processor.gd")
	if TP == null or not TP.has_method("process_turn"):
		print("BATTLE PIPELINE TESTS: FAIL (turn_processor.gd did not compile)")
		quit(1)
		return

	_seed_world(g)

	_test_battler_assembly(g)
	_test_ability_list_for_dropdown(g, gdb)
	_test_turn_order_and_advance(g, bm)
	_test_damage_resolution(g, bm, TP)
	_test_shield_absorption(g, bm, TP)
	_test_healing_and_overkill(g, bm, TP)
	_test_effects_display_payload(g, bm)
	_test_active_turn_stats(g, cm)
	_test_dock_visibility_rules(g)
	_test_snapshot_roundtrip(bm)
	_test_element_requires_damage(g, bm, TP)
	_test_element_applied_by_support(g, bm, TP)
	_test_element_vs_shield_absorption(g, bm, TP)
	_test_miss_does_not_consume_existing_element(g, bm, TP)
	_test_party_stats_table(g, bm)
	_test_party_stats_overlay(g, bm)

	_check(_completed == EXPECTED_TESTS,
		"all %d test functions ran to completion (only %d did — an aborted function runs no assertions)" % [EXPECTED_TESTS, _completed])

	if _fails.is_empty():
		print("BATTLE PIPELINE TESTS: PASS")
		quit(0)
	else:
		print("BATTLE PIPELINE TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)


# ─── Fixture ────────────────────────────────────────────────────────────────

const P_NAME := "Brian C."
const C_NAME := "Test Companion"
const E_LABEL := "Ruin Guard 900"

## Stand up a minimal but realistic battle world in the synced tables. Uses a real
## character id/element/weapon combination so GameDB ability lookups resolve.
func _seed_world(g) -> void:
	g._synced["Characters"] = {
		"2": {
			"id": 2, "Name": P_NAME, "Element": "Nature", "Current_Health": 100,
			"Max_Health": 100, "Burst_Charges": 0, "Applied_Element": "None",
			"Shield_Health": 0, "Shield_Duration": 0, "Skipped": false,
			"Health_Base_Points": 10, "Attack_Base_Points": 10, "Defense_Base_Points": 10,
			"Elemental_Mastery_Base_Points": 5, "Energy_Recharge_Base_Points": 5,
			"Critical_Damage_Base_Points": 5, "User_Type": "Player",
		},
	}
	g._synced["Companions"] = {
		"77": {
			"id": 77, "Name": C_NAME, "Element": "Nature", "Owner": P_NAME,
			"Active": true, "Deceased": false, "Unlocked": true,
			"Current_Health": 50, "Max_Health": 50, "Applied_Element": "None",
		},
	}
	g._synced["BattleEnemies"] = {
		"900": {
			"id": 900, "EnemyName": "Ruin Guard", "EnemyID": 1,
			"Current_Health": 200, "Max_Health": 200, "Killed": false,
			# NB: BattleEnemies spells this without the underscore — Characters and
			# Companions use "Applied_Element", enemies use "AppliedElement".
			"AppliedElement": "None", "Shield_Health": 0, "Shield_Duration": 0,
		},
	}
	g._synced["Party"] = {
		"1": {
			"id": 1, "Current_Turn": P_NAME, "Party_Member_1": P_NAME,
			"Mora": 1000, "Current_Region": "Mondstadt", "Companion_Limit": 2,
		},
	}
	g._synced["Character_Weapons"] = {
		"10": {
			"id": 10, "Weapon": "Test Claymore", "Owner": P_NAME, "Owner_Type": "Character",
			"Equipped": true, "Type": "Claymore", "Quantity": 1,
			"Stat_1_Type": "Attack", "Stat_1_Value": 5.0,
		},
	}
	g._synced["Character_Artifacts"] = {}
	g._synced["Active_Status_Effects"] = {}
	for t in ["Characters", "Companions", "BattleEnemies", "Party", "Character_Weapons"]:
		g._process_table(t, g._synced[t].values())


func _enemy_hp(g) -> int:
	return int(g.BATTLEENEMIES.get("900", {}).get("Current_Health", -1))


## Apply an updates array the way Global.Update_Records would locally, so a test
## can assert on post-turn state without a host or a network peer.
func _apply(g, updates: Array) -> void:
	for u in updates:
		g._apply_local_update(str(u.get("table", "")), str(int(u.get("record_id", 0))),
			str(u.get("field", "")), u.get("value"))


# ─── Battler assembly ───────────────────────────────────────────────────────

func _test_battler_assembly(g) -> void:
	var order := [P_NAME, C_NAME, E_LABEL]
	var bd: Dictionary = BattlerState.build_all(order)

	_eq(bd.size(), 3, "all three battlers assemble")
	_eq(str(bd.get(P_NAME, {}).get("type", "")), "Character", "player typed as Character")
	_eq(str(bd.get(C_NAME, {}).get("type", "")), "Companion", "companion typed as Companion")
	_eq(str(bd.get(E_LABEL, {}).get("type", "")), "Enemy", "enemy typed as Enemy")

	_eq(int(bd.get(P_NAME, {}).get("current_health", 0)), 100, "player HP carried into battler_data")
	_eq(int(bd.get(E_LABEL, {}).get("max_health", 0)), 200, "enemy max HP carried")

	# The enemy label's trailing token is its record id — a rename that breaks this
	# convention silently reclassifies the battler (this is how players got dropped).
	var stray: Dictionary = BattlerState.build_all(["Nobody At All"])
	_eq(stray.size(), 0, "an unknown battler is dropped rather than misclassified")
	_done()


# ─── Ability list (what the attack dropdown renders) ────────────────────────

## _setup_attacks filters entity_current_active_ability_data by passive/weight and
## resolves each id through GameDB. Mirror that here so a data change that empties
## the dropdown fails a test instead of a session.
func _test_ability_list_for_dropdown(g, gdb) -> void:
	var bd: Dictionary = BattlerState.build_all([P_NAME])
	var battler: Dictionary = bd.get(P_NAME, {})
	_check(not battler.is_empty(), "player battler assembled for ability test")

	var actives: Dictionary = battler.get("entity_current_active_ability_data", {})
	_check(actives.size() > 0, "player has active abilities (dropdown would not be empty)")

	var selectable := 0
	var passives := 0
	var unresolved := 0
	for item in actives.values():
		var raw = item.get("Ability_ID")
		if raw == null:
			continue
		var ability: AbilityData = gdb.get_ability(int(raw))
		if ability == null:
			unresolved += 1
			continue
		if str(ability.ability_type).to_lower() == "passive" or ability.weight <= 0.0:
			passives += 1
		else:
			selectable += 1

	_eq(unresolved, 0, "every active ability id resolves in GameDB (no null entries)")
	_check(selectable > 0, "at least one selectable attack exists for the dropdown")

	# The kit filter is element + weapon type; a mismatch must yield nothing rather
	# than leaking another element's kit.
	var defs: Dictionary = battler.get("entity_current_ability_data", {})
	for d in defs.values():
		var el := str(d.get("element", ""))
		if el != "" and el != "Physical":
			_eq(el, "Nature", "current ability defs match the character's element")
	_done()


# ─── Turn order ─────────────────────────────────────────────────────────────

func _test_turn_order_and_advance(g, bm) -> void:
	bm.clear_state()
	var order := [P_NAME, C_NAME, E_LABEL]
	var bd: Dictionary = BattlerState.build_all(order)
	bm.set_host_view(bd, P_NAME, 0)
	_check(bm.active, "BattleManager activates with a host view")
	_eq(bm.current_turn, P_NAME, "current turn starts on the player")

	# Cooldowns are per battler and per ability, and must not bleed across.
	bm.put_on_cooldown(P_NAME, 1234, 3)
	_eq(bm.remaining(P_NAME, 1234), 3, "cooldown registered")
	bm.tick_battler(C_NAME)
	_eq(bm.remaining(P_NAME, 1234), 3, "another battler's tick doesn't decrement ours")
	bm.tick_battler(P_NAME)
	_eq(bm.remaining(P_NAME, 1234), 2, "own tick decrements")
	bm.clear_state()
	_done()


# ─── Damage ─────────────────────────────────────────────────────────────────

func _turn_input(battler: String, target_label: String, dmg: int, extra := {}) -> Dictionary:
	var input := {
		"battler_name": battler,
		"attack_used": extra.get("attack_used", "None"),
		"attack_roll": 10,
		"tiles_moved": 0,
		"burst_gained": 0,
		"passive_stacks": 0,
		"critical_hit": false,
		"item_used": "None",
		"item_target": "None",
		"battle_id": "test",
		"turn_no": 1,
		"targets": [{
			"name": target_label,
			"table": "BattleEnemies",
			"record_id": 900,
			"defense_roll": 0,
			"hits": extra.get("hits", 1),
			"raw_damage": dmg,
			"attack_type": extra.get("attack_type", "Damage"),
			"killed": false,
			"shield_hit": extra.get("shield_hit", false),
		}],
	}
	return input

func _test_damage_resolution(g, bm, TP) -> void:
	_seed_world(g)
	var bd: Dictionary = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)

	var before := _enemy_hp(g)
	_eq(before, 200, "enemy starts at full HP")

	var updates: Array = TP.process_turn(_turn_input(P_NAME, E_LABEL, 50))
	_check(updates.size() > 0, "processing a damaging turn produces updates")
	_apply(g, updates)
	_eq(_enemy_hp(g), 150, "50 damage reduces enemy HP to 150")

	bm.clear_state()
	_done()

func _test_shield_absorption(g, bm, TP) -> void:
	_seed_world(g)
	# Give the enemy a shield to absorb into.
	g._apply_local_update("BattleEnemies", "900", "Shield_Health", 30)
	var bd: Dictionary = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)

	# Damage under the shield: HP untouched, shield reduced.
	var u1: Array = TP.process_turn(_turn_input(P_NAME, E_LABEL, 10, {"shield_hit": true}))
	_apply(g, u1)
	_eq(_enemy_hp(g), 200, "damage inside the shield leaves HP untouched")
	_eq(int(g.BATTLEENEMIES.get("900", {}).get("Shield_Health", -1)), 20, "shield absorbs the hit")

	# Damage exceeding the shield: shield breaks, overflow hits HP.
	var u2: Array = TP.process_turn(_turn_input(P_NAME, E_LABEL, 50, {"shield_hit": true}))
	_apply(g, u2)
	_eq(_enemy_hp(g), 170, "overflow past a 20 shield deals 30 to HP")

	bm.clear_state()
	_done()

func _test_healing_and_overkill(g, bm, TP) -> void:
	_seed_world(g)
	var bd: Dictionary = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)

	# Healing is negative damage routed through the same path.
	var d: Array = TP.process_turn(_turn_input(P_NAME, E_LABEL, 60))
	_apply(g, d)
	_eq(_enemy_hp(g), 140, "damage applied before healing test")

	var h: Array = TP.process_turn(_turn_input(P_NAME, E_LABEL, 30, {"attack_type": "Healed"}))
	_apply(g, h)
	_eq(_enemy_hp(g), 170, "healing restores HP")

	# Healing must not exceed Max_Health.
	var h2: Array = TP.process_turn(_turn_input(P_NAME, E_LABEL, 9999, {"attack_type": "Healed"}))
	_apply(g, h2)
	_eq(_enemy_hp(g), 200, "overheal clamps at Max_Health")

	# Overkill must clamp at 0, never go negative — negative HP has broken UI before.
	var u: Array = TP.process_turn(_turn_input(P_NAME, E_LABEL, 9999))
	_apply(g, u)
	_eq(_enemy_hp(g), 0, "overkill clamps to 0 rather than going negative")

	# And a killed enemy should be flagged, so turn-advance can skip it.
	var killed = g.BATTLEENEMIES.get("900", {}).get("Killed", false)
	_check(_enemy_hp(g) == 0, "enemy at 0 HP after overkill")
	_check(killed == true or _enemy_hp(g) == 0,
		"enemy is either flagged Killed or readable as 0 HP for skip logic")

	bm.clear_state()
	_done()


# ─── Effects display ────────────────────────────────────────────────────────

## The EFFECTS tab renders from EffectProcessor.serialize_battler(). Pin the shape
## it depends on: source, description, duration string inputs, and permanence.
func _test_effects_display_payload(g, bm) -> void:
	var proc = EffectProcessor.new()

	var gear = GameEffect.new()
	gear.trigger = "ON_HIT"
	gear.duration = 0
	gear.effect_type = "FLAT_DAMAGE"
	gear.effect_value = 3.0
	gear.description = "Weapon passive"
	proc.add_effect(P_NAME, gear, "weapon", "Test Claymore")

	var stun = GameEffect.new()
	stun.trigger = "ON_HIT"
	stun.duration = 2
	stun.effect_type = "STUN"
	stun.description = "Stunned"
	proc.add_effect(P_NAME, stun, "status", "Stun")

	var rows: Array = proc.serialize_battler(P_NAME)
	_eq(rows.size(), 2, "both effects serialize for display")

	var by_source := {}
	for r in rows:
		by_source[str(r.get("source_type", ""))] = r

	_check(by_source.has("weapon"), "weapon effect present in display payload")
	_check(by_source.has("status"), "status effect present in display payload")
	_eq(int(by_source["weapon"].get("turns_remaining", 0)), -1,
		"gear effect reports perm (-1) to the UI")
	_eq(int(by_source["status"].get("turns_remaining", 0)), 2,
		"status effect reports its real duration")
	_eq(str(by_source["weapon"].get("description", "")), "Weapon passive",
		"description survives into the display payload")
	_eq(str(by_source["weapon"].get("source_name", "")), "Test Claymore",
		"source name survives into the display payload")

	# A turn end must not evict the standing trait, but must tick the status.
	proc.on_turn_end(P_NAME)
	var after: Array = proc.serialize_battler(P_NAME)
	var srcs := []
	for r in after:
		srcs.append(str(r.get("source_type", "")))
	_check(srcs.has("weapon"), "gear effect survives a turn end (never leaves the tab)")
	_check(srcs.has("status"), "status effect with 2 turns survives one tick")

	proc.on_turn_end(P_NAME)
	var after2: Array = proc.serialize_battler(P_NAME)
	var srcs2 := []
	for r in after2:
		srcs2.append(str(r.get("source_type", "")))
	_check(srcs2.has("weapon"), "gear effect still present after two turn ends")
	_check(not srcs2.has("status"), "status effect expires when its duration runs out")
	_done()


# ─── Stats for the active battler ───────────────────────────────────────────

func _test_active_turn_stats(g, cm) -> void:
	cm.recalculate_all()
	var calc = cm.get_stats(P_NAME)
	_check(calc != null, "player stats calculate for the active turn")
	if calc != null:
		_check(float(calc.health) > 0.0, "calculated health is positive")
		_check(float(calc.attack) > 0.0, "calculated attack is positive")

	# Companion stats derive from the party average plus their own gear, and must
	# not silently collapse to zero when the party list is healthy.
	var ccalc = cm.calculate_companion_stats(C_NAME)
	_check(ccalc != null, "companion stats calculate")
	if ccalc != null:
		_check(float(ccalc.health) > 0.0,
			"companion base stats are non-zero (guards the empty-party-average bug)")

	# An unknown name must return null rather than a zeroed block that reads as real.
	_check(cm.calculate_companion_stats("No Such Companion") == null,
		"unknown companion yields null, not a fake zeroed stat block")
	_done()


# ─── Dock visibility (host vs client) ───────────────────────────────────────

## BattleScene._update_dock_visibility decides who may act. Recreate the rule so a
## change to it fails here rather than handing a client someone else's turn.
func _should_show(g, is_host: bool, current_turn: String, active_user: String) -> bool:
	var turn_type := "Enemy"
	if g.PartyCharacters.has(current_turn):
		turn_type = "Character"
	elif g.PartyCompanions.has(current_turn):
		turn_type = "Companion"

	var is_my_turn := (current_turn == active_user)
	var is_my_companion := false
	if turn_type == "Companion":
		var cid = g.COMPANIONS_NAME.get(current_turn, "")
		is_my_companion = (str(g.COMPANIONS.get(cid, {}).get("Owner", "")) == active_user)

	if is_host:
		return is_my_turn or is_my_companion or (turn_type == "Enemy")
	return is_my_turn or is_my_companion

func _test_dock_visibility_rules(g) -> void:
	_seed_world(g)

	_check(_should_show(g, false, P_NAME, P_NAME), "client sees dock on their own turn")
	_check(not _should_show(g, false, P_NAME, "Someone Else"),
		"client does NOT see dock on another player's turn")
	_check(not _should_show(g, false, E_LABEL, P_NAME),
		"client does NOT get the dock on an enemy turn")
	_check(_should_show(g, true, E_LABEL, "DM"),
		"host DOES get the dock on an enemy turn")
	_check(_should_show(g, false, C_NAME, P_NAME),
		"companion owner gets the dock on their companion's turn")
	_check(not _should_show(g, false, C_NAME, "Someone Else"),
		"a non-owner does NOT get the dock for someone else's companion")
	_done()


# ─── Snapshot round-trip ────────────────────────────────────────────────────

## The client renders the host's broadcast, which crosses JSON. Anything that
## doesn't survive stringify/parse is invisible on every machine but the host's.
func _test_snapshot_roundtrip(bm) -> void:
	bm.clear_state()
	var bd := {
		P_NAME: {
			"id": 2, "name": P_NAME, "type": "Character", "current_health": 88,
			"max_health": 100, "burst_charges": 2,
			"entity_current_ability_data": {"397": {"id": 397, "name": "Skill", "cooldown": 2}},
			"entity_current_active_ability_data": {"1": {"Ability_ID": 397, "Ability_Cooldown": 1}},
		},
		E_LABEL: {"id": 900, "type": "Enemy", "current_health": 200},
	}
	bm.set_host_view(bd, P_NAME, 4)
	var parsed = JSON.parse_string(JSON.stringify(bm.make_snapshot()))
	bm.clear_state()
	bm.apply_snapshot(parsed)

	_check(bm.active, "client activates from a broadcast snapshot")
	_eq(bm.current_turn, P_NAME, "current turn survives the wire")
	_eq(bm.turn_no, 4, "turn number survives the wire")
	_eq(int(bm.battler_data.get(P_NAME, {}).get("current_health", 0)), 88,
		"battler HP survives the wire")
	var cd = bm.battler_data.get(P_NAME, {}).get("entity_current_active_ability_data", {}).get("1", {}).get("Ability_Cooldown")
	_eq(int(cd), 1, "nested ability cooldown survives the wire (drives the dropdown label)")

	# A stale snapshot must not roll state backwards.
	bm.apply_snapshot({"turn_no": 1, "current_turn": "Stale", "battler_data": {}})
	_eq(bm.current_turn, P_NAME, "out-of-order snapshot is ignored")
	_eq(bm.turn_no, 4, "turn number not rolled back by a stale snapshot")
	bm.clear_state()
	_done()

# ─── Element application ────────────────────────────────────────────────────
# An action applies its element only when it actually did something to the
# target: an attack has to get damage through to HP (a shield that swallows the
# hit whole counts as nothing landing), and a heal or shield has to be non-zero.
# Before the fix (2026-08-22) step 4b in turn_processor ran unconditionally, so
# a whiff still stamped the element on the target — and could even trigger a
# reaction that consumed a standing aura for free.

## Element currently on the test enemy.
func _enemy_element(g) -> String:
	return str(g.BATTLEENEMIES.get("900", {}).get("AppliedElement", "?"))

## A non-Physical ability the seeded player can actually use, as
## {"name": String, "element": String}, so the turn processor resolves a real
## element rather than falling back to Physical. Empty name means none was found.
##
## Only valid AFTER bm.set_host_view() — that is what populates Global.BattlerData.
func _elemental_attack(g) -> Dictionary:
	var bd: Dictionary = g.BattlerData.get(P_NAME, {})
	for ab in bd.get("entity_current_ability_data", {}).values():
		var el := str(ab.get("element", ""))
		if el != "" and el != "Physical" and el != "None":
			return {"name": str(ab.get("name", "")), "element": el}
	return {"name": "", "element": ""}

func _test_element_requires_damage(g, bm, TP) -> void:
	_seed_world(g)
	var bd: Dictionary = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)

	var atk: String = _elemental_attack(g).get("name", "")
	if atk == "":
		_fails.append("element gating: no elemental ability available on the fixture")
		bm.clear_state()
		_done()
		return

	# A landed hit applies the element.
	_eq(_enemy_element(g), "None", "enemy starts with no element applied")
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 12, {"attack_used": atk})))
	_check(_enemy_element(g) != "None", "a hit dealing 12 damage applies its element")

	# A whiff must not. Reset, then swing for 0.
	_seed_world(g)
	bd = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 0, {"attack_used": atk})))
	_eq(_enemy_element(g), "None", "a 0-damage attack must NOT apply its element")

	# hits = 0 is the other way a miss gets recorded on the result card.
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 9, {"attack_used": atk, "hits": 0})))
	_eq(_enemy_element(g), "None", "an attack that landed no hits must NOT apply its element")

	# And 1 damage — the boundary — does apply.
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 1, {"attack_used": atk})))
	_check(_enemy_element(g) != "None", "1 damage is enough to apply the element")

	bm.clear_state()
	_done()

## Heals and shield grants DO carry their element, as long as the amount is
## non-zero — they did something to the target.
func _test_element_applied_by_support(g, bm, TP) -> void:
	_seed_world(g)
	var bd: Dictionary = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)

	var atk: String = _elemental_attack(g).get("name", "")
	if atk == "":
		_fails.append("support gating: no elemental ability available on the fixture")
		bm.clear_state()
		_done()
		return

	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 10,
		{"attack_used": atk, "attack_type": "Healed"})))
	_check(_enemy_element(g) != "None", "a heal of 10 applies its element")

	# A zero-value heal did nothing, so it applies nothing.
	_seed_world(g)
	bd = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 0,
		{"attack_used": atk, "attack_type": "Healed"})))
	_eq(_enemy_element(g), "None", "a 0-value heal must NOT apply its element")

	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 15,
		{"attack_used": atk, "attack_type": "Shielded"})))
	_check(_enemy_element(g) != "None", "granting a 15-point shield applies its element")

	bm.clear_state()
	_done()

## Shields gate the element on whether damage actually reached HP: fully
## absorbed applies nothing, partially absorbed applies it.
func _test_element_vs_shield_absorption(g, bm, TP) -> void:
	_seed_world(g)
	g._apply_local_update("BattleEnemies", "900", "Shield_Health", 30)
	var bd: Dictionary = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)

	var atk: String = _elemental_attack(g).get("name", "")
	if atk == "":
		_fails.append("shield gating: no elemental ability available on the fixture")
		bm.clear_state()
		_done()
		return

	# 10 into a 30 shield — swallowed whole, nothing reaches HP.
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 10,
		{"attack_used": atk, "shield_hit": true})))
	_eq(_enemy_hp(g), 200, "fixture: the fully-absorbed hit left HP alone")
	_eq(_enemy_element(g), "None", "a hit the shield fully absorbs must NOT apply its element")

	# Exactly the shield value is still full absorption (0 reaches HP).
	_seed_world(g)
	g._apply_local_update("BattleEnemies", "900", "Shield_Health", 30)
	bd = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 30,
		{"attack_used": atk, "shield_hit": true})))
	_eq(_enemy_element(g), "None", "damage exactly equal to the shield applies nothing")

	# 31 into a 30 shield — 1 gets through, so the element lands.
	_seed_world(g)
	g._apply_local_update("BattleEnemies", "900", "Shield_Health", 30)
	bd = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 31,
		{"attack_used": atk, "shield_hit": true})))
	_eq(_enemy_hp(g), 199, "fixture: 1 point of overflow reached HP")
	_check(_enemy_element(g) != "None", "partial absorption still applies the element")

	bm.clear_state()
	_done()

## A miss must not consume an aura that is already on the target — that was the
## sharpest edge of the bug: whiffing still burned the setup for a reaction.
func _test_miss_does_not_consume_existing_element(g, bm, TP) -> void:
	_seed_world(g)
	var bd: Dictionary = BattlerState.build_all([P_NAME, E_LABEL])
	bm.set_host_view(bd, P_NAME, 1)

	# Global.BattlerData is only populated by set_host_view, so the lookup has to
	# happen here — doing it earlier silently returns nothing and the test
	# quietly proves nothing.
	var atk: Dictionary = _elemental_attack(g)
	if str(atk.get("name", "")) == "":
		_fails.append("aura gating: no elemental ability available on the fixture")
		bm.clear_state()
		_done()
		return

	# Pre-load a DIFFERENT element so any application would read as a reaction
	# and clear the aura.
	var standing := "Fire" if str(atk.get("element", "")) != "Fire" else "Water"
	g._apply_local_update("BattleEnemies", "900", "AppliedElement", standing)
	_eq(_enemy_element(g), standing, "fixture: the standing aura is in place")

	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 0, {"attack_used": str(atk.get("name", ""))})))
	_eq(_enemy_element(g), standing, "a whiff must leave an existing aura intact")

	# The same swing that connects does consume it (reaction).
	_apply(g, TP.process_turn(_turn_input(P_NAME, E_LABEL, 7, {"attack_used": str(atk.get("name", ""))})))
	_eq(_enemy_element(g), "None", "a landed hit of a different element reacts and consumes the aura")

	bm.clear_state()
	_done()

# ─── Party stats table ──────────────────────────────────────────────────────
# The battle screen's sidebar only ever shows the battler whose turn it is, so
# there was no way to read a companion's DEF when an enemy targeted it. The
# always-available Party Stats table covers every player AND every active
# companion, whoever's turn it is.

func _test_party_stats_table(g, bm) -> void:
	_seed_world(g)
	var bd: Dictionary = BattlerState.build_all([P_NAME, C_NAME, E_LABEL])
	# Deliberately put the turn on the ENEMY: the whole point is that the table
	# works when it is nobody in the party's turn.
	bm.set_host_view(bd, E_LABEL, 1)

	var screen = _new_battle_screen()
	if screen == null:
		bm.clear_state()
		_done()
		return

	# Roster covers players and active companions alike.
	var roster: Array = screen._ps_roster()
	var names: Array = []
	for r in roster:
		names.append(str(r.get("name", "")))
	_check(names.has(P_NAME), "roster includes the player (got %s)" % str(names))
	_check(names.has(C_NAME), "roster includes the active companion (got %s)" % str(names))

	# The companion's numbers are readable even though it isn't its turn.
	var comp: Dictionary = screen._ps_collect(C_NAME, true)
	_check(not comp.is_empty(), "companion stats resolve off-turn")
	_eq(str(comp.get("kind", "")), "Companion", "companion row is labelled Companion")
	# Current HP comes from the synced row; MAX comes from calculated stats
	# (base points + gear + effects), same as the sidebar panel — so assert the
	# shape and the current value, not a hardcoded maximum.
	_check(str(comp.get("hp", "")).begins_with("50 / "),
		"companion current HP reads from the synced row (got %s)" % str(comp.get("hp", "")))
	_check(str(comp.get("def", "")).is_valid_int(),
		"companion DEF is a number (got %s)" % str(comp.get("def", "")))

	# And the player's.
	var play: Dictionary = screen._ps_collect(P_NAME, false)
	_check(not play.is_empty(), "player stats resolve")
	_eq(str(play.get("kind", "")), "Player", "player row is labelled Player")
	_check(str(play.get("hp", "")).begins_with("100 / "),
		"player current HP reads from the synced row (got %s)" % str(play.get("hp", "")))
	_check(str(play.get("atk", "")).is_valid_int(),
		"player ATK is a number (got %s)" % str(play.get("atk", "")))

	# Shield and element render as a dash when there's nothing to show, so the
	# table never displays a bare "0"/"None" that reads as a real value.
	_eq(str(play.get("shield", "")), "—", "no shield renders as a dash")
	_eq(str(play.get("element", "")), "—", "no applied element renders as a dash")

	# With a shield and an aura up, the real values come through.
	g._apply_local_update("Characters", "2", "Shield_Health", 25)
	g._apply_local_update("Characters", "2", "Applied_Element", "Fire")
	var play2: Dictionary = screen._ps_collect(P_NAME, false)
	_eq(str(play2.get("shield", "")), "25", "an active shield shows its value")
	_eq(str(play2.get("element", "")), "Fire", "an applied element shows its name")

	# An unknown battler yields nothing rather than a row of zeroes.
	_check(screen._ps_collect("Nobody At All", false).is_empty(),
		"an unknown battler produces no row")

	screen.free()
	bm.clear_state()
	_done()


## Build the overlay for real, so a bad call in the UI path fails here rather
## than mid-session. Separate from the data test so an abort is attributable.
func _test_party_stats_overlay(g, bm) -> void:
	_seed_world(g)
	# Build with a shield and an aura up so the dash/value branches both render.
	g._apply_local_update("Characters", "2", "Shield_Health", 25)
	g._apply_local_update("Characters", "2", "Applied_Element", "Fire")
	var bd: Dictionary = BattlerState.build_all([P_NAME, C_NAME, E_LABEL])
	bm.set_host_view(bd, E_LABEL, 1)

	var screen = _new_battle_screen()
	if screen == null:
		bm.clear_state()
		_done()
		return
	screen.Current_Turn = E_LABEL

	screen._on_party_stats_pressed()
	_check(screen._party_stats_overlay != null, "the stats overlay opens")
	_check(screen._party_stats_grid != null, "the stats table is built")
	if screen._party_stats_grid != null:
		var cols: int = screen._party_stats_grid.columns
		var cells: int = screen._party_stats_grid.get_child_count()
		_eq(cols, screen.PS_COLUMNS.size(), "the grid has one column per stat")
		# 1 header row + 1 player + 1 companion, all fully populated.
		_eq(cells, cols * 3, "header plus a full row for the player and the companion")

	# Pressing again toggles it shut.
	screen._on_party_stats_pressed()
	_check(screen._party_stats_overlay == null, "pressing again closes the overlay")

	# Refreshing while closed is a no-op rather than a crash.
	screen._refresh_party_stats()

	screen.free()
	bm.clear_state()
	_done()


## An off-tree BattleScene instance. _ready() never runs, so none of the battle
## bootstrap fires — only the pure helpers under test are exercised.
func _new_battle_screen():
	var scene_script = load("res://Scenes/BattleScene.gd")
	if scene_script == null:
		_fails.append("party stats: BattleScene.gd did not compile")
		return null
	return scene_script.new()
