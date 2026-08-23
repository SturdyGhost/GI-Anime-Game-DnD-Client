extends SceneTree
## Headless regression tests for the party-membership drift bug (2026-07-24).
## Run: godot --headless --script test/party_membership_drift_test.gd
## (No GdUnit4 in this project; this is a self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## The bug: PartyManager.get_members() read the typed PartySaveData.members on the
## host and the synced Party_Member_1..4 only on clients. PartySaveData.members is
## populated in exactly one place — migration.gd, during legacy save migration —
## and Global._set_party_field never maps Party_Member_*, so the typed field is
## frozen. Once it drifted, the host's Global.PartyCharacters omitted a real
## player, which meant:
##   1. BattlerState._build_one() fell through to the Enemy branch for that name,
##      _extract_enemy_id() returned 0, BATTLEENEMIES["0"] was empty -> {} -> the
##      player was dropped from battler_data entirely. Their client then saw only
##      "None" in the attack dropdown.
##   2. NetworkManager._peer_owns_battler() returned false -> their turn was
##      rejected -> the End Turn button did nothing.
## Both symptoms, one cause. These tests pin the fix: membership always comes
## from the synced Party record, on host and client alike.

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
	var g = root.get_node_or_null("Global")
	var pm = root.get_node_or_null("PartyManager")
	if g == null or pm == null:
		print("PARTY MEMBERSHIP DRIFT TESTS: FAIL (Global/PartyManager autoload missing)")
		quit(1)
		return

	_test_members_from_synced(g, pm)
	_test_player_dropped_from_battler_data(g, pm)

	if _fails.is_empty():
		print("PARTY MEMBERSHIP DRIFT TESTS: PASS")
		quit(0)
	else:
		print("PARTY MEMBERSHIP DRIFT TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)

## Seed a synced Party record with the given members, plus matching Characters
## rows so get_player_names()'s CHARACTERS_NAME check passes.
func _seed(g, members: Array) -> void:
	var party := {"id": 1, "Current_Turn": members[0] if members.size() > 0 else ""}
	for i in range(members.size()):
		party["Party_Member_%d" % (i + 1)] = members[i]
	g._synced["Party"] = {"1": party}
	var chars := {}
	for i in range(members.size()):
		chars[str(i + 10)] = {"id": i + 10, "Name": members[i], "Current_Health": 100, "Max_Health": 100}
	g._synced["Characters"] = chars
	g._process_table("Characters", chars.values())

func _test_members_from_synced(g, pm) -> void:
	_seed(g, ["Brian C.", "Dylan", "Brian F."])

	var members: Array = pm.get_members()
	_check(members.size() == 3, "get_members reads all 3 synced Party_Member_* (got %d)" % members.size())
	_check(members.has("Brian C."), "get_members includes Brian C.")
	_check(members.has("Brian F."), "get_members includes Brian F.")

	# The regression itself: the typed save is stale/empty, but membership must
	# still come from the synced record. Pre-fix this returned [] on the host.
	var party = pm.get_party()
	if party != null:
		party.members = []
		_check(pm.get_members().size() == 3,
			"stale/empty PartySaveData.members does NOT shrink get_members (was the bug)")

	# COMPANION placeholders are not player members.
	_seed(g, ["Brian C.", "COMPANION", "Dylan"])
	var m2: Array = pm.get_members()
	_check(not m2.has("COMPANION"), "COMPANION placeholder is excluded")
	_check(m2.size() == 2, "COMPANION slot doesn't count as a member (got %d)" % m2.size())

## The downstream consequence: a player present in the synced party must survive
## BattlerState.build_all() rather than falling through to the Enemy branch.
func _test_player_dropped_from_battler_data(g, pm) -> void:
	_seed(g, ["Brian C.", "Dylan"])
	g._synced["BattleEnemies"] = {}

	_check(g.PartyCharacters.has("Brian C."), "Global.PartyCharacters includes a synced party player")

	var bd: Dictionary = BattlerState.build_all(["Brian C.", "Dylan"])
	_check(bd.has("Brian C."), "player survives build_all (pre-fix they were dropped)")
	_check(str(bd.get("Brian C.", {}).get("type", "")) == "Character",
		"player is typed Character, not misclassified as Enemy")
	_check(bd.has("Dylan"), "second player also survives build_all")
