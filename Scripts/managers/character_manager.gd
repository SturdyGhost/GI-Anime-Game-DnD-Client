extends Node
## Manages player characters: stat calculation, equipment, abilities.
## All scene code talks to this — never to raw data directly.

signal stats_recalculated(player_name: String)

## Safe numeric casts — JSON nulls survive .get() defaults when the key exists with null value.
static func _safe_int(val) -> int:
	return int(val) if val != null else 0

static func _safe_float(val) -> float:
	return float(val) if val != null else 0.0

# Cache of calculated stats per player name
var _calculated: Dictionary = {}  # name → CalculatedStats

# ── Stat Calculation ─────────────────────────────────────────────────────────

## Calculate the full stat block for a player including gear, artifacts, set bonuses.
func calculate_stats(player_name: String) -> CalculatedStats:
	# Try typed Resources first (host), fall back to _synced dicts (client)
	var player: PlayerData = SaveManager.get_player(player_name)
	if player != null:
		return _calculate_from_resources(player_name, player)
	return _calculate_from_synced(player_name)

func _calculate_from_resources(player_name: String, player: PlayerData) -> CalculatedStats:
	var calc = CalculatedStats.new()
	var weapon: OwnedWeapon = SaveManager.get_equipped_weapon(player_name)
	var artifacts: Array = SaveManager.get_equipped_artifacts(player_name)

	# Start from base stats
	for stat in EntityStats.stat_names():
		var value: float = player.stats.get_raw(stat)

		# Add weapon stats
		if weapon:
			for i in range(1, 4):
				var wstat: String = weapon.get("stat_%d_type" % i)
				if wstat != null and wstat.to_lower().replace(" ", "_") == stat:
					value += weapon.get("stat_%d_value" % i)

			# Add weapon stat modifier
			var wdef: WeaponData = weapon.get_definition() if weapon.weapon_id > 0 else null
			if wdef and wdef.stat_modifier != "" and wdef.stat_modifier.to_lower().contains(stat):
				value += wdef.stat_modifier_value

		# Add artifact stats
		for artifact in artifacts:
			for i in range(1, 3):
				var astat = artifact.get("stat_%d_type" % i)
				if astat != null and astat.to_lower().replace(" ", "_") == stat:
					value += artifact.get("stat_%d_value" % i)

		# Add artifact set bonuses
		var set_pieces = _count_artifact_sets(artifacts)
		for set_name in set_pieces:
			var piece_count: int = set_pieces[set_name]
			for bonus_type in [2, 4]:
				if piece_count < bonus_type:
					continue
				var bonus: ArtifactSetData = GameDB.get_artifact_bonus(set_name, bonus_type)
				if bonus == null or bonus.stat_modifier == "":
					continue
				if bonus.stat_modifier.to_lower().contains(stat):
					var meets_condition = true
					if bonus.condition != "":
						meets_condition = _check_artifact_condition(bonus, player)
					if meets_condition:
						value += bonus.stat_modifier_value

		# Apply DM overrides
		var override_key: String = str(stat) + "_override"
		if player.dm_overrides.has(override_key):
			value += float(player.dm_overrides[override_key])

		# Apply effect stat bonuses/multipliers from processor (host) or synced data (client)
		value = _apply_effect_stat_mods(player_name, stat, value)

		# Store
		match stat:
			"health": calc.health = snapped(value, 0.01)
			"attack": calc.attack = snapped(value, 0.01)
			"defense": calc.defense = snapped(value, 0.01)
			"elemental_mastery": calc.elemental_mastery = snapped(value, 0.01)
			"energy_recharge": calc.energy_recharge = snapped(value, 0.01)
			"critical_damage": calc.critical_damage = snapped(value, 0.01)

	# Combat state from save
	calc.current_health = player.current_health
	calc.max_health = player.max_health
	calc.burst_charges = player.burst_charges
	calc.shield_health = player.shield_health
	calc.shield_duration = player.shield_duration
	calc.applied_element = player.applied_element
	calc.crit_threshold = 20  # Default, modified by effects at runtime

	_calculated[player_name] = calc
	emit_signal("stats_recalculated", player_name)
	GameDB.update_player_ability_dice(calc.attack, calc.elemental_mastery)
	return calc

