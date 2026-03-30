class_name GameEffect extends Resource
## Universal effect definition used by weapons, artifacts, abilities, reactions,
## status effects, constellations, and talents.
##
## Pattern: WHEN (trigger) → IF (condition) → DO (effect) → TO (target) → FOR (duration/stacks)

# ─── Trigger: WHEN does this fire? ───────────────────────────────────────────
# PASSIVE              Always active, no trigger needed
# ON_HIT               When you deal damage with any attack
# ON_NORMAL_HIT        When normal attack deals damage
# ON_CHARGED_HIT       When charged attack deals damage
# ON_SKILL_HIT         When skill deals damage
# ON_BURST_HIT         When burst deals damage
# ON_CRIT              When you score a critical hit
# ON_NON_CRIT          When you deal damage but don't crit
# ON_KILL              When you kill an enemy
# ON_SKILL_USE         When you activate your skill (before damage)
# ON_BURST_USE         When you activate your burst (before damage)
# ON_DAMAGE_TAKEN      When you take damage
# ON_REACTION          When you trigger an elemental reaction
# ON_HEAL              When you heal someone
# START_OF_TURN        At the beginning of your turn
# END_OF_TURN          At the end of your turn
# ON_SHIELD_BREAK      When your shield is broken by damage (not timeout)
# ON_ELEMENT_APPLIED   When an element is applied to you
# ONCE_PER_BATTLE      Fires once when condition is first met
@export var trigger: String = "PASSIVE"

# ─── Condition: IF what is true? ─────────────────────────────────────────────
# NONE                    No condition
# ENEMY_HAS_ELEMENT      Target has element (condition_value = element name)
# SELF_HAS_ELEMENT        You have element applied (condition_value = element name)
# IS_SHIELDED             You have an active shield
# NOT_SHIELDED            You don't have a shield
# HP_BELOW_PERCENT        HP below threshold (condition_value = "50" for 50%)
# HP_ABOVE_PERCENT        HP above threshold
# BURST_CHARGES_FULL      At max burst charges
# BURST_CHARGES_ABOVE     Charges above threshold (condition_value = number)
# DICE_ROLL_CHECK         D20 roll check (condition_value = "even", "11+", "15+")
# ATTACK_TYPE             Specific attack type (condition_value = "Normal", "Charged", "Skill", "Burst")
# ELEMENT_MATCH           Attack uses element (condition_value = element name)
# ENEMY_COUNT_NEARBY      Enemies within range (condition_value = "2+_3tiles")
# STACKS_AT_MAX           Effect stacks at maximum
# ALLY_FROM_REGION        Companion from region (condition_value = "Liyue")
# HAS_STATUS              Unit has status (condition_value = status name)
# REACTION_ELEMENT        Reaction involves element (condition_value = element)
@export var condition: String = "NONE"
@export var condition_value: String = ""

# ─── Effect: WHAT happens? ───────────────────────────────────────────────────
# FLAT_DAMAGE             Add flat damage to attacks
# PERCENT_DAMAGE          Multiply damage by percentage (1.5 = 150%)
# CRIT_THRESHOLD          Modify crit threshold (negative = easier to crit)
# CRIT_DAMAGE             Add to crit damage bonus
# STAT_BONUS              Add to stat (effect_stat = stat name)
# STAT_MULTIPLIER         Multiply stat (effect_stat = stat name, value = 0.2 for +20%)
# BURST_CHARGE_GAIN       Gain burst charges
# BURST_CHARGE_FULL       Gain full burst charges
# BURST_CHARGE_LOSE       Lose burst charges
# EXTRA_TURN              Take another turn immediately
# EXTRA_ACTION            Take additional action this turn
# SHIELD_GENERATE         Generate shield (value = health, or dice)
# SHIELD_BONUS            Shields absorb extra damage (value = amount)
# HEAL                    Restore HP (value = amount, or dice, or percent)
# HEAL_PERCENT_DEALT      Heal percentage of damage dealt
# COOLDOWN_RESET          Reset skill cooldown
# REPEAT_ATTACK           Repeat the attack (value = damage multiplier, 1.0 = same)
# DAMAGE_REDUCTION        Reduce incoming damage (value = flat or percent)
# DAMAGE_IMMUNITY         Immune to element damage (condition_value = element)
# SKIP_TURN               Target skips next turn (stun)
# PREVENT_MOVEMENT        Target can't move (root)
# ROLL_ADVANTAGE          Roll twice, take higher
# ROLL_DISADVANTAGE        Roll twice, take lower
# RANDOM_TARGET           Attack hits random target
# APPLY_ELEMENT           Apply element (effect_element = element name)
# REAPPLY_ELEMENT         Continuously reapply element while active
# DOT                     Damage over time (value = damage per tick)
# DOT_PER_ACTION          Damage per any unit's action (not just per turn)
# DEFENSE_REDUCTION       Reduce target defense roll (value = amount)
# KNOCKBACK               Push target tiles (value = distance)
# TAUNT                   Force enemies to target you
# FEAR                    Force movement away from source
# DISARM                  Can't use normal/charged attacks
# REFLECT                 Reflect damage back at attacker
# ENRAGE                  Next attack deals double damage
# FREEZE                  Stun every other turn
# MOVEMENT_BONUS          Extra movement tiles
# RANGE_BONUS             Extra attack range (value = tiles)
# DOUBLE_ACTION           Act twice on your turn
# CHAIN_DAMAGE            Hit additional enemies near target
# SUMMON                  Create entity/object (description has details)
# PREVENT_ELEMENT         Can't apply elements for rest of battle
# EXTEND_SHIELD           Add turns/health to active shield
@export var effect_type: String = ""

