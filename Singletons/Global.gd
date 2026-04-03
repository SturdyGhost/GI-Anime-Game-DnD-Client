extends Node
## COMPATIBILITY SHIM — delegates to SaveManager, CharacterManager, etc.
## Existing scenes reference Global.*; this forwards to the new managers.
## New code should use managers directly, not Global.

# ── Session state (stays here — not persisted, set at login) ─────────────────
var ACTIVE_USER_EMAIL: String = ""
var ACTIVE_USER_NAME: String = ""
var ACTIVE_USER_TYPE: String = ""
var ACTIVE_USER_RECORD_ID: int = 0
var PublicIP = ""
var Luck_Set: bool = false
var Region_Changed: int = 1
var _returned_from_battle: bool = false

## Returns effective luck for a player, factoring in Bennett's party penalty.
## If Bennett is an active chosen companion, all luck is reduced by 25%.
func get_effective_luck(player_name: String) -> int:
	var p = SaveManager.get_player(player_name)
	if p == null:
		return 50
	var luck = p.daily_luck
	# Bennett penalty: if Bennett is active+chosen, reduce luck by 25%
	var bennett = SaveManager.get_companion("Bennett")
	if bennett != null and bennett.active and bennett.player_chosen:
		luck = int(round(float(luck) * 0.75))
	return luck

# ── Synced table data (populated by host on both host+client via _process_table)
var _synced: Dictionary = {}          # { "TableName": { "rid": {record}, ... } }
var _synced_name: Dictionary = {}     # { "TableName": { "Name": "rid", ... } }  (only for tables with Name field)

# ── Signals (kept for backward compat — scenes await these) ─────────────────
signal table_loaded(table_name: String, records_loaded: int)
signal data_load_complete
signal insert_finished(correlation_id: String, table: String, record_id: int, payload: Dictionary, ok: bool)

# ── Legacy computed stats (delegate to CharacterManager) ─────────────────────
var Current_Health: float:
	get: var s = CharacterManager.get_stats(ACTIVE_USER_NAME); return s.health if s else 0.0
var Current_Attack: float:
	get: var s = CharacterManager.get_stats(ACTIVE_USER_NAME); return s.attack if s else 0.0
var Current_Defense: float:
	get: var s = CharacterManager.get_stats(ACTIVE_USER_NAME); return s.defense if s else 0.0
var Current_Elemental_Mastery: float:
	get: var s = CharacterManager.get_stats(ACTIVE_USER_NAME); return s.elemental_mastery if s else 0.0
var Current_Energy_Recharge: float:
	get: var s = CharacterManager.get_stats(ACTIVE_USER_NAME); return s.energy_recharge if s else 0.0
var Current_Critical_Damage: float:
	get: var s = CharacterManager.get_stats(ACTIVE_USER_NAME); return s.critical_damage if s else 0.0

var _current_region: String = ""
var Current_Region: String:
	get: return _current_region
	set(value):
		if _current_region != value:
			_current_region = value
			Region_Changed = 1

# ── Legacy dictionary shims (read from SaveManager/GameDB) ──────────────────
# These properties rebuild dicts on access for backward compatibility.
# New code should NOT use these — use SaveManager/GameDB/managers directly.

var CHARACTERS: Dictionary:
	get:
		if _synced.has("Characters"):
			return _synced["Characters"]
		if SaveManager.data == null:
			return {}
		var d = {}
		for p in SaveManager.get_all_players():
			d[str(p.id)] = _player_to_dict(p)
		return d
var CHARACTERS_NAME: Dictionary:
	get:
		if _synced_name.has("Characters"):
			return _synced_name["Characters"]
		if SaveManager.data == null:
			return {}
		var d = {}
		for p in SaveManager.get_all_players():
			d[p.name] = str(p.id)
		return d
var COMPANIONS: Dictionary:
	get:
		if _synced.has("Companions"):
			return _synced["Companions"]
		if SaveManager.data == null:
			return {}
		var d = {}
		for c in SaveManager.get_all_companions():
			d[str(c.id)] = _companion_to_dict(c)
		return d
var COMPANIONS_NAME: Dictionary:
	get:
		if _synced_name.has("Companions"):
			return _synced_name["Companions"]
		if SaveManager.data == null:
			return {}
		var d = {}
		for c in SaveManager.get_all_companions():
			d[c.name] = str(c.id)
		return d
var CHARACTER_WEAPONS: Dictionary:
	get:
		if _synced.has("Character_Weapons"):
			return _synced["Character_Weapons"]
		if SaveManager.data == null:
			return {}
		var d = {}
		for w in SaveManager.get_all_owned_weapons():
			d[str(w.id)] = _weapon_to_dict(w)
		return d
var CHARACTER_ARTIFACTS: Dictionary:
	get:
		if _synced.has("Character_Artifacts"):
			return _synced["Character_Artifacts"]
		if SaveManager.data == null:
			return {}
		var d = {}
		for a in SaveManager.get_all_owned_artifacts():
			d[str(a.id)] = _artifact_to_dict(a)
		return d
