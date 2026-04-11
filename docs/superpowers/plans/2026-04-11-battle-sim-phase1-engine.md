# Battle Simulator Phase 1: Shared Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a headless battle simulation engine that can run a complete battle with true RNG, smart AI, full effect system integration, and simplified spatial model — without any UI.

**Architecture:** A set of pure-logic classes (`DiceRoller`, `SimSpatial`, `SimAI`, `BattleSimEngine`) that take a battle config, run turn-by-turn combat using the existing `EffectProcessor`/`GameEffect`/`EffectState` system, and return structured results. Threading support for bulk runs (10–10,000 battles). No UI, no networking.

**Tech Stack:** GDScript (Godot 4.4.1). Reuses existing `EffectProcessor`, `GameEffect`, `EffectState`, `EffectBuilder`, `WeaponEffects`, `AbilityEffects`, `StatusEffectsMap`, `GameDB`, `CharacterManager`.

**Spec:** `docs/superpowers/specs/2026-04-11-battle-simulator-design.md` (Phase 1 section)

---

### Task 1: DiceRoller — Static Dice Utility

The foundation for all damage calculations. Pure static functions, no state.

**Files:**
- Create: `Scripts/battle/dice_roller.gd`

- [ ] **Step 1: Create DiceRoller with basic roll function**

Create `Scripts/battle/dice_roller.gd`:

```gdscript
class_name DiceRoller extends RefCounted

## Roll a single die of given size. Returns 1 to die_size inclusive.
static func roll(die_size: int) -> int:
	if die_size <= 0:
		return 0
	return randi_range(1, die_size)

## Map a stat value (or roll difference) to an array of dice sizes.
## Uses the standard stat-to-dice table.
## Returns empty array if value <= 3 (miss).
static func stat_to_dice(value: float) -> Array[int]:
	var v := int(value)
	if v <= 3:
		return []
	var dice: Array[int] = []
	# Handle overflow above 20 by splitting into D20 + remainder
	while v >= 20:
		dice.append(20)
		v -= 20
	# Map remainder to closest die
	if v >= 12:
		dice.append(12)
	elif v >= 10:
		dice.append(10)
	elif v >= 8:
		dice.append(8)
	elif v >= 6:
		dice.append(6)
	elif v >= 4:
		dice.append(4)
	# If v < 4 after subtracting D20s, no additional die (e.g., stat 22 = D20 only)
	return dice

## Roll dice for a stat value. Maps stat to dice, rolls all, returns total.
static func roll_stat(stat_value: float) -> int:
	var dice = stat_to_dice(stat_value)
	var total := 0
	for die in dice:
		total += roll(die)
	return total

## Map attack-defense difference to damage dice (same table as stat_to_dice).
static func difference_to_damage_dice(diff: int) -> Array[int]:
	if diff <= 0:
		return []
	return stat_to_dice(float(diff))

## Roll a damage die from the difference, apply mods, handle multi-hit.
## Returns total damage dealt across all hits.
static func roll_damage(diff: int, hits: int, flat_mod: float, mult_mod: float) -> int:
	var dice = difference_to_damage_dice(diff)
	if dice.is_empty():
		return 0
	var base_roll := 0
	for die in dice:
		base_roll += roll(die)
	var single_hit_damage := int((float(base_roll) + flat_mod) * mult_mod)
	if single_hit_damage < 1:
		single_hit_damage = 1
	return multi_hit_total(single_hit_damage, hits)

## Calculate total damage across multiple hits with 1/3 reduction per successive hit.
## Each successive hit deals floor(previous / 3), minimum 1.
static func multi_hit_total(base_damage: int, hits: int) -> int:
	if hits <= 0:
		return 0
	if hits == 1:
		return base_damage
	var total := base_damage
	var current := base_damage
	for i in range(1, hits):
		current = maxi(current / 3, 1)
		total += current
	return total

## Calculate all possible damage outcomes for a given damage die.
## Returns Array of {roll: int, damage: int} for each possible roll value.
## Used by the post-turn damage breakdown panel.
static func all_possible_damages(diff: int, hits: int, flat_mod: float, mult_mod: float) -> Array:
	var dice = difference_to_damage_dice(diff)
	if dice.is_empty():
		return []
	# For simplicity, treat as a single die (sum of dice for compound).
	# The max roll is the sum of all die maxes.
	var min_roll := dice.size()  # Each die rolls at least 1
	var max_roll := 0
	for die in dice:
		max_roll += die
	var results: Array = []
	for r in range(min_roll, max_roll + 1):
		var single := int((float(r) + flat_mod) * mult_mod)
		if single < 1:
			single = 1
		var total := multi_hit_total(single, hits)
		results.append({"roll": r, "damage": total})
	return results

## Brian C.'s Nature Skill escalation chain.
## hp_available: how much HP the battler can spend on passive (2 HP per threshold reduction).
## Returns {damage: int, hp_spent: int, rolls: Array[int]}
static func roll_escalation(hp_available: int) -> Dictionary:
	var chain := [4, 6, 8, 10, 12, 20]
	var thresholds := [3, 4, 5, 6, 7, 11]  # Must roll above half (rounded up)
	var cumulative := 0
	var hp_spent := 0
	var rolls: Array[int] = []

	for i in range(chain.size()):
		var die_size: int = chain[i]
		var threshold: int = thresholds[i]

		# Passive: spend 2 HP per threshold reduction (minimum threshold of 1)
		var can_reduce := mini(hp_available - hp_spent, (threshold - 1) * 2) / 2
		# For AI: spend HP to reduce threshold if roll is risky (50%+ chance of failure)
		# For now, don't auto-spend — let the AI decide externally
		# The engine just rolls with the base threshold
		var result := roll(die_size)
		rolls.append(result)

		if result < threshold:
			# Failed — total damage is 0
			return {"damage": 0, "hp_spent": hp_spent, "rolls": rolls, "succeeded": false}

		cumulative += result

	return {"damage": cumulative, "hp_spent": hp_spent, "rolls": rolls, "succeeded": true}
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/battle/dice_roller.gd
git commit -m "feat(sim): add DiceRoller static utility — dice rolling, stat mapping, damage calc"
```

