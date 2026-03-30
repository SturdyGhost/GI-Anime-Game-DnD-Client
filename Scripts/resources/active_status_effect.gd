class_name ActiveStatusEffect extends Resource
## An active status effect on an entity during battle.

@export var id: int
@export var entity_id: int
@export var entity_type: String  # "Character", "Companion", "Enemy"
@export var status_id: int       # FK to StatusEffectData.id
@export var duration: int

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> ActiveStatusEffect:
	var r = ActiveStatusEffect.new()
	r.id = _i(d.get("id"))
	r.entity_id = _i(d.get("Entity_ID"))
	r.entity_type = _s(d.get("Entity_Type"))
	r.status_id = _i(d.get("Status_ID"))
	r.duration = _i(d.get("Duration"))
	return r

func to_dict() -> Dictionary:
	return {
		"id": id, "Entity_ID": entity_id, "Entity_Type": entity_type,
		"Status_ID": status_id, "Duration": duration
	}