var set_count: Dictionary:
	get:
		var counts := {}
		for artifact in CHARACTER_ARTIFACTS.values():
			if artifact.get("Owner") == ACTIVE_USER_NAME and artifact.get("Equipped") == true:
				var sn = artifact.get("Artifact_Set", "")
				if sn != "":
					counts[sn] = counts.get(sn, 0) + 1
		return counts
var CHARACTER_ITEMS: Dictionary:
	get:
		if _synced.has("Character_Items"):
			return _synced["Character_Items"]
		if SaveManager.data == null:
			return {}
		var d = {}
		for item in SaveManager.get_all_owned_items():
			d[str(item.id)] = _item_to_dict(item)
		return d
var PARTY: Dictionary:
	get:
		if _synced.has("Party"):
			return _synced["Party"]
		if SaveManager.data == null:
			return {}
		var p = SaveManager.get_party()
		if p: return {str(p.id): _party_to_dict(p)}
		return {}
var Current_Party: Dictionary:
	get:
		if _synced.has("Party"):
			for v in _synced["Party"].values():
				return v
			return {}
		if SaveManager.data == null:
			return {}
		var p = SaveManager.get_party()
		return _party_to_dict(p) if p else {}
	set(value):
		pass  # Legacy setter — ignored, use PartyManager
var TALENTS: Dictionary:
	get:
		if _synced.has("Talents"):
			return _synced["Talents"]
		var d = {}
		for raw in _read_json_cached("Talents.json"):
			if typeof(raw) == TYPE_DICTIONARY and raw.has("id"):
				d[str(int(raw["id"]))] = raw
		return d
var CONSTELLATIONS: Dictionary:
	get:
		if _synced.has("Constellations"):
			return _synced["Constellations"]
		var d = {}
		for raw in _read_json_cached("Constellations.json"):
			if typeof(raw) == TYPE_DICTIONARY and raw.has("id"):
				d[str(int(raw["id"]))] = raw
		return d
var GAME_CONFIG: Dictionary:
	get:
		if _synced.has("Game_Config"):
			return _synced["Game_Config"]
		if SaveManager.data == null:
			return {}
		return SaveManager.data.game_config

# ── Static data shims (delegate to GameDB) ──────────────────────────────────
var ENEMIES: Dictionary:
	get:
		var d = {}
		for e in GameDB.enemies.values():
			d[str(e.id)] = e.to_dict()
		return d
var ENEMIES_NAME: Dictionary:
	get:
		var d = {}
		for e in GameDB.enemies.values():
			d[e.name] = str(e.id)
		return d
var EnemyList: Array:
	get:
		var l = []
		for e in GameDB.enemies.values():
			l.append(e.name)
		return l
var WEAPONS: Dictionary:
	get:
		var d = {}
		for w in GameDB.weapons.values():
			d[str(w.id)] = {"id": w.id, "Name": w.name, "Rarity": w.rarity, "Region": w.region, "Weapon_Type": w.weapon_type, "Effect": w.effect, "Stat_1_Type": w.stat_1_type, "Stat_1_Value": w.stat_1_value, "Stat_2_Type": w.stat_2_type, "Stat_2_Value": w.stat_2_value, "Stat_3_Type": w.stat_3_type, "Stat_3_Value": w.stat_3_value, "Stat_Modifier": w.stat_modifier, "Stat_Modifier_Value": w.stat_modifier_value}
		return d
var WEAPONS_NAME: Dictionary:
	get:
		var d = {}
		for w in GameDB.weapons.values():
			d[w.name] = str(w.id)
		return d
var ABILITIES: Dictionary:
	get:
		var d = {}
		for a in GameDB.abilities.values():
			d[str(a.id)] = {"id": a.id, "name": a.name, "element": a.element, "description": a.description, "cooldown": a.cooldown, "charge_cost": a.charge_cost, "effect_status": a.effect_status, "effect_status_duration_rounds": a.effect_status_duration_rounds, "effect_status_target": a.effect_status_target}
		return d
var ITEMS: Dictionary:
	get:
		var d = {}
		for it in GameDB.items.values():
			d[str(it.id)] = {"id": it.id, "Item": it.item_name, "Type": it.type, "Rarity": it.rarity, "Region": it.region, "Description": it.description, "Value": it.value, "Buff_Duration": it.buff_duration}
		return d
var ARTIFACTS: Dictionary:
	get:
		var d = {}
		for a in GameDB.artifact_sets.values():
			d[str(a.id)] = {"id": a.id, "Artifact_Set": a.artifact_set, "Bonus_Type": a.bonus_type, "Effect": a.effect, "Stat_Modifier": a.stat_modifier, "Stat_Modifier_Value": a.stat_modifier_value, "Condition": a.condition, "Condition_Value": a.condition_value}
		return d
var REACTIONS: Dictionary:
	get:
		var d = {}
		for r in GameDB.reactions.values():
			d[str(r.id)] = {"id": r.id, "First_Element": r.first_element, "Second_Element": r.second_element, "Effect": r.effect}
		return d
var STATUS_EFFECTS: Dictionary:
	get:
		var d = {}
		for s in GameDB.status_effects.values():
			d[str(s.id)] = {"id": s.id, "Name": s.name, "Description": s.description}
		return d
