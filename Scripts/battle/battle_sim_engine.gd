class_name BattleSimEngine extends RefCounted
## Headless battle simulator. Runs a single battle to completion with full
## damage formula, smart AI, effect system, and spatial model.
## Thread-safe — creates its own EffectProcessor instance.

const MAX_ROUNDS := 50  # Safety limit to prevent infinite battles
const DEFAULT_MOVEMENT := 7
const DEFAULT_REVIVES := 1  # Each player gets 1 revive

var _spatial: SimSpatial
var _effect_processor: EffectProcessor
var _battler_data: Dictionary = {}      # name -> battler dict (mutable clone)
var _cooldowns: Dictionary = {}         # name -> {ability_id: turns_remaining}
var _revives: Dictionary = {}           # name -> int (revives available)
var _turn_order: Array = []
var _turn_index: int = 0
var _round: int = 0
var _damage_mod_players: float = 1.0
var _damage_mod_enemies: float = 1.0

# Per-battle tracking
var _stats: Dictionary = {}  # name -> tracking dict


func run_battle(config: Dictionary) -> Dictionary:
	_init_battle(config)
	_register_effects(config)

	while _round < MAX_ROUNDS:
		_round += 1
		for i in range(_turn_order.size()):
			_turn_index = i
			var battler_name: String = _turn_order[i]
			var bd: Dictionary = _battler_data.get(battler_name, {})

			# Skip dead battlers
			if bd.get("killed_status", false):
				continue

			# Process start-of-turn effects
			_effect_processor.on_turn_start(battler_name, {})

			# Check stun/skip
			if bd.get("skipped_status", false):
				var skip_dur: int = int(bd.get("skipped_duration", 0))
				if skip_dur > 0:
					bd["skipped_duration"] = skip_dur - 1
					if skip_dur - 1 <= 0:
						bd["skipped_status"] = false
				_track(battler_name, "turns_skipped", 1)
				_effect_processor.on_turn_end(battler_name)
				continue

			# AI decides action
			var decision := SimAI.decide_turn(
				battler_name, bd, _battler_data, _spatial,
				_effect_processor, _cooldowns.get(battler_name, {}),
				_revives
			)

			match decision.get("action", "skip"):
				"attack":
					_execute_attack(battler_name, bd, decision)
				"revive":
					_execute_revive(battler_name, decision.get("targets", [])[0])
				"move_only":
					var target: String = decision.get("targets", [""])[0]
					if target != "":
						_spatial.move_toward(battler_name, target, float(decision.get("movement", DEFAULT_MOVEMENT)))
				"skip":
					pass

			# Process end-of-turn effects
			_effect_processor.on_turn_end(battler_name)

			# Tick cooldowns
			_tick_cooldowns(battler_name)

			# Check win/loss conditions
			var result := _check_battle_end()
			if result != "":
				return _build_result(result)

	# Max rounds reached — treat as loss
	return _build_result("loss")


