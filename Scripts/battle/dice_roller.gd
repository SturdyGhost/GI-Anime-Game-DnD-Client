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
	while v >= 20:
		dice.append(20)
		v -= 20
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


# ============================================================================
#  Enemy tier-based damage formula
#  Enemies roll a tier accuracy die against the target's defense roll. The
#  positive difference picks the CLOSEST damage die (ties round DOWN), which is
#  rolled N times and added to a flat floor — both N and floor set by the tier.
#  Non-standard "combo" dice are built from real dice: D16 = D10+D6,
#  D24 = D20+D4, D30 = D20+D10, D32 (accuracy only) = D20+D12.
# ============================================================================

const _DMG_DIE_LADDER := [4, 6, 8, 10, 12, 16, 20, 24, 30]
const _DMG_DIE_FACES := {
	4: [4], 6: [6], 8: [8], 10: [10], 12: [12],
	16: [10, 6], 20: [20], 24: [20, 4], 30: [20, 10],
}

## Component dice an enemy of the given tier rolls for accuracy.
static func enemy_accuracy_dice(tier: String) -> Array:
	match tier.to_lower():
		"common": return [12]
		"uncommon": return [10, 6]            # D16
		"rare": return [20]
		"epic": return [20, 4]                # D24
		"story_boss": return [20]             # D20 — story bosses trade accuracy
		                                      # for multi-target / multi-hit kits
		"boss", "world_boss", "legendary":
			return [20, 12]                   # D32
	return [12]

## Damage dice count + flat floor for an enemy of the given tier.
static func enemy_damage_profile(tier: String) -> Dictionary:
	match tier.to_lower():
		"common": return {"count": 2, "floor": 3}
		"uncommon": return {"count": 3, "floor": 6}
		"rare": return {"count": 3, "floor": 9}
		"epic": return {"count": 4, "floor": 12}
		"story_boss": return {"count": 4, "floor": 15}
		"boss", "world_boss", "legendary":
			return {"count": 4, "floor": 15}
	return {"count": 2, "floor": 3}

## Roll a set of component dice and return the sum.
static func roll_dice_array(dice: Array) -> int:
	var total := 0
	for d in dice:
		total += roll(int(d))
	return total

## Map a positive roll difference to the closest damage-die SIZE (ties round down).
## Returns 0 for a non-positive difference (a miss).
static func closest_damage_die(diff: int) -> int:
	if diff <= 0:
		return 0
	var best_size: int = int(_DMG_DIE_LADDER[0])
	var best_dist: int = absi(int(_DMG_DIE_LADDER[0]) - diff)
	for size in _DMG_DIE_LADDER:
		var dist := absi(int(size) - diff)
		if dist < best_dist:   # ascending ladder + strict < keeps the smaller die on a tie
			best_dist = dist
			best_size = int(size)
	return best_size

## Enemy damage for a confirmed hit (diff > 0): roll N copies of the closest
## damage die to the difference, then add the tier's flat floor.
static func roll_enemy_tier_damage(diff: int, tier: String) -> int:
	var die_size := closest_damage_die(diff)
	if die_size <= 0:
		return 0
	var faces: Array = _DMG_DIE_FACES[die_size]
	var prof := enemy_damage_profile(tier)
	var total := 0
	for _i in range(int(prof["count"])):
		for f in faces:
			total += roll(int(f))
	return total + int(prof["floor"])

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
		current = maxi(ceili(current / 3.0), 1)
		total += current
	return total

## Calculate all possible damage outcomes for a given damage die.
## Returns Array of {roll: int, damage: int} for each possible roll value.
## Used by the post-turn damage breakdown panel.
static func all_possible_damages(diff: int, hits: int, flat_mod: float, mult_mod: float) -> Array:
	var dice = difference_to_damage_dice(diff)
	if dice.is_empty():
		return []
	var min_roll := dice.size()
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
## Passive: spend 2 HP per threshold reduction (min threshold of 1).
## AI spends HP when the roll would otherwise fail.
## Returns {damage: int, hp_spent: int, rolls: Array[int], succeeded: bool}
static func roll_escalation(hp_available: int, push_further: bool = false) -> Dictionary:
	var chain := [4, 6, 8, 10, 12, 20]
	var thresholds := [3, 4, 5, 6, 7, 11]
	var cumulative := 0
	var hp_spent := 0
	var rolls: Array[int] = []
	var hp_remaining := hp_available

	for i in range(chain.size()):
		var die_size: int = chain[i]
		var threshold: int = thresholds[i]
		# Push Further talent: first roll gets -1 requirement
		if push_further and i == 0:
			threshold = maxi(threshold - 1, 1)
		var result := roll(die_size)
		rolls.append(result)

		# If roll fails, try spending HP to reduce threshold (passive)
		if result < threshold:
			var deficit := threshold - result  # How much we need to reduce threshold
			var reductions_needed := deficit
			var hp_cost := reductions_needed * 2
			# Can't reduce below 1, so max reductions = threshold - 1
			var max_reductions := threshold - 1
			reductions_needed = mini(reductions_needed, max_reductions)
			hp_cost = reductions_needed * 2
			if hp_cost <= hp_remaining and result >= (threshold - reductions_needed):
				# Spend HP to save the roll
				hp_spent += hp_cost
				hp_remaining -= hp_cost
			else:
				# Can't afford or threshold can't go low enough — fail
				return {"damage": 0, "hp_spent": hp_spent, "rolls": rolls, "succeeded": false}

		cumulative += result

	return {"damage": cumulative, "hp_spent": hp_spent, "rolls": rolls, "succeeded": true}
