## ============================================================================
## GLOBAL.GD - CORE GAME STATE & DATA MANAGEMENT SINGLETON
## ============================================================================
## 
## PURPOSE:
##   Central hub for all game state, data management, synchronization, and
##   stat calculations. Handles player session, character data, database sync,
##   battle management, and logging.
##
## KEY SYSTEMS:
##   1. User Session Management (login, active user, permissions)
##   2. Game Data Storage (characters, weapons, artifacts, etc.)
##   3. Real-time Data Sync (polling, refresh, updates)
##   4. Stat Calculation (CRITICAL: order matters!)
##   5. Battle State Management
##   6. Equipment Management (equip/unequip artifacts, weapons)
##   7. Logging & Telemetry
##
## CRITICAL INVARIANTS (DO NOT BREAK):
##   ⚠️  #1: Stat calculation order MATTERS (see calculate_all_stats)
##   ⚠️  #2: ALWAYS call calculate_all_stats() after equipping items
##   ⚠️  #3: ACTIVE_USER_NAME MUST be set before stat access (was #4)
##
## ============================================================================

extends Node

# ===========================================================================
# LOGGING CONFIGURATION
# ===========================================================================

# ===========================================================================
# SECTION 1: USER SESSION DATA
# ===========================================================================

## Email of currently logged-in player
var ACTIVE_USER_EMAIL: String = ""

## Name of currently logged-in player (MUST be set before accessing stats!)
var ACTIVE_USER_NAME: String = ""

## User type: "Player" or "DM" (determines permissions and calculations)
var ACTIVE_USER_TYPE: String = ""

## Database record ID for this user
var ACTIVE_USER_RECORD_ID: float

## All table names in the game database
var TABLES: Array = ["Artifacts","Reactions","Weapons","Abilities","Companions","Crafting_Recipes","Items","Enemies","Characters","BattleEnemies","Character_Items","Character_Weapons", "Character_Artifacts","Talents","Constellations","Material_Caches","Party","Active_Abilities","Active_Status_Effects","Status_Effects","Game_Config","Minigames","Minigames_Results"]

var joined = ",".join(TABLES)

# ===========================================================================
# SECTION 2: GAME DATA DICTIONARIES (All loaded from NocoDB backend)
# ===========================================================================

## Artifact data (bonuses, sets, types)
var ARTIFACTS: Dictionary = {}

## Elemental reaction definitions
var REACTIONS: Dictionary = {}

## Weapon data (names, stats, bonuses, refinements)
var WEAPONS: Dictionary = {}

## Ability/skill data (damage, cost, effects)
var ABILITIES: Dictionary = {}

## Companion/teammate data
var COMPANIONS: Dictionary = {}

## Crafting recipe definitions
var CRAFTING_RECIPES: Dictionary = {}

## Consumable items, materials, etc.
var ITEMS: Dictionary = {}

## Enemy definitions (HP, stats, abilities)
var ENEMIES: Dictionary = {}

## Old attack data (legacy, may be unused)
var ATTACKS: Dictionary = {}

## Main character data (players control these)
var CHARACTERS: Dictionary = {}

## Battle-specific enemy instances (characters in active battle)
var BATTLEENEMIES: Dictionary = {}

## Battle turn sequence
var BATTLE_TURNS: Array = []

## Items owned by a character (inventory)
var CHARACTER_ITEMS: Dictionary = {}

## Weapons owned by a character
var CHARACTER_WEAPONS: Dictionary = {}

## Artifacts owned by a character (with equip status)
var CHARACTER_ARTIFACTS: Dictionary = {}

## Game configuration (settings, balancing parameters)
var GAME_CONFIG: Dictionary

## Status effects (buffs, debuffs, conditions)
var STATUS_EFFECTS = {}

## Actively applied abilities in battle
var ACTIVE_ABILITIES: Dictionary = {}

## Actively applied status effects
var ACTIVE_STATUS_EFFECTS: Dictionary = {}

## Party information (members, turn order, current state)
var PARTY: Dictionary = {}

## Talent/constellation data for progression
var TALENTS = {}

## Constellation unlock data
var CONSTELLATIONS = {}

## Historical battle log entries
var BATTLE_LOG: Dictionary = {}

## Minigame definitions and state
var MINIGAMES: Dictionary = {}

## Minigame results/scores
var MINIGAMES_RESULTS: Dictionary = {}

# ===========================================================================
# SECTION 3: NAME LOOKUP DICTIONARIES (Fast O(1) lookups by name)
# ===========================================================================

## Maps artifact name -> id for quick lookup
var ARTIFACTS_NAME = {}

## Maps weapon name -> id
var WEAPONS_NAME = {}

## Maps companion name -> id
var COMPANIONS_NAME = {}

## Maps recipe name -> id
var CRAFTINGRECIPES_NAME = {}

## Material cache data
var MATERIAL_CACHES = {}

## Maps item name -> id
var ITEMS_NAME = {}

## Maps enemy name -> id
var ENEMIES_NAME = {}

## Maps character name -> id
var CHARACTERS_NAME = {}

## Maps battle enemy name -> id
var BATTLEENEMIES_NAME = {}

# ===========================================================================
# SECTION 4: DATA SYNC CONFIGURATION
# ===========================================================================

## Tables to persist when saving (call manual re-sync after save)
var TABLES_TO_SAVE = ["Characters","BattleEnemies","Character Items","Character_Weapons", "Character_Artifacts", "Companions"]

## Tables to refresh frequently during battles (more responsive)
var TABLES_TO_SYNC_OFTEN = ["Characters","BattleEnemies","Companions"]

## Tables watched by polling system
var watched_tables := [
	"Characters",
	"Character_Items",
	"Character_Weapons",
	"Character_Artifacts",
	"Talents",
	"Constellations",
	"BattleEnemies",
	"Party",
	"Companions",
	"Active_Status_Effects"
]

## Last known server timestamps (prevents redundant refreshes)
var last_known_timestamps := {}

## Pending timestamps to commit after successful refresh
var pending_timestamps: Dictionary = {}

## Per-field timestamp tracking (prevents stale field overwrites)
var last_local_field_touch_ms: Dictionary = {}

## Timestamp tracking for stale data prevention
const STALE_GUARD_MS: int = 2000

## Local write timestamps per table (prevents race conditions)
var last_local_write_ms: Dictionary = {}

## Artifact bonuses applied (for debugging)
var APPLIED_ARTIFACT_BONUSES := {}

## Final calculated stats per character (for debugging)
var FINAL_CHARACTER_STATS := {}

## Cached list of bonus field names
var known_bonus_fields = []

# ===========================================================================
# SECTION 5: BATTLE STATE
# ===========================================================================

## Turn order for current battle
var BATTLE_TURN_ORDER = []

## List of enemy names in current battle
var EnemyList = []

## Participants fighting (players + enemies)
var BATTLE_PARTICIPANTS = []

## Active party record data
var Current_Party

## Battle data per participant
var BattlerData = {}

## Current turn's actor battle data
var Current_Battler_Data

# ===========================================================================
# SECTION 6: ARTIFACT & EQUIPMENT MANAGEMENT
# ===========================================================================

## Count of equipped pieces per artifact set
## Used to check if set bonuses trigger (need 2+ pieces minimum)
var set_count = {}

## Artifact pieces tracker
var set_pieces

## Set modifier calculations
var set_modifiers := {}

## Calculation state flag
var artifact_set_calculated = 0

# ===========================================================================
# SECTION 7: CHARACTER STATS (Updated by calculate_all_stats)
# These are FINAL calculated values shown to the player
# ===========================================================================

## Final health after all bonuses applied
var Current_Health

## Final attack after all bonuses applied
var Current_Attack

## Final defense after all bonuses applied
var Current_Defense