func _init_battle(config: Dictionary) -> void:
	_spatial = SimSpatial.new()
	_effect_processor = EffectProcessor.new()
	_battler_data.clear()
	_cooldowns.clear()
	_revives.clear()
	_stats.clear()
	_turn_order.clear()
	_round = 0
	_damage_mod_players = config.get("damage_modifier_players", 1.0)
	_damage_mod_enemies = config.get("damage_modifier_enemies", 1.0)

	var player_names: Array = []
	var enemy_names: Array = []
	var enemy_sizes: Dictionary = {}

	# Build player battlers from config
	for pc in config.get("party", []):
		var name: String = pc.get("name", "")
		var char_raw = pc.get("character_data")
		var char_data: Dictionary = (char_raw.duplicate(true)) if char_raw is Dictionary else {}

		# Apply kit override
		var kit = pc.get("kit_override")
		if kit != null:
			char_data["Element"] = kit.get("element", char_data.get("Element", ""))

		# Get weapon and artifacts (override or current)
		var w_raw = pc.get("weapon_override")
		var weapon: Dictionary = w_raw if w_raw is Dictionary else {}
		var a_raw = pc.get("artifact_overrides")
		var artifacts: Array = a_raw if a_raw is Array else []

		# Calculate stats from character data + gear (not from live game state)
		var calc := _calc_stats(char_data, weapon, artifacts)

		# Build battler dict
		var bd := {
			"id": int(char_data.get("id", 0)),
			"name": name,
			"type": "Character",
			"entity_data": char_data,
			"entity_weapon_data": weapon,
			"entity_current_ability_data": _get_abilities_for_config(pc, char_data),
			"current_health": int(calc.get("health", 30)),
			"max_health": int(calc.get("health", 30)),
			"burst_charges": int(char_data.get("Burst_Charges", 0)),
			"applied_element": "None",
			"killed_status": false,
			"skipped_status": false,
			"skipped_duration": 0,
			"attack_stat": calc.get("attack", 10.0),
			"defense_stat": calc.get("defense", 10.0),
			"em_stat": calc.get("elemental_mastery", 7.0),
			"er_stat": calc.get("energy_recharge", 1.0),
			"crit_damage_stat": calc.get("critical_damage", 0.0),
			"crit_threshold": 20,
		}
		_battler_data[name] = bd
		_cooldowns[name] = {}
		_revives[name] = DEFAULT_REVIVES
		_stats[name] = _empty_stats()
		player_names.append(name)
		_turn_order.append(name)

	# Build companion battlers
	for pc in config.get("party", []):
		var comp = pc.get("companion_override")
		if comp == null or comp.is_empty():
			continue
		var comp_name: String = str(comp.get("Name", ""))
		if comp_name == "":
			continue
		var comp_bd := {
			"id": int(comp.get("id", 0)),
			"name": comp_name,
			"type": "Companion",
			"entity_data": comp.duplicate(true),
			"entity_weapon_data": {},
			"entity_current_ability_data": _get_companion_abilities(int(comp.get("id", 0))),
			"current_health": int(comp.get("Current_Health", comp.get("Max_Health", 20))),
			"max_health": int(comp.get("Max_Health", 20)),
			"burst_charges": 0,
			"applied_element": "None",
			"killed_status": false,
			"skipped_status": false,
			"skipped_duration": 0,
			"attack_stat": 8.0,
			"defense_stat": 8.0,
			"em_stat": 5.0,
			"er_stat": 1.0,
			"crit_damage_stat": 0.0,
			"crit_threshold": 20,
		}
		_battler_data[comp_name] = comp_bd
		_cooldowns[comp_name] = {}
		_revives[comp_name] = 0
		_stats[comp_name] = _empty_stats()
		player_names.append(comp_name)
		_turn_order.append(comp_name)

	# Build enemy battlers
	for enemy_config in config.get("enemies", []):
		var enemy_id: int = int(enemy_config.get("enemy_id", 0))
		var count: int = int(enemy_config.get("count", 1))
		var enemy_def: EnemyData = GameDB.enemies.get(enemy_id)
		if enemy_def == null:
			continue

		for i in range(count):
			var label := "%s %d" % [enemy_def.name, i + 1] if count > 1 else enemy_def.name
			var e_bd := {
				"id": enemy_id,
				"name": label,
				"type": "Enemy",
				"entity_data": {
					"Name": label,
					"EnemyName": enemy_def.name,
					"id": enemy_id,
					"Current_Health": enemy_def.phase1_hp,
					"Max_Health": enemy_def.phase1_hp,
					"Tier": enemy_def.tier,
					"Size": enemy_def.size_tiles,
					"Movement": enemy_def.size_tiles * 2,  # Larger enemies move more
				},
				"entity_current_ability_data": _get_enemy_abilities(enemy_id),
				"current_health": enemy_def.phase1_hp,
				"max_health": enemy_def.phase1_hp,
				"burst_charges": 0,
				"applied_element": "None",
				"killed_status": false,
				"skipped_status": false,
				"skipped_duration": 0,
				"attack_stat": 12.0,  # Enemies use tier-based dice, not stat-based
				"defense_stat": 12.0,
				"em_stat": 10.0,
				"er_stat": 1.0,
				"crit_damage_stat": 0.0,
				"crit_threshold": 20,
			}
			_battler_data[label] = e_bd
			_cooldowns[label] = {}
			_stats[label] = _empty_stats()
			enemy_names.append(label)
			enemy_sizes[label] = enemy_def.size_tiles
			_turn_order.append(label)

	# Initialize spatial
	_spatial.setup(player_names, enemy_names, enemy_sizes, config.get("arena_size", 20))