---

### Task 2: SimSpatial — Distance-Based Spatial Model

Tracks positions and handles range/movement checks.

**Files:**
- Create: `Scripts/battle/sim_spatial.gd`

- [ ] **Step 1: Create SimSpatial**

Create `Scripts/battle/sim_spatial.gd`:

```gdscript
class_name SimSpatial extends RefCounted
## Simplified distance-based spatial model for battle simulation.
## Tracks positions as floats on a 1D line (0 = player start, arena_size = enemy start).

var _positions: Dictionary = {}  # battler_name -> float
var _sizes: Dictionary = {}      # battler_name -> int (NxN tile size)
var arena_size: int = 20

func setup(player_names: Array, enemy_names: Array, enemy_sizes: Dictionary, p_arena_size: int = 20) -> void:
	arena_size = p_arena_size
	_positions.clear()
	_sizes.clear()
	for name in player_names:
		_positions[name] = 0.0
		_sizes[name] = 1
	for name in enemy_names:
		_positions[name] = float(arena_size)
		_sizes[name] = enemy_sizes.get(name, 1)

func get_position(name: String) -> float:
	return _positions.get(name, 0.0)

## Get effective distance between two combatants (accounts for size).
func distance(a: String, b: String) -> float:
	var raw := absf(_positions.get(a, 0.0) - _positions.get(b, 0.0))
	# Larger enemies are easier to reach
	var size_a: int = _sizes.get(a, 1)
	var size_b: int = _sizes.get(b, 1)
	var reach_bonus := float(maxi(size_a, size_b) / 2)
	return maxf(0.0, raw - reach_bonus)

## Check if a can reach b with a melee attack (distance <= 1).
func in_melee_range(a: String, b: String) -> bool:
	return distance(a, b) <= 1.0

## Check if a can reach b with a ranged ability.
func in_range(a: String, b: String, attack_range: int) -> bool:
	if attack_range <= 0:
		return in_melee_range(a, b)
	return distance(a, b) <= float(attack_range)

## Move battler toward target by up to movement_budget tiles.
## Returns tiles actually moved.
func move_toward(name: String, target: String, movement_budget: float) -> float:
	var my_pos := _positions.get(name, 0.0)
	var target_pos := _positions.get(target, 0.0)
	var dir := signf(target_pos - my_pos)
	var dist := absf(target_pos - my_pos)
	var move := minf(movement_budget, dist)
	_positions[name] = my_pos + dir * move
	return move

## Move battler away from target by up to movement_budget tiles.
func move_away(name: String, target: String, movement_budget: float) -> float:
	var my_pos := _positions.get(name, 0.0)
	var target_pos := _positions.get(target, 0.0)
	var dir := -signf(target_pos - my_pos)
	var move := minf(movement_budget, float(arena_size))
	var new_pos := clampf(my_pos + dir * move, 0.0, float(arena_size))
	var actual := absf(new_pos - my_pos)
	_positions[name] = new_pos
	return actual

## Get all combatants within radius of a position.
func get_in_radius(center_name: String, radius: float, all_names: Array) -> Array:
	var result: Array = []
	for name in all_names:
		if name == center_name:
			continue
		if distance(center_name, name) <= radius:
			result.append(name)
	return result

## Remove a combatant (dead/removed from battle).
func remove(name: String) -> void:
	_positions.erase(name)
	_sizes.erase(name)
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/battle/sim_spatial.gd
git commit -m "feat(sim): add SimSpatial distance-based spatial model"
```

---

### Task 3: SimAI — Smart Ability and Target Selection

Decides what each combatant does on their turn.

**Files:**
- Create: `Scripts/battle/sim_ai.gd`

- [ ] **Step 1: Create SimAI**

Create `Scripts/battle/sim_ai.gd`:

