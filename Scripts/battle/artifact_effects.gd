class_name ArtifactEffects extends RefCounted
## Maps artifact set names + bonus type to their structured GameEffect arrays.
## Every artifact set bonus gets effects — even simple stat bonuses — so they're
## visible in the .tres inspector and available to the effect processor.

static func get_effects(set_name: String, bonus_type: int) -> Array:
	var key = set_name + "|" + str(bonus_type)
	match key:
		# ══════════════════════════════════════════════════════════════════
		# 2-PIECE BONUSES
		# ══════════════════════════════════════════════════════════════════
		"Archaic Petra|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 to all Earth damage rolls.")]
		"Crimson Witch of Flames|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 to all Fire damage rolls.")]
		"Thundering Fury|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 damage to all Electric attacks that hit.")]
		"Blizzard Strayer|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 damage to all Ice attacks that hit.")]
		"Viridescent Venerer|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 to all Wind damage rolls.")]
		"Heart of Depth|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 damage to all Water/Ice attacks that hit.")]
		"Pale Flame|2":
			return [EffectBuilder.stat_bonus("Attack_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 to all Physical damage rolls.")]
		"Bloodstained Chivalry|2":
			return [EffectBuilder.stat_bonus("Attack_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 to all Physical damage rolls.")]
		"Nymphs Dream|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 damage to all Water attacks that hit.")]
		"Desert Pavilion Chronicle|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 damage to all Wind attacks that hit.")]
		"Deepwood Memories|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Damage_Bonus", 2.0, "PASSIVE", -1, "+2 damage to all Nature attacks that hit.")]
		"Wanderers Troupe|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Stat_Bonus", 2.0, "PASSIVE", -1, "+2 Elemental Mastery.")]
		"Gilded Dreams|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Stat_Bonus", 2.0, "PASSIVE", -1, "+2 Elemental Mastery.")]
		"Flower of Paradise Lost|2":
			return [EffectBuilder.stat_bonus("Elemental_Mastery_Added_Stat_Bonus", 2.0, "PASSIVE", -1, "+2 Elemental Mastery.")]
		"Gladiators Finale|2":
			return [EffectBuilder.stat_bonus("Attack_Added_Stat_Bonus", 2.0, "PASSIVE", -1, "+2 Attack.")]
		"Shimenawas Reminiscence|2":
			return [EffectBuilder.stat_bonus("Attack_Added_Stat_Bonus", 2.0, "PASSIVE", -1, "+2 Attack.")]
		"Vermillion Hereafter|2":
			return [EffectBuilder.stat_bonus("Attack_Added_Stat_Bonus", 2.0, "PASSIVE", -1, "+2 Attack.")]
		"Echoes of an Offering|2":
			return [EffectBuilder.stat_bonus("Attack_Added_Stat_Bonus", 2.0, "PASSIVE", -1, "+2 Attack.")]
		"Tenacity of the Millelith|2":
			return [EffectBuilder.stat_multiplier("Health", 0.2, "HP increased by 20%.")]
		"Vourukashas Glow|2":
			return [EffectBuilder.stat_multiplier("Health", 0.2, "HP increased by 20%.")]
		"Husk of Opulent Dreams|2":
			return [EffectBuilder.stat_bonus("Defense_Added_Stat_Bonus", 2.0, "PASSIVE", -1, "+2 Defense.")]
		"Emblem of Severed Fate|2":
			return [EffectBuilder.stat_bonus("Energy_Recharge_Added_Stat_Bonus", 0.5, "PASSIVE", -1, "+0.5 Energy Recharge.")]
		"Maiden Beloved|2":
			return [_heal_bonus(2.0, "Heals restore 2 extra health.")]
		"Ocean-Hued Clam|2":
			return [_heal_bonus_dice("1d4", 0.5, "Heals restore extra 1/2 D4 health.")]
		"Retracing Bolide|2":
			return [_shield_extra_hit("Non-earth elemental shields take one extra hit before breaking.")]
		"Thundersoother|2":
			return [_element_damage_reduction("Electric", 0.5, "Electric damage taken reduced by half.")]
		"Lavawalker|2":
			return [_element_damage_reduction("Fire", 0.5, "Fire damage taken reduced by half.")]
		"Noblesse Oblige|2":
			return [_burst_percent_damage(1.5, "Burst damage x1.5.")]

		# ══════════════════════════════════════════════════════════════════
		# 4-PIECE BONUSES
		# ══════════════════════════════════════════════════════════════════
		"Archaic Petra|4":
			return [_on_shield_from_reaction_damage(4.0, "While crystallize shield active, deal +4 damage.")]
		"Crimson Witch of Flames|4":
			return [
				_reaction_element_damage_mult("Fire", 1.5, "Fire reaction damage x1.5."),
				_on_skill_stack_element_bonus("Fire", 2.0, "On skill use, gain D4 stacks. Per stack +2 to fire rolls."),
			]
		"Viridescent Venerer|4":
			return [_on_swirl_extra_turn("On wind swirl reaction, gain another turn (2 turn CD).")]
		"Blizzard Strayer|4":
			return [_element_crit_threshold("Ice", -5.0, "Ice attacks: crit threshold -5.")]
		"Tenacity of the Millelith|4":
			return [_on_skill_ally_damage(0.25, 3, "After skill, all allies deal 25% more damage for 3 turns.")]
		"Bloodstained Chivalry|4":
			return [_on_kill_free_charged("On kill, immediately fire another charged attack at chosen enemy.")]
		"Ocean-Hued Clam|4":
			return [_on_heal_wave_damage("On heal, wave hits nearest enemy for total amount healed.")]
		"Husk of Opulent Dreams|4":
			return [_curiosity_stacks()]
		"Shimenawas Reminiscence|4":
			return [_shimenawa()]
		"Thundering Fury|4":
			return [_extra_burst_charge("Gain 1 extra charge per burst charge gain.")]
		"Wanderers Troupe|4":
			return [_charged_percent_damage(1.5, "Charged attacks deal 50% more damage.")]
		"Retracing Bolide|4":
			return [_shielded_normal_charged_mult(1.5, "While shielded, normal/charged deal 1.5x.")]
		"Thundersoother|4":
			return [_element_damage_immunity("Electric", "Immune to electric attacks.")]
		"Lavawalker|4":
			return [_element_damage_immunity("Fire", "Immune to fire damage.")]
		"Gladiators Finale|4":
			return [_normal_percent_damage(1.5, "Normal attacks deal 50% more damage.")]
		"Maiden Beloved|4":
			return [_on_skill_burst_heal("1d4", 2, "After skill/burst, heal chosen ally within 2 tiles for 1D4.")]
		"Heart of Depth|4":
			return [_on_skill_normal_charged_bonus(2.0, 3, "After skill, normal/charged +2 damage for 3 turns.")]
		"Noblesse Oblige|4":
			return [_on_burst_ally_damage_dice("1d8", "On burst, all allies add 1D8 to next attack damage.")]
		"Emblem of Severed Fate|4":
			return [_burst_er_scaling("Burst damage multiplied by 1 + 25% of ER.")]
		"Deepwood Memories|4":
			return [
				_nature_defense_reduction(4.0, "Nature damage reduces target defense roll by 4."),
				_on_nature_reaction_heal(1.0, "On nature reaction, heal 1 HP."),
			]
		"Vourukashas Glow|4":
			return [
				_skill_burst_flat_damage(2.0, "Skill/Burst damage +2."),
				_if_took_damage_skill_burst_bonus(2.0, "If took damage since last turn, skill/burst +2 more."),
				_on_burst_heal(1.0, "On burst, heal 1 HP."),
			]
		"Vermillion Hereafter|4":
			return [_vermillion()]
		"Pale Flame|4":
			return [_on_burst_physical_advantage(3, "After burst, physical attacks gain advantage for 3 turns.")]
		"Nymphs Dream|4":
			return [_nymphs_dream()]
		"Desert Pavilion Chronicle|4":
			return [_desert_pavilion()]
		"Echoes of an Offering|4":
			return [_echoes()]
		"Gilded Dreams|4":
			return [_gilded_dreams()]
		"Flower of Paradise Lost|4":
			return [_flower_paradise()]
	return []