func _register_effects(config: Dictionary) -> void:
	# Register weapon effects for each player
	for pc in config.get("party", []):
		var name: String = pc.get("name", "")
		var w_raw = pc.get("weapon_override")
		var weapon: Dictionary = w_raw if w_raw is Dictionary else {}
		var weapon_name: String = str(weapon.get("Name", weapon.get("Weapon", "")))
		if weapon_name != "":
			var effects := WeaponEffects.get_effects(weapon_name)
			if effects.size() > 0:
				_effect_processor.register_battler(name, effects)

		# Register artifact set bonuses
		var art_raw = pc.get("artifact_overrides")
		var artifacts: Array = art_raw if art_raw is Array else []
		var set_counts: Dictionary = {}
		for a in artifacts:
			var set_name: String = str(a.get("Set_Name", a.get("Artifact_Set", "")))
			if set_name != "":
				set_counts[set_name] = set_counts.get(set_name, 0) + 1
		for set_name in set_counts:
			for bonus_type in [2, 4]:
				if set_counts[set_name] >= bonus_type:
					var bonus = GameDB.get_artifact_bonus(set_name, bonus_type)
					if bonus != null and bonus.effects.size() > 0:
						_effect_processor.register_battler(name, bonus.effects)

	# Register enemy ability passives
	for name in _battler_data:
		var bd: Dictionary = _battler_data[name]
		if bd.get("type") != "Enemy":
			continue
		var abilities: Dictionary = bd.get("entity_current_ability_data", {})
		for aid in abilities:
			var effects := AbilityEffects.get_effects(int(aid))
			var passives: Array = []
			for eff in effects:
				if eff is GameEffect and (eff.trigger == "PASSIVE" or eff.trigger == "ON_DAMAGE_TAKEN"):
					passives.append(eff)
			if passives.size() > 0:
				_effect_processor.register_battler(name, passives)


