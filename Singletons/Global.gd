extends Node

var ACTIVE_USER_EMAIL: String = ""
var ACTIVE_USER_NAME: String = ""
var ACTIVE_USER_TYPE: String = ""
var ACTIVE_USER_RECORD_ID: float
var TABLES: Array = ["Artifacts","Reactions","Weapons","Abilities","Companions","Crafting_Recipes","Items","Enemies","Characters","BattleEnemies","Character_Items","Character_Weapons", "Character_Artifacts","Talents","Constellations","Material_Caches","Party","Active_Abilities","Active_Status_Effects","Status_Effects","Game_Config","Minigames","Minigames_Results"]
var joined = ",".join(TABLES)
var ARTIFACTS: Dictionary = {}
var REACTIONS: Dictionary = {}
var WEAPONS: Dictionary = {}
var ABILITIES: Dictionary = {}
var COMPANIONS: Dictionary = {}
var CRAFTING_RECIPES: Dictionary = {}
var ITEMS: Dictionary = {}
var ENEMIES: Dictionary = {}
var ATTACKS: Dictionary = {}
var CHARACTERS: Dictionary = {}
var BATTLEENEMIES: Dictionary = {}
var BATTLE_TURNS: Array = []
var CHARACTER_ITEMS: Dictionary = {}
var CHARACTER_WEAPONS: Dictionary = {}
var CHARACTER_ARTIFACTS: Dictionary = {}
var GAME_CONFIG: Dictionary
var STATUS_EFFECTS = {}
var ACTIVE_ABILITIES: Dictionary = {}
var ACTIVE_STATUS_EFFECTS: Dictionary = {}
var PARTY: Dictionary = {}
var TALENTS = {}
var CONSTELLATIONS = {}
var BATTLE_LOG: Dictionary = {}
var MINIGAMES: Dictionary = {}
var MINIGAMES_RESULTS: Dictionary = {}
var ARTIFACTS_NAME = {}
var WEAPONS_NAME = {}
var COMPANIONS_NAME = {}
var CRAFTINGRECIPES_NAME = {}
var MATERIAL_CACHES = {}
var BATTLE_PARTICIPANTS = []
var ITEMS_NAME = {}
var ENEMIES_NAME = {}
var CHARACTERS_NAME = {}
var BATTLEENEMIES_NAME = {}
var TABLES_TO_SAVE = ["Characters","BattleEnemies","Character Items","Character_Weapons", "Character_Artifacts", "Companions"]
var TABLES_TO_SYNC_OFTEN = ["Characters","BattleEnemies","Companions"]
var BATTLE_TURN_ORDER = []
var _current_region = ""
var Current_Health: float = 0.0
var Current_Attack: float = 0.0
var Current_Defense: float = 0.0
var Current_Elemental_Mastery: float = 0.0
var Current_Energy_Recharge: float = 0.0
var Current_Critical_Damage: float = 0.0
var Current_Weapon = null
var EnemyList = []
var set_count = {}
var set_pieces = null
var Current_Party = null
var total_records: int = 0
var variable_name = ""
var request_start_time: float = 0.0
var elapsed: float = 0.0
var set_modifiers := {}
var artifact_set_calculated = 0
var Region_Changed = 1
var PublicIP
var PartyCharacters = []
var PartyCompanions = []
var BattlerData = {}
var Current_Battler_Data
var Luck_Set = false

var AverageHealth : int
var APPLIED_ARTIFACT_BONUSES := {}
var FINAL_CHARACTER_STATS := {}
var known_bonus_fields = []
var Current_Region:
	get:
		return _current_region
	set(value):
		if _current_region != value:
			_current_region = value
			Region_Changed = 1
signal table_loaded(table_name: String, records_loaded: int)
signal data_load_complete

