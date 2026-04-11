class_name TierProfiles extends RefCounted
## Fixed difficulty tier profiles for encounter balancing.
## Each profile defines target win rates, resource usage, etc.

static func get_profile(tier: String) -> Dictionary:
	match tier.to_lower():
		"common":
			return {
				"tier": "Common",
				"win_rate": 99.0,
				"wipe_rate": 0.5,
				"rounds_per_enemy": [1, 2],
				"revives_needed_rate": 2.0,
				"perma_death_rate": 0.5,
				"items_needed_rate": 1.0,
				"defense_die": 12,
				"attack_die": 12,
				"description": "Trivial. Players win easily, no resources needed.",
			}
		"uncommon":
			return {
				"tier": "Uncommon",
				"win_rate": 95.0,
				"wipe_rate": 2.0,
				"rounds_per_enemy": [3, 5],
				"revives_needed_rate": 5.0,
				"perma_death_rate": 2.0,
				"items_needed_rate": 10.0,
				"defense_die": 16,
				"attack_die": 16,
				"description": "Easy. Occasional item use, revives almost never.",
			}
		"rare":
			return {
				"tier": "Rare",
				"win_rate": 85.0,
				"wipe_rate": 8.0,
				"rounds_per_enemy": [5, 8],
				"revives_needed_rate": 30.0,
				"perma_death_rate": 8.0,
				"items_needed_rate": 40.0,
				"defense_die": 16,
				"attack_die": 16,
				"description": "Moderate. Items likely, someone downed in ~30% of fights.",
			}
		"epic":
			return {
				"tier": "Epic",
				"win_rate": 80.0,
				"wipe_rate": 15.0,
				"rounds_per_enemy": [8, 12],
				"revives_needed_rate": 80.0,
				"perma_death_rate": 10.0,
				"items_needed_rate": 70.0,
				"defense_die": 20,
				"attack_die": 20,
				"description": "Hard. All revives burned in most fights, permanent deaths rare.",
			}
		"boss":
			return {
				"tier": "Boss",
				"win_rate": 75.0,
				"wipe_rate": 25.0,
				"rounds_per_enemy": [12, 20],
				"revives_needed_rate": 50.0,  # of wins
				"perma_death_rate": 25.0,     # of wins
				"items_needed_rate": 80.0,
				"defense_die": 20,
				"attack_die": 0,  # Ability-specified
				"description": "Boss. Full wipe ~25%, all revives burned in half of wins.",
			}
		"legendary":
			return {
				"tier": "Legendary",
				"win_rate": 50.0,
				"wipe_rate": 40.0,
				"rounds_per_enemy": [15, 30],
				"revives_needed_rate": 95.0,
				"perma_death_rate": 80.0,  # of wins
				"items_needed_rate": 95.0,
				"defense_die": 20,
				"attack_die": 0,  # Ability-specified
				"description": "Brutal. ~50% win rate, clean wins rare (~10%).",
			}
	# Default to common
	return get_profile("common")


static func get_all_tiers() -> Array:
	return ["Common", "Uncommon", "Rare", "Epic", "Boss", "Legendary"]


## Scale profile expectations based on enemy count.
## More enemies = longer fights, more resource usage, slightly lower win rate.
static func scale_profile(profile: Dictionary, enemy_count: int) -> Dictionary:
	if enemy_count <= 1:
		return profile.duplicate()
	var scaled := profile.duplicate(true)
	var factor := float(enemy_count)
	# Rounds scale proportionally
	scaled["rounds_per_enemy"][0] = int(float(scaled["rounds_per_enemy"][0]) * factor * 0.7)
	scaled["rounds_per_enemy"][1] = int(float(scaled["rounds_per_enemy"][1]) * factor * 0.8)
	# Win rate decreases slightly with more enemies
	scaled["win_rate"] = maxf(scaled["win_rate"] - (factor - 1.0) * 3.0, 30.0)
	# Resource usage increases
	scaled["revives_needed_rate"] = minf(scaled["revives_needed_rate"] + factor * 5.0, 99.0)
	scaled["items_needed_rate"] = minf(scaled["items_needed_rate"] + factor * 8.0, 99.0)
	return scaled
