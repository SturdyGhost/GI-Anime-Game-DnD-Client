class_name ExpeditionManager
extends RefCounted

const EXPEDITION_TEMPLATES := [
	{"type": "foraging", "name_pattern": "Harvest the %s", "description": "Gather herbs and plants", "bonus_weapon": "Bow", "risk_level": "safe", "base_materials": 3},
	{"type": "mining", "name_pattern": "Mine the %s Deposits", "description": "Extract ore and minerals", "bonus_weapon": "Claymore", "risk_level": "safe", "base_materials": 3},
	{"type": "hunting", "name_pattern": "Hunt in the %s Wilds", "description": "Track and gather from creatures", "bonus_weapon": "Polearm", "risk_level": "moderate", "base_materials": 4},
	{"type": "research", "name_pattern": "Study the %s Ruins", "description": "Investigate ancient sites", "bonus_weapon": "Catalyst", "risk_level": "moderate", "base_materials": 4},
	{"type": "trade", "name_pattern": "Trade at the %s Market", "description": "Barter for rare goods", "bonus_weapon": "Sword", "risk_level": "safe", "base_materials": 3},
	{"type": "foraging", "name_pattern": "Deep %s Expedition", "description": "Venture deep for rare specimens", "bonus_weapon": "Bow", "risk_level": "risky", "base_materials": 6},
	{"type": "mining", "name_pattern": "Dangerous %s Caverns", "description": "Delve into unstable mines", "bonus_weapon": "Claymore", "risk_level": "risky", "base_materials": 6},
]

const ELEMENT_REGION_AFFINITY := {
	"Fire": ["Sumeru", "Inazuma"],
	"Water": ["Liyue", "Inazuma"],
	"Electric": ["Inazuma", "Sumeru"],
	"Ice": ["Mondstadt", "Liyue"],
	"Wind": ["Mondstadt"],
	"Earth": ["Liyue"],
	"Nature": ["Sumeru"],
}

const ALL_REGIONS := ["Mondstadt", "Liyue", "Inazuma", "Sumeru"]

## Returns all elements that have affinity with a region, shuffled.
static func _elements_for_region(region: String) -> Array:
	var elems: Array = []
	for elem in ELEMENT_REGION_AFFINITY:
		if region in ELEMENT_REGION_AFFINITY[elem]:
			elems.append(elem)
	elems.shuffle()
	return elems

static func generate_pool(region: String, pool_size: int = 5) -> Array:
	var templates = EXPEDITION_TEMPLATES.duplicate()
	templates.shuffle()
	var pool: Array = []

	# Pick regions: mostly current, with a chance of other regions
	var regions_for_pool: Array = []
	var other_regions: Array = ALL_REGIONS.filter(func(r): return r != region)
	other_regions.shuffle()
	for i in range(pool_size):
		if i < 3 or randf() > 0.4:
			regions_for_pool.append(region)
		else:
			regions_for_pool.append(other_regions[i % other_regions.size()])

	# Collect element pools per region so we rotate through them
	var region_elem_pools: Dictionary = {}

	for i in range(mini(pool_size, templates.size())):
		var tmpl = templates[i]
		var exp_region: String = regions_for_pool[i]
		var caches = LootGenerator.pick_caches(exp_region, 4)
		if caches.is_empty():
			caches = LootGenerator.pick_caches(region, 4)
			exp_region = region
		var cache_idx = i % caches.size()
		var cache = caches[cache_idx]
		var cache_roll_val = cache.roll if cache is MaterialCacheData else int(cache.get("Roll", 1))

		# Pick a bonus element, rotating through all matching elements for this region
		if not region_elem_pools.has(exp_region):
			region_elem_pools[exp_region] = _elements_for_region(exp_region)
		var elem_list: Array = region_elem_pools[exp_region]
		var bonus_elem = ""
		if elem_list.size() > 0:
			bonus_elem = elem_list[i % elem_list.size()]

		var data = {
			"name": tmpl["name_pattern"] % exp_region,
			"region": exp_region,
			"type": tmpl["type"],
			"description": tmpl["description"],
			"base_materials": tmpl["base_materials"],
			"cache_roll": cache_roll_val,
			"risk_level": tmpl["risk_level"],
			"bonus_region": exp_region,
			"bonus_weapon": tmpl["bonus_weapon"],
			"bonus_element": bonus_elem,
		}
		pool.append(ExpeditionData.new(data))
	return pool