var CRAFTING_RECIPES: Dictionary:
	get:
		var d = {}
		for c in GameDB.crafting_recipes.values():
			d[str(c.id)] = {"id": c.id, "Product": c.product, "Region": c.region, "Description": c.description, "Role": c.role, "Material": c.material, "Quantity": c.quantity}
		return d
var MATERIAL_CACHES: Dictionary:
	get:
		var d = {}
		for m in GameDB.material_caches.values():
			d[str(m.id)] = {"id": m.id, "Region": m.region, "Roll": m.roll, "Materials": m.materials}
		return d
var MINIGAMES: Dictionary:
	get:
		var d = {}
		for m in GameDB.minigames.values():
			d[str(m.id)] = {"id": m.id, "key": m.key, "name": m.name, "description": m.description, "unlocked": m.unlocked}
		return d
var MINIGAMES_RESULTS: Dictionary:
	get:
		if _synced.has("Minigames_Results"):
			return _synced["Minigames_Results"]
		var d = {}
		for r in SaveManager.data.minigame_results if SaveManager.data else []:
			d[str(r.id)] = {"id": r.id, "minigame_id": r.minigame_id, "player_name": r.player_name, "score": r.score, "rewards": r.rewards}
		return d

# ── Battle state shims (delegate to BattleManager) ──────────────────────────
var BATTLEENEMIES: Dictionary:
	get:
		if BattleManager.active:
			var d = {}
			for e in BattleManager.enemies.values():
				d[str(e.id)] = e.to_dict()
			return d
		return _synced.get("BattleEnemies", {})

var ACTIVE_ABILITIES: Dictionary:
	get:
		# Start with .tres-based abilities (source of truth for mappings)
		var result = GameDB.build_active_abilities_table()
		# Merge synced runtime state (cooldowns) on top
		if _synced.has("Active_Abilities"):
			for key in _synced["Active_Abilities"]:
				var synced_entry = _synced["Active_Abilities"][key]
				# Update cooldown state on matching entries
				if result.has(key):
					result[key]["Ability_Cooldown"] = synced_entry.get("Ability_Cooldown", 0)
				else:
					result[key] = synced_entry
		return result
var ACTIVE_STATUS_EFFECTS: Dictionary:
	get:
		return _synced.get("Active_Status_Effects", {})

var BattlerData: Dictionary:
	get: return BattleManager.battler_data if BattleManager.active else _battler_data_fallback
	set(value): _battler_data_fallback = value
var _battler_data_fallback: Dictionary = {}

var Current_Battler_Data:
	get:
		if BattleManager.active:
			return BattleManager.battler_data.get(BattleManager.current_turn, null)
		return _current_battler_fallback
	set(value): _current_battler_fallback = value
var _current_battler_fallback = null

var PartyCharacters: Array:
	get: return PartyManager.get_player_names()
	set(value): pass
var PartyCompanions: Array:
	get: return PartyManager.get_companion_names()
	set(value): pass

var Current_Weapon = null
var AverageHealth: int = 0
var BATTLE_TURNS: Array = []
var BATTLE_TURN_ORDER: Array = []
var BATTLE_PARTICIPANTS: Array = []

# ── Effect Processor (host-only, authoritative for all combat effects) ──────
var effect_processor: EffectProcessor = null

## Called at battle start (host only). Registers all battlers with their effects.
func start_battle_effects(battler_data: Dictionary) -> void:
	effect_processor = EffectProcessor.new()
	for battler_name in battler_data.keys():
		var bd = battler_data[battler_name]

		# Always-visible sources: weapon, artifact, food buff, passive abilities
		# Register ALL their effects regardless of trigger type.
		# Triggered sources: skill, burst, basic/charged attack
		# Their effects only appear when the ability is used (wired in process_turn).

		# Weapon effects — always visible
		var weapon_data = bd.get("entity_weapon_data")
		if weapon_data != null and not weapon_data.is_empty():
			var wname = str(weapon_data.get("Weapon", ""))
			if wname != "":
				for eff in WeaponEffects.get_effects(wname):
					effect_processor.add_effect(battler_name, eff, "weapon", wname)

		# Artifact set bonuses — always visible
		var equipped_artifacts = []
		for a in CHARACTER_ARTIFACTS.values():
			if a.get("Owner") == battler_name and a.get("Equipped") == true:
				equipped_artifacts.append(a)
		var set_pieces = {}
		for a in equipped_artifacts:
			var sn = a.get("Artifact_Set", "")
			if sn != "":
				set_pieces[sn] = set_pieces.get(sn, 0) + 1
		for sn in set_pieces:
			for bonus_type in [2, 4]:
				if set_pieces[sn] >= bonus_type:
					var label = "%s %dpc" % [sn, bonus_type]
					for eff in ArtifactEffects.get_effects(sn, bonus_type):
						effect_processor.add_effect(battler_name, eff, "artifact", label)

		# Ability effects — only register Passive abilities at battle start.
		# Skill/Burst/Basic/Charged effects fire when used (in process_turn).
		var abilities = bd.get("entity_current_ability_data", {})
		for ability in abilities.values():
			var aid = ability.get("id", 0)
			if aid == null:
				continue
			var aid_int = int(aid)
			if aid_int <= 0:
				continue
			var atype = str(ability.get("Ability_Type", ability.get("ability_type", "")))
			var ability_res: AbilityData = GameDB.get_ability(aid_int)
			# Detect passives by: explicit type, zero weight, or ability_type field on resource
			var is_passive = atype.to_lower() == "passive"
			if not is_passive and ability_res:
				is_passive = ability_res.ability_type.to_lower() == "passive" or ability_res.weight <= 0.0
			if not is_passive:
				continue
			var ability_name = ability_res.name if ability_res else "Ability %d" % aid_int
			if ability_res and ability_res.effects.size() > 0:
				for eff in ability_res.effects:
					effect_processor.add_effect(battler_name, eff, "passive", ability_name)
			for eff in AbilityEffects.get_effects(aid_int):
				effect_processor.add_effect(battler_name, eff, "passive", ability_name)

	# Recalculate stats now that effects are registered (weapon/artifact stat bonuses)
	CharacterManager.recalculate_all()
	sync_active_effects()

