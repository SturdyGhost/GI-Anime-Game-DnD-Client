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
## Returns {damage: int, hp_spent: int, rolls: Array[int], succeeded: bool}
static func roll_escalation(hp_available: int) -> Dictionary:
	var chain := [4, 6, 8, 10, 12, 20]
	var thresholds := [3, 4, 5, 6, 7, 11]
	var cumulative := 0
	var hp_spent := 0
	var rolls: Array[int] = []

	for i in range(chain.size()):
		var die_size: int = chain[i]
		var threshold: int = thresholds[i]
		var result := roll(die_size)
		rolls.append(result)

		if result < threshold:
			return {"damage": 0, "hp_spent": hp_spent, "rolls": rolls, "succeeded": false}

		cumulative += result

	return {"damage": cumulative, "hp_spent": hp_spent, "rolls": rolls, "succeeded": true}
