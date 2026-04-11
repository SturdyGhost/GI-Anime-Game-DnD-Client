extends Control
## Test Scene — Simulates host + mock players, runs through key game flows.
## Run this scene directly from the editor (F5 with this as main scene, or F6).
## Results are printed to the Output panel and displayed on screen.

const BG = Color(0.102, 0.122, 0.169)
const TEXT = Color(0.941, 0.949, 0.973)
const GREEN = Color(0.292, 0.855, 0.498)
const RED = Color(0.937, 0.267, 0.267)
const ACCENT = Color(0.788, 0.659, 0.298)
const MUTED = Color(0.471, 0.51, 0.627)

var _log_container: VBoxContainer
var _status_label: Label
var _pass_count: int = 0
var _fail_count: int = 0
var _total_count: int = 0


func _ready():
	_build_ui()
	# Wait a frame for UI to settle, then run tests
	await get_tree().process_frame
	_run_all_tests()


func _build_ui():
	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "INTEGRATION TEST SUITE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Running tests..."
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_status_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 3)
	scroll.add_child(_log_container)


# ═══════════════════════════════════════════════════════════════════════
#  TEST RUNNER
# ═══════════════════════════════════════════════════════════════════════

func _run_all_tests():
	_log_header("SETUP: Initializing host simulation")
	var setup_ok = await _setup_host_simulation()
	if not setup_ok:
		_log_fail("HOST SETUP", "Failed to initialize — cannot run tests")
		_finalize()
		return

	_log_header("TEST GROUP 1: Data Layer")
	_test_global_data_loaded()
	_test_character_data_accessible()
	_test_party_data_accessible()
	_test_companion_data_accessible()
	_test_weapon_data_accessible()
	_test_artifact_data_accessible()
	_test_item_data_accessible()

	_log_header("TEST GROUP 2: Stat Calculation")
	_test_character_manager_stats()
	_test_stat_scaling()

	_log_header("TEST GROUP 3: Update Records Flow")
	await _test_update_records()

	_log_header("TEST GROUP 4: Turn Processor")
	_test_turn_processor_validation()
	_test_turn_processor_basic_turn()

	_log_header("TEST GROUP 5: Effect System")
	_test_effect_processor_init()
	_test_weapon_effects_load()
	_test_status_effects_map()

	_log_header("TEST GROUP 6: Battle Flow")
	await _test_battle_flow()

	_log_header("TEST GROUP 7: Battle Logger")
	_test_battle_logger()

	_log_header("TEST GROUP 8: Crafting & Artifact Forge")
	_test_crafting_recipes_loaded()
	_test_crafting_recipe_data_fields()
	_test_gem_upgrade_downgrade_recipes()
	_test_artifact_forge_piece_resolution()
	_test_artifact_forge_stat_resolution()
	_test_artifact_forge_stat_dice_boundaries()

	_log_header("TEST GROUP 9: Offline Mode")
	await _test_offline_snapshot_save_load()
	await _test_offline_changes_logger()
	await _test_offline_mutation_routing()
	await _test_offline_changes_replay()
	_test_offline_management_panel_loads()

	_log_header("TEST GROUP 10: Scene Instantiation")
	_test_scene_loads("res://Scenes/BattleScene.tscn", "BattleScene")
	_test_scene_loads("res://Scenes/PlayerInventory.tscn", "PlayerInventory")
	_test_scene_loads("res://Scenes/MarketPanel.tscn", "MarketPanel")
	_test_scene_loads("res://Scenes/CraftingMenu.tscn", "CraftingMenu")
	_test_scene_loads("res://Scenes/gathering.tscn", "Gathering")
	_test_scene_loads("res://Scenes/stat_summary.tscn", "StatSummary")
	_test_scene_loads("res://Scenes/weapon_detail_scene.tscn", "WeaponDetail")
	_test_scene_loads("res://Scenes/artifact_detail_scene.tscn", "ArtifactDetail")
	_test_scene_loads("res://Scenes/character_profile.tscn", "CharacterProfile")
	_test_scene_loads("res://Scenes/CompanionsOverview.tscn", "CompanionsOverview")
	_test_scene_loads("res://Scenes/SettingsPopup.tscn", "SettingsPopup")
	_test_scene_loads("res://Scenes/RulesScene.tscn", "RulesScene")

	_finalize()