```gdscript
class_name SimAI extends RefCounted
## Smart AI for battle simulation. Selects abilities and targets.
## Same priority framework for players and enemies with different targeting.

## Returns a decision dict: {ability: Dict, targets: Array[String], action: String}
## action: "attack", "revive", "move_only", "skip"
static func decide_turn(
	battler_name: String,
	battler_data: Dictionary,
	all_battlers: Dictionary,
	spatial: SimSpatial,
	effect_processor: EffectProcessor,
	cooldowns: Dictionary,       # ability_id -> turns remaining
	revives_available: Dictionary  # battler_name -> int
) -> Dictionary:

	var b_type: String = battler_data.get("type", "Character")
	var is_player_side := b_type == "Character" or b_type == "Companion"
	var my_abilities: Dictionary = battler_data.get("entity_current_ability_data", {})
	var burst_charges: int = int(battler_data.get("burst_charges", 0))

	# Check if stunned/skipped
	if battler_data.get("skipped_status", false):
		return {"action": "skip", "ability": {}, "targets": []}

	# Priority 1: Revive a downed ally
	if is_player_side:
		var downed := _find_downed_allies(battler_name, all_battlers, is_player_side)
		if downed.size() > 0 and revives_available.get(battler_name, 0) > 0:
			return {"action": "revive", "ability": {}, "targets": [downed[0]]}

	# Gather available abilities (off cooldown, enough burst charges)
	var available: Array = []
	for aid in my_abilities:
		var ab: Dictionary = my_abilities[aid]
		if cooldowns.get(int(aid), 0) > 0:
			continue
		var charge_cost := int(ab.get("charge_cost", 0))
		if charge_cost > 0 and burst_charges < charge_cost:
			continue
		available.append(ab)

	# Sort by priority: Burst > Skill > Charged > Basic
	available.sort_custom(func(a, b): return _ability_priority(a) > _ability_priority(b))

	# Find enemies to target
	var enemies := _find_enemies(battler_name, all_battlers, is_player_side)
	if enemies.is_empty():
		return {"action": "skip", "ability": {}, "targets": []}

	# Pick best ability that can reach a target
	var movement := int(battler_data.get("entity_data", {}).get("Movement", 7))
	# Check for movement effects (root, slow)
	if _is_rooted(battler_name, effect_processor):
		movement = 0
	elif _is_slowed(battler_name, effect_processor):
		movement = movement / 2

	for ab in available:
		var ab_range := int(ab.get("targeting_length", 0))
		var is_melee := ab_range <= 0
		var best_target := _pick_target(battler_name, enemies, all_battlers, spatial, ab_range, movement, is_melee)
		if best_target != "":
			return {"action": "attack", "ability": ab, "targets": [best_target], "movement": movement}

	# Priority 5: Move only (no ability can reach)
	var closest_enemy := _closest(battler_name, enemies, spatial)
	if closest_enemy != "" and movement > 0:
		return {"action": "move_only", "ability": {}, "targets": [closest_enemy], "movement": movement}

	return {"action": "skip", "ability": {}, "targets": []}


static func _ability_priority(ab: Dictionary) -> int:
	var atype := str(ab.get("ability_type", "")).to_lower()
	if atype.contains("burst"):
		return 4
	elif atype.contains("skill"):
		return 3
	elif atype.contains("charged"):
		return 2
	elif atype.contains("basic"):
		return 1
	return 0


static func _find_downed_allies(my_name: String, all_battlers: Dictionary, is_player_side: bool) -> Array:
	var downed: Array = []
	for name in all_battlers:
		if name == my_name:
			continue
		var bd: Dictionary = all_battlers[name]
		var their_type: String = bd.get("type", "")
		var same_side := (is_player_side and (their_type == "Character" or their_type == "Companion")) \
			or (not is_player_side and their_type == "Enemy")
		if same_side and bd.get("killed_status", false) and int(bd.get("current_health", 0)) <= 0:
			downed.append(name)
	return downed


static func _find_enemies(my_name: String, all_battlers: Dictionary, is_player_side: bool) -> Array:
	var enemies: Array = []
	for name in all_battlers:
		if name == my_name:
			continue
		var bd: Dictionary = all_battlers[name]
		var their_type: String = bd.get("type", "")
		var is_enemy_of_me := (is_player_side and their_type == "Enemy") \
			or (not is_player_side and (their_type == "Character" or their_type == "Companion"))
		if is_enemy_of_me and not bd.get("killed_status", false):
			enemies.append(name)
	return enemies


static func _pick_target(
	my_name: String, enemies: Array, all_battlers: Dictionary,
	spatial: SimSpatial, ab_range: int, movement: int, is_melee: bool
) -> String:
	# Sort enemies by HP (lowest first — focus fire)
	var sorted_enemies := enemies.duplicate()
	sorted_enemies.sort_custom(func(a, b):
		return int(all_battlers[a].get("current_health", 999)) < int(all_battlers[b].get("current_health", 999))
	)
	# Find first target in range (or reachable after moving)
	for enemy in sorted_enemies:
		var dist := spatial.distance(my_name, enemy)
		var effective_range := float(ab_range) if not is_melee else 1.0
		if dist <= effective_range:
			return enemy
		# Can we move into range?
		if dist <= effective_range + float(movement):
			return enemy
	return ""


static func _closest(my_name: String, enemies: Array, spatial: SimSpatial) -> String:
	var best := ""
	var best_dist := 99999.0
	for enemy in enemies:
		var d := spatial.distance(my_name, enemy)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


static func _is_rooted(battler_name: String, ep: EffectProcessor) -> bool:
	var effects := ep.query(battler_name, "PASSIVE", {})
	for es in effects:
		if es.effect.effect_type == "PREVENT_MOVEMENT":
			return true
	return false


static func _is_slowed(battler_name: String, ep: EffectProcessor) -> bool:
	var effects := ep.query(battler_name, "PASSIVE", {})
	for es in effects:
		if es.effect.effect_type == "MOVEMENT_COST" and es.effect.effect_value > 1.0:
			return true
	return false
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/battle/sim_ai.gd
git commit -m "feat(sim): add SimAI — smart ability selection and targeting"
```

---

### Task 4: BattleSimEngine — Core Single-Battle Runner

The main engine that runs a complete battle start to finish.