## Serialize and broadcast active effects to all clients.
func sync_active_effects() -> void:
	if effect_processor == null:
		return
	var effects_data = effect_processor.serialize_all()
	_synced["ActiveEffects"] = effects_data
	if NetworkManager.is_host:
		var json_test = JSON.stringify(effects_data)
		if json_test == null or json_test == "":
			push_warning("sync_active_effects: effects_data failed to serialize")
			return
		NetworkManager.broadcast_field_updates([{
			"table": "ActiveEffects",
			"record_id": 0,
			"field": "_all",
			"value": effects_data
		}])

## Get active effects display data for a battler (from _synced, works on all clients).
func get_battler_effects(battler_name: String) -> Array:
	var all_fx = _synced.get("ActiveEffects", {})
	return all_fx.get(battler_name, [])

## Clean up at battle end.
func end_battle_effects() -> void:
	if effect_processor != null:
		effect_processor.clear_all()
		effect_processor = null
	_synced.erase("ActiveEffects")
	if NetworkManager.is_host:
		NetworkManager.broadcast_field_updates([{
			"table": "ActiveEffects",
			"record_id": 0,
			"field": "_all",
			"value": {}
		}])

# ── Correlation ID for inserts ───────────────────────────────────────────────
var _next_insert_corr_id: String = ""
func set_next_correlation_id(id_value: String) -> void:
	_next_insert_corr_id = id_value

# ── Lifecycle ────────────────────────────────────────────────────────────────
var _json_cache: Dictionary = {}

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

func _read_json_cached(filename: String) -> Array:
	if _json_cache.has(filename):
		return _json_cache[filename]
	var path = "res://data/" + filename
	if not FileAccess.file_exists(path):
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		_json_cache[filename] = parsed
		return parsed
	return []

# ── Stat calculation (delegates to CharacterManager) ─────────────────────────
func calculate_all_stats() -> void:
	CharacterManager.recalculate_all()
	if SaveManager.get_player(ACTIVE_USER_NAME):
		var p = SaveManager.get_player(ACTIVE_USER_NAME)
		Current_Region = p.current_region

# ── Network-aware write operations (kept for compat) ────────────────────────
func Update_Records(updates: Array) -> void:
	print("Global.Update_Records: %d updates, is_host=%s" % [updates.size(), str(NetworkManager.is_host)])
	if NetworkManager.is_host:
		NetworkManager.host_update_records(updates)
	else:
		var json_str = JSON.stringify(updates)
		NetworkManager.request_update.rpc_id(1, json_str)
	# Apply to save data
	for u in updates:
		_apply_update_to_save(u)
	SaveManager.mark_dirty()

func Insert(table: String, columns: Array, values: Array) -> void:
	if table.strip_edges() == "" or columns.is_empty():
		return
	if columns.size() != values.size():
		return
	var corr_id = _next_insert_corr_id
	_next_insert_corr_id = ""
	if NetworkManager.is_host:
		var new_id = NetworkManager.host_insert(table, columns, values)
		var record = {"id": new_id}
		for i in columns.size():
			record[columns[i]] = values[i]
		emit_signal("insert_finished", corr_id, table, new_id, record, true)
	else:
		var record = {}
		for i in columns.size():
			record[columns[i]] = values[i]
		var json_str = JSON.stringify(record)
		NetworkManager.request_insert.rpc_id(1, table, json_str, corr_id)

func Remove_Record(table: String, record_id: int) -> void:
	if table.strip_edges() == "":
		return
	if NetworkManager.is_host:
		NetworkManager.host_remove(table, record_id)
	else:
		NetworkManager.request_remove.rpc_id(1, table, record_id)

