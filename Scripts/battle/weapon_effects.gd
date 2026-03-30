class_name WeaponEffects extends RefCounted
## Maps weapon names to their structured GameEffect arrays.
## Called during GameDB loading to populate weapon.effects arrays.

static func get_effects(weapon_name: String) -> Array:
	match weapon_name:
		# ── LEGENDARY ────────────────────────────────────────────────────
		"Skyward Spine":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				EffectBuilder.on_crit_flat_damage(2.0, "Crits deal +2 damage"),
			]
		"Skyward Pride":
			return [EffectBuilder.passive_flat_damage(2.0, "All damage rolls deal +2")]
		"Skyward Blade":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				EffectBuilder.on_crit_flat_damage(2.0, "Crits deal +2 damage"),
			]
		"Skyward Harp":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				EffectBuilder.on_crit_flat_damage(2.0, "Crits deal +2 damage"),
			]
		"Skyward Atlas":
			return [_skill_flat_damage(4.0, "Skill deals +4 damage")]
		"Engulfing Lightning":
			return [
				EffectBuilder.stat_bonus("Attack", 0, "PASSIVE", -1, "ATT/EM increased by ER value"),  # Needs runtime resolution
				_on_burst_stat_bonus("Energy_Recharge", 1.0, 2, "After burst +1.0 ER for 2 turns"),
			]
		"Staff of Homa":
			return [
				EffectBuilder.stat_multiplier("Health", 0.2, "HP increased by 20%"),
				EffectBuilder.percent_of_stat_damage("max_health", 0.1, "ON_HIT", "Attacks add 10% max HP to roll"),
			]
		"Elegy For The End":
			return [EffectBuilder.ally_flat_damage(0, 1, "ON_SKILL_USE", "1d6", "On skill/burst allies add 1D6 to next elemental attack")]
		"Polar Star":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				EffectBuilder.attack_type_stack(4, "STAT_MULTIPLIER", 0.5, "At 4 unique attack type stacks, +50% ATT+EM"),
			]
		"Thundering Pulse":
			return [EffectBuilder.attack_type_stack(4, "PERCENT_DAMAGE", 0.5, "At 4 unique attack type stacks, deal 50% more damage")]
		"Mistsplitter Reforged":
			return [EffectBuilder.attack_type_stack(4, "PERCENT_DAMAGE", 0.5, "At 4 unique attack type stacks, deal 50% more damage")]
		"Aqua Simulacra":
			return [
				EffectBuilder.stat_multiplier("Health", 0.3, "HP increased by 30%"),
				EffectBuilder.passive_percent_damage(1.3, "All damage increased by 30%"),
			]
		"Redhorn Stonethresher":
			return [
				EffectBuilder.stat_multiplier("Defense", 0.25, "Def increased by 25%"),
				EffectBuilder.percent_of_stat_damage("defense", 0.5, "ON_NORMAL_HIT", "Normal/charged +50% def as damage"),
			]
		"Primordial Jade-Winged Spear":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				EffectBuilder.percent_of_stat_damage("current_health", 0.1, "ON_HIT", "Attacks deal +10% current HP"),
			]
		"Primordial Jade Cutter":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				EffectBuilder.percent_of_stat_damage("current_health", 0.1, "ON_HIT", "Attacks deal +10% current HP"),
			]
		"Jadefalls Splendor":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				EffectBuilder.percent_of_stat_damage("current_health", 0.1, "ON_HIT", "Attacks deal +10% current HP"),
			]
		"Summit Shaper", "The Unforged", "Vortex Vanquisher", "Memory of Dust":
			return [
				EffectBuilder.shield_bonus(2.0, "Shields absorb 2 extra damage"),
				_shielded_hit_stack(1.0, 2.0, 3, "On hit +1 dmg (max 3), while shielded +2 per stack"),
			]
		"Calamity Queller":
			return [_calamity_queller()]
		"Everlasting Moonglow":
			return [
				_passive_heal_bonus(1.0, "Heals +1"),
				EffectBuilder.percent_of_stat_damage("max_health", 0.1, "ON_NORMAL_HIT", "Normal attacks +10% max HP"),
				_on_burst_energy_gain("1d4", 2, "After burst, normal hits give 1D4 energy for 2 turns"),
			]
		"Kaguras Verity":
			return [_kagura_stacks()]
		"Song of Broken Pines":
			return [_ally_movement_on_attack("On normal/charged, allies may move their normal tiles")]
		"Freedom-Sworn":
			return [_on_reaction_ally_damage(2.0, 2, "On reaction, all allies deal +2 dmg for 2 turns")]
		"Haran Geppaku Futsu":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				_haran_stacks(),
			]

		# ── EPIC ─────────────────────────────────────────────────────────
		"Favonius Lance", "Favonius Sword", "Favonius Warbow", "Favonius Greatsword", "Favonius Codex":
			return [EffectBuilder.on_crit_burst_full("On crit with normal/charged, gain full burst charges")]
		"Fading Twilight":
			return [EffectBuilder.passive_percent_damage(1.15, "Deal 15% increased damage")]
		"Sacrificial Greatsword", "Sacrificial Bow", "Sacrificial Sword", "Sacrificial Fragments":
			return [EffectBuilder.sacrificial_cooldown_reset("After skill, D20 even = skill cooldown reset")]
		"Prototype Starglitter":
			return [EffectBuilder.on_skill_next_attack_bonus("PERCENT_DAMAGE", 2.0, "After skill, next normal/charged deals double")]
		"Rainslasher":
			return [
				EffectBuilder.conditional_element_damage("Electric", 4.0, "+4 damage if enemy has Electric"),
				EffectBuilder.conditional_element_damage("Water", 4.0, "+4 damage if enemy has Water"),
			]
		"Lions Roar":
			return [
				EffectBuilder.conditional_element_damage("Fire", 4.0, "+4 damage if enemy has Fire"),
				EffectBuilder.conditional_element_damage("Electric", 4.0, "+4 damage if enemy has Electric"),
			]
		"Dragons Bane":
			return [
				EffectBuilder.conditional_element_damage("Fire", 4.0, "+4 damage if enemy has Fire"),
				EffectBuilder.conditional_element_damage("Water", 4.0, "+4 damage if enemy has Water"),
			]
		"The Black Sword":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				EffectBuilder.heal_percent_dealt(0.1, "Heal 10% of damage dealt"),
			]
		"Deathmatch":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				_deathmatch_conditional(),
			]
		"Serpent Spine":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				_serpent_spine_stack(),
			]
		"The Bell":
			return [EffectBuilder.damage_taken_shield(10.0, 1, true, "First hit generates 10hp shield for 1 turn, once per battle")]
		"Royal Greatsword", "Royal Longsword", "Royal Spear", "Royal Bow", "Royal Grimoire":
			return [EffectBuilder.royal_crit_ramp("On non-crit hit, crit threshold -2, resets on crit")]
		"The Flute":
			return [_flute_splash()]
		"Cinnabar Spindle":
			return [EffectBuilder.percent_of_stat_damage("defense", 0.4, "ON_SKILL_HIT", "Skill damage +40% of defense")]
		"Prototype Archaic":
			return [_prototype_archaic()]
		"Akuoumaru", "Wavebreakers Fin", "Mouuns Moon":
			return [_burst_charge_scaling("Burst damage +2% per total party burst charge cost")]
		"Luxurious Sea-Lord":
			return [
				_burst_percent_damage(1.2, "Burst damage +20%"),
				_on_burst_hit_summon("Tuna barrage dealing 100% ATT as water damage"),
			]
		"Predator":
			return [_predator_stacks()]
		"The Stringless":
			return [_skill_burst_flat_damage(2.0, "Skill and Burst damage +2")]
		"Solar Pearl":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				_solar_pearl_stacks(),
			]
		"The Widsith":
			return [_widsith_roll()]
		"Prototype Crescent":
			return [_charged_attack_movement(5, "Charged attack hit: move up to 5 tiles after")]
		"Kagotsurube Isshin":
			return [_kagotsurube()]
		"The Viridescent Hunt":
			return [
				EffectBuilder.crit_threshold(-3.0, "Lower crit threshold by 3"),
				_viridescent_crit_splash(),
			]
		"Prototype Rancour":
			return [EffectBuilder.on_hit_stack("STAT_BONUS", 1.0, 5, -1, "On normal hit +1 Def (max 5)")]
		"The Catch":
			return [
				_burst_percent_damage(1.25, "Burst damage +25%"),
				_burst_crit_threshold(-5.0, "Burst crit threshold -5"),
			]
		"Oathsworn Eye":
			return [_on_skill_stat_bonus("Energy_Recharge", 0.75, 3, "After skill +0.75 ER for 3 turns")]

		# ── RARE ─────────────────────────────────────────────────────────
		"Hakushin Ring":
			return [_on_electric_reaction_ally_damage(0.2, 3, "After electric reaction, all allies deal 20% more damage for 3 turns")]
		"Hamayumi":
			return [_hamayumi()]
		"Kitain Cross Spear", "Katsuragikiri Nagamasa":
			return [_kitain()]
		"Amenoma Kageuchi":
			return [_amenoma()]

		# ── UNCOMMON ─────────────────────────────────────────────────────
		"Blackcliff Slasher", "Blackcliff Longsword", "Blackcliff Warbow", "Blackcliff Pole", "Blackcliff Agate":
			return [
				EffectBuilder.on_kill_extra_turn("On kill, take another turn"),
				EffectBuilder.on_enemy_hit_extra_turn("When enemy hits you, they gain another turn (max 1/turn)"),
			]
		"Wine and Song", "Alley Hunter", "The Alley Flash":
			return [
				EffectBuilder.passive_flat_damage(2.0, "Damage dealt +2"),
				_passive_damage_taken_increase(2.0, "Damage received +2"),
			]
		"Frostbearer", "Dragonspine Spear", "Snow-Tombed Starsilver":
			return [_self_damage_on_attack(1.0, "Normal/Charged attacks cost 1 HP from an ally")]
		"Lithic Blade", "Lithic Spear":
			return [_lithic()]

	return []

