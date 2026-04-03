class_name BattleLogger
extends RefCounted
## Per-battle structured logging. Creates per-battle folders with turn logs and
## an aggregated summary written at battle end.


var _battle_id: String = ""
var _turns: Array = []
var _start_time_iso: String = ""
var _start_ticks: int = 0


func start_battle(battle_id: String) -> void:
	_battle_id = battle_id
	_turns = []
	_start_time_iso = Time.get_datetime_string_from_system(true)
	_start_ticks = Time.get_ticks_msec()

	var dir_path: String = "user://data/battles/%s" % battle_id
	DirAccess.make_dir_recursive_absolute(dir_path)


func log_turn(input: Dictionary, results: Dictionary) -> void:
	var battler_name: String = str(input.get("battler_name", ""))
	var battler_data: Dictionary = Global.BattlerData.get(battler_name, {})
	var battler_type: String = str(battler_data.get("type", "Unknown"))

	var attack_used: String = str(input.get("attack_used", "None"))
	var attack_roll: int = int(input.get("attack_roll", 0))
	var critical_hit: bool = input.get("critical_hit", false)
	var tiles_moved: int = int(input.get("tiles_moved", 0))
	var burst_gained: int = int(input.get("burst_gained", 0))
	var item_used: String = str(input.get("item_used", "None"))
	var item_target: String = str(input.get("item_target", "None"))
	var turn_no: int = int(input.get("turn_no", _turns.size() + 1))

	var killed_names: Array = results.get("killed", [])
	var total_damage: int = int(results.get("total_damage", 0))

	# Build per-target detail array
	var target_entries: Array = []
	var total_healing: int = 0
	for t in input.get("targets", []):
		var t_name: String = str(t.get("name", ""))
		var t_hits: int = int(t.get("hits", 0))
		var t_raw_dmg: int = int(t.get("raw_damage", 0))
		var t_type: String = str(t.get("attack_type", "Damage"))
		var t_shield_hit: bool = t.get("shield_hit", false)
		var t_def_roll: int = int(t.get("defense_roll", 0))

		if t_type.to_lower() == "healed":
			total_healing += t_raw_dmg

		target_entries.append({
			"name": t_name,
			"hits": t_hits,
			"damage": t_raw_dmg,
			"type": t_type,
			"shield_hit": t_shield_hit,
			"defense_roll": t_def_roll,
		})

	var entry: Dictionary = {
		"turn_no": turn_no,
		"timestamp": Time.get_datetime_string_from_system(true),
		"battler": battler_name,
		"battler_type": battler_type,
		"attack_used": attack_used,
		"attack_roll": attack_roll,
		"critical_hit": critical_hit,
		"tiles_moved": tiles_moved,
		"burst_gained": burst_gained,
		"item_used": item_used if item_used != "None" else "",
		"item_target": item_target if item_target != "None" else "",
		"targets": target_entries,
		"total_damage": total_damage,
		"total_healing": total_healing,
		"kills": killed_names,
	}

	_turns.append(entry)
	_write_turns_file()