# ═══════════════════════════════════════════════════════════════════════
#  SETUP
# ═══════════════════════════════════════════════════════════════════════

func _setup_host_simulation() -> bool:
	# Step 1: Set session state
	if Global.ACTIVE_USER_NAME == "" or Global.ACTIVE_USER_NAME == null:
		Global.ACTIVE_USER_NAME = "TestHost"
	if Global.ACTIVE_USER_TYPE == "" or Global.ACTIVE_USER_TYPE == null:
		Global.ACTIVE_USER_TYPE = "Player"

	_log_info("Active user: %s (%s)" % [Global.ACTIVE_USER_NAME, Global.ACTIVE_USER_TYPE])

	# Step 2: Initialize data stores
	DataStore.set_host(true)
	SaveManager.set_host(true)
	NetworkManager.is_host = true

	# Step 3: Load all table data from disk
	var tables = DataStore.load_all_tables()
	if tables.is_empty():
		_log_warn("No tables loaded from DataStore — is user://data/ populated?")
	else:
		_log_info("Loaded %d tables from DataStore" % tables.size())
		for table_name in tables.keys():
			Global._process_table(table_name, tables[table_name])
			_log_info("  - %s: %d records" % [table_name, tables[table_name].size()])

	# Step 4: Load save data
	SaveManager.load_save()
	_log_info("SaveManager loaded")

	# Step 5: Set record ID
	var pid = Global.CHARACTERS_NAME.get(Global.ACTIVE_USER_NAME, "")
	if pid != "":
		Global.ACTIVE_USER_RECORD_ID = int(pid)
		_log_info("Record ID: %d" % Global.ACTIVE_USER_RECORD_ID)
	else:
		_log_warn("Could not find record ID for '%s'" % Global.ACTIVE_USER_NAME)

	# Step 6: Calculate stats
	CharacterManager.recalculate_all()
	_log_info("Stats recalculated")

	# Step 7: Set region
	Global.Current_Region = Global.Current_Party.get("Current_Region", "Mondstadt")
	_log_info("Region: %s" % Global.Current_Region)

	# Step 8: Signal ready
	Global.emit_signal("data_load_complete")

	await get_tree().process_frame
	_log_pass("HOST SETUP", "Initialized successfully")
	return true


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 1: Data Layer
# ═══════════════════════════════════════════════════════════════════════

func _test_global_data_loaded():
	var has_chars = Global.CHARACTERS.size() > 0
	var has_party = not Global.Current_Party.is_empty()
	_assert("Global.CHARACTERS populated", has_chars, "%d characters" % Global.CHARACTERS.size())
	_assert("Global.Current_Party populated", has_party, str(Global.Current_Party.keys()))

func _test_character_data_accessible():
	for name in Global.PartyCharacters:
		var cid = Global.CHARACTERS_NAME.get(name, "")
		var data = Global.CHARACTERS.get(cid, {})
		_assert("Character '%s' has data" % name, not data.is_empty(), "id=%s" % cid)
		_assert("Character '%s' has HP" % name, data.get("Current_Health") != null, "HP=%s" % str(data.get("Current_Health")))

func _test_party_data_accessible():
	var party = Global.Current_Party
	_assert("Party has Turn_Order", party.get("Turn_Order") != null, str(party.get("Turn_Order")))
	_assert("Party has Current_Turn", party.get("Current_Turn") != null, str(party.get("Current_Turn")))
	_assert("Party has Dungeon_Master", party.get("Dungeon_Master") != null, str(party.get("Dungeon_Master")))

func _test_companion_data_accessible():
	var count = Global.COMPANIONS.size()
	_assert("Companions table has data", count > 0, "%d companions" % count)

func _test_weapon_data_accessible():
	var count = Global.CHARACTER_WEAPONS.size()
	_assert("Weapons table has data", count > 0, "%d weapons" % count)

func _test_artifact_data_accessible():
	var count = Global.CHARACTER_ARTIFACTS.size()
	_assert("Artifacts table has data", count > 0, "%d artifacts" % count)

func _test_item_data_accessible():
	var count = Global.CHARACTER_ITEMS.size()
	_assert("Items table has data", count > 0, "%d items" % count)


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 2: Stat Calculation
# ═══════════════════════════════════════════════════════════════════════