## Final elemental mastery (affects reaction damage)
var Current_Elemental_Mastery

## Final energy recharge (affects ultimate charge speed)
var Current_Energy_Recharge

## Final critical damage (damage multiplier when crit)
var Current_Critical_Damage

## Currently equipped weapon (set during stat calc)
var Current_Weapon

# ===========================================================================
# SECTION 8: REGION & LOCATION TRACKING
# ===========================================================================

## Internal storage for Current_Region property
var _current_region = ""

## Get/set region with automatic change detection
var Current_Region:
	get:
		return _current_region
	set(value):
		if _current_region != value:
			print("[GLOBAL] 🗺️  Region changed from '%s' to '%s'" % [_current_region, value])
			_current_region = value
			# This flag triggers on region change
			Region_Changed = 1

## Flag indicating region just changed (1=yes, 0=no)
var Region_Changed = 1

# ===========================================================================
# SECTION 9: HTTP MANAGEMENT
# ===========================================================================
## Note: Real-time sync is handled by WSClient singleton (WebSocket).

## Base URL for all API calls
const API_BASE: String = "https://api.mydndbackend.party"

## Stat scaling multipliers (affects final stat calculation)
## Health is 2.0 because we want it to be impactful
var scaling = {
	"Health": 2.0,
	"Attack": 1.0,
	"Defense": 1.0,
	"Elemental_Mastery": 1.0,
	"Energy_Recharge": 0.1,
	"Critical_Damage": 0.1,
}

# ===========================================================================
# SECTION 9B: ELEMENT / REGION UNLOCK SYSTEM
# ===========================================================================

## Element order matching the ElementButton dropdown (indices 0-6)
const ELEMENT_ORDER = ["Wind", "Earth", "Electric", "Nature", "Water", "Fire", "Ice"]

## Kit element order for talents/abilities (includes Nod Krai at index 7)
const KIT_ELEMENT_ORDER = ["Wind", "Earth", "Electric", "Nature", "Water", "Fire", "Ice", "Nod Krai"]

## Region order matching the RegionButton dropdown (indices 0-6)
const REGION_ORDER = ["Mondstadt", "Liyue", "Inazuma", "Sumeru", "Fontaine", "Natlan", "Nod Krai"]

## Element UI colors (hex values for tab/button coloring)
const ELEMENT_COLORS = {
	"Wind": Color("b4fcd4"),
	"Earth": Color("f4d563"),
	"Electric": Color("d092fc"),
	"Nature": Color("b1ea29"),
	"Water": Color("00c0fe"),
	"Fire": Color("ffa971"),
	"Ice": Color("ccffff"),
	"Nod Krai": Color("252525"),
}

## Constellation tier colors
const TIER_COLORS = {
	"Weak": Color("e0e0e0"),
	"Medium": Color("4374b6"),
	"Strong": Color("fdd22e"),
}

## Maps Ascension_Material values to base element
## Update this dict if DB uses different material names
const ASCENSION_MATERIAL_MAP = {
	"Wind": "Wind",
	"Earth": "Earth",
	"Electric": "Electric",
	"Nature": "Nature",
	"Water": "Water",
	"Fire": "Fire",
	"Ice": "Ice",
	"Nod Krai": "Nod Krai",
	"Vayuda Turquoise": "Wind",
	"Prithiva Topaz": "Earth",
	"Vajrada Amethyst": "Electric",
	"Nagadus Emerald": "Nature",
	"Varunada Lazurite": "Water",
	"Agnidus Agate": "Fire",
	"Shivada Jade": "Ice",
}

## Determine the base element from a character's Ascension_Material
func get_base_element(material: String) -> String:
	if ASCENSION_MATERIAL_MAP.has(material):
		return ASCENSION_MATERIAL_MAP[material]
	for element in KIT_ELEMENT_ORDER:
		if material.to_lower().contains(element.to_lower()):
			return element
	return ""

## Get list of unlocked elements for the active user
## Unlocked = indices 0..Ascension_Rank + base element
func get_unlocked_elements() -> Array:
	var rid = CHARACTERS_NAME.get(ACTIVE_USER_NAME)
	if rid == null:
		return KIT_ELEMENT_ORDER.duplicate()
	var char_data = CHARACTERS.get(rid, {})
	var rank = int(char_data.get("Ascension_Rank", 0))
	var material = str(char_data.get("Ascension_Material", ""))
	var base_el = get_base_element(material)
	var unlocked: Array = []
	for i in range(min(rank + 1, KIT_ELEMENT_ORDER.size())):
		unlocked.append(KIT_ELEMENT_ORDER[i])
	if base_el != "" and base_el not in unlocked:
		unlocked.append(base_el)
	return unlocked

## Get list of unlocked regions for the active user
## Unlocked = indices 0..Ascension_Rank (no base region)
func get_unlocked_regions() -> Array:
	var rid = CHARACTERS_NAME.get(ACTIVE_USER_NAME)
	if rid == null:
		return REGION_ORDER.duplicate()
	var char_data = CHARACTERS.get(rid, {})
	var rank = int(char_data.get("Ascension_Rank", 0))
	var unlocked: Array = []
	for i in range(min(rank + 1, REGION_ORDER.size())):
		unlocked.append(REGION_ORDER[i])
	return unlocked

# ===========================================================================
# SECTION 10: UTILITY DATA & TIMING
# ===========================================================================

## Party member characters
var PartyCharacters = []

## Party member companions
var PartyCompanions = []

## Flag: daily luck bonus applied
var Luck_Set = false

## Calculated average party health
var AverageHealth : int

## Total records loaded in last refresh
var total_records

## Temporary variable for dynamic stat access
var variable_name

## HTTP request start time
var request_start_time

## Elapsed time for last request
var elapsed

## Public IP address (for logging)
var PublicIP

# ===========================================================================
# SECTION 11: SIGNALS
# ===========================================================================

## Emitted when a table finishes loading
signal table_loaded(table_name: String, records_loaded: int)

## Emitted when all data finishes loading
signal data_load_complete

## Emitted when an insert operation completes
signal insert_finished(correlation_id: String, table: String, record_id: int, payload: Dictionary, ok: bool)

## Tracking for insert correlation IDs
var _next_insert_corr_id: String = ""

## Whether the initial full data dump has been saved
var _initial_dump_done: bool = false

# ===========================================================================
# SECTION 12: HELPER - CORRELATION ID TRACKING
# ===========================================================================

## Set the correlation ID for the next insert operation
func set_next_correlation_id(id_value: String) -> void:
	print("[GLOBAL] 🔗 set_next_correlation_id() - ID: ", id_value)
	_next_insert_corr_id = id_value

# ===========================================================================
# SECTION 13: HELPER - FILENAME NORMALIZATION
# ===========================================================================

## Removes hidden Unicode characters from filenames
## These can appear when downloading files online and break asset loading
##
## Example: "Weapon Name" (with invisible char) → "weapon-name.png"
func normalize_text_filename(weapon_name: String) -> String:
	print("[GLOBAL] 🧹 normalize_text_filename() - input: ", weapon_name)
	var cleaned := weapon_name.strip_edges().to_lower()
	
	# Handle known invisible/Unicode-breaking characters
	cleaned = cleaned.replace(" ", " ")  # U+00A0 non-breaking space
	cleaned = cleaned.replace("­", "")   # U+00AD soft hyphen
	cleaned = cleaned.replace("'", "")   # curly apostrophe
	cleaned = cleaned.replace(" ", "-")
	
	# Compile a regex to remove any non a–z, 0–9, or dash
	var regex := RegEx.new()
	regex.compile("[^a-z0-9-]")
	cleaned = regex.sub(cleaned, "", true)
	
	var result = cleaned + ".png"
	print("[GLOBAL] ✅ Normalized to: ", result)
	return result

