class_name EffectProcessor extends RefCounted
## Central processor for the universal effect system.
## Manages active EffectStates per battler and evaluates triggers.
##
## Usage:
##   var proc = EffectProcessor.new()
##   proc.register_battler("Dylan", weapon_effects + artifact_effects + talent_effects)
##   var mods = proc.get_trigger_results("Dylan", "ON_HIT", context)

# battler_name → Array[EffectState]
var _active_effects: Dictionary = {}

# ─── Registration ────────────────────────────────────────────────────────────

## Register all static effects for a battler (from their gear, talents, constellations).
func register_battler(battler_name: String, effects: Array) -> void:
	if not _active_effects.has(battler_name):
		_active_effects[battler_name] = []
	for eff in effects:
		if eff is GameEffect:
			var state = EffectState.from_effect(eff, "gear", battler_name)
			_active_effects[battler_name].append(state)

## Add a single runtime effect (from a reaction, ability, status, etc.)
func add_effect(battler_name: String, effect: GameEffect, source_type: String = "", source_name: String = "") -> void:
	if not _active_effects.has(battler_name):
		_active_effects[battler_name] = []
	var state = EffectState.from_effect(effect, source_type, source_name)
	_active_effects[battler_name].append(state)

## Remove all effects from a specific source.
func remove_effects_from_source(battler_name: String, source_name: String) -> void:
	if not _active_effects.has(battler_name):
		return
	var kept = []
	for state in _active_effects[battler_name]:
		if state.source_name != source_name:
			kept.append(state)
	_active_effects[battler_name] = kept

## Clear all effects for a battler.
func clear_battler(battler_name: String) -> void:
	_active_effects[battler_name] = []

## Clear everything (battle end).
func clear_all() -> void:
	_active_effects.clear()

# ─── Querying ────────────────────────────────────────────────────────────────

## Get all active EffectStates for a battler.
func get_effects(battler_name: String) -> Array:
	return _active_effects.get(battler_name, [])

## Get all effects that fire on a specific trigger, with optional context filtering.
## context keys: "attack_type", "element", "is_crit", "target_element",
##               "is_shielded", "hp_percent", "burst_charges", "max_burst",
##               "enemy_count_nearby", "dice_roll"
func query(battler_name: String, trigger: String, context: Dictionary = {}) -> Array:
	var results: Array = []
	for state in _active_effects.get(battler_name, []):
		if not state.is_active:
			continue
		if state.effect.trigger != trigger:
			continue
		if not _check_condition(state.effect, context):
			continue
		results.append(state)
	return results

## Convenience: sum all FLAT_DAMAGE modifiers for a trigger.
func sum_flat_damage(battler_name: String, trigger: String, context: Dictionary = {}) -> float:
	var total = 0.0
	for state in query(battler_name, trigger, context):
		if state.effect.effect_type == "FLAT_DAMAGE":
			total += state.current_value()
	return total

## Convenience: get the total crit threshold modifier.
func total_crit_threshold_mod(battler_name: String) -> int:
	var total = 0
	for state in _active_effects.get(battler_name, []):
		if not state.is_active:
			continue
		if state.effect.effect_type == "CRIT_THRESHOLD":
			total += int(state.current_value())
	return total

## Convenience: get damage multiplier (product of all PERCENT_DAMAGE effects).
func damage_multiplier(battler_name: String, trigger: String, context: Dictionary = {}) -> float:
	var mult = 1.0
	for state in query(battler_name, trigger, context):
		if state.effect.effect_type == "PERCENT_DAMAGE":
			mult *= state.current_value()
	return mult

## Convenience: get total stat bonus from effects.
func stat_bonus(battler_name: String, stat_name: String) -> float:
	var total = 0.0
	for state in _active_effects.get(battler_name, []):
		if not state.is_active:
			continue
		if state.effect.effect_type == "STAT_BONUS" and state.effect.effect_stat == stat_name:
			total += state.current_value()
	return total