## Calculate stats from _synced dict data (client path — host is authoritative).
func _calculate_from_synced(player_name: String) -> CalculatedStats:
	var char_id: String = Global._synced_name.get("Characters", {}).get(player_name, "")
	var pd: Dictionary = Global._synced.get("Characters", {}).get(char_id, {})
	if pd.is_empty():
		return null

	var calc = CalculatedStats.new()

	# Base + skill points from synced character data, scaled per stat
	var stat_map = {
		"health": "Health", "attack": "Attack", "defense": "Defense",
		"elemental_mastery": "Elemental_Mastery", "energy_recharge": "Energy_Recharge",
		"critical_damage": "Critical_Damage"
	}
	var scaling = {
		"health": 2.0, "attack": 1.0, "defense": 1.0,
		"elemental_mastery": 1.0, "energy_recharge": 0.1, "critical_damage": 0.1,
	}
	for stat in stat_map:
		var key: String = stat_map[stat]
		var base: float = _safe_float(pd.get("%s_Base_Points" % key, 0))
		var skill: float = _safe_float(pd.get("%s_Skill_Points" % key, 0))
		var value: float = (base + skill) * scaling[stat]

		# Add weapon stats
		for w in Global._synced.get("Character_Weapons", {}).values():
			if w.get("Owner") == player_name and w.get("Equipped") == true:
				for i in range(1, 4):
					var wstat = str(w.get("Stat_%d_Type" % i, ""))
					if wstat != "" and wstat.to_lower().replace(" ", "_") == stat:
						value += _safe_float(w.get("Stat_%d_Value" % i, 0))
				# Weapon stat modifier from GameDB definition
				var wdef: WeaponData = GameDB.weapons_by_name.get(w.get("Weapon", ""), null)
				if wdef and wdef.stat_modifier != "" and wdef.stat_modifier.to_lower().contains(stat):
					value += wdef.stat_modifier_value
				break

		# Add artifact stats + count sets
		var set_pieces := {}
		for a in Global._synced.get("Character_Artifacts", {}).values():
			if a.get("Owner") == player_name and a.get("Equipped") == true:
				for i in range(1, 3):
					var astat = str(a.get("Stat_%d_Type" % i, ""))
					if astat != "" and astat.to_lower().replace(" ", "_") == stat:
						value += _safe_float(a.get("Stat_%d_Value" % i, 0))
				var sn = a.get("Artifact_Set", "")
				if sn != "":
					set_pieces[sn] = set_pieces.get(sn, 0) + 1

		# Artifact set bonuses
		for set_name in set_pieces:
			var piece_count: int = set_pieces[set_name]
			for bonus_type in [2, 4]:
				if piece_count < bonus_type:
					continue
				var bonus: ArtifactSetData = GameDB.get_artifact_bonus(set_name, bonus_type)
				if bonus == null or bonus.stat_modifier == "":
					continue
				if bonus.stat_modifier.to_lower().contains(stat):
					if bonus.condition != "":
						if bonus.condition == "Element" and pd.get("Element", "") != bonus.condition_value:
							continue
					value += bonus.stat_modifier_value

		# Apply effect stat bonuses/multipliers from processor (host) or synced data (client)
		value = _apply_effect_stat_mods(player_name, stat, value)

		match stat:
			"health": calc.health = snapped(value, 0.01)
			"attack": calc.attack = snapped(value, 0.01)
			"defense": calc.defense = snapped(value, 0.01)
			"elemental_mastery": calc.elemental_mastery = snapped(value, 0.01)
			"energy_recharge": calc.energy_recharge = snapped(value, 0.01)
			"critical_damage": calc.critical_damage = snapped(value, 0.01)

	calc.current_health = _safe_int(pd.get("Current_Health", 0))
	calc.max_health = _safe_int(pd.get("Max_Health", 0))
	calc.burst_charges = _safe_int(pd.get("Burst_Charges", 0))
	calc.shield_health = _safe_int(pd.get("Shield_Health", 0))
	calc.shield_duration = _safe_int(pd.get("Shield_Duration", 0))
	calc.applied_element = str(pd.get("Applied_Element", "None")) if pd.get("Applied_Element") != null else "None"
	calc.crit_threshold = 20

	_calculated[player_name] = calc
	emit_signal("stats_recalculated", player_name)
	GameDB.update_player_ability_dice(calc.attack, calc.elemental_mastery)
	return calc

## Get cached calculated stats (or recalculate if missing).
func get_stats(player_name: String) -> CalculatedStats:
	if not _calculated.has(player_name):
		return calculate_stats(player_name)
	return _calculated[player_name]

## Recalculate all players.
func recalculate_all() -> void:
	if SaveManager.data != null:
		for player in SaveManager.get_all_players():
			calculate_stats(player.name)
	else:
		for name in Global._synced_name.get("Characters", {}).keys():
			calculate_stats(name)