# ===========================================================================
# SECTION 14: STAT CALCULATION - MOST CRITICAL FUNCTION
# ===========================================================================

## CALCULATES ALL STATS FOR ACTIVE_USER_NAME
## 
## MUST be called after:
##   - Equipping/unequipping artifacts
##   - Equipping/unequipping weapons
##   - DM manually editing stat overrides
##   - Loading character data
##
## Updates: Current_Health, Current_Attack, Current_Defense, etc.
##
## STAT CALCULATION ORDER (DO NOT CHANGE - ORDER MATTERS):
##   1. Base Points + Skill Points → scaled by stat multiplier
##   2. Artifact SET bonuses (only if 2+ pieces + condition met)
##   3. Weapon bonuses
##   4. Final multiplier applied to everything
##
## Why order matters: (100 base + 50 bonus) * 1.2 multiplier = 180
##                vs (100 base * 1.2) + 50 bonus = 170 (DIFFERENT!)
func calculate_all_stats() -> void:
	print("[GLOBAL] 📊 ====== calculate_all_stats() STARTING ======")
	
	# Validate that ACTIVE_USER_NAME is set
	if ACTIVE_USER_NAME.is_empty():
		push_error("[GLOBAL] ❌ calculate_all_stats() - ACTIVE_USER_NAME is empty!")
		return
	
	print("[GLOBAL] 👤 Calculating stats for player: ", ACTIVE_USER_NAME)
	
	# Get character ID from name lookup
	if not CHARACTERS_NAME.has(ACTIVE_USER_NAME):
		push_error("[GLOBAL] ❌ ACTIVE_USER_NAME not found in CHARACTERS_NAME")
		push_error("[GLOBAL]    Available: ", CHARACTERS_NAME.keys())
		return
	
	var ACTIVE_CHARACTER_ID = CHARACTERS_NAME[ACTIVE_USER_NAME]
	print("[GLOBAL] 🔍 Found character ID: ", ACTIVE_CHARACTER_ID)
	
	# Get character record
	if not CHARACTERS.has(ACTIVE_CHARACTER_ID):
		push_error("[GLOBAL] ❌ Character ID not found in CHARACTERS dict")
		return
	
	var character = CHARACTERS[ACTIVE_CHARACTER_ID]
	print("[GLOBAL] ✅ Loaded character: ", character.get("Name", "Unknown"))
	
	# Get current region
	Current_Region = character.get("Current_Region", "Unknown")
	print("[GLOBAL] 🗺️  Region: ", Current_Region)
	
	# All possible bonus suffixes for stat calculations
	var bonus_suffixes = [
		"Added_Stat_Bonus",
		"Multiplier_Stat_Bonus",
		"Added_Roll_Bonus",
		"Multiplier_Roll_Bonus",
		"Added_Damage_Bonus",
		"Multiplier_Damage_Bonus",
		"Manual_Added_Amount_Override",
		"Manual_Multiplier_Amount_Override",
		"Manual_Roll_Added_Amount_Override",
		"Manual_Roll_Multiplier_Amount_Override",
		"Manual_Damage_Added_Amount_Override",
		"Manual_Damage_Multiplier_Amount_Override"
	]
	
	# ========== STEP 1: Reset artifact bonuses to 0 ==========
	print("[GLOBAL] 🔄 STEP 1: Resetting old artifact bonuses...")
	if known_bonus_fields.size() == 0:
		for stat in scaling.keys():
			for suffix in bonus_suffixes:
				known_bonus_fields.append("%s_%s" % [stat, suffix])
		print("[GLOBAL]   ✅ Built list of %d bonus fields" % known_bonus_fields.size())
	
	for bonus_field in known_bonus_fields:
		if not bonus_field.contains("Manual"):
			character[bonus_field] = 0
	print("[GLOBAL] ✅ STEP 1 complete - bonuses reset")
	
	# ========== STEP 2: Count equipped artifact pieces per set ==========
	print("[GLOBAL] 🔄 STEP 2: Counting equipped artifact pieces...")
	var set_pieces = {}
	for key in set_count:
		set_count[key] = 0
	
	var equipped_count = 0
	for artifact in CHARACTER_ARTIFACTS.values():
		if artifact.get("Owner") == ACTIVE_USER_NAME and artifact.get("Equipped") == true:
			var set_name = artifact.get("Artifact_Set", "Unknown")
			set_pieces[set_name] = set_pieces.get(set_name, 0) + 1
			set_count[set_name] = set_count.get(set_name, 0) + 1
			equipped_count += 1
			print("[GLOBAL]   - %s from set '%s'" % [artifact.get("Type", "?"), set_name])
	
	print("[GLOBAL]   Total equipped: %d artifacts" % equipped_count)
	for set_name in set_count.keys():
		if set_count[set_name] > 0:
			print("[GLOBAL]   Set count: %s = %d pieces" % [set_name, set_count[set_name]])
	print("[GLOBAL] ✅ STEP 2 complete")
	
	# ========== STEP 3: Apply artifact set bonuses ==========
	print("[GLOBAL] 🔄 STEP 3: Applying artifact SET bonuses...")
	var sets_applied = 0
	for artifact_set in set_pieces.keys():
		for DBset in ARTIFACTS.values():
			if artifact_set == DBset.get("Artifact_Set") and set_pieces[artifact_set] >= DBset.get("Bonus_Type", 999):
				var stat = DBset.get("Stat_Modifier")
				var value = DBset.get("Stat_Modifier_Value")
				var condition = DBset.get("Condition")
				var condition_val = DBset.get("Condition_Value")
				
				if stat == null or stat == "":
					continue  # Skip sets that don't modify a stat
				
				# Check if condition is met (e.g., "Element" == "Pyro")
				var meets_condition = true
				if condition != null and condition != "":
					var char_value = character.get(condition)
					meets_condition = char_value == condition_val
				
				if meets_condition:
					character[stat] = character.get(stat, 0) + value
					sets_applied += 1
					print("[GLOBAL]   ✅ %s (%d pieces): +%d to %s" % [artifact_set, set_pieces[artifact_set], value, stat])
				else:
					print("[GLOBAL]   ⚠️  %s condition not met: %s != %s" % [artifact_set, character.get(condition), condition_val])
	print("[GLOBAL] ✅ STEP 3 complete - applied %d set bonuses" % sets_applied)
	
	# ========== STEP 3B: Apply weapon bonuses ==========
	print("[GLOBAL] 🔄 STEP 3B: Applying weapon bonuses...")
	var weapons_applied = 0
	for weapon in CHARACTER_WEAPONS.values():
		if weapon.get("Owner") == ACTIVE_USER_NAME and weapon.get("Equipped") == true:
			if not WEAPONS_NAME.has(weapon.get("Weapon", "")):
				print("[GLOBAL]   ⚠️  Weapon not found: %s" % weapon.get("Weapon"))
				continue
			
			var weapon_data = WEAPONS[WEAPONS_NAME[weapon.get("Weapon")]]
			if weapon_data.get("Stat_Modifier") != null:
				var stat = weapon_data.get("Stat_Modifier")
				var value = weapon_data.get("Stat_Modifier_Value")
				character[stat] = character.get(stat, 0) + value
				weapons_applied += 1
				print("[GLOBAL]   ✅ %s: +%d %s" % [weapon.get("Weapon"), value, stat])
	print("[GLOBAL] ✅ STEP 3B complete - applied %d weapon bonuses" % weapons_applied)
	
	# ========== STEP 4: Calculate final stat values ==========
	print("[GLOBAL] 🔄 STEP 4: Calculating final stat values...")
	for stat in scaling.keys():
		var base = character.get("%s_Base_Points" % stat, 0)
		var skill = character.get("%s_Skill_Points" % stat, 0)
		var added = character.get("%s_Added_Stat_Bonus" % stat, 0)
		var multiplier = character.get("%s_Multiplier_Stat_Bonus" % stat, 0.0)
		var AddEdit = character.get("%s_Manual_Added_Amount_Override" % stat, 0)
		var MultEdit = character.get("%s_Manual_Multiplier_Amount_Override" % stat, 0.0)
		var uadded = character.get("Universal_Added_Stat_Bonus", 0)
		var umultiplier = character.get("Universal_Multiplier_Stat_Bonus", 0.0)
		
		# Formula: ((base + skill) * scaling) + added + manual + universal
		var value = (((base + skill) * scaling[stat]) + added + AddEdit + uadded)
		
		# Apply weapon bonuses to this specific stat
		for weapon in CHARACTER_WEAPONS.values():
			if weapon.get("Owner") == ACTIVE_USER_NAME and weapon.get("Equipped") == true:
				Global.Current_Weapon = weapon
				for i in range(1, 4):
					if weapon.get("Stat_%d_Type" % i) == stat:
						value += weapon.get("Stat_%d_Value" % i, 0)
		
		# Apply artifact bonuses to this specific stat
		for artifact in CHARACTER_ARTIFACTS.values():
			if artifact.get("Owner") == ACTIVE_USER_NAME and artifact.get("Equipped") == true:
				for i in range(1, 3):
					if artifact.get("Stat_%d_Type" % i) == stat:
						value += artifact.get("Stat_%d_Value" % i, 0)
		
		# Apply final multiplier: all multipliers stack multiplicatively
		value *= (multiplier + MultEdit + umultiplier + 1.0)
		
		# Store in class variable for UI to read
		variable_name = stat.replace(" ", "_")
		Global.set("Current_%s" % variable_name, snapped(value, 0.01))
		print("[GLOBAL]   📈 %s = %.2f (base:%d + skill:%d → scaled → + bonuses → * %.2f)" % [stat, value, base, skill, multiplier + MultEdit + umultiplier + 1.0])
	
	print("[GLOBAL] ✅ STEP 4 complete")
	print("[GLOBAL] 📊 ====== FINAL STATS ======")
	print("[GLOBAL]    Health:     %.0f" % Current_Health)
	print("[GLOBAL]    Attack:     %.2f" % Current_Attack)
	print("[GLOBAL]    Defense:    %.2f" % Current_Defense)
	print("[GLOBAL]    E.Mastery:  %.2f" % Current_Elemental_Mastery)
	print("[GLOBAL]    E.Recharge: %.2f" % Current_Energy_Recharge)
	print("[GLOBAL]    Crit Dmg:   %.2f" % Current_Critical_Damage)
	print("[GLOBAL] ✅ ====== calculate_all_stats() COMPLETE ======")

