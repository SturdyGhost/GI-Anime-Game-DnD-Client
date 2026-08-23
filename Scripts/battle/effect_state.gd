class_name EffectState extends RefCounted
## Runtime state for a single active GameEffect on a battler.
## Tracks current stacks, remaining duration, and unique-per categories.

var effect: GameEffect            # The rule definition
var source_type: String = ""      # "weapon", "artifact", "ability", "reaction", "status", "constellation", "talent"
var source_name: String = ""      # e.g., "Royal Greatsword", "Stun", "Vaporize"
var current_stacks: int = 0
var turns_remaining: int = 0      # -1 = permanent, 0 = expired
var actions_remaining: int = 0    # For DOT_PER_ACTION
var stack_categories: Array = []  # For unique_per tracking (e.g., ["Normal", "Charged"])
var is_active: bool = true

## Source types that describe a STANDING TRAIT rather than an applied instance.
## Gear, passive abilities and food buffs are registered once at battle start and
## must last the whole battle — they should never leave the effects tab. Status
## effects and move-applied ability effects (stuns, roots, temporary buffs) are
## instances and keep their authored duration instead.
## "gear" is what EffectProcessor.register_battler tags bulk registrations with.
const PERMANENT_SOURCES := ["weapon", "artifact", "passive", "food", "gear"]

## Create an EffectState from a GameEffect rule.
static func from_effect(eff: GameEffect, src_type: String = "", src_name: String = "") -> EffectState:
	var s = EffectState.new()
	s.effect = eff
	s.source_type = src_type
	s.source_name = src_name
	# `duration` is overloaded: 0 means "instant" for an applied instance, but
	# "lasts the battle" for a standing trait. Disambiguate by SOURCE, not by
	# trigger — a passive is still a passive when it uses ON_DAMAGE_TAKEN to
	# describe when it applies (e.g. the Ruin Grader's Shock Absorbers). Judging
	# by trigger alone silently expired every weapon effect and most artifact set
	# bonuses at the holder's first turn end.
	# An explicit non-zero duration is always honoured, so deliberately timed gear
	# buffs still tick down as authored.
	if eff.duration == 0 and (eff.trigger == "PASSIVE" or src_type in PERMANENT_SOURCES):
		s.turns_remaining = -1
	else:
		s.turns_remaining = eff.duration
	s.actions_remaining = eff.duration_actions
	if eff.is_stackable():
		s.current_stacks = 1
	return s

## Try to add a stack. Returns true if stack was added.
func add_stack(category: String = "") -> bool:
	if effect.max_stacks <= 0:
		return false
	# Check unique_per
	if effect.unique_per != "" and category != "":
		if stack_categories.has(category):
			return false  # Already have this category
		stack_categories.append(category)
	if current_stacks >= effect.max_stacks:
		return false
	current_stacks += 1
	# Refresh duration on stack gain
	if effect.duration > 0:
		turns_remaining = effect.duration
	return true

## Reset stacks to 0 and clear categories.
func reset_stacks() -> void:
	current_stacks = 0
	stack_categories.clear()

## Get the current effective value (base + stacks).
func current_value() -> float:
	return effect.value_at_stacks(current_stacks)

## Tick down duration by 1 turn. Returns true if still active.
func tick_turn() -> bool:
	if turns_remaining == -1:
		return true  # Permanent
	if turns_remaining > 0:
		turns_remaining -= 1
	if turns_remaining == 0:
		is_active = false
	return is_active

## Tick down per-action duration. Returns true if still active.
func tick_action() -> bool:
	if actions_remaining <= 0:
		return true  # Not action-based
	actions_remaining -= 1
	if actions_remaining <= 0:
		is_active = false
	return is_active

## Check if this effect has expired.
func is_expired() -> bool:
	return not is_active
