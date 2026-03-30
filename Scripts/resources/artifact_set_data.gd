class_name ArtifactSetData extends Resource

@export var id: int
@export var artifact_set: String
@export var bonus_type: int  # 2 = 2-piece, 4 = 4-piece
@export var effect: String
@export var stat_modifier: String
@export var stat_modifier_value: float
@export var condition: String
@export var condition_value: String
@export var effects: Array = []

static func _i(v) -> int:    return int(v) if v != null else 0
static func _f(v) -> float:  return float(v) if v != null else 0.0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> ArtifactSetData:
	var r = ArtifactSetData.new()
	r.id = _i(d.get("id"))
	r.artifact_set = _s(d.get("Artifact_Set"))
	r.bonus_type = _i(d.get("Bonus_Type"))
	r.effect = _s(d.get("Effect"))
	r.stat_modifier = _s(d.get("Stat_Modifier"))
	r.stat_modifier_value = _f(d.get("Stat_Modifier_Value"))
	r.condition = _s(d.get("Condition"))
	r.condition_value = _s(d.get("Condition_Value"))
	return r