func _apply_update_to_save(u: Dictionary) -> void:
	var table: String = str(u.get("table", ""))
	var rid: int = int(u.get("record_id", 0))
	var field: String = str(u.get("field", ""))
	var value = u.get("value")

	# Special: ActiveEffects is a whole-dict replacement, not per-record
	if table == "ActiveEffects" and field == "_all":
		_synced["ActiveEffects"] = value if value != null else {}
		return

	# Always update _synced (the host-authoritative data)
	if _synced.has(table) and _synced[table].has(str(rid)):
		_synced[table][str(rid)][field] = value
		if field == "Name" and _synced_name.has(table):
			_synced_name[table][str(value)] = str(rid)

	# Sync local state for party-wide values regardless of SaveManager
	if table == "Party" and field == "Current_Region":
		Current_Region = str(value) if value != null else ""

	# Also update typed Resources if SaveManager is active (host only)
	if SaveManager.data != null:
		match table:
			"Characters":
				for p in SaveManager.get_all_players():
					if p.id == rid:
						_set_player_field(p, field, value)
						break
			"Companions":
				for c in SaveManager.get_all_companions():
					if c.id == rid:
						_set_companion_field(c, field, value)
						break
			"Party":
				var party = SaveManager.get_party()
				if party and party.id == rid:
					_set_party_field(party, field, value)
			"Character_Items":
				for item in SaveManager.get_all_owned_items():
					if item.id == rid:
						_set_owned_item_field(item, field, value)
						break
			"Character_Weapons":
				for w in SaveManager.get_all_owned_weapons():
					if w.id == rid:
						_set_owned_weapon_field(w, field, value)
						break
			"Character_Artifacts":
				for a in SaveManager.get_all_owned_artifacts():
					if a.id == rid:
						_set_owned_artifact_field(a, field, value)
						break

	# BattleManager gets updates regardless
	if table == "BattleEnemies" and BattleManager.active and BattleManager.enemies.has(rid):
		_set_battle_enemy_field(BattleManager.enemies[rid], field, value)

func _set_player_field(p: PlayerData, field: String, value) -> void:
	match field:
		"Current_Health": p.current_health = int(value) if value != null else 0
		"Max_Health": p.max_health = int(value) if value != null else 0
		"Burst_Charges": p.burst_charges = int(value) if value != null else 0
		"Shield_Health": p.shield_health = int(value) if value != null else 0
		"Shield_Duration": p.shield_duration = int(value) if value != null else 0
		"Applied_Element": p.applied_element = str(value) if value != null else "None"
		"Skipped": p.skipped = bool(value) if value != null else false
		"Skip_Duration": p.skip_duration = int(value) if value != null else 0
		"Ready": p.ready = bool(value) if value != null else false
		"Element": p.element = str(value) if value != null else ""
		"Current_Region":
			p.current_region = str(value) if value != null else ""
			Current_Region = p.current_region
		"Level": p.level = int(value) if value != null else 0
		"Daily_Luck": p.daily_luck = int(value) if value != null else 50

func _set_companion_field(c: CompanionSaveData, field: String, value) -> void:
	match field:
		"Current_Health": c.current_health = int(value) if value != null else 0
		"Max_Health": c.max_health = int(value) if value != null else 0
		"Burst_Charges": c.burst_charges = int(value) if value != null else 0
		"Applied_Element": c.applied_element = str(value) if value != null else "None"
		"Active": c.active = bool(value) if value != null else false
		"Player_Chosen": c.player_chosen = bool(value) if value != null else false
		"Shield_Health": c.shield_health = int(value) if value != null else 0
		"Shield_Duration": c.shield_duration = int(value) if value != null else 0

func _set_party_field(party: PartySaveData, field: String, value) -> void:
	match field:
		"Current_Turn": party.current_turn = str(value) if value != null else ""
		"Active_Food_Buff": party.active_food_buff = str(value) if value != null else "None"
		"Buff_Battles_Left": party.buff_battles_left = int(value) if value != null else 0
		"Mora": party.mora = int(value) if value != null else 0
		"Active_Battle_ID": party.active_battle_id = str(value) if value != null else ""
		"Current_Region":
			var r = str(value) if value != null else ""
			party.current_region = r
			Current_Region = r

func _set_owned_item_field(item, field: String, value) -> void:
	match field:
		"Quantity": item.quantity = int(value) if value != null else 0
		"Owner": item.owner = str(value) if value != null else ""

func _set_owned_weapon_field(w, field: String, value) -> void:
	match field:
		"Quantity": w.quantity = int(value) if value != null else 1
		"Owner": w.owner = str(value) if value != null else ""
		"Equipped": w.equipped = bool(value) if value != null else false
		"Refinement": w.refinement = int(value) if value != null else 0

func _set_owned_artifact_field(a, field: String, value) -> void:
	match field:
		"Owner": a.owner = str(value) if value != null else ""
		"Equipped": a.equipped = bool(value) if value != null else false

func _set_battle_enemy_field(e: BattleEnemy, field: String, value) -> void:
	match field:
		"Current_Health": e.current_health = int(value) if value != null else 0
		"Max_Health": e.max_health = int(value) if value != null else 0
		"AppliedElement": e.applied_element = str(value) if value != null else "None"
		"Killed": e.killed = bool(value) if value != null else false
		"Phase": e.phase = int(value) if value != null else 1
		"Shield_Health": e.shield_health = int(value) if value != null else 0
		"Shield_Duration": e.shield_duration = int(value) if value != null else 0
		"Skipped": e.skipped = bool(value) if value != null else false
		"Skip_Duration": e.skip_duration = int(value) if value != null else 0
		"EnemyName": e.enemy_name = str(value) if value != null else ""
		"Fog": e.fog = bool(value) if value != null else false

