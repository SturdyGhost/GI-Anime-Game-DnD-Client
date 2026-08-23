class_name ExpeditionManager
extends RefCounted

## Expedition flavour. A template is now ONLY an identity: type, name and blurb.
## Weapon bonus, risk level and material yield are rolled per slot, so any type
## can turn up as a safe Bow run one pool and a risky Catalyst run the next.
##
## Names are split into `lead` + region + `tail` rather than one pattern so a
## risky run can slot an adjective in front of the region and still read as
## English: "Excavate the Perilous Sumeru Barrows", not "Perilous Excavate the".
const EXPEDITION_TEMPLATES := [
	{"type": "foraging",   "lead": "Harvest the",  "tail": "Groves",   "description": "Gather herbs and plants"},
	{"type": "mining",     "lead": "Mine the",     "tail": "Deposits", "description": "Extract ore and minerals"},
	{"type": "hunting",    "lead": "Hunt in the",  "tail": "Wilds",    "description": "Track and gather from creatures"},
	{"type": "research",   "lead": "Study the",    "tail": "Ruins",    "description": "Investigate ancient sites"},
	{"type": "trade",      "lead": "Trade at the", "tail": "Market",   "description": "Barter for rare goods"},
	{"type": "fishing",    "lead": "Fish the",     "tail": "Waters",   "description": "Work the shoals and still pools"},
	{"type": "salvage",    "lead": "Salvage the",  "tail": "Wreckage", "description": "Strip what the disasters left behind"},
	{"type": "escort",     "lead": "Escort a",     "tail": "Caravan",  "description": "See a merchant train safely through"},
	{"type": "survey",     "lead": "Chart the",    "tail": "Frontier", "description": "Map the ground nobody has walked"},
	{"type": "excavation", "lead": "Excavate the", "tail": "Barrows",  "description": "Dig out what was buried on purpose"},
	{"type": "patrol",     "lead": "Patrol the",   "tail": "Borders",  "description": "Walk the line and clear what's on it"},
	{"type": "diplomacy",  "lead": "Petition the", "tail": "Court",    "description": "Trade favours with those who hold them"},
	{"type": "bounty",     "lead": "Claim a",      "tail": "Bounty",   "description": "Collect on a posted contract"},
]

## Risk tier -> material yield. Riskier ALWAYS pays more; this is the only place
## base_materials comes from, so the two can never disagree.
const RISK_MATERIALS := {"safe": 3, "moderate": 4, "risky": 6}

## Adjectives used only when a slot rolls risky, so a name never promises danger
## the risk level doesn't back up ("Dangerous Caverns — Risk: safe").
const RISKY_ADJECTIVES := ["Deep", "Dangerous", "Perilous", "Treacherous"]

## Every weapon can headline any expedition type now, so the bonus is rolled.
const BONUS_WEAPONS := ["Sword", "Claymore", "Polearm", "Bow", "Catalyst"]

## A pool may contain at most ONE duplicated type (two mining runs, never three,
## and never two separate duplicated types). This is how often that happens.
const TYPE_REPEAT_CHANCE := 0.25

## Slots 0-1 always draw the party's current region. Later slots roll for it.
const GUARANTEED_HOME_SLOTS := 2
const HOME_REGION_CHANCE := 0.6

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


## Pick the templates for one pool: `count` entries, all distinct except that a
## single type may be duplicated (TYPE_REPEAT_CHANCE of the time).
static func _pick_templates(count: int) -> Array:
	var deck: Array = EXPEDITION_TEMPLATES.duplicate()
	deck.shuffle()

	var unique_wanted: int = mini(count, deck.size())
	var allow_repeat: bool = (
		count > 1
		and deck.size() >= count - 1
		and randf() < TYPE_REPEAT_CHANCE
	)
	if allow_repeat:
		unique_wanted = mini(count - 1, deck.size())

	var picked: Array = deck.slice(0, unique_wanted)
	while picked.size() < count:
		# Duplicate one already-picked type rather than reaching for a new one.
		picked.append(picked[randi() % maxi(picked.size(), 1)])
	picked.shuffle()
	return picked


## One risk tier per slot. Every pool is guaranteed at least one safe, one
## moderate and one risky; any slots beyond those three roll freely. Shuffled so
## the guaranteed tiers don't always land in the same positions.
static func _roll_risk_levels(count: int) -> Array:
	var tiers: Array = RISK_MATERIALS.keys()
	var levels: Array = []
	for tier in tiers:
		if levels.size() < count:
			levels.append(tier)
	while levels.size() < count:
		levels.append(tiers[randi() % tiers.size()])
	levels.shuffle()
	return levels


