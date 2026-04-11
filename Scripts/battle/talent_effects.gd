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
