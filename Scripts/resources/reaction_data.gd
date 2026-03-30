class_name ReactionData extends Resource

@export var id: int
@export var first_element: String
@export var second_element: String
@export var outcome: String  # "FAVORABLE", "UNFAVORABLE", "NEUTRAL"
@export var effect: String
@export var effects: Array = []

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> ReactionData:
	var r = ReactionData.new()
	r.id = _i(d.get("id"))
	r.first_element = _s(d.get("First_Element"))
	r.second_element = _s(d.get("Second_Element"))
	# Parse [TAG] from beginning of Effect text
	var raw_effect = _s(d.get("Effect"))
	if raw_effect.begins_with("["):
		var close = raw_effect.find("]")
		if close > 0:
			r.outcome = raw_effect.substr(1, close - 1)
			r.effect = raw_effect.substr(close + 2)  # skip "] "
		else:
			r.outcome = ""
			r.effect = raw_effect
	else:
		r.outcome = ""
		r.effect = raw_effect
	return r
