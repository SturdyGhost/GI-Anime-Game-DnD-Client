extends SceneTree
## Headless tests for the host-authoritative battle refactor (cooldowns + snapshot).
## Run: godot --headless --script test/battle_host_authority_test.gd
## (No GdUnit4 in this project; this is a self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.

var _ran := false
var _fails: Array[String] = []

func _init() -> void:
	# Autoloads aren't attached during _init; run after the first process frame.
	process_frame.connect(_run)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _run() -> void:
	if _ran:
		return
	_ran = true
	var bm = root.get_node_or_null("BattleManager")
	if bm == null:
		print("BATTLE HOST-AUTHORITY TESTS: FAIL (BattleManager autoload missing)")
		quit(1)
		return

	_test_cooldowns(bm)
	_test_snapshot(bm)

	if _fails.is_empty():
		print("BATTLE HOST-AUTHORITY TESTS: PASS")
		quit(0)
	else:
		print("BATTLE HOST-AUTHORITY TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)

func _test_cooldowns(bm) -> void:
	bm.clear_state()
	bm.put_on_cooldown("Brian C.", 397, 5)
	_check(bm.remaining("Brian C.", 397) == 5, "put_on_cooldown sets remaining=static length")
	bm.tick_battler("Brian C.")
	_check(bm.remaining("Brian C.", 397) == 4, "tick decrements the acting battler")
	# Cross-battler isolation
	bm.put_on_cooldown("Dylan", 100, 2)
	bm.tick_battler("Dylan")
	_check(bm.remaining("Brian C.", 397) == 4, "ticking another battler doesn't touch this one")
	_check(bm.remaining("Dylan", 100) == 1, "tick decrements Dylan")
	# End-of-own-turn ORDER: tick existing first, then set the just-used ability ->
	# it must NOT be decremented this turn.
	bm.tick_battler("Brian C.")            # 397: 4 -> 3
	bm.put_on_cooldown("Brian C.", 500, 2)
	_check(bm.remaining("Brian C.", 500) == 2, "freshly-used ability is not double-ticked")
	_check(bm.remaining("Brian C.", 397) == 3, "older cooldown still ticked")
	# Ready (0) entries are removed
	bm.put_on_cooldown("Brian C.", 999, 1)
	bm.tick_battler("Brian C.")            # 999: 1 -> 0 (removed)
	_check(bm.remaining("Brian C.", 999) == 0, "cooldown reaches 0 (ready)")
	_check(bm.cooldowns.get("Brian C.", {}).has(397), "non-zero cooldowns survive the tick")
	bm.clear_state()
	_check(bm.cooldowns.is_empty(), "clear_state empties cooldowns")

func _test_snapshot(bm) -> void:
	var bd := {
		"Brian C.": {
			"id": 2, "name": "Brian C.", "type": "Character", "current_health": 120,
			"entity_current_ability_data": {"397": {"id": 397, "name": "Skill", "cooldown": 2, "Ability_Cooldown": 1}},
			"max_burst_charges": 12,
		},
		"Ruin Guard 5": {"id": 5, "type": "Enemy", "current_health": 300},
	}
	bm.set_host_view(bd, "Brian C.", 7)
	_check(bm.active, "set_host_view activates BattleManager")
	# Round-trip through JSON exactly like the broadcast RPC.
	var parsed = JSON.parse_string(JSON.stringify(bm.make_snapshot()))
	bm.clear_state()
	_check(not bm.active, "clear_state deactivates")
	bm.apply_snapshot(parsed)
	_check(bm.active, "apply_snapshot reactivates")
	_check(bm.current_turn == "Brian C.", "current_turn survives round-trip")
	_check(bm.turn_no == 7, "turn_no survives round-trip")
	var cd = bm.battler_data.get("Brian C.", {}).get("entity_current_ability_data", {}).get("397", {}).get("Ability_Cooldown")
	_check(int(cd) == 1, "nested ability cooldown survives round-trip")
	_check(bm.battler_data.get("Ruin Guard 5", {}).get("current_health") == 300, "enemy HP survives round-trip")
	# Monotonic guard: a stale (lower turn_no) snapshot is ignored.
	bm.apply_snapshot({"turn_no": 3, "current_turn": "X", "battler_data": {}})
	_check(bm.turn_no == 7 and bm.current_turn == "Brian C.", "stale snapshot is ignored")
	bm.clear_state()
