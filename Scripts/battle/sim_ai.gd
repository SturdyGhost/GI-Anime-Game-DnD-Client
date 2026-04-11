class_name SimAI extends RefCounted
## Smart AI for battle simulation. Selects abilities and targets.
## Same priority framework for players and enemies with different targeting.

## Returns a decision dict: {ability: Dict, targets: Array[String], action: String, movement: int}
## action: "attack", "revive", "move_only", "skip"
static func decide_turn(
	battler_name: String,
	battler_data: Dictionary,
	all_battlers: Dictionary,
	spatial: SimSpatial,
	effect_processor: EffectProcessor,
	cooldowns: Dictionary,
	revives_available: Dictionary
) -> Dictionary:

	var b_type: String = battler_data.get("type", "Character")
	var is_player_side := b_type == "Character" or b_type == "Companion"
	var my_abilities: Dictionary = battler_data.get("entity_current_ability_data", {})
	var burst_charges: int = int(battler_data.get("burst_charges", 0))

	# Check if stunned/skipped
	if battler_data.get("skipped_status", false):
		return {"action": "skip", "ability": {}, "targets": []}

	# Determine movement budget
	var movement := int(battler_data.get("entity_data", {}).get("Movement", 7))
	if _is_rooted(battler_name, effect_processor):
		movement = 0
	elif _is_slowed(battler_name, effect_processor):
		movement = movement / 2

	# Priority 1: Revive a downed ally
	if is_player_side:
		var downed := _find_downed_allies(battler_name, all_battlers, is_player_side)
		if downed.size() > 0 and revives_available.get(battler_name, 0) > 0:
			return {"action": "revive", "ability": {}, "targets": [downed[0]], "movement": movement}

	# Gather available abilities (off cooldown, enough burst charges)
	var available: Array = []
	for aid in my_abilities:
		var ab: Dictionary = my_abilities[aid]
		if cooldowns.get(int(aid), 0) > 0:
			continue
		var charge_cost := int(ab.get("charge_cost", 0))
		if charge_cost > 0 and burst_charges < charge_cost:
			continue
		available.append(ab)

	# Sort by priority: Burst > Skill > Charged > Basic
	available.sort_custom(func(a, b): return _ability_priority(a) > _ability_priority(b))

	# Find enemies to target
	var enemies := _find_enemies(battler_name, all_battlers, is_player_side)
	if enemies.is_empty():
		return {"action": "skip", "ability": {}, "targets": []}

	# Pick best ability that can reach a target
	for ab in available:
		var ab_range := int(ab.get("targeting_length", 0))
		var is_melee := ab_range <= 0
		var best_target := _pick_target(battler_name, enemies, all_battlers, spatial, ab_range, movement, is_melee)
		if best_target != "":
			return {"action": "attack", "ability": ab, "targets": [best_target], "movement": movement}

	# Priority 5: Move only (no ability can reach)
	var closest_enemy := _closest(battler_name, enemies, spatial)
	if closest_enemy != "" and movement > 0:
		return {"action": "move_only", "ability": {}, "targets": [closest_enemy], "movement": movement}

	return {"action": "skip", "ability": {}, "targets": []}


static func _ability_priority(ab: Dictionary) -> int:
	var atype := str(ab.get("ability_type", "")).to_lower()
	if atype.contains("burst"):
		return 4
	elif atype.contains("skill"):
		return 3
	elif atype.contains("charged"):
		return 2
	elif atype.contains("basic"):
		return 1
	return 0


static func _find_downed_allies(my_name: String, all_battlers: Dictionary, is_player_side: bool) -> Array:
	var downed: Array = []
	for name in all_battlers:
		if name == my_name:
			continue
		var bd: Dictionary = all_battlers[name]
		var their_type: String = bd.get("type", "")
		var same_side := (is_player_side and (their_type == "Character" or their_type == "Companion")) \
			or (not is_player_side and their_type == "Enemy")
		if same_side and bd.get("killed_status", false) and int(bd.get("current_health", 0)) <= 0:
			downed.append(name)
	return downed


static func _find_enemies(my_name: String, all_battlers: Dictionary, is_player_side: bool) -> Array:
	var enemies: Array = []
	for name in all_battlers:
		if name == my_name:
			continue
		var bd: Dictionary = all_battlers[name]
		var their_type: String = bd.get("type", "")
		var is_enemy_of_me := (is_player_side and their_type == "Enemy") \
			or (not is_player_side and (their_type == "Character" or their_type == "Companion"))
		if is_enemy_of_me and not bd.get("killed_status", false):
			enemies.append(name)
	return enemies


static func _pick_target(
	my_name: String, enemies: Array, all_battlers: Dictionary,
	spatial: SimSpatial, ab_range: int, movement: int, is_melee: bool
) -> String:
	# Sort enemies by HP (lowest first — focus fire)
	var sorted_enemies := enemies.duplicate()
	sorted_enemies.sort_custom(func(a, b):
		return int(all_battlers[a].get("current_health", 999)) < int(all_battlers[b].get("current_health", 999))
	)
	# Find first target in range (or reachable after moving)
	for enemy in sorted_enemies:
		var dist := spatial.distance(my_name, enemy)
		var effective_range := float(ab_range) if not is_melee else 1.0
		if dist <= effective_range:
			return enemy
		if dist <= effective_range + float(movement):
			return enemy
	return ""


static func _closest(my_name: String, enemies: Array, spatial: SimSpatial) -> String:
	var best := ""
	var best_dist := 99999.0
	for enemy in enemies:
		var d := spatial.distance(my_name, enemy)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


static func _is_rooted(battler_name: String, ep: EffectProcessor) -> bool:
	var effects := ep.query(battler_name, "PASSIVE", {})
	for es in effects:
		if es.effect.effect_type == "PREVENT_MOVEMENT":
			return true
	return false


static func _is_slowed(battler_name: String, ep: EffectProcessor) -> bool:
	var effects := ep.query(battler_name, "PASSIVE", {})
	for es in effects:
		if es.effect.effect_type == "MOVEMENT_COST" and es.effect.effect_value > 1.0:
			return true
	return false
