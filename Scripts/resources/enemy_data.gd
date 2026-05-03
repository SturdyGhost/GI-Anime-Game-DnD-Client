class_name EnemyData extends Resource

@export var id: int
@export var name: String
@export var tier: String
@export var size_tiles: int
@export var phase_count: int
@export var hp_per_phase: int
@export var phase1_hp: int
@export var phase2_hp: int
@export var phase3_hp: int
@export var phase4_hp: int
@export var phase1_name: String
@export var phase2_name: String
@export var phase3_name: String
@export var phase4_name: String
@export var turn_structure: String
@export var defense_scale_per_asc: float
@export var res_pyro: float
@export var res_hydro: float
@export var res_electro: float
@export var res_cryo: float
@export var res_anemo: float
@export var res_geo: float
@export var res_dendro: float
@export var notes: String

static func _i(v) -> int:    return int(v) if v != null else 0
static func _f(v) -> float:  return float(v) if v != null else 0.0
static func _s(v) -> String: return str(v) if v != null else ""

static func from_dict(d: Dictionary) -> EnemyData:
	var r = EnemyData.new()
	r.id = _i(d.get("id"))
	r.name = _s(d.get("name"))
	r.tier = _s(d.get("tier"))
	r.size_tiles = _i(d.get("size_tiles"))
	r.phase_count = _i(d.get("phase_count"))
	r.hp_per_phase = _i(d.get("hp_per_phase"))
	r.phase1_hp = _i(d.get("phase1_hp"))
	r.phase2_hp = _i(d.get("phase2_hp"))
	r.phase3_hp = _i(d.get("phase3_hp"))
	r.phase4_hp = _i(d.get("phase4_hp"))
	r.phase1_name = _s(d.get("phase1_name"))
	r.phase2_name = _s(d.get("phase2_name"))
	r.phase3_name = _s(d.get("phase3_name"))
	r.phase4_name = _s(d.get("phase4_name"))
	r.turn_structure = _s(d.get("turn_structure"))
	r.defense_scale_per_asc = _f(d.get("defense_scale_per_asc"))
	r.res_pyro = _f(d.get("res_pyro"))
	r.res_hydro = _f(d.get("res_hydro"))
	r.res_electro = _f(d.get("res_electro"))
	r.res_cryo = _f(d.get("res_cryo"))
	r.res_anemo = _f(d.get("res_anemo"))
	r.res_geo = _f(d.get("res_geo"))
	r.res_dendro = _f(d.get("res_dendro"))
	r.notes = _s(d.get("notes"))
	return r

## Get HP for a specific phase (1-indexed). Falls back to hp_per_phase if no specific value.
func get_phase_hp(phase: int) -> int:
	match phase:
		1: if phase1_hp > 0: return phase1_hp
		2: if phase2_hp > 0: return phase2_hp
		3: if phase3_hp > 0: return phase3_hp
		4: if phase4_hp > 0: return phase4_hp
	return hp_per_phase if hp_per_phase > 0 else 100

## Get the display name for a specific phase, or "" if none.
func get_phase_name(phase: int) -> String:
	match phase:
		1: return phase1_name
		2: return phase2_name
		3: return phase3_name
		4: return phase4_name
	return ""

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "tier": tier, "size_tiles": size_tiles,
		"phase_count": phase_count, "hp_per_phase": hp_per_phase,
		"phase1_hp": phase1_hp, "phase2_hp": phase2_hp,
		"phase3_hp": phase3_hp, "phase4_hp": phase4_hp,
		"phase1_name": phase1_name, "phase2_name": phase2_name,
		"phase3_name": phase3_name, "phase4_name": phase4_name,
		"turn_structure": turn_structure, "defense_scale_per_asc": defense_scale_per_asc,
		"res_pyro": res_pyro, "res_hydro": res_hydro, "res_electro": res_electro,
		"res_cryo": res_cryo, "res_anemo": res_anemo, "res_geo": res_geo,
		"res_dendro": res_dendro, "notes": notes
	}
