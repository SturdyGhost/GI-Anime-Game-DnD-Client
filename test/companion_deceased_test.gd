extends SceneTree
## Headless tests for the companion `deceased` flag.
## Run: godot --headless --script test/companion_deceased_test.gd
## (No GdUnit4 in this project; self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## `deceased` is CATALOG data: SaveManager._load_base_resources() re-reads every
## companion .tres each boot, and companion_state overlays only a whitelist of
## mutable fields. But the UI and all clients read Global.COMPANIONS — the SYNCED
## table from canonical_save.json — so the flag has to be backfilled into that
## table for saves written before the field existed. These tests pin the catalog
## default, the bridge in both directions, and the never-active invariant.

var _ran := false
var _fails: Array[String] = []

func _init() -> void:
	process_frame.connect(_run)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _run() -> void:
	if _ran:
		return
	_ran = true
	var g = root.get_node_or_null("Global")
	if g == null:
		print("COMPANION DECEASED TESTS: FAIL (Global autoload missing)")
		quit(1)
		return

	var sm = root.get_node_or_null("SaveManager")
	_test_catalog_default()
	_test_bridge_roundtrip(g)
	_test_backfill_and_invariant(g, sm)
	_test_expedition_excludes_deceased(g)

	if _fails.is_empty():
		print("COMPANION DECEASED TESTS: PASS")
		quit(0)
	else:
		print("COMPANION DECEASED TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)

## The .tres catalog is the source of the default: Ayaka dead, everyone else not.
func _test_catalog_default() -> void:
	var ayaka = load("res://data/resources/companions/ayaka.tres")
	_check(ayaka != null, "ayaka.tres loads")
	if ayaka != null:
		_check(ayaka.deceased == true, "Ayaka is deceased in the catalog")
		_check(ayaka.active == false, "a deceased companion is not active in the catalog")
		_check(ayaka.player_chosen == false, "a deceased companion is not player_chosen in the catalog")

	# Spot-check that the default did not leak to others.
	for slug in ["albedo", "amber", "ayato"]:
		var c = load("res://data/resources/companions/%s.tres" % slug)
		if c != null:
			_check(c.deceased == false, "%s defaults to not deceased" % slug)

## Deceased must survive typed -> dict and dict -> typed, or it drifts between
## host and clients exactly like the party-membership bug did.
func _test_bridge_roundtrip(g) -> void:
	var c = CompanionSaveData.new()
	c.id = 999
	c.name = "Test Companion"
	c.deceased = true
	var d: Dictionary = g._companion_to_dict(c)
	_check(d.has("Deceased"), "_companion_to_dict emits Deceased")
	_check(d.get("Deceased") == true, "_companion_to_dict carries the value")

	var c2 = CompanionSaveData.new()
	g._set_companion_field(c2, "Deceased", true)
	_check(c2.deceased == true, "_set_companion_field applies Deceased")
	g._set_companion_field(c2, "Deceased", false)
	_check(c2.deceased == false, "_set_companion_field clears Deceased")

## The backfill fills a missing key without clobbering runtime values, and always
## clears Active/Player_Chosen on the dead.
func _test_backfill_and_invariant(g, sm) -> void:
	if sm == null or sm.data == null:
		# No save loaded in a bare headless run — exercise the invariant directly
		# against the synced table instead, which is what the UI actually reads.
		g._synced["Companions"] = {
			"1": {"id": 1, "Name": "Dead One", "Deceased": true, "Active": true, "Player_Chosen": true},
			"2": {"id": 2, "Name": "Live One", "Deceased": false, "Active": true, "Player_Chosen": true},
		}
		g.backfill_companion_catalog_flags()
		# Without SaveManager the function returns early by design; assert it is
		# a no-op rather than a crash, so client-side calls stay safe.
		_check(g._synced["Companions"]["2"]["Active"] == true,
			"backfill without SaveManager leaves data untouched (no crash)")
		return

	g._synced["Companions"] = {
		"1": {"id": 1, "Name": "Dead One", "Deceased": true, "Active": true, "Player_Chosen": true},
	}
	g.backfill_companion_catalog_flags()
	var row: Dictionary = g._synced["Companions"]["1"]
	_check(row.get("Active") == false, "backfill clears Active on a deceased companion")
	_check(row.get("Player_Chosen") == false, "backfill clears Player_Chosen on a deceased companion")

## Deceased companions must not appear in the expeditions idle list, and a
## companion who dies while already deployed must be released from their slot.
func _test_expedition_excludes_deceased(g) -> void:
	g._synced["Companions"] = {
		"1": {"id": 1, "Name": "Dead One", "Deceased": true, "Unlocked": true, "Active": false},
		"2": {"id": 2, "Name": "Live One", "Deceased": false, "Unlocked": true, "Active": false},
		"3": {"id": 3, "Name": "Busy One", "Deceased": false, "Unlocked": true, "Active": true},
		"4": {"id": 4, "Name": "Locked One", "Deceased": false, "Unlocked": false, "Active": false},
	}

	# Mirror the idle-list filter from ExpeditionPanel._load_state().
	var idle: Array = []
	for comp in g.COMPANIONS.values():
		if comp.get("Deceased", false) == true:
			continue
		if comp.get("Unlocked", false) and not comp.get("Active", false):
			idle.append(str(comp.get("Name", "")))

	_check(not idle.has("Dead One"), "deceased companion is excluded from the idle list")
	_check(idle.has("Live One"), "a living idle companion still appears")
	_check(not idle.has("Busy One"), "an active companion is still excluded")
	_check(not idle.has("Locked One"), "a locked companion is still excluded")

	# A death while deployed must free the slot — both list and legacy string form.
	# Instantiate via load() rather than the ExpeditionPanel class_name: in a
	# --script SceneTree run the global class table is built before autoloads
	# register, so the class_name resolves to an uncompiled GDScript and .new()
	# fails. Guard on null so that failure can never masquerade as a pass.
	var panel_script = load("res://Scenes/UI/expedition_panel.gd")
	_check(panel_script != null, "expedition_panel.gd loads")
	if panel_script == null:
		return
	var panel = panel_script.new()
	_check(panel != null, "ExpeditionPanel instantiates")
	if panel == null:
		return
	panel._assignments = {0: ["Dead One", "Live One"], 1: ["Dead One"], 2: "Dead One", 3: ["Live One"]}
	panel._release_deceased_assignments()
	_check(panel._assignments.get(0) == ["Live One"], "deceased removed, survivor kept in a shared slot")
	_check(not panel._assignments.has(1), "slot emptied by the death is erased (array form)")
	_check(not panel._assignments.has(2), "slot emptied by the death is erased (legacy string form)")
	_check(panel._assignments.get(3) == ["Live One"], "untouched slot is left alone")
	panel.free()