var scaling = {
	"Health": 2.0,
	"Attack": 1.0,
	"Defense": 1.0,
	"Elemental_Mastery": 1.0,
	"Energy_Recharge": 0.1,
	"Critical_Damage": 0.1,
}
signal insert_finished(correlation_id: String, table: String, record_id: int, payload: Dictionary, ok: bool)

var _next_insert_corr_id: String = ""

func set_next_correlation_id(id_value: String) -> void:
	_next_insert_corr_id = id_value


func normalize_text_filename(weapon_name: String) -> String:
	var cleaned := weapon_name.strip_edges().to_lower()
	cleaned = cleaned.replace("\u00a0", " ")
	cleaned = cleaned.replace("\u00ad", "")
	cleaned = cleaned.replace("\u2019", "")
	cleaned = cleaned.replace(" ", "-")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9-]")
	cleaned = regex.sub(cleaned, "", true)
	return cleaned + ".png"

func calculate_all_stats() -> void:
	if not CHARACTERS_NAME.has(ACTIVE_USER_NAME):
		return
	var ACTIVE_CHARACTER_ID = CHARACTERS_NAME[ACTIVE_USER_NAME]
	var character = CHARACTERS[ACTIVE_CHARACTER_ID]
	Current_Region = CHARACTERS[CHARACTERS_NAME[ACTIVE_USER_NAME]].get("Current_Region")
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
	if known_bonus_fields.size() == 0:
		for stat in scaling.keys():
				for suffix in bonus_suffixes:
					known_bonus_fields.append("%s_%s" % [stat, suffix])

	for bonus_field in known_bonus_fields:
		if bonus_field.contains("Manual") == false:
			character[bonus_field] = 0

	var set_pieces = {}
	for key in set_count:
		set_count[key] = 0
	for artifact in CHARACTER_ARTIFACTS.values():
		if artifact.get("Owner") == ACTIVE_USER_NAME and artifact.get("Equipped") == true:
			var set_name = artifact.get("Artifact_Set")
			set_pieces[set_name] = set_pieces.get(set_name, 0) + 1
			set_count[set_name] = set_count.get(set_name, 0) + 1

	for artifact_set in set_pieces.keys():
		for DBset in ARTIFACTS.values():
			if artifact_set == DBset.get("Artifact_Set") and set_pieces[artifact_set] >= DBset.get("Bonus_Type"):
				var stat = DBset.get("Stat_Modifier")
				var value = DBset.get("Stat_Modifier_Value")
				var condition = DBset.get("Condition")
				var condition_val = DBset.get("Condition_Value")

				if stat == null or stat == "":
					continue

				var meets_condition = true
				if condition != null and condition != "":
					var char_value = character.get(condition)
					meets_condition = char_value == condition_val

				if meets_condition:
					character[stat] = character.get(stat, 0) + value

	for weapon in CHARACTER_WEAPONS.values():
		if weapon.get("Owner") == ACTIVE_USER_NAME and weapon.get("Equipped") == true:
			var weapon_data = WEAPONS[WEAPONS_NAME[weapon.get("Weapon")]]
			if weapon_data.get("Stat_Modifier") != null:
				var stat = weapon_data.get("Stat_Modifier")
				var value = weapon_data.get("Stat_Modifier_Value")
				character[stat] = character.get(stat,0) + value


	for stat in scaling.keys():
		var base = character.get("%s_Base_Points" % stat, 0)
		var skill = character.get("%s_Skill_Points" % stat, 0)
		var added = character.get("%s_Added_Stat_Bonus" % stat, 0)
		var multiplier = character.get("%s_Multiplier_Stat_Bonus" % stat, 0.0)
		var AddEdit = character.get("%s_Manual_Added_Amount_Override" % stat, 0)
		var MultEdit = character.get("%s_Manual_Multiplier_Amount_Override" % stat, 0.0)
		var uadded = character.get("Universal_Added_Stat_Bonus", 0)
		var umultiplier = character.get("Universal_Multiplier_Stat_Bonus", 0.0)

		var value = (((base + skill) * scaling[stat]) + added + AddEdit+uadded)

		for weapon in CHARACTER_WEAPONS.values():
			if weapon.get("Owner") == ACTIVE_USER_NAME and weapon.get("Equipped") == true:
				Global.Current_Weapon = weapon
				for i in range(1, 4):
					if weapon.get("Stat_%d_Type" % i) == stat:
						value += weapon.get("Stat_%d_Value" % i, 0)

		for artifact in CHARACTER_ARTIFACTS.values():
			if artifact.get("Owner") == ACTIVE_USER_NAME and artifact.get("Equipped") == true:
				for i in range(1, 3):
					if artifact.get("Stat_%d_Type" % i) == stat:
						value += artifact.get("Stat_%d_Value" % i, 0)

		value *= (multiplier + MultEdit + umultiplier + 1.0)

		variable_name = stat.replace(" ", "_")
		Global.set("Current_%s" % variable_name, snapped(value, 0.01))

