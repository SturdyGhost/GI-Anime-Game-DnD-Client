class_name TalentEffects extends RefCounted
## Maps chosen talent IDs to GameEffect arrays for battle simulation.
## Only combat-relevant talents are mapped — gathering/crafting/utility talents are skipped.

static func get_effects(talent_id: int) -> Array:
	match talent_id:

		# ═════════════════════════════════════════
		#  BRIAN C. TALENTS
		# ═════════════════════════════════════════

		# Push Further – First escalation each turn: −1 requirement
		# (Handled directly in DiceRoller.roll_escalation via flag)
		41:
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "ESCALATION_THRESHOLD_REDUCTION"
			e.effect_value = 1.0
			e.description = "Push Further: first escalation roll -1 requirement"
			return [e]

		# Nature Takes Its Due – If 10+ HP lost this turn, next Nature damage doubled
		139:
			var e = GameEffect.new()
			e.trigger = "ON_DAMAGE_TAKEN"
			e.condition = "HP_LOST_THRESHOLD"
			e.condition_value = "10"
			e.effect_type = "PERCENT_DAMAGE"
			e.effect_value = 2.0
			e.duration = 1
			e.description = "Nature Takes Its Due: if 10+ HP lost, next Nature damage doubled"
			return [e]

		# Defense roll boost – if roll 5 or less, add D10
		10, 27:
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "DEFENSE_ROLL_BOOST"
			e.effect_value = 10.0  # Add D10
			e.condition = "DICE_ROLL_CHECK"
			e.condition_value = "5-"
			e.description = "If defense roll 5 or less, add D10"
			return [e]

		# Once per battle below 25% HP, restore to 50%
		22, 44:
			var e = GameEffect.new()
			e.trigger = "ON_DAMAGE_TAKEN"
			e.effect_type = "HEAL"
			e.condition = "HP_BELOW_PERCENT"
			e.condition_value = "25"
			e.effect_value = 0.5  # 50% max HP
			e.value_is_percent_of = "max_health"
			e.duration = 0  # Once per battle
			e.description = "Once per battle: below 25% HP, restore to 50%"
			return [e]

		# Lucky Collapse – On escalation failure, deal half highest successful roll
		47:
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "ESCALATION_LUCKY_COLLAPSE"
			e.effect_value = 0.5
			e.description = "Lucky Collapse: on escalation failure, deal half highest roll"
			return [e]

		# High Roller – Each voluntary escalation grants +1 burst charge
		125:
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "ESCALATION_BURST_CHARGE"
			e.effect_value = 1.0
			e.description = "High Roller: each escalation step grants +1 burst charge"
			return [e]

		# Move +5 tiles before basic/item
		68, 64, 85:
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "MOVEMENT_BONUS"
			e.effect_value = 5.0
			e.description = "Increase movement before basic/item by 5 tiles"
			return [e]

		# Brian C. Wind – For each tile traveled in skill, add that much damage to AoE
		135:
			var e = GameEffect.new()
			e.trigger = "ON_SKILL_HIT"
			e.effect_type = "FLAT_DAMAGE"
			e.effect_value = 1.0  # Per tile moved (engine multiplies by tiles)
			e.value_is_percent_of = "tiles_moved"
			e.description = "Skill distance scaling: +1 damage per tile traveled"
			return [e]

		# Brian C. Fire – After using skill, absorb next hit with no damage
		133:
			var e = GameEffect.new()
			e.trigger = "ON_SKILL_USE"
			e.effect_type = "DAMAGE_IMMUNITY"
			e.duration = 1  # Lasts until next hit
			e.target = "SELF"
			e.description = "Post-skill: absorb next hit with no damage"
			return [e]

		# Brian C. Electric – Burst extension on hit + 2x electric damage while burst active
		123:
			var e_extend = GameEffect.new()
			e_extend.trigger = "ON_DAMAGE_TAKEN"
			e_extend.effect_type = "BURST_EXTEND"
			e_extend.effect_value = 1.0  # +1 turn
			e_extend.max_stacks = 2  # Max 2 extensions
			e_extend.description = "While burst active: extend duration +1 on hit (max 2)"
			var e_double = GameEffect.new()
			e_double.trigger = "ON_HIT"
			e_double.condition = "ELEMENT_MATCH"
			e_double.condition_value = "Electric"
			e_double.effect_type = "PERCENT_DAMAGE"
			e_double.effect_value = 2.0
			e_double.description = "While burst active: enemies take 2x electric damage"
			return [e_extend, e_double]

		# ═════════════════════════════════════════
		#  BRIAN F. TALENTS
		# ═════════════════════════════════════════

		# Measured Wind-Up – If no movement this turn, Charged Attack +2 damage
		15:
			var e = GameEffect.new()
			e.trigger = "ON_CHARGED_HIT"
			e.condition = "NO_MOVEMENT"
			e.effect_type = "FLAT_DAMAGE"
			e.effect_value = 2.0
			e.description = "Measured Wind-Up: no movement = charged attack +2 damage"
			return [e]

		# Brian F. Wind – While shielded, all party members +5 to EM rolls
		138:
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.condition = "IS_SHIELDED"
			e.effect_type = "STAT_BONUS"
			e.effect_stat = "elemental_mastery"
			e.effect_value = 5.0
			e.target = "ALL_ALLIES"
			e.description = "While shielded: all allies +5 EM"
			return [e]

		# Brian F. Electric – Physical: 1+ floor, shield break, +1 crit damage
		34:
			var e_floor = GameEffect.new()
			e_floor.trigger = "ON_HIT"
			e_floor.condition = "ELEMENT_MATCH"
			e_floor.condition_value = "Physical"
			e_floor.effect_type = "FLAT_DAMAGE"
			e_floor.effect_value = 1.0
			e_floor.description = "Physical hits always deal 1+ damage minimum"
			var e_crit = GameEffect.new()
			e_crit.trigger = "PASSIVE"
			e_crit.effect_type = "CRIT_DAMAGE"
			e_crit.effect_value = 1.0
			e_crit.condition = "ELEMENT_MATCH"
			e_crit.condition_value = "Physical"
			e_crit.description = "Physical hits: +1.0 crit damage"
			return [e_floor, e_crit]

		# Brian F. Earth – Burst field: earth crit threshold -4, +0.5 crit damage
		54:
			var e_crit_thresh = GameEffect.new()
			e_crit_thresh.trigger = "PASSIVE"
			e_crit_thresh.effect_type = "CRIT_THRESHOLD"
			e_crit_thresh.effect_value = -4.0
			e_crit_thresh.condition = "ELEMENT_MATCH"
			e_crit_thresh.condition_value = "Earth"
			e_crit_thresh.description = "Burst field: earth attacks crit threshold -4"
			var e_crit_dmg = GameEffect.new()
			e_crit_dmg.trigger = "PASSIVE"
			e_crit_dmg.effect_type = "CRIT_DAMAGE"
			e_crit_dmg.effect_value = 0.5
			e_crit_dmg.condition = "ELEMENT_MATCH"
			e_crit_dmg.condition_value = "Earth"
			e_crit_dmg.description = "Burst field: earth attacks +0.5 crit damage"
			return [e_crit_thresh, e_crit_dmg]

		# Brian F. Ice – Skill +5 flat damage, burst heal +2 to allies
		81:
			var e_skill_dmg = GameEffect.new()
			e_skill_dmg.trigger = "ON_SKILL_HIT"
			e_skill_dmg.effect_type = "FLAT_DAMAGE"
			e_skill_dmg.effect_value = 5.0
			e_skill_dmg.description = "Skill always deals +5 damage"
			var e_heal = GameEffect.new()
			e_heal.trigger = "END_OF_TURN"
			e_heal.effect_type = "HEAL"
			e_heal.effect_value = 2.0
			e_heal.target = "ALL_ALLIES"
			e_heal.description = "Allies in burst field heal +2 at end of turn"
			return [e_skill_dmg, e_heal]

		# ═════════════════════════════════════════
		#  DYLAN TALENTS
		# ═════════════════════════════════════════

		# Grasping Vines – Skill pull radius +1
		70:
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "RANGE_BONUS"
			e.effect_value = 1.0
			e.condition = "ATTACK_TYPE"
			e.condition_value = "Skill"
			e.description = "Grasping Vines: skill pull radius +1 tile"
			return [e]

		# Dylan Earth – Basic attack grants 1 burst charge
		128:
			var e = GameEffect.new()
			e.trigger = "ON_NORMAL_HIT"
			e.effect_type = "BURST_CHARGE_GAIN"
			e.effect_value = 1.0
			e.description = "Basic attacks grant 1 burst charge"
			return [e]

		# Dylan Wind – Double basic attack, +1 burst charge + Declension per use
		49:
			var e_double = GameEffect.new()
			e_double.trigger = "PASSIVE"
			e_double.effect_type = "DOUBLE_ACTION"
			e_double.condition = "ATTACK_TYPE"
			e_double.condition_value = "Basic Attack"
			e_double.description = "May use basic attack 2x per turn"
			var e_burst = GameEffect.new()
			e_burst.trigger = "ON_NORMAL_HIT"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_value = 1.0
			e_burst.description = "Each basic attack grants +1 burst charge"
			return [e_double, e_burst]

	return []


## Get all combat-relevant talent effects for a player based on their chosen talents
## and current element. Reads from Global._synced Talents table.
static func get_player_talent_effects(player_name: String, element: String) -> Array:
	var all_effects: Array = []
	var talents_table: Dictionary = Global._synced.get("Talents", {})
	for rid in talents_table:
		var t: Dictionary = talents_table[rid]
		if str(t.get("Name", "")) != player_name:
			continue
		if not t.get("Chosen", false):
			continue
		if str(t.get("Element", "")) != element:
			continue
		var tid: int = int(t.get("id", 0))
		var effects := get_effects(tid)
		all_effects.append_array(effects)
	return all_effects
