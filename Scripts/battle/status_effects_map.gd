class_name StatusEffectsMap extends RefCounted
## Maps status effect names to their structured GameEffect arrays.

static func get_effects(status_name: String) -> Array:
	match status_name:
		"Stun":
			return [EffectBuilder.skip_turn(1, "Turn is skipped, cannot act or do anything.")]
		"Root":
			return [EffectBuilder.prevent_movement(1, "Cannot move. Abilities with built-in movement cannot be used.")]
		"Blind":
			return [EffectBuilder.random_target(1, "Targets are randomized. AoE centers on random target. Friendly fire enabled.")]
		"Slow":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "MOVEMENT_COST"
			e.effect_value = 2.0
			e.description = "Each tile of movement counts as 2."
			return [e]
		"Quick":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "MOVEMENT_COST"
			e.effect_value = 0.5
			e.description = "Each tile of movement counts as 0.5."
			return [e]
		"Advantage":
			return [EffectBuilder.roll_advantage(1, "Roll twice, take the better result.")]
		"Disadvantage":
			return [EffectBuilder.roll_disadvantage(1, "Roll twice, take the worse result.")]
		"Camouflage":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "CAMOUFLAGE"
			e.description = "Cannot be seen by enemies. Ends when you attack."
			return [e]
		"Disarm":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "DISARM"
			e.description = "Cannot attack until weapon is recovered. May swap to same type from inventory (counts as action)."
			return [e]
		"Taunt":
			return [EffectBuilder.taunt(1, "Forces enemies to target this unit.")]
		"Fear":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "FEAR"
			e.description = "Enemies move away from and target furthest ally from this unit."
			return [e]
		"Burst Bust":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "PREVENT_BURST_CHARGE"
			e.description = "Cannot generate burst charges."
			return [e]
		"Skill Suck":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "PREVENT_COOLDOWN"
			e.description = "Skill cooldown does not decrease."
			return [e]
		"Unlucky":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "OVERRIDE_LUCK"
			e.effect_value = -1.0
			e.description = "Overrides luck, bad things happen."
			return [e]
		"Lucky":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "OVERRIDE_LUCK"
			e.effect_value = 1.0
			e.description = "Overrides luck, good things happen."
			return [e]
		"En Garde":
			var e = GameEffect.new()
			e.trigger = "ON_DAMAGE_TAKEN"
			e.effect_type = "NEGATE_AND_STUN"
			e.target = "ATTACKER"
			e.duration = 1
			e.description = "Next attack deals no damage and stuns the attacker for 1 turn."
			return [e]
		"Reflect":
			return [EffectBuilder.reflect(1, "Next attack is reflected back at the attacker.")]
		"Overheated":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "COOLDOWN_INCREASE"
			e.effect_value = 1.0
			e.description = "Abilities with cooldowns have their cooldown increased by 1."
			return [e]
		"Locked In":
			var e = GameEffect.new()
			e.trigger = "START_OF_TURN"
			e.effect_type = "REPEAT_LAST_ACTIONS"
			e.description = "Must repeat the same actions from last turn in the same order."
			return [e]
		"Loner":
			var e = GameEffect.new()
			e.trigger = "END_OF_TURN"
			e.condition = "ENEMY_COUNT_NEARBY"
			e.condition_value = "1+_1tiles"
			e.effect_type = "NEGATE_NEXT_DAMAGE"
			e.description = "If any entity on surrounding tiles at end of turn, next attack deals no damage."
			return [e]
		"Collateral Damage":
			var e = GameEffect.new()
			e.trigger = "ON_HIT"
			e.effect_type = "CHAIN_DAMAGE"
			e.effect_value = 0.25
			e.target = "CLOSEST_ENEMY"
			e.description = "25% of damage dealt is also dealt to closest ally."
			return [e]
		"Shield-Break":
			var e1 = GameEffect.new()
			e1.trigger = "ON_DAMAGE_TAKEN"
			e1.effect_type = "PERCENT_DAMAGE"
			e1.effect_value = 2.0
			e1.description = "Incoming damage is doubled."
			var e2 = GameEffect.new()
			e2.trigger = "PASSIVE"
			e2.effect_type = "PREVENT_SHIELD"
			e2.description = "Cannot gain a new shield or eat food items."
			return [e1, e2]
		"Dazed":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "RESTRICT_BASIC_ONLY"
			e.description = "Can only use Basic Attacks. Skills and Bursts cannot be used."
			return [e]
		"Slippery":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "FORCED_FULL_MOVEMENT"
			e.description = "Next movement slides full distance in chosen direction, cannot stop early."
			return [e]
		"Pinned":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "PREVENT_ROTATION"
			e.description = "Cannot rotate or change facing direction."
			return [e]
		"Hot Feet":
			var e = GameEffect.new()
			e.trigger = "PASSIVE"
			e.effect_type = "FORCED_MOVEMENT_BEFORE_ATTACK"
			e.description = "Must use full movement before attacking. Cannot end on starting tile."
			return [e]
	return []