## Convenience: get stat multiplier from effects.
func stat_multiplier(battler_name: String, stat_name: String) -> float:
	var mult = 1.0
	for state in _active_effects.get(battler_name, []):
		if not state.is_active:
			continue
		if state.effect.effect_type == "STAT_MULTIPLIER" and state.effect.effect_stat == stat_name:
			mult *= (1.0 + state.current_value())
	return mult

# ─── Trigger Processing ─────────────────────────────────────────────────────

## Process a trigger event and return all resulting actions.
## Returns Array of Dictionaries describing what should happen:
## { "effect_type": "FLAT_DAMAGE", "value": 4.0, "target": "TARGET", ... }
func process_trigger(battler_name: String, trigger: String, context: Dictionary = {}) -> Array:
	var actions: Array = []
	for state in query(battler_name, trigger, context):
		var eff = state.effect

		# Handle stacking
		if eff.is_stackable():
			var category: String = ""
			if eff.unique_per == "attack_type":
				category = context.get("attack_type", "")
			var added = state.add_stack(category)
			if not added and not eff.resets_on.is_empty():
				continue  # Stack full but no reset trigger

		# Handle resets
		if eff.resets_on != "" and eff.resets_on == trigger:
			state.reset_stacks()
			continue  # Reset consumes the trigger

		# Build action
		var action = {
			"effect_type": eff.effect_type,
			"value": state.current_value(),
			"target": eff.target,
			"element": eff.effect_element,
			"stat": eff.effect_stat,
			"source": state.source_name,
			"dice": eff.effect_dice,
		}

		# Resolve percent-of-stat values
		if eff.value_is_percent_of != "":
			var base_stat: float = _resolve_stat(battler_name, eff.value_is_percent_of, context)
			action["value"] = eff.effect_value * base_stat

		actions.append(action)
	return actions

# ─── Turn Lifecycle ──────────────────────────────────────────────────────────

## Call at the start of a battler's turn. Processes START_OF_TURN effects.
func on_turn_start(battler_name: String, context: Dictionary = {}) -> Array:
	return process_trigger(battler_name, "START_OF_TURN", context)

## Call at the end of a battler's turn. Ticks durations and cleans up expired effects.
func on_turn_end(battler_name: String) -> void:
	if not _active_effects.has(battler_name):
		return
	var kept = []
	for state in _active_effects[battler_name]:
		if state.tick_turn():
			kept.append(state)
	_active_effects[battler_name] = kept

## Call after each unit's action (for DOT_PER_ACTION effects).
func on_action_tick(battler_name: String) -> Array:
	var dot_actions = []
	if not _active_effects.has(battler_name):
		return dot_actions
	for state in _active_effects[battler_name]:
		if not state.is_active:
			continue
		if state.effect.effect_type in ["DOT", "DOT_PER_ACTION"]:
			if state.effect.duration_actions > 0:
				dot_actions.append({
					"effect_type": "DOT",
					"value": state.current_value(),
					"source": state.source_name,
					"dice": state.effect.effect_dice,
				})
				state.tick_action()
	return dot_actions

# ─── Condition Checking ──────────────────────────────────────────────────────

