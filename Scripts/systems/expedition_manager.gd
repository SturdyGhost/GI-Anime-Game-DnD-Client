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
	"Pyro": ["Sumeru", "Inazuma"],
	"Hydro": ["Liyue", "Inazuma"],
	"Electro": ["Inazuma", "Sumeru"],
	"Cryo": ["Mondstadt", "Liyue"],
	"Anemo": ["Mondstadt"],
	"Geo": ["Liyue"],
	"Dendro": ["Sumeru"],
}

static func generate_pool(region: String, pool_size: int = 5) -> Array:
	var templates = EXPEDITION_TEMPLATES.duplicate()
	templates.shuffle()
	var pool: Array = []
	var caches = LootGenerator.pick_caches(region, 4)
	for i in range(mini(pool_size, templates.size())):
		var tmpl = templates[i]
		var cache_idx = i % caches.size()
		var cache = caches[cache_idx]
		var cache_roll_val = cache.roll if cache is MaterialCacheData else int(cache.get("Roll", 1))
		var bonus_elem = ""
		for elem in ELEMENT_REGION_AFFINITY:
			if region in ELEMENT_REGION_AFFINITY[elem]:
				bonus_elem = elem
				break
		var data = {
			"name": tmpl["name_pattern"] % region,
			"region": region,
			"type": tmpl["type"],
			"description": tmpl["description"],
			"base_materials": tmpl["base_materials"],
			"cache_roll": cache_roll_val,
			"risk_level": tmpl["risk_level"],
			"bonus_region": region,
			"bonus_weapon": tmpl["bonus_weapon"],
			"bonus_element": bonus_elem,
		}
		pool.append(ExpeditionData.new(data))
	return pool

static func companion_bonus(companion: Dictionary, expedition: ExpeditionData) -> float:
	var bonus := 1.0
	if str(companion.get("Region", "")) == expedition.bonus_region:
		bonus += 0.25
	if str(companion.get("Weapon", "")) == expedition.bonus_weapon:
		bonus += 0.25
	if str(companion.get("Element", "")) == expedition.bonus_element:
		bonus += 0.2
	var lore: String = str(companion.get("Lore", companion.get("lore", ""))).to_lower()
	if expedition.expedition_type == "research" and ("scholar" in lore or "knowledge" in lore or "curious" in lore or "study" in lore):
		bonus += 0.15
	if expedition.expedition_type == "trade" and ("merchant" in lore or "shrewd" in lore or "business" in lore or "mora" in lore):
		bonus += 0.15
	if "diligent" in lore or "enthusiastic" in lore or "determined" in lore or "hardworking" in lore:
		bonus += 0.1
	if "lazy" in lore or "sleepy" in lore or "carefree" in lore:
		bonus -= 0.1
	return maxf(bonus, 0.5)

static func process_results(expedition: ExpeditionData, companion: Dictionary) -> Dictionary:
	var bonus = companion_bonus(companion, expedition)
	var region = expedition.region
	var cache = null
	for c in GameDB.material_caches.values():
		var c_region = c.region if c is MaterialCacheData else str(c.get("Region", ""))
		var c_roll = c.roll if c is MaterialCacheData else int(c.get("Roll", 0))
		if c_region == region and c_roll == expedition.cache_roll:
			cache = c
			break
	if cache == null:
		return {}
	var materials = LootGenerator.parse_materials(cache)
	var loot: Dictionary = {}
	var base_qty: int = expedition.base_materials
	var final_qty: int = maxi(int(ceil(base_qty * bonus)), 1)
	if expedition.risk_level == "moderate":
		if randf() < 0.1:
			return {}
	elif expedition.risk_level == "risky":
		if randf() < 0.3:
			return {}
		final_qty = int(ceil(final_qty * 1.5))
	for mat_name in materials:
		loot[mat_name] = final_qty
	return loot