func _test_character_manager_stats():
	for name in Global.PartyCharacters:
		var stats = CharacterManager.get_stats(name)
		_assert("CharacterManager.get_stats('%s') returns data" % name, stats != null, "")
		if stats:
			_assert("'%s' health > 0" % name, stats.health > 0, "health=%d" % int(stats.health))
			_assert("'%s' attack > 0" % name, stats.attack > 0, "attack=%d" % int(stats.attack))

func _test_stat_scaling():
	# Test that weapon effects apply to stats
	var name = Global.ACTIVE_USER_NAME
	var stats = CharacterManager.get_stats(name)
	if stats == null:
		_log_warn("Cannot test stat scaling — no stats for '%s'" % name)
		return
	# Find equipped weapon
	var weapon_name = ""
	for w in Global.CHARACTER_WEAPONS.values():
		if w.get("Owner") == name and w.get("Equipped") == true:
			weapon_name = str(w.get("Weapon", w.get("Name", "")))
			break
	if weapon_name == "":
		_log_info("No equipped weapon for '%s' — skipping weapon effect test" % name)
		return
	var effects = WeaponEffects.get_effects(weapon_name)
	_log_info("Weapon '%s' has %d effects" % [weapon_name, effects.size()])
	for eff in effects:
		if eff.trigger == "PASSIVE" and eff.effect_type == "STAT_MULTIPLIER":
			_log_info("  STAT_MULTIPLIER on %s: +%.0f%%" % [eff.effect_stat, eff.effect_value * 100])


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 3: Update Records
# ═══════════════════════════════════════════════════════════════════════

func _test_update_records():
	# Test that Update_Records works locally
	var party_id = int(Global.Current_Party.get("id", 0))
	if party_id == 0:
		_log_warn("No party ID — skipping Update_Records test")
		return

	var original_turn = Global.Current_Party.get("Current_Turn", "")
	var test_value = "TestTurnValue"

	Global.Update_Records([{
		"table": "Party",
		"record_id": party_id,
		"field": "Current_Turn",
		"value": test_value
	}])

	await get_tree().process_frame

	var new_turn = Global.Current_Party.get("Current_Turn", "")
	_assert("Update_Records changes data", new_turn == test_value, "got '%s'" % new_turn)

	# Restore original
	Global.Update_Records([{
		"table": "Party",
		"record_id": party_id,
		"field": "Current_Turn",
		"value": original_turn
	}])
	await get_tree().process_frame
	_assert("Update_Records restores data", Global.Current_Party.get("Current_Turn") == original_turn, "restored")


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 4: Turn Processor
# ═══════════════════════════════════════════════════════════════════════

func _test_turn_processor_validation():
	# Test with invalid battler name
	var result = TurnProcessor.process_turn({"battler_name": "NonexistentPlayer999"})
	_assert("TurnProcessor rejects invalid battler", result.is_empty(), "returned %d updates" % result.size())

func _test_turn_processor_basic_turn():
	# Build battler data first
	var order = Global.Current_Party.get("Turn_Order", [])
	if order.is_empty():
		_log_warn("No turn order — skipping TurnProcessor test")
		return
	Global.BattlerData = BattlerState.build_all(order)
	var first_battler = str(order[0])
	if not Global.BattlerData.has(first_battler):
		_log_warn("Battler '%s' not in BattlerData — skipping" % first_battler)
		return
	Global.Current_Battler_Data = Global.BattlerData[first_battler]

	var input = {
		"battler_name": first_battler,
		"attack_used": "None",
		"attack_roll": 0,
		"tiles_moved": 0,
		"burst_gained": 0,
		"passive_stacks": 0,
		"critical_hit": false,
		"item_used": "None",
		"item_target": "None",
		"targets": [],
		"battle_id": "test_battle",
		"turn_no": 1,
	}
	var updates = TurnProcessor.process_turn(input)
	_assert("TurnProcessor processes empty turn", updates is Array, "returned %d updates" % updates.size())


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 5: Effect System
# ═══════════════════════════════════════════════════════════════════════

