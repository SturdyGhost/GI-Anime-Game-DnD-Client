class_name StatusEffectData extends Resource

@export var id: int
@export var name: String
@export var description: String
@export var effects: Array = []

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> StatusEffectData:
	var r = StatusEffectData.new()
	r.id = _i(d.get("id"))
	r.name = _s(d.get("Name"))
	r.description = _s(d.get("Description"))
	return r
