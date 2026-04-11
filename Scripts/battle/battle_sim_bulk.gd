class_name BattleSimBulkRunner extends Node
## Runs N battles on a background thread, aggregates results, emits signals.

signal simulation_progress(completed: int, total: int)
signal simulation_complete(results: Dictionary)

var _thread: Thread = null
var _cancel_requested: bool = false
var _config: Dictionary = {}
var _battle_count: int = 0
var _results: Dictionary = {}

func run(config: Dictionary, count: int) -> void:
	if _thread != null and _thread.is_started():
		push_warning("BattleSimBulkRunner: Simulation already running")
		return
	_cancel_requested = false
	_config = config
	_battle_count = count

	if count <= 10:
		# Small count: run on main thread
		_results = _run_battles()
		simulation_complete.emit(_results)
	else:
		_thread = Thread.new()
		_thread.start(_thread_func)

func cancel() -> void:
	_cancel_requested = true

func is_running() -> bool:
	return _thread != null and _thread.is_started()

func _thread_func() -> void:
	_results = _run_battles()
	call_deferred("_on_thread_done")

func _on_thread_done() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	simulation_complete.emit(_results)

func _run_battles() -> Dictionary:
	var agg := {
		"battles_run": 0,
		"wins": 0,
		"losses": 0,
		"total_wipes": 0,
		"rounds_list": [],
		"per_battler": {},
		"battles_with_zero_deaths": 0,
		"battles_with_perma_death": 0,
		"battles_all_revives_burned": 0,
	}

	for i in range(_battle_count):
		if _cancel_requested:
			break

		var engine := BattleSimEngine.new()
		var result := engine.run_battle(_config)
		agg["battles_run"] += 1

		# Aggregate outcome
		if result.get("outcome") == "win":
			agg["wins"] += 1
		else:
			agg["losses"] += 1
			# Check total wipe (all players/companions dead)
			agg["total_wipes"] += 1

		agg["rounds_list"].append(result.get("total_rounds", 0))

		# Aggregate per-battler stats
		var per_b: Dictionary = result.get("per_battler", {})
		for name in per_b:
			if not agg["per_battler"].has(name):
				agg["per_battler"][name] = {
					"damage_dealt": 0, "damage_taken": 0, "damage_absorbed": 0,
					"healing_done": 0, "total_downs": 0, "total_deaths": 0,
					"total_revives_given": 0, "total_revives_received": 0,
					"total_crits": 0, "total_misses": 0,
					"abilities": {},
				}
			var a: Dictionary = agg["per_battler"][name]
			var b: Dictionary = per_b[name]
			a["damage_dealt"] += int(b.get("damage_dealt", 0))
			a["damage_taken"] += int(b.get("damage_taken", 0))
			a["damage_absorbed"] += int(b.get("damage_absorbed", 0))
			a["healing_done"] += int(b.get("healing_done", 0))
			a["total_downs"] += int(b.get("times_downed", 0))
			a["total_deaths"] += int(b.get("deaths", 0))
			a["total_revives_given"] += int(b.get("times_reviving_others", 0))
			a["total_revives_received"] += int(b.get("times_revived", 0))
			a["total_crits"] += int(b.get("crits", 0))
			a["total_misses"] += int(b.get("misses", 0))
			# Aggregate abilities
			for ab_name in b.get("abilities_used", {}):
				var ab_data: Dictionary = b["abilities_used"][ab_name]
				if not a["abilities"].has(ab_name):
					a["abilities"][ab_name] = {"total_uses": 0, "total_damage": 0}
				a["abilities"][ab_name]["total_uses"] += int(ab_data.get("uses", 0))
				a["abilities"][ab_name]["total_damage"] += int(ab_data.get("total_damage", 0))

		# Track battle-level stats
		var any_deaths := false
		var total_revives_this_battle := 0
		for name in per_b:
			if int(per_b[name].get("deaths", 0)) > 0:
				any_deaths = true
			total_revives_this_battle += int(per_b[name].get("times_reviving_others", 0))
		if not any_deaths and result.get("outcome") == "win":
			agg["battles_with_zero_deaths"] += 1
		if any_deaths:
			agg["battles_with_perma_death"] += 1

		# Emit progress periodically (every 10% or every 100 battles)
		if i % maxi(1, _battle_count / 20) == 0:
			call_deferred("_emit_progress", i + 1, _battle_count)

	# Finalize aggregated results
	return _finalize(agg)


func _emit_progress(completed: int, total: int) -> void:
	simulation_progress.emit(completed, total)


func _finalize(agg: Dictionary) -> Dictionary:
	var n: float = maxf(float(agg.get("battles_run", 1)), 1.0)
	var rounds_list: Array = agg.get("rounds_list", [])

	# Calculate round stats
	var min_rounds := 999
	var max_rounds := 0
	var total_rounds := 0
	for r in rounds_list:
		min_rounds = mini(min_rounds, int(r))
		max_rounds = maxi(max_rounds, int(r))
		total_rounds += int(r)

	# Build final output
	var result := {
		"battles_run": int(n),
		"wins": agg.get("wins", 0),
		"losses": agg.get("losses", 0),
		"win_rate": float(agg.get("wins", 0)) / n * 100.0,
		"total_wipes": agg.get("total_wipes", 0),
		"wipe_rate": float(agg.get("total_wipes", 0)) / n * 100.0,
		"avg_rounds": float(total_rounds) / n,
		"min_rounds": min_rounds if min_rounds < 999 else 0,
		"max_rounds": max_rounds,
		"battles_with_zero_deaths": agg.get("battles_with_zero_deaths", 0),
		"battles_with_perma_death": agg.get("battles_with_perma_death", 0),
		"battles_all_revives_burned": agg.get("battles_all_revives_burned", 0),
		"per_battler": {},
		"damage_distribution": {},
	}

	# Finalize per-battler averages
	var total_damage_all := 0
	for name in agg.get("per_battler", {}):
		var a: Dictionary = agg["per_battler"][name]
		total_damage_all += int(a.get("damage_dealt", 0))
		var pb := {
			"avg_damage_dealt": float(a.get("damage_dealt", 0)) / n,
			"avg_damage_taken": float(a.get("damage_taken", 0)) / n,
			"avg_damage_absorbed": float(a.get("damage_absorbed", 0)) / n,
			"avg_healing_done": float(a.get("healing_done", 0)) / n,
			"total_downs": a.get("total_downs", 0),
			"total_deaths": a.get("total_deaths", 0),
			"total_revives_given": a.get("total_revives_given", 0),
			"total_revives_received": a.get("total_revives_received", 0),
			"total_crits": a.get("total_crits", 0),
			"total_misses": a.get("total_misses", 0),
			"abilities": {},
		}
		for ab_name in a.get("abilities", {}):
			var ab: Dictionary = a["abilities"][ab_name]
			var uses := int(ab.get("total_uses", 0))
			pb["abilities"][ab_name] = {
				"avg_uses": float(uses) / n,
				"avg_damage": float(ab.get("total_damage", 0)) / maxf(float(uses), 1.0),
				"total_damage": ab.get("total_damage", 0),
			}
		result["per_battler"][name] = pb

	# Damage distribution percentages
	if total_damage_all > 0:
		for name in agg.get("per_battler", {}):
			var dmg: int = int(agg["per_battler"][name].get("damage_dealt", 0))
			result["damage_distribution"][name] = float(dmg) / float(total_damage_all) * 100.0

	return result
