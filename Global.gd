extends Node

var ACTIVE_USER_EMAIL: String = ""
var ACTIVE_USER_NAME: String = ""
var TABLES: Array = ["Artifacts","Reactions","Weapons","Abilities","Companions","Crafting_Recipes","Items","Enemies","Characters","BattleEnemies","Character_Items","Character_Weapons", "Character_Artifacts","Battle_Log","Talents","Constellations"]
var joined = ",".join(TABLES)
var ARTIFACTS: Dictionary = {}
var REACTIONS: Dictionary = {}
var WEAPONS: Dictionary = {}
var ABILITIES: Dictionary = {}
var COMPANIONS: Dictionary = {}
var CRAFTINGRECIPES: Dictionary = {}
var ITEMS: Dictionary = {}
var ENEMIES: Dictionary = {}
var CHARACTERS: Dictionary = {}
var BATTLEENEMIES: Dictionary = {}
var CHARACTER_ITEMS: Dictionary = {}
var CHARACTER_WEAPONS: Dictionary = {}
var CHARACTER_ARTIFACTS: Dictionary = {}
var TALENTS = {}
var CONSTELLATIONS = {}
var BATTLE_LOG: Dictionary = {}
var ARTIFACTS_NAME = {}
var WEAPONS_NAME = {}
var COMPANIONS_NAME = {}
var CRAFTINGRECIPES_NAME = {}
var ITEMS_NAME = {}
var ENEMIES_NAME = {}
var CHARACTERS_NAME = {}
var BATTLEENEMIES_NAME = {}
var TABLES_TO_SAVE = ["Characters","BattleEnemies","Character Items","Character_Weapons", "Character_Artifacts","Battle_Log", "Companions"] #When you save also force a manual re-sync
var TABLES_TO_SYNC_OFTEN = ["Characters","BattleEnemies"] #Resycnc often while in battles.
var BATTLE_TURN_ORDER = []
var _current_region = ""
var Current_Health
var Current_Attack
var Current_Defense
var Current_Elemental_Mastery
var Current_Energy_Recharge
var Current_Critical_Damage
var Current_Weapon
var Polling_Timer
var set_count = {}
var set_pieces 
var total_records
var variable_name
var request_start_time
var elapsed
var set_modifiers := {}
var artifact_set_calculated = 0
var Region_Changed = 1
var watched_tables := [
	"Characters",
	"Character_Items",
	"Character_Weapons",
	"Character_Artifacts",
	"Talents",
	"Constellations",
	"BattleEnemies"
]
var last_known_timestamps := {}  # Dictionary<String, String>
var APPLIED_ARTIFACT_BONUSES := {}  # key: character name, value: list of {stat: ..., amount: ...}
var FINAL_CHARACTER_STATS := {}  # key: char name, value: dict of {stat: total value}
var known_bonus_fields = []
var Current_Region:
	get:
		return _current_region
	set(value):
		if _current_region != value:
			_current_region = value
			# This fires on *any* change to the variable
			Region_Changed = 1
signal table_loaded(table_name: String, records_loaded: int)
signal data_load_complete

const API_BASE: String = "https://api.mydndbackend.party"





#When downloading/referencing files downloaded from online they sometimes contain hidden symbols or charaacters in their name, this function removes any hidden characters
#For scenarios where you encounter them.
func normalize_text_filename(weapon_name: String) -> String:
	var cleaned := weapon_name.strip_edges().to_lower()

	# Handle known invisible/Unicode-breaking characters
	cleaned = cleaned.replace(" ", " ")  # U+00A0 non-breaking space
	cleaned = cleaned.replace("­", "")   # U+00AD soft hyphen
	cleaned = cleaned.replace("’", "")   # curly apostrophe
	cleaned = cleaned.replace(" ", "-")

	# Compile a regex to remove any non a–z, 0–9, or dash
	var regex := RegEx.new()
	regex.compile("[^a-z0-9-]")

	cleaned = regex.sub(cleaned, "", true)

	return cleaned + ".png"