# ─── DATA LOADING (from _process_table, used by DataStore/NetworkManager) ───

func Refresh_Data(table_list: Array) -> void:
	if table_list.is_empty():
		push_error("Refresh_Data called with an empty table list.")
		return

	if NetworkManager.is_host:
		# Host: reload from disk and broadcast
		for table_name in table_list:
			var records := DataStore.load_table(table_name)
			_process_table(table_name, records)
			NetworkManager.broadcast_table_update(table_name)
	else:
		# Client: data comes from host via RPC, nothing to do locally
		pass

	if ACTIVE_USER_TYPE == "Player":
		calculate_all_stats()
	if CHARACTERS_NAME.has(ACTIVE_USER_NAME):
		Current_Region = CHARACTERS[CHARACTERS_NAME[ACTIVE_USER_NAME]].get("Current_Region")

	emit_signal("data_load_complete")

func _process_table(table_name: String, records: Array) -> void:
	if records.size() > 0 and typeof(records[0]) != TYPE_DICTIONARY:
		push_warning("_process_table '%s': records[0] is type %s, expected Dictionary. Skipping." % [table_name, type_string(typeof(records[0]))])
		return
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
				if typeof(record) != TYPE_DICTIONARY:
					continue
				GAME_CONFIG[str(record.get("key", ""))] = str(record.get("value", ""))

		"Minigames":
			MINIGAMES = {}
			for record in records:
				MINIGAMES[str(record["id"])] = record

		"Minigames_Results":
			MINIGAMES_RESULTS = {}
			for record in records:
				MINIGAMES_RESULTS[str(record["id"])] = record
		_:
			pass

	emit_signal("table_loaded", table_name, records.size())
	total_records += records.size()
	print("Parsed table: ", table_name, " with ", records.size(), " records.")

# ─── LOCAL MUTATION HELPERS (used by NetworkManager for applying changes) ───

func _apply_local_update(table_name: String, record_id: String, field: String, value) -> void:
	var dict := _get_dict_for_table(table_name)
	if not dict.is_empty():
		if not dict.has(record_id):
			dict[record_id] = {}
		dict[record_id][field] = value

func _apply_record_update(table_name: String, record_id: String, data: Dictionary) -> void:
	var dict := _get_dict_for_table(table_name)
	if not dict.is_empty():
		dict[record_id] = data
	if ACTIVE_USER_TYPE == "Player":
		calculate_all_stats()
	emit_signal("data_load_complete")

func _insert_record(table_name: String, record_id: String, record: Dictionary) -> void:
	var dict := _get_dict_for_table(table_name)
	dict[record_id] = record
	# Update name lookups
	match table_name:
		"Characters":
			if record.has("Name"):
				CHARACTERS_NAME[record["Name"]] = record_id
		"Weapons":
			if record.has("Name"):
				WEAPONS_NAME[record["Name"]] = record_id
		"Companions":
			if record.has("Name"):
				COMPANIONS_NAME[record["Name"]] = record_id
		"Enemies":
			if record.has("name"):
				ENEMIES_NAME[record["name"]] = record_id
				EnemyList.append(record.get("name"))

