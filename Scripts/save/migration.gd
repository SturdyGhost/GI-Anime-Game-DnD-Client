class_name SaveMigration extends RefCounted
## One-time migration: reads current JSON data files, creates individual .tres
## resource files for players/companions/inventory, and a slim save.tres for
## mutable state overrides.

const DATA_DIR = "res://data/"
const RES_DIR = "res://data/resources/"

static func migrate() -> SaveData:
	var save = SaveData.new()
	print("Migration: starting JSON → .tres resource conversion...")

	_migrate_players(save)
	_migrate_companions(save)
	_migrate_weapons(save)
	_migrate_artifacts(save)
	_migrate_items(save)
	_migrate_party(save)
	_migrate_talents(save)
	_migrate_constellations(save)
	_migrate_game_config(save)
	_migrate_minigame_results(save)

	print("Migration: complete")
	return save

# ── Players → individual .tres + save state ──────────────────────────────────

static func _migrate_players(save: SaveData) -> void:
	var dir_path = RES_DIR + "players/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var count = 0

	for d in _read_json("Characters.json"):
		var p = PlayerData.new()
		p.id = _i(d.get("id"))
		p.name = _s(d.get("Name"))
		p.email = _s(d.get("Email"))
		p.user_type = _s(d.get("UserType", "Player"))
		p.portrait = _s(d.get("Portrait"))
		p.level = _i(d.get("Level"))
		p.level_cap = _i(d.get("Level_Cap"))
		p.ascension_rank = _i(d.get("Ascension_Rank"))
		p.ascension_material = _s(d.get("Ascension_Material"))
		p.element = _s(d.get("Element", "Physical"))
		p.role = _s(d.get("Role"))
		p.current_region = _s(d.get("Current_Region", "Mondstadt"))
		p.daily_luck = _i(d.get("Daily_Luck"))

		p.stats = EntityStats.new()
		p.stats.health_base = _i(d.get("Health_Base_Points"))
		p.stats.attack_base = _i(d.get("Attack_Base_Points"))
		p.stats.defense_base = _i(d.get("Defense_Base_Points"))
		p.stats.elemental_mastery_base = _i(d.get("Elemental_Mastery_Base_Points"))
		p.stats.energy_recharge_base = _f(d.get("Energy_Recharge_Base_Points"))
		p.stats.critical_damage_base = _f(d.get("Critical_Damage_Base_Points"))
		p.stats.health_skill = _i(d.get("Health_Skill_Points"))
		p.stats.attack_skill = _i(d.get("Attack_Skill_Points"))
		p.stats.defense_skill = _i(d.get("Defense_Skill_Points"))
		p.stats.elemental_mastery_skill = _i(d.get("Elemental_Mastery_Skill_Points"))
		p.stats.energy_recharge_skill = _f(d.get("Energy_Recharge_Skill_Points"))
		p.stats.critical_damage_skill = _f(d.get("Critical_Damage_Skill_Points"))
		p.stats.unspent_skill_points = _i(d.get("Unspent_Skill_Points"))
		p.stats.unspent_base_points = _i(d.get("Unspent_Base_Points"))

		# Combat state → save file, not the .tres
		p.current_health = _i(d.get("Current_Health"))
		p.max_health = _i(d.get("Max_Health"))
		p.burst_charges = _i(d.get("Burst_Charges"))
		p.shield_health = _i(d.get("Shield_Health"))
		p.shield_duration = _i(d.get("Shield_Duration"))
		p.applied_element = _s(d.get("Applied_Element", "None"))
		p.skipped = _b(d.get("Skipped"))
		p.skip_duration = _i(d.get("Skip_Duration"))
		p.ready = _b(d.get("Ready"))

		# Save the base player resource
		var slug = _slugify(p.name)
		ResourceSaver.save(p, dir_path + slug + ".tres")

		# Store mutable state in save file
		save.player_state[p.name] = {
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
		count += 1
	print("  Migrated %d players → .tres + save state" % count)

# ── Companions → individual .tres + save state ──────────────────────────────

static func _migrate_companions(save: SaveData) -> void:
	var dir_path = RES_DIR + "companions/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var count = 0

	for d in _read_json("Companions.json"):
		var c = CompanionSaveData.new()
		c.id = _i(d.get("id"))
		c.name = _s(d.get("Name"))
		c.element = _s(d.get("Element"))
		c.weapon = _s(d.get("Weapon"))
		c.region = _s(d.get("Region"))
		c.lore = _s(d.get("Lore"))
		c.unlocked = _b(d.get("Unlocked"))
		c.active = _b(d.get("Active"))
		c.met = _b(d.get("Met"))
		c.player_chosen = _b(d.get("Player_Chosen"))
		c.owner = _s(d.get("Owner"))
		c.stats = EntityStats.new()
		c.current_health = _i(d.get("Current_Health"))
		c.max_health = _i(d.get("Max_Health"))
		c.burst_charges = _i(d.get("Burst_Charges"))
		c.shield_health = _i(d.get("Shield_Health"))
		c.shield_duration = _i(d.get("Shield_Duration"))
		c.applied_element = _s(d.get("Applied_Element", d.get("AppliedElement", "None")))
		c.skipped = _b(d.get("Skipped"))
		c.skip_duration = _i(d.get("Skipped_Duration", d.get("Skip_Duration")))

		var slug = _slugify(c.name)
		ResourceSaver.save(c, dir_path + slug + ".tres")

		save.companion_state[c.name] = {
			"current_health": c.current_health,
			"max_health": c.max_health,
			"burst_charges": c.burst_charges,
			"shield_health": c.shield_health,
			"shield_duration": c.shield_duration,
			"applied_element": c.applied_element,
			"active": c.active,
			"player_chosen": c.player_chosen,
			"owner": c.owner,
		}
		count += 1
	print("  Migrated %d companions → .tres + save state" % count)

# ── Owned Weapons → individual .tres + save overrides ────────────────────────

static func _migrate_weapons(save: SaveData) -> void:
	var dir_path = RES_DIR + "inventory/weapons/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var count = 0

	for d in _read_json("Character_Weapons.json"):
		var w = OwnedWeapon.new()
		w.id = _i(d.get("id"))
		w.weapon_name = _s(d.get("Weapon"))
		w.owner = _s(d.get("Owner"))
		w.equipped = _b(d.get("Equipped"))
		w.refinement = _i(d.get("Refinement"))
		w.quantity = _i(d.get("Quantity", 1))
		w.rarity = _s(d.get("Rarity"))
		w.region = _s(d.get("Region"))
		w.weapon_type = _s(d.get("Type"))
		w.stat_1_type = _s(d.get("Stat_1_Type"))
		w.stat_1_value = _f(d.get("Stat_1_Value"))
		w.stat_2_type = _s(d.get("Stat_2_Type"))
		w.stat_2_value = _f(d.get("Stat_2_Value"))
		w.stat_3_type = _s(d.get("Stat_3_Type"))
		w.stat_3_value = _f(d.get("Stat_3_Value"))

		var wdef = GameDB.get_weapon_by_name(w.weapon_name)
		if wdef:
			w.weapon_id = wdef.id

		var slug = _slugify(w.owner + " " + w.weapon_name)
		ResourceSaver.save(w, dir_path + slug + ".tres")

		save.weapon_overrides[slug] = {
			"equipped": w.equipped,
			"owner": w.owner,
		}
		count += 1
	print("  Migrated %d weapons → .tres + save overrides" % count)

# ── Owned Artifacts → individual .tres + save overrides ──────────────────────

static func _migrate_artifacts(save: SaveData) -> void:
	var dir_path = RES_DIR + "inventory/artifacts/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var count = 0

	for d in _read_json("Character_Artifacts.json"):
		var a = OwnedArtifact.new()
		a.id = _i(d.get("id"))
		a.artifact_set = _s(d.get("Artifact_Set"))
		a.owner = _s(d.get("Owner"))
		a.type = _s(d.get("Type"))
		a.equipped = _b(d.get("Equipped"))
		a.rarity = _i(d.get("Rarity"))
		a.stat_1_type = _s(d.get("Stat_1_Type"))
		a.stat_1_value = _f(d.get("Stat_1_Value"))
		a.stat_2_type = _s(d.get("Stat_2_Type"))
		a.stat_2_value = _f(d.get("Stat_2_Value"))

		var type_short = a.type.split(" ")[0] if a.type != "" else "unknown"
		var slug = _slugify(a.owner + " " + a.artifact_set + " " + type_short)
		ResourceSaver.save(a, dir_path + slug + ".tres")

		save.artifact_overrides[slug] = {
			"equipped": a.equipped,
			"owner": a.owner,
		}
		count += 1
	print("  Migrated %d artifacts → .tres + save overrides" % count)

# ── Owned Items → individual .tres + save quantities ─────────────────────────

static func _migrate_items(save: SaveData) -> void:
	var dir_path = RES_DIR + "inventory/items/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var count = 0

	for d in _read_json("Character_Items.json"):
		var item = OwnedItem.new()
		item.id = _i(d.get("id"))
		item.item_name = _s(d.get("Item", d.get("Name", "")))
		item.owner = _s(d.get("Owner"))
		item.quantity = _i(d.get("Quantity"))
		item.rarity = _s(d.get("Rarity"))
		item.type = _s(d.get("Type"))

		var slug = _slugify(item.owner + " " + item.item_name)
		ResourceSaver.save(item, dir_path + slug + ".tres")

		save.item_quantities[slug] = {
			"quantity": item.quantity,
			"owner": item.owner,
		}
		count += 1
	print("  Migrated %d items → .tres + save quantities" % count)

# ── Party → .tres + save state ───────────────────────────────────────────────

static func _migrate_party(save: SaveData) -> void:
	var dir_path = RES_DIR + "party/"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var parties = _read_json("Party.json")
	if parties.is_empty():
		return
	var d: Dictionary = parties[0]

	var party = PartySaveData.new()
	party.id = _i(d.get("id"))
	party.dungeon_master = _s(d.get("Dungeon_Master"))
	party.companion_limit = _i(d.get("Companion_Limit", 1))
	party.current_region = _s(d.get("Current_Region", "Mondstadt"))

	for i in range(1, 5):
		var member = d.get("Party_Member_%d" % i)
		if member != null and str(member) != "" and str(member) != "COMPANION":
			party.members.append(str(member))

	var to = d.get("Turn_Order")
	if to is Array:
		party.turn_order = to

	# Save base party resource
	ResourceSaver.save(party, dir_path + "party.tres")

	# Mutable state → save file
	save.party_mora = _i(d.get("Mora"))
	save.party_current_turn = _s(d.get("Current_Turn"))
	save.party_active_food_buff = _s(d.get("Active_Food_Buff", "None"))
	save.party_buff_battles_left = _i(d.get("Buff_Battles_Left"))
	save.party_gambles = _i(d.get("Gambles"))
	save.party_active_battle_id = _s(d.get("Active_Battle_ID"))
	save.party_turn_order = party.turn_order.duplicate()

	print("  Migrated party → .tres + save state")

# ── Talents & Constellations (just IDs in save) ─────────────────────────────

static func _migrate_talents(save: SaveData) -> void:
	for d in _read_json("Talents.json"):
		if d.get("Chosen") == true:
			save.talents_chosen.append(_i(d.get("id")))
	print("  Migrated %d chosen talents" % save.talents_chosen.size())

static func _migrate_constellations(save: SaveData) -> void:
	for d in _read_json("Constellations.json"):
		if d.get("Chosen") == true:
			save.constellations_chosen.append(_i(d.get("id")))
	print("  Migrated %d chosen constellations" % save.constellations_chosen.size())

# ── Game Config ──────────────────────────────────────────────────────────────

static func _migrate_game_config(save: SaveData) -> void:
	for d in _read_json("Game_Config.json"):
		var key = _s(d.get("key", d.get("id", "")))
		var value = d.get("value", "")
		if key != "":
			save.game_config[key] = value
	print("  Migrated %d config entries" % save.game_config.size())

# ── Minigame Results ─────────────────────────────────────────────────────────

static func _migrate_minigame_results(save: SaveData) -> void:
	for d in _read_json("Minigames_Results.json"):
		var r = MinigameResult.new()
		r.id = _i(d.get("id"))
		r.minigame_id = _s(d.get("minigame_id"))
		r.player_name = _s(d.get("player_name"))
		r.score = _i(d.get("score"))
		r.rewards = _s(d.get("rewards"))
		save.minigame_results.append(r)
	print("  Migrated %d minigame results" % save.minigame_results.size())

# ── Helpers ──────────────────────────────────────────────────────────────────

static func _read_json(filename: String) -> Array:
	var path = DATA_DIR + filename
	if not FileAccess.file_exists(path):
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed

static func _slugify(text: String) -> String:
	var s = text.strip_edges().to_lower()
	s = s.replace("'", "").replace("\"", "").replace("(", "").replace(")", "")
	s = s.replace(" ", "_").replace("-", "_").replace(",", "").replace(".", "")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	s = regex.sub(s, "", true)
	while s.contains("__"):
		s = s.replace("__", "_")
	return s.trim_prefix("_").trim_suffix("_")

static func _i(v) -> int:    return int(v) if v != null else 0
static func _f(v) -> float:  return float(v) if v != null else 0.0
static func _s(v) -> String: return str(v) if v != null else ""
static func _b(v) -> bool:   return bool(v) if v != null else false