# Which stat this effect modifies (for STAT_BONUS, STAT_MULTIPLIER, etc.)
@export var effect_stat: String = ""

# The numeric value of the effect.
# For FLAT_DAMAGE: +2, +4, etc.
# For PERCENT_DAMAGE: 1.5 = 150%, 2.0 = double
# For CRIT_THRESHOLD: -3 (lowers threshold by 3)
# For STAT_BONUS: the amount added
@export var effect_value: float = 0.0

# If set, effect_value is multiplied by this stat's current value.
# e.g., "max_health" with effect_value=0.1 means 10% of max HP.
# e.g., "Energy_Recharge" means value equals ER stat.
@export var value_is_percent_of: String = ""

# Dice expression if effect uses dice (shields, heals, reaction damage).
# Format: "1d4", "2d8", "1d20", etc.
@export var effect_dice: String = ""

# Element associated with this effect (for APPLY_ELEMENT, REAPPLY_ELEMENT, etc.)
@export var effect_element: String = ""

# ─── Target: WHO is affected? ────────────────────────────────────────────────
# SELF            The unit with this effect
# ALL_ALLIES      All party members
# TARGET          The attack target
# ALL_ENEMIES     All enemies
# CLOSEST_ENEMY   Nearest enemy to target
# ATTACKER        Whoever attacked you (for reactive effects like Reflect)
@export var target: String = "SELF"

# ─── Duration ────────────────────────────────────────────────────────────────
# 0 = instant (apply once), -1 = permanent/until removed, N = lasts N turns
@export var duration: int = 0

# For DOT_PER_ACTION: number of actions instead of turns
@export var duration_actions: int = 0

# ─── Stacking ────────────────────────────────────────────────────────────────
# max_stacks = 0 means not stackable
@export var max_stacks: int = 0

# Bonus per stack (added to effect_value per stack)
@export var stack_value: float = 0.0

# If set, only one stack per unique category.
# "attack_type" = one stack per Normal/Charged/Skill/Burst
@export var unique_per: String = ""

# Trigger type that clears/resets all stacks
@export var resets_on: String = ""

# ─── Metadata ────────────────────────────────────────────────────────────────
@export var effect_id: String = ""        # Unique identifier for this effect
@export var description: String = ""      # Human readable summary

# ─── Helpers ─────────────────────────────────────────────────────────────────

## Check if this effect has a dice-based value
func has_dice() -> bool:
	return effect_dice != ""

## Parse dice string "XdY" into [count, die_size]
func parse_dice() -> Array:
	if effect_dice == "":
		return [0, 0]
	var parts = effect_dice.to_lower().split("d")
	if parts.size() != 2:
		return [0, 0]
	return [int(parts[0]), int(parts[1])]

## Check if this effect is stackable
func is_stackable() -> bool:
	return max_stacks > 0

## Get the effective value at a given stack count
func value_at_stacks(stacks: int) -> float:
	return effect_value + (stack_value * stacks)