**Files:**
- Create: `Scripts/battle/battle_sim_engine.gd`

- [ ] **Step 1: Create BattleSimEngine**

Create `Scripts/battle/battle_sim_engine.gd`:

```gdscript
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
		var char_data: Dictionary = pc.get("character_data", {}).duplicate(true)
		var stats := CharacterManager.get_stats(name)

		# Apply kit override
		var kit = pc.get("kit_override")
		if kit != null:
			char_data["Element"] = kit.get("element", char_data.get("Element", ""))

		# Build battler dict (simplified from BattlerState._build_one)
		var bd := {
			"id": int(char_data.get("id", 0)),
			"name": name,
			"type": "Character",
			"entity_data": char_data,
			"entity_weapon_data": pc.get("weapon_override", {}),
			"entity_current_ability_data": _get_abilities_for_config(pc, char_data),
			"current_health": int(char_data.get("Current_Health", char_data.get("Max_Health", 30))),
			"max_health": int(stats.health) if stats else int(char_data.get("Max_Health", 30)),
			"burst_charges": int(char_data.get("Burst_Charges", 0)),
			"applied_element": "None",
			"killed_status": false,
			"skipped_status": false,
			"skipped_duration": 0,
			"attack_stat": stats.attack if stats else 10.0,
			"defense_stat": stats.defense if stats else 10.0,
			"em_stat": stats.elemental_mastery if stats else 7.0,
			"er_stat": stats.energy_recharge if stats else 1.0,
			"crit_damage_stat": stats.critical_damage if stats else 0.0,
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
		var weapon: Dictionary = pc.get("weapon_override", {})
		var weapon_name: String = str(weapon.get("Name", weapon.get("Weapon", "")))
		if weapon_name != "":
			var effects := WeaponEffects.get_effects(weapon_name)
			if effects.size() > 0:
				_effect_processor.register_battler(name, effects)

		# Register artifact set bonuses
		var artifacts: Array = pc.get("artifact_overrides", [])
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
	var ability_element: String = str(ability.get("element", "Physical"))
	var accuracy_stat: float = attacker_bd.get("attack_stat", 10.0)
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
	var ab_type: String = str(ability.get("ability_type", "")).to_lower()
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
	if kit:
		element = str(kit.get("element", element))
	var weapon_type: String = ""
	var weapon: Dictionary = pc.get("weapon_override", {})
	if weapon.has("Type"):
		weapon_type = str(weapon.get("Type", ""))
	elif kit:
		weapon_type = str(kit.get("weapon_type", ""))

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


static func _tier_to_defense_die(tier: String) -> int:
	match tier.to_lower():
		"common": return 12
		"uncommon", "rare": return 16
		"epic", "boss", "legendary": return 20
	return 12


static func _tier_to_attack_die(tier: String) -> int:
	# Default attack dice when ability doesn't specify
	return _tier_to_defense_die(tier)
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/battle/battle_sim_engine.gd
git commit -m "feat(sim): add BattleSimEngine — headless single-battle runner"
```

---

### Task 5: BattleSimBulkRunner — Threaded Bulk Simulation

Runs N battles on a background thread and aggregates results.

**Files:**
- Create: `Scripts/battle/battle_sim_bulk.gd`

- [ ] **Step 1: Create BattleSimBulkRunner**

Create `Scripts/battle/battle_sim_bulk.gd`:

```gdscript
class_name BattleSimBulkRunner extends Node
## Runs N battles on a background thread, aggregates results, emits signals.

signal simulation_progress(completed: int, total: int)
signal simulation_complete(results: Dictionary)

var _thread: Thread = null
var _cancel_requested: bool = false
var _config: Dictionary = {}
var _battle_count: int = 0
var _results: Dictionary = {}

func run(config: Dictionary, count: int) -> void:
	if _thread != null and _thread.is_started():
		push_warning("BattleSimBulkRunner: Simulation already running")
		return
	_cancel_requested = false
	_config = config
	_battle_count = count

	if count <= 10:
		# Small count: run on main thread
		_results = _run_battles()
		simulation_complete.emit(_results)
	else:
		_thread = Thread.new()
		_thread.start(_thread_func)

func cancel() -> void:
	_cancel_requested = true

func is_running() -> bool:
	return _thread != null and _thread.is_started()

func _thread_func() -> void:
	_results = _run_battles()
	call_deferred("_on_thread_done")

func _on_thread_done() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	simulation_complete.emit(_results)

func _run_battles() -> Dictionary:
	var agg := {
		"battles_run": 0,
		"wins": 0,
		"losses": 0,
		"total_wipes": 0,
		"rounds_list": [],
		"per_battler": {},
		"battles_with_zero_deaths": 0,
		"battles_with_perma_death": 0,
		"battles_all_revives_burned": 0,
	}

	for i in range(_battle_count):
		if _cancel_requested:
			break

		var engine := BattleSimEngine.new()
		var result := engine.run_battle(_config)
		agg["battles_run"] += 1

		# Aggregate outcome
		if result.get("outcome") == "win":
			agg["wins"] += 1
		else:
			agg["losses"] += 1
			# Check total wipe (all players/companions dead)
			agg["total_wipes"] += 1

		agg["rounds_list"].append(result.get("total_rounds", 0))

		# Aggregate per-battler stats
		var per_b: Dictionary = result.get("per_battler", {})
		for name in per_b:
			if not agg["per_battler"].has(name):
				agg["per_battler"][name] = {
					"damage_dealt": 0, "damage_taken": 0, "damage_absorbed": 0,
					"healing_done": 0, "total_downs": 0, "total_deaths": 0,
					"total_revives_given": 0, "total_revives_received": 0,
					"total_crits": 0, "total_misses": 0,
					"abilities": {},
				}
			var a: Dictionary = agg["per_battler"][name]
			var b: Dictionary = per_b[name]
			a["damage_dealt"] += int(b.get("damage_dealt", 0))
			a["damage_taken"] += int(b.get("damage_taken", 0))
			a["damage_absorbed"] += int(b.get("damage_absorbed", 0))
			a["healing_done"] += int(b.get("healing_done", 0))
			a["total_downs"] += int(b.get("times_downed", 0))
			a["total_deaths"] += int(b.get("deaths", 0))
			a["total_revives_given"] += int(b.get("times_reviving_others", 0))
			a["total_revives_received"] += int(b.get("times_revived", 0))
			a["total_crits"] += int(b.get("crits", 0))
			a["total_misses"] += int(b.get("misses", 0))
			# Aggregate abilities
			for ab_name in b.get("abilities_used", {}):
				var ab_data: Dictionary = b["abilities_used"][ab_name]
				if not a["abilities"].has(ab_name):
					a["abilities"][ab_name] = {"total_uses": 0, "total_damage": 0}
				a["abilities"][ab_name]["total_uses"] += int(ab_data.get("uses", 0))
				a["abilities"][ab_name]["total_damage"] += int(ab_data.get("total_damage", 0))

		# Track battle-level stats
		var any_deaths := false
		var total_revives_this_battle := 0
		for name in per_b:
			if int(per_b[name].get("deaths", 0)) > 0:
				any_deaths = true
			total_revives_this_battle += int(per_b[name].get("times_reviving_others", 0))
		if not any_deaths and result.get("outcome") == "win":
			agg["battles_with_zero_deaths"] += 1
		if any_deaths:
			agg["battles_with_perma_death"] += 1

		# Emit progress periodically (every 10% or every 100 battles)
		if i % maxi(1, _battle_count / 20) == 0:
			call_deferred("_emit_progress", i + 1, _battle_count)

	# Finalize aggregated results
	return _finalize(agg)


func _emit_progress(completed: int, total: int) -> void:
	simulation_progress.emit(completed, total)


func _finalize(agg: Dictionary) -> Dictionary:
	var n: float = maxf(float(agg.get("battles_run", 1)), 1.0)
	var rounds_list: Array = agg.get("rounds_list", [])

	# Calculate round stats
	var min_rounds := 999
	var max_rounds := 0
	var total_rounds := 0
	for r in rounds_list:
		min_rounds = mini(min_rounds, int(r))
		max_rounds = maxi(max_rounds, int(r))
		total_rounds += int(r)

	# Build final output
	var result := {
		"battles_run": int(n),
		"wins": agg.get("wins", 0),
		"losses": agg.get("losses", 0),
		"win_rate": float(agg.get("wins", 0)) / n * 100.0,
		"total_wipes": agg.get("total_wipes", 0),
		"wipe_rate": float(agg.get("total_wipes", 0)) / n * 100.0,
		"avg_rounds": float(total_rounds) / n,
		"min_rounds": min_rounds if min_rounds < 999 else 0,
		"max_rounds": max_rounds,
		"battles_with_zero_deaths": agg.get("battles_with_zero_deaths", 0),
		"battles_with_perma_death": agg.get("battles_with_perma_death", 0),
		"battles_all_revives_burned": agg.get("battles_all_revives_burned", 0),
		"per_battler": {},
		"damage_distribution": {},
	}

	# Finalize per-battler averages
	var total_damage_all := 0
	for name in agg.get("per_battler", {}):
		var a: Dictionary = agg["per_battler"][name]
		total_damage_all += int(a.get("damage_dealt", 0))
		var pb := {
			"avg_damage_dealt": float(a.get("damage_dealt", 0)) / n,
			"avg_damage_taken": float(a.get("damage_taken", 0)) / n,
			"avg_damage_absorbed": float(a.get("damage_absorbed", 0)) / n,
			"avg_healing_done": float(a.get("healing_done", 0)) / n,
			"total_downs": a.get("total_downs", 0),
			"total_deaths": a.get("total_deaths", 0),
			"total_revives_given": a.get("total_revives_given", 0),
			"total_revives_received": a.get("total_revives_received", 0),
			"total_crits": a.get("total_crits", 0),
			"total_misses": a.get("total_misses", 0),
			"abilities": {},
		}
		for ab_name in a.get("abilities", {}):
			var ab: Dictionary = a["abilities"][ab_name]
			var uses := int(ab.get("total_uses", 0))
			pb["abilities"][ab_name] = {
				"avg_uses": float(uses) / n,
				"avg_damage": float(ab.get("total_damage", 0)) / maxf(float(uses), 1.0),
				"total_damage": ab.get("total_damage", 0),
			}
		result["per_battler"][name] = pb

	# Damage distribution percentages
	if total_damage_all > 0:
		for name in agg.get("per_battler", {}):
			var dmg: int = int(agg["per_battler"][name].get("damage_dealt", 0))
			result["damage_distribution"][name] = float(dmg) / float(total_damage_all) * 100.0

	return result
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/battle/battle_sim_bulk.gd
git commit -m "feat(sim): add BattleSimBulkRunner — threaded bulk simulation with aggregation"
```

