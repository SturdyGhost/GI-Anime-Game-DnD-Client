class_name BalanceAdvisor extends RefCounted
## Compare simulation results against a tier profile and generate advisory suggestions.
## Returns { verdict: String, verdict_level: String, suggestions: Array[Dictionary] }
## verdict_level: "too_easy", "balanced", "too_hard"
## Each suggestion: { title: String, description: String }

static func analyze(results: Dictionary, profile: Dictionary) -> Dictionary:
	var win_rate := float(results.get("win_rate", 0))
	var target_win := float(profile.get("win_rate", 75))
	var wipe_rate := float(results.get("wipe_rate", 0))
	var target_wipe := float(profile.get("wipe_rate", 25))

	# Determine verdict
	var diff := win_rate - target_win
	var verdict := ""
	var level := "balanced"
	if diff > 10:
		verdict = "TOO EASY — Players winning %.1f%% (target: ~%.0f%%)" % [win_rate, target_win]
		level = "too_easy"
	elif diff > 3:
		verdict = "SLIGHTLY TOO EASY — Players winning %.1f%% (target: ~%.0f%%)" % [win_rate, target_win]
		level = "too_easy"
	elif diff < -10:
		verdict = "TOO HARD — Players winning %.1f%% (target: ~%.0f%%)" % [win_rate, target_win]
		level = "too_hard"
	elif diff < -3:
		verdict = "SLIGHTLY TOO HARD — Players winning %.1f%% (target: ~%.0f%%)" % [win_rate, target_win]
		level = "too_hard"
	else:
		verdict = "BALANCED — Players winning %.1f%% (target: ~%.0f%%)" % [win_rate, target_win]
		level = "balanced"

	var suggestions: Array = []

	# Generate suggestions based on gaps
	if diff > 5:
		# Too easy — need to make enemy harder
		var hp_increase := int(diff * 2.5)
		suggestions.append({
			"title": "Increase HP by ~%d%%" % hp_increase,
			"description": "Players are winning too often. More HP extends the fight, increasing resource drain. Expected to drop win rate ~%.0f%%." % (diff * 0.5),
		})
		if wipe_rate < target_wipe * 0.7:
			suggestions.append({
				"title": "Increase Attack Dice",
				"description": "Enemy damage output is low — players rarely need revives (%.1f%% wipes vs %.0f%% target). Higher attack dice increases pressure." % [wipe_rate, target_wipe],
			})
	elif diff < -5:
		# Too hard — need to make enemy easier
		var hp_decrease := int(absf(diff) * 2.0)
		suggestions.append({
			"title": "Decrease HP by ~%d%%" % hp_decrease,
			"description": "Players are losing too often. Less HP shortens the fight. Expected to raise win rate ~%.0f%%." % (absf(diff) * 0.5),
		})
		if wipe_rate > target_wipe * 1.3:
			suggestions.append({
				"title": "Decrease Attack Dice",
				"description": "Enemy is downing players too fast (%.1f%% wipes vs %.0f%% target). Lower attack dice reduces spike damage." % [wipe_rate, target_wipe],
			})

	# Check revive/resource usage
	var battles_run := float(results.get("battles_run", 1))
	var perma_death_rate := float(results.get("battles_with_perma_death", 0)) / battles_run * 100.0
	var target_perma := float(profile.get("perma_death_rate", 25))
	if perma_death_rate > target_perma * 1.5 and level != "too_hard":
		suggestions.append({
			"title": "Reduce burst damage",
			"description": "Permanent deaths are too frequent (%.1f%% vs %.0f%% target). Consider lowering max damage on key abilities." % [perma_death_rate, target_perma],
		})

	# If balanced, say so
	if suggestions.is_empty():
		suggestions.append({
			"title": "No changes recommended",
			"description": "Enemy stats are well-calibrated for %s tier." % str(profile.get("tier", "this")),
		})

	return {"verdict": verdict, "verdict_level": level, "suggestions": suggestions}