# ── Effect Stat Modifiers ────────────────────────────────────────────────────

## Apply STAT_BONUS and STAT_MULTIPLIER from effects. Works on both host (processor)
## and client (reads from synced ActiveEffects data).
func _apply_effect_stat_mods(player_name: String, stat: String, value: float) -> float:
	var cap_stat = stat.capitalize().replace(" ", "_")

	# Host path: query the processor directly (battle active)
	if Global.effect_processor:
		value += Global.effect_processor.stat_bonus(player_name, cap_stat)
		value *= Global.effect_processor.stat_multiplier(player_name, cap_stat)
		return value

	# Client path: read from synced effects data (battle active on client)
	var synced_fx = Global._synced.get("ActiveEffects", {}).get(player_name, [])
	var bonus_total = 0.0
	var mult_total = 1.0
	for fx in synced_fx:
		var fx_stat = str(fx.get("effect_stat", ""))
		if fx_stat != cap_stat:
			continue
		match fx.get("effect_type", ""):
			"STAT_BONUS":
				bonus_total += _safe_float(fx.get("value", 0))
			"STAT_MULTIPLIER":
				mult_total *= (1.0 + _safe_float(fx.get("value", 0)))

	# Fallback: if no battle effects, check weapon/artifact passive effects directly
	# This makes weapon effects like "+30% HP" apply outside of battle too
	if synced_fx.is_empty():
		for weapon in Global.CHARACTER_WEAPONS.values():
			if weapon.get("Owner") != player_name or weapon.get("Equipped") != true:
				continue
			var weapon_name = str(weapon.get("Weapon", weapon.get("Name", "")))
			var effects = WeaponEffects.get_effects(weapon_name)
			for eff in effects:
				if eff.trigger != "PASSIVE":
					continue
				if eff.effect_stat != cap_stat:
					continue
				match eff.effect_type:
					"STAT_BONUS":
						bonus_total += eff.effect_value
					"STAT_MULTIPLIER":
						mult_total *= (1.0 + eff.effect_value)

	value += bonus_total
	value *= mult_total
	return value

# ── Abilities ────────────────────────────────────────────────────────────────

## Get abilities available to a player based on their current element + weapon type.
func get_available_abilities(player_name: String) -> Array:
	var player: PlayerData = SaveManager.get_player(player_name)
	if player == null:
		return []

	var weapon: OwnedWeapon = SaveManager.get_equipped_weapon(player_name)
	var element: String = player.element
	var wtype: String = weapon.weapon_type if weapon else ""

	var result = []
	for ability in GameDB.abilities.values():
		# Match entity
		if ability.entity_type != "Character":
			continue
		if ability.entity_name != player_name and ability.entity_name != "":
			# Check if it's a generic ability for this player's entity_id
			if ability.entity_id != player.id:
				continue

		# Match element + weapon
		if ability.element != "" and ability.element != "Physical":
			if ability.element != element:
				continue
		if ability.weapon_type != "" and ability.weapon_type != wtype:
			continue

		result.append(ability)
	return result

## Get all abilities for a companion.
func get_companion_abilities(companion_name: String) -> Array:
	var comp: CompanionSaveData = SaveManager.get_companion(companion_name)
	if comp == null:
		return []

	var result = []
	for ability in GameDB.abilities.values():
		if ability.entity_type != "Companion":
			continue
		if ability.entity_name == companion_name or ability.entity_id == comp.id:
			result.append(ability)
	return result

# ── Equipment ────────────────────────────────────────────────────────────────

## Equip a weapon for a player. Unequips any currently equipped weapon.
func equip_weapon(player_name: String, weapon: OwnedWeapon) -> void:
	# Unequip current
	for w in SaveManager.get_all_owned_weapons():
		if w.owner == player_name and w.equipped:
			w.equipped = false
	# Equip new
	weapon.owner = player_name
	weapon.equipped = true
	calculate_stats(player_name)
	SaveManager.mark_dirty()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _count_artifact_sets(artifacts: Array) -> Dictionary:
	var sets = {}
	for a in artifacts:
		if a is OwnedArtifact:
			sets[a.artifact_set] = sets.get(a.artifact_set, 0) + 1
	return sets

func _check_artifact_condition(bonus: ArtifactSetData, player: PlayerData) -> bool:
	if bonus.condition == "Element":
		return player.element == bonus.condition_value
	return true
