class_name CalculatedStats extends RefCounted
## Runtime-only calculated stat block. Produced by CharacterManager.calculate_stats().
## Combines base stats + gear + effects. Never persisted.

var health: float = 0.0
var attack: float = 0.0
var defense: float = 0.0
var elemental_mastery: float = 0.0
var energy_recharge: float = 0.0
var critical_damage: float = 0.0
var universal_damage_bonus: float = 0.0
var crit_threshold: int = 20

## Current combat state (updated during battle)
var current_health: int = 0
var max_health: int = 0
var burst_charges: int = 0
var shield_health: int = 0
var shield_duration: int = 0
var applied_element: String = "None"

func get_stat(stat_name: String) -> float:
	match stat_name:
		"health": return health
		"attack": return attack
		"defense": return defense
		"elemental_mastery": return elemental_mastery
		"energy_recharge": return energy_recharge
		"critical_damage": return critical_damage
		"universal_damage_bonus": return universal_damage_bonus
	return 0.0