## Unused caches for a region, as an Array. Consumes nothing — the caller marks
## what it takes in `used_cache_ids`.
static func _unused_caches(region: String, used_cache_ids: Dictionary) -> Array:
	var out: Array = []
	for cache in LootGenerator.pick_caches(region, 99):
		if not used_cache_ids.has(_cache_id(cache)):
			out.append(cache)
	return out


## Stable identity for a cache, so "Sumeru cache 2" can be struck off the list
## once it has been handed to a slot.
static func _cache_id(cache) -> String:
	if cache is MaterialCacheData:
		return "%s#%d" % [cache.region, cache.id]
	return "%s#%s" % [str(cache.get("Region", "")), str(cache.get("id", cache.get("Roll", 0)))]


static func _cache_roll(cache) -> int:
	return cache.roll if cache is MaterialCacheData else int(cache.get("Roll", 1))


## Choose the region for one slot, given which caches are already spoken for.
##
## Slots 0-1 are the party's current region; later slots take it with
## HOME_REGION_CHANCE. Either way the choice only stands if that region still has
## an unused cache — once home is exhausted (there are only 4 caches per region,
## so with 5 slots that always happens) the slot is forced abroad.
## Returns "" when every region is exhausted.
static func _pick_region(slot: int, home: String, used_cache_ids: Dictionary) -> String:
	var home_open: bool = not _unused_caches(home, used_cache_ids).is_empty()
	var wants_home: bool = slot < GUARANTEED_HOME_SLOTS or randf() < HOME_REGION_CHANCE

	if wants_home and home_open:
		return home

	var others: Array = ALL_REGIONS.filter(func(r): return r != home)
	others.shuffle()
	for r in others:
		if not _unused_caches(r, used_cache_ids).is_empty():
			return r

	# Nowhere else left — fall back home if it still has anything.
	return home if home_open else ""


## "Excavate the Sumeru Barrows", or with the risk adjective folded in before the
## region, "Excavate the Perilous Sumeru Barrows".
static func _build_name(tmpl: Dictionary, region: String, risk: String) -> String:
	var middle: String = region
	if risk == "risky":
		middle = "%s %s" % [RISKY_ADJECTIVES[randi() % RISKY_ADJECTIVES.size()], region]
	return "%s %s %s" % [str(tmpl["lead"]), middle, str(tmpl["tail"])]


static func generate_pool(region: String, pool_size: int = 5) -> Array:
	var templates: Array = _pick_templates(pool_size)
	var risks: Array = _roll_risk_levels(pool_size)
	var pool: Array = []

	# Caches are unique across the WHOLE pool: once a slot takes Sumeru cache 2,
	# no other slot may offer it, in any region.
	var used_cache_ids: Dictionary = {}
	var region_elem_pools: Dictionary = {}

	for i in range(pool_size):
		if i >= templates.size():
			break

		var exp_region: String = _pick_region(i, region, used_cache_ids)
		if exp_region == "":
			break  # every cache in the game is spoken for

		var available: Array = _unused_caches(exp_region, used_cache_ids)
		if available.is_empty():
			break
		var cache = available[randi() % available.size()]
		used_cache_ids[_cache_id(cache)] = true

		var tmpl: Dictionary = templates[i]
		var risk: String = str(risks[i])

		# Pick a bonus element, rotating through all matching elements for this region
		if not region_elem_pools.has(exp_region):
			region_elem_pools[exp_region] = _elements_for_region(exp_region)
		var elem_list: Array = region_elem_pools[exp_region]
		var bonus_elem: String = ""
		if elem_list.size() > 0:
			bonus_elem = str(elem_list[i % elem_list.size()])

		var exp_name: String = _build_name(tmpl, exp_region, risk)

		pool.append(ExpeditionData.new({
			"name": exp_name,
			"region": exp_region,
			"type": tmpl["type"],
			"description": tmpl["description"],
			"base_materials": int(RISK_MATERIALS.get(risk, 3)),
			"cache_roll": _cache_roll(cache),
			"risk_level": risk,
			"bonus_region": exp_region,
			"bonus_weapon": BONUS_WEAPONS[randi() % BONUS_WEAPONS.size()],
			"bonus_element": bonus_elem,
		}))
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
