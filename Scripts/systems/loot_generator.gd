class_name LootGenerator
extends RefCounted

# Enemy tier → difficulty score
const TIER_SCORES := {
	"common": 1, "Common": 1,
	"uncommon": 2, "Uncommon": 2,
	"rare": 5, "Rare": 5,
	"epic": 8, "Epic": 8,
	"world_boss": 25, "World Boss": 25,
	"story_boss": 25, "Story Boss": 25,
	"legendary": 40, "Legendary": 40,
}

# Score thresholds → {loot_tier, min_qty, max_qty, cache_count}
const LOOT_TIERS := [
	{"min_score": 40, "tier": "Abundant", "min_qty": 16, "max_qty": 20, "caches": 2},
	{"min_score": 25, "tier": "Rich",     "min_qty": 11, "max_qty": 15, "caches": 2},
	{"min_score": 16, "tier": "Moderate",  "min_qty": 7,  "max_qty": 10, "caches": 1},
	{"min_score": 6,  "tier": "Light",     "min_qty": 4,  "max_qty": 6,  "caches": 1},
	{"min_score": 3,  "tier": "Scraps",    "min_qty": 2,  "max_qty": 3,  "caches": 1},
]

## Calculate total difficulty score from enemy list.
## enemies: Array of Dictionaries with "tier" key (from Global.BATTLEENEMIES snapshot)
static func calc_difficulty_score(enemies: Array) -> int:
	var score := 0
	for enemy in enemies:
		var tier_str := str(enemy.get("tier", "common"))
		score += TIER_SCORES.get(tier_str, 1)
	return score

## Get the loot tier config for a given score. Returns null if no loot.
static func get_loot_tier(score: int) -> Variant:
	for tier in LOOT_TIERS:
		if score >= tier["min_score"]:
			return tier
	return null

## Apply luck modifier to base quantity.
## luck: player's effective daily luck (0-100)
static func apply_luck(base_qty: int, luck: int) -> int:
	if luck >= 85:
		return base_qty + 2
	elif luck >= 70:
		return base_qty + 1
	elif luck <= 10:
		return maxi(base_qty - 2, 0)
	elif luck <= 25:
		return maxi(base_qty - 1, 0)
	return base_qty

## Pick N unique random caches for a region.
## Returns Array of MaterialCacheData.
static func pick_caches(region: String, count: int) -> Array:
	var region_caches: Array = []
	for cache in GameDB.material_caches.values():
		var cache_region: String = ""
		if cache is MaterialCacheData:
			cache_region = cache.region
		else:
			cache_region = str(cache.get("Region", ""))
		if cache_region == region:
			region_caches.append(cache)
	region_caches.shuffle()
	return region_caches.slice(0, mini(count, region_caches.size()))

## Parse the materials string from a cache into an Array of material names.
static func parse_materials(cache) -> Array:
	var mat_str: String = ""
	if cache is MaterialCacheData:
		mat_str = cache.materials
	elif cache is Dictionary:
		mat_str = str(cache.get("materials", cache.get("Materials", "")))
	# Strip surrounding brackets (material lists stored as "[Item1,Item2]")
	mat_str = mat_str.strip_edges()
	if mat_str.begins_with("["):
		mat_str = mat_str.substr(1)
	if mat_str.ends_with("]"):
		mat_str = mat_str.substr(0, mat_str.length() - 1)
	var mats: Array = []
	for m in mat_str.split(","):
		var trimmed = m.strip_edges()
		if trimmed != "":
			mats.append(trimmed)
	return mats

## Generate loot for a single player.
## Returns: Dictionary { "material_name": quantity, ... } or empty if no loot.
static func generate_player_loot(score: int, region: String, luck: int) -> Dictionary:
	var tier = get_loot_tier(score)
	if tier == null:
		return {}
	var base_qty: int = randi_range(tier["min_qty"], tier["max_qty"])
	var final_qty: int = apply_luck(base_qty, luck)
	if final_qty <= 0:
		return {}
	var caches = pick_caches(region, tier["caches"])
	var loot: Dictionary = {}
	for cache in caches:
		var materials = parse_materials(cache)
		for mat_name in materials:
			loot[mat_name] = loot.get(mat_name, 0) + final_qty
	return loot

## Generate loot for all players in the party.
## Returns: Dictionary { "player_name": { "material_name": qty, ... }, ... }
static func generate_all_loot(enemies: Array, region: String) -> Dictionary:
	var score = calc_difficulty_score(enemies)
	var all_loot: Dictionary = {}
	for char in Global.CHARACTERS.values():
		if str(char.get("User_Type", "")) == "Dungeon Master":
			continue
		var name: String = str(char.get("Name", ""))
		var luck: int = Global.get_effective_luck(name)
		all_loot[name] = generate_player_loot(score, region, luck)
	return all_loot