## Returns { "total": float, "bonuses": Array[String] } with breakdown of all bonuses.
static func companion_bonus_detailed(companion: Dictionary, expedition: ExpeditionData) -> Dictionary:
	var total := 1.0
	var bonuses: Array = []

	if str(companion.get("Region", "")) == expedition.bonus_region:
		total += 0.25
		bonuses.append("Region match (%s) +25%%" % expedition.bonus_region)
	if str(companion.get("Weapon", "")) == expedition.bonus_weapon:
		total += 0.25
		bonuses.append("Weapon match (%s) +25%%" % expedition.bonus_weapon)
	if str(companion.get("Element", "")) == expedition.bonus_element:
		total += 0.2
		bonuses.append("Element match (%s) +20%%" % expedition.bonus_element)

	var lore: String = str(companion.get("Lore", companion.get("lore", ""))).to_lower()
	if expedition.expedition_type == "research" and ("scholar" in lore or "knowledge" in lore or "curious" in lore or "study" in lore):
		total += 0.15
		bonuses.append("Scholarly trait +15%%")
	if expedition.expedition_type == "trade" and ("merchant" in lore or "shrewd" in lore or "business" in lore or "mora" in lore):
		total += 0.15
		bonuses.append("Merchant trait +15%%")
	if "diligent" in lore or "enthusiastic" in lore or "determined" in lore or "hardworking" in lore:
		total += 0.1
		bonuses.append("Diligent trait +10%%")
	if "lazy" in lore or "sleepy" in lore or "carefree" in lore:
		total -= 0.1
		bonuses.append("Lazy trait -10%%")

	total = maxf(total, 0.5)
	return { "total": total, "bonuses": bonuses }

static func companion_bonus(companion: Dictionary, expedition: ExpeditionData) -> float:
	return companion_bonus_detailed(companion, expedition)["total"]

## Count how many category matches a companion has (region, weapon, element).
static func _count_matches(companion: Dictionary, expedition: ExpeditionData) -> int:
	var matches := 0
	if str(companion.get("Region", "")) == expedition.bonus_region:
		matches += 1
	if str(companion.get("Weapon", "")) == expedition.bonus_weapon:
		matches += 1
	if str(companion.get("Element", "")) == expedition.bonus_element:
		matches += 1
	return matches

## Process expedition with one companion (legacy, still used for single-companion).
static func process_results(expedition: ExpeditionData, companion: Dictionary) -> Dictionary:
	return process_multi_results(expedition, [companion])

## Process expedition with multiple companions. Bonuses add, rewards stay at base amount.
## Failure rate: safe=15%, moderate=60%, risky=90%, reduced by 5% per match across all companions.
static func process_multi_results(expedition: ExpeditionData, companions: Array) -> Dictionary:
	var region = expedition.region
	var cache = null
	for c in GameDB.material_caches.values():
		var c_region = c.region if c is MaterialCacheData else str(c.get("Region", ""))
		var c_roll = c.roll if c is MaterialCacheData else int(c.get("Roll", 0))
		if c_region == region and c_roll == expedition.cache_roll:
			cache = c
			break
	if cache == null:
		return {"_failed": true, "_bonus_total": 1.0, "_bonuses": []}

	# Combine bonuses: one base of 1.0 + each companion's bonus portion added
	var combined_bonus := 1.0  # single base
	var all_bonuses: Array = []
	var total_matches := 0
	for comp in companions:
		var info = companion_bonus_detailed(comp, expedition)
		# Add only the bonus portion (total - 1.0 base) from each companion
		combined_bonus += info["total"] - 1.0
		var comp_name = str(comp.get("Name", ""))
		for b in info["bonuses"]:
			all_bonuses.append("%s: %s" % [comp_name, b])
		total_matches += _count_matches(comp, expedition)

	combined_bonus = maxf(combined_bonus, 0.5)

	# Failure check — base rate reduced by 5% per match across all companions
	var base_failure: float
	match expedition.risk_level:
		"risky":
			base_failure = 0.90
		"moderate":
			base_failure = 0.60
		_:
			base_failure = 0.15
	var failure_rate: float = maxf(base_failure - (total_matches * 0.05), 0.0)
	var failed := randf() < failure_rate

	if failed:
		all_bonuses.append("Failure rate: %.0f%%" % (failure_rate * 100))
		return {"_failed": true, "_bonus_total": combined_bonus, "_bonuses": all_bonuses, "_failure_rate": failure_rate}

	# Base rewards * combined multiplier
	var materials = LootGenerator.parse_materials(cache)
	var base_qty: int = expedition.base_materials
	var final_qty: int = maxi(int(ceil(base_qty * combined_bonus)), 1)
	var loot: Dictionary = {}
	for mat_name in materials:
		loot[mat_name] = final_qty
	all_bonuses.append("Failure rate: %.0f%% (passed)" % (failure_rate * 100))
	loot["_bonus_total"] = combined_bonus
	loot["_bonuses"] = all_bonuses
	loot["_failure_rate"] = failure_rate
	return loot