func _execute_attack(attacker_name: String, attacker_bd: Dictionary, decision: Dictionary) -> void:
	var ability: Dictionary = decision.get("ability", {})
	var targets: Array = decision.get("targets", [])
	var movement: int = int(decision.get("movement", DEFAULT_MOVEMENT))
	var is_player_side: bool = attacker_bd.get("type") != "Enemy"
	var damage_mod: float = _damage_mod_players if is_player_side else _damage_mod_enemies

	# Determine which stat to use for accuracy
	# Catalyst wielders always use EM
	# Everyone else: Basic/Charged use Attack, Skill/Burst use EM if elemental
	var ability_element: String = str(ability.get("element", "Physical"))
	var ab_type: String = str(ability.get("ability_type", "")).to_lower()
	var weapon_type: String = str(attacker_bd.get("entity_weapon_data", {}).get("Type", ""))
	var accuracy_stat: float = attacker_bd.get("attack_stat", 10.0)
	if weapon_type == "Catalyst":
		accuracy_stat = attacker_bd.get("em_stat", 7.0)
	elif not ab_type.contains("basic") and not ab_type.contains("charged"):
		if ability_element != "Physical" and ability_element != "None":
			accuracy_stat = attacker_bd.get("em_stat", 7.0)

	# Roll accuracy
	var attack_roll := DiceRoller.roll_stat(accuracy_stat)

	# For enemies, use tier-based dice instead of stat-based
	if not is_player_side:
		var tier: String = str(attacker_bd.get("entity_data", {}).get("Tier", "Common"))
		var enemy_dice: int = _tier_to_attack_die(tier)
		# Check if ability specifies its own dice
		var ab_dice: int = int(ability.get("dice_die", 0))
		if ab_dice > 0:
			enemy_dice = ab_dice
		attack_roll = DiceRoller.roll(enemy_dice)

	# Crit check
	var crit_threshold: int = attacker_bd.get("crit_threshold", 20)
	crit_threshold += _effect_processor.total_crit_threshold_mod(attacker_name)
	var is_crit: bool = attack_roll >= crit_threshold

	# Process ability use effects (ON_SKILL_USE, ON_BURST_USE)
	if ab_type.contains("skill"):
		_effect_processor.process_trigger(attacker_name, "ON_SKILL_USE", {"element": ability_element})
	elif ab_type.contains("burst"):
		_effect_processor.process_trigger(attacker_name, "ON_BURST_USE", {"element": ability_element})

	# Consume burst charges
	var charge_cost := int(ability.get("charge_cost", 0))
	if charge_cost > 0:
		attacker_bd["burst_charges"] = maxi(0, int(attacker_bd.get("burst_charges", 0)) - charge_cost)

	# Set cooldown
	var cd := int(ability.get("cooldown", 0))
	if cd > 0:
		var aid := int(ability.get("id", 0))
		if aid > 0:
			_cooldowns[attacker_name][aid] = cd

	var hits_count := maxi(1, int(ability.get("hits_count", 1)))

	# Process each target
	for target_name in targets:
		var target_bd: Dictionary = _battler_data.get(target_name, {})
		if target_bd.is_empty() or target_bd.get("killed_status", false):
			continue

		# Move into range if needed
		var ab_range := int(ability.get("targeting_length", 0))
		if not _spatial.in_range(attacker_name, target_name, ab_range):
			_spatial.move_toward(attacker_name, target_name, float(movement))

		# Still out of range after moving? Miss.
		if not _spatial.in_range(attacker_name, target_name, ab_range):
			_track(attacker_name, "misses", 1)
			continue

		# Roll defense
		var defense_stat: float = target_bd.get("defense_stat", 10.0)
		var defense_roll: int
		if target_bd.get("type") == "Enemy":
			var tier: String = str(target_bd.get("entity_data", {}).get("Tier", "Common"))
			defense_roll = DiceRoller.roll(_tier_to_defense_die(tier))
		else:
			defense_roll = DiceRoller.roll_stat(defense_stat)

		# Check bypass defense
		if ability.get("bypass_defense", false):
			defense_roll = 0

		# Calculate difference
		var diff := attack_roll - defense_roll
		if diff <= 0:
			_track(attacker_name, "misses", 1)
			continue

		# Get effect modifiers
		var hit_ctx := {
			"attack_type": ab_type,
			"element": ability_element,
			"is_crit": is_crit,
			"target_element": target_bd.get("applied_element", "None"),
		}
		var flat_mod := _effect_processor.sum_flat_damage(attacker_name, "ON_HIT", hit_ctx)
		var mult_mod := _effect_processor.damage_multiplier(attacker_name, "ON_HIT", hit_ctx)
		if is_crit:
			flat_mod += _effect_processor.sum_flat_damage(attacker_name, "ON_CRIT", hit_ctx)
			mult_mod *= _effect_processor.damage_multiplier(attacker_name, "ON_CRIT", hit_ctx)

		# Roll damage
		var total_damage := DiceRoller.roll_damage(diff, hits_count, flat_mod, mult_mod)

		# Apply crit multiplier
		if is_crit:
			var crit_dmg_stat := attacker_bd.get("crit_damage_stat", 0.0)
			if crit_dmg_stat > 0:
				total_damage = int(float(total_damage) * (1.0 + crit_dmg_stat))
			_track(attacker_name, "crits", 1)

		# Apply damage modifier
		total_damage = int(float(total_damage) * damage_mod)
		total_damage = maxi(total_damage, 1)

		# Apply element and check reaction
		var reaction := false
		if ability_element != "Physical" and ability_element != "None":
			var current_elem: String = target_bd.get("applied_element", "None")
			if current_elem != "None" and current_elem != ability_element:
				reaction = true
				target_bd["applied_element"] = "None"
			else:
				target_bd["applied_element"] = ability_element

		# Reaction damage bonus
		if reaction:
			var react_ctx := {"reaction_element": target_bd.get("applied_element", "None"), "attack_element": ability_element, "is_crit": is_crit}
			var react_actions := _effect_processor.process_trigger(attacker_name, "ON_REACTION", react_ctx)
			for act in react_actions:
				match str(act.get("effect_type", "")):
					"FLAT_DAMAGE":
						total_damage += int(act.get("value", 0))
					"PERCENT_DAMAGE":
						total_damage = int(float(total_damage) * float(act.get("value", 1.0)))

		# Apply damage to target
		_apply_damage(target_name, total_damage, attacker_name)

		# Apply status effect from ability
		var status_id := int(ability.get("effect_status", 0))
		if status_id > 0:
			var status_data = GameDB.status_effects.get(status_id)
			if status_data:
				var status_effects := StatusEffectsMap.get_effects(status_data.name)
				var duration := int(ability.get("effect_status_duration_rounds", 1))
				for eff in status_effects:
					if eff is GameEffect:
						eff.duration = duration
						_effect_processor.add_effect(target_name, eff, "status", status_data.name)

		# Track stats
		_track(attacker_name, "damage_dealt", total_damage)
		_track_ability(attacker_name, str(ability.get("name", "Unknown")), total_damage)

	# Generate burst charges
	var burst_gained := int(ability.get("burst_gained", 0))
	if burst_gained > 0:
		attacker_bd["burst_charges"] = mini(
			int(attacker_bd.get("burst_charges", 0)) + burst_gained,
			10  # Burst cap
		)