func calculate_all_stats() -> void:
	var ACTIVE_CHARACTER_ID = CHARACTERS_NAME[ACTIVE_USER_NAME]
	var character = CHARACTERS[ACTIVE_CHARACTER_ID]
	Current_Region = CHARACTERS[CHARACTERS_NAME[ACTIVE_USER_NAME]].get("Current_Region")
	var scaling = {
		"Health": 2.0,
		"Attack": 1.0,
		"Defense": 1.0,
		"Elemental_Mastery": 1.0,
		"Energy_Recharge": 0.1,
		"Critical_Damage": 0.1,
	}
	var bonus_suffixes = [
		"Added_Stat_Bonus",
		"Multiplier_Stat_Bonus",
		"Added_Roll_Bonus",
		"Multiplier_Roll_Bonus",
		"Added_Damage_Bonus",
		"Multiplier_Damage_Bonus"
	]
	# STEP 1: Reset old set bonuses (clear all known artifact-related bonus fields)
	if known_bonus_fields.size() == 0:
		for stat in scaling.keys():
				for suffix in bonus_suffixes:
					known_bonus_fields.append("%s_%s" % [stat, suffix])

	for bonus_field in known_bonus_fields:
		character[bonus_field] = 0

	# STEP 2: Count equipped set pieces
	var set_pieces = {}
	for key in set_count:
		set_count[key] = 0
	for artifact in CHARACTER_ARTIFACTS.values():
		if artifact.get("Owner") == ACTIVE_USER_NAME and artifact.get("Equipped") == true:
			var set_name = artifact.get("Artifact_Set")
			set_pieces[set_name] = set_pieces.get(set_name, 0) + 1
			set_count[set_name] = set_count.get(set_name, 0) + 1

	# STEP 3: Apply set effects
	for artifact_set in set_pieces.keys():
		for DBset in ARTIFACTS.values():
			if artifact_set == DBset.get("Artifact_Set") and set_pieces[artifact_set] >= DBset.get("Bonus_Type"):
				var stat = DBset.get("Stat_Modifier")
				var value = DBset.get("Stat_Modifier_Value")
				var condition = DBset.get("Condition")
				var condition_val = DBset.get("Condition_Value")

				if stat == null or stat == "":
					continue  # Skip sets that don't modify a stat

				# Check if set condition (e.g., "Element" == "Electric") is met
				var meets_condition = true
				if condition != null and condition != "":
					var char_value = character.get(condition)
					meets_condition = char_value == condition_val

				if meets_condition:
					character[stat] = character.get(stat, 0) + value  # ✅ Write to CHARACTERS dict

	# STEP 4: Final calculated stat values (includes everything)
	for stat in scaling.keys():
		var base = character.get("%s_Base_Points" % stat, 0)
		var skill = character.get("%s_Skill_Points" % stat, 0)
		var added = character.get("%s_Added_Stat_Bonus" % stat, 0)
		var multiplier = character.get("%s_Multiplier_Stat_Bonus" % stat, 1.0)

		var value = ((base + skill) * scaling[stat]) + added

		# Apply weapon bonuses
		for weapon in CHARACTER_WEAPONS.values():
			if weapon.get("Owner") == ACTIVE_USER_NAME and weapon.get("Equipped") == true:
				Global.Current_Weapon = weapon
				for i in range(1, 4):
					if weapon.get("Stat_%d_Type" % i) == stat:
						value += weapon.get("Stat_%d_Value" % i, 0)

		# Apply artifact bonuses
		for artifact in CHARACTER_ARTIFACTS.values():
			if artifact.get("Owner") == ACTIVE_USER_NAME and artifact.get("Equipped") == true:
				for i in range(1, 3):
					if artifact.get("Stat_%d_Type" % i) == stat:
						value += artifact.get("Stat_%d_Value" % i, 0)

		# Apply final multiplier
		value *= (multiplier + 1.0)

		variable_name = stat.replace(" ", "_")
		Global.set("Current_%s" % variable_name, snapped(value, 0.01))

# ------------------------------
# POLLING + TIMESTAMP UTILITIES
# ------------------------------

# How long to ignore poll-triggered refreshes after a local write to that table
const STALE_GUARD_MS: int = 2000

# Last local write time per table (set this whenever you submit an update touching that table)
var last_local_write_ms: Dictionary = {}  # table_name -> ms

# Timestamps we *intend* to accept once the refresh completes successfully
var pending_timestamps: Dictionary = {}   # table_name -> timestamp (string)

# (Optional) per-field guard if you want to block specific stale fields in Refresh_Data
var last_local_field_touch_ms: Dictionary = {}  # "%s|%s" % [record_id, field] -> ms

func note_local_field_write(record_id: String, field: String) -> void:
	last_local_field_touch_ms["%s|%s" % [record_id, field]] = Time.get_ticks_msec()