# ── Data loading shim (used by NetworkManager) ──────────────────────────────
var TABLES: Array = ["Characters","Companions","Character_Items","Character_Weapons","Character_Artifacts","Talents","Constellations","Party","Active_Abilities","Active_Status_Effects","BattleEnemies","Game_Config","Minigames_Results"]
var TABLES_TO_SAVE: Array = ["Characters","Companions","Character_Items","Character_Weapons","Character_Artifacts","Talents","Constellations","Party","Game_Config","Minigames_Results","BattleEnemies","Active_Abilities","Active_Status_Effects"]
var TABLES_TO_SYNC_OFTEN: Array = ["Characters","BattleEnemies","Companions","Active_Abilities","Active_Status_Effects"]

func _process_table(table_name: String, records: Array) -> void:
	# Stores every synced table into _synced so both host and client can read it.
	if not _synced.has(table_name):
		_synced[table_name] = {}
	else:
		_synced[table_name].clear()
	if not _synced_name.has(table_name):
		_synced_name[table_name] = {}
	else:
		_synced_name[table_name].clear()

	for record in records:
		if typeof(record) != TYPE_DICTIONARY or not record.has("id"):
			continue
		var rid = int(record["id"]) if record["id"] != null else 0
		record["id"] = rid
		_synced[table_name][str(rid)] = record
		if record.has("Name"):
			_synced_name[table_name][str(record["Name"])] = str(rid)

	emit_signal("table_loaded", table_name, records.size())

func Refresh_Data(table_list: Array) -> void:
	if NetworkManager.is_host:
		for table_name in table_list:
			var records = DataStore.load_table(table_name)
			_process_table(table_name, records)
			NetworkManager.broadcast_table_update(table_name)
	CharacterManager.recalculate_all()
	emit_signal("data_load_complete")

func _apply_local_update(table_name: String, record_id: String, field: String, value) -> void:
	_apply_update_to_save({"table": table_name, "record_id": int(record_id), "field": field, "value": value})

func _apply_record_update(table_name: String, record_id: String, data: Dictionary) -> void:
	_process_table(table_name, [data])
	CharacterManager.recalculate_all()
	emit_signal("data_load_complete")

func _insert_record(table_name: String, record_id: String, record: Dictionary) -> void:
	record["id"] = int(record_id)
	if not _synced.has(table_name):
		_synced[table_name] = {}
	_synced[table_name][record_id] = record
	if record.has("Name") :
		if not _synced_name.has(table_name):
			_synced_name[table_name] = {}
		_synced_name[table_name][str(record["Name"])] = record_id

func _remove_record(table_name: String, record_id: String) -> void:
	if _synced.has(table_name):
		_synced[table_name].erase(record_id)

func _get_dict_for_table(table_name: String) -> Dictionary:
	return _synced.get(table_name, {})

# ── Utility functions (kept) ────────────────────────────────────────────────
func normalize_text_filename(weapon_name: String) -> String:
	var cleaned = weapon_name.strip_edges().to_lower()
	cleaned = cleaned.replace("\u00a0", " ").replace("\u00ad", "").replace("\u2019", "").replace(" ", "-")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9-]")
	cleaned = regex.sub(cleaned, "", true)
	return cleaned + ".png"

const ARTIFACT_TYPE_MAP = {
	"Flower": "Flower of Life", "Feather": "Feather of Death",
	"Sands": "Sands of Time", "Goblet": "Goblet of Space", "Circlet": "Circlet of Principles"
}

func slot_label_to_type(slot_short: String) -> String:
	return ARTIFACT_TYPE_MAP.get(slot_short, slot_short)

func find_substring_matches_ci(query_text: String, source_list: Array) -> Array:
	var q = query_text.strip_edges()
	if q == "": return []
	var ql = q.to_lower()
	var matches = []
	for item in source_list:
		if str(item).to_lower().find(ql) != -1:
			matches.append(str(item))
	matches.sort()
	return matches

# ── Logging (kept, delegates to NetworkManager) ─────────────────────────────
func Log(category: String, action: String, related_type: String = "", related_id: String = "",
		 old_values: Dictionary = {}, new_values: Dictionary = {}, metadata: Dictionary = {},
		 result: String = "success", severity: String = "audit") -> void:
	var scene_name = ""
	if get_tree().current_scene != null:
		scene_name = get_tree().current_scene.name
	var meta = {
		"scene": scene_name,
		"client_time": Time.get_datetime_string_from_system(),
		"client_version": ProjectSettings.get_setting("application/config/version", "dev"),
	}
	for k in metadata: meta[k] = metadata[k]
	NetworkManager.host_log({
		"user_id": ACTIVE_USER_NAME, "category": category, "action": action,
		"related_type": related_type, "related_id": related_id,
		"old_values": old_values, "new_values": new_values,
		"metadata": meta, "result": result, "severity": severity
	})

