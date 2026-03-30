class_name AbilityData extends Resource

@export var id: int
@export var name: String
@export var element: String
@export var description: String
@export var dice_count: int
@export var dice_die: int
@export var dice_flat: int
@export var defense_threshold: int
@export var blockable: bool
@export var bypass_defense: bool
@export var targeting_type: String
@export var targeting_radius: int
@export var targeting_length: int
@export var targeting_width: int
@export var targeting_targets: int
@export var selector: String
@export var selector_radius: int
@export var tiles_locked_count: int
@export var trigger_type: String
@export var trigger_threshold_int: int
@export var trigger_window_rounds: int
@export var hits_count: int
@export var effect_mark_name: String
@export var effect_mark_duration_rnds: int
@export var effect_mark_consumed_on_hit: bool
@export var effect_guaranteed_crit: bool
@export var effect_silence_skill_rnds: int
@export var effect_immobilize: bool
@export var effect_tile_dmg_dice_cnt: int
@export var effect_tile_dmg_dice_die: int
@export var effect_tile_dmg_dice_flat: int
@export var effect_tile_dmg_when: String
@export var effect_resource_name: String
@export var effect_res_dice_cnt: int
@export var effect_res_dice_die: int
@export var effect_res_flat: int
@export var effect_res_sign: String
@export var effect_status: int
@export var effect_status_duration_rounds: int
@export var effect_status_target: String
@export var status_effects: String
@export var movement: int
@export var charge_cost: int
@export var cooldown: int
@export var phase_idx: int
@export var order: int
@export var weight: float
@export var effects: Array = []

# ── Entity context (merged from Active_Abilities) ───────────────────────────
@export var entity_type: String = ""   # "Character", "Companion", "Enemy"
@export var entity_id: int = 0         # FK to PlayerData/CompanionData/EnemyData
@export var entity_name: String = ""   # Denormalized for display
@export var weapon_type: String = ""   # Sword, Claymore, Polearm, Bow, Catalyst
@export var ability_type: String = ""  # "Basic Attack", "Charged Attack", "Skill", "Burst", "Passive"
@export var ability_cooldown: int = 0  # Runtime cooldown state

static func _i(v) -> int:    return int(v) if v != null else 0
static func _f(v) -> float:  return float(v) if v != null else 0.0
static func _s(v) -> String: return str(v) if v != null else ""
static func _b(v) -> bool:   return bool(v) if v != null else false

static func from_dict(d: Dictionary) -> AbilityData:
	var r = AbilityData.new()
	r.id = _i(d.get("id"))
	r.name = _s(d.get("name"))
	r.element = _s(d.get("element"))
	r.description = _s(d.get("description"))
	r.dice_count = _i(d.get("dice_count"))
	r.dice_die = _i(d.get("dice_die"))
	r.dice_flat = _i(d.get("dice_flat"))
	r.defense_threshold = _i(d.get("defense_threshold"))
	r.blockable = _b(d.get("blockable"))
	r.bypass_defense = _b(d.get("bypass_defense"))
	r.targeting_type = _s(d.get("targeting_type"))
	r.targeting_radius = _i(d.get("targeting_radius"))
	r.targeting_length = _i(d.get("targeting_length"))
	r.targeting_width = _i(d.get("targeting_width"))
	r.targeting_targets = _i(d.get("targeting_targets"))
	r.selector = _s(d.get("selector"))
	r.selector_radius = _i(d.get("selector_radius"))
	r.tiles_locked_count = _i(d.get("tiles_locked_count"))
	r.trigger_type = _s(d.get("trigger_type"))
	r.trigger_threshold_int = _i(d.get("trigger_threshold_int"))
	r.trigger_window_rounds = _i(d.get("trigger_window_rounds"))
	r.hits_count = _i(d.get("hits_count"))
	r.effect_mark_name = _s(d.get("effect_mark_name"))
	r.effect_mark_duration_rnds = _i(d.get("effect_mark_duration_rnds"))
	r.effect_mark_consumed_on_hit = _b(d.get("effect_mark_consumed_on_hit"))
	r.effect_guaranteed_crit = _b(d.get("effect_guaranteed_crit"))
	r.effect_silence_skill_rnds = _i(d.get("effect_silence_skill_rnds"))
	r.effect_immobilize = _b(d.get("effect_immobilize"))
	r.effect_tile_dmg_dice_cnt = _i(d.get("effect_tile_dmg_dice_cnt"))
	r.effect_tile_dmg_dice_die = _i(d.get("effect_tile_dmg_dice_die"))
	r.effect_tile_dmg_dice_flat = _i(d.get("effect_tile_dmg_dice_flat"))
	r.effect_tile_dmg_when = _s(d.get("effect_tile_dmg_when"))
	r.effect_resource_name = _s(d.get("effect_resource_name"))
	r.effect_res_dice_cnt = _i(d.get("effect_res_dice_cnt"))
	r.effect_res_dice_die = _i(d.get("effect_res_dice_die"))
	r.effect_res_flat = _i(d.get("effect_res_flat"))
	r.effect_res_sign = _s(d.get("effect_res_sign"))
	r.effect_status = _i(d.get("effect_status"))
	r.effect_status_duration_rounds = _i(d.get("effect_status_duration_rounds"))
	r.effect_status_target = _s(d.get("effect_status_target"))
	r.status_effects = _s(d.get("status_effects"))
	r.movement = _i(d.get("movement"))
	r.charge_cost = _i(d.get("charge_cost"))
	r.cooldown = _i(d.get("cooldown"))
	r.phase_idx = _i(d.get("phase_idx"))
	r.order = _i(d.get("order"))
	r.weight = _f(d.get("weight"))
	return r