func _apply_damage(target_name: String, damage: int, attacker_name: String) -> void:
	var bd: Dictionary = _battler_data.get(target_name, {})
	if bd.is_empty():
		return

	# Route through shield first
	var shield := int(bd.get("shield_health", 0))
	if shield > 0:
		if damage <= shield:
			bd["shield_health"] = shield - damage
			_track(target_name, "damage_absorbed", damage)
			return
		else:
			_track(target_name, "damage_absorbed", shield)
			damage -= shield
			bd["shield_health"] = 0

	var hp := int(bd.get("current_health", 0))
	hp -= damage
	bd["current_health"] = maxi(hp, 0)
	_track(target_name, "damage_taken", damage)

	if hp <= 0:
		bd["killed_status"] = true
		_track(target_name, "times_downed", 1)
		_spatial.remove(target_name)


func _execute_revive(reviver: String, target: String) -> void:
	var bd: Dictionary = _battler_data.get(target, {})
	if bd.is_empty():
		return
	bd["killed_status"] = false
	bd["current_health"] = int(bd.get("max_health", 20)) / 2  # Revive at half HP
	_revives[reviver] = _revives.get(reviver, 0) - 1
	_track(reviver, "times_reviving_others", 1)
	_track(target, "times_revived", 1)
	# Re-add to spatial
	_spatial._positions[target] = _spatial.get_position(reviver)


func _tick_cooldowns(battler_name: String) -> void:
	var cds: Dictionary = _cooldowns.get(battler_name, {})
	for aid in cds.keys():
		cds[aid] = maxi(0, cds[aid] - 1)


func _check_battle_end() -> String:
	var players_alive := false
	var enemies_alive := false
	for name in _battler_data:
		var bd: Dictionary = _battler_data[name]
		if bd.get("killed_status", false):
			continue
		if bd.get("type") == "Enemy":
			enemies_alive = true
		else:
			players_alive = true
	if not enemies_alive:
		return "win"
	if not players_alive:
		return "loss"
	return ""