func _should_accept_field(record_id: String, field: String) -> bool:
	var key := "%s|%s" % [record_id, field]
	var t := int(last_local_field_touch_ms.get(key, 0))
	return t == 0 or (Time.get_ticks_msec() - t) >= STALE_GUARD_MS

func _merge_fields(target: Dictionary, rec_id: String, incoming: Dictionary) -> void:
	# Merge field-by-field; skip very recent local edits.
	for f in incoming.keys():
		if _should_accept_field(rec_id, String(f)):
			target[String(f)] = incoming[f]

# --- Timestamp parsing (handles "Z" and timezone offsets with microseconds) ---
func _iso_to_unix_ms(iso: String) -> int:
	if iso == null or iso == "" or iso == "null":
		return 0
	# Let Godot parse to a datetime dict (treat as UTC once normalized)
	var dt := Time.get_datetime_dict_from_datetime_string(iso, true)
	return int(Time.get_unix_time_from_datetime_dict(dt) * 1000.0)

# ------------------------------
# REQUESTS
# ------------------------------

func _check_modified_batch():
	var http := HTTPRequest.new()
	add_child(http)

	var table_json = JSON.stringify(watched_tables)
	var url = API_BASE + "/check_modified_batch?tables=" + table_json

	# per-request timing stored on the node to avoid overlap bugs
	http.set_meta("t0_ms", Time.get_ticks_msec())
	http.request_completed.connect(_on_check_modified_batch_response.bind(http))
	http.request(url)

func _on_check_modified_batch_response(result, code, headers, body, request_node: HTTPRequest) -> void:
	# timing
	var t0_ms := int(request_node.get_meta("t0_ms", Time.get_ticks_msec()))
	var elapsed_s = max((Time.get_ticks_msec() - t0_ms) / 1000.0, 0.000001)
	var bytes_received = body.size()
	var kbps = (bytes_received / 1024.0) / elapsed_s

	#print("Request completed in %.2f seconds" % elapsed_s)
	#print("Data received: %.2f KB" % (bytes_received / 1024.0))
	#print("Average speed: %.2f KB/s" % kbps)

	request_node.queue_free()

	if code != 200:
		print("❌ Failed to check modified batch:", code)
		print(body.get_string_from_utf8())
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		return

	var now_ms: int = Time.get_ticks_msec()
	var immediate_tables: Array = []
	var deferred: Array = []  # [ [table_name, new_timestamp, wait_ms] ]

	for table_name in data.keys():
		var raw = data[table_name]
		if raw == null:
			continue

		var new_ts: String = str(raw)                          # e.g. 2025-08-08T18:07:39.867542-06:00
		var prev_ts: String = str(last_known_timestamps.get(table_name, ""))

		# First time seeing this table: just remember the server value, don't fetch.
		if prev_ts == "" or prev_ts == "null":
			last_known_timestamps[table_name] = new_ts
			continue

		var new_ms := _iso_to_unix_ms(new_ts)
		var prev_ms := _iso_to_unix_ms(prev_ts)

		# No change (or equal down to ms)
		if new_ms <= prev_ms:
			continue

		# Change detected — check if we *just* wrote to this table locally.
		var last_write_ms: int = int(last_local_write_ms.get(table_name, 0))
		var age_ms: int = now_ms - last_write_ms

		if last_write_ms > 0 and age_ms < STALE_GUARD_MS:
			var wait_ms: int = STALE_GUARD_MS - age_ms
			deferred.append([table_name, new_ts, wait_ms])
		else:
			immediate_tables.append(table_name)
			pending_timestamps[table_name] = new_ts  # only commit after refresh succeeds

	# Kick immediate refresh (no poll overlap, per your pause logic)
	if immediate_tables.size() > 0:
		Global.Refresh_Data(immediate_tables)

	# Schedule deferred refreshes so we don't read during the stale window
	for item in deferred:
		var tname: String = item[0]
		var nts: String = item[1]
		var wait_ms: int = item[2]
		_schedule_delayed_refresh(tname, nts, wait_ms)

func _schedule_delayed_refresh(table_name: String, new_ts: String, wait_ms: int) -> void:
	pending_timestamps[table_name] = new_ts
	var timer: SceneTreeTimer = get_tree().create_timer(float(wait_ms) / 1000.0)
	await timer.timeout
	Global.Refresh_Data([table_name])

