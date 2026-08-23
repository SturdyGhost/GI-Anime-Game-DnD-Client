class_name BattleSimEngine extends RefCounted
## Headless battle simulator. Runs a single battle to completion with full
## damage formula, smart AI, effect system, and spatial model.
## Thread-safe — creates its own EffectProcessor instance.

const MAX_ROUNDS := 50  # Safety limit to prevent infinite battles
const DEFAULT_MOVEMENT := 7
const DEFAULT_REVIVES := 1  # Each player gets 1 revive
var debug_log: bool = false  # Set true to print turn-by-turn details

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
var _player_attack_stats: Array = []  # Individual player attack stats for companion averaging
var _player_em_stats: Array = []      # Individual player EM stats for companion averaging

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

			if debug_log:
				var ab_name: String = str(decision.get("ability", {}).get("name", ""))
				var tgt: String = str(decision.get("targets", [""])[0]) if decision.get("targets", []).size() > 0 else ""
				var hp_str: String = "%d/%d" % [int(bd.get("current_health", 0)), int(bd.get("max_health", 0))]
				var num_abilities: int = bd.get("entity_current_ability_data", {}).size()
				var atk_s: float = bd.get("attack_stat", 0)
				var em_s: float = bd.get("em_stat", 0)
				var wtype: String = str(bd.get("entity_weapon_data", {}).get("Type", "?"))
				print("R%d %s [%s] hp=%s action=%s ability=%s target=%s burst=%d abs=%d atk=%.0f em=%.0f wep=%s pos=%.0f" % [
					_round, battler_name, bd.get("type", "?"), hp_str,
					decision.get("action", "?"), ab_name, tgt,
					int(bd.get("burst_charges", 0)), num_abilities, atk_s, em_s, wtype,
					_spatial.get_position(battler_name)
				])

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
	_player_attack_stats.clear()
	_player_em_stats.clear()
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

		# Apply manual stat overrides (sandbox "what if" testing)
		var overrides = pc.get("stat_overrides")
		if overrides is Dictionary:
			for stat_key in overrides:
				if calc.has(stat_key):
					calc[stat_key] = float(overrides[stat_key])

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
		# Store individual stats for companion roll averaging
		_player_attack_stats.append(calc.get("attack", 10.0))
		_player_em_stats.append(calc.get("elemental_mastery", 7.0))

	# Average player BASE points (skill excluded) — the companion stat floor.
	var avg_base := {"Health": 0.0, "Attack": 0.0, "Defense": 0.0,
		"Elemental_Mastery": 0.0, "Energy_Recharge": 0.0, "Critical_Damage": 0.0}
	var pc_count := 0
	for pname in player_names:
		var pbd: Dictionary = _battler_data.get(pname, {})
		if pbd.get("type") == "Character":
			var ed: Dictionary = pbd.get("entity_data", {})
			for k in avg_base:
				avg_base[k] += _sf(ed.get("%s_Base_Points" % k, 0))
			pc_count += 1
	if pc_count > 0:
		for k in avg_base:
			avg_base[k] /= float(pc_count)

	# Build companion battlers — add ALL active companions from config + _synced
	var added_companions: Dictionary = {}  # Track by name to avoid duplicates

	# First add any companion overrides from config
	for pc in config.get("party", []):
		var comp = pc.get("companion_override")
		if comp == null or not comp is Dictionary or comp.is_empty():
			continue
		var comp_name: String = str(comp.get("Name", ""))
		if comp_name == "" or added_companions.has(comp_name):
			continue
		added_companions[comp_name] = comp

	# Then scan all companions in _synced for any active ones owned by party members
	var party_names_set: Dictionary = {}
	for pn in player_names:
		party_names_set[pn] = true
	for rid in Global._synced.get("Companions", {}):
		var c: Dictionary = Global._synced["Companions"][rid]
		var owner: String = str(c.get("Owner", ""))
		var comp_name: String = str(c.get("Name", ""))
		if comp_name == "" or added_companions.has(comp_name):
			continue
		if owner in party_names_set and c.get("Active", false):
			added_companions[comp_name] = c

	for comp_name in added_companions:
		var comp: Dictionary = added_companions[comp_name]
		# Synthetic char_data: averaged player base points, zero skill points.
		var synth := {"Element": str(comp.get("Element", ""))}
		for k in avg_base:
			synth["%s_Base_Points" % k] = avg_base[k]
			synth["%s_Skill_Points" % k] = 0
		# Companion's own equipped weapon + artifacts.
		var comp_weapon := {}
		for w in Global.CHARACTER_WEAPONS.values():
			if str(w.get("Owner", "")) == comp_name \
					and str(w.get("Owner_Type", "Character")) == "Companion" \
					and w.get("Equipped") == true:
				comp_weapon = w
				break
		var comp_arts: Array = []
		for a in Global.CHARACTER_ARTIFACTS.values():
			if str(a.get("Owner", "")) == comp_name \
					and str(a.get("Owner_Type", "Character")) == "Companion" \
					and a.get("Equipped") == true:
				comp_arts.append(a)
		# Companions build their own battler from averaged player base + own gear.
		var ccalc := _calc_stats(synth, comp_weapon, comp_arts)
		var comp_hp := int(ccalc.get("health", 20))
		if comp_hp <= 0:
			comp_hp = 20
		var comp_bd := {
			"id": int(comp.get("id", 0)),
			"name": comp_name,
			"type": "Companion",
			"entity_data": comp.duplicate(true),
			"entity_weapon_data": comp_weapon,
			"equipped_artifacts": comp_arts,
			"equipped_weapon": comp_weapon,
			"entity_current_ability_data": _get_companion_abilities(int(comp.get("id", 0))),
			"current_health": comp_hp,
			"max_health": comp_hp,
			"burst_charges": 0,
			"applied_element": "None",
			"killed_status": false,
			"skipped_status": false,
			"skipped_duration": 0,
			"attack_stat": ccalc.get("attack", 8.0),
			"defense_stat": ccalc.get("defense", 8.0),
			"em_stat": ccalc.get("elemental_mastery", 5.0),
			"er_stat": ccalc.get("energy_recharge", 1.0),
			"crit_damage_stat": ccalc.get("critical_damage", 0.0),
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
					"Movement": maxi(enemy_def.size_tiles * 2, 5),  # Min 5 movement, larger enemies move more
				},
				"entity_current_ability_data": _get_enemy_abilities(enemy_id),
				"current_health": enemy_def.phase1_hp,
				"max_health": enemy_def.phase1_hp,
				"burst_charges": 0,
				"applied_element": "None",
				"killed_status": false,
				"skipped_status": false,
				"skipped_duration": 0,
				"attack_stat": float(_tier_to_attack_die(enemy_def.tier)),
				"defense_stat": float(_tier_to_defense_die(enemy_def.tier)),
				"em_stat": float(_tier_to_attack_die(enemy_def.tier)),
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
		var weapon_name: String = str(weapon.get("Weapon", weapon.get("Name", "")))
		if weapon_name != "":
			# Try WeaponEffects lookup first, then GameDB weapon resource effects
			var effects := WeaponEffects.get_effects(weapon_name)
			if effects.is_empty():
				var wdef = GameDB.weapons_by_name.get(weapon_name, null)
				if wdef and wdef.effects.size() > 0:
					effects = wdef.effects
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

	# Register talent effects for each player
	for pc in config.get("party", []):
		var pname: String = pc.get("name", "")
		var char_raw = pc.get("character_data")
		var char_data: Dictionary = char_raw if char_raw is Dictionary else {}
		var element: String = str(char_data.get("Element", ""))
		var kit = pc.get("kit_override")
		if kit != null:
			element = str(kit.get("element", element))
		var talent_effects := TalentEffects.get_player_talent_effects(pname, element)
		if talent_effects.size() > 0:
			_effect_processor.register_battler(pname, talent_effects)

	# Register player/companion ability effects — only persistent combat modifiers.
	# Skip temporary ability mechanics (movement lock, extra actions, immunity)
	# that should only apply during the turn the ability is used.
	const SKIP_PERMANENT := ["PREVENT_MOVEMENT", "EXTRA_ACTION", "DOUBLE_ACTION",
		"DAMAGE_IMMUNITY", "SUMMON", "MOVEMENT_COST"]
	for name in _battler_data:
		var bd: Dictionary = _battler_data[name]
		if bd.get("type") == "Enemy":
			continue
		var abilities: Dictionary = bd.get("entity_current_ability_data", {})
		for aid in abilities:
			var effects := AbilityEffects.get_effects(int(aid))
			var filtered: Array = []
			for eff in effects:
				if eff is GameEffect and eff.effect_type in SKIP_PERMANENT and eff.trigger == "PASSIVE":
					continue  # Don't register as permanent
				filtered.append(eff)
			if filtered.size() > 0:
				_effect_processor.register_battler(name, filtered)

	# Register companion ability passives from GameDB
	for name in _battler_data:
		var bd: Dictionary = _battler_data[name]
		if bd.get("type") != "Companion":
			continue
		var comp_id := int(bd.get("id", 0))
		for a in GameDB.abilities_by_entity.values():
			if a.entity_type == "Companion" and a.entity_id == comp_id and a.effects.size() > 0:
				var passive_effects: Array = []
				for eff in a.effects:
					if eff is GameEffect and (eff.trigger == "PASSIVE" or eff.trigger == "ON_DAMAGE_TAKEN"):
						passive_effects.append(eff)
				if passive_effects.size() > 0:
					_effect_processor.register_battler(name, passive_effects)

	# Register companion gear effects (weapon + artifact set bonuses)
	for name in _battler_data:
		var bd: Dictionary = _battler_data[name]
		if bd.get("type") != "Companion":
			continue
		var cw: Dictionary = bd.get("equipped_weapon", {})
		var cw_name: String = str(cw.get("Weapon", cw.get("Name", "")))
		if cw_name != "":
			var weffects := WeaponEffects.get_effects(cw_name)
			if weffects.is_empty():
				var wdef = GameDB.weapons_by_name.get(cw_name, null)
				if wdef and wdef.effects.size() > 0:
					weffects = wdef.effects
			if weffects.size() > 0:
				_effect_processor.register_battler(name, weffects)
		var carts: Array = bd.get("equipped_artifacts", [])
		var set_counts: Dictionary = {}
		for a in carts:
			var sn: String = str(a.get("Artifact_Set", a.get("Set_Name", "")))
			if sn != "":
				set_counts[sn] = set_counts.get(sn, 0) + 1
		for sn in set_counts:
			for bonus_type in [2, 4]:
				if set_counts[sn] >= bonus_type:
					var bonus = GameDB.get_artifact_bonus(sn, bonus_type)
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
	var attack_roll: int
	if attacker_bd.get("type") == "Companion":
		# Companions: N players each roll the COMPANION's stat die; take the best (max).
		attack_roll = _best_of_n_roll(accuracy_stat)
	elif attacker_bd.get("type") == "Enemy":
		# Enemies roll their tier accuracy die (combo dice, e.g. uncommon = D16 = D10+D6).
		# Accuracy is purely tier-driven now; abilities only flavor the hit, not the roll.
		var tier: String = str(attacker_bd.get("entity_data", {}).get("Tier", "Common"))
		attack_roll = DiceRoller.roll_dice_array(DiceRoller.enemy_accuracy_dice(tier))
	else:
		# Players: roll based on accuracy stat
		attack_roll = DiceRoller.roll_stat(accuracy_stat)

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

		# Determine effective range and movement
		var targeting_type: String = str(ability.get("targeting_type", ""))
		var ab_range := int(ability.get("targeting_length", 0))
		# Global with range 0 = melee AoE (adjacent tiles, range 1)
		if targeting_type.to_lower() == "global" and ab_range <= 0:
			ab_range = 1
		# Total movement = base movement + ability built-in movement
		var ab_movement := int(ability.get("movement", 0))
		var total_move := float(movement + ab_movement)

		# Move into range if needed
		if not _spatial.in_range(attacker_name, target_name, ab_range):
			_spatial.move_toward(attacker_name, target_name, total_move)
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
		elif target_bd.get("type") == "Companion":
			# Companions: N players each roll the companion's defense die; take the best.
			defense_roll = _best_of_n_roll(defense_stat)
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
		# Roll D20 for dice-check effects (Prototype Archaic, Sacrificial weapons, etc.)
		var dice_check_roll := DiceRoller.roll(20)
		var hit_ctx := {
			"attack_type": ab_type,
			"element": ability_element,
			"is_crit": is_crit,
			"target_element": target_bd.get("applied_element", "None"),
			"dice_roll": dice_check_roll,
		}
		var flat_mod := _effect_processor.sum_flat_damage(attacker_name, "ON_HIT", hit_ctx)
		var mult_mod := _effect_processor.damage_multiplier(attacker_name, "ON_HIT", hit_ctx)
		if is_crit:
			flat_mod += _effect_processor.sum_flat_damage(attacker_name, "ON_CRIT", hit_ctx)
			mult_mod *= _effect_processor.damage_multiplier(attacker_name, "ON_CRIT", hit_ctx)

		# Determine damage based on attacker type
		var total_damage: int
		var ability_name: String = str(ability.get("name", ""))

		var attacker_type: String = str(attacker_bd.get("type", ""))
		var ab_dice_die := int(ability.get("dice_die", 0))
		if attacker_type == "Enemy":
			# Enemy damage (tier formula): roll N tier dice of the closest die to the
			# attack-defense difference, plus the tier's flat floor. The ability's own
			# dice_count/dice_die/dice_flat are ignored for enemy damage.
			var enemy_tier: String = str(attacker_bd.get("entity_data", {}).get("Tier", "Common"))
			var enemy_base := DiceRoller.roll_enemy_tier_damage(diff, enemy_tier)
			total_damage = int((float(enemy_base) + flat_mod) * mult_mod)
			total_damage = DiceRoller.multi_hit_total(maxi(total_damage, 1), hits_count)
		elif attacker_type == "Companion" and ab_dice_die > 0:
			# Enemy/Companion damage: roll ability's dice directly (dice_count * d(dice_die) + dice_flat)
			# The hit check (attack > defense) already passed — damage uses ability dice, not difference
			var ab_dice_count := maxi(int(ability.get("dice_count", 1)), 1)
			var ab_dice_flat := int(ability.get("dice_flat", 0))
			var raw_roll := 0
			for _d in range(ab_dice_count):
				raw_roll += DiceRoller.roll(ab_dice_die)
			raw_roll += ab_dice_flat
			total_damage = int((float(raw_roll) + flat_mod) * mult_mod)
			total_damage = DiceRoller.multi_hit_total(maxi(total_damage, 1), hits_count)
		elif _is_escalation_ability(ability_name, ability_element):
			# Check for talent modifiers
			var has_push_further := _has_effect_type(attacker_name, "ESCALATION_THRESHOLD_REDUCTION")
			var has_lucky_collapse := _has_effect_type(attacker_name, "ESCALATION_LUCKY_COLLAPSE")
			var has_burst_per_step := _has_effect_type(attacker_name, "ESCALATION_BURST_CHARGE")
			# Escalation replaces the standard damage die step
			var hp_available: int = int(attacker_bd.get("current_health", 0)) - 1
			var esc_result := DiceRoller.roll_escalation(hp_available, has_push_further)
			if esc_result.get("succeeded", false):
				total_damage = int((float(esc_result.get("damage", 0)) + flat_mod) * mult_mod)
			elif has_lucky_collapse:
				# Lucky Collapse: on failure, deal half of highest successful roll
				var highest: int = 0
				for r in esc_result.get("rolls", []):
					highest = maxi(highest, int(r))
				total_damage = int((float(highest) / 2.0 + flat_mod) * mult_mod)
			else:
				total_damage = 0
			# Apply passive HP cost
			var hp_spent: int = esc_result.get("hp_spent", 0)
			if hp_spent > 0:
				attacker_bd["current_health"] = maxi(int(attacker_bd.get("current_health", 0)) - hp_spent, 1)
			# High Roller: +1 burst charge per successful escalation step
			if has_burst_per_step:
				var steps = esc_result.get("rolls", []).size()
				var burst_cap := 10
				var abilities_dict: Dictionary = attacker_bd.get("entity_current_ability_data", {})
				for aid in abilities_dict:
					var ab: Dictionary = abilities_dict[aid]
					if str(ab.get("ability_type", "")).to_lower().contains("burst"):
						burst_cap = maxi(int(ab.get("charge_cost", 10)), 1)
						break
				attacker_bd["burst_charges"] = mini(
					int(attacker_bd.get("burst_charges", 0)) + steps,
					burst_cap
				)
		else:
			# Standard damage formula
			total_damage = DiceRoller.roll_damage(diff, hits_count, flat_mod, mult_mod)

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

		if debug_log:
			print("  -> %s atk_roll=%d def_roll=%d diff=%d dmg=%d crit=%s" % [
				target_name, attack_roll, defense_roll, diff, total_damage, str(is_crit)])

		# Apply damage to target
		_apply_damage(target_name, total_damage, attacker_name)

		# Process all ON_HIT triggered effects beyond flat/percent damage
		_process_hit_effects(attacker_name, attacker_bd, target_name, target_bd,
			hit_ctx, total_damage, diff, hits_count, flat_mod, mult_mod, damage_mod)

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

	# Generate burst charges — Skills and Charged Attacks roll 1d4 * ER
	if ab_type.contains("skill") or ab_type.contains("charged"):
		var d4_roll := DiceRoller.roll(4)
		var er: float = attacker_bd.get("er_stat", 1.0)
		var burst_gained := int(float(d4_roll) * er)
		# Burst cap = cost of their Burst ability (find it)
		var burst_cap := 10
		var abilities_dict: Dictionary = attacker_bd.get("entity_current_ability_data", {})
		for aid in abilities_dict:
			var ab: Dictionary = abilities_dict[aid]
			var abt: String = str(ab.get("ability_type", "")).to_lower()
			if abt.contains("burst"):
				burst_cap = maxi(int(ab.get("charge_cost", 10)), 1)
				break
		attacker_bd["burst_charges"] = mini(
			int(attacker_bd.get("burst_charges", 0)) + burst_gained,
			burst_cap
		)


