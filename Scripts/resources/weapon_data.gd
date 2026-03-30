class_name WeaponData extends Resource

@export var id: int
@export var name: String
@export var rarity: String
@export var region: String
@export var weapon_type: String
@export var effect: String
@export var stat_1_type: String
@export var stat_1_value: float
@export var stat_2_type: String
@export var stat_2_value: float
@export var stat_3_type: String
@export var stat_3_value: float
@export var stat_modifier: String
@export var stat_modifier_value: float
@export var effects: Array = []

static func _i(v) -> int:    return int(v) if v != null else 0
static func _f(v) -> float:  return float(v) if v != null else 0.0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> WeaponData:
	var r = WeaponData.new()
	r.id = _i(d.get("id"))
	r.name = _s(d.get("Name"))
	r.rarity = _s(d.get("Rarity"))
	r.region = _s(d.get("Region"))
	r.weapon_type = _s(d.get("Weapon_Type"))
	r.effect = _s(d.get("Effect"))
	r.stat_1_type = _s(d.get("Stat_1_Type"))
	r.stat_1_value = _f(d.get("Stat_1_Value"))
	r.stat_2_type = _s(d.get("Stat_2_Type"))
	r.stat_2_value = _f(d.get("Stat_2_Value"))
	r.stat_3_type = _s(d.get("Stat_3_Type"))
	r.stat_3_value = _f(d.get("Stat_3_Value"))
	r.stat_modifier = _s(d.get("Stat_Modifier"))
	r.stat_modifier_value = _f(d.get("Stat_Modifier_Value"))
	return r
