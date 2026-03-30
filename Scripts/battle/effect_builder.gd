class_name EffectBuilder extends RefCounted
## Factory for creating GameEffect resources from common patterns.
## Used both for programmatic construction and for parsing weapon/artifact descriptions.

# ─── Simple builders ─────────────────────────────────────────────────────────

static func passive_flat_damage(value: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = value
	e.description = desc
	return e

static func passive_percent_damage(value: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "PERCENT_DAMAGE"
	e.effect_value = value
	e.description = desc
	return e

static func crit_threshold(value: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "CRIT_THRESHOLD"
	e.effect_value = value
	e.duration = -1
	e.description = desc
	return e

static func on_crit_flat_damage(value: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_CRIT"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = value
	e.description = desc
	return e

static func on_crit_burst_full(desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_CRIT"
	e.effect_type = "BURST_CHARGE_FULL"
	e.description = desc
	return e

static func on_kill_extra_turn(desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_KILL"
	e.effect_type = "EXTRA_TURN"
	e.description = desc
	return e

static func on_enemy_hit_extra_turn(desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_DAMAGE_TAKEN"
	e.effect_type = "EXTRA_TURN"
	e.target = "ATTACKER"
	e.description = desc
	return e

static func sacrificial_cooldown_reset(desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.condition = "DICE_ROLL_CHECK"
	e.condition_value = "even"
	e.effect_type = "COOLDOWN_RESET"
	e.effect_dice = "1d20"
	e.description = desc
	return e

static func royal_crit_ramp(desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_NON_CRIT"
	e.effect_type = "CRIT_THRESHOLD"
	e.stack_value = -2.0
	e.max_stacks = 10
	e.resets_on = "ON_CRIT"
	e.duration = -1
	e.description = desc
	return e

static func conditional_element_damage(element: String, value: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "ENEMY_HAS_ELEMENT"
	e.condition_value = element
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = value
	e.description = desc
	return e

static func on_hit_stack(effect_type: String, stack_val: float, max_s: int, duration: int = -1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.effect_type = effect_type
	e.stack_value = stack_val
	e.max_stacks = max_s
	e.duration = duration
	e.description = desc
	return e

static func shield_bonus(value: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "SHIELD_BONUS"
	e.effect_value = value
	e.description = desc
	return e

static func stat_bonus(stat: String, value: float, trigger: String = "PASSIVE", duration: int = -1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = trigger
	e.effect_type = "STAT_BONUS"
	e.effect_stat = stat
	e.effect_value = value
	e.duration = duration
	e.description = desc
	return e

static func stat_multiplier(stat: String, value: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "STAT_MULTIPLIER"
	e.effect_stat = stat
	e.effect_value = value
	e.description = desc
	return e

static func percent_of_stat_damage(stat_ref: String, percent: float, trigger: String = "ON_HIT", desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = trigger
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = percent
	e.value_is_percent_of = stat_ref
	e.description = desc
	return e

static func heal_percent_dealt(percent: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.effect_type = "HEAL_PERCENT_DEALT"
	e.effect_value = percent
	e.target = "SELF"
	e.description = desc
	return e

static func on_skill_next_attack_bonus(effect_type: String, value: float, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.effect_type = effect_type
	e.effect_value = value
	e.duration = 1  # Next attack only
	e.description = desc
	return e

static func shield_generate(health_dice: String, duration: int = 1, target: String = "SELF", desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.effect_type = "SHIELD_GENERATE"
	e.effect_dice = health_dice
	e.duration = duration
	e.target = target
	e.description = desc
	return e

static func damage_taken_shield(health: float, duration: int = 1, once_per_battle: bool = false, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ONCE_PER_BATTLE" if once_per_battle else "ON_DAMAGE_TAKEN"
	e.effect_type = "SHIELD_GENERATE"
	e.effect_value = health
	e.duration = duration
	e.description = desc
	return e

static func attack_type_stack(max_s: int, effect_type: String = "PERCENT_DAMAGE", at_max_value: float = 0.5, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "STACKS_AT_MAX"
	e.effect_type = effect_type
	e.effect_value = at_max_value
	e.max_stacks = max_s
	e.unique_per = "attack_type"
	e.duration = -1
	e.description = desc
	return e

static func dot_per_action(damage: float, actions: int, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "DOT_PER_ACTION"
	e.effect_value = damage
	e.duration_actions = actions
	e.description = desc
	return e

static func skip_turn(duration: int = 1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "START_OF_TURN"
	e.effect_type = "SKIP_TURN"
	e.duration = duration
	e.description = desc
	return e

static func prevent_movement(duration: int = 1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "PREVENT_MOVEMENT"
	e.duration = duration
	e.description = desc
	return e

static func roll_advantage(duration: int = 1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "ROLL_ADVANTAGE"
	e.duration = duration
	e.description = desc
	return e

static func roll_disadvantage(duration: int = 1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "ROLL_DISADVANTAGE"
	e.duration = duration
	e.description = desc
	return e

static func random_target(duration: int = 1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "RANDOM_TARGET"
	e.duration = duration
	e.description = desc
	return e

static func taunt(duration: int = 1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "TAUNT"
	e.duration = duration
	e.description = desc
	return e

static func reflect(duration: int = 1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_DAMAGE_TAKEN"
	e.effect_type = "REFLECT"
	e.duration = duration
	e.description = desc
	return e

static func ally_flat_damage(value: float, duration: int = 0, trigger: String = "ON_SKILL_USE", dice: String = "", desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = trigger
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = value
	e.effect_dice = dice
	e.target = "ALL_ALLIES"
	e.duration = duration
	e.description = desc
	return e

static func apply_element(element: String, target: String = "TARGET", duration: int = 0, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "APPLY_ELEMENT"
	e.effect_element = element
	e.target = target
	e.duration = duration
	e.description = desc
	return e

static func reapply_element(element: String, target: String = "SELF", duration: int = -1, desc: String = "") -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.effect_type = "REAPPLY_ELEMENT"
	e.effect_element = element
	e.target = target
	e.duration = duration
	e.description = desc
	return e