---

### Task 6: Tier Profiles

Fixed difficulty tier definitions for the encounter balancer.

**Files:**
- Create: `Scripts/battle/tier_profiles.gd`

- [ ] **Step 1: Create TierProfiles**

Create `Scripts/battle/tier_profiles.gd`:

```gdscript
class_name TierProfiles extends RefCounted
## Fixed difficulty tier profiles for encounter balancing.
## Each profile defines target win rates, resource usage, etc.

static func get_profile(tier: String) -> Dictionary:
	match tier.to_lower():
		"common":
			return {
				"tier": "Common",
				"win_rate": 99.0,
				"wipe_rate": 0.5,
				"rounds_per_enemy": [1, 2],
				"revives_needed_rate": 2.0,
				"perma_death_rate": 0.5,
				"items_needed_rate": 1.0,
				"defense_die": 12,
				"attack_die": 12,
				"description": "Trivial. Players win easily, no resources needed.",
			}
		"uncommon":
			return {
				"tier": "Uncommon",
				"win_rate": 95.0,
				"wipe_rate": 2.0,
				"rounds_per_enemy": [3, 5],
				"revives_needed_rate": 5.0,
				"perma_death_rate": 2.0,
				"items_needed_rate": 10.0,
				"defense_die": 16,
				"attack_die": 16,
				"description": "Easy. Occasional item use, revives almost never.",
			}
		"rare":
			return {
				"tier": "Rare",
				"win_rate": 85.0,
				"wipe_rate": 8.0,
				"rounds_per_enemy": [5, 8],
				"revives_needed_rate": 30.0,
				"perma_death_rate": 8.0,
				"items_needed_rate": 40.0,
				"defense_die": 16,
				"attack_die": 16,
				"description": "Moderate. Items likely, someone downed in ~30% of fights.",
			}
		"epic":
			return {
				"tier": "Epic",
				"win_rate": 80.0,
				"wipe_rate": 15.0,
				"rounds_per_enemy": [8, 12],
				"revives_needed_rate": 80.0,
				"perma_death_rate": 10.0,
				"items_needed_rate": 70.0,
				"defense_die": 20,
				"attack_die": 20,
				"description": "Hard. All revives burned in most fights, permanent deaths rare.",
			}
		"boss":
			return {
				"tier": "Boss",
				"win_rate": 75.0,
				"wipe_rate": 25.0,
				"rounds_per_enemy": [12, 20],
				"revives_needed_rate": 50.0,  # of wins
				"perma_death_rate": 25.0,     # of wins
				"items_needed_rate": 80.0,
				"defense_die": 20,
				"attack_die": 0,  # Ability-specified
				"description": "Boss. Full wipe ~25%, all revives burned in half of wins.",
			}
		"legendary":
			return {
				"tier": "Legendary",
				"win_rate": 50.0,
				"wipe_rate": 40.0,
				"rounds_per_enemy": [15, 30],
				"revives_needed_rate": 95.0,
				"perma_death_rate": 80.0,  # of wins
				"items_needed_rate": 95.0,
				"defense_die": 20,
				"attack_die": 0,  # Ability-specified
				"description": "Brutal. ~50% win rate, clean wins rare (~10%).",
			}
	# Default to common
	return get_profile("common")


static func get_all_tiers() -> Array:
	return ["Common", "Uncommon", "Rare", "Epic", "Boss", "Legendary"]


## Scale profile expectations based on enemy count.
## More enemies = longer fights, more resource usage, slightly lower win rate.
static func scale_profile(profile: Dictionary, enemy_count: int) -> Dictionary:
	if enemy_count <= 1:
		return profile.duplicate()
	var scaled := profile.duplicate(true)
	var factor := float(enemy_count)
	# Rounds scale proportionally
	scaled["rounds_per_enemy"][0] = int(float(scaled["rounds_per_enemy"][0]) * factor * 0.7)
	scaled["rounds_per_enemy"][1] = int(float(scaled["rounds_per_enemy"][1]) * factor * 0.8)
	# Win rate decreases slightly with more enemies
	scaled["win_rate"] = maxf(scaled["win_rate"] - (factor - 1.0) * 3.0, 30.0)
	# Resource usage increases
	scaled["revives_needed_rate"] = minf(scaled["revives_needed_rate"] + factor * 5.0, 99.0)
	scaled["items_needed_rate"] = minf(scaled["items_needed_rate"] + factor * 8.0, 99.0)
	return scaled
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/battle/tier_profiles.gd
git commit -m "feat(sim): add TierProfiles — fixed difficulty tier definitions for encounter balancing"
```

---

### Task 7: Tests — Add Battle Engine Tests to test_scene.gd

**Files:**
- Modify: `Scenes/test_scene.gd`

- [ ] **Step 1: Add test group for battle engine**

In `_run_all_tests()`, add after the offline mode tests and before scene instantiation:

```gdscript
	_log_header("TEST GROUP 10: Battle Simulation Engine")
	_test_dice_roller_stat_mapping()
	_test_dice_roller_damage_calc()
	_test_dice_roller_multi_hit()
	_test_dice_roller_all_possible_damages()
	_test_sim_spatial_distance()
	_test_sim_spatial_movement()
	_test_sim_ai_target_selection()
	await _test_battle_sim_single_battle()
	await _test_battle_sim_bulk_runner()
	_test_tier_profiles()
```