# ===========================================================================
# SECTION 15: POLLING + TIMESTAMP UTILITIES
# ===========================================================================

## Mark that we just wrote to a field locally (prevents stale overwrites)
func note_local_field_write(record_id: String, field: String) -> void:
	print("[GLOBAL] ⏱️  Marked field write: %s.%s at %.0fms" % [record_id, field, Time.get_ticks_msec()])
	last_local_field_touch_ms["%s|%s" % [record_id, field]] = Time.get_ticks_msec()

## Check if enough time has passed to accept a field from server
func _should_accept_field(record_id: String, field: String) -> bool:
	var key := "%s|%s" % [record_id, field]
	var t := int(last_local_field_touch_ms.get(key, 0))
	var should_accept = t == 0 or (Time.get_ticks_msec() - t) >= STALE_GUARD_MS
	if not should_accept:
		var age_ms = Time.get_ticks_msec() - t
		print("[GLOBAL] ⏱️  Field too fresh (age: %dms < guard: %dms), rejecting" % [age_ms, STALE_GUARD_MS])
	return should_accept

## Merge incoming fields only if they're not too fresh (prevents stale overwrites)
func _merge_fields(target: Dictionary, rec_id: String, incoming: Dictionary) -> void:
	print("[GLOBAL] 🔀 Merging fields for record %s" % rec_id)
	for f in incoming.keys():
		if _should_accept_field(rec_id, String(f)):
			target[String(f)] = incoming[f]
			print("[GLOBAL]   ✅ Accepted: %s" % f)
		else:
			print("[GLOBAL]   ⏭️  Skipped (too fresh): %s" % f)

## Convert ISO 8601 timestamp string to Unix milliseconds
func _iso_to_unix_ms(iso: String) -> int:
	if iso == null or iso == "" or iso == "null":
		return 0
	# Let Godot parse to a datetime dict (treat as UTC once normalized)
	var dt := Time.get_datetime_dict_from_datetime_string(iso, true)
	return int(Time.get_unix_time_from_datetime_dict(dt) * 1000.0)

# ===========================================================================
# SECTION 16: CHECK FOR MODIFIED TABLES (Polling)
# ===========================================================================

## Wait and then refresh a deferred table
func _schedule_delayed_refresh(table_name: String, new_ts: String, wait_ms: int) -> void:
	print("[GLOBAL] ⏳ Scheduling delayed refresh for '%s' in %dms..." % [table_name, wait_ms])
	pending_timestamps[table_name] = new_ts
	var timer: SceneTreeTimer = get_tree().create_timer(float(wait_ms) / 1000.0)
	await timer.timeout
	print("[GLOBAL] ✅ Delayed refresh ready for '%s'" % table_name)
	Global.Refresh_Data([table_name])

# ===========================================================================
# SECTION 17: REFRESH DATA (Main sync function)
# ===========================================================================

## Fetch latest data from backend for specified tables
## This is the main way to pull data from the database
func Refresh_Data(table_list: Array) -> void:
	print("[GLOBAL] 📥 ====== Refresh_Data() START ======")
	
	if table_list.is_empty():
		print("[GLOBAL] ❌ Refresh_Data called with empty table list")
		push_error("Refresh_Data called with an empty table list.")
		return
	
	print("[GLOBAL] 📋 Refreshing tables: %s" % str(table_list))
	
	# Ensure everything is a string first
	var names: PackedStringArray = []
	for t in table_list:
		names.append(str(t))
	
	var joined_tables: String = ",".join(names)
	
	# URL-encode both params (safer even if you have underscores)
	var url: String = "%s/get_all_tables?email=%s&tables=%s" % [
		API_BASE,
		ACTIVE_USER_EMAIL.uri_encode(),
		joined_tables.uri_encode()
	]
	
	var http := HTTPRequest.new()
	add_child(http)
	http.set_meta("t0_ms", Time.get_ticks_msec())
	request_start_time = (Time.get_ticks_msec() / 1000.0)
	http.request_completed.connect(Callable(self, "_on_all_tables_loaded").bind(http, table_list))
	
	var err: int = http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		print("[GLOBAL] ❌ HTTP request failed to start: %s" % str(err))
		push_error("❌ Failed to start combined fetch. Error: " + str(err))
		return
	
	print("[GLOBAL] 📤 GET: %s" % url)