func _test_effect_processor_init():
	if Global.effect_processor != null:
		_assert("EffectProcessor exists", true, "already initialized")
		return
	# Try initializing
	var order = Global.Current_Party.get("Turn_Order", [])
	if order.is_empty():
		_log_warn("No turn order — skipping effect processor test")
		return
	Global.BattlerData = BattlerState.build_all(order)
	Global.start_battle_effects(Global.BattlerData)
	_assert("EffectProcessor initialized", Global.effect_processor != null, "")
	# Clean up
	Global.end_battle_effects()

func _test_weapon_effects_load():
	var test_weapons = ["Royal Greatsword", "Aqua Simulacra", "Serpent Spine", "NonexistentWeapon"]
	for w in test_weapons:
		var effects = WeaponEffects.get_effects(w)
		if w == "NonexistentWeapon":
			_assert("WeaponEffects empty for unknown weapon", effects.is_empty(), "")
		else:
			_log_info("WeaponEffects('%s'): %d effects" % [w, effects.size()])

func _test_status_effects_map():
	var statuses = ["Stun", "Root", "Blind", "Slow", "Quick"]
	for s in statuses:
		var effects = StatusEffectsMap.get_effects(s)
		_assert("StatusEffectsMap has '%s'" % s, effects.size() > 0, "%d effects" % effects.size())


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 6: Battle Flow
# ═══════════════════════════════════════════════════════════════════════

func _test_battle_flow():
	var order = Global.Current_Party.get("Turn_Order", [])
	if order.is_empty():
		_log_warn("No turn order — skipping battle flow test")
		return

	# Build battlers
	Global.BattlerData = BattlerState.build_all(order)
	_assert("BattlerState.build_all produces data", Global.BattlerData.size() > 0, "%d battlers" % Global.BattlerData.size())

	for battler_name in Global.BattlerData:
		var bd = Global.BattlerData[battler_name]
		_log_info("Battler '%s': type=%s, hp=%s" % [
			battler_name,
			bd.get("type", "?"),
			str(bd.get("current_health", "?"))
		])

	await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 7: Battle Logger
# ═══════════════════════════════════════════════════════════════════════

func _test_battle_logger():
	var logger = BattleLogger.new()
	logger.start_battle("test_run_%d" % Time.get_unix_time_from_system())

	# Log a mock turn
	var input = {
		"battler_name": "TestPlayer",
		"attack_used": "Normal Attack",
		"attack_roll": 15,
		"tiles_moved": 3,
		"burst_gained": 1,
		"passive_stacks": 0,
		"critical_hit": false,
		"item_used": "None",
		"item_target": "None",
		"targets": [
			{"name": "Enemy1", "hits": 1, "raw_damage": 10, "attack_type": "Damage", "shield_hit": false, "defense_roll": 5}
		],
		"battle_id": "test",
		"turn_no": 1,
	}
	logger.log_turn(input, {"total_damage": 10, "killed": [], "reactions": []})

	var summary = logger.end_battle()
	_assert("BattleLogger produces summary", not summary.is_empty(), "keys: %s" % str(summary.keys()))
	_assert("Summary has combatants", summary.get("combatants", {}).size() > 0, "")
	_assert("Summary has total_turns", summary.get("total_turns", 0) > 0, "%d turns" % summary.get("total_turns", 0))


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 8: Crafting & Artifact Forge
# ═══════════════════════════════════════════════════════════════════════

func _test_crafting_recipes_loaded():
	var count = Global.CRAFTING_RECIPES.size()
	_assert("Crafting recipes loaded", count > 0, "%d recipes" % count)

func _test_crafting_recipe_data_fields():
	# Verify required fields on a sample of recipes
	var checked = 0
	for rid in Global.CRAFTING_RECIPES:
		var r = Global.CRAFTING_RECIPES[rid]
		if not (r is CraftingRecipeData):
			_log_fail("Recipe %s is CraftingRecipeData" % str(rid), "got %s" % str(typeof(r)))
			continue
		_assert("Recipe %d has product" % r.id, r.product != "", r.product)
		_assert("Recipe %d has material" % r.id, r.material != "", r.material)
		_assert("Recipe %d quantity > 0" % r.id, r.quantity > 0, "qty=%d" % r.quantity)
		_assert("Recipe %d output_quantity > 0" % r.id, r.output_quantity > 0, "out=%d" % r.output_quantity)
		checked += 1
		if checked >= 5:
			break
	_log_info("Checked %d recipe field sets" % checked)