Update the scene instantiation header to `TEST GROUP 11`.

- [ ] **Step 2: Add DiceRoller tests**

Add these test functions:

```gdscript
# ═══════════════════════════════════════════════════════════════════════
#  TEST GROUP 10: Battle Simulation Engine
# ═══════════════════════════════════════════════════════════════════════

func _test_dice_roller_stat_mapping():
	# Test stat-to-dice mapping follows the table
	_assert("Stat 3 -> miss (empty)", DiceRoller.stat_to_dice(3.0).is_empty(), "")
	_assert("Stat 4 -> [D4]", DiceRoller.stat_to_dice(4.0) == [4], str(DiceRoller.stat_to_dice(4.0)))
	_assert("Stat 6 -> [D6]", DiceRoller.stat_to_dice(6.0) == [6], str(DiceRoller.stat_to_dice(6.0)))
	_assert("Stat 8 -> [D8]", DiceRoller.stat_to_dice(8.0) == [8], str(DiceRoller.stat_to_dice(8.0)))
	_assert("Stat 10 -> [D10]", DiceRoller.stat_to_dice(10.0) == [10], str(DiceRoller.stat_to_dice(10.0)))
	_assert("Stat 12 -> [D12]", DiceRoller.stat_to_dice(12.0) == [12], str(DiceRoller.stat_to_dice(12.0)))
	_assert("Stat 19 -> [D12]", DiceRoller.stat_to_dice(19.0) == [12], str(DiceRoller.stat_to_dice(19.0)))
	_assert("Stat 20 -> [D20]", DiceRoller.stat_to_dice(20.0) == [20], str(DiceRoller.stat_to_dice(20.0)))
	_assert("Stat 24 -> [D20, D4]", DiceRoller.stat_to_dice(24.0) == [20, 4], str(DiceRoller.stat_to_dice(24.0)))
	_assert("Stat 26 -> [D20, D6]", DiceRoller.stat_to_dice(26.0) == [20, 6], str(DiceRoller.stat_to_dice(26.0)))
	# Test roll returns valid range
	for _i in range(20):
		var r = DiceRoller.roll(20)
		_assert("D20 roll in range", r >= 1 and r <= 20, "got %d" % r)
		if r < 1 or r > 20:
			break

func _test_dice_roller_damage_calc():
	# Test damage with known values
	var dmg := DiceRoller.roll_damage(0, 1, 0.0, 1.0)
	_assert("Diff 0 = 0 damage", dmg == 0, "got %d" % dmg)
	# With mods
	var dmg2 := DiceRoller.roll_damage(4, 1, 2.0, 1.5)
	_assert("Diff 4 with mods produces damage > 0", dmg2 > 0, "got %d" % dmg2)

func _test_dice_roller_multi_hit():
	# Test multi-hit reduction: 15 damage, 4 hits = 15 + 5 + 2 + 1 = 23
	var total := DiceRoller.multi_hit_total(15, 4)
	_assert("Multi-hit 15 x4 = 23", total == 23, "got %d" % total)
	# Single hit = base
	_assert("Multi-hit 15 x1 = 15", DiceRoller.multi_hit_total(15, 1) == 15, "")
	# Zero hits = 0
	_assert("Multi-hit 15 x0 = 0", DiceRoller.multi_hit_total(15, 0) == 0, "")
	# Small values: 3 x3 = 3 + 1 + 1 = 5
	_assert("Multi-hit 3 x3 = 5", DiceRoller.multi_hit_total(3, 3) == 5, "got %d" % DiceRoller.multi_hit_total(3, 3))

func _test_dice_roller_all_possible_damages():
	var results := DiceRoller.all_possible_damages(4, 1, 0.0, 1.0)
	_assert("Diff 4 has 4 possible outcomes", results.size() == 4, "got %d" % results.size())
	if results.size() == 4:
		_assert("Roll 1 = 1 damage", results[0]["damage"] == 1, "got %d" % results[0]["damage"])
		_assert("Roll 4 = 4 damage", results[3]["damage"] == 4, "got %d" % results[3]["damage"])
```

- [ ] **Step 3: Add spatial and AI tests**

```gdscript
func _test_sim_spatial_distance():
	var sp := SimSpatial.new()
	sp.setup(["Player1"], ["Enemy1"], {"Enemy1": 1}, 20)
	var dist := sp.distance("Player1", "Enemy1")
	_assert("Initial distance is 20", dist == 20.0, "got %.1f" % dist)
	_assert("Not in melee range", not sp.in_melee_range("Player1", "Enemy1"), "")
	# Test size bonus
	sp.setup(["Player1"], ["BigEnemy"], {"BigEnemy": 3}, 20)
	var dist2 := sp.distance("Player1", "BigEnemy")
	_assert("Size 3 enemy reduces effective distance", dist2 < 20.0, "got %.1f" % dist2)

func _test_sim_spatial_movement():
	var sp := SimSpatial.new()
	sp.setup(["Player1"], ["Enemy1"], {"Enemy1": 1}, 20)
	sp.move_toward("Player1", "Enemy1", 7.0)
	var new_dist := sp.distance("Player1", "Enemy1")
	_assert("After moving 7, distance is 13", new_dist == 13.0, "got %.1f" % new_dist)

func _test_sim_ai_target_selection():
	# AI should target lowest HP enemy
	var spatial := SimSpatial.new()
	spatial.setup(["Player"], ["E1", "E2"], {"E1": 1, "E2": 1}, 5)
	# Move player close
	spatial.move_toward("Player", "E1", 5.0)
	var battlers := {
		"Player": {"type": "Character", "killed_status": false, "current_health": 30},
		"E1": {"type": "Enemy", "killed_status": false, "current_health": 20},
		"E2": {"type": "Enemy", "killed_status": false, "current_health": 5},
	}
	var enemies := SimAI._find_enemies("Player", battlers, true)
	_assert("AI finds 2 enemies", enemies.size() == 2, "got %d" % enemies.size())
	# Lowest HP target
	var target := SimAI._pick_target("Player", enemies, battlers, spatial, 0, 7, true)
	_assert("AI targets lowest HP enemy (E2)", target == "E2", "got %s" % target)
```

