class_name MinigameData extends Resource

@export var id: int
@export var key: String
@export var name: String
@export var description: String
@export var unlocked: bool

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""
static func _b(v) -> bool:   return bool(v) if v != null else false

static func from_dict(d: Dictionary) -> MinigameData:
	var r = MinigameData.new()
	r.id = _i(d.get("id"))
	r.key = _s(d.get("key"))
	r.name = _s(d.get("name"))
	r.description = _s(d.get("description"))
	r.unlocked = _b(d.get("unlocked"))
	return r