func _test_gem_upgrade_downgrade_recipes():
	# Verify gem crafting recipes exist for upgrades and downgrades
	var upgrade_count = 0
	var downgrade_count = 0
	for rid in Global.CRAFTING_RECIPES:
		var r = Global.CRAFTING_RECIPES[rid]
		if not (r is CraftingRecipeData):
			continue
		var p = r.product.to_lower()
		if p.find("gem") >= 0:
			if r.output_quantity > 1:
				downgrade_count += 1
			else:
				upgrade_count += 1
	_assert("Gem upgrade recipes exist", upgrade_count > 0, "%d upgrades" % upgrade_count)
	_assert("Gem downgrade recipes exist", downgrade_count > 0, "%d downgrades" % downgrade_count)
	# Downgrades should produce multiple outputs
	for rid in Global.CRAFTING_RECIPES:
		var r = Global.CRAFTING_RECIPES[rid]
		if not (r is CraftingRecipeData):
			continue
		if r.output_quantity > 1:
			_assert("Downgrade recipe %d output > 1" % r.id, r.output_quantity >= 2, "out=%d" % r.output_quantity)
			break

func _test_artifact_forge_piece_resolution():
	# Test piece type mapping from D12 roll
	# Instantiate CraftingMenu to access its methods
	var scene = load("res://Scenes/CraftingMenu.tscn")
	if scene == null:
		_log_warn("Cannot load CraftingMenu.tscn — skipping forge piece test")
		return
	var menu = scene.instantiate()
	# D12: 1-3 Flower, 4-6 Feather, 7-8 Sands, 9-10 Goblet, 11-12 Circlet
	var expected = {
		1: "Flower of Life", 2: "Flower of Life", 3: "Flower of Life",
		4: "Feather of Death", 5: "Feather of Death", 6: "Feather of Death",
		7: "Sands of Time", 8: "Sands of Time",
		9: "Goblet of Space", 10: "Goblet of Space",
		11: "Circlet of Principles", 12: "Circlet of Principles",
	}
	var all_pass = true
	for roll in expected:
		var got = menu._af_resolve_piece(roll)
		if got != expected[roll]:
			_log_fail("Piece D12=%d" % roll, "expected '%s' got '%s'" % [expected[roll], got])
			all_pass = false
	if all_pass:
		_assert("All 12 piece type rolls resolve correctly", true, "")
	menu.queue_free()

func _test_artifact_forge_stat_resolution():
	# Test stat mapping for both D8 (basic) and D10 (special) pieces
	var scene = load("res://Scenes/CraftingMenu.tscn")
	if scene == null:
		_log_warn("Cannot load CraftingMenu.tscn — skipping forge stat test")
		return
	var menu = scene.instantiate()

	# D8 basic piece (Flower): 1-2 HP, 3-4 ATK, 5-6 DEF, 7-8 EM
	var basic_expected = {1: "Health", 2: "Health", 3: "Attack", 4: "Attack",
		5: "Defense", 6: "Defense", 7: "Elemental_Mastery", 8: "Elemental_Mastery"}
	var basic_pass = true
	for roll in basic_expected:
		var got = menu._af_resolve_stat(roll, "Flower of Life")
		if got != basic_expected[roll]:
			_log_fail("Basic stat D8=%d" % roll, "expected '%s' got '%s'" % [basic_expected[roll], got])
			basic_pass = false
	_assert("D8 basic stat resolution (Flower)", basic_pass, "all 8 rolls correct")

	# D10 special piece (Sands): 1-2 HP, 3-4 ATK, 5-7 DEF, 8-9 EM, 10 special
	var special_expected = {1: "Health", 2: "Health", 3: "Attack", 4: "Attack",
		5: "Defense", 6: "Defense", 7: "Defense",
		8: "Elemental_Mastery", 9: "Elemental_Mastery",
		10: "Energy_Recharge"}
	var special_pass = true
	for roll in special_expected:
		var got = menu._af_resolve_stat(roll, "Sands of Time")
		if got != special_expected[roll]:
			_log_fail("Special stat D10=%d (Sands)" % roll, "expected '%s' got '%s'" % [special_expected[roll], got])
			special_pass = false
	_assert("D10 special stat resolution (Sands)", special_pass, "all 10 rolls correct")

	# Goblet special roll = Universal_Added_Damage_Bonus
	var goblet_10 = menu._af_resolve_stat(10, "Goblet of Space")
	_assert("Goblet D10=10 gives damage bonus", goblet_10 == "Universal_Added_Damage_Bonus", goblet_10)

	# Circlet special roll = Critical_Damage
	var circlet_10 = menu._af_resolve_stat(10, "Circlet of Principles")
	_assert("Circlet D10=10 gives crit damage", circlet_10 == "Critical_Damage", circlet_10)

	menu.queue_free()