func _remove_record(table_name: String, record_id: String) -> void:
	var dict := _get_dict_for_table(table_name)
	dict.erase(record_id)

func _get_dict_for_table(table_name: String) -> Dictionary:
	match table_name:
		"Characters": return CHARACTERS
		"Weapons": return WEAPONS
		"Artifacts": return ARTIFACTS
		"Reactions": return REACTIONS
		"Abilities": return ABILITIES
		"Companions": return COMPANIONS
		"Crafting_Recipes": return CRAFTING_RECIPES
		"Items": return ITEMS
		"Enemies": return ENEMIES
		"BattleEnemies": return BATTLEENEMIES
		"Character_Weapons": return CHARACTER_WEAPONS
		"Character_Artifacts": return CHARACTER_ARTIFACTS
		"Character_Items": return CHARACTER_ITEMS
		"Talents": return TALENTS
		"Constellations": return CONSTELLATIONS
		"Material_Caches": return MATERIAL_CACHES
		"Party": return PARTY
		"Active_Abilities": return ACTIVE_ABILITIES
		"Active_Status_Effects": return ACTIVE_STATUS_EFFECTS
		"Status_Effects": return STATUS_EFFECTS
		"Game_Config": return GAME_CONFIG
		"Minigames": return MINIGAMES
		"Minigames_Results": return MINIGAMES_RESULTS
	return {}

# ─── NETWORK-AWARE WRITE OPERATIONS ───

func Update_Records(updates: Array) -> void:
	if NetworkManager.is_host:
		NetworkManager.host_update_records(updates)
	else:
		# Client: send request to host
		var json_str := JSON.stringify(updates)
		NetworkManager.request_update.rpc_id(1, json_str)

	# Apply locally immediately for responsiveness
	for u in updates:
		_apply_local_update(str(u.get("table", "")), str(u.get("record_id", "")), str(u.get("field", "")), u.get("value"))

func Insert(table: String, columns: Array, values: Array) -> void:
	if table.strip_edges() == "":
		push_warning("Insert: table is empty")
		return
	if columns.is_empty() or values.is_empty():
		push_warning("Insert: columns/values empty")
		return
	if columns.size() != values.size():
		push_warning("Insert: columns and values length mismatch")
		return

	var corr_id = _next_insert_corr_id
	_next_insert_corr_id = ""

	if NetworkManager.is_host:
		var new_id := NetworkManager.host_insert(table, columns, values)
		var record := { "id": new_id }
		for i in columns.size():
			record[columns[i]] = values[i]
		emit_signal("insert_finished", corr_id, table, new_id, record, true)
	else:
		var record := {}
		for i in columns.size():
			record[columns[i]] = values[i]
		var json_str := JSON.stringify(record)
		NetworkManager.request_insert.rpc_id(1, table, json_str, corr_id)

func Remove_Record(table: String, record_id: int) -> void:
	if table.strip_edges() == "":
		push_warning("Remove_Record: table is empty")
		return

	if NetworkManager.is_host:
		NetworkManager.host_remove(table, record_id)
	else:
		NetworkManager.request_remove.rpc_id(1, table, record_id)

	# Remove locally for responsiveness
	_remove_record(table, str(record_id))

# ─── ARTIFACT UTILITIES ───

const ARTIFACT_TYPE_MAP = {
	"Flower":  "Flower of Life",
	"Feather": "Feather of Death",
	"Sands":   "Sands of Time",
	"Goblet":  "Goblet of Space",
	"Circlet": "Circlet of Principles"
}

func slot_label_to_type(slot_short: String) -> String:
	return ARTIFACT_TYPE_MAP.get(slot_short, slot_short)

