extends Node
## Manages the save file + loads base resources from data/resources/.
## Base data lives as .tres files in the project. Save file holds mutable overrides.

const SAVE_PATH = "user://save.tres"
const SAVE_BACKUP = "user://save.tres.bak"
const SAVE_TMP = "user://save.tres.tmp"
const RES_DIR = "res://data/resources/"

var data: SaveData = null
var _is_host: bool = false

# ── Loaded base resources ────────────────────────────────────────────────────
var players: Dictionary = {}          # name → PlayerData
var companions: Dictionary = {}       # name → CompanionSaveData
var owned_weapons: Array = []         # Array of OwnedWeapon
var owned_artifacts: Array = []       # Array of OwnedArtifact
var owned_items: Array = []           # Array of OwnedItem
var party: PartySaveData = null

signal save_loaded
signal save_updated

func set_host(value: bool) -> void:
	_is_host = value

# ── Load ─────────────────────────────────────────────────────────────────────

func load_save() -> void:
	# 1. Load base resources from .tres files
	_load_base_resources()

	# 2. If no base resources exist, run migration to create them
	if players.size() == 0:
		print("SaveManager: no player resources found, running migration...")
		# Delete any stale save file from old format
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(SAVE_PATH)
		data = SaveMigration.migrate()
		# Reload the newly created .tres files
		_load_base_resources()
		if _is_host:
			save_to_disk()
	else:
		# 3. Load save file (mutable overrides). Try main, then backup.
		if FileAccess.file_exists(SAVE_PATH):
			var loaded = load(SAVE_PATH)
			if loaded is SaveData:
				data = loaded
				print("SaveManager: loaded save overrides from %s" % SAVE_PATH)
			else:
				push_error("SaveManager: %s exists but failed to deserialize as SaveData — trying backup" % SAVE_PATH)
		if data == null and FileAccess.file_exists(SAVE_BACKUP):
			var loaded = load(SAVE_BACKUP)
			if loaded is SaveData:
				data = loaded
				push_warning("SaveManager: recovered save from backup %s" % SAVE_BACKUP)
			else:
				push_error("SaveManager: backup %s also failed to deserialize" % SAVE_BACKUP)
		if data == null:
			push_warning("SaveManager: no valid save found — starting with empty SaveData")
			data = SaveData.new()

	# 4. Apply save overrides on top of base resources
	_apply_overrides()

	print("SaveManager: ready — %d players, %d companions, %d weapons, %d artifacts, %d items" % [
		players.size(), companions.size(), owned_weapons.size(),
		owned_artifacts.size(), owned_items.size()
	])
	emit_signal("save_loaded")

func _load_base_resources() -> void:
	# Players
	players.clear()
	for res in _load_folder(RES_DIR + "players/"):
		if res is PlayerData:
			players[res.name] = res

	# Companions
	companions.clear()
	for res in _load_folder(RES_DIR + "companions/"):
		if res is CompanionSaveData:
			companions[res.name] = res

	# Owned weapons
	owned_weapons.clear()
	for res in _load_folder(RES_DIR + "inventory/weapons/"):
		if res is OwnedWeapon:
			owned_weapons.append(res)

	# Owned artifacts
	owned_artifacts.clear()
	for res in _load_folder(RES_DIR + "inventory/artifacts/"):
		if res is OwnedArtifact:
			owned_artifacts.append(res)

	# Owned items
	owned_items.clear()
	for res in _load_folder(RES_DIR + "inventory/items/"):
		if res is OwnedItem:
			owned_items.append(res)

	# Party
	var party_res = _load_folder(RES_DIR + "party/")
	if party_res.size() > 0 and party_res[0] is PartySaveData:
		party = party_res[0]
	else:
		party = PartySaveData.new()