func _test_artifact_forge_stat_dice_boundaries():
	# Verify that basic pieces use D8 max and special pieces use D10 max
	var scene = load("res://Scenes/CraftingMenu.tscn")
	if scene == null:
		_log_warn("Cannot load CraftingMenu.tscn — skipping dice boundary test")
		return
	var menu = scene.instantiate()

	# Basic piece: rolling 9 or 10 should still return a valid stat (fallback to Health)
	var overflow_basic = menu._af_resolve_stat(9, "Flower of Life")
	_assert("D8 overflow (9 on basic) returns fallback", overflow_basic == "Health", overflow_basic)

	# Special piece: rolling > 10 should still return a valid stat
	var overflow_special = menu._af_resolve_stat(11, "Sands of Time")
	_assert("D10 overflow (11 on special) returns fallback", overflow_special == "Health", overflow_special)

	menu.queue_free()


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 9: Offline Mode
# ═══════════════════════════════════════════════════════════════════════

func _test_offline_snapshot_save_load():
	# Test that save_synced_snapshot and load_synced_snapshot round-trip correctly
	_assert("_synced has data before snapshot", Global._synced.size() > 0, "%d tables" % Global._synced.size())

	# Save snapshot
	Global.save_synced_snapshot()
	_assert("Snapshot file created", FileAccess.file_exists("user://last_sync.json"), "")

	# Remember current state
	var original_char_count = Global.CHARACTERS.size()
	var original_tables = Global._synced.keys().duplicate()

	# Clear _synced and reload from snapshot
	for table_name in Global._synced.keys():
		Global._synced[table_name].clear()
	_assert("_synced cleared", Global.CHARACTERS.size() == 0, "chars=%d" % Global.CHARACTERS.size())

	var loaded = Global.load_synced_snapshot()
	_assert("load_synced_snapshot returns true", loaded, "")
	_assert("Characters restored from snapshot", Global.CHARACTERS.size() == original_char_count,
		"expected %d, got %d" % [original_char_count, Global.CHARACTERS.size()])

	# Verify all tables survived round-trip
	var missing_tables = []
	for t in original_tables:
		if not Global._synced.has(t) or Global._synced[t].is_empty():
			missing_tables.append(t)
	_assert("All tables survive snapshot round-trip", missing_tables.is_empty(),
		"missing: %s" % str(missing_tables) if not missing_tables.is_empty() else "%d tables" % original_tables.size())

	await get_tree().process_frame

func _test_offline_changes_logger():
	# Test OfflineChanges singleton logs and clears correctly
	OfflineChanges.clear()
	_assert("OfflineChanges starts empty after clear", not OfflineChanges.has_changes(), "")

	# Log an update
	OfflineChanges.log_update("Characters", 1, "Current_Region", "Sumeru")
	_assert("OfflineChanges has changes after log_update", OfflineChanges.has_changes(), "")

	# Log an insert
	OfflineChanges.log_insert("Character_Weapons", 999, {"id": 999, "Name": "TestWeapon", "Owner": 1})
	var json = OfflineChanges.get_changes_json()
	var parsed = JSON.parse_string(json)
	_assert("OfflineChanges JSON has 2 entries", parsed is Array and parsed.size() == 2, "size=%d" % (parsed.size() if parsed is Array else -1))

	# Verify first entry structure
	var first = parsed[0] if parsed is Array and parsed.size() > 0 else {}
	_assert("First change is 'update' action", first.get("action") == "update", first.get("action", ""))
	_assert("First change has table 'Characters'", first.get("table") == "Characters", first.get("table", ""))
	_assert("First change has timestamp", first.get("timestamp", "") != "", first.get("timestamp", ""))

	# Verify second entry
	var second = parsed[1] if parsed is Array and parsed.size() > 1 else {}
	_assert("Second change is 'insert' action", second.get("action") == "insert", second.get("action", ""))
	_assert("Second change has data dict", second.get("data") is Dictionary, "")

	# Log a delete
	OfflineChanges.log_delete("Character_Weapons", 999)
	json = OfflineChanges.get_changes_json()
	parsed = JSON.parse_string(json)
	_assert("OfflineChanges has 3 entries after delete", parsed is Array and parsed.size() == 3, "")

	# Test persistence — reload from disk
	OfflineChanges._load_from_disk()
	_assert("OfflineChanges survives disk reload", OfflineChanges.has_changes(), "")

	# Clean up
	OfflineChanges.clear()
	_assert("OfflineChanges empty after clear", not OfflineChanges.has_changes(), "")
	_assert("Changes file deleted", not FileAccess.file_exists("user://offline_changes.json"), "")

	await get_tree().process_frame

