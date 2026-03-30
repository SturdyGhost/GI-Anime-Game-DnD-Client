class_name EntityStats extends Resource
## Base persistent stats for any entity (player, companion, enemy).
## Final calculated values come from CharacterManager at runtime.
## Effects, gear, and buffs modify the calculated values — not these.

# ── Base Points (permanent starting stats) ───────────────────────────────────
@export var health_base: int = 0
@export var attack_base: int = 0
@export var defense_base: int = 0
@export var elemental_mastery_base: int = 0
@export var energy_recharge_base: float = 0.0
@export var critical_damage_base: float = 0.0

# ── Skill Points (temporary between ascensions) ─────────────────────────────
@export var health_skill: int = 0
@export var attack_skill: int = 0
@export var defense_skill: int = 0
@export var elemental_mastery_skill: int = 0
@export var energy_recharge_skill: float = 0.0
@export var critical_damage_skill: float = 0.0

# ── Unspent ──────────────────────────────────────────────────────────────────
@export var unspent_skill_points: int = 0
@export var unspent_base_points: int = 0

## Scaling factors for stat calculation (base + skill) * scale
const SCALING := {
	"health": 2.0,
	"attack": 1.0,
	"defense": 1.0,
	"elemental_mastery": 1.0,
	"energy_recharge": 0.1,
	"critical_damage": 0.1,
}

## Get the raw base value for a stat (before gear/effects).
func get_raw(stat: String) -> float:
	var base: float = 0.0
	var skill: float = 0.0
	var scale: float = SCALING.get(stat, 1.0)
	match stat:
		"health":
			base = health_base; skill = health_skill
		"attack":
			base = attack_base; skill = attack_skill
		"defense":
			base = defense_base; skill = defense_skill
		"elemental_mastery":
			base = elemental_mastery_base; skill = elemental_mastery_skill
		"energy_recharge":
			base = energy_recharge_base; skill = energy_recharge_skill
		"critical_damage":
			base = critical_damage_base; skill = critical_damage_skill
	return (base + skill) * scale

## All stat names this system tracks.
static func stat_names() -> Array:
	return ["health", "attack", "defense", "elemental_mastery", "energy_recharge", "critical_damage"]