# ─── Complex effect helpers ──────────────────────────────────────────────────

static func _skill_flat_damage(value: float, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_HIT"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = value
	e.description = desc
	return e

static func _on_burst_stat_bonus(stat: String, value: float, dur: int, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_BURST_USE"
	e.effect_type = "STAT_BONUS"
	e.effect_stat = stat
	e.effect_value = value
	e.duration = dur
	e.description = desc
	return e

static func _on_skill_stat_bonus(stat: String, value: float, dur: int, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.effect_type = "STAT_BONUS"
	e.effect_stat = stat
	e.effect_value = value
	e.duration = dur
	e.description = desc
	return e

static func _shielded_hit_stack(base_val: float, shielded_val: float, max_s: int, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.effect_type = "FLAT_DAMAGE"
	e.stack_value = base_val  # +1 per stack normally, +2 while shielded checked at runtime
	e.max_stacks = max_s
	e.duration = -1
	e.description = desc
	# The shielded doubling needs runtime check — store extra info in description
	return e

static func _calamity_queller() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.effect_type = "STAT_BONUS"
	e.effect_stat = "Attack"
	e.stack_value = 2.0
	e.max_stacks = 5
	e.duration = -1
	e.description = "On skill use gain 1 stack (max 5). Per stack +2 ATT but crit threshold +2."
	return e

static func _kagura_stacks() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.effect_type = "PERCENT_DAMAGE"
	e.condition = "ATTACK_TYPE"
	e.condition_value = "Skill"
	e.stack_value = 0.5
	e.max_stacks = 3
	e.duration = 3
	e.description = "On skill use gain stack (max 3, 3 turns each). Per stack skill deals 50% more damage."
	return e

static func _serpent_spine_stack() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "START_OF_TURN"
	e.effect_type = "FLAT_DAMAGE"
	e.stack_value = 1.0
	e.max_stacks = 6
	e.duration = -1
	e.description = "Start of turn +1 damage (max 6 stacks), but -1 defense per stack."
	return e

static func _deathmatch_conditional() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.condition = "ENEMY_COUNT_NEARBY"
	e.condition_value = "2+_3tiles"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = 5.0
	e.description = "2+ enemies within 3 tiles: +5 damage +5 defense. Otherwise -5 damage -5 defense."
	return e

static func _flute_splash() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "ATTACK_TYPE"
	e.condition_value = "Normal"
	e.effect_type = "CHAIN_DAMAGE"
	e.effect_value = 0.5
	e.target = "CLOSEST_ENEMY"
	e.description = "Normal/charged hit: closest enemy to target receives half damage."
	return e

static func _prototype_archaic() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "DICE_ROLL_CHECK"
	e.condition_value = "15+"
	e.effect_type = "REPEAT_ATTACK"
	e.effect_value = 1.0
	e.effect_dice = "1d20"
	e.description = "On normal/charged hit, D20 roll 15+: repeat damage."
	return e

static func _burst_percent_damage(mult: float, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_BURST_HIT"
	e.effect_type = "PERCENT_DAMAGE"
	e.effect_value = mult
	e.description = desc
	return e

static func _burst_crit_threshold(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_BURST_USE"
	e.effect_type = "CRIT_THRESHOLD"
	e.effect_value = val
	e.duration = 0  # Only for this burst
	e.description = desc
	return e

static func _burst_charge_scaling(desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_BURST_HIT"
	e.effect_type = "PERCENT_DAMAGE"
	e.effect_value = 0.02  # 2% per charge cost
	e.value_is_percent_of = "total_party_burst_cost"
	e.description = desc
	return e

static func _on_burst_hit_summon(desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_BURST_HIT"
	e.effect_type = "SUMMON"
	e.effect_value = 1.0
	e.value_is_percent_of = "attack"
	e.effect_element = "Water"
	e.description = desc
	return e

static func _predator_stacks() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "ELEMENT_MATCH"
	e.condition_value = "Ice"
	e.effect_type = "PERCENT_DAMAGE"
	e.stack_value = 0.2
	e.max_stacks = 2
	e.duration = 4
	e.description = "On ice damage hit, gain stack (max 2, 4 turns). Per stack normal/charged +20%."
	return e

static func _skill_burst_flat_damage(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_HIT"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = val
	e.description = desc
	# Note: also applies to burst — would need a second effect or combined trigger
	return e

static func _solar_pearl_stacks() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_NORMAL_HIT"
	e.effect_type = "FLAT_DAMAGE"
	e.condition = "ATTACK_TYPE"
	e.condition_value = "Skill"
	e.stack_value = 2.0
	e.max_stacks = 3
	e.description = "Normal attacks increase next skill/burst damage by 2 (max 3 stacks)."
	return e

static func _widsith_roll() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ONCE_PER_BATTLE"
	e.condition = "DICE_ROLL_CHECK"
	e.condition_value = "11+"
	e.effect_type = "STAT_BONUS"
	e.effect_stat = "Elemental_Mastery"
	e.effect_value = 5.0
	e.effect_dice = "1d20"
	e.duration = -1
	e.description = "Start of battle D20: ≤10 → +5 ATT, >10 → +5 EM."
	return e

static func _charged_attack_movement(tiles: int, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_CHARGED_HIT"
	e.effect_type = "MOVEMENT_BONUS"
	e.effect_value = float(tiles)
	e.description = desc
	return e

static func _kagotsurube() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "ATTACK_TYPE"
	e.condition_value = "Normal"
	e.effect_type = "SUMMON"
	e.effect_value = 1.0
	e.value_is_percent_of = "attack"
	e.effect_element = "Wind"
	e.duration = 2  # 2 turn cooldown
	e.description = "On normal/charged hit, summon galing wind (2 turn CD) 3x3 dealing 100% ATT as wind."
	return e

static func _viridescent_crit_splash() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_CRIT"
	e.effect_type = "CHAIN_DAMAGE"
	e.effect_value = 0.5
	e.target = "CLOSEST_ENEMY"
	e.description = "On crit, deal half damage to closest enemy of target."
	return e

static func _on_electric_reaction_ally_damage(mult: float, dur: int, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_REACTION"
	e.condition = "REACTION_ELEMENT"
	e.condition_value = "Electric"
	e.effect_type = "PERCENT_DAMAGE"
	e.effect_value = 1.0 + mult
	e.target = "ALL_ALLIES"
	e.duration = dur
	e.description = desc
	return e

static func _on_reaction_ally_damage(val: float, dur: int, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_REACTION"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = val
	e.target = "ALL_ALLIES"
	e.duration = dur
	e.description = desc
	return e

static func _hamayumi() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "ATTACK_TYPE"
	e.condition_value = "Normal"
	e.effect_type = "PERCENT_DAMAGE"
	e.effect_value = 1.15
	e.description = "Normal/Charged +15%, doubled at full burst charges."
	return e

static func _kitain() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.effect_type = "BURST_CHARGE_LOSE"
	e.effect_value = 4.0
	e.description = "Skill damage +10%. After skill lose 4 charges, gain 1.5 (×ER) per turn for 3 turns."
	return e

static func _amenoma() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.effect_type = "BURST_CHARGE_GAIN"
	e.stack_value = 1.5
	e.max_stacks = 3
	e.description = "After skill gain 1 seed (max 3). After burst gain 1.5 charges per seed."
	return e

static func _passive_damage_taken_increase(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_DAMAGE_TAKEN"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = val
	e.target = "SELF"
	e.description = desc
	return e

static func _self_damage_on_attack(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = val
	e.target = "ALL_ALLIES"
	e.description = desc
	return e

static func _lithic() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.condition = "ALLY_FROM_REGION"
	e.condition_value = "Liyue"
	e.effect_type = "DAMAGE_REDUCTION"
	e.effect_value = 2.0
	e.description = "Liyue companion: take 2 less damage per hit. Otherwise take 4 extra per hit."
	return e

static func _haran_stacks() -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_SKILL_USE"
	e.effect_type = "PERCENT_DAMAGE"
	e.condition = "ATTACK_TYPE"
	e.condition_value = "Normal"
	e.stack_value = 0.5
	e.max_stacks = 2
	e.duration = 2
	e.target = "SELF"
	e.description = "When ally uses skill, gain stack (max 2). On your skill, consume stacks: normal attacks deal 50% more per stack for 2 turns."
	return e

static func _on_burst_energy_gain(dice: String, dur: int, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_BURST_USE"
	e.effect_type = "BURST_CHARGE_GAIN"
	e.effect_dice = dice
	e.duration = dur
	e.description = desc
	return e

static func _passive_heal_bonus(val: float, desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HEAL"
	e.effect_type = "HEAL"
	e.effect_value = val
	e.description = desc
	return e

static func _ally_movement_on_attack(desc: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "ATTACK_TYPE"
	e.condition_value = "Normal"
	e.effect_type = "MOVEMENT_BONUS"
	e.target = "ALL_ALLIES"
	e.description = desc
	return e