func CombatLog(battle_id, turn_no: int, phase: String, actor_type: String, actor_id: String,
			   action_type: String, action_name: String, target_id: String, ignores_def: bool,
			   rolls: Dictionary, damage: int, hp_before: int, hp_after: int, energy_change: int,
			   elements_applied: Array = [], status_changes: Dictionary = {}, misc: Dictionary = {}) -> void:
	NetworkManager.host_combat_log({
		"battle_id": battle_id, "turn_no": turn_no, "phase": phase,
		"actor_type": actor_type, "actor_id": actor_id,
		"action_type": action_type, "action_name": action_name,
		"target_id": target_id, "ignores_def": ignores_def,
		"rolls": rolls, "damage": damage, "hp_before": hp_before, "hp_after": hp_after,
		"energy_change": energy_change, "elements_applied": elements_applied,
		"status_changes": status_changes, "misc": misc
	})

# ── Dict converters for legacy compat ────────────────────────────────────────
func _player_to_dict(p: PlayerData) -> Dictionary:
	var d = {
		"id": p.id, "Name": p.name, "Email": p.email, "UserType": p.user_type,
		"Portrait": p.portrait, "Level": p.level, "Level_Cap": p.level_cap,
		"Ascension_Rank": p.ascension_rank, "Ascension_Material": p.ascension_material,
		"Element": p.element, "Role": p.role, "Current_Region": p.current_region,
		"Daily_Luck": p.daily_luck, "Current_Health": p.current_health,
		"Max_Health": p.max_health, "Burst_Charges": p.burst_charges,
		"Shield_Health": p.shield_health, "Shield_Duration": p.shield_duration,
		"Applied_Element": p.applied_element, "Skipped": p.skipped,
		"Skip_Duration": p.skip_duration, "Ready": p.ready,
	}
	if p.stats:
		d["Health_Base_Points"] = p.stats.health_base
		d["Attack_Base_Points"] = p.stats.attack_base
		d["Defense_Base_Points"] = p.stats.defense_base
		d["Elemental_Mastery_Base_Points"] = p.stats.elemental_mastery_base
		d["Energy_Recharge_Base_Points"] = p.stats.energy_recharge_base
		d["Critical_Damage_Base_Points"] = p.stats.critical_damage_base
		d["Health_Skill_Points"] = p.stats.health_skill
		d["Attack_Skill_Points"] = p.stats.attack_skill
		d["Defense_Skill_Points"] = p.stats.defense_skill
		d["Elemental_Mastery_Skill_Points"] = p.stats.elemental_mastery_skill
		d["Energy_Recharge_Skill_Points"] = p.stats.energy_recharge_skill
		d["Critical_Damage_Skill_Points"] = p.stats.critical_damage_skill
		d["Unspent_Skill_Points"] = p.stats.unspent_skill_points
		d["Unspent_Base_Points"] = p.stats.unspent_base_points
	return d

func _companion_to_dict(c: CompanionSaveData) -> Dictionary:
	return {
		"id": c.id, "Name": c.name, "Element": c.element, "Weapon": c.weapon,
		"Region": c.region, "Lore": c.lore, "Unlocked": c.unlocked, "Active": c.active,
		"Met": c.met, "Player_Chosen": c.player_chosen, "Owner": c.owner,
		"Current_Health": c.current_health, "Max_Health": c.max_health,
		"Burst_Charges": c.burst_charges, "Shield_Health": c.shield_health,
		"Shield_Duration": c.shield_duration, "Applied_Element": c.applied_element,
		"AppliedElement": c.applied_element, "Skipped": c.skipped,
	}

func _weapon_to_dict(w: OwnedWeapon) -> Dictionary:
	return {
		"id": w.id, "Weapon": w.weapon_name, "Owner": w.owner, "Equipped": w.equipped,
		"Refinement": w.refinement, "Quantity": w.quantity, "Rarity": w.rarity,
		"Region": w.region, "Type": w.weapon_type,
		"Stat_1_Type": w.stat_1_type, "Stat_1_Value": w.stat_1_value,
		"Stat_2_Type": w.stat_2_type, "Stat_2_Value": w.stat_2_value,
		"Stat_3_Type": w.stat_3_type, "Stat_3_Value": w.stat_3_value,
	}

func _artifact_to_dict(a: OwnedArtifact) -> Dictionary:
	return {
		"id": a.id, "Artifact_Set": a.artifact_set, "Owner": a.owner,
		"Type": a.type, "Equipped": a.equipped, "Rarity": a.rarity,
		"Stat_1_Type": a.stat_1_type, "Stat_1_Value": a.stat_1_value,
		"Stat_2_Type": a.stat_2_type, "Stat_2_Value": a.stat_2_value,
	}

func _item_to_dict(item: OwnedItem) -> Dictionary:
	return {
		"id": item.id, "Item": item.item_name, "Name": item.item_name,
		"Owner": item.owner, "Quantity": item.quantity,
		"Rarity": item.rarity, "Type": item.type,
	}

func _party_to_dict(p: PartySaveData) -> Dictionary:
	var d = {
		"id": p.id, "Current_Turn": p.current_turn, "Mora": p.mora,
		"Dungeon_Master": p.dungeon_master, "Active_Food_Buff": p.active_food_buff,
		"Buff_Battles_Left": p.buff_battles_left, "Gambles": p.gambles,
		"Companion_Limit": p.companion_limit, "Active_Battle_ID": p.active_battle_id,
		"Turn_Order": p.turn_order, "Current_Region": p.current_region,
	}
	for i in range(p.members.size()):
		d["Party_Member_%d" % (i + 1)] = p.members[i]
	return d