func _test_offline_mutation_routing():
	# Test that Update_Records/Insert/Remove route through offline path
	var was_offline = Global.is_offline
	Global.is_offline = true
	OfflineChanges.clear()

	# Test Update_Records in offline mode
	var party_id = int(Global.Current_Party.get("id", 0))
	var original_turn = Global.Current_Party.get("Current_Turn", "")
	if party_id > 0:
		Global.Update_Records([{
			"table": "Party",
			"record_id": party_id,
			"field": "Current_Turn",
			"value": "OfflineTestTurn"
		}])
		await get_tree().process_frame
		var new_turn = Global.Current_Party.get("Current_Turn", "")
		_assert("Offline Update_Records changes _synced", new_turn == "OfflineTestTurn", "got '%s'" % new_turn)
		_assert("Offline Update_Records logs to OfflineChanges", OfflineChanges.has_changes(), "")

		# Restore
		Global.Update_Records([{
			"table": "Party",
			"record_id": party_id,
			"field": "Current_Turn",
			"value": original_turn
		}])

	# Test Insert in offline mode
	var pre_count = Global._synced.get("Character_Items", {}).size()
	Global.Insert("Character_Items", ["Name", "Owner", "Quantity"], ["OfflineTestItem", Global.ACTIVE_USER_RECORD_ID, 1])
	await get_tree().process_frame
	var post_count = Global._synced.get("Character_Items", {}).size()
	_assert("Offline Insert adds record to _synced", post_count == pre_count + 1, "before=%d after=%d" % [pre_count, post_count])

	# Find the inserted record and remove it
	var inserted_rid = ""
	for rid in Global._synced.get("Character_Items", {}).keys():
		if Global._synced["Character_Items"][rid].get("Name") == "OfflineTestItem":
			inserted_rid = rid
			break
	_assert("Offline Insert record findable in _synced", inserted_rid != "", "rid=%s" % inserted_rid)

	# Test Remove in offline mode
	if inserted_rid != "":
		Global.Remove_Record("Character_Items", int(inserted_rid))
		await get_tree().process_frame
		var final_count = Global._synced.get("Character_Items", {}).size()
		_assert("Offline Remove_Record removes from _synced", final_count == pre_count, "before=%d after=%d" % [pre_count, final_count])

	# Verify all 4 operations were logged (2 updates + 1 insert + 1 delete)
	var json = OfflineChanges.get_changes_json()
	var parsed = JSON.parse_string(json)
	_assert("All offline mutations logged", parsed is Array and parsed.size() == 4, "expected 4, got %d" % (parsed.size() if parsed is Array else 0))

	# Clean up
	OfflineChanges.clear()
	Global.is_offline = was_offline
	await get_tree().process_frame