## Best-of-N roll of a stat die. N = number of player characters — each rolls the
## companion's die and the highest result is used (mirrors the table best-of-N rule).
func _best_of_n_roll(stat_value: float) -> int:
	var n := maxi(_player_attack_stats.size(), 1)
	var best := 0
	for _i in range(n):
		best = maxi(best, DiceRoller.roll_stat(stat_value))
	return best


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


## Process triggered effects beyond flat/percent damage mods (which are already applied).
## Handles: REPEAT_ATTACK, BURST_CHARGE_GAIN, SHIELD_GENERATE, HEAL, KNOCKBACK, etc.
func _process_hit_effects(
	attacker_name: String, attacker_bd: Dictionary,
	target_name: String, target_bd: Dictionary,
	hit_ctx: Dictionary, damage_dealt: int,
	diff: int, hits: int, flat_mod: float, mult_mod: float, damage_mod: float
) -> void:
	var actions := _effect_processor.process_trigger(attacker_name, "ON_HIT", hit_ctx)
	if hit_ctx.get("is_crit", false):
		actions.append_array(_effect_processor.process_trigger(attacker_name, "ON_CRIT", hit_ctx))

	for act in actions:
		var etype: String = str(act.get("effect_type", ""))
		var value: float = float(act.get("value", 0))
		match etype:
			"REPEAT_ATTACK":
				# Condition already passed via EffectProcessor's DICE_ROLL_CHECK
				# Repeat the damage roll
				var repeat_dmg := DiceRoller.roll_damage(diff, hits, flat_mod, mult_mod)
				repeat_dmg = int(float(repeat_dmg) * damage_mod)
				repeat_dmg = maxi(repeat_dmg, 1)
				_apply_damage(target_name, repeat_dmg, attacker_name)
				_track(attacker_name, "damage_dealt", repeat_dmg)

			"BURST_CHARGE_GAIN":
				var gain := int(value)
				if str(act.get("dice", "")) != "":
					var parts = str(act.get("dice", "")).split("d")
					if parts.size() == 2:
						for _j in range(int(parts[0])):
							gain += DiceRoller.roll(int(parts[1]))
				# Apply ER scaling if specified
				if str(act.get("value_is_percent_of", "")) == "Energy_Recharge":
					gain = int(float(gain) * attacker_bd.get("er_stat", 1.0))
				var burst_cap := _get_burst_cap(attacker_bd)
				attacker_bd["burst_charges"] = mini(
					int(attacker_bd.get("burst_charges", 0)) + gain, burst_cap)

			"SHIELD_GENERATE":
				var shield_amount := int(value)
				target_bd["shield_health"] = int(target_bd.get("shield_health", 0)) + shield_amount

			"HEAL":
				var heal_amount := int(value)
				var target_for_heal: String = str(act.get("target", "SELF"))
				if target_for_heal == "SELF":
					var max_hp := int(attacker_bd.get("max_health", 30))
					attacker_bd["current_health"] = mini(
						int(attacker_bd.get("current_health", 0)) + heal_amount, max_hp)
					_track(attacker_name, "healing_done", heal_amount)

			"HEAL_PERCENT_DEALT":
				var heal := int(float(damage_dealt) * value)
				var max_hp := int(attacker_bd.get("max_health", 30))
				attacker_bd["current_health"] = mini(
					int(attacker_bd.get("current_health", 0)) + heal, max_hp)
				_track(attacker_name, "healing_done", heal)

			"KNOCKBACK":
				# Push target away
				_spatial.move_away(target_name, attacker_name, value)

			"DAMAGE_REDUCTION":
				# Registered as a persistent effect, already handled by EffectProcessor
				pass

			"COOLDOWN_RESET":
				# Reset a random ability cooldown (Sacrificial weapons)
				var cds: Dictionary = _cooldowns.get(attacker_name, {})
				for aid in cds:
					if cds[aid] > 0:
						cds[aid] = 0
						break


