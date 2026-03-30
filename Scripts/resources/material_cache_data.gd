class_name MaterialCacheData extends Resource

@export var id: int
@export var region: String
@export var roll: int
@export var materials: String

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> MaterialCacheData:
	var r = MaterialCacheData.new()
	r.id = _i(d.get("id"))
	r.region = _s(d.get("Region"))
	r.roll = _i(d.get("Roll"))
	r.materials = _s(d.get("Materials"))
	return r