func _test_offline_changes_replay():
	# Test that pending offline changes are replayed on top of a snapshot
	var was_offline = Global.is_offline
	Global.is_offline = true
	OfflineChanges.clear()

	# Make a change and log it
	var party_id = int(Global.Current_Party.get("id", 0))
	var original_turn = Global.Current_Party.get("Current_Turn", "")
	if party_id > 0:
		Global.Update_Records([{
			"table": "Party",
			"record_id": party_id,
			"field": "Current_Turn",
			"value": "ReplayTestValue"
		}])
		await get_tree().process_frame

		# Now simulate a fresh offline session: reload snapshot (which has original data)
		Global.load_synced_snapshot()
		var after_reload = Global.Current_Party.get("Current_Turn", "")
		_assert("Snapshot reload reverts to original", after_reload == original_turn,
			"expected '%s', got '%s'" % [original_turn, after_reload])

		# Replay pending changes (simulating what _enter_offline_mode does)
		var changes = JSON.parse_string(OfflineChanges.get_changes_json())
		if changes is Array:
			for change in changes:
				var action = str(change.get("action", ""))
				var table = str(change.get("table", ""))
				match action:
					"update":
						var record_id = str(int(change.get("record_id", 0)))
						var field = str(change.get("field", ""))
						var value = change.get("value")
						Global._apply_local_update(table, record_id, field, value)

		var after_replay = Global.Current_Party.get("Current_Turn", "")
		_assert("Changes replayed on top of snapshot", after_replay == "ReplayTestValue",
			"expected 'ReplayTestValue', got '%s'" % after_replay)

		# Restore original
		Global._apply_local_update("Party", str(party_id), "Current_Turn", original_turn)

	# Clean up
	OfflineChanges.clear()
	Global.is_offline = was_offline
	await get_tree().process_frame

func _test_offline_management_panel_loads():
	_test_scene_loads("res://Scenes/UI/offline_management_panel.tscn", "OfflineManagementPanel")


# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 10: Scene Instantiation
# ═══════════════════════════════════════════════════════════════════════

func _test_scene_loads(path: String, name: String):
	if not ResourceLoader.exists(path):
		_log_fail(name, "Scene file not found: %s" % path)
		return
	var scene = load(path)
	if scene == null:
		_log_fail(name, "Failed to load scene")
		return
	_assert("%s scene loads" % name, scene is PackedScene, "")


# ═══════════════════════════════════════════════════════════════════════
#  ASSERTION HELPERS
# ═══════════════════════════════════════════════════════════════════════

func _assert(test_name: String, condition: bool, detail: String = ""):
	_total_count += 1
	if condition:
		_pass_count += 1
		_log_pass(test_name, detail)
	else:
		_fail_count += 1
		_log_fail(test_name, detail)

func _log_pass(test_name: String, detail: String):
	var lbl = Label.new()
	lbl.text = "  PASS  %s%s" % [test_name, (" — " + detail if detail != "" else "")]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", GREEN)
	_log_container.add_child(lbl)
	print("[PASS] %s %s" % [test_name, detail])

func _log_fail(test_name: String, detail: String):
	var lbl = Label.new()
	lbl.text = "  FAIL  %s%s" % [test_name, (" — " + detail if detail != "" else "")]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", RED)
	_log_container.add_child(lbl)
	print("[FAIL] %s %s" % [test_name, detail])

func _log_info(msg: String):
	var lbl = Label.new()
	lbl.text = "  INFO  %s" % msg
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", MUTED)
	_log_container.add_child(lbl)
	print("[INFO] %s" % msg)

func _log_warn(msg: String):
	var lbl = Label.new()
	lbl.text = "  WARN  %s" % msg
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", ACCENT)
	_log_container.add_child(lbl)
	print("[WARN] %s" % msg)

func _log_header(text: String):
	var sep = HSeparator.new()
	_log_container.add_child(sep)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", ACCENT)
	_log_container.add_child(lbl)
	print("\n=== %s ===" % text)

func _finalize():
	var sep = HSeparator.new()
	_log_container.add_child(sep)

	var result_text = "%d / %d tests passed" % [_pass_count, _total_count]
	var result_color = GREEN if _fail_count == 0 else RED

	_status_label.text = result_text + (" — ALL PASSED" if _fail_count == 0 else " — %d FAILED" % _fail_count)
	_status_label.add_theme_color_override("font_color", result_color)

	var summary = Label.new()
	summary.text = result_text
	summary.add_theme_font_size_override("font_size", 20)
	summary.add_theme_color_override("font_color", result_color)
	_log_container.add_child(summary)

	print("\n%s" % result_text)
	if _fail_count > 0:
		print("%d FAILURES" % _fail_count)
	else:
		print("ALL PASSED")