## Handle response from Refresh_Data
func _on_all_tables_loaded(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, requested_tables: Array = []):
	elapsed = (Time.get_ticks_msec() / 1000.0) - request_start_time
	var bytes_received = body.size()
	var kbps = (bytes_received/1024) / elapsed
	
	print("[GLOBAL] 📥 Response received in %.2fs" % elapsed)
	print("[GLOBAL]    Data size: %.2f KB" % (bytes_received / 1024.0))
	print("[GLOBAL]    Speed: %.2f KB/s" % kbps)
	
	http.queue_free()
	if code != 200:
		print("[GLOBAL] ❌ Failed to fetch combined tables - HTTP %d" % code)
		return
	
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		print("[GLOBAL] ❌ JSON parse failed")
		return
	
	print("[GLOBAL] 🔄 Processing %d tables..." % data.keys().size())
	total_records = 0
	for table_name in data.keys():
		var records = data[table_name]
		_process_table(table_name, records)
	
	print("[GLOBAL] ✅ Total records loaded: %d" % total_records)
	
	if ACTIVE_USER_TYPE == "Player":
		print("[GLOBAL] 🧮 Player detected, recalculating stats...")
		calculate_all_stats()
	
	var _cr_id = CHARACTERS_NAME.get(ACTIVE_USER_NAME)
	if _cr_id != null and CHARACTERS.has(_cr_id) and CHARACTERS[_cr_id] is Dictionary:
		Current_Region = CHARACTERS[_cr_id].get("Current_Region", Current_Region)
	
	# ✅ Commit versions only after successful apply
	for t in requested_tables:
		if pending_timestamps.has(t):
			print("[GLOBAL] 📝 Committing timestamp for '%s'" % t)
			last_known_timestamps[t] = pending_timestamps[t]
			pending_timestamps.erase(t)
	
	emit_signal("data_load_complete")
	print("[GLOBAL] 🔔 Emitted data_load_complete signal")

	# One-time dump of all tables to JSON after the first full load
	if not _initial_dump_done and requested_tables.size() >= TABLES.size():
		_initial_dump_done = true
		_save_data_snapshot()

	print("[GLOBAL] 📥 ====== Refresh_Data() COMPLETE ======")

## Commit pending timestamps after successful refresh
func _commit_pending_timestamps(tables: Array) -> void:
	print("[GLOBAL] 📝 Committing pending timestamps for: %s" % str(tables))
	for t in tables:
		if pending_timestamps.has(t):
			last_known_timestamps[t] = String(pending_timestamps[t])
			pending_timestamps.erase(t)

