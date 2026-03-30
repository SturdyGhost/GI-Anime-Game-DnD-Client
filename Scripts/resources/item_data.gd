class_name ItemData extends Resource

@export var id: int
@export var item_name: String
@export var type: String
@export var rarity: String
@export var region: String
@export var description: String
@export var value: int
@export var buff_duration: int

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> ItemData:
	var r = ItemData.new()
	r.id = _i(d.get("id"))
	r.item_name = _s(d.get("Item"))
	r.type = _s(d.get("Type"))
	r.rarity = _s(d.get("Rarity"))
	r.region = _s(d.get("Region"))
	r.description = _s(d.get("Description"))
	r.value = _i(d.get("Value"))
	r.buff_duration = _i(d.get("Buff_Duration"))
	return r
