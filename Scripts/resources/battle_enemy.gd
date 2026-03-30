class_name BattleEnemy extends Resource
## Runtime enemy instance during battle. Not persisted between sessions.

@export var id: int
@export var enemy_name: String
@export var enemy_id: int  # FK to EnemyData.id
@export var current_health: int
@export var max_health: int
@export var phase: int = 1
@export var killed: bool = false
@export var applied_element: String = "None"
@export var status_effect: String = "None"
@export var fog: bool = false
@export var skipped: bool = false
@export var skip_duration: int = 0
@export var shield_health: int = 0
@export var shield_duration: int = 0

## The battle name used in turn order: "EnemyName ID"
@export var battle_label: String:
	get: return enemy_name + " " + str(id)

static func _i(v) -> int:    return int(v) if v != null else 0
static func _s(v) -> String: return str(v) if v != null else ""
static func _b(v) -> bool:   return bool(v) if v != null else false

static func from_dict(d: Dictionary) -> BattleEnemy:
	var r = BattleEnemy.new()
	r.id = _i(d.get("id"))
	r.enemy_name = _s(d.get("EnemyName"))
	r.enemy_id = _i(d.get("EnemyID"))
	r.current_health = _i(d.get("Current_Health", d.get("HP_Current")))
	r.max_health = _i(d.get("Max_Health", d.get("HP_Max")))
	r.phase = _i(d.get("Phase")) if d.get("Phase") != null else 1
	r.killed = _b(d.get("Killed"))
	r.applied_element = _s(d.get("AppliedElement")) if d.get("AppliedElement") != null else "None"
	r.status_effect = _s(d.get("StatusEffect")) if d.get("StatusEffect") != null else "None"
	r.fog = _b(d.get("Fog"))
	r.skipped = _b(d.get("Skipped"))
	r.skip_duration = _i(d.get("Skip_Duration"))
	r.shield_health = _i(d.get("Shield_Health"))
	r.shield_duration = _i(d.get("Shield_Duration"))
	return r

func to_dict() -> Dictionary:
	return {
		"id": id, "EnemyName": enemy_name, "EnemyID": enemy_id,
		"Current_Health": current_health, "Max_Health": max_health,
		"Phase": phase, "Killed": killed, "AppliedElement": applied_element,
		"StatusEffect": status_effect, "Fog": fog, "Skipped": skipped,
		"Skip_Duration": skip_duration, "Shield_Health": shield_health,
		"Shield_Duration": shield_duration
	}
