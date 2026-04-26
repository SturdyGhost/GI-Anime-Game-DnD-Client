class_name FoodBuffEffects
extends RefCounted

static func get_effects(buff_name: String) -> Array:
	match buff_name:
		"Candied Ajilenakh Nut":
			return [_stat_bonus("attack", 3.0)]
		"Padisarah Pudding":
			return [_stat_bonus("elemental_mastery", 3.0)]
		"Aaru Mixed Rice":
			return [_roll_bonus(2.0)]
		"Biryani":
			return [_flat_damage(2.0)]
		"Shawarma Wrap":
			return [_damage_reduction(2.0)]
		"Lambad Fish Roll":
			return [_heal_per_turn(2.0, 10)]
		"Sabza Meat Stew":
			return [_burst_restore("1d12")]
		"Tahchin":
			return []
		_:
			return []

static func _stat_bonus(stat: String, value: float) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.condition = "NONE"
	e.effect_type = "STAT_BONUS"
	e.effect_stat = stat
	e.effect_value = value
	e.target = "ALL_ALLIES"
	e.duration = -1
	e.description = "+%d %s (food)" % [int(value), stat]
	e.effect_id = "food_buff_%s" % stat
	return e

static func _roll_bonus(value: float) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.condition = "NONE"
	e.effect_type = "STAT_BONUS"
	e.effect_stat = "attack_roll"
	e.effect_value = value
	e.target = "ALL_ALLIES"
	e.duration = -1
	e.description = "+%d attack rolls (food)" % int(value)
	e.effect_id = "food_buff_roll"
	return e

static func _flat_damage(value: float) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "NONE"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = value
	e.target = "SELF"
	e.duration = -1
	e.description = "+%d damage (food)" % int(value)
	e.effect_id = "food_buff_damage"
	return e

static func _damage_reduction(value: float) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_DAMAGE_TAKEN"
	e.condition = "NONE"
	e.effect_type = "DAMAGE_REDUCTION"
	e.effect_value = value
	e.target = "SELF"
	e.duration = -1
	e.description = "-%d damage taken (food)" % int(value)
	e.effect_id = "food_buff_reduction"
	return e

static func _heal_per_turn(value: float, turns: int) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "START_OF_TURN"
	e.condition = "NONE"
	e.effect_type = "HEAL"
	e.effect_value = value
	e.target = "SELF"
	e.duration = turns
	e.description = "Heal %d HP/turn (food)" % int(value)
	e.effect_id = "food_buff_heal"
	return e

static func _burst_restore(dice: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ONCE_PER_BATTLE"
	e.condition = "NONE"
	e.effect_type = "BURST_CHARGE_GAIN"
	e.effect_dice = dice
	e.target = "SELF"
	e.duration = 0
	e.description = "Restore %s burst charges (food)" % dice
	e.effect_id = "food_buff_burst"
	return e