func equip_artifact(slot_type: String, record_id: String) -> bool:
	if not CHARACTER_ARTIFACTS.has(record_id):
		return false
	var owner = ACTIVE_USER_NAME

	for rid in CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = CHARACTER_ARTIFACTS[rid]
		if rec.get("Owner") == owner and rec.get("Type") == slot_type:
			rec["Equipped"] = null
			CHARACTER_ARTIFACTS[rid] = rec

	var sel: Dictionary = CHARACTER_ARTIFACTS[record_id]
	if sel.get("Owner") != owner or sel.get("Type") != slot_type:
		return false
	sel["Equipped"] = owner
	CHARACTER_ARTIFACTS[record_id] = sel

	calculate_all_stats()
	return true

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

	matches.sort_custom(Callable(self, "_ci_less"))
	return matches


func _ci_less(a: String, b: String) -> bool:
	return a.nocasecmp_to(b) < 0

func preview_stats_with_artifact(slot_type: String, record_id: String) -> Dictionary:
	var owner = ACTIVE_USER_NAME
	var snapshot = {
		"Health": Current_Health,
		"Attack": Current_Attack,
		"Defense": Current_Defense,
		"Elemental Mastery": Current_Elemental_Mastery,
		"Energy Recharge": Current_Energy_Recharge,
		"Critical Damage": Current_Critical_Damage
	}

	var prev_equipped: String = ""
	for rid in CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = CHARACTER_ARTIFACTS[rid]
		if rec.get("Owner") == owner and rec.get("Type") == slot_type:
			if rec.get("Equipped") == owner or rec.get("Equipped") == true:
				prev_equipped = rid
			rec["Equipped"] = null
			CHARACTER_ARTIFACTS[rid] = rec

	if not CHARACTER_ARTIFACTS.has(record_id):
		return snapshot
	var cand: Dictionary = CHARACTER_ARTIFACTS[record_id]
	if cand.get("Owner") != owner or cand.get("Type") != slot_type:
		return snapshot
	cand["Equipped"] = owner
	CHARACTER_ARTIFACTS[record_id] = cand

	calculate_all_stats()
	var preview = {
		"Health": Current_Health,
		"Attack": Current_Attack,
		"Defense": Current_Defense,
		"Elemental Mastery": Current_Elemental_Mastery,
		"Energy Recharge": Current_Energy_Recharge,
		"Critical Damage": Current_Critical_Damage
	}

	for rid2 in CHARACTER_ARTIFACTS.keys():
		var rec2: Dictionary = CHARACTER_ARTIFACTS[rid2]
		if rec2.get("Owner") == owner and rec2.get("Type") == slot_type:
			rec2["Equipped"] = null
			CHARACTER_ARTIFACTS[rid2] = rec2
	if prev_equipped != "":
		var prev: Dictionary = CHARACTER_ARTIFACTS[prev_equipped]
		prev["Equipped"] = owner
		CHARACTER_ARTIFACTS[prev_equipped] = prev

	Current_Health = snapshot["Health"]
	Current_Attack = snapshot["Attack"]
	Current_Defense = snapshot["Defense"]
	Current_Elemental_Mastery = snapshot["Elemental Mastery"]
	Current_Energy_Recharge = snapshot["Energy Recharge"]
	Current_Critical_Damage = snapshot["Critical Damage"]

	return preview

# ─── LOGGING (network-aware) ───

func Log(category: String, action: String, related_type: String = "", related_id: String = "",
		 old_values: Dictionary = {}, new_values: Dictionary = {}, metadata: Dictionary = {},
		 result: String = "success", severity: String = "audit") -> void:

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
	NetworkManager.host_log(payload)


func CombatLog(battle_id, turn_no: int, phase: String, actor_type: String, actor_id: String,
			   action_type: String, action_name: String, target_id: String, ignores_def: bool,
			   rolls: Dictionary, damage: int, hp_before: int, hp_after: int, energy_change: int,
			   elements_applied: Array = [], status_changes: Dictionary = {}, misc: Dictionary = {}) -> void:

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
	NetworkManager.host_combat_log(payload)