## Save a snapshot of all loaded tables to user://data_snapshot.json (once on initial load)
func _save_data_snapshot() -> void:
	print("[GLOBAL] 💾 Saving initial data snapshot to user://data_snapshot.json ...")
	var snapshot := {
		"_meta": {
			"timestamp": Time.get_datetime_string_from_system(),
			"user": ACTIVE_USER_NAME,
		},
		"CHARACTERS": CHARACTERS,
		"COMPANIONS": COMPANIONS,
		"ENEMIES": ENEMIES,
		"ABILITIES": ABILITIES,
		"ACTIVE_ABILITIES": ACTIVE_ABILITIES,
		"ACTIVE_STATUS_EFFECTS": ACTIVE_STATUS_EFFECTS,
		"BATTLEENEMIES": BATTLEENEMIES,
		"CHARACTER_ITEMS": CHARACTER_ITEMS,
		"CHARACTER_WEAPONS": CHARACTER_WEAPONS,
		"CHARACTER_ARTIFACTS": CHARACTER_ARTIFACTS,
		"TALENTS": TALENTS,
		"CONSTELLATIONS": CONSTELLATIONS,
		"PARTY": PARTY,
		"ARTIFACTS": ARTIFACTS,
		"WEAPONS": WEAPONS,
		"REACTIONS": REACTIONS,
		"ITEMS": ITEMS,
		"STATUS_EFFECTS": STATUS_EFFECTS,
		"CRAFTING_RECIPES": CRAFTING_RECIPES,
		"MATERIAL_CACHES": MATERIAL_CACHES,
		"GAME_CONFIG": GAME_CONFIG,
	}
	var json_string = JSON.stringify(snapshot, "\t")
	var file = FileAccess.open("res://data_snapshot.json", FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[GLOBAL] 💾 Snapshot saved (%d bytes)" % json_string.length())
	else:
		push_error("[GLOBAL] ❌ Failed to write data_snapshot.json")

# ===========================================================================
# SECTION 18: PROCESS TABLE DATA
# ===========================================================================

## Parse table data from API response and populate dictionaries
func _process_table(table_name: String, records: Array) -> void:
	print("[GLOBAL] 🔄 Processing table '%s' (%d records)..." % [table_name, records.size()])
	match table_name:
		"Characters":
			CHARACTERS = {}
			for record in records:
				CHARACTERS[str(record["id"])] = record
				CHARACTERS_NAME[record["Name"]] = str(record["id"])
		"Weapons":
			WEAPONS = {}
			for record in records:
				WEAPONS[str(record["id"])] = record
				WEAPONS_NAME[record["Name"]] = str(record["id"])
		"Artifacts":
			ARTIFACTS = {}
			for record in records:
				ARTIFACTS[str(record["id"])] = record
		"Reactions":
			REACTIONS = {}
			for record in records:
				REACTIONS[str(record["id"])] = record
		"Abilities":
			ABILITIES = {}
			for record in records:
				ABILITIES[str(record["id"])] = record
		"Companions":
			COMPANIONS = {}
			for record in records:
				COMPANIONS[str(record["id"])] = record
				COMPANIONS_NAME[record["Name"]] = str(record["id"])
		"Crafting_Recipes":
			CRAFTING_RECIPES = {}
			for record in records:
				CRAFTING_RECIPES[str(record["id"])] = record
		"Items":
			ITEMS = {}
			for record in records:
				ITEMS[str(record["id"])] = record
		"Enemies":
			ENEMIES = {}
			for record in records:
				ENEMIES[str(record["id"])] = record
				EnemyList.append(record.get("name"))
				ENEMIES_NAME[record["name"]] = str(record["id"])
		"BattleEnemies":
			BATTLEENEMIES = {}
			for record in records:
				BATTLEENEMIES[str(record["id"])] = record
		"Character_Weapons":
			CHARACTER_WEAPONS = {}
			for record in records:
				CHARACTER_WEAPONS[str(record["id"])] = record
		"Character_Artifacts":
			CHARACTER_ARTIFACTS = {}
			for record in records:
				CHARACTER_ARTIFACTS[str(record["id"])] = record
		"Character_Items":
			CHARACTER_ITEMS = {}
			for record in records:
				CHARACTER_ITEMS[str(record["id"])] = record
		"Talents":
			TALENTS = {}
			for record in records:
				TALENTS[str(record["id"])] = record
		"Constellations":
			CONSTELLATIONS = {}
			for record in records:
				CONSTELLATIONS[str(record["id"])] = record
		"Material_Caches":
			MATERIAL_CACHES = {}
			for record in records:
				MATERIAL_CACHES[str(record["id"])] = record
		"Party":
			PARTY = {}
			for record in records:
				PARTY[str(record["id"])] = record
		"Active_Abilities":
			ACTIVE_ABILITIES = {}
			for record in records:
				ACTIVE_ABILITIES[str(record["id"])] = record
		"Active_Status_Effects":
			ACTIVE_STATUS_EFFECTS = {}
			for record in records:
				ACTIVE_STATUS_EFFECTS[str(record["id"])] = record
		"Status_Effects":
			STATUS_EFFECTS = {}
			for record in records:
				STATUS_EFFECTS[str(record["id"])] = record
		"Game_Config":
			GAME_CONFIG = {}
			for record in records:
				GAME_CONFIG[str(record["key"])] = str(record["value"])
		"Minigames":
			MINIGAMES = {}
			for record in records:
				MINIGAMES[str(record["id"])] = record
		"Minigames_Results":
			MINIGAMES_RESULTS = {}
			for record in records:
				MINIGAMES_RESULTS[str(record["id"])] = record
		_:
			print("[GLOBAL] ⚠️  Unknown table: %s" % table_name)
	
	emit_signal("table_loaded", table_name, records.size())
	print("[GLOBAL] ✅ Parsed table '%s' with %d records" % [table_name, records.size()])
	total_records += records.size()

# ===========================================================================
# SECTION 19: APPLY LOCAL UPDATES
# ===========================================================================

## Apply a local update to a record without going to the database
func _apply_local_update(table_name: String, record_id: String, field: String, value) -> void:
	print("[GLOBAL] ✏️  Local update: %s[%s].%s = %s" % [table_name, record_id, field, value])
	match table_name:
		"Characters":
			if not CHARACTERS.has(record_id): CHARACTERS[record_id] = {}
			CHARACTERS[record_id][field] = value
		"Character_Weapons":
			if not CHARACTER_WEAPONS.has(record_id): CHARACTER_WEAPONS[record_id] = {}
			CHARACTER_WEAPONS[record_id][field] = value
		"Character_Artifacts":
			if not CHARACTER_ARTIFACTS.has(record_id): CHARACTER_ARTIFACTS[record_id] = {}
			CHARACTER_ARTIFACTS[record_id][field] = value
		"Character_Items":
			if not CHARACTER_ITEMS.has(record_id): CHARACTER_ITEMS[record_id] = {}
			CHARACTER_ITEMS[record_id][field] = value
		"Abilities":
			if not ABILITIES.has(record_id): ABILITIES[record_id] = {}
			ABILITIES[record_id][field] = value
		"Talents":
			if not TALENTS.has(record_id): TALENTS[record_id] = {}
			TALENTS[record_id][field] = value
		"Constellations":
			if not CONSTELLATIONS.has(record_id): CONSTELLATIONS[record_id] = {}
			CONSTELLATIONS[record_id][field] = value
		_:
			print("[GLOBAL] ⚠️  Unknown table for local update: %s" % table_name)

# ===========================================================================
# SECTION 20: UPDATE RECORDS (Send changes to database)
# ===========================================================================

## Send record updates to the backend database
## This is how you persist changes (equipping items, leveling up, etc.)
func Update_Records(updates: Array) -> void:
	print("[GLOBAL] 📤 ====== Update_Records() START ======")
	print("[GLOBAL] 📋 Sending %d updates to server..." % updates.size())
	for i in range(min(3, updates.size())):
		print("[GLOBAL]    %d. %s" % [i+1, updates[i]])
	if updates.size() > 3:
		print("[GLOBAL]    ... and %d more" % (updates.size() - 3))
	
	# Mark fields and tables as recently written (prevents stale overwrites)
	for u in updates:
		if u.has("record_id") and u.has("field"):
			note_local_field_write(str(u["record_id"]), u["field"])
		if u.has("table"):
			last_local_write_ms[u["table"]] = Time.get_ticks_msec()
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	var url = API_BASE+"/update_records"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({ "updates": updates })
	request_start_time = Time.get_ticks_msec() / 1000.0
	http_request.request_completed.connect(_on_multi_update_response.bind(http_request))
	print("[GLOBAL] 📤 PATCH: %s" % url)
	http_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

# ===========================================================================
# SECTION 21: INSERT RECORD
# ===========================================================================

## Insert a new record into a table
func Insert(table: String, columns: Array, values: Array) -> void:
	print("[GLOBAL] 📤 ====== Insert() START ======")
	print("[GLOBAL] 📋 Inserting into '%s'" % table)
	print("[GLOBAL]    Columns: %s" % str(columns))
	print("[GLOBAL]    Values: %s" % str(values))
	
	# Quick guards
	if table.strip_edges() == "":
		print("[GLOBAL] ❌ Table name is empty")
		push_warning("Insert: table is empty")
		return
	if columns.is_empty() or values.is_empty():
		print("[GLOBAL] ❌ Columns or values are empty")
		push_warning("Insert: columns/values empty")
		return
	if columns.size() != values.size():
		print("[GLOBAL] ❌ Column/value count mismatch")
		push_warning("Insert: columns and values length mismatch")
		return
	
	last_local_write_ms[table] = Time.get_ticks_msec()

	var http_request := HTTPRequest.new()
	add_child(http_request)

	var url := API_BASE + "/insert_record"
	var headers := ["Content-Type: application/json"]
	var payload := {
		"table": table,
		"columns": columns,
		"values": values
	}
	
	# Include correlation ID if one was set
	var corr_id = _next_insert_corr_id
	if corr_id != "":
		print("[GLOBAL] 🔗 Correlation ID: %s" % corr_id)
		payload["correlation_id"] = corr_id
		_next_insert_corr_id = ""  # Clear after use
	
	request_start_time = Time.get_ticks_msec() / 1000.0
	http_request.request_completed.connect(
		_on_insert_response.bind(http_request, table, columns, corr_id)
	)
	
	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		print("[GLOBAL] ❌ HTTP request failed to start: %s" % str(err))
		push_error("Insert: HTTP request failed to start (%s)" % str(err))

# ===========================================================================
# SECTION 22: REMOVE RECORD
# ===========================================================================

## Delete a record from a table
func Remove_Record(table: String, record_id: int) -> void:
	print("[GLOBAL] 🗑️  ====== Remove_Record() START ======")
	print("[GLOBAL] 📋 Removing from '%s' id=%d" % [table, record_id])
	
	# Guards
	if table.strip_edges() == "":
		print("[GLOBAL] ❌ Table name is empty")
		push_warning("Remove_Record: table is empty")
		return
	if typeof(record_id) != TYPE_INT and typeof(record_id) != TYPE_FLOAT:
		print("[GLOBAL] ❌ Invalid record_id type")
		push_warning("Remove_Record: record_id must be a number")
		return
	
	var record
	var normalized = table.to_upper()
	var object = Global.get(normalized)
	record = object[str(float(record_id))]
	
	last_local_write_ms[table] = Time.get_ticks_msec()

	var http_request := HTTPRequest.new()
	add_child(http_request)

	var url := API_BASE + "/remove_record"
	var headers := ["Content-Type: application/json"]
	var body_dict := {
		"table": table,
		"record_id": int(record_id)
	}
	var body = JSON.stringify(body_dict)
	
	request_start_time = Time.get_ticks_msec() / 1000.0
	http_request.request_completed.connect(_on_remove_response.bind(http_request, table, int(record_id), record))
	print("[GLOBAL] 📤 DELETE: %s" % url)
	var err := http_request.request(url, headers, HTTPClient.METHOD_DELETE, body)
	if err != OK:
		print("[GLOBAL] ❌ HTTP request failed to start: %s" % str(err))
		push_error("Remove_Record: HTTP request failed to start (%s)" % str(err))

# ===========================================================================
# SECTION 23: HTTP RESPONSE HANDLERS
# ===========================================================================

## Handle response from Remove_Record delete request
func _on_remove_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest, table: String, record_id: int, record) -> void:
	var took = (Time.get_ticks_msec() / 1000.0) - request_start_time
	var text = body.get_string_from_utf8()
	var parsed: Dictionary = {}
	if text != "":
		var p = JSON.parse_string(text)
		if typeof(p) == TYPE_DICTIONARY:
			parsed = p
	
	print("[GLOBAL] 📥 Remove response (%.3fs): %s" % [took, text])
	
	# Clean up request node
	if is_instance_valid(http_node):
		http_node.queue_free()
	
	var ok := (result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)

	if not ok:
		print("[GLOBAL] ❌ Remove failed (result=%s, http=%s)" % [str(result), str(response_code)])
		push_error("Remove_Record: transport/server error (result=%s, http=%s) -> %s (%.3fs)" % [str(result), str(response_code), text, took])
		if has_method("Log"):
			Global.Log("HTTP.Delete", "error", table, str(record_id), {}, parsed, {}, "failure", "error")
		return
	
	# Success
	if parsed.has("success") and parsed["success"] == true:
		var rows := int(parsed.get("rows_affected", 1))
		print("[GLOBAL] ✅ Removed from %s id=%s (rows=%d) in %.3fs" % [table, str(record_id), rows, took])
	else:
		print("[GLOBAL] ✅ Remove OK (%.3fs)" % took)
	
	# Refresh table
	Global.Refresh_Data([table])
	
	# Audit log
	if has_method("Log"):
		Global.Log("HTTP.Delete", "remove_record", table, str(record_id), record, parsed, {}, "success", "audit")