func _get_burst_cap(bd: Dictionary) -> int:
	var abilities_dict: Dictionary = bd.get("entity_current_ability_data", {})
	for aid in abilities_dict:
		var ab: Dictionary = abilities_dict[aid]
		if str(ab.get("ability_type", "")).to_lower().contains("burst"):
			return maxi(int(ab.get("charge_cost", 10)), 1)
	return 10


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


## Check if a battler has a specific effect type registered.
func _has_effect_type(battler_name: String, effect_type: String) -> bool:
	var effects := _effect_processor.query(battler_name, "PASSIVE", {})
	for es in effects:
		if es.effect.effect_type == effect_type:
			return true
	return false

## Check if an ability uses the escalation damage formula instead of standard.
static func _is_escalation_ability(ability_name: String, element: String) -> bool:
	# Brian C.'s Nature Skill uses escalation (d4→d6→d8→d10→d12→d20)
	return ability_name.contains("Brian C.") and ability_name.contains("Skill") and element == "Nature"


static func _tier_to_defense_die(tier: String) -> int:
	match tier.to_lower():
		"common": return 12
		"uncommon", "rare": return 16
		"epic", "boss", "legendary": return 20
	return 12


static func _tier_to_attack_die(tier: String) -> int:
	# Nominal accuracy die size by tier (display/stat only — enemies actually roll
	# combo accuracy dice via DiceRoller.enemy_accuracy_dice during an attack).
	match tier.to_lower():
		"common": return 12
		"uncommon": return 16
		"rare": return 20
		"epic": return 24
		"story_boss": return 20
		"boss", "world_boss", "legendary": return 32
	return 12