func _build_result(outcome: String) -> Dictionary:
	var result := {
		"outcome": outcome,
		"total_rounds": _round,
		"per_battler": {},
		"revives_used": 0,
		"items_used": 0,
	}
	var total_revives := 0
	for name in _stats:
		var s: Dictionary = _stats[name]
		result["per_battler"][name] = s.duplicate(true)
		total_revives += int(s.get("times_reviving_others", 0))
		# Check for deaths (still downed at battle end)
		if _battler_data.has(name) and _battler_data[name].get("killed_status", false):
			s["deaths"] = 1
	result["revives_used"] = total_revives
	return result


func _empty_stats() -> Dictionary:
	return {
		"damage_dealt": 0,
		"damage_taken": 0,
		"damage_absorbed": 0,
		"healing_done": 0,
		"times_downed": 0,
		"times_revived": 0,
		"times_reviving_others": 0,
		"deaths": 0,
		"crits": 0,
		"misses": 0,
		"turns_skipped": 0,
		"abilities_used": {},
	}

func _track(name: String, field: String, amount: int) -> void:
	if _stats.has(name):
		_stats[name][field] = int(_stats[name].get(field, 0)) + amount

func _track_ability(name: String, ability_name: String, damage: int) -> void:
	if not _stats.has(name):
		return
	var abilities: Dictionary = _stats[name].get("abilities_used", {})
	if not abilities.has(ability_name):
		abilities[ability_name] = {"uses": 0, "total_damage": 0}
	abilities[ability_name]["uses"] += 1
	abilities[ability_name]["total_damage"] += damage
	_stats[name]["abilities_used"] = abilities


func _get_abilities_for_config(pc: Dictionary, char_data: Dictionary) -> Dictionary:
	var element: String = str(char_data.get("Element", ""))
	var kit = pc.get("kit_override")
	if kit != null:
		element = str(kit.get("element", element))
	var weapon_type: String = ""
	var weapon_raw = pc.get("weapon_override")
	var weapon: Dictionary = weapon_raw if weapon_raw is Dictionary else {}
	if weapon.has("Type"):
		weapon_type = str(weapon.get("Type", ""))
	elif kit != null:
		weapon_type = str(kit.get("weapon_type", ""))
	# If still no weapon type, look up the player's currently equipped weapon
	if weapon_type == "":
		var pname: String = str(pc.get("name", ""))
		for rid in Global._synced.get("Character_Weapons", {}):
			var w: Dictionary = Global._synced["Character_Weapons"][rid]
			if w.get("Owner") == pname and w.get("Equipped", false):
				weapon_type = str(w.get("Type", ""))
				break

	var result: Dictionary = {}
	var char_id := int(char_data.get("id", 0))
	for a in GameDB.abilities_by_entity.values():
		if a.entity_type == "Character" and a.entity_id == char_id:
			if a.kit_element == element and (weapon_type == "" or a.weapon_type == weapon_type):
				result[a.id] = _ability_to_dict(a)
	return result


func _get_companion_abilities(comp_id: int) -> Dictionary:
	var result: Dictionary = {}
	for a in GameDB.abilities_by_entity.values():
		if a.entity_type == "Companion" and a.entity_id == comp_id:
			result[a.id] = _ability_to_dict(a)
	return result


func _get_enemy_abilities(enemy_id: int) -> Dictionary:
	var result: Dictionary = {}
	for a in GameDB.abilities_by_entity.values():
		if a.entity_type == "Enemy" and a.entity_id == enemy_id:
			result[a.id] = _ability_to_dict(a)
	return result


