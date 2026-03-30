class_name BattlerState extends RefCounted
## Builds the per-battler state dictionary used by battle scenes.
## Replaces the duplicated set_battlers() logic across 3 scripts.
##
## Usage:
##   var data = BattlerState.build_all(turn_order)
##   Global.BattlerData = data
##   Global.Current_Battler_Data = data[current_turn]

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

## Build full BattlerData dictionary for every actor in the turn order.
static func build_all(turn_order: Array) -> Dictionary:
	var result = {}
	for battler_name in turn_order:
		var entry = _build_one(str(battler_name))
		if entry.size() > 0:
			result[battler_name] = entry
	return result

## Build state for a single battler by name.
static func _build_one(battler: String) -> Dictionary:
	var b_id: int = 0
	var b_type: String = ""
	var b_complete_data: Dictionary = {}
	var b_weapon: Dictionary = {}
	var b_all_active_abilities: Dictionary = {}
	var b_all_ability_defs: Dictionary = {}
	var b_current_abilities: Dictionary = {}
	var b_current_ability_defs: Dictionary = {}
	var b_status_effects: Dictionary = {}
	var b_burst_charges = null

	# ── Identify battler type and fetch base data ─────────────────────────
	if Global.PartyCharacters.has(battler):
		b_type = "Character"
		b_complete_data = Global.CHARACTERS.get(Global.CHARACTERS_NAME.get(battler, ""), {})
		b_id = _i(b_complete_data.get("id"))
		b_burst_charges = b_complete_data.get("Burst_Charges")
		b_weapon = _find_equipped_weapon(battler)

	elif Global.PartyCompanions.has(battler):
		b_type = "Companion"
		b_complete_data = Global.COMPANIONS.get(Global.COMPANIONS_NAME.get(battler, ""), {})
		b_id = _i(b_complete_data.get("id"))
		b_burst_charges = b_complete_data.get("Burst_Charges")

	else:
		# Enemy: label format is "EnemyName ID"
		b_type = "Enemy"
		var enemy_record_id = _extract_enemy_id(battler)
		b_complete_data = Global.BATTLEENEMIES.get(str(enemy_record_id), {})
		b_id = _i(b_complete_data.get("id"))

	if b_complete_data.is_empty():
		return {}

	# ── Collect active abilities for this entity ──────────────────────────
	var entity_enemy_id: int = _i(b_complete_data.get("EnemyID")) if b_type == "Enemy" else b_id
	for aa in Global.ACTIVE_ABILITIES.values():
		var aa_entity_type = _s(aa.get("Entity_Type"))
		var aa_entity_id = _i(aa.get("Entity_ID"))
		var match_id = entity_enemy_id if b_type == "Enemy" else b_id

		if aa_entity_type != b_type or aa_entity_id != match_id:
			continue

		var aa_id = str(_i(aa.get("id")))
		var ability_id = _i(aa.get("Ability_ID"))
		var ability_def: AbilityData = GameDB.get_ability(ability_id)

		# Store in "all" collections
		b_all_active_abilities[aa_id] = aa
		if ability_def:
			b_all_ability_defs[str(ability_id)] = _ability_to_dict(ability_def)

		# Filter for "current" (matching element + weapon type for characters)
		var passes_filter = true
		if b_type == "Character" and b_weapon.size() > 0:
			passes_filter = (
				_s(aa.get("Element")) == _s(b_complete_data.get("Element"))
				and _s(aa.get("Weapon_Type")) == _s(b_weapon.get("Type"))
			)
		# Companions and enemies: all abilities are current
		if passes_filter:
			b_current_abilities[aa_id] = aa
			if ability_def:
				b_current_ability_defs[str(ability_id)] = _ability_to_dict(ability_def)

	# ── Collect active status effects ─────────────────────────────────────
	for status in Global.ACTIVE_STATUS_EFFECTS.values():
		if _s(status.get("Entity_Type")) == b_type and _i(status.get("Entity_ID")) == b_id:
			b_status_effects[str(_i(status.get("id")))] = status

	# ── Assemble result ───────────────────────────────────────────────────
	return {
		"id": b_id,
		"name": battler,
		"type": b_type,
		"entity_data": b_complete_data,
		"entity_weapon_data": b_weapon if b_weapon.size() > 0 else null,
		"entity_total_active_ability_data": b_all_active_abilities,
		"entity_total_ability_data": b_all_ability_defs,
		"entity_current_active_ability_data": b_current_abilities,
		"entity_current_ability_data": b_current_ability_defs,
		"entity_status_effect_data": b_status_effects,
		"current_health": _i(b_complete_data.get("Current_Health")),
		"max_health": _i(b_complete_data.get("Max_Health")),
		"burst_charges": b_burst_charges,
		"applied_element": _s(b_complete_data.get("Applied_Element", b_complete_data.get("AppliedElement", "None"))),
		"killed_status": b_complete_data.get("Killed", false),
		"skipped_status": b_complete_data.get("Skipped", false),
		"skipped_duration": _i(b_complete_data.get("Skip_Duration")),
	}

# ── Helpers ───────────────────────────────────────────────────────────────────

## Find the equipped weapon for a character by name.
static func _find_equipped_weapon(owner_name: String) -> Dictionary:
	for w in Global.CHARACTER_WEAPONS.values():
		if _s(w.get("Owner")) == owner_name and w.get("Equipped") == true:
			return w
	return {}

## Extract the numeric enemy record ID from a battle label like "Ruin Guard 5".
## The ID is always the LAST space-separated token.
static func _extract_enemy_id(label: String) -> int:
	var parts = label.split(" ")
	if parts.size() == 0:
		return 0
	var last = parts[-1]
	if last.is_valid_int():
		return int(last)
	return 0

## Convert AbilityData resource to a dict matching the old Global.ABILITIES format.
static func _ability_to_dict(a: AbilityData) -> Dictionary:
	return {
		"id": a.id,
		"name": a.name,
		"element": a.element,
		"description": a.description,
		"cooldown": a.cooldown,
		"charge_cost": a.charge_cost,
		"effect_status": a.effect_status,
		"effect_status_duration_rounds": a.effect_status_duration_rounds,
		"effect_status_target": a.effect_status_target,
		"dice_count": a.dice_count,
		"dice_die": a.dice_die,
		"dice_flat": a.dice_flat,
		"hits_count": a.hits_count,
		"movement": a.movement,
		"bypass_defense": a.bypass_defense,
		"defense_threshold": a.defense_threshold,
	}
