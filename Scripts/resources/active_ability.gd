class_name ActiveAbility extends Resource
## Maps an entity to one of their known abilities. Persists between sessions.
## Ability_Cooldown is runtime state that resets at battle end.

@export var id: int
@export var entity_id: int
@export var entity_type: String  # "Character", "Companion", "Enemy"
@export var ability_id: int      # FK to AbilityData.id
@export var weapon_type: String
@export var element: String
@export var ability_type: String  # "Normal", "Skill", "Burst", "Passive"
@export var ability_cooldown: int = 0

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> ActiveAbility:
	var r = ActiveAbility.new()
	r.id = _i(d.get("id"))
	r.entity_id = _i(d.get("Entity_ID"))
	r.entity_type = _s(d.get("Entity_Type"))
	r.ability_id = _i(d.get("Ability_ID"))
	r.weapon_type = _s(d.get("Weapon_Type"))
	r.element = _s(d.get("Element"))
	r.ability_type = _s(d.get("Ability_Type"))
	r.ability_cooldown = _i(d.get("Ability_Cooldown"))
	return r

func to_dict() -> Dictionary:
	return {
		"id": id, "Entity_ID": entity_id, "Entity_Type": entity_type,
		"Ability_ID": ability_id, "Weapon_Type": weapon_type,
		"Element": element, "Ability_Type": ability_type,
		"Ability_Cooldown": ability_cooldown
	}
