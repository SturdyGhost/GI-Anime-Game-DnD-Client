extends SceneTree
## Headless tests for the reflection-driven typed<->synced field bridge.
## Run: godot --headless --script test/sync_bridge_test.gd
## (No GdUnit4 in this project; self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## The synced tables (Global._synced, what clients receive) and the typed save
## resources (SaveManager) are two representations of the same entities. They used
## to be bridged by hand-written `match` statements that covered only 36 of 85
## exported fields; the other 49 silently drifted. PartySaveData.members was one
## of them, which dropped players out of battler_data and rejected their turns.
##
## These tests pin three things:
##   1. Every field the OLD hand-written setters handled still behaves identically
##      (including the null -> default fallbacks).
##   2. Fields that used to be unmapped now round-trip.
##   3. The bridge refuses to touch anything it shouldn't (ids, unknown fields).

var _ran := false
var _fails: Array[String] = []

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
	if g == null:
		print("SYNC BRIDGE TESTS: FAIL (Global autoload missing)")
		quit(1)
		return

	_test_player_parity(g)
	_test_companion_parity(g)
	_test_previously_unmapped(g)
	_test_aliases(g)
	_test_null_uses_declared_default(g)
	_test_party_members_structural(g)
	_test_refuses_bad_input(g)

	if _fails.is_empty():
		print("SYNC BRIDGE TESTS: PASS")
		quit(0)
	else:
		print("SYNC BRIDGE TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)

## Every field the old _set_player_field match covered, same results.
func _test_player_parity(g) -> void:
	var p = PlayerData.new()
	g._set_player_field(p, "Current_Health", 42)
	g._set_player_field(p, "Max_Health", 99)
	g._set_player_field(p, "Burst_Charges", 3)
	g._set_player_field(p, "Shield_Health", 7)
	g._set_player_field(p, "Shield_Duration", 2)
	g._set_player_field(p, "Applied_Element", "Fire")
	g._set_player_field(p, "Skipped", true)
	g._set_player_field(p, "Skip_Duration", 1)
	g._set_player_field(p, "Ready", true)
	g._set_player_field(p, "Element", "Nature")
	g._set_player_field(p, "Level", 12)
	g._set_player_field(p, "Daily_Luck", 77)
	_eq(p.current_health, 42, "player Current_Health")
	_eq(p.max_health, 99, "player Max_Health")
	_eq(p.burst_charges, 3, "player Burst_Charges")
	_eq(p.shield_health, 7, "player Shield_Health")
	_eq(p.shield_duration, 2, "player Shield_Duration")
	_eq(p.applied_element, "Fire", "player Applied_Element")
	_eq(p.skipped, true, "player Skipped")
	_eq(p.skip_duration, 1, "player Skip_Duration")
	_eq(p.ready, true, "player Ready")
	_eq(p.element, "Nature", "player Element")
	_eq(p.level, 12, "player Level")
	_eq(p.daily_luck, 77, "player Daily_Luck")

	# Current_Region carries a side effect onto the Global singleton.
	g._set_player_field(p, "Current_Region", "Inazuma")
	_eq(p.current_region, "Inazuma", "player Current_Region")
	_eq(g.Current_Region, "Inazuma", "Current_Region side effect still fires")

func _test_companion_parity(g) -> void:
	var c = CompanionSaveData.new()
	g._set_companion_field(c, "Current_Health", 55)
	g._set_companion_field(c, "Max_Health", 60)
	g._set_companion_field(c, "Burst_Charges", 2)
	g._set_companion_field(c, "Applied_Element", "Ice")
	g._set_companion_field(c, "Active", true)
	g._set_companion_field(c, "Player_Chosen", true)
	g._set_companion_field(c, "Deceased", true)
	g._set_companion_field(c, "Shield_Health", 4)
	g._set_companion_field(c, "Shield_Duration", 3)
	_eq(c.current_health, 55, "companion Current_Health")
	_eq(c.max_health, 60, "companion Max_Health")
	_eq(c.burst_charges, 2, "companion Burst_Charges")
	_eq(c.applied_element, "Ice", "companion Applied_Element")
	_eq(c.active, true, "companion Active")
	_eq(c.player_chosen, true, "companion Player_Chosen")
	_eq(c.deceased, true, "companion Deceased")
	_eq(c.shield_health, 4, "companion Shield_Health")
	_eq(c.shield_duration, 3, "companion Shield_Duration")

## Fields that the old match statements never handled — these silently drifted.
func _test_previously_unmapped(g) -> void:
	var p = PlayerData.new()
	g._set_player_field(p, "Role", "Support")
	g._set_player_field(p, "Ascension_Rank", 4)
	g._set_player_field(p, "Level_Cap", 30)
	g._set_player_field(p, "Portrait", "amber.png")
	_eq(p.role, "Support", "player Role now bridges (was unmapped)")
	_eq(p.ascension_rank, 4, "player Ascension_Rank now bridges (was unmapped)")
	_eq(p.level_cap, 30, "player Level_Cap now bridges (was unmapped)")
	_eq(p.portrait, "amber.png", "player Portrait now bridges (was unmapped)")

	var c = CompanionSaveData.new()
	g._set_companion_field(c, "Unlocked", true)
	g._set_companion_field(c, "Met", true)
	g._set_companion_field(c, "Owner", "Dylan")
	g._set_companion_field(c, "Region", "Liyue")
	_eq(c.unlocked, true, "companion Unlocked now bridges (was unmapped)")
	_eq(c.met, true, "companion Met now bridges (was unmapped)")
	_eq(c.owner, "Dylan", "companion Owner now bridges (was unmapped)")
	_eq(c.region, "Liyue", "companion Region now bridges (was unmapped)")

	var w = OwnedWeapon.new()
	g._set_owned_weapon_field(w, "Rarity", "5 Star")
	g._set_owned_weapon_field(w, "Stat_1_Value", 12.5)
	_eq(w.rarity, "5 Star", "weapon Rarity now bridges (was unmapped)")
	_eq(w.stat_1_value, 12.5, "weapon Stat_1_Value now bridges (was unmapped)")

	var a = OwnedArtifact.new()
	g._set_owned_artifact_field(a, "Artifact_Set", "Gladiator")
	g._set_owned_artifact_field(a, "Rarity", 5)
	g._set_owned_artifact_field(a, "Stat_2_Value", 3.5)
	_eq(a.artifact_set, "Gladiator", "artifact Artifact_Set now bridges (was unmapped)")
	_eq(a.rarity, 5, "artifact Rarity now bridges (was unmapped)")
	_eq(a.stat_2_value, 3.5, "artifact Stat_2_Value now bridges (was unmapped)")

## Keys whose snake_case form doesn't match the property name.
func _test_aliases(g) -> void:
	var w = OwnedWeapon.new()
	g._set_owned_weapon_field(w, "Weapon", "Wolf's Gravestone")
	g._set_owned_weapon_field(w, "Type", "Claymore")
	_eq(w.weapon_name, "Wolf's Gravestone", "weapon alias Weapon -> weapon_name")
	_eq(w.weapon_type, "Claymore", "weapon alias Type -> weapon_type")

	# Same key, different meaning on an artifact — must NOT use the weapon alias.
	var a = OwnedArtifact.new()
	g._set_owned_artifact_field(a, "Type", "Flower of Life")
	_eq(a.type, "Flower of Life", "artifact Type maps to plain `type`, not weapon_type")

	var e = BattleEnemy.new()
	g._set_battle_enemy_field(e, "AppliedElement", "Electric")
	g._set_battle_enemy_field(e, "EnemyName", "Ruin Guard")
	g._set_battle_enemy_field(e, "Killed", true)
	g._set_battle_enemy_field(e, "Phase", 2)
	_eq(e.applied_element, "Electric", "enemy alias AppliedElement")
	_eq(e.enemy_name, "Ruin Guard", "enemy alias EnemyName")
	_eq(e.killed, true, "enemy Killed")
	_eq(e.phase, 2, "enemy Phase")

## A null update resolves to the resource's DECLARED default, matching what the
## old hand-written fallbacks did.
func _test_null_uses_declared_default(g) -> void:
	var p = PlayerData.new()
	p.applied_element = "Fire"
	g._set_player_field(p, "Applied_Element", null)
	_eq(p.applied_element, "None", "null Applied_Element falls back to 'None'")

	p.daily_luck = 5
	g._set_player_field(p, "Daily_Luck", null)
	_eq(p.daily_luck, 50, "null Daily_Luck falls back to 50")

	var w = OwnedWeapon.new()
	w.quantity = 9
	g._set_owned_weapon_field(w, "Quantity", null)
	_eq(w.quantity, 1, "null weapon Quantity falls back to 1")

	w.owner_type = "Companion"
	g._set_owned_weapon_field(w, "Owner_Type", null)
	_eq(w.owner_type, "Character", "null Owner_Type falls back to 'Character'")

	var e = BattleEnemy.new()
	e.phase = 3
	g._set_battle_enemy_field(e, "Phase", null)
	_eq(e.phase, 1, "null enemy Phase falls back to 1")

## Party_Member_N is a flattened view of PartySaveData.members — the bug that
## started all of this. It must now write through.
func _test_party_members_structural(g) -> void:
	var party = PartySaveData.new()
	g._set_party_field(party, "Party_Member_1", "Brian C.")
	g._set_party_field(party, "Party_Member_2", "Dylan")
	g._set_party_field(party, "Party_Member_3", "COMPANION")
	g._set_party_field(party, "Party_Member_4", "Brian F.")
	_eq(party.members.size(), 3, "COMPANION placeholder excluded from members")
	_check(party.members.has("Brian C."), "Party_Member_1 written into members")
	_check(party.members.has("Dylan"), "Party_Member_2 written into members")
	_check(party.members.has("Brian F."), "Party_Member_4 written into members")
	_check(not party.members.has("COMPANION"), "COMPANION not treated as a member")

	# Scalar party fields still bridge, plus the region side effect.
	g._set_party_field(party, "Mora", 1234)
	g._set_party_field(party, "Current_Turn", "Dylan")
	g._set_party_field(party, "Companion_Limit", 3)
	_eq(party.mora, 1234, "party Mora")
	_eq(party.current_turn, "Dylan", "party Current_Turn")
	_eq(party.companion_limit, 3, "party Companion_Limit now bridges (was unmapped)")
	g._set_party_field(party, "Current_Region", "Fontaine")
	_eq(g.Current_Region, "Fontaine", "party Current_Region side effect still fires")

## The bridge must never invent properties or rewrite primary keys.
func _test_refuses_bad_input(g) -> void:
	var p = PlayerData.new()
	var original_id = p.id
	g._set_player_field(p, "id", 999)
	_eq(p.id, original_id, "id is denied — primary key never rewritten")

	_check(not g._apply_typed_field(p, "Totally_Made_Up_Field", 1),
		"unknown field is refused, not silently set")
	_check(not g._apply_typed_field(null, "Current_Health", 1),
		"null object is refused without crashing")