func Refresh_Data(table_list: Array) -> void:
	if table_list.is_empty():
		push_error("Refresh_Data called with an empty table list.")
		return

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
		push_error("❌ Failed to start combined fetch. Error: " + str(err))
		return

	print("➡️ GET:", url)

func _on_all_tables_loaded(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, requested_tables: Array = []):
	elapsed = (Time.get_ticks_msec() / 1000.0) - request_start_time
	var bytes_received = body.size()
	var kbps = (bytes_received/1024) / elapsed
	print("Request completed in %.2f seconds" % elapsed)
	print("Data received: %.2f KB" % (bytes_received / 1024.0))
	print("Average speed: %.2f KB/s" % kbps)
	http.queue_free()
	if code != 200:
		print("❌ Failed to fetch combined tables. Code:", code)
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		print("❌ JSON parse failed.")
		return
	total_records = 0
	for table_name in data.keys():
		var records = data[table_name]
		_process_table(table_name, records)
		

	calculate_all_stats()
	Current_Region = CHARACTERS[CHARACTERS_NAME[ACTIVE_USER_NAME]].get("Current_Region")

	# ✅ commit versions only after successful apply
	for t in requested_tables:
		if pending_timestamps.has(t):
			last_known_timestamps[t] = pending_timestamps[t]
			pending_timestamps.erase(t)

	emit_signal("data_load_complete")

func _commit_pending_timestamps(tables: Array) -> void:
	for t in tables:
		if pending_timestamps.has(t):
			last_known_timestamps[t] = String(pending_timestamps[t])
			pending_timestamps.erase(t)

func _process_table(table_name: String, records: Array) -> void:
	match table_name:
		"Characters":
			for record in records:
				CHARACTERS[str(record["id"])] = record
				CHARACTERS_NAME[record["Name"]] = str(record["id"])

		"Weapons":
			for record in records:
				WEAPONS[str(record["id"])] = record

		"Artifacts":
			for record in records:
				ARTIFACTS[str(record["id"])] = record

		"Reactions":
			for record in records:
				REACTIONS[str(record["id"])] = record

		"Abilities":
			for record in records:
				ABILITIES[str(record["id"])] = record

		"Companions":
			for record in records:
				COMPANIONS[str(record["id"])] = record

		"Crafting_Recipes":
			for record in records:
				CRAFTINGRECIPES[str(record["id"])] = record

		"Items":
			for record in records:
				ITEMS[str(record["id"])] = record

		"Enemies":
			for record in records:
				ENEMIES[str(record["id"])] = record

		"BattleEnemies":
			for record in records:
				BATTLEENEMIES[str(record["id"])] = record

		"Character_Weapons":
			for record in records:
				CHARACTER_WEAPONS[str(record["id"])] = record

		"Character_Artifacts":
			for record in records:
				CHARACTER_ARTIFACTS[str(record["id"])] = record

		"Character Items":
			for record in records:
				CHARACTER_ITEMS[str(record["id"])] = record

		"Talents":
			for record in records:
				TALENTS[str(record["id"])] = record

		"Constellations":
			for record in records:
				CONSTELLATIONS[str(record["id"])] = record

		_:
			pass

	emit_signal("table_loaded", table_name, records.size())
	print("✅ Parsed table: ", table_name, " with ", records.size(), " records.")
	total_records += records.size()

func _apply_local_update(table_name: String, record_id: String, field: String, value) -> void:
	match table_name:
		"Characters":
			if not CHARACTERS.has(record_id): CHARACTERS[record_id] = {}
			CHARACTERS[record_id][field] = value

		"Character Weapons":
			if not CHARACTER_WEAPONS.has(record_id): CHARACTER_WEAPONS[record_id] = {}
			CHARACTER_WEAPONS[record_id][field] = value

		"Character Artifacts":
			if not CHARACTER_ARTIFACTS.has(record_id): CHARACTER_ARTIFACTS[record_id] = {}
			CHARACTER_ARTIFACTS[record_id][field] = value

		"Character Items":
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

		# add others only if you actually edit them from the UI
		_:
			pass

func Update_Records(updates: Array) -> void:
	# Pause poller like you already do
	Global.Polling_Timer.paused = true

	# ✅ Only tag; do NOT modify your local dictionaries here
	for u in updates:
		if u.has("record_id") and u.has("field"):
			note_local_field_write(str(u["record_id"]), u["field"])

	var http_request = HTTPRequest.new()
	add_child(http_request)
	var url = API_BASE+"/update_records"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({ "updates": updates })
	request_start_time = Time.get_ticks_msec() / 1000.0  # seconds
	http_request.request_completed.connect(_on_multi_update_response.bind(http_request))
	http_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