## Handle response from Insert request
func _on_insert_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest, table: String, columns: Array, correlation_id: String) -> void:
	var took = (Time.get_ticks_msec() / 1000.0) - request_start_time
	var text = body.get_string_from_utf8()
	var parsed: Dictionary = {}
	if text != "":
		var p = JSON.parse_string(text)
		if typeof(p) == TYPE_DICTIONARY:
			parsed = p
	
	print("[GLOBAL] 📥 Insert response (%.3fs): %s" % [took, text])
	
	if is_instance_valid(http_node):
		http_node.queue_free()

	var ok := (result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)
	if not ok:
		print("[GLOBAL] ❌ Insert failed (result=%s, http=%s) in %.3fs" % [str(result), str(response_code), took])
		push_error("Insert: transport/server error (result=%s, http=%s) in %.3fs" % [str(result), str(response_code), took])
		emit_signal("insert_finished", correlation_id, table, -1, parsed, false)
		return
	
	# Success
	var record_id := -1
	if parsed.has("record_id"):
		record_id = int(parsed["record_id"])
	# If server echoes correlation_id back, use that
	if parsed.has("correlation_id") and str(parsed["correlation_id"]) != "":
		correlation_id = str(parsed["correlation_id"])
	
	if parsed.has("status") and str(parsed["status"]).to_lower() == "success":
		print("[GLOBAL] ✅ Insert OK into %s cols=%s record_id=%s (%.3fs)" % [table, columns, str(record_id), took])
	else:
		print("[GLOBAL] ✅ Insert OK (%.3fs)" % took)
	
	# Emit signal
	emit_signal("insert_finished", correlation_id, table, record_id, parsed, true)
	
	# Refresh table
	Global.Refresh_Data([table])

## Handle response from Update_Records request
func _on_multi_update_response(result, code, headers, body, request_node) -> void:
	elapsed = (Time.get_ticks_msec() / 1000.0) - request_start_time
	var bytes_received = body.size()
	var kbps = (bytes_received/1024) / elapsed
	
	print("[GLOBAL] 📥 Update response in %.2fs (%.2f KB @ %.1f KB/s)" % [elapsed, bytes_received / 1024.0, kbps])
	
	request_node.queue_free()
	if code != 200:
		print("[GLOBAL] ❌ Failed to update records - HTTP %d" % code)
		print("[GLOBAL]    %s" % body.get_string_from_utf8())
		return
	
	var tables_to_refresh: Array = []
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("updated"):
		for update in json["updated"]:
			var t = String(update.get("table",""))
			var ts
			if update.get("modified_time") != null:
				ts = String(update.get("modified_time",""))
			if t != "" and not tables_to_refresh.has(t):
				print("[GLOBAL] 📝 Updated table: %s" % t)
				tables_to_refresh.append(t)
				pending_timestamps[t] = ts
	
	print("[GLOBAL] 🔄 Refreshing %d tables after update: %s" % [tables_to_refresh.size(), tables_to_refresh])
	if tables_to_refresh.size() > 0:
		Global.Refresh_Data(tables_to_refresh)

# ===========================================================================
# SECTION 24: ARTIFACT TYPE MAPPING
# ===========================================================================

## Map short artifact type names to full names
const ARTIFACT_TYPE_MAP = {
	"Flower":  "Flower of Life",
	"Feather": "Feather of Death",
	"Sands":   "Sands of Time",
	"Goblet":  "Goblet of Space",
	"Circlet": "Circlet of Principles"
}

## Convert artifact slot short name to full type name
func slot_label_to_type(slot_short: String) -> String:
	return ARTIFACT_TYPE_MAP.get(slot_short, slot_short)

# ===========================================================================
# SECTION 25: EQUIPMENT MANAGEMENT - EQUIP ARTIFACT
# ===========================================================================

## Equip an artifact in a specific slot, automatically unequipping what was there
func equip_artifact(slot_type: String, record_id: String) -> bool:
	print("[GLOBAL] 🎯 equip_artifact() - slot: %s, artifact_id: %s" % [slot_type, record_id])
	
	if not CHARACTER_ARTIFACTS.has(record_id):
		print("[GLOBAL] ❌ Artifact not found: %s" % record_id)
		return false
	
	var owner = ACTIVE_USER_NAME
	print("[GLOBAL] 👤 Owner: %s" % owner)
	
	# Unequip any current in this slot
	print("[GLOBAL] 🔄 Unequipping current artifact in slot '%s'..." % slot_type)
	var unequipped = 0
	for rid in CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = CHARACTER_ARTIFACTS[rid]
		if rec.get("Owner") == owner and rec.get("Type") == slot_type:
			print("[GLOBAL]   ✅ Unequipped: %s" % rid)
			rec["Equipped"] = null
			CHARACTER_ARTIFACTS[rid] = rec
			unequipped += 1
	print("[GLOBAL] Unequipped %d artifact(s)" % unequipped)
	
	# Equip the target
	print("[GLOBAL] 🎯 Equipping artifact %s..." % record_id)
	var sel: Dictionary = CHARACTER_ARTIFACTS[record_id]
	if sel.get("Owner") != owner or sel.get("Type") != slot_type:
		print("[GLOBAL] ❌ Artifact mismatch - Owner: %s (expected %s), Type: %s (expected %s)" % [sel.get("Owner"), owner, sel.get("Type"), slot_type])
		return false
	
	sel["Equipped"] = owner
	CHARACTER_ARTIFACTS[record_id] = sel
	print("[GLOBAL] ✅ Equipped artifact: %s" % record_id)
	
	# Recalculate stats
	print("[GLOBAL] 📊 Recalculating stats...")
	calculate_all_stats()
	
	print("[GLOBAL] ✅ equip_artifact() complete")
	return true

# ===========================================================================
# SECTION 26: ARTIFACT SEARCH & PREVIEW
# ===========================================================================

## Find items matching a search query (case-insensitive substring match)
func find_substring_matches_ci(query_text: String, source_list: Array) -> Array:
	var q: String = query_text.strip_edges()
	if q == "":
		return []
	
	var ql: String = q.to_lower()
	var matches: Array = []
	
	for item in source_list:
		var s: String = str(item)
		if s.to_lower().find(ql) != -1:
			matches.append(s)
	
	# Sort alphabetically ignoring case
	matches.sort_custom(Callable(self, "_ci_less"))
	print("[GLOBAL] 🔍 Found %d matches for '%s'" % [matches.size(), query_text])
	return matches

## Helper: case-insensitive string comparison
func _ci_less(a: String, b: String) -> bool:
	return a.nocasecmp_to(b) < 0