- [ ] **Step 4: Add engine integration tests**

```gdscript
func _test_battle_sim_single_battle():
	# Run a single battle with current party vs a common enemy
	var config := _build_test_battle_config()
	if config.is_empty():
		_log_warn("Cannot build test battle config — skipping engine test")
		return

	var engine := BattleSimEngine.new()
	var result := engine.run_battle(config)
	_assert("Battle produces outcome", result.get("outcome", "") != "", result.get("outcome", "none"))
	_assert("Battle has rounds > 0", int(result.get("total_rounds", 0)) > 0, "%d rounds" % result.get("total_rounds", 0))
	_assert("Battle has per_battler data", result.get("per_battler", {}).size() > 0, "%d battlers" % result.get("per_battler", {}).size())
	await get_tree().process_frame

func _test_battle_sim_bulk_runner():
	var config := _build_test_battle_config()
	if config.is_empty():
		_log_warn("Cannot build test battle config — skipping bulk runner test")
		return

	var runner := BattleSimBulkRunner.new()
	add_child(runner)
	var results_received := [false]
	var bulk_results := [{}]
	runner.simulation_complete.connect(func(r):
		results_received[0] = true
		bulk_results[0] = r
	)
	runner.run(config, 10)
	# Wait for completion
	for _j in range(100):
		if results_received[0]:
			break
		await get_tree().create_timer(0.1).timeout
	_assert("Bulk runner completes", results_received[0], "")
	if results_received[0]:
		_assert("Bulk ran 10 battles", int(bulk_results[0].get("battles_run", 0)) == 10, "got %d" % bulk_results[0].get("battles_run", 0))
		_assert("Has win rate", bulk_results[0].get("win_rate", -1.0) >= 0.0, "%.1f%%" % bulk_results[0].get("win_rate", 0))
		_assert("Has per_battler data", bulk_results[0].get("per_battler", {}).size() > 0, "")
		_log_info("Win rate: %.1f%%, Avg rounds: %.1f" % [bulk_results[0].get("win_rate", 0), bulk_results[0].get("avg_rounds", 0)])
	runner.queue_free()
	await get_tree().process_frame

func _test_tier_profiles():
	for tier in TierProfiles.get_all_tiers():
		var profile := TierProfiles.get_profile(tier)
		_assert("Tier '%s' has win_rate" % tier, profile.has("win_rate"), "")
		_assert("Tier '%s' has defense_die" % tier, profile.has("defense_die"), "")
	# Test scaling
	var common := TierProfiles.get_profile("common")
	var scaled := TierProfiles.scale_profile(common, 4)
	_assert("Scaled common has lower win rate", scaled["win_rate"] < common["win_rate"], "%.1f vs %.1f" % [scaled["win_rate"], common["win_rate"]])

func _build_test_battle_config() -> Dictionary:
	# Build a minimal test config from current game data
	var party: Array = []
	for name in Global.PartyCharacters:
		var rid := Global.CHARACTERS_NAME.get(name, "")
		if rid == "":
			continue
		var char_data: Dictionary = Global.CHARACTERS.get(rid, {})
		if char_data.is_empty():
			continue
		# Find equipped weapon
		var weapon := {}
		for w in Global.CHARACTER_WEAPONS.values():
			if w.get("Owner") == name and w.get("Equipped") == true:
				weapon = w
				break
		# Find equipped artifacts
		var artifacts: Array = []
		for a in Global.CHARACTER_ARTIFACTS.values():
			if a.get("Owner") == name and a.get("Equipped") == true:
				artifacts.append(a)
		# Find companion
		var companion := {}
		for c in Global.COMPANIONS.values():
			if c.get("Owner") == name:
				companion = c
				break
		party.append({
			"name": name,
			"character_data": char_data,
			"weapon_override": weapon,
			"artifact_overrides": artifacts,
			"companion_override": companion,
			"kit_override": null,
			"food_buff": "None",
		})

	if party.is_empty():
		return {}

	# Pick first available enemy from GameDB
	var enemy_id := 0
	for eid in GameDB.enemies:
		enemy_id = int(eid)
		break
	if enemy_id == 0:
		return {}

	return {
		"party": party,
		"enemies": [{"enemy_id": enemy_id, "count": 1}],
		"damage_modifier_players": 1.0,
		"damage_modifier_enemies": 1.0,
		"arena_size": 20,
	}
```

- [ ] **Step 5: Commit**

```bash
git add Scenes/test_scene.gd
git commit -m "test(sim): add battle engine tests — dice roller, spatial, AI, single + bulk battles, tier profiles"
```