func _apply_overrides() -> void:
	if data == null:
		return

	# Player combat state
	for player_name in data.player_state:
		var p = players.get(player_name)
		if p == null:
			continue
		var state: Dictionary = data.player_state[player_name]
		if state.has("current_health"): p.current_health = int(state["current_health"])
		if state.has("max_health"): p.max_health = int(state["max_health"])
		if state.has("burst_charges"): p.burst_charges = int(state["burst_charges"])
		if state.has("shield_health"): p.shield_health = int(state["shield_health"])
		if state.has("shield_duration"): p.shield_duration = int(state["shield_duration"])
		if state.has("applied_element"): p.applied_element = str(state["applied_element"])
		if state.has("skipped"): p.skipped = bool(state["skipped"])
		if state.has("skip_duration"): p.skip_duration = int(state["skip_duration"])
		if state.has("ready"): p.ready = bool(state["ready"])

	# Companion state
	for comp_name in data.companion_state:
		var c = companions.get(comp_name)
		if c == null:
			continue
		var state: Dictionary = data.companion_state[comp_name]
		if state.has("current_health"): c.current_health = int(state["current_health"])
		if state.has("max_health"): c.max_health = int(state["max_health"])
		if state.has("burst_charges"): c.burst_charges = int(state["burst_charges"])
		if state.has("shield_health"): c.shield_health = int(state["shield_health"])
		if state.has("shield_duration"): c.shield_duration = int(state["shield_duration"])
		if state.has("applied_element"): c.applied_element = str(state["applied_element"])
		if state.has("active"): c.active = bool(state["active"])
		if state.has("player_chosen"): c.player_chosen = bool(state["player_chosen"])
		# Absent in saves written before the field existed — the .tres catalog
		# value then stands, which is what seeds Ayaka as deceased.
		if state.has("deceased"): c.deceased = bool(state["deceased"])
		if state.has("owner"): c.owner = str(state["owner"])

	# Weapon overrides (equipped, owner)
	for w in owned_weapons:
		var slug = _slugify(w.owner + " " + w.weapon_name)
		if data.weapon_overrides.has(slug):
			var ov: Dictionary = data.weapon_overrides[slug]
			if ov.has("equipped"): w.equipped = bool(ov["equipped"])
			if ov.has("owner"): w.owner = str(ov["owner"])

	# Artifact overrides
	for a in owned_artifacts:
		var type_short = a.type.split(" ")[0] if a.type != "" else "unknown"
		var slug = _slugify(a.owner + " " + a.artifact_set + " " + type_short)
		if data.artifact_overrides.has(slug):
			var ov: Dictionary = data.artifact_overrides[slug]
			if ov.has("equipped"): a.equipped = bool(ov["equipped"])
			if ov.has("owner"): a.owner = str(ov["owner"])

	# Item quantities
	for item in owned_items:
		var slug = _slugify(item.owner + " " + item.item_name)
		if data.item_quantities.has(slug):
			var ov: Dictionary = data.item_quantities[slug]
			if ov.has("quantity"): item.quantity = int(ov["quantity"])
			if ov.has("owner"): item.owner = str(ov["owner"])

	# Party mutable state
	if party:
		party.mora = data.party_mora
		party.current_turn = data.party_current_turn
		party.active_food_buff = data.party_active_food_buff
		party.buff_battles_left = data.party_buff_battles_left
		party.gambles = data.party_gambles
		party.active_battle_id = data.party_active_battle_id
		if data.party_turn_order.size() > 0:
			party.turn_order = data.party_turn_order

# ── Save ─────────────────────────────────────────────────────────────────────

func save_to_disk() -> void:
	if not _is_host or data == null:
		return
	_sync_to_save()
	# Write to a tmp file first so a mid-write crash never corrupts SAVE_PATH.
	# Only after the tmp write succeeds do we promote the previous save to the
	# .bak slot and replace SAVE_PATH with the new contents.
	var err = ResourceSaver.save(data, SAVE_TMP)
	if err != OK:
		push_error("SaveManager: save failed (error %d) — SAVE_PATH untouched" % err)
		return
	if FileAccess.file_exists(SAVE_PATH):
		var backup_err = DirAccess.copy_absolute(SAVE_PATH, SAVE_BACKUP)
		if backup_err != OK:
			push_warning("SaveManager: could not promote SAVE_PATH to backup (error %d)" % backup_err)
	var promote_err = DirAccess.copy_absolute(SAVE_TMP, SAVE_PATH)
	if promote_err != OK:
		push_error("SaveManager: could not promote tmp save to SAVE_PATH (error %d) — previous save preserved" % promote_err)
		return
	DirAccess.remove_absolute(SAVE_TMP)
	print("SaveManager: saved to disk")