# ─── Complex effect helpers ──────────────────────────────────────────────────

static func _heal_bonus(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HEAL"; e.effect_type = "HEAL"; e.effect_value = val; e.description = desc; return e

static func _heal_bonus_dice(dice: String, mult: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HEAL"; e.effect_type = "HEAL"; e.effect_dice = dice; e.effect_value = mult; e.description = desc; return e

static func _shield_extra_hit(desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "PASSIVE"; e.effect_type = "SHIELD_BONUS"; e.effect_value = 1.0; e.description = desc; return e

static func _element_damage_reduction(element: String, mult: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_DAMAGE_TAKEN"; e.condition = "ELEMENT_MATCH"; e.condition_value = element; e.effect_type = "DAMAGE_REDUCTION"; e.effect_value = mult; e.description = desc; return e

static func _element_damage_immunity(element: String, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_DAMAGE_TAKEN"; e.condition = "ELEMENT_MATCH"; e.condition_value = element; e.effect_type = "DAMAGE_IMMUNITY"; e.description = desc; return e

static func _burst_percent_damage(mult: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_BURST_HIT"; e.effect_type = "PERCENT_DAMAGE"; e.effect_value = mult; e.description = desc; return e

static func _on_shield_from_reaction_damage(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HIT"; e.condition = "IS_SHIELDED"; e.effect_type = "FLAT_DAMAGE"; e.effect_value = val; e.description = desc; return e

static func _reaction_element_damage_mult(element: String, mult: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_REACTION"; e.condition = "REACTION_ELEMENT"; e.condition_value = element; e.effect_type = "PERCENT_DAMAGE"; e.effect_value = mult; e.description = desc; return e

static func _on_skill_stack_element_bonus(element: String, val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_SKILL_USE"; e.effect_type = "FLAT_DAMAGE"; e.condition = "ELEMENT_MATCH"; e.condition_value = element; e.effect_dice = "1d4"; e.stack_value = val; e.max_stacks = 99; e.duration = -1; e.description = desc; return e

static func _on_swirl_extra_turn(desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_REACTION"; e.condition = "REACTION_ELEMENT"; e.condition_value = "Wind"; e.effect_type = "EXTRA_TURN"; e.duration = 2; e.description = desc; return e

static func _element_crit_threshold(element: String, val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "PASSIVE"; e.condition = "ELEMENT_MATCH"; e.condition_value = element; e.effect_type = "CRIT_THRESHOLD"; e.effect_value = val; e.description = desc; return e

static func _on_skill_ally_damage(mult: float, dur: int, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_SKILL_USE"; e.effect_type = "PERCENT_DAMAGE"; e.effect_value = 1.0 + mult; e.target = "ALL_ALLIES"; e.duration = dur; e.description = desc; return e

static func _on_kill_free_charged(desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_KILL"; e.effect_type = "EXTRA_ACTION"; e.condition = "ATTACK_TYPE"; e.condition_value = "Charged"; e.description = desc; return e

static func _on_heal_wave_damage(desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HEAL"; e.effect_type = "CHAIN_DAMAGE"; e.value_is_percent_of = "damage_dealt"; e.effect_value = 1.0; e.target = "CLOSEST_ENEMY"; e.description = desc; return e

static func _curiosity_stacks() -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HIT"; e.effect_type = "FLAT_DAMAGE"; e.stack_value = 1.0; e.max_stacks = 4; e.duration = -1; e.description = "On hit/being hit gain curiosity (max 4). Per stack +1 damage to defense-based and earth attacks."; return e

static func _shimenawa() -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HIT"; e.condition = "BURST_CHARGES_ABOVE"; e.condition_value = "50%"; e.effect_type = "PERCENT_DAMAGE"; e.effect_value = 2.0; e.description = "At 50%+ burst charges, spend half to double next normal/charged damage."; return e

static func _extra_burst_charge(desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "PASSIVE"; e.effect_type = "BURST_CHARGE_GAIN"; e.effect_value = 1.0; e.description = desc; return e

static func _charged_percent_damage(mult: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_CHARGED_HIT"; e.effect_type = "PERCENT_DAMAGE"; e.effect_value = mult; e.description = desc; return e

static func _normal_percent_damage(mult: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_NORMAL_HIT"; e.effect_type = "PERCENT_DAMAGE"; e.effect_value = mult; e.description = desc; return e

static func _shielded_normal_charged_mult(mult: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HIT"; e.condition = "IS_SHIELDED"; e.effect_type = "PERCENT_DAMAGE"; e.effect_value = mult; e.description = desc; return e

static func _on_skill_burst_heal(dice: String, range_tiles: int, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_SKILL_USE"; e.effect_type = "HEAL"; e.effect_dice = dice; e.target = "ALL_ALLIES"; e.description = desc; return e

static func _on_skill_normal_charged_bonus(val: float, dur: int, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_SKILL_USE"; e.effect_type = "FLAT_DAMAGE"; e.effect_value = val; e.duration = dur; e.description = desc; return e

static func _on_burst_ally_damage_dice(dice: String, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_BURST_USE"; e.effect_type = "FLAT_DAMAGE"; e.effect_dice = dice; e.target = "ALL_ALLIES"; e.duration = 1; e.description = desc; return e

static func _burst_er_scaling(desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_BURST_HIT"; e.effect_type = "PERCENT_DAMAGE"; e.effect_value = 0.25; e.value_is_percent_of = "energy_recharge"; e.description = desc; return e

static func _nature_defense_reduction(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HIT"; e.condition = "ELEMENT_MATCH"; e.condition_value = "Nature"; e.effect_type = "DEFENSE_REDUCTION"; e.effect_value = val; e.target = "TARGET"; e.description = desc; return e

static func _on_nature_reaction_heal(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_REACTION"; e.condition = "REACTION_ELEMENT"; e.condition_value = "Nature"; e.effect_type = "HEAL"; e.effect_value = val; e.target = "SELF"; e.description = desc; return e

static func _skill_burst_flat_damage(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_SKILL_HIT"; e.effect_type = "FLAT_DAMAGE"; e.effect_value = val; e.description = desc; return e

static func _if_took_damage_skill_burst_bonus(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_SKILL_HIT"; e.condition = "HAS_STATUS"; e.condition_value = "took_damage_last_turn"; e.effect_type = "FLAT_DAMAGE"; e.effect_value = val; e.description = desc; return e

static func _on_burst_heal(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_BURST_USE"; e.effect_type = "HEAL"; e.effect_value = val; e.target = "SELF"; e.description = desc; return e

static func _vermillion() -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_BURST_USE"; e.effect_type = "STAT_BONUS"; e.effect_stat = "Attack"; e.effect_value = 2.0; e.duration = -1; e.max_stacks = 1; e.description = "Once per battle after burst: +2 ATT rolls, +1 DEF rolls. Self-damage gives +1 ATT (max +3)."; return e

static func _on_burst_physical_advantage(dur: int, desc: String) -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_BURST_USE"; e.effect_type = "ROLL_ADVANTAGE"; e.duration = dur; e.description = desc; return e

static func _nymphs_dream() -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HIT"; e.condition = "ELEMENT_MATCH"; e.condition_value = "Water"; e.effect_type = "STAT_BONUS"; e.effect_stat = "Elemental_Mastery"; e.stack_value = 1.0; e.max_stacks = 3; e.duration = -1; e.description = "First water damage/skill/burst: +1 EM+ATT per stack (max 3). Water attacks +1 range per stack."; return e

static func _desert_pavilion() -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_CHARGED_HIT"; e.effect_type = "FLAT_DAMAGE"; e.effect_value = 2.0; e.duration = 1; e.description = "After charged/skill, next basic/charged +2 to roll, +1 range. Wind attacks +2 damage."; return e

static func _echoes() -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_HIT"; e.condition = "DICE_ROLL_CHECK"; e.condition_value = "11+"; e.effect_type = "REPEAT_ATTACK"; e.effect_value = 0.5; e.effect_dice = "1d20"; e.description = "On normal/charged hit, D20 roll 11+: repeat damage one die step smaller (min D4). Once/turn."; return e

static func _gilded_dreams() -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_REACTION"; e.effect_type = "STAT_BONUS"; e.effect_stat = "Attack"; e.effect_value = 2.0; e.max_stacks = 1; e.duration = -1; e.description = "Once per battle after reaction: +2 ATT+EM rolls. Nature reactions give +1 burst charge."; return e

static func _flower_paradise() -> GameEffect:
	var e = GameEffect.new(); e.trigger = "ON_REACTION"; e.condition = "REACTION_ELEMENT"; e.condition_value = "Nature"; e.effect_type = "FLAT_DAMAGE"; e.effect_value = 4.0; e.description = "Nature applied first reaction: +4 damage or +2 healing."; return e