func end_battle() -> Dictionary:
	var end_time_iso: String = Time.get_datetime_string_from_system(true)
	var elapsed_ms: int = Time.get_ticks_msec() - _start_ticks
	var duration_seconds: float = elapsed_ms / 1000.0

	var combatants: Dictionary = {}
	var grand_total_damage: int = 0
	var grand_total_kills: int = 0

	# Pre-initialize ALL known battlers so damage_received works
	# even for combatants who haven't taken a turn yet
	var _empty_entry = func(btype: String) -> Dictionary:
		return {
			"type": btype, "turns_taken": 0,
			"total_damage_dealt": 0, "total_damage_received": 0,
			"total_healing_done": 0, "total_healing_received": 0,
			"kills": 0, "abilities_used": {}, "items_used": {},
			"tiles_moved": 0, "crits": 0, "total_hits": 0, "shields_generated": 0,
			"attack_rolls": [],  # list of all attack rolls made
			"defense_rolls": [],  # list of all defense rolls received
		}
	for bname in Global.BattlerData:
		combatants[bname] = _empty_entry.call(Global.BattlerData[bname].get("type", "Unknown"))

	# Accumulate per-combatant stats from turns
	for turn in _turns:
		var name: String = turn.get("battler", "")
		if name == "":
			continue

		if not combatants.has(name):
			combatants[name] = _empty_entry.call(turn.get("battler_type", "Unknown"))

		var c: Dictionary = combatants[name]
		c["turns_taken"] += 1
		c["tiles_moved"] += int(turn.get("tiles_moved", 0))

		if turn.get("critical_hit", false):
			c["crits"] += 1

		var attack: String = turn.get("attack_used", "None")
		if attack != "None" and attack != "":
			c["abilities_used"][attack] = c["abilities_used"].get(attack, 0) + 1

		var item: String = turn.get("item_used", "")
		if item != "":
			c["items_used"][item] = c["items_used"].get(item, 0) + 1

		var kill_list: Array = turn.get("kills", [])
		c["kills"] += kill_list.size()
		grand_total_kills += kill_list.size()

		# Track the attacker's attack roll (once per turn, not per target)
		var atk_roll: int = int(turn.get("attack_roll", 0))
		if atk_roll > 0:
			c["attack_rolls"].append(atk_roll)

		# Per-target stats
		for t in turn.get("targets", []):
			var t_type: String = str(t.get("type", "Damage")).to_lower()
			var t_dmg: int = int(t.get("damage", 0))
			var t_hits: int = int(t.get("hits", 0))
			var t_name: String = str(t.get("name", ""))
			var t_def_roll: int = int(t.get("defense_roll", 0))

			match t_type:
				"damage", "true damage":
					c["total_damage_dealt"] += t_dmg
					c["total_hits"] += maxi(t_hits, 1) if t_dmg > 0 else 0
					grand_total_damage += t_dmg
					if combatants.has(t_name):
						combatants[t_name]["total_damage_received"] += t_dmg
						# Track the defense roll on the target being attacked
						if t_def_roll > 0:
							combatants[t_name]["defense_rolls"].append(t_def_roll)
				"healed":
					c["total_healing_done"] += t_dmg
					if combatants.has(t_name):
						combatants[t_name]["total_healing_received"] += t_dmg
				"shielded":
					c["shields_generated"] += t_dmg

	# Compute averages
	for cname in combatants:
		var c: Dictionary = combatants[cname]
		var turns: int = c.get("turns_taken", 0)
		var hits: int = c.get("total_hits", 0)
		var dealt: int = c.get("total_damage_dealt", 0)
		c["avg_damage_per_turn"] = (dealt / float(turns)) if turns > 0 else 0.0
		c["avg_damage_per_hit"] = (dealt / float(hits)) if hits > 0 else 0.0
		# Average attack and defense rolls
		var atk_rolls: Array = c.get("attack_rolls", [])
		var def_rolls: Array = c.get("defense_rolls", [])
		var atk_sum: float = 0.0
		for r in atk_rolls:
			atk_sum += float(r)
		c["avg_attack_roll"] = (atk_sum / float(atk_rolls.size())) if atk_rolls.size() > 0 else 0.0
		var def_sum: float = 0.0
		for r in def_rolls:
			def_sum += float(r)
		c["avg_defense_roll"] = (def_sum / float(def_rolls.size())) if def_rolls.size() > 0 else 0.0
		c["times_attacked"] = def_rolls.size()

	var summary: Dictionary = {
		"battle_id": _battle_id,
		"total_turns": _turns.size(),
		"duration_seconds": duration_seconds,
		"start_time": _start_time_iso,
		"end_time": end_time_iso,
		"combatants": combatants,
		"total_kills": grand_total_kills,
		"total_damage": grand_total_damage,
	}

	_write_summary_file(summary)
	return summary


# ── File I/O ────────────────────────────────────────────────────────────────


func _write_turns_file() -> void:
	var path: String = "user://data/battles/%s/turns.json" % _battle_id
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_turns, "\t"))
		file.close()
	else:
		push_warning("BattleLogger: Failed to write turns file at %s" % path)


func _write_summary_file(summary: Dictionary) -> void:
	var path: String = "user://data/battles/%s/summary.json" % _battle_id
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()
	else:
		push_warning("BattleLogger: Failed to write summary file at %s" % path)