## Sync current resource state back to the save file's override dictionaries.
func _sync_to_save() -> void:
	# Player state
	for p in players.values():
		data.player_state[p.name] = {
			"current_health": p.current_health,
			"max_health": p.max_health,
			"burst_charges": p.burst_charges,
			"shield_health": p.shield_health,
			"shield_duration": p.shield_duration,
			"applied_element": p.applied_element,
			"skipped": p.skipped,
			"skip_duration": p.skip_duration,
			"ready": p.ready,
		}

	# Companion state
	for c in companions.values():
		data.companion_state[c.name] = {
			"current_health": c.current_health,
			"max_health": c.max_health,
			"burst_charges": c.burst_charges,
			"shield_health": c.shield_health,
			"shield_duration": c.shield_duration,
			"applied_element": c.applied_element,
			"active": c.active,
			"player_chosen": c.player_chosen,
			"deceased": c.deceased,
			"owner": c.owner,
		}

	# Weapon state
	data.weapon_overrides.clear()
	for w in owned_weapons:
		var slug = _slugify(w.owner + " " + w.weapon_name)
		data.weapon_overrides[slug] = {"equipped": w.equipped, "owner": w.owner}

	# Artifact state
	data.artifact_overrides.clear()
	for a in owned_artifacts:
		var type_short = a.type.split(" ")[0] if a.type != "" else "unknown"
		var slug = _slugify(a.owner + " " + a.artifact_set + " " + type_short)
		data.artifact_overrides[slug] = {"equipped": a.equipped, "owner": a.owner}

	# Item state
	data.item_quantities.clear()
	for item in owned_items:
		var slug = _slugify(item.owner + " " + item.item_name)
		data.item_quantities[slug] = {"quantity": item.quantity, "owner": item.owner}

	# Party
	if party:
		data.party_mora = party.mora
		data.party_current_turn = party.current_turn
		data.party_active_food_buff = party.active_food_buff
		data.party_buff_battles_left = party.buff_battles_left
		data.party_gambles = party.gambles
		data.party_active_battle_id = party.active_battle_id
		data.party_turn_order = party.turn_order.duplicate()

	# Map markers (kept in data.map_markers directly, no separate runtime copy)

func mark_dirty() -> void:
	emit_signal("save_updated")
	if _is_host:
		save_to_disk()

## Replace save data entirely (used when client receives from host).
func apply_save(new_data: SaveData) -> void:
	data = new_data
	_apply_overrides()
	emit_signal("save_loaded")

# ── Access ───────────────────────────────────────────────────────────────────

func get_player(name: String) -> PlayerData:
	return players.get(name, null)

func get_all_players() -> Array:
	return players.values()

func get_companion(name: String) -> CompanionSaveData:
	return companions.get(name, null)

func get_all_companions() -> Array:
	return companions.values()

func get_party() -> PartySaveData:
	return party

func get_equipped_weapon(owner: String) -> OwnedWeapon:
	for w in owned_weapons:
		if w.owner == owner and w.equipped:
			return w
	return null

func get_equipped_artifacts(owner: String) -> Array:
	var result = []
	for a in owned_artifacts:
		if a.owner == owner and a.equipped:
			result.append(a)
	return result

func get_items_for(owner: String) -> Array:
	var result = []
	for item in owned_items:
		if item.owner == owner and item.quantity > 0:
			result.append(item)
	return result

func get_all_owned_weapons() -> Array:
	return owned_weapons

func get_all_owned_artifacts() -> Array:
	return owned_artifacts

func get_all_owned_items() -> Array:
	return owned_items

# ── Serialization for network ────────────────────────────────────────────────

func serialize_for_network() -> PackedByteArray:
	_sync_to_save()
	var temp_path = "user://save_sync_temp.tres"
	ResourceSaver.save(data, temp_path)
	var file = FileAccess.open(temp_path, FileAccess.READ)
	var bytes = file.get_buffer(file.get_length())
	file.close()
	return bytes

func deserialize_from_network(bytes: PackedByteArray) -> void:
	var temp_path = "user://save_sync_temp.tres"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var loaded = load(temp_path)
	if loaded is SaveData:
		apply_save(loaded)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _load_folder(path: String) -> Array:
	var results = []
	var dir = DirAccess.open(path)
	if dir == null:
		push_warning("SaveManager: cannot open resource folder %s" % path)
		return results
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res = load(path + fname)
			if res != null:
				results.append(res)
			else:
				push_error("SaveManager: failed to load %s%s — file may be corrupted or class missing" % [path, fname])
		fname = dir.get_next()
	dir.list_dir_end()
	return results

# ── Map Markers ──────────────────────────────────────────────────────────────

func get_map_markers() -> Dictionary:
	if data == null:
		return {}
	return data.map_markers

func get_player_markers(player_name: String) -> Array:
	if data == null:
		return []
	return data.map_markers.get(player_name, [])

func set_player_markers(player_name: String, markers: Array) -> void:
	if data == null:
		data = SaveData.new()
	data.map_markers[player_name] = markers
	mark_dirty()

func set_all_markers(all_markers: Dictionary) -> void:
	if data == null:
		data = SaveData.new()
	data.map_markers = all_markers
	mark_dirty()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _slugify(text: String) -> String:
	var s = text.strip_edges().to_lower()
	s = s.replace("'", "").replace("\"", "").replace("(", "").replace(")", "")
	s = s.replace(" ", "_").replace("-", "_").replace(",", "").replace(".", "")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	s = regex.sub(s, "", true)
	while s.contains("__"):
		s = s.replace("__", "_")
	return s.trim_prefix("_").trim_suffix("_")