## Preview stats if an artifact were equipped (non-destructive)
## Returns dict of stats that WOULD result if equipped
func preview_stats_with_artifact(slot_type: String, record_id: String) -> Dictionary:
	print("[GLOBAL] 👁️  preview_stats_with_artifact() - non-destructive preview")
	print("[GLOBAL] 🎯 Slot: %s, Artifact: %s" % [slot_type, record_id])
	
	var owner = ACTIVE_USER_NAME
	
	# Snapshot currently displayed totals
	var snapshot = {
		"Health": Current_Health,
		"Attack": Current_Attack,
		"Defense": Current_Defense,
		"Elemental Mastery": Current_Elemental_Mastery,
		"Energy Recharge": Current_Energy_Recharge,
		"Critical Damage": Current_Critical_Damage
	}
	print("[GLOBAL] 📸 Current stats snapshot taken")
	
	# Remember what is currently equipped in this slot
	var prev_equipped: String = ""
	print("[GLOBAL] 🔍 Finding current artifact in this slot...")
	for rid in CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = CHARACTER_ARTIFACTS[rid]
		if rec.get("Owner") == owner and rec.get("Type") == slot_type:
			if rec.get("Equipped") == owner or rec.get("Equipped") == true:
				prev_equipped = rid
				print("[GLOBAL]   Found: %s" % rid)
			rec["Equipped"] = null
			CHARACTER_ARTIFACTS[rid] = rec
	
	# Temporarily equip candidate
	if not CHARACTER_ARTIFACTS.has(record_id):
		print("[GLOBAL] ⚠️  Artifact not found, returning current stats")
		return snapshot
	
	var cand: Dictionary = CHARACTER_ARTIFACTS[record_id]
	if cand.get("Owner") != owner or cand.get("Type") != slot_type:
		print("[GLOBAL] ⚠️  Artifact mismatch, returning current stats")
		return snapshot
	
	cand["Equipped"] = owner
	CHARACTER_ARTIFACTS[record_id] = cand
	print("[GLOBAL] 🔄 Temporarily equipped: %s" % record_id)
	
	# Recompute
	print("[GLOBAL] 📊 Recalculating stats with preview artifact...")
	calculate_all_stats()
	
	var preview = {
		"Health": Current_Health,
		"Attack": Current_Attack,
		"Defense": Current_Defense,
		"Elemental Mastery": Current_Elemental_Mastery,
		"Energy Recharge": Current_Energy_Recharge,
		"Critical Damage": Current_Critical_Damage
	}
	print("[GLOBAL] 📊 Preview stats calculated")
	
	# Restore equip state
	print("[GLOBAL] ↩️  Restoring original artifact...")
	# 1) clear slot
	for rid2 in CHARACTER_ARTIFACTS.keys():
		var rec2: Dictionary = CHARACTER_ARTIFACTS[rid2]
		if rec2.get("Owner") == owner and rec2.get("Type") == slot_type:
			rec2["Equipped"] = null
			CHARACTER_ARTIFACTS[rid2] = rec2
	# 2) restore previous equip
	if prev_equipped != "":
		var prev: Dictionary = CHARACTER_ARTIFACTS[prev_equipped]
		prev["Equipped"] = owner
		CHARACTER_ARTIFACTS[prev_equipped] = prev
		print("[GLOBAL]   ✅ Restored: %s" % prev_equipped)
	
	# 3) restore current totals
	Current_Health = snapshot["Health"]
	Current_Attack = snapshot["Attack"]
	Current_Defense = snapshot["Defense"]
	Current_Elemental_Mastery = snapshot["Elemental Mastery"]
	Current_Energy_Recharge = snapshot["Energy Recharge"]
	Current_Critical_Damage = snapshot["Critical Damage"]
	print("[GLOBAL] ✅ Original state restored")
	
	print("[GLOBAL] 👁️  Preview complete")
	return preview

# ===========================================================================
# SECTION 27: LOGGING FUNCTIONS
# ===========================================================================

## Log an audit event to the backend
func Log(category: String, action: String, related_type: String = "", related_id: String = "",
		 old_values: Dictionary = {}, new_values: Dictionary = {}, metadata: Dictionary = {},
		 result: String = "success", severity: String = "audit") -> void:
	print("[GLOBAL] 📝 Log() - category: %s, action: %s, result: %s" % [category, action, result])

	var scene_name = ""
	if get_tree().current_scene != null:
		scene_name = get_tree().current_scene.name
	
	var meta: Dictionary = {
		"scene": scene_name,
		"client_time": Time.get_datetime_string_from_system(),
		"client_version": ProjectSettings.get_setting("application/config/version", "dev"),
		"client_locale_info": OS.get_locale(),
		"client_memory_info": OS.get_memory_info(),
		"client_OS_type": OS.get_name(),
		"client_OS_version": OS.get_version(),
		"client_OS_version_alias": OS.get_version_alias(),
		"client_CPU_info": OS.get_processor_name(),
		"client_GPU_info": OS.get_video_adapter_driver_info(),
		"client_audio_device": AudioServer.output_device,
		"client_audio_driver": AudioServer.get_driver_name(),
		"client_audio_device_list" : AudioServer.get_output_device_list(),
		"client_public_ip_address": PublicIP,
		"client_internal_ip_address": str(IP.resolve_hostname(str(OS.get_environment("COMPUTERNAME")), IP.TYPE_IPV4))
	}
	for k in metadata.keys():
		meta[k] = metadata[k]
	
	var payload: Dictionary = {
		"user_id": ACTIVE_USER_NAME,
		"category": category,
		"action": action,
		"related_type": related_type,
		"related_id": related_id,
		"old_values": old_values,
		"new_values": new_values,
		"metadata": meta,
		"result": result,
		"severity": severity
	}
	
	print("[GLOBAL] 📤 Posting to /log endpoint")
	_post_json("/log", payload, _on_log_response)

## Log a combat event (damage, heals, status effects, etc.)
func CombatLog(battle_id, turn_no: int, phase: String, actor_type: String, actor_id: String,
			   action_type: String, action_name: String, target_id: String, ignores_def: bool,
			   rolls: Dictionary, damage: int, hp_before: int, hp_after: int, energy_change: int,
			   elements_applied: Array = [], status_changes: Dictionary = {}, misc: Dictionary = {}) -> void:
	print("[GLOBAL] 🎯 CombatLog() - battle: %s, turn: %d, action: %s" % [battle_id, turn_no, action_name])
	print("[GLOBAL]    %s → %s (damage: %d, hp: %d→%d)" % [actor_id, target_id, damage, hp_before, hp_after])

	var payload: Dictionary = {
		"battle_id": battle_id,
		"turn_no": turn_no,
		"phase": phase,
		"actor_type": actor_type,
		"actor_id": actor_id,
		"action_type": action_type,
		"action_name": action_name,
		"target_id": target_id,
		"ignores_def": ignores_def,
		"rolls": rolls,
		"damage": damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"energy_change": energy_change,
		"elements_applied": elements_applied,
		"status_changes": status_changes,
		"misc": misc
	}
	
	print("[GLOBAL] 📤 Posting to /combat_log endpoint")
	_post_json("/combat_log", payload, _on_combat_log_response)

# ===========================================================================
# SECTION 28: HTTP HELPERS
# ===========================================================================

## Generic POST JSON helper for logging
func _post_json(endpoint: String, data: Dictionary, callback: Callable) -> void:
	print("[GLOBAL] 📤 _post_json() to endpoint: %s" % endpoint)
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	var url: String = API_BASE + endpoint
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body: String = JSON.stringify(data)
	request_start_time = Time.get_ticks_msec() / 1000.0
	http_request.request_completed.connect(callback.bind(http_request))
	print("[GLOBAL] 📤 POST: %s" % url)
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

# ===========================================================================
# SECTION 29: HTTP RESPONSE CALLBACKS
# ===========================================================================

## Handle response from Log() call
func _on_log_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	print("[GLOBAL] 📥 Log response - HTTP %d" % response_code)
	http.queue_free()
	if response_code < 200 or response_code >= 300:
		print("[GLOBAL] ❌ Log() failed - HTTP %d" % response_code)
		push_warning("Log() failed: HTTP " + str(response_code) + " body=" + body.get_string_from_utf8())

## Handle response from CombatLog() call
func _on_combat_log_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	print("[GLOBAL] 📥 CombatLog response - HTTP %d" % response_code)
	http.queue_free()
	if response_code < 200 or response_code >= 300:
		print("[GLOBAL] ❌ CombatLog() failed - HTTP %d" % response_code)
		push_warning("CombatLog() failed: HTTP " + str(response_code) + " body=" + body.get_string_from_utf8())

# ===========================================================================
# END OF Global.gd
# ===========================================================================