func _ability_to_dict(a: AbilityData) -> Dictionary:
	return {
		"id": a.id,
		"name": a.name,
		"element": a.element,
		"ability_type": a.ability_type,
		"dice_count": a.dice_count,
		"dice_die": a.dice_die,
		"dice_flat": a.dice_flat,
		"hits_count": a.hits_count,
		"defense_threshold": a.defense_threshold,
		"bypass_defense": a.bypass_defense,
		"targeting_type": a.targeting_type,
		"targeting_length": a.targeting_length,
		"targeting_radius": a.targeting_radius,
		"cooldown": a.cooldown,
		"charge_cost": a.charge_cost,
		"movement": a.movement,
		"effect_status": a.effect_status,
		"effect_status_duration_rounds": a.effect_status_duration_rounds,
		"effect_status_target": a.effect_status_target,
	}


## Calculate stats from character data + weapon + artifacts (not from live game state).
## Mirrors CharacterManager._calculate_from_synced but uses provided overrides.
static func _calc_stats(char_data: Dictionary, weapon: Dictionary, artifacts: Array) -> Dictionary:
	var stat_map := {
		"health": "Health", "attack": "Attack", "defense": "Defense",
		"elemental_mastery": "Elemental_Mastery", "energy_recharge": "Energy_Recharge",
		"critical_damage": "Critical_Damage"
	}
	var scaling := {
		"health": 2.0, "attack": 1.0, "defense": 1.0,
		"elemental_mastery": 1.0, "energy_recharge": 0.1, "critical_damage": 0.1,
	}
	var result := {}
	for stat in stat_map:
		var key: String = stat_map[stat]
		var base := _sf(char_data.get("%s_Base_Points" % key, 0))
		var skill := _sf(char_data.get("%s_Skill_Points" % key, 0))
		var value: float = (base + skill) * scaling[stat]

		# Add weapon stats
		if not weapon.is_empty():
			for i in range(1, 4):
				var wstat: String = str(weapon.get("Stat_%d_Type" % i, ""))
				if wstat != "" and wstat.to_lower().replace(" ", "_") == stat:
					value += _sf(weapon.get("Stat_%d_Value" % i, 0))
			# Weapon stat modifier from GameDB definition
			var wname: String = str(weapon.get("Weapon", weapon.get("Name", "")))
			var wdef = GameDB.weapons_by_name.get(wname, null)
			if wdef and wdef.stat_modifier != "" and wdef.stat_modifier.to_lower().contains(stat):
				value += wdef.stat_modifier_value

		# Add artifact stats + count sets
		var set_pieces := {}
		for a in artifacts:
			if not a is Dictionary:
				continue
			for i in range(1, 3):
				var astat: String = str(a.get("Stat_%d_Type" % i, ""))
				if astat != "" and astat.to_lower().replace(" ", "_") == stat:
					value += _sf(a.get("Stat_%d_Value" % i, 0))
			var sn: String = str(a.get("Artifact_Set", a.get("Set_Name", "")))
			if sn != "":
				set_pieces[sn] = set_pieces.get(sn, 0) + 1

		# Artifact set bonuses
		for set_name in set_pieces:
			var piece_count: int = set_pieces[set_name]
			for bonus_type in [2, 4]:
				if piece_count < bonus_type:
					continue
				var bonus = GameDB.get_artifact_bonus(set_name, bonus_type)
				if bonus == null or bonus.stat_modifier == "":
					continue
				if bonus.stat_modifier.to_lower().contains(stat):
					if bonus.condition != "":
						if bonus.condition == "Element" and str(char_data.get("Element", "")) != bonus.condition_value:
							continue
					value += bonus.stat_modifier_value

		result[stat] = snapped(value, 0.01)
	return result

static func _sf(val) -> float:
	return float(val) if val != null else 0.0


static func _tier_to_defense_die(tier: String) -> int:
	match tier.to_lower():
		"common": return 12
		"uncommon", "rare": return 16
		"epic", "boss", "legendary": return 20
	return 12


static func _tier_to_attack_die(tier: String) -> int:
	# Default attack dice when ability doesn't specify
	return _tier_to_defense_die(tier)