func _check_condition(effect: GameEffect, context: Dictionary) -> bool:
	match effect.condition:
		"NONE":
			return true
		"ENEMY_HAS_ELEMENT":
			return context.get("target_element", "") == effect.condition_value
		"SELF_HAS_ELEMENT":
			return context.get("self_element", "") == effect.condition_value
		"IS_SHIELDED":
			return context.get("is_shielded", false) == true
		"NOT_SHIELDED":
			return context.get("is_shielded", false) == false
		"HP_BELOW_PERCENT":
			var threshold = float(effect.condition_value) / 100.0
			return context.get("hp_percent", 1.0) < threshold
		"HP_ABOVE_PERCENT":
			var threshold = float(effect.condition_value) / 100.0
			return context.get("hp_percent", 1.0) > threshold
		"BURST_CHARGES_FULL":
			return context.get("burst_charges", 0) >= context.get("max_burst", 999)
		"BURST_CHARGES_ABOVE":
			return context.get("burst_charges", 0) >= int(effect.condition_value)
		"DICE_ROLL_CHECK":
			var roll: int = context.get("dice_roll", 0)
			if effect.condition_value == "even":
				return roll % 2 == 0
			elif effect.condition_value == "odd":
				return roll % 2 == 1
			elif effect.condition_value.ends_with("+"):
				return roll >= int(effect.condition_value.trim_suffix("+"))
			else:
				return roll >= int(effect.condition_value)
		"ATTACK_TYPE":
			return context.get("attack_type", "") == effect.condition_value
		"ELEMENT_MATCH":
			return context.get("attack_element", "") == effect.condition_value
		"ENEMY_COUNT_NEARBY":
			# Format: "2+_3tiles" means 2 or more within 3 tiles
			var parts = effect.condition_value.split("_")
			if parts.size() >= 1:
				var threshold = int(parts[0].replace("+", ""))
				return context.get("enemy_count_nearby", 0) >= threshold
			return false
		"STACKS_AT_MAX":
			# Check in the calling context — we'd need the state here
			# This is handled in process_trigger instead
			return true
		"ALLY_FROM_REGION":
			return context.get("companion_region", "") == effect.condition_value
		"HAS_STATUS":
			var statuses: Array = context.get("active_statuses", [])
			return statuses.has(effect.condition_value)
		"REACTION_ELEMENT":
			return context.get("reaction_element", "") == effect.condition_value
		"NOT_CRIT":
			return context.get("is_crit", false) == false
	return true

# ─── Stat Resolution ────────────────────────────────────────────────────────

func _resolve_stat(battler_name: String, stat_ref: String, context: Dictionary) -> float:
	match stat_ref:
		"max_health":
			return float(context.get("max_health", 0))
		"current_health":
			return float(context.get("current_health", 0))
		"defense":
			return float(context.get("defense", 0))
		"attack":
			return float(context.get("attack", 0))
		"elemental_mastery":
			return float(context.get("elemental_mastery", 0))
		"energy_recharge":
			return float(context.get("energy_recharge", 0))
		"damage_dealt":
			return float(context.get("damage_dealt", 0))
	return 0.0

# ─── Serialization (for network sync) ────────────────────────────────────────

## Serialize all active effects for every battler into a dict for _synced.
## Returns { battler_name: [ { display fields }, ... ] }
func serialize_all() -> Dictionary:
	var result = {}
	for battler_name in _active_effects.keys():
		result[battler_name] = serialize_battler(battler_name)
	return result

## Serialize active effects for one battler into an array of display dicts.
func serialize_battler(battler_name: String) -> Array:
	var arr = []
	for state in _active_effects.get(battler_name, []):
		if not state.is_active:
			continue
		arr.append({
			"source_type": state.source_type,
			"source_name": state.source_name,
			"effect_type": state.effect.effect_type,
			"effect_stat": state.effect.effect_stat,
			"trigger": state.effect.trigger,
			"description": state.effect.description,
			"value": state.current_value(),
			"turns_remaining": state.turns_remaining,
			"stacks": state.current_stacks,
			"max_stacks": state.effect.max_stacks,
			"target": state.effect.target,
			"element": state.effect.effect_element,
		})
	return arr

## Get battler names that have registered effects.
func get_battler_names() -> Array:
	return _active_effects.keys()

# ─── Debug ───────────────────────────────────────────────────────────────────

func debug_print(battler_name: String) -> void:
	print("=== Effects for %s ===" % battler_name)
	for state in _active_effects.get(battler_name, []):
		var status = "ACTIVE" if state.is_active else "EXPIRED"
		var stacks_str = " stacks=%d/%d" % [state.current_stacks, state.effect.max_stacks] if state.effect.is_stackable() else ""
		var dur_str = " dur=%d" % state.turns_remaining if state.turns_remaining != 0 else ""
		print("  [%s] %s: %s %s val=%.1f%s%s (from %s)" % [
			status, state.effect.trigger, state.effect.effect_type,
			state.effect.effect_stat, state.current_value(),
			stacks_str, dur_str, state.source_name
		])