func _on_multi_update_response(result, code, headers, body, request_node):
	elapsed = (Time.get_ticks_msec() / 1000.0) - request_start_time
	var bytes_received = body.size()
	var kbps = (bytes_received/1024) / elapsed
	print("Request completed in %.2f seconds" % elapsed)
	print("Data received: %.2f KB" % (bytes_received / 1024.0))
	print("Average speed: %.2f KB/s" % kbps)
	
	request_node.queue_free()
	if code != 200:
		print("❌ Failed to update records.")
		print(body.get_string_from_utf8())
		return

	var tables_to_refresh: Array = []
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("updated"):
		for update in json["updated"]:
			var t = String(update.get("table",""))
			var ts = String(update.get("modified_time",""))
			if t != "" and not tables_to_refresh.has(t):
				tables_to_refresh.append(t)
				# ✅ stash; commit after refresh succeeds
				pending_timestamps[t] = ts

	Global.Refresh_Data(tables_to_refresh)
# Put near the top of Global.gd
const ARTIFACT_TYPE_MAP = {
	"Flower":  "Flower of Life",
	"Feather": "Feather of Death",
	"Sands":   "Sands of Time",
	"Goblet":  "Goblet of Space",
	"Circlet": "Circlet of Principles"
}

func slot_label_to_type(slot_short: String) -> String:
	return ARTIFACT_TYPE_MAP.get(slot_short, slot_short)

# Equip artifact for ACTIVE_USER_NAME in a given slot type ("Feather of Death", etc.)
func equip_artifact(slot_type: String, record_id: String) -> bool:
	if not CHARACTER_ARTIFACTS.has(record_id):
		return false
	var owner = ACTIVE_USER_NAME

	# Unequip any current in this slot
	for rid in CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = CHARACTER_ARTIFACTS[rid]
		if rec.get("Owner") == owner and rec.get("Type") == slot_type:
			rec["Equipped"] = null
			CHARACTER_ARTIFACTS[rid] = rec

	# Equip the target
	var sel: Dictionary = CHARACTER_ARTIFACTS[record_id]
	if sel.get("Owner") != owner or sel.get("Type") != slot_type:
		return false
	sel["Equipped"] = owner
	CHARACTER_ARTIFACTS[record_id] = sel

	# Recalculate overall stats
	calculate_all_stats()
	return true

# Non-destructive preview: returns a dict of final stats if this record were equipped
func preview_stats_with_artifact(slot_type: String, record_id: String) -> Dictionary:
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

	# Remember what is currently equipped in this slot
	var prev_equipped: String = ""
	for rid in CHARACTER_ARTIFACTS.keys():
		var rec: Dictionary = CHARACTER_ARTIFACTS[rid]
		if rec.get("Owner") == owner and rec.get("Type") == slot_type:
			if rec.get("Equipped") == owner or rec.get("Equipped") == true:
				prev_equipped = rid
			rec["Equipped"] = null
			CHARACTER_ARTIFACTS[rid] = rec

	# Temporarily equip candidate
	if not CHARACTER_ARTIFACTS.has(record_id):
		return snapshot # nothing to preview; fall back to current
	var cand: Dictionary = CHARACTER_ARTIFACTS[record_id]
	if cand.get("Owner") != owner or cand.get("Type") != slot_type:
		return snapshot
	cand["Equipped"] = owner
	CHARACTER_ARTIFACTS[record_id] = cand

	# Recompute
	calculate_all_stats()
	var preview = {
		"Health": Current_Health,
		"Attack": Current_Attack,
		"Defense": Current_Defense,
		"Elemental Mastery": Current_Elemental_Mastery,
		"Energy Recharge": Current_Energy_Recharge,
		"Critical Damage": Current_Critical_Damage
	}

	# Restore equip state
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

	# 3) restore current totals
	Current_Health = snapshot["Health"]
	Current_Attack = snapshot["Attack"]
	Current_Defense = snapshot["Defense"]
	Current_Elemental_Mastery = snapshot["Elemental Mastery"]
	Current_Energy_Recharge = snapshot["Energy Recharge"]
	Current_Critical_Damage = snapshot["Critical Damage"]

	return preview