# ─── NOTES BACKUP (Brian F. exit intercept) ─────────────────────────────────

var _notes_popup_active: bool = false
var _notes_ack_received: bool = false
var _notes_ack_success: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if ACTIVE_USER_NAME == "Brian F.":
			if not _notes_popup_active:
				_show_notes_backup_popup()
			return
		get_tree().quit()

func _show_notes_backup_popup() -> void:
	_notes_popup_active = true

	# Full-screen semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.name = "NotesBackupOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100

	# Centered panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 250)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	sb.border_color = Color(0.4, 0.4, 0.5, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)

	# Header label
	var header = Label.new()
	header.text = "Have you remembered to save the notes file?"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)

	# File path row
	var hbox_path = HBoxContainer.new()
	hbox_path.add_theme_constant_override("separation", 8)

	var path_edit = LineEdit.new()
	path_edit.name = "NotesPathEdit"
	path_edit.placeholder_text = "Select your notes file..."
	path_edit.editable = false
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_path.add_child(path_edit)

	var browse_btn = Button.new()
	browse_btn.text = "Browse"
	hbox_path.add_child(browse_btn)
	vbox.add_child(hbox_path)

	# Status label (for sending/error feedback)
	var status_label = Label.new()
	status_label.name = "NotesStatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_label.text = ""
	vbox.add_child(status_label)

	# Button row
	var hbox_btns = HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_END
	hbox_btns.add_theme_constant_override("separation", 12)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	hbox_btns.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.name = "NotesConfirmBtn"
	confirm_btn.text = "Confirm and exit"
	confirm_btn.disabled = true
	hbox_btns.add_child(confirm_btn)

	vbox.add_child(hbox_btns)
	panel.add_child(vbox)
	overlay.add_child(panel)

	# FileDialog for browsing
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.doc,*.docx ; Word Documents"])
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	file_dialog.size = Vector2(800, 500)
	file_dialog.title = "Select Notes File"
	overlay.add_child(file_dialog)

	# Load persisted path
	var config = ConfigFile.new()
	if config.load("user://brian_notes_path.cfg") == OK:
		var saved_path = config.get_value("notes", "path", "")
		if saved_path != "":
			path_edit.text = saved_path
			if FileAccess.file_exists(saved_path):
				confirm_btn.disabled = false

	# Wire up signals
	browse_btn.pressed.connect(func(): file_dialog.popup_centered())
	file_dialog.file_selected.connect(func(path: String):
		path_edit.text = path
		confirm_btn.disabled = not FileAccess.file_exists(path)
		status_label.text = ""
	)
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
		_notes_popup_active = false
	)
	confirm_btn.pressed.connect(_on_notes_confirm.bind(path_edit, confirm_btn, cancel_btn, browse_btn, status_label, overlay))

	# Add to the scene tree root so it works from any scene
	get_tree().root.add_child(overlay)

func _on_notes_confirm(path_edit: LineEdit, confirm_btn: Button, cancel_btn: Button, browse_btn: Button, status_label: Label, overlay: ColorRect) -> void:
	var file_path = path_edit.text
	if not FileAccess.file_exists(file_path):
		status_label.text = "File not found. Please browse again."
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		confirm_btn.disabled = true
		return

	# Disable UI while sending
	confirm_btn.disabled = true
	cancel_btn.disabled = true
	browse_btn.disabled = true
	status_label.text = "Sending file to host..."
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Read the file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		status_label.text = "Failed to read file: %s" % error_string(FileAccess.get_open_error())
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		confirm_btn.disabled = false
		cancel_btn.disabled = false
		browse_btn.disabled = false
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()
	var filename = file_path.get_file()

	# Send to host (peer 1)
	NetworkManager.send_notes_file.rpc_id(1, filename, file_bytes)

	# Wait for ack with timeout
	var result = await _wait_for_notes_ack(10.0)
	if result:
		# Save the path for next time
		var config = ConfigFile.new()
		config.set_value("notes", "path", file_path)
		config.save("user://brian_notes_path.cfg")
		get_tree().quit()
	else:
		status_label.text = "Failed to send file. Try again or cancel."
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		confirm_btn.disabled = false
		cancel_btn.disabled = false
		browse_btn.disabled = false

func _wait_for_notes_ack(timeout: float) -> bool:
	_notes_ack_received = false
	_notes_ack_success = false
	NetworkManager.notes_file_ack_received.connect(_on_notes_ack, CONNECT_ONE_SHOT)
	var elapsed = 0.0
	while not _notes_ack_received and elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not _notes_ack_received:
		# Timeout — disconnect if still connected
		if NetworkManager.notes_file_ack_received.is_connected(_on_notes_ack):
			NetworkManager.notes_file_ack_received.disconnect(_on_notes_ack)
	return _notes_ack_success

func _on_notes_ack(success: bool) -> void:
	_notes_ack_success = success
	_notes_ack_received = true
