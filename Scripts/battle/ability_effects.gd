class_name AbilityEffects extends RefCounted
## Maps ability IDs to their structured GameEffect arrays.
## Called during battle to resolve special mechanics beyond basic damage.

static func get_effects(ability_id: int) -> Array:
	match ability_id:

		# =====================================================================
		#  BRIAN C. ABILITIES
		# =====================================================================

		# Brian C. – Skill (Nature) – Escalation mechanic + burst charge gain
		397:
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.value_is_percent_of = "Energy_Recharge"
			e_burst.description = "Gain 1d4 burst charges x ER after"
			return [e_burst]

		# Brian C. – Basic (Physical) – just stab + move, no special effects
		452, 444, 431, 426, 409:
			return []

		# Brian C. – Basic (Nature) – just slash + move
		416:
			return []

		# Brian C. – Charged Attack (Nature) – Applies Nature + burst charges
		473:
			var e_elem = EffectBuilder.apply_element("Nature", "TARGET", 0, "Applies Nature to target")
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.value_is_percent_of = "Energy_Recharge"
			e_burst.description = "Gain 1d4 burst charges x ER"
			return [e_elem, e_burst]

		# Brian C. – Charged Attack (Physical) – knockback + burst charge
		388:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Brian C. – Charged Attack (Electric) – knockback + burst charge
		412:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Brian C. – Burst (Nature) – 2 attacks as Nature + double reactions + charge regain
		417:
			var e_extra = GameEffect.new()
			e_extra.trigger = "PASSIVE"
			e_extra.effect_type = "EXTRA_ACTION"
			e_extra.description = "Perform up to 2 Basic or Charged Attacks"
			var e_double_react = GameEffect.new()
			e_double_react.trigger = "ON_REACTION"
			e_double_react.effect_type = "PERCENT_DAMAGE"
			e_double_react.effect_value = 2.0
			e_double_react.description = "Double Nature reactions triggered"
			var e_no_move = EffectBuilder.prevent_movement(0, "Cannot move this turn")
			return [e_extra, e_double_react, e_no_move]

		# Brian C. – Burst (Earth) – Empower for 2 turns, attack twice, earth damage
		443:
			var e_extra = GameEffect.new()
			e_extra.trigger = "PASSIVE"
			e_extra.effect_type = "DOUBLE_ACTION"
			e_extra.duration = 2
			e_extra.description = "May basic/charged attack twice while empowered"
			var e_elem = EffectBuilder.apply_element("Earth", "SELF", 2, "Attacks deal earth damage")
			return [e_extra, e_elem]

		# Brian C. – Burst (Wind) – Summon wind ninja for 2 turns
		445:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.duration = 2
			e_summon.description = "Summon a wind ninja that performs coordinated attacks or heals"
			return [e_summon]

		# Brian C. – Burst (Water) – Buff whole team for 2 turns
		380:
			var e_skill_dmg = GameEffect.new()
			e_skill_dmg.trigger = "PASSIVE"
			e_skill_dmg.effect_type = "PERCENT_DAMAGE"
			e_skill_dmg.effect_value = 1.5
			e_skill_dmg.target = "ALL_ALLIES"
			e_skill_dmg.duration = 2
			e_skill_dmg.condition = "ATTACK_TYPE"
			e_skill_dmg.condition_value = "Skill"
			e_skill_dmg.description = "Elemental skills + bursts deal 1.5x damage"
			var e_double_react = GameEffect.new()
			e_double_react.trigger = "ON_REACTION"
			e_double_react.effect_type = "PERCENT_DAMAGE"
			e_double_react.effect_value = 2.0
			e_double_react.target = "ALL_ALLIES"
			e_double_react.duration = 2
			e_double_react.description = "Reaction damage is doubled"
			var e_double_charge = GameEffect.new()
			e_double_charge.trigger = "PASSIVE"
			e_double_charge.effect_type = "BURST_CHARGE_GAIN"
			e_double_charge.effect_value = 2.0
			e_double_charge.target = "ALL_ALLIES"
			e_double_charge.duration = 2
			e_double_charge.description = "Burst charges gained is doubled"
			return [e_skill_dmg, e_double_react, e_double_charge]

		# Brian C. – Burst (Fire) – Slash + shield + fire reapply
		414:
			var e_shield = GameEffect.new()
			e_shield.trigger = "PASSIVE"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.effect_value = 0.25
			e_shield.value_is_percent_of = "max_health"
			e_shield.description = "Generate shield equal to 1/4 max HP roll"
			var e_elem = EffectBuilder.reapply_element("Fire", "SELF", -1, "While shielded fire is continuously reapplied")
			return [e_shield, e_elem]

		# Brian C. – Burst (Electric) – Half damage for 2 turns + chain electric
		454:
			var e_dr = GameEffect.new()
			e_dr.trigger = "PASSIVE"
			e_dr.effect_type = "DAMAGE_REDUCTION"
			e_dr.effect_value = 0.5
			e_dr.duration = 2
			e_dr.description = "Take half damage for 2 turns"
			var e_chain = GameEffect.new()
			e_chain.trigger = "ON_HIT"
			e_chain.effect_type = "CHAIN_DAMAGE"
			e_chain.effect_element = "Electric"
			e_chain.target = "ALL_ALLIES"
			e_chain.duration = 2
			e_chain.description = "All allies attacks deal linked electrical damage"
			return [e_dr, e_chain]

		# Brian C. – Skill (Water) – Reflect next attack as double water damage
		455:
			var e_reflect = EffectBuilder.reflect(1, "Reflect next attack dealing double damage as water")
			var e_elem = EffectBuilder.apply_element("Water", "ATTACKER", 0, "Reflected damage is water")
			return [e_reflect, e_elem]

		# Brian C. – Skill (Electric) – Wide slash, empowered if hit last
		418:
			var e_emp = GameEffect.new()
			e_emp.trigger = "PASSIVE"
			e_emp.condition = "HAS_STATUS"
			e_emp.condition_value = "was_last_hit"
			e_emp.effect_type = "RANGE_BONUS"
			e_emp.effect_value = 99.0
			e_emp.description = "If you were hit last, slash extends to edge of floor"
			return [e_emp]

		# Brian C. – Skill (Wind) – Beyblade pull + wind damage
		448:
			var e_move = GameEffect.new()
			e_move.trigger = "PASSIVE"
			e_move.effect_type = "MOVEMENT_BONUS"
			e_move.effect_value = 7.0
			e_move.description = "Move up to 7 tiles pulling small enemies"
			return [e_move]

		# Brian C. – Skill (Earth) – Shield + earth reapply
		413:
			var e_shield = GameEffect.new()
			e_shield.trigger = "PASSIVE"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.effect_value = 0.5
			e_shield.value_is_percent_of = "defense"
			e_shield.duration = 3
			e_shield.description = "Shield absorbs 1/2 Defense Roll for 3 turns"
			var e_elem = EffectBuilder.reapply_element("Earth", "SELF", 3, "While shielded earth is continuously reapplied")
			return [e_shield, e_elem]

		# Brian C. – Skill (Fire) – Apply fire + taunt + advantage + ally buff
		415:
			var e_elem = EffectBuilder.apply_element("Fire", "TARGET", 0, "Apply fire to all units within 3 tiles")
			var e_taunt = EffectBuilder.taunt(1, "Small units are taunted for next attack")
			var e_adv = EffectBuilder.roll_advantage(1, "Roll twice and take the better roll")
			var e_ally_buff = GameEffect.new()
			e_ally_buff.trigger = "PASSIVE"
			e_ally_buff.effect_type = "FLAT_DAMAGE"
			e_ally_buff.effect_value = 5.0
			e_ally_buff.target = "ALL_ALLIES"
			e_ally_buff.duration = 1
			e_ally_buff.condition = "ATTACK_TYPE"
			e_ally_buff.condition_value = "Normal"
			e_ally_buff.description = "Allies next physical attack roll +5"
			return [e_elem, e_taunt, e_adv, e_ally_buff]

		# Brian C. Nature – Passive
		472:
			return []  # Complex escalation mechanic handled in logic

		# =====================================================================
		#  BRIAN F. ABILITIES
		# =====================================================================

		# Brian F. – Basic (Physical) – just shoot + move, no special effects
		451, 449, 387, 419, 399, 393:
			return []

		# Brian F. – Basic (Nature) – bonus damage if target rooted
		385:
			var e_root_bonus = GameEffect.new()
			e_root_bonus.trigger = "ON_HIT"
			e_root_bonus.condition = "HAS_STATUS"
			e_root_bonus.condition_value = "Rooted"
			e_root_bonus.effect_type = "FLAT_DAMAGE"
			e_root_bonus.effect_value = 2.0
			e_root_bonus.description = "If target Rooted, +2 damage"
			return [e_root_bonus]

		# Brian F. – Charged Attack (Physical) – knockback + burst charge
		439, 377, 378, 391, 381:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Brian F. – Charged Attack (Physical ring blade) – burst charge
		407:
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_burst]

		# Brian F. – Charged Attack (Nature) – distance bonus + root bonus
		440:
			var e_root_bonus = GameEffect.new()
			e_root_bonus.trigger = "ON_HIT"
			e_root_bonus.condition = "HAS_STATUS"
			e_root_bonus.condition_value = "Rooted"
			e_root_bonus.effect_type = "FLAT_DAMAGE"
			e_root_bonus.effect_value = 3.0
			e_root_bonus.description = "If target Rooted, +3 damage"
			return [e_root_bonus]

		# Brian F. – Burst (Water) – Twilight Justice state
		434:
			var e_double_action = GameEffect.new()
			e_double_action.trigger = "PASSIVE"
			e_double_action.effect_type = "DOUBLE_ACTION"
			e_double_action.duration = 3
			e_double_action.description = "May perform 2 charged attacks per turn"
			var e_flat = GameEffect.new()
			e_flat.trigger = "PASSIVE"
			e_flat.effect_type = "FLAT_DAMAGE"
			e_flat.effect_value = 2.0
			e_flat.duration = 3
			e_flat.description = "+2 water damage to all hits"
			var e_double_dmg = GameEffect.new()
			e_double_dmg.trigger = "ON_CHARGED_HIT"
			e_double_dmg.effect_type = "PERCENT_DAMAGE"
			e_double_dmg.effect_value = 2.0
			e_double_dmg.duration = 3
			e_double_dmg.description = "Charged attack damage doubled after all boosts"
			var e_elem = EffectBuilder.apply_element("Water", "SELF", 3, "Charged attacks deal water damage using EM")
			return [e_double_action, e_flat, e_double_dmg, e_elem]

		# Brian F. – Burst (Nature) – Range + basic attack + root + bonus damage
		428:
			var e_range = GameEffect.new()
			e_range.trigger = "PASSIVE"
			e_range.effect_type = "RANGE_BONUS"
			e_range.effect_value = 2.0
			e_range.description = "Range +2 this turn"
			var e_extra = GameEffect.new()
			e_extra.trigger = "PASSIVE"
			e_extra.effect_type = "EXTRA_ACTION"
			e_extra.description = "Can use basic attack as well this turn"
			var e_root = EffectBuilder.prevent_movement(2, "Root target for 2 turns")
			e_root.target = "TARGET"
			var e_flat = GameEffect.new()
			e_flat.trigger = "PASSIVE"
			e_flat.effect_type = "FLAT_DAMAGE"
			e_flat.effect_value = 5.0
			e_flat.duration = 2
			e_flat.description = "First damage each turn +5 Nature damage"
			var e_def_ignore = GameEffect.new()
			e_def_ignore.trigger = "PASSIVE"
			e_def_ignore.effect_type = "DEFENSE_REDUCTION"
			e_def_ignore.effect_value = 1.0
			e_def_ignore.duration = 2
			e_def_ignore.target = "TARGET"
			e_def_ignore.description = "Ignore 1 Defense for 2 turns"
			var e_no_move = EffectBuilder.prevent_movement(0, "Cannot move on activation turn")
			return [e_range, e_extra, e_root, e_flat, e_def_ignore, e_no_move]

		# Brian F. – Burst (Wind) – Vacuum pull + swirl
		446:
			var e_elem = EffectBuilder.apply_element("Wind", "TARGET", 0, "Deals wind damage to enemies in range")
			return [e_elem]

		# Brian F. – Burst (Ice) – DoT field + ally heal
		421:
			var e_dot = EffectBuilder.dot_per_action(0, 0, "Enemies take ice damage after every action for 2 turns")
			e_dot.effect_element = "Ice"
			e_dot.target = "ALL_ENEMIES"
			var e_heal = GameEffect.new()
			e_heal.trigger = "END_OF_TURN"
			e_heal.effect_type = "HEAL"
			e_heal.effect_dice = "1d4"
			e_heal.target = "ALL_ALLIES"
			e_heal.duration = 2
			e_heal.description = "Allies who end turn in field heal 1d4"
			var e_elem = EffectBuilder.apply_element("Ice", "ALL_ALLIES", 2, "Allies have ice applied")
			return [e_dot, e_heal, e_elem]

		# Brian F. – Burst (Electric) – Chain lightning + party burst charges
		403:
			var e_chain = GameEffect.new()
			e_chain.trigger = "ON_HIT"
			e_chain.effect_type = "CHAIN_DAMAGE"
			e_chain.effect_element = "Electric"
			e_chain.description = "Explosion chains outward in star pattern"
			var e_burst_all = GameEffect.new()
			e_burst_all.trigger = "ON_HIT"
			e_burst_all.effect_type = "BURST_CHARGE_GAIN"
			e_burst_all.effect_value = 1.0
			e_burst_all.target = "ALL_ALLIES"
			e_burst_all.description = "Each enemy hit gives 1 burst charge to whole party (max 8)"
			return [e_chain, e_burst_all]

		# Brian F. – Burst (Fire) – Field of fire + ally double damage
		395:
			var e_field = EffectBuilder.apply_element("Fire", "TARGET", -1, "Creates field of fire applying to all who pass through")
			var e_double = GameEffect.new()
			e_double.trigger = "PASSIVE"
			e_double.effect_type = "PERCENT_DAMAGE"
			e_double.effect_value = 2.0
			e_double.target = "ALL_ALLIES"
			e_double.duration = 1
			e_double.condition = "ELEMENT_MATCH"
			e_double.condition_value = "Fire"
			e_double.description = "Next fire or electric attack from each ally deals double damage"
			return [e_field, e_double]

		# Brian F. – Burst (Earth) – Earth field doubling
		396:
			var e_self_double = GameEffect.new()
			e_self_double.trigger = "PASSIVE"
			e_self_double.effect_type = "PERCENT_DAMAGE"
			e_self_double.effect_value = 2.0
			e_self_double.duration = 2
			e_self_double.condition = "ELEMENT_MATCH"
			e_self_double.condition_value = "Earth"
			e_self_double.description = "Earth damage you deal is doubled on your field"
			var e_ally_boost = GameEffect.new()
			e_ally_boost.trigger = "PASSIVE"
			e_ally_boost.effect_type = "PERCENT_DAMAGE"
			e_ally_boost.effect_value = 1.5
			e_ally_boost.target = "ALL_ALLIES"
			e_ally_boost.duration = 2
			e_ally_boost.condition = "ELEMENT_MATCH"
			e_ally_boost.condition_value = "Earth"
			e_ally_boost.description = "Allies Earth damage is multiplied by 1.5x"
			return [e_self_double, e_ally_boost]

		# Brian F. – Skill (Water) – Jump back + watery arrow + reaction burst bonus
		435:
			var e_burst_react = GameEffect.new()
			e_burst_react.trigger = "ON_REACTION"
			e_burst_react.effect_type = "BURST_CHARGE_GAIN"
			e_burst_react.effect_dice = "1d12"
			e_burst_react.description = "If reaction triggered gain 1d12 burst charges instead of 1d4"
			return [e_burst_react]

		# Brian F. – Skill (Ice) – Root target + ice wall
		433:
			var e_root = EffectBuilder.prevent_movement(1, "Root target")
			e_root.target = "TARGET"
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.description = "Lay down a wall of ice in a 1x3 zone"
			return [e_root, e_summon]

		# Brian F. – Skill (Nature) – Root Beer buff
		390:
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.value_is_percent_of = "Energy_Recharge"
			e_burst.description = "Gain 1d4 burst charges x ER"
			var e_flat = GameEffect.new()
			e_flat.trigger = "ON_HIT"
			e_flat.effect_type = "FLAT_DAMAGE"
			e_flat.effect_value = 4.0
			e_flat.effect_element = "Nature"
			e_flat.duration = 2
			e_flat.description = "First enemy damaged each turn: +4 Nature damage"
			var e_root = EffectBuilder.prevent_movement(1, "First enemy damaged each turn: Root")
			e_root.target = "TARGET"
			e_root.duration = 2
			return [e_burst, e_flat, e_root]

		# Brian F. – Skill (Wind) – Dash + conditional shield
		389:
			var e_shield = GameEffect.new()
			e_shield.trigger = "ON_HIT"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.effect_value = 1.0
			e_shield.description = "If enemy is elemental, gain small shield absorbing next hit"
			var e_elem = GameEffect.new()
			e_elem.trigger = "PASSIVE"
			e_elem.effect_type = "REAPPLY_ELEMENT"
			e_elem.description = "While shielded that element is continuously reapplied"
			return [e_shield, e_elem]

		# Brian F. – Skill (Electric) – Party physical damage buff
		423:
			var e_buff = GameEffect.new()
			e_buff.trigger = "PASSIVE"
			e_buff.effect_type = "FLAT_DAMAGE"
			e_buff.effect_value = 0.5
			e_buff.value_is_percent_of = "Attack"
			e_buff.target = "ALL_ALLIES"
			e_buff.duration = 3
			e_buff.description = "All party members add half your Attack roll to physical damage for 3 turns"
			return [e_buff]

		# Brian F. – Skill (Earth) – Shield + earth reapply + piercing charged
		425:
			var e_shield = GameEffect.new()
			e_shield.trigger = "PASSIVE"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.effect_value = 0.25
			e_shield.value_is_percent_of = "defense"
			e_shield.description = "Shield absorbs 1/4 defense roll"
			var e_elem = EffectBuilder.reapply_element("Earth", "SELF", -1, "While shielded earth is continuously reapplied")
			var e_extra = GameEffect.new()
			e_extra.trigger = "PASSIVE"
			e_extra.effect_type = "EXTRA_ACTION"
			e_extra.condition = "IS_SHIELDED"
			e_extra.description = "May charge attack once during activation turn"
			return [e_shield, e_elem, e_extra]

		# Brian F. – Skill (Fire) – Musket shot + party heal on reaction
		384:
			var e_heal = GameEffect.new()
			e_heal.trigger = "ON_REACTION"
			e_heal.effect_type = "HEAL_PERCENT_DEALT"
			e_heal.effect_value = 0.5
			e_heal.target = "ALL_ALLIES"
			e_heal.description = "If fire reaction triggered, party healed for half damage dealt each"
			return [e_heal]

		# =====================================================================
		#  DYLAN ABILITIES
		# =====================================================================

		# Dylan – Basic (Water) – just attack + move
		441:
			return []

		# Dylan – Basic (Nature) – pull small units
		401:
			return []  # Pull handled in targeting logic

		# Dylan – Basic (Earth) – gem stack gain
		382:
			var e_stack = GameEffect.new()
			e_stack.trigger = "ON_HIT"
			e_stack.effect_type = "STAT_BONUS"
			e_stack.effect_stat = "gem_stacks"
			e_stack.effect_value = 1.0
			e_stack.max_stacks = 99
			e_stack.duration = -1
			e_stack.description = "Each normal attack grants 1 gem stack (no cap)"
			return [e_stack]

		# Dylan – Basic (Electric) – just attack + move
		427:
			return []

		# Dylan – Basic (Physical) – just slash + move
		424:
			return []

		# Dylan – Basic (Wind) – dash + kick + move
		398:
			return []

		# Dylan – Basic (Fire) – fire stack gain
		430:
			var e_stack = GameEffect.new()
			e_stack.trigger = "ON_HIT"
			e_stack.effect_type = "STAT_BONUS"
			e_stack.effect_stat = "fire_stacks"
			e_stack.effect_dice = "1d4"
			e_stack.max_stacks = 3
			e_stack.duration = -1
			e_stack.description = "Each normal attack gives 1d4 Fire Stacks (max 3)"
			return [e_stack]

		# Dylan – Charged Attack (Nature) – Root + pull + burst charges
		408:
			var e_root = EffectBuilder.prevent_movement(1, "Rooted until end of next turn")
			e_root.target = "TARGET"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.value_is_percent_of = "Energy_Recharge"
			e_burst.description = "Gain 1d4 burst charges x ER"
			return [e_root, e_burst]

		# Dylan – Charged Attack (Physical) – knockback + burst charge
		447:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Dylan – Charged Attack (Water) – knockback + burst charge
		400:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Dylan – Charged Attack (Earth) – knockback + burst charge
		394:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Dylan – Charged Attack (Wind) – gain Declension stack
		402:
			var e_stack = GameEffect.new()
			e_stack.trigger = "ON_HIT"
			e_stack.effect_type = "STAT_BONUS"
			e_stack.effect_stat = "declension_stacks"
			e_stack.effect_value = 1.0
			e_stack.max_stacks = 4
			e_stack.duration = -1
			e_stack.description = "Gain 1 Declension Stack"
			return [e_stack]

		# Dylan – Charged Attack (Electric) – knockback + burst charge
		383:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Dylan – Charged Attack (Fire) – damage x fire stacks, clear stacks
		420:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			var e_stack_mult = GameEffect.new()
			e_stack_mult.trigger = "PASSIVE"
			e_stack_mult.effect_type = "PERCENT_DAMAGE"
			e_stack_mult.condition = "HAS_STATUS"
			e_stack_mult.condition_value = "fire_stacks"
			e_stack_mult.description = "Damage multiplied by number of fire stacks (cleared on use)"
			return [e_kb, e_burst, e_stack_mult]

		# Dylan – Skill (Nature) – Root + pull
		376:
			var e_root = EffectBuilder.prevent_movement(1, "All enemies are Rooted")
			e_root.target = "TARGET"
			var e_elem = EffectBuilder.apply_element("Nature", "TARGET", 0, "Apply Nature damage")
			return [e_root, e_elem]

		# Dylan – Skill (Earth) – Earth screen + self buff
		386:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.duration = 2
			e_summon.description = "Creates 1x3 earth screen absorbing non-earth projectiles"
			var e_buff = GameEffect.new()
			e_buff.trigger = "PASSIVE"
			e_buff.effect_type = "FLAT_DAMAGE"
			e_buff.effect_value = 4.0
			e_buff.duration = 2
			e_buff.condition = "ELEMENT_MATCH"
			e_buff.condition_value = "Earth"
			e_buff.description = "Passing through screen adds +4 to Earth attacks for 2 turns"
			return [e_summon, e_buff]

		# Dylan – Skill (Water) – Water droplets + heal on attack
		453:
			var e_elem = EffectBuilder.reapply_element("Water", "SELF", 3, "Water constantly reapplied to you")
			var e_apply = EffectBuilder.apply_element("Water", "TARGET", 3, "Enemies within 2 tiles have water applied")
			var e_heal = EffectBuilder.heal_percent_dealt(0.5, "Normal/charged attacks heal party for half damage dealt")
			e_heal.target = "ALL_ALLIES"
			e_heal.duration = 3
			return [e_elem, e_apply, e_heal]

		# Dylan – Skill (Electric) – Throw sword + blink
		432:
			return []  # Blink mechanics handled in targeting logic

		# Dylan – Skill (Electric) – Cloud familiar
		392:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.duration = 2
			e_summon.description = "Summon a cloud familiar"
			var e_cd = GameEffect.new()
			e_cd.trigger = "ON_HIT"
			e_cd.effect_type = "COOLDOWN_RESET"
			e_cd.effect_value = 1.0
			e_cd.description = "Every unit hit by cloud refunds 1 turn of cooldown"
			return [e_summon, e_cd]

		# Dylan – Skill (Wind) – Dash punch x3 + Declension stack
		450:
			var e_repeat = GameEffect.new()
			e_repeat.trigger = "PASSIVE"
			e_repeat.effect_type = "REPEAT_ATTACK"
			e_repeat.effect_value = 3.0
			e_repeat.description = "Punch dealing wind damage 3 times"
			var e_stack = GameEffect.new()
			e_stack.trigger = "PASSIVE"
			e_stack.effect_type = "STAT_BONUS"
			e_stack.effect_stat = "declension_stacks"
			e_stack.effect_value = 1.0
			e_stack.max_stacks = 4
			e_stack.duration = -1
			e_stack.description = "Grant 1 Declension stack"
			return [e_repeat, e_stack]

		# Dylan – Skill (Fire) – Fire ball + fire stacks
		410:
			var e_stack = GameEffect.new()
			e_stack.trigger = "PASSIVE"
			e_stack.effect_type = "STAT_BONUS"
			e_stack.effect_stat = "fire_stacks"
			e_stack.effect_value = 3.0
			e_stack.max_stacks = 3
			e_stack.duration = -1
			e_stack.description = "Gives you 3 Fire Stacks"
			return [e_stack]

		# Dylan – Burst (Electric) – Chain lightning + movement
		442:
			var e_chain = GameEffect.new()
			e_chain.trigger = "ON_HIT"
			e_chain.effect_type = "CHAIN_DAMAGE"
			e_chain.effect_element = "Electric"
			e_chain.description = "Attacks chain outward on hit until no more units"
			var e_move = GameEffect.new()
			e_move.trigger = "ON_HIT"
			e_move.effect_type = "MOVEMENT_BONUS"
			e_move.effect_value = 1.0
			e_move.description = "For each unit hit gain 1 movement"
			return [e_chain, e_move]

		# Dylan – Burst (Fire) – Empower charged attacks + fire stacks
		438:
			var e_range = GameEffect.new()
			e_range.trigger = "PASSIVE"
			e_range.effect_type = "RANGE_BONUS"
			e_range.effect_value = 4.0
			e_range.duration = 3
			e_range.description = "Charged attacks can target any tile within 4 tiles"
			var e_stack = GameEffect.new()
			e_stack.trigger = "START_OF_TURN"
			e_stack.effect_type = "STAT_BONUS"
			e_stack.effect_stat = "fire_stacks"
			e_stack.effect_value = 3.0
			e_stack.max_stacks = 3
			e_stack.duration = 3
			e_stack.description = "At start of turn generates 3 fire stacks"
			return [e_range, e_stack]

		# Dylan – Burst (Wind) – Vacuum pull + knockback x declension stacks
		422:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 2.0
			e_kb.target = "TARGET"
			e_kb.description = "Kick pulled units 2 tiles outward"
			var e_mult = GameEffect.new()
			e_mult.trigger = "PASSIVE"
			e_mult.effect_type = "PERCENT_DAMAGE"
			e_mult.condition = "HAS_STATUS"
			e_mult.condition_value = "declension_stacks"
			e_mult.description = "Damage multiplied by Declension stacks (max 4, cleared)"
			return [e_kb, e_mult]

		# Dylan – Burst (Electric) – Time rewind / reposition
		436:
			var e_elem = EffectBuilder.apply_element("Electric", "ALL_ALLIES", 0, "Applies electricity to all involved")
			return [e_elem]

		# Dylan – Burst (Earth) – Fire missiles equal to gem stacks
		406:
			var e_repeat = GameEffect.new()
			e_repeat.trigger = "PASSIVE"
			e_repeat.effect_type = "REPEAT_ATTACK"
			e_repeat.condition = "HAS_STATUS"
			e_repeat.condition_value = "gem_stacks"
			e_repeat.description = "Number of missiles equals gem stacks (consumed)"
			return [e_repeat]

		# Dylan – Burst (Water) – Full heal + revive
		379:
			var e_heal = GameEffect.new()
			e_heal.trigger = "PASSIVE"
			e_heal.effect_type = "HEAL"
			e_heal.effect_value = 9999.0
			e_heal.target = "ALL_ALLIES"
			e_heal.description = "Heal all allies to full including downed allies"
			var e_elem = EffectBuilder.apply_element("Water", "ALL_ALLIES", 0, "Apply water to all party members")
			return [e_heal, e_elem]

		# Dylan – Burst (Nature) – Transformation based on EM roll
		437:
			var e_no_move = EffectBuilder.prevent_movement(0, "Cannot move on activation turn")
			return [e_no_move]  # Transformation handled in logic based on roll

		# Dylan test passives – no effects
		459, 460:
			return []

		# =====================================================================
		#  COMPANION ABILITIES
		# =====================================================================

		# Ayaka – Skill (Ice) – Buff charged attacks for 2 turns
		255:
			var e_elem = EffectBuilder.apply_element("Ice", "SELF", 2, "Charged attacks deal ice damage for 2 turns")
			var e_double_charge = GameEffect.new()
			e_double_charge.trigger = "PASSIVE"
			e_double_charge.effect_type = "BURST_CHARGE_GAIN"
			e_double_charge.effect_value = 2.0
			e_double_charge.duration = 2
			e_double_charge.description = "Doubles charges gained for 2 turns"
			return [e_elem, e_double_charge]

		# Ayaka – Burst (Ice) – Multi-hit blizzard
		264:
			return []  # Multi-hit count determined by EM roll in logic

		# Ayato – Skill (Water) – Takimeguri Kanka state
		297:
			var e_elem = EffectBuilder.apply_element("Water", "SELF", 1, "Attacks deal water damage")
			return [e_elem]

		# Ayato – Burst (Water) – Rain cloud field
		277:
			var e_elem = EffectBuilder.reapply_element("Water", "ALL_ENEMIES", 2, "Water constantly reapplied to all units in area")
			var e_double = GameEffect.new()
			e_double.trigger = "ON_CHARGED_HIT"
			e_double.effect_type = "PERCENT_DAMAGE"
			e_double.effect_value = 2.0
			e_double.duration = 2
			e_double.description = "Charged attacks in field deal double damage"
			return [e_elem, e_double]

		# Baizhu – Skill (Nature) – Changsheng heals + defense bonus
		321:
			var e_heal = GameEffect.new()
			e_heal.trigger = "START_OF_TURN"
			e_heal.effect_type = "HEAL"
			e_heal.effect_value = 0.5
			e_heal.value_is_percent_of = "Elemental_Mastery"
			e_heal.target = "ALL_ALLIES"
			e_heal.duration = 3
			e_heal.description = "Heal allies for 1/2 avg EM roll each turn"
			var e_def = EffectBuilder.stat_bonus("Defense", 2.0, "PASSIVE", 1, "Healed ally gets +2 to next defense roll")
			e_def.target = "ALL_ALLIES"
			return [e_heal, e_def]

		# Baizhu – Charged Attack (Nature) – mark enemies
		314:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "Marks enemies"
			return [e_kb, e_burst, e_mark]

		# Baizhu – Burst (Nature) – Barrier + heal on damage
		331:
			var e_dr = GameEffect.new()
			e_dr.trigger = "PASSIVE"
			e_dr.effect_type = "DAMAGE_REDUCTION"
			e_dr.effect_value = 2.0
			e_dr.target = "ALL_ALLIES"
			e_dr.duration = 2
			e_dr.description = "Barrier reduces all incoming damage by 2"
			var e_heal = GameEffect.new()
			e_heal.trigger = "ON_DAMAGE_TAKEN"
			e_heal.effect_type = "HEAL"
			e_heal.effect_dice = "1d4"
			e_heal.target = "SELF"
			e_heal.duration = 2
			e_heal.description = "Changsheng heals damaged ally for 1d4"
			return [e_dr, e_heal]

		# Bennett – Skill (Fire) – Knockback self and allies
		375:
			var e_kb = GameEffect.new()
			e_kb.trigger = "PASSIVE"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 2.0
			e_kb.target = "SELF"
			e_kb.description = "Knocks self and adjacent allies back 2 tiles"
			return [e_kb]

		# Bennett – Burst (Fire) – Flaming field + heal + damage buff
		373:
			var e_heal = GameEffect.new()
			e_heal.trigger = "START_OF_TURN"
			e_heal.effect_type = "HEAL"
			e_heal.effect_value = 1.0
			e_heal.target = "ALL_ALLIES"
			e_heal.duration = 3
			e_heal.description = "Heal all party members inside for 1 health at start of turn"
			var e_elem = EffectBuilder.apply_element("Fire", "SELF", 3, "Damage within field converted to fire")
			var e_flat = GameEffect.new()
			e_flat.trigger = "PASSIVE"
			e_flat.effect_type = "FLAT_DAMAGE"
			e_flat.effect_value = 0.0
			e_flat.value_is_percent_of = "Attack"
			e_flat.duration = 3
			e_flat.description = "Base damage increased by 1 Avg Attack roll (limit once per target)"
			return [e_heal, e_elem, e_flat]

		# Collei – Skill (Nature) – Boomerang double hit
		303:
			var e_repeat = GameEffect.new()
			e_repeat.trigger = "PASSIVE"
			e_repeat.effect_type = "REPEAT_ATTACK"
			e_repeat.effect_value = 1.0
			e_repeat.description = "Hits on the way out and back"
			return [e_repeat]

		# Collei – Burst (Nature) – AoE field + DoT + taunt + bonus on reaction
		374:
			var e_dot = GameEffect.new()
			e_dot.trigger = "END_OF_TURN"
			e_dot.effect_type = "DOT"
			e_dot.effect_element = "Nature"
			e_dot.target = "ALL_ENEMIES"
			e_dot.description = "Enemies inside take Nature damage at end of each turn"
			var e_taunt = EffectBuilder.taunt(-1, "Small enemies taunted to center")
			e_taunt.target = "ALL_ENEMIES"
			return [e_dot, e_taunt]

		# Cyno – Skill (Electric) – Follow-up on reaction
		286:
			var e_followup = GameEffect.new()
			e_followup.trigger = "ON_REACTION"
			e_followup.effect_type = "REPEAT_ATTACK"
			e_followup.effect_value = 1.0
			e_followup.effect_element = "Electric"
			e_followup.description = "If electric reaction triggered, follow up attack dealing 2 electric damage"
			return [e_followup]

		# Cyno – Burst (Electric) – Ascension Stance
		292:
			var e_double = GameEffect.new()
			e_double.trigger = "ON_CHARGED_HIT"
			e_double.effect_type = "PERCENT_DAMAGE"
			e_double.effect_value = 2.0
			e_double.duration = 3
			e_double.description = "Charged attack deals double damage"
			var e_extra = GameEffect.new()
			e_extra.trigger = "ON_CHARGED_HIT"
			e_extra.effect_type = "EXTRA_ACTION"
			e_extra.duration = 3
			e_extra.description = "On charged attack, an ally also blinks in and uses their charged attack"
			return [e_double, e_extra]

		# Dehya – Skill (Fire) – Sanctum field
		267:
			var e_dr = GameEffect.new()
			e_dr.trigger = "PASSIVE"
			e_dr.effect_type = "DAMAGE_REDUCTION"
			e_dr.effect_value = 2.0
			e_dr.target = "ALL_ALLIES"
			e_dr.duration = 3
			e_dr.description = "Allies in sanctum take 2 less damage"
			var e_reflect = GameEffect.new()
			e_reflect.trigger = "ON_DAMAGE_TAKEN"
			e_reflect.effect_type = "REFLECT"
			e_reflect.effect_value = 2.0
			e_reflect.effect_element = "Fire"
			e_reflect.duration = 3
			e_reflect.description = "Enemies that damage allies take 2 fire damage back"
			return [e_dr, e_reflect]

		# Dehya – Burst (Fire) – Lioness Spirit state
		268:
			var e_reflect = EffectBuilder.reflect(3, "Counterstrike dealing fire damage back at attacker")
			var e_def = EffectBuilder.stat_bonus("Defense", 4.0, "PASSIVE", 3, "Guard targetted ally giving +4 to defense rolls")
			e_def.target = "ALL_ALLIES"
			return [e_reflect, e_def]

		# Diluc – Skill (Fire) – Leap + smash
		322:
			return []  # Just damage, no special mechanics

		# Diluc – Burst (Fire) – Phoenix knockback
		326:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 99.0
			e_kb.target = "TARGET"
			e_kb.description = "Push all enemies to edge regardless of size"
			return [e_kb]

		# Eula – Skill (Ice) – Dash + ice slash
		309:
			return []  # Just dash + damage

		# Eula – Burst (Ice) – Ice field doubles physical
		281:
			var e_double = GameEffect.new()
			e_double.trigger = "PASSIVE"
			e_double.effect_type = "PERCENT_DAMAGE"
			e_double.effect_value = 2.0
			e_double.duration = 3
			e_double.condition = "ELEMENT_MATCH"
			e_double.condition_value = "Physical"
			e_double.description = "All units attacking in field deal double physical damage"
			return [e_double]

		# Ganyu – Skill (Ice) – Taunt flower
		345:
			var e_taunt = EffectBuilder.taunt(3, "Taunts all tauntable enemies within 5 tiles")
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.duration = 3
			e_summon.description = "Frozen lotus flower (7 HP) explodes on death"
			return [e_taunt, e_summon]

		# Ganyu – Burst (Ice) – Ice rain DoT
		354:
			var e_dot = GameEffect.new()
			e_dot.trigger = "PASSIVE"
			e_dot.effect_type = "DOT_PER_ACTION"
			e_dot.effect_element = "Ice"
			e_dot.target = "ALL_ENEMIES"
			e_dot.description = "Ice spears rain on all enemies after every action"
			return [e_dot]

		# Hu Tao – Skill (Fire) – Fire infusion + stack multiplier
		262:
			var e_elem = EffectBuilder.apply_element("Fire", "SELF", 4, "Charged attacks deal fire damage for 4 turns")
			var e_mult = GameEffect.new()
			e_mult.trigger = "ON_CHARGED_HIT"
			e_mult.effect_type = "PERCENT_DAMAGE"
			e_mult.duration = 4
			e_mult.description = "Charged attack damage multiplied by 1 + number of stacks"
			return [e_elem, e_mult]

		# Hu Tao – Burst (Fire) – Heal allies + damage based on stacks
		287:
			var e_heal = GameEffect.new()
			e_heal.trigger = "PASSIVE"
			e_heal.effect_type = "HEAL"
			e_heal.target = "ALL_ALLIES"
			e_heal.description = "Heal all allies equal to stacks squared"
			return [e_heal]

		# Jean – Skill (Wind) – Knockback + ally burst charge sharing
		358:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 2.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small units 2 tiles"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.target = "ALL_ALLIES"
			e_burst.description = "Allies also gain burst charges from this skill"
			return [e_kb, e_burst]

		# Jean – Burst (Wind) – Heal + field buff
		355:
			var e_heal = GameEffect.new()
			e_heal.trigger = "PASSIVE"
			e_heal.effect_type = "HEAL"
			e_heal.value_is_percent_of = "Attack"
			e_heal.target = "ALL_ALLIES"
			e_heal.description = "Immediately heal all allies 1 Avg Attack Roll"
			var e_flat = GameEffect.new()
			e_flat.trigger = "PASSIVE"
			e_flat.effect_type = "FLAT_DAMAGE"
			e_flat.effect_value = 4.0
			e_flat.target = "ALL_ALLIES"
			e_flat.duration = 2
			e_flat.description = "Any attack roll in field has 4 added to it"
			return [e_heal, e_flat]

		# Kaeya – Skill (Ice) – Just damage cone
		359:
			return []

		# Kaeya – Burst (Ice) – Ice field DoT + movement reduction
		328:
			var e_dot = GameEffect.new()
			e_dot.trigger = "PASSIVE"
			e_dot.effect_type = "DOT_PER_ACTION"
			e_dot.effect_element = "Ice"
			e_dot.target = "ALL_ENEMIES"
			e_dot.description = "Damage all enemies on field after every action"
			var e_slow = GameEffect.new()
			e_slow.trigger = "PASSIVE"
			e_slow.effect_type = "MOVEMENT_BONUS"
			e_slow.effect_value = -98.0
			e_slow.target = "ALL_ENEMIES"
			e_slow.description = "Units on field can only move 2 tiles"
			return [e_dot, e_slow]

		# Kazuha – Skill (Wind) – Vacuum pull
		334:
			return []  # Pull handled in targeting logic

		# Kazuha – Burst (Wind) – Wind field DoT + element transform
		261:
			var e_dot = GameEffect.new()
			e_dot.trigger = "PASSIVE"
			e_dot.effect_type = "DOT_PER_ACTION"
			e_dot.effect_value = 1.0
			e_dot.effect_element = "Wind"
			e_dot.target = "ALL_ENEMIES"
			e_dot.duration = 2
			e_dot.description = "1 wind damage to every enemy after every action"
			var e_double = GameEffect.new()
			e_double.trigger = "PASSIVE"
			e_double.effect_type = "PERCENT_DAMAGE"
			e_double.effect_value = 2.0
			e_dot.target = "ALL_ALLIES"
			e_double.duration = 2
			e_double.description = "Allies deal double damage of transformed element"
			return [e_dot, e_double]

		# Keqing – Skill (Electric) – Blink slash + mark
		333:
			return []  # Blink mechanics handled in targeting logic

		# Keqing – Burst (Electric) – 5-tile dash chain
		304:
			return []  # Just damage along path

		# Klee – Skill (Fire) – Bouncing dumpty + mines
		335:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.description = "Leaves behind mines exploding in 3x3 area when stepped on"
			return [e_summon]

		# Klee – Charged Attack (Fire) – Mark enemies
		317:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "Marks enemies"
			return [e_kb, e_burst, e_mark]

		# Klee – Burst (Fire) – Explosion + mines
		324:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.description = "Leaves 10 mines on empty tiles"
			return [e_summon]

		# Lisa – Skill (Electric) – Blast + mark
		313:
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "All units hit are marked"
			return [e_mark]

		# Lisa – Charged Attack (Electric) – Mark enemies
		263:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "Marks enemies"
			return [e_kb, e_burst, e_mark]

		# Lisa – Burst (Electric) – Damage marked + DoT
		271:
			var e_dot = EffectBuilder.dot_per_action(0, 3, "Marked units take D4 damage every action for 3 actions")
			e_dot.effect_dice = "1d4"
			e_dot.target = "TARGET"
			return [e_dot]

		# Mona – Skill (Water) – Root
		291:
			var e_root = EffectBuilder.prevent_movement(1, "Rooted until end of next turn")
			e_root.target = "TARGET"
			return [e_root]

		# Mona – Burst (Water) – Omen's touch: double action + double damage
		270:
			var e_double_action = GameEffect.new()
			e_double_action.trigger = "PASSIVE"
			e_double_action.effect_type = "DOUBLE_ACTION"
			e_double_action.target = "ALL_ALLIES"
			e_double_action.duration = 1
			e_double_action.description = "Allies may take 2 actions on next turn"
			var e_double_dmg = GameEffect.new()
			e_double_dmg.trigger = "PASSIVE"
			e_double_dmg.effect_type = "PERCENT_DAMAGE"
			e_double_dmg.effect_value = 2.0
			e_double_dmg.target = "ALL_ALLIES"
			e_double_dmg.duration = 1
			e_double_dmg.description = "Next attack damage dealt is doubled"
			return [e_double_action, e_double_dmg]

		# Mona – Charged Attack (Water) – Mark
		338:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "Marks enemies"
			return [e_kb, e_burst, e_mark]

		# Nahida – Skill (Nature) – Mark + link + Nature reapply after reaction
		282:
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.duration = 5
			e_mark.description = "Mark and link all enemies for 5 turns"
			var e_reapply = GameEffect.new()
			e_reapply.trigger = "ON_REACTION"
			e_reapply.effect_type = "REAPPLY_ELEMENT"
			e_reapply.effect_element = "Nature"
			e_reapply.target = "TARGET"
			e_reapply.duration = 5
			e_reapply.description = "After Nature reaction, Nature reapplied to linked enemies"
			return [e_mark, e_reapply]

		# Nahida – Charged Attack (Nature) – Mark
		294:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "Marks enemies"
			return [e_kb, e_burst, e_mark]

		# Nahida – Burst (Nature) – Shrine of Maya
		300:
			var e_em = EffectBuilder.stat_bonus("Elemental_Mastery", 5.0, "PASSIVE", 3, "Allies gain +5 to EM rolls")
			e_em.target = "ALL_ALLIES"
			var e_react_dmg = GameEffect.new()
			e_react_dmg.trigger = "ON_REACTION"
			e_react_dmg.effect_type = "FLAT_DAMAGE"
			e_react_dmg.effect_value = 6.0
			e_react_dmg.condition = "ELEMENT_MATCH"
			e_react_dmg.condition_value = "Nature"
			e_react_dmg.duration = 3
			e_react_dmg.description = "Nature reactions deal +6 damage or +3 extra healing"
			return [e_em, e_react_dmg]

		# Nilou – Skill (Water) – Water reapply + Dance of Haftkarsvar
		256:
			var e_reapply = EffectBuilder.reapply_element("Water", "ALL_ENEMIES", 2, "Water passively reapplied to enemies within 5 tiles")
			return [e_reapply]

		# Nilou – Burst (Water) – Domain of flowing waters
		283:
			var e_heal = GameEffect.new()
			e_heal.trigger = "ON_REACTION"
			e_heal.effect_type = "HEAL"
			e_heal.effect_dice = "2d8"
			e_heal.target = "ALL_ALLIES"
			e_heal.duration = 2
			e_heal.description = "Nature + Water triggers twice healing for 2d8"
			return [e_heal]

		# Raiden Shogun – Skill (Electric) – Eye of Stormy Judgement
		366:
			var e_follow = GameEffect.new()
			e_follow.trigger = "ON_HIT"
			e_follow.effect_type = "FLAT_DAMAGE"
			e_follow.effect_dice = "1d6"
			e_follow.effect_element = "Electric"
			e_follow.target = "ALL_ALLIES"
			e_follow.duration = 6
			e_follow.description = "After every ally attack, eye does follow up 1d6 electric damage"
			return [e_follow]

		# Raiden Shogun – Burst (Electric) – Musou Isshin state
		290:
			var e_charge_share = GameEffect.new()
			e_charge_share.trigger = "PASSIVE"
			e_charge_share.effect_type = "BURST_CHARGE_GAIN"
			e_charge_share.target = "ALL_ALLIES"
			e_charge_share.duration = 4
			e_charge_share.description = "Burst charges anyone generates also generated for everyone"
			var e_resolve = GameEffect.new()
			e_resolve.trigger = "ON_BURST_USE"
			e_resolve.effect_type = "STAT_BONUS"
			e_resolve.effect_stat = "resolve_stacks"
			e_resolve.effect_value = 1.0
			e_resolve.max_stacks = 4
			e_resolve.duration = 4
			e_resolve.description = "Each ally burst gives 1 resolve stack, multiplying burst damage"
			return [e_charge_share, e_resolve]

		# Razor – Skill (Electric) – Just damage
		339:
			return []

		# Razor – Burst (Electric) – Wolf within
		325:
			var e_double = GameEffect.new()
			e_double.trigger = "PASSIVE"
			e_double.effect_type = "DOUBLE_ACTION"
			e_double.duration = 1
			e_double.description = "Take 2 actions per turn"
			var e_elem = EffectBuilder.apply_element("Electric", "SELF", 1, "Physical attacks converted to elemental")
			return [e_double, e_elem]

		# Sangonomiya Kokomi – Skill (Water) – Bake-Kurage summon
		296:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.duration = 3
			e_summon.description = "Summon Bake-Kurage for follow up water attacks"
			var e_heal = GameEffect.new()
			e_heal.trigger = "ON_HIT"
			e_heal.effect_type = "HEAL_PERCENT_DEALT"
			e_heal.effect_value = 0.25
			e_heal.target = "SELF"
			e_heal.duration = 3
			e_heal.description = "Attacking ally healed for 1/4 damage dealt by Bake-Kurage"
			return [e_summon, e_heal]

		# Sangonomiya Kokomi – Charged Attack (Water) – knockback + burst
		336:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Sangonomiya Kokomi – Burst (Water) – Ceremonial state
		327:
			var e_move = GameEffect.new()
			e_move.trigger = "PASSIVE"
			e_move.effect_type = "MOVEMENT_BONUS"
			e_move.effect_value = 7.0
			e_move.duration = 4
			e_move.description = "Move up to 7 tiles before any action"
			var e_double = GameEffect.new()
			e_double.trigger = "ON_CHARGED_HIT"
			e_double.effect_type = "PERCENT_DAMAGE"
			e_double.effect_value = 2.0
			e_double.duration = 4
			e_double.description = "Charged attacks deal double damage"
			var e_heal = EffectBuilder.heal_percent_dealt(0.25, "Allies healed for 1/4 charged attack damage")
			e_heal.target = "ALL_ALLIES"
			e_heal.duration = 4
			return [e_move, e_double, e_heal]

		# Shenhe – Skill (Ice) – Icy quills follow-up
		259:
			var e_follow = GameEffect.new()
			e_follow.trigger = "ON_HIT"
			e_follow.effect_type = "FLAT_DAMAGE"
			e_follow.effect_element = "Ice"
			e_follow.target = "ALL_ALLIES"
			e_follow.duration = 2
			e_follow.description = "Icy quills do follow up equal ice damage on ally attacks"
			var e_burst = GameEffect.new()
			e_burst.trigger = "ON_HIT"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_value = 1.0
			e_burst.description = "Shenhe gains 1 burst charge per quill attack"
			return [e_follow, e_burst]

		# Shenhe – Burst (Physical/Ice) – Icy field + DoT + extra damage
		341:
			var e_dot = GameEffect.new()
			e_dot.trigger = "START_OF_TURN"
			e_dot.effect_type = "DOT"
			e_dot.value_is_percent_of = "Elemental_Mastery"
			e_dot.effect_element = "Ice"
			e_dot.target = "ALL_ENEMIES"
			e_dot.duration = 3
			e_dot.description = "All enemies take 1 Avg EM roll at start of Shenhe's turn"
			var e_extra_dmg = GameEffect.new()
			e_extra_dmg.trigger = "PASSIVE"
			e_extra_dmg.effect_type = "FLAT_DAMAGE"
			e_extra_dmg.effect_dice = "1d4"
			e_extra_dmg.effect_element = "Ice"
			e_extra_dmg.target = "ALL_ENEMIES"
			e_extra_dmg.duration = 3
			e_extra_dmg.description = "Enemies take extra ice and physical damage equal to 1d4 rolled on cast"
			return [e_dot, e_extra_dmg]

		# Tartaglia – Skill (Water) – Riptide + dash slash
		288:
			var e_riptide = GameEffect.new()
			e_riptide.trigger = "ON_HIT"
			e_riptide.effect_type = "APPLY_STATUS"
			e_riptide.target = "TARGET"
			e_riptide.duration = -1
			e_riptide.description = "Passively apply Riptide causing 1d4 extra water damage on next hit"
			return [e_riptide]

		# Tartaglia – Burst (Water) – Arrow barrage with Riptide
		293:
			var e_riptide = GameEffect.new()
			e_riptide.trigger = "ON_HIT"
			e_riptide.effect_type = "APPLY_STATUS"
			e_riptide.target = "TARGET"
			e_riptide.description = "Each arrow applies Riptide"
			return [e_riptide]

		# Thoma – Skill (Fire) – Shield on allies
		305:
			var e_shield = GameEffect.new()
			e_shield.trigger = "PASSIVE"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.effect_value = 0.125
			e_shield.value_is_percent_of = "max_health"
			e_shield.target = "ALL_ALLIES"
			e_shield.duration = 2
			e_shield.description = "Shield on all allies within 5 tiles (1/8 avg max HP)"
			var e_elem = EffectBuilder.reapply_element("Fire", "ALL_ALLIES", 2, "While shielded fire continuously reapplied")
			return [e_shield, e_elem]

		# Thoma – Burst (Fire) – Stronger shield on all allies
		371:
			var e_shield = GameEffect.new()
			e_shield.trigger = "PASSIVE"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.effect_value = 0.25
			e_shield.value_is_percent_of = "max_health"
			e_shield.target = "ALL_ALLIES"
			e_shield.duration = 2
			e_shield.description = "Shield on all allies (1/4 avg max HP)"
			var e_elem = EffectBuilder.reapply_element("Fire", "ALL_ALLIES", 2, "While shielded fire continuously reapplied")
			var e_extend = GameEffect.new()
			e_extend.trigger = "ON_HIT"
			e_extend.effect_type = "EXTEND_SHIELD"
			e_extend.effect_value = 2.0
			e_extend.target = "SELF"
			e_extend.description = "On attack, extend shield 1 turn and restore 2 HP (max 3 turn extension)"
			return [e_shield, e_elem, e_extend]

		# Tighnari – Skill (Nature) – Vine shot + homing follow-up
		348:
			var e_follow = GameEffect.new()
			e_follow.trigger = "ON_HIT"
			e_follow.effect_type = "REPEAT_ATTACK"
			e_follow.effect_value = 1.0
			e_follow.effect_element = "Nature"
			e_follow.description = "Next ally elemental hit triggers homing vineshot for 2 Nature damage"
			var e_reapply = GameEffect.new()
			e_reapply.trigger = "ON_REACTION"
			e_reapply.effect_type = "REAPPLY_ELEMENT"
			e_reapply.effect_element = "Nature"
			e_reapply.target = "TARGET"
			e_reapply.description = "Reapply Nature after any reactions"
			return [e_follow, e_reapply]

		# Tighnari – Burst (Nature) – Empowered bolt + 2 homing shots
		360:
			var e_chain = GameEffect.new()
			e_chain.trigger = "ON_HIT"
			e_chain.effect_type = "CHAIN_DAMAGE"
			e_chain.effect_element = "Nature"
			e_chain.description = "Bolt erupts into 2 homing shots at closest enemies"
			return [e_chain]

		# Venti – Skill (Wind) – Just damage
		342:
			return []

		# Venti – Burst (Wind) – Vacuum pull
		274:
			return []  # Pull mechanic handled in targeting logic

		# Wanderer – Skill (Wind) – Reposition allies
		361:
			return []  # Repositioning handled in targeting logic

		# Wanderer – Charged Attack (Wind) – Mark
		289:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "Marks enemies"
			return [e_kb, e_burst, e_mark]

		# Wanderer – Burst (Wind) – Conditional element effects
		310:
			return []  # Element-conditional effects resolved in logic

		# Xiangling – Skill (Fire) – Gouba summon
		351:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.description = "Throw Gouba who spits fire at closest enemy"
			var e_ally_buff = GameEffect.new()
			e_ally_buff.trigger = "ON_HIT"
			e_ally_buff.effect_type = "FLAT_DAMAGE"
			e_ally_buff.effect_value = 4.0
			e_ally_buff.target = "ALL_ALLIES"
			e_ally_buff.description = "Allies hit by Gouba fire add 4 to next attack"
			return [e_summon, e_ally_buff]

		# Xiangling – Burst (Fire) – Fire ring DoT
		350:
			var e_dot = GameEffect.new()
			e_dot.trigger = "PASSIVE"
			e_dot.effect_type = "DOT_PER_ACTION"
			e_dot.effect_element = "Fire"
			e_dot.target = "ALL_ENEMIES"
			e_dot.duration = 3
			e_dot.description = "Enemies on fire ring damaged after every action for 3 turns"
			return [e_dot]

		# Xiao – Skill (Wind) – Dash x3 knockback
		362:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back enemies 1 tile"
			var e_repeat = GameEffect.new()
			e_repeat.trigger = "PASSIVE"
			e_repeat.effect_type = "REPEAT_ATTACK"
			e_repeat.effect_value = 3.0
			e_repeat.description = "Dash up to 3 times"
			return [e_kb, e_repeat]

		# Xiao – Burst (Wind) – Double charged attack for 3 turns
		353:
			var e_double = GameEffect.new()
			e_double.trigger = "PASSIVE"
			e_double.effect_type = "DOUBLE_ACTION"
			e_double.duration = 3
			e_double.description = "Can use charged attack up to twice per turn"
			return [e_double]

		# Xingqui – Skill (Water) – Upward slash
		273:
			return []  # Just damage

		# Xingqui – Burst (Water) – Swords ring
		363:
			var e_dr = GameEffect.new()
			e_dr.trigger = "PASSIVE"
			e_dr.effect_type = "DAMAGE_REDUCTION"
			e_dr.effect_value = 0.5
			e_dr.target = "ALL_ALLIES"
			e_dr.description = "Damage from opponents cut in half (removes 1 sword per hit)"
			var e_elem = EffectBuilder.apply_element("Water", "SELF", -1, "Converts charged attacks to water damage")
			return [e_dr, e_elem]

		# Yelan – Skill (Water) – Dash + mark + damage
		367:
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "Enemies passed through are marked"
			return [e_mark]

		# Yelan – Burst (Water) – Depth-Clarion Dice
		364:
			var e_follow = GameEffect.new()
			e_follow.trigger = "ON_HIT"
			e_follow.effect_type = "FLAT_DAMAGE"
			e_follow.effect_element = "Water"
			e_follow.target = "ALL_ALLIES"
			e_follow.duration = 2
			e_follow.description = "On attack, water damage added dealing avg max HP roll"
			return [e_follow]

		# Yoimiya – Skill (Fire) – Fire charged attacks + double charges
		346:
			var e_elem = EffectBuilder.apply_element("Fire", "SELF", 2, "Charged attacks deal fire damage for 2 turns")
			var e_double = GameEffect.new()
			e_double.trigger = "ON_CHARGED_HIT"
			e_double.effect_type = "PERCENT_DAMAGE"
			e_double.effect_value = 2.0
			e_double.duration = 2
			e_double.description = "Charged attacks deal double damage for 2 turns"
			var e_double_charge = GameEffect.new()
			e_double_charge.trigger = "PASSIVE"
			e_double_charge.effect_type = "BURST_CHARGE_GAIN"
			e_double_charge.effect_value = 2.0
			e_double_charge.duration = 2
			e_double_charge.description = "Double burst charges for 2 turns"
			return [e_elem, e_double, e_double_charge]

		# Yoimiya – Burst (Fire) – Firework + mark
		365:
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.duration = 3
			e_mark.description = "Mark one enemy for 3 turns"
			var e_follow = GameEffect.new()
			e_follow.trigger = "ON_HIT"
			e_follow.effect_type = "FLAT_DAMAGE"
			e_follow.effect_element = "Fire"
			e_follow.target = "ALL_ALLIES"
			e_follow.duration = 3
			e_follow.description = "Allies attacking marked enemy deal extra fire damage"
			return [e_mark, e_follow]

		# Yae Miko – Skill (Electric) – Turret placement
		340:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.duration = 2
			e_summon.description = "Leave behind electrical turrets that attack enemies within 5 tiles"
			return [e_summon]

		# Yae Miko – Burst (Electric) – Explode turrets + respawn
		357:
			return []  # Turret explosion handled in logic

		# Yae Miko – Charged Attack (Electric) – knockback + burst
		356:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Yaoyao – Skill (Nature) – Yuegui summon + heal
		265:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.duration = 2
			e_summon.description = "Summon Yuegui that heals allies and damages enemies"
			var e_heal = GameEffect.new()
			e_heal.trigger = "ON_HIT"
			e_heal.effect_type = "HEAL"
			e_heal.effect_value = 1.0
			e_heal.target = "ALL_ALLIES"
			e_heal.duration = 2
			e_heal.description = "Yuegui heals ally for 1 health on their attack"
			return [e_summon, e_heal]

		# Yaoyao – Burst (Nature) – Skip around healing
		315:
			var e_heal = GameEffect.new()
			e_heal.trigger = "PASSIVE"
			e_heal.effect_type = "HEAL"
			e_heal.target = "ALL_ALLIES"
			e_heal.description = "Heals allies within 5 tiles at each tile skipped"
			return [e_heal]

		# Yun Jin – Skill (Earth) – Shield on non-earth allies
		368:
			var e_shield = GameEffect.new()
			e_shield.trigger = "PASSIVE"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.effect_value = 0.25
			e_shield.value_is_percent_of = "defense"
			e_shield.target = "ALL_ALLIES"
			e_shield.duration = -1
			e_shield.description = "Shield on non-earth allies (1/4 Avg Defense Roll, no expiration)"
			return [e_shield]

		# Yun Jin – Burst (Earth) – Normal attack damage buff
		272:
			var e_buff = GameEffect.new()
			e_buff.trigger = "ON_NORMAL_HIT"
			e_buff.effect_type = "FLAT_DAMAGE"
			e_buff.effect_value = 0.5
			e_buff.value_is_percent_of = "defense"
			e_buff.target = "ALL_ALLIES"
			e_buff.duration = 3
			e_buff.description = "Normal attacks deal +1/2 avg defense roll for 3 turns"
			return [e_buff]

		# Zhongli – Skill (Earth) – Shield on allies + earth reapply
		258:
			var e_shield = GameEffect.new()
			e_shield.trigger = "PASSIVE"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.effect_value = 2.0
			e_shield.value_is_percent_of = "Elemental_Mastery"
			e_shield.target = "ALL_ALLIES"
			e_shield.duration = 3
			e_shield.description = "Shield on allies within 3 tiles (2 Avg EM roll)"
			var e_elem = EffectBuilder.reapply_element("Earth", "ALL_ALLIES", 3, "While shielded earth continuously reapplied")
			return [e_shield, e_elem]

		# Zhongli – Burst (Earth) – Planet drop + double damage debuff
		369:
			var e_debuff = GameEffect.new()
			e_debuff.trigger = "ON_HIT"
			e_debuff.effect_type = "PERCENT_DAMAGE"
			e_debuff.effect_value = 2.0
			e_debuff.target = "TARGET"
			e_debuff.duration = 1
			e_debuff.description = "Enemies hit take double damage from any element on next hit"
			return [e_debuff]

		# Albedo – Skill (Earth) – Earthen field + lotus spawns
		307:
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.duration = 2
			e_summon.description = "Earthen field: every other enemy damage spawns earthen lotus"
			return [e_summon]

		# Albedo – Burst (Earth) – Boulder + flowers
		276:
			return []  # Just damage + conditional flower spawn handled in logic

		# Alhaithem – Skill (Nature) – Blink + mirror + follow-up
		319:
			var e_follow = GameEffect.new()
			e_follow.trigger = "ON_CHARGED_HIT"
			e_follow.effect_type = "FLAT_DAMAGE"
			e_follow.effect_dice = "1d8"
			e_follow.effect_element = "Nature"
			e_follow.duration = 3
			e_follow.description = "Mirror does follow up D8 Nature damage on charged attacks"
			return [e_follow]

		# Alhaithem – Burst (Nature) – Triple swipe + mirror refresh
		320:
			return []  # Swipe count doubled by mirror handled in logic

		# Amber – Skill (Fire) – Rain fire arrows
		329:
			return []  # Just AoE damage

		# Amber – Burst (Fire) – Baron bunny taunt + explode
		372:
			var e_taunt = EffectBuilder.taunt(-1, "Taunt all enemies within 4 tiles")
			var e_summon = GameEffect.new()
			e_summon.trigger = "PASSIVE"
			e_summon.effect_type = "SUMMON"
			e_summon.description = "Baron bunny explodes in 3x3 when hit"
			return [e_taunt, e_summon]

		# =====================================================================
		#  DEFAULT WEAPON CHARGED ATTACKS
		# =====================================================================

		# Polearm – Default Charged Attack – knockback + burst charge
		253:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Sword – Default Charged Attack – knockback + burst charge
		266:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Claymore – Default Charged Attack – knockback + burst charge
		260:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# Bow – Default Charged Attack – knockback + burst charge
		275:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back small enemies"
			var e_burst = GameEffect.new()
			e_burst.trigger = "PASSIVE"
			e_burst.effect_type = "BURST_CHARGE_GAIN"
			e_burst.effect_dice = "1d4"
			e_burst.description = "Gain 1d4 burst charges"
			return [e_kb, e_burst]

		# =====================================================================
		#  SIGNIFICANT ENEMY ABILITIES
		# =====================================================================

		# Judgment Seal – Mark lowest HP for guaranteed crit
		3:
			var e_mark = GameEffect.new()
			e_mark.trigger = "ON_HIT"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "TARGET"
			e_mark.description = "Marks lowest HP; next hit is guaranteed crit"
			var e_crit = GameEffect.new()
			e_crit.trigger = "PASSIVE"
			e_crit.effect_type = "CRIT_THRESHOLD"
			e_crit.effect_value = -99.0
			e_crit.target = "TARGET"
			e_crit.duration = 1
			e_crit.description = "Next hit vs marked target is guaranteed crit"
			return [e_mark, e_crit]

		# Stillness Cage – Tile damage
		5:
			var e_dot = GameEffect.new()
			e_dot.trigger = "PASSIVE"
			e_dot.effect_type = "DOT_PER_ACTION"
			e_dot.effect_dice = "1d8"
			e_dot.duration_actions = 99
			e_dot.duration = 1
			e_dot.description = "Standing on locked tiles deals 1d8 at end of action"
			return [e_dot]

		# Still Thunder – Silence skill on failed defense
		8:
			var e_silence = GameEffect.new()
			e_silence.trigger = "ON_HIT"
			e_silence.effect_type = "DISARM"
			e_silence.target = "TARGET"
			e_silence.duration = 1
			e_silence.description = "On failed defense, cannot use Skill next turn"
			return [e_silence]

		# Raiden's Will – Burst charge drain + Overcharged
		12:
			var e_drain = GameEffect.new()
			e_drain.trigger = "PASSIVE"
			e_drain.effect_type = "BURST_CHARGE_LOSE"
			e_drain.effect_dice = "2d4"
			e_drain.target = "TARGET"
			e_drain.description = "Target loses 2d4 burst charges"
			var e_overcharge = GameEffect.new()
			e_overcharge.trigger = "PASSIVE"
			e_overcharge.effect_type = "PREVENT_ELEMENT"
			e_overcharge.target = "TARGET"
			e_overcharge.duration = 1
			e_overcharge.description = "Overcharged: next reaction does not apply their element"
			return [e_drain, e_overcharge]

		# Whip of Flame – DoT on platforms
		19:
			var e_dot = GameEffect.new()
			e_dot.trigger = "END_OF_TURN"
			e_dot.effect_type = "DOT"
			e_dot.effect_dice = "1d4"
			e_dot.effect_element = "Fire"
			e_dot.target = "TARGET"
			e_dot.description = "Platforms become ignited: 1d4 Pyro DoT at end of each round"
			return [e_dot]

		# Scarlet Maelstrom – Scorched platforms
		17:
			var e_dot = GameEffect.new()
			e_dot.trigger = "END_OF_TURN"
			e_dot.effect_type = "DOT"
			e_dot.effect_dice = "1d4"
			e_dot.effect_element = "Fire"
			e_dot.target = "TARGET"
			e_dot.description = "Platforms become Scorched: 1d4 Pyro DoT at end of each round"
			return [e_dot]

		# Cryo Whip – Frostbitten platforms
		15:
			var e_dot = GameEffect.new()
			e_dot.trigger = "END_OF_TURN"
			e_dot.effect_type = "DOT"
			e_dot.effect_dice = "1d4"
			e_dot.effect_element = "Ice"
			e_dot.target = "TARGET"
			e_dot.description = "Platforms become Frostbitten: 1d4 Cryo DoT at end of each round"
			return [e_dot]

		# Frostbinding Veil – Mark + Cryo DoT + Frozen tile
		13:
			var e_dot = GameEffect.new()
			e_dot.trigger = "END_OF_TURN"
			e_dot.effect_type = "DOT"
			e_dot.effect_dice = "1d4"
			e_dot.effect_element = "Ice"
			e_dot.target = "TARGET"
			e_dot.description = "Marked player takes 1d4 Cryo each round"
			var e_debuff = GameEffect.new()
			e_debuff.trigger = "PASSIVE"
			e_debuff.effect_type = "FLAT_DAMAGE"
			e_debuff.effect_value = 2.0
			e_debuff.target = "TARGET"
			e_debuff.condition = "HAS_STATUS"
			e_debuff.condition_value = "Frozen"
			e_debuff.description = "If not moving: +2 dmg from all attacks"
			return [e_dot, e_debuff]

		# Tree's Malice – Damage per action, cannot be shielded
		42:
			var e_dot = EffectBuilder.dot_per_action(1.0, 99, "Each player takes 1 damage per action (cannot be shielded)")
			e_dot.target = "ALL_ENEMIES"
			return [e_dot]

		# Dark Leap – Mark that explodes if not cleared
		52:
			var e_mark = GameEffect.new()
			e_mark.trigger = "PASSIVE"
			e_mark.effect_type = "APPLY_STATUS"
			e_mark.target = "ALL_ENEMIES"
			e_mark.description = "Marks all players; clear by stepping on arena edge or explodes for 1d20"
			return [e_mark]

		# Fire Ball – Burning residue DoT per action
		182:
			var e_dot = EffectBuilder.dot_per_action(1.0, 99, "Tiles deal 1 fire damage per action until fight end")
			e_dot.effect_element = "Fire"
			e_dot.duration = -1
			return [e_dot]

		# Healing Tinders – Enemy self-heal
		183:
			var e_heal = GameEffect.new()
			e_heal.trigger = "START_OF_TURN"
			e_heal.effect_type = "HEAL"
			e_heal.effect_value = 5.0
			e_heal.target = "SELF"
			e_heal.duration = -1
			e_heal.description = "Tinders heal boss 5 HP each turn until destroyed"
			return [e_heal]

		# Healing Thunder – Instant self-heal
		185:
			var e_heal = GameEffect.new()
			e_heal.trigger = "PASSIVE"
			e_heal.effect_type = "HEAL"
			e_heal.effect_value = 0.5
			e_heal.value_is_percent_of = "max_health"
			e_heal.target = "SELF"
			e_heal.description = "Instantly heals 50% of missing HP"
			return [e_heal]

		# Blazing Tinders – Area DoT per action
		184:
			var e_dot = EffectBuilder.dot_per_action(2.0, 99, "Players within 2 tiles take 2 fire damage per action")
			e_dot.effect_element = "Fire"
			return [e_dot]

		# Molten Pillars – Adjacent DoT per action
		180:
			var e_dot = EffectBuilder.dot_per_action(1.0, 99, "Adjacent units take 1 fire damage per action")
			e_dot.effect_element = "Fire"
			return [e_dot]

		# Crushing Clap – Stun
		465:
			var e_stun = EffectBuilder.skip_turn(1, "Stuns target for 1 round")
			e_stun.target = "TARGET"
			return [e_stun]

		# Taunt (Maguu Kenki)
		165:
			var e_taunt = GameEffect.new()
			e_taunt.trigger = "ON_HIT"
			e_taunt.effect_type = "TAUNT"
			e_taunt.target = "TARGET"
			e_taunt.duration = 1
			e_taunt.description = "Taunted players move toward Kenki"
			return [e_taunt]

		# Spinning Arm Sweep – Knockback
		463:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back smaller enemies"
			return [e_kb]

		# Jump Slam – Knockback
		466:
			var e_kb = GameEffect.new()
			e_kb.trigger = "ON_HIT"
			e_kb.effect_type = "KNOCKBACK"
			e_kb.effect_value = 1.0
			e_kb.target = "TARGET"
			e_kb.description = "Knock back those hit 1 tile"
			return [e_kb]

		# Spiritwind Storm – DoT per action
		137:
			var e_dot = EffectBuilder.dot_per_action(0, 99, "Tornados deal 1d4 per action until exited")
			e_dot.effect_dice = "1d4"
			return [e_dot]

		# Rifthound Skulls – Boss shield
		152:
			var e_shield = GameEffect.new()
			e_shield.trigger = "PASSIVE"
			e_shield.effect_type = "SHIELD_GENERATE"
			e_shield.target = "SELF"
			e_shield.description = "Boss gains shield until skulls destroyed"
			return [e_shield]

		# Bubble Support – Boss heal
		154:
			var e_heal = GameEffect.new()
			e_heal.trigger = "PASSIVE"
			e_heal.effect_type = "HEAL"
			e_heal.effect_value = 0.33
			e_heal.value_is_percent_of = "max_health"
			e_heal.target = "SELF"
			e_heal.description = "If droplet reaches boss, heals 33% max HP"
			return [e_heal]

		# Caelestinum Finale Termini – Platform corruption
		63:
			var e_dot = GameEffect.new()
			e_dot.trigger = "END_OF_TURN"
			e_dot.effect_type = "DOT"
			e_dot.effect_dice = "1d6"
			e_dot.target = "TARGET"
			e_dot.description = "Abyssal Corruption: 1d6 damage at end of occupant's turn (persists)"
			return [e_dot]

		# =====================================================================
		#  TEST DUMMY ABILITIES (ID 100)
		# =====================================================================

		# Test Dummy – Passive: Fire Aura (START_OF_TURN DOT to all nearby)
		507:
			var e_aura = GameEffect.new()
			e_aura.trigger = "START_OF_TURN"
			e_aura.effect_type = "FLAT_DAMAGE"
			e_aura.effect_value = 2.0
			e_aura.effect_element = "Fire"
			e_aura.target = "ALL_ENEMIES"
			e_aura.duration = -1  # permanent
			e_aura.description = "Fire Aura: 2 flat Fire damage to all nearby at turn start"
			return [e_aura]

	return []
