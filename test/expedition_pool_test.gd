extends SceneTree
## Headless tests for expedition pool generation (2026-08-22 rework).
## Run: godot --headless --script test/expedition_pool_test.gd
## (No GdUnit4 in this project; self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## The rework decoupled weapon/risk/yield from the expedition template and made
## caches unique across the whole pool. The rules, all of which are checked over
## many generated pools rather than a single lucky sample:
##
##   1. A cache never appears twice in one pool, in any region.
##   2. base_materials is derived from risk: safe 3, moderate 4, risky 6. Always.
##   3. Every pool offers at least one safe, one moderate and one risky.
##   4. Slots 0-1 are the party's region; 2-4 take it ~60% of the time, except
##      that a region with no unused caches left forces the slot abroad.
##   5. At most one expedition TYPE is duplicated, and only ever twice.
##   6. Any weapon can headline any type.
##   7. A name only claims danger when the slot actually rolled risky.

const RUNS := 400
const POOL_SIZE := 5
const REGIONS := ["Mondstadt", "Liyue", "Inazuma", "Sumeru"]

var _ran := false
var _fails: Array[String] = []
var _completed := 0
const EXPECTED_TESTS := 7

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
	var gdb = root.get_node_or_null("GameDB")
	if gdb == null:
		print("EXPEDITION POOL TESTS: FAIL (GameDB autoload missing)")
		quit(1)
		return

	var EM = load("res://Scripts/systems/expedition_manager.gd")
	if EM == null or not EM.has_method("generate_pool"):
		print("EXPEDITION POOL TESTS: FAIL (expedition_manager.gd did not compile)")
		quit(1)
		return

	# Every region must actually have caches, or the rest of this proves nothing.
	var LG = load("res://Scripts/systems/loot_generator.gd")
	for r in REGIONS:
		_check(LG.pick_caches(r, 99).size() > 0, "region %s has caches to draw from" % r)

	_test_pool_size_and_shape(EM)
	_test_cache_uniqueness(EM)
	_test_risk_drives_materials(EM)
	_test_every_tier_present(EM)
	_test_region_slot_rules(EM)
	_test_type_repeat_cap(EM)
	_test_risky_naming(EM)

	_check(_completed == EXPECTED_TESTS,
		"all %d test functions ran to completion (only %d did)" % [EXPECTED_TESTS, _completed])

	if _fails.is_empty():
		print("EXPEDITION POOL TESTS: PASS")
		quit(0)
	else:
		print("EXPEDITION POOL TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)


# ─── Helpers ────────────────────────────────────────────────────────────────

## Generate `RUNS` pools, cycling the party's region so no rule is only ever
## exercised from Mondstadt.
func _pools(EM) -> Array:
	var out: Array = []
	for i in range(RUNS):
		var home: String = REGIONS[i % REGIONS.size()]
		out.append({"home": home, "pool": EM.generate_pool(home, POOL_SIZE)})
	return out


# ─── Tests ──────────────────────────────────────────────────────────────────

func _test_pool_size_and_shape(EM) -> void:
	var bad_size := 0
	var bad_weapon := 0
	var weapons_seen := {}
	var types_seen := {}
	for run in _pools(EM):
		var pool: Array = run["pool"]
		if pool.size() != POOL_SIZE:
			bad_size += 1
		for e in pool:
			if not (e.bonus_weapon in EM.BONUS_WEAPONS):
				bad_weapon += 1
			weapons_seen[e.bonus_weapon] = true
			types_seen[e.expedition_type] = true

	_eq(bad_size, 0, "every pool has %d slots" % POOL_SIZE)
	_eq(bad_weapon, 0, "every bonus_weapon is a real weapon type")
	_eq(weapons_seen.size(), EM.BONUS_WEAPONS.size(),
		"all %d weapon types show up as a bonus across runs" % EM.BONUS_WEAPONS.size())
	_eq(types_seen.size(), EM.EXPEDITION_TEMPLATES.size(),
		"all %d expedition types are reachable" % EM.EXPEDITION_TEMPLATES.size())
	_done()

## The headline rule: take Sumeru cache 2 in one slot and no other slot may
## offer it, in that region or any other.
func _test_cache_uniqueness(EM) -> void:
	var dupes := 0
	for run in _pools(EM):
		var seen := {}
		for e in run["pool"]:
			# region+roll identifies the cache from the outside; two slots in one
			# region can't share a roll, and roll is what drives the payout.
			var key: String = "%s#%d" % [e.region, e.cache_roll]
			if seen.has(key):
				dupes += 1
			seen[key] = true
	_eq(dupes, 0, "no cache is offered twice in the same pool")
	_done()

## Riskier always pays more, and the two can never disagree.
func _test_risk_drives_materials(EM) -> void:
	var mismatches := 0
	var unknown_risk := 0
	for run in _pools(EM):
		for e in run["pool"]:
			if not EM.RISK_MATERIALS.has(e.risk_level):
				unknown_risk += 1
				continue
			if e.base_materials != int(EM.RISK_MATERIALS[e.risk_level]):
				mismatches += 1
	_eq(unknown_risk, 0, "every slot has a known risk tier")
	_eq(mismatches, 0, "base_materials always matches the risk tier")
	# And the ordering the rule exists to guarantee.
	_check(int(EM.RISK_MATERIALS["safe"]) < int(EM.RISK_MATERIALS["moderate"]),
		"safe yields less than moderate")
	_check(int(EM.RISK_MATERIALS["moderate"]) < int(EM.RISK_MATERIALS["risky"]),
		"moderate yields less than risky")
	_done()

## One of each tier is guaranteed, so a pool is never all-safe or all-risky.
func _test_every_tier_present(EM) -> void:
	var missing := 0
	var tier_counts := {"safe": 0, "moderate": 0, "risky": 0}
	for run in _pools(EM):
		var seen := {}
		for e in run["pool"]:
			seen[e.risk_level] = true
			tier_counts[e.risk_level] = int(tier_counts.get(e.risk_level, 0)) + 1
		for tier in ["safe", "moderate", "risky"]:
			if not seen.has(tier):
				missing += 1
	_eq(missing, 0, "every pool contains at least one safe, one moderate and one risky")

	# The 2 free slots should spread across tiers rather than favouring one, so
	# no tier should dominate. Each tier is guaranteed 1 of 5 (20%) plus a share
	# of the 2 free slots; anything outside 20-60% means the roll is skewed.
	var total: int = RUNS * POOL_SIZE
	for tier in tier_counts:
		var share: float = float(tier_counts[tier]) / float(total)
		_check(share > 0.20 and share < 0.60,
			"%s tier share is plausible (got %.2f, expected 0.20-0.60)" % [tier, share])
	_done()

## Slots 0-1 are home. Later slots lean home but must go abroad once home runs
## dry — with only 4 caches per region and 5 slots, that happens every pool.
func _test_region_slot_rules(EM) -> void:
	var slot0_away := 0
	var slot1_away := 0
	var pools_all_home := 0
	var late_home := 0
	var late_total := 0

	for run in _pools(EM):
		var home: String = run["home"]
		var pool: Array = run["pool"]
		if pool.size() < POOL_SIZE:
			continue
		if pool[0].region != home:
			slot0_away += 1
		if pool[1].region != home:
			slot1_away += 1

		var away := 0
		for i in range(POOL_SIZE):
			if pool[i].region != home:
				away += 1
			if i >= 2:
				late_total += 1
				if pool[i].region == home:
					late_home += 1
		if away == 0:
			pools_all_home += 1

	_eq(slot0_away, 0, "slot 0 is always the party's region")
	_eq(slot1_away, 0, "slot 1 is always the party's region")
	_eq(pools_all_home, 0,
		"no pool is entirely home region (4 caches per region can't fill 5 slots)")

	# Slots 2-4 want home 60% of the time, but cache exhaustion drags the real
	# rate down — home can supply at most 2 more after slots 0-1. So the observed
	# rate must sit below the nominal 60% yet still show a clear home lean.
	var late_rate: float = float(late_home) / float(maxi(late_total, 1))
	_check(late_rate > 0.25 and late_rate < 0.60,
		"slots 2-4 lean home but are capped by exhaustion (got %.2f, expected 0.25-0.60)" % late_rate)
	_done()

## At most one type may be duplicated, and only ever twice.
func _test_type_repeat_cap(EM) -> void:
	var over_two := 0
	var multi_dupe := 0
	var pools_with_dupe := 0

	for run in _pools(EM):
		var counts := {}
		for e in run["pool"]:
			counts[e.expedition_type] = int(counts.get(e.expedition_type, 0)) + 1
		var duped := 0
		for t in counts:
			if int(counts[t]) > 2:
				over_two += 1
			if int(counts[t]) == 2:
				duped += 1
		if duped > 1:
			multi_dupe += 1
		if duped == 1:
			pools_with_dupe += 1

	_eq(over_two, 0, "no type ever appears more than twice in a pool")
	_eq(multi_dupe, 0, "at most ONE type is duplicated per pool")
	# It has to actually happen sometimes, or the allowance is dead code.
	_check(pools_with_dupe > 0, "duplicated types do occur")
	_check(pools_with_dupe < RUNS, "duplicated types are not universal")
	_done()

## A name only promises danger when the slot really is risky.
func _test_risky_naming(EM) -> void:
	var false_alarm := 0
	var unmarked_risky := 0
	for run in _pools(EM):
		for e in run["pool"]:
			var flagged := false
			for adj in EM.RISKY_ADJECTIVES:
				if str(adj) in e.expedition_name:
					flagged = true
					break
			if flagged and e.risk_level != "risky":
				false_alarm += 1
			if e.risk_level == "risky" and not flagged:
				unmarked_risky += 1
	_eq(false_alarm, 0, "no safe/moderate run is named as though it were dangerous")
	_eq(unmarked_risky, 0, "every risky run is named as such")
	_done()
