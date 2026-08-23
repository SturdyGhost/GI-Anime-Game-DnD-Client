extends Node
## ReputationManager — trait-vector reputation across three layers (Region, Faction,
## Individual). Actions are tagged per player; the world reacts to the PARTY as the
## aggregate. Trait points decay at a severity-scaled half-life, computed at read-time
## (storage is permanent/append-only). See data/reputation/*.json for catalogs.

signal reputation_changed
signal clock_advanced(new_day: int)

const TABLE := "Reputation_Events"

# ── Calendar (7d/week, 30d/month, 365d/year; Year is 1-indexed) ───────────────
const DAYS_PER_MONTH := 30
const DAYS_PER_YEAR := 365
const DEFAULT_START_DAY := 835   # → "Year 3 · Month 4 · Day 16"

# ── Severity → decay half-life (days). Anchor points, linearly interpolated;
#    steepens hard at the top so severe acts are effectively campaign-permanent. ──
const HL_ANCHORS := [
	[0.0, 14.0], [0.05, 30.0], [0.2, 180.0], [0.4, 600.0],
	[0.7, 1825.0], [0.95, 3650.0], [1.0, 5475.0],
]

# ── Loaded definition catalogs ────────────────────────────────────────────────
var _traits: Dictionary = {}     # name -> {Name, Category, Valence}
var _regions: Dictionary = {}    # name -> {Name, Profile{}}
var _factions: Dictionary = {}   # name -> {Name, Region, Region_Sensitivity, Weights{}}
var _npcs: Dictionary = {}       # name -> {Name, Faction, Personal_Weights{}, Region_Sensitivity?}
var _actions: Dictionary = {}    # id -> {Id, Label, Emissions[]}

func _ready() -> void:
	_load_catalogs()

# =============================================================================
# CATALOG LOADING
# =============================================================================
func _load_catalogs() -> void:
	for e in _load_json("res://data/reputation/traits.json").get("traits", []):
		_traits[str(e.get("Name", ""))] = e
	for e in _load_json("res://data/reputation/regions.json").get("regions", []):
		_regions[str(e.get("Name", ""))] = e
	for e in _load_json("res://data/reputation/factions.json").get("factions", []):
		_factions[str(e.get("Name", ""))] = e
	for e in _load_json("res://data/reputation/npcs.json").get("npcs", []):
		_npcs[str(e.get("Name", ""))] = e
	for e in _load_json("res://data/reputation/actions.json").get("actions", []):
		_actions[str(e.get("Id", ""))] = e

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("ReputationManager: missing catalog %s" % path)
		return {}
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return {}
	var txt := fa.get_as_text()
	fa.close()
	var parsed = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return []
	var txt := fa.get_as_text()
	fa.close()
	var parsed = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_ARRAY else []

## DM-only: wipe all reputation events and reload the bundled campaign-history
## default. Lets the DM pick up seed edits without discarding the rest of the
## save. Host-authoritative — broadcasts the fresh table to clients.
func reseed_from_defaults() -> bool:
	if not NetworkManager.is_host:
		push_warning("ReputationManager.reseed_from_defaults: host only")
		return false
	var arr := _load_json_array("res://data/Reputation_Events.json")
	CanonicalSave.replace_table(TABLE, arr)
	DataStore.persist_table(TABLE)
	NetworkManager.broadcast_table_update(TABLE)
	emit_signal("reputation_changed")
	return true

func trait_valence(trait_name: String) -> int:
	return int(_traits.get(trait_name, {}).get("Valence", 0))

# =============================================================================
# CALENDAR
# =============================================================================
func current_day() -> int:
	return int(Global.Current_Party.get("Campaign_Day", DEFAULT_START_DAY))

## Format a day count as "Year Y · Month M · Day D" (Year/Month/Day all 1-indexed).
func fmt_day(day: int = -1) -> String:
	var d := current_day() if day < 0 else day
	var year := d / DAYS_PER_YEAR + 1
	var rem := d % DAYS_PER_YEAR
	var month := mini(rem / DAYS_PER_MONTH + 1, 12)
	var dom := rem % DAYS_PER_MONTH + 1
	return "Year %d · Month %d · Day %d" % [year, month, dom]

## Advance the campaign clock (host writes the Party record; everyone syncs).
func advance_days(n: int) -> void:
	var party: Dictionary = Global.Current_Party
	var pid := int(party.get("id", 1))
	var cur := int(party.get("Campaign_Day", DEFAULT_START_DAY))
	Global.Update_Records([{"table": "Party", "record_id": pid, "field": "Campaign_Day", "value": cur + n}])
	emit_signal("clock_advanced", cur + n)

# =============================================================================
# DECAY
# =============================================================================
func _half_life(severity: float) -> float:
	var s := clampf(severity, 0.0, 1.0)
	for i in range(HL_ANCHORS.size() - 1):
		var a = HL_ANCHORS[i]
		var b = HL_ANCHORS[i + 1]
		if s <= float(b[0]):
			var span: float = float(b[0]) - float(a[0])
			var t := (s - float(a[0])) / span if span > 0.0 else 0.0
			return lerp(float(a[1]), float(b[1]), t)
	return float(HL_ANCHORS[-1][1])

func _decayed(points: float, severity: float, age_days: float) -> float:
	if age_days <= 0.0:
		return points
	return points * pow(0.5, age_days / _half_life(severity))

# =============================================================================
# AGGREGATION
# =============================================================================
func _party_members() -> Array:
	return Global.PartyCharacters

## Decayed trait vector for a viewpoint in a region. actor="" → the whole party
## (every deed). actor="<name>" → that member's IDENTITY: the shared party deeds
## (Actor "Party"/blank) PLUS their own personal deeds, but NOT a teammate's
## personal deeds. So the party is the baseline and each member's own actions
## move them off it — without one member's quirks bleeding onto another.
func trait_vector(region: String, actor: String = "") -> Dictionary:
	var now := current_day()
	var vec: Dictionary = {}
	for rec in Global.REPUTATION_EVENTS.values():
		var tn := str(rec.get("Trait", ""))
		if tn == "":
			continue  # standing event, not a trait emission
		if region != "" and str(rec.get("Region", "")) != region:
			continue
		if actor != "":
			var ra := str(rec.get("Actor", ""))
			if ra != "Party" and ra != "" and ra != actor:
				continue
		var age := float(now - int(rec.get("Campaign_Day", now)))
		vec[tn] = vec.get(tn, 0.0) + _decayed(float(rec.get("Points", 0)), float(rec.get("Severity", 0.5)), age)
	return vec

func party_trait_vector(region: String) -> Dictionary:
	return trait_vector(region, "")

func member_trait_vector(actor: String, region: String) -> Dictionary:
	return trait_vector(region, actor)

## Top-N traits as [{trait, weight, valence}], highest weight first.
func word_cloud(vector: Dictionary, top_n: int = 6) -> Array:
	var arr: Array = []
	for t in vector:
		arr.append({"trait": t, "weight": vector[t], "valence": trait_valence(t)})
	arr.sort_custom(func(a, b): return a.weight > b.weight)
	return arr.slice(0, top_n)

func party_word_cloud(region: String, top_n: int = 6) -> Array:
	return word_cloud(party_trait_vector(region), top_n)

func member_word_cloud(actor: String, region: String, top_n: int = 6) -> Array:
	return word_cloud(member_trait_vector(actor, region), top_n)

func _dot(vec: Dictionary, weights: Dictionary) -> float:
	var s := 0.0
	for t in vec:
		s += float(vec[t]) * float(weights.get(t, 0.0))
	return s

## Decayed sum of standing deeds for a scope. actor="" → party-wide deeds only
## (Actor "Party"/blank); actor="<name>" → only that member's personal deeds. So
## a party baseline and a per-member adjustment never double-count each other.
func _standing_total(scope_type: String, scope: String, actor: String) -> float:
	var now := current_day()
	var total := 0.0
	for rec in Global.REPUTATION_EVENTS.values():
		if str(rec.get("Scope_Type", "")) != scope_type or str(rec.get("Scope", "")) != scope:
			continue
		var ra := str(rec.get("Actor", ""))
		if actor == "":
			if ra != "" and ra != "Party":
				continue
		elif ra != actor:
			continue
		var age := float(now - int(rec.get("Campaign_Day", now)))
		total += _decayed(float(rec.get("Standing", 0)), float(rec.get("Severity", 0.5)), age)
	return total

## A region judges the party through its OWN value profile (standalone), plus any
## region-scoped standing deeds.
func region_opinion(region: String) -> float:
	var rdef: Dictionary = _regions.get(region, {})
	var score := _dot(party_trait_vector(region), rdef.get("Profile", {}))
	score += _standing_total("Region", region, "")
	return score

## Compose a faction's effective weights by walking its Parent chain (parent
## first, children add their emphasis on top). So a Harbinger cell inherits the
## Fatui's lens and deviates from it.
func _composed_faction_weights(faction_name: String) -> Dictionary:
	var w: Dictionary = {}
	var cur := faction_name
	var guard := 0
	while cur != "" and _factions.has(cur) and guard < 12:
		var fw: Dictionary = _factions[cur].get("Weights", {})
		for t in fw:
			w[t] = w.get(t, 0.0) + float(fw[t])
		cur = str(_factions[cur].get("Parent", ""))
		guard += 1
	return w

## The region a faction is judged in: its own Region, or — for "Global"/blank
## factions — the contextual region the caller passes (where the interaction
## happens). Lets a Fatui agent in Liyue judge you by your Liyue reputation.
func _faction_region(faction_name: String, ctx_region: String) -> String:
	var r := str(_factions.get(faction_name, {}).get("Region", ""))
	if r == "" or r == "Global":
		return ctx_region
	return r

func _faction_region_sensitivity(faction_name: String) -> float:
	return float(_factions.get(faction_name, {}).get("Region_Sensitivity", 0.0))

## Faction opinion = the faction's composed lens on the party identity + the
## region baseline leaking in (scaled by Region_Sensitivity) + faction ledger.
func faction_opinion(faction_name: String, ctx_region: String = "") -> float:
	var region := _faction_region(faction_name, ctx_region)
	var score := _dot(party_trait_vector(region), _composed_faction_weights(faction_name))
	score += region_opinion(region) * _faction_region_sensitivity(faction_name)
	score += _standing_total("Faction", faction_name, "")
	return score

## NPC disposition. Inherits region + faction (composed up the Parent chain),
## adds the individual's personal trait variance, then — if an actor is given —
## that member's divergence from the party and personal history with this NPC.
func npc_disposition(npc_name: String, ctx_region: String = "", actor: String = "") -> float:
	var npc: Dictionary = _npcs.get(npc_name, {})
	if npc.is_empty():
		return 0.0
	var fac := str(npc.get("Faction", ""))
	var region := _faction_region(fac, ctx_region)
	var party_vec := party_trait_vector(region)
	# Full lens: composed faction weights + this person's personal variance.
	var lens := _composed_faction_weights(fac)
	var pw: Dictionary = npc.get("Personal_Weights", {})
	for t in pw:
		lens[t] = lens.get(t, 0.0) + float(pw[t])

	# 1) inherited + personal interpretation of the party identity
	var score := _dot(party_vec, lens)
	# 2) region baseline leaks in via the faction's sensitivity
	var rsens := float(npc.get("Region_Sensitivity", _faction_region_sensitivity(fac)))
	score += region_opinion(region) * rsens
	# 3) party-level faction standing ledger
	score += _standing_total("Faction", fac, "")
	# 4) per-member divergence + personal grudge/favor (falls back to party if none)
	if actor != "":
		var count := maxi(_party_members().size(), 1)
		var mv := member_trait_vector(actor, region)
		var keys: Dictionary = {}
		for t in mv:
			keys[t] = true
		for t in party_vec:
			keys[t] = true
		var div: Dictionary = {}
		for t in keys:
			div[t] = float(mv.get(t, 0.0)) - float(party_vec.get(t, 0.0)) / float(count)
		score += _dot(div, lens)
		score += _standing_total("Individual", npc_name, actor)
	return score

# =============================================================================
# NORMALIZED STANDING, LABELS & CONSEQUENCES
# =============================================================================
## Alignment of a trait vector with a weight set, in [-1, 1]: of the traits the
## viewer actually cares about (weighted by how much reputation the party has in
## each), how favorable vs unfavorable. +1 = everything they prize, -1 =
## everything they despise, 0 = mixed/unknown. Magnitude-independent so a famous
## and an obscure party are judged on the same scale.
func _align(pv: Dictionary, weights: Dictionary) -> float:
	var num := 0.0
	var den := 0.0
	for t in weights:
		var w := float(weights[t])
		if w == 0.0:
			continue
		var p := float(pv.get(t, 0.0))
		num += p * w
		den += absf(p) * absf(w)
	if den <= 0.0:
		return 0.0
	return clampf(num / den, -1.0, 1.0)

## Nudge from explicit standing-deed events (war ledgers, grudges/favors). Scaled
## so a decisive authored deed (e.g. "you got our leader killed") can fully
## override trait-alignment and drive standing to the Hostile/Honored extreme.
func _standing_nudge(scope_type: String, scope: String, actor: String) -> float:
	return clampf(_standing_total(scope_type, scope, actor) / 50.0, -2.5, 2.5)

const DISPO_TIERS := [[0.6, "Honored"], [0.2, "Friendly"], [-0.2, "Neutral"], [-0.6, "Wary"]]
func disposition_label(standing: float) -> String:
	for tier in DISPO_TIERS:
		if standing >= float(tier[0]):
			return str(tier[1])
	return "Hostile"

## How a region regards the party (~[-1, 1]) — its own value lens + region-scoped
## standing deeds. With `actor`, the party is the baseline and it shifts toward
## that member (their trait divergence + their personal region-standing deeds),
## e.g. Dylan's marriage lifting him above the party's Inazuma standing.
func region_standing(region: String, actor: String = "") -> float:
	var profile: Dictionary = region_def(region).get("Profile", {})
	var s := _align(trait_vector(region, actor), profile)
	s += _standing_nudge("Region", region, "")
	if actor != "":
		s += _standing_nudge("Region", region, actor)
	return clampf(s, -1.5, 1.5)

## Faction standing: its own composed lens, pulled toward the regional baseline
## by its Region_Sensitivity, plus ledger nudge. With `actor`, shifts toward that
## member's divergence and personal faction-standing deeds.
func faction_standing(faction_name: String, ctx_region: String = "", actor: String = "") -> float:
	var region := _faction_region(faction_name, ctx_region)
	var pv := trait_vector(region, actor)
	var lens := _composed_faction_weights(faction_name)
	var sens := clampf(_faction_region_sensitivity(faction_name), 0.0, 1.0)
	var base: float = lerp(_align(pv, lens), _align(pv, region_def(region).get("Profile", {})), sens)
	base += _standing_nudge("Faction", faction_name, "")
	if actor != "":
		base += _standing_nudge("Faction", faction_name, actor)
	return clampf(base, -1.5, 1.5)

## NPC standing: inherits region + faction (composed up the Parent chain) + this
## person's personal trait variance, then shifts toward the named member's own
## identity and personal history (0 shift if they match the party / have none).
func npc_standing(npc_name: String, ctx_region: String = "", actor: String = "") -> float:
	var npc: Dictionary = _npcs.get(npc_name, {})
	if npc.is_empty():
		return 0.0
	var fac := str(npc.get("Faction", ""))
	var region := _faction_region(fac, ctx_region)
	var pv := trait_vector(region, actor)
	var lens := _composed_faction_weights(fac)
	for t in npc.get("Personal_Weights", {}):
		lens[t] = lens.get(t, 0.0) + float(npc["Personal_Weights"][t])
	var sens := clampf(float(npc.get("Region_Sensitivity", _faction_region_sensitivity(fac))), 0.0, 1.0)
	var base: float = lerp(_align(pv, lens), _align(pv, region_def(region).get("Profile", {})), sens)
	base += _standing_nudge("Faction", fac, "")
	base += _standing_nudge("Individual", npc_name, "")  # party-level personal favor/grudge
	if actor != "":
		base += _standing_nudge("Faction", fac, actor)
		base += _standing_nudge("Individual", npc_name, actor)
	return clampf(base, -1.5, 1.5)

## Market price multiplier for a buyer. Revered → steep discount (to 0.6x);
## disliked → massive markup (to 2.5x), asymmetric because merchants gouge those
## they resent harder than they reward favourites. Per-buyer: `player`'s own
## regional standing is used, so a beloved member pays less than a hated one.
func market_price_modifier(region: String, player: String = "") -> float:
	var s := region_standing(region, player)
	if s >= 0.0:
		return lerp(1.0, 0.6, clampf(s / 1.5, 0.0, 1.0))
	return lerp(1.0, 2.5, clampf(-s / 1.5, 0.0, 1.0))

## Reward multiplier for loot/expeditions: revered locals help you reap more
## (up to +40%); a region that resents you yields less (down to -50%). 1.0 = neutral.
func reward_modifier(region: String, actor: String = "") -> float:
	var s := region_standing(region, actor)
	if s >= 0.0:
		return lerp(1.0, 1.4, clampf(s / 1.5, 0.0, 1.0))
	return lerp(1.0, 0.5, clampf(-s / 1.5, 0.0, 1.0))

## Whether the party could avoid a fight with a faction by standing alone — true
## when the faction regards them highly enough. A 'bad-loving' faction rates a
## brutal party highly, so cruelty can open this door as readily as heroism.
func can_bypass_encounter(faction_name: String, ctx_region: String = "", threshold: float = 0.3) -> bool:
	return faction_standing(faction_name, ctx_region) >= threshold

# =============================================================================
# CONTRIBUTION BREAKDOWN (powers the UI "why do they feel this way?" expansion)
# =============================================================================
func action_label(action_id: String) -> String:
	return str(_actions.get(action_id, {}).get("Label", action_id))

## The composed lens a faction judges through (its own weights + parent chain).
func faction_lens(faction_name: String) -> Dictionary:
	return _composed_faction_weights(faction_name)

## The full lens an NPC judges through (faction composed + personal variance).
func npc_lens(npc_name: String) -> Dictionary:
	var npc: Dictionary = _npcs.get(npc_name, {})
	var lens := _composed_faction_weights(str(npc.get("Faction", "")))
	for t in npc.get("Personal_Weights", {}):
		lens[t] = lens.get(t, 0.0) + float(npc["Personal_Weights"][t])
	return lens

## The region a faction/NPC is actually judged in (own region, or ctx if global).
func ctx_region_for(faction_name: String, ctx_region: String) -> String:
	return _faction_region(faction_name, ctx_region)

## Per-deed contributions to a viewer's opinion: trait events in `region` whose
## trait this viewer weights, grouped by the action that produced them. Positive
## value endears the party to them; negative offends. Sorted by impact.
func deed_contributions(weights: Dictionary, region: String, actor: String = "") -> Array:
	var now := current_day()
	var by_action: Dictionary = {}
	for rec in Global.REPUTATION_EVENTS.values():
		var tn := str(rec.get("Trait", ""))
		if tn == "" or str(rec.get("Region", "")) != region:
			continue
		if actor != "":
			var ra := str(rec.get("Actor", ""))
			if ra != "Party" and ra != "" and ra != actor:
				continue
		var w := float(weights.get(tn, 0.0))
		if w == 0.0:
			continue
		var age := float(now - int(rec.get("Campaign_Day", now)))
		var c := _decayed(float(rec.get("Points", 0)), float(rec.get("Severity", 0.5)), age) * w
		var aid := str(rec.get("Source_Action", "deed"))
		if not by_action.has(aid):
			by_action[aid] = {"value": 0.0, "traits": {}}
		by_action[aid]["value"] = float(by_action[aid]["value"]) + c
		by_action[aid]["traits"][tn] = true
	var out: Array = []
	for aid in by_action:
		out.append({"label": action_label(aid), "value": by_action[aid]["value"], "traits": by_action[aid]["traits"].keys()})
	out.sort_custom(func(a, b): return absf(a.value) > absf(b.value))
	return out

## The traits that actually drive a viewer's feeling, by IMPACT (how much the
## party exhibits the trait × how strongly the viewer weights it) — not by raw
## frequency. Each: {trait, value}; value>0 = endears, value<0 = offends. Traits
## the viewer is indifferent to (weight 0) are omitted, so the pills reflect the
## real drivers rather than cluttering with "neutral" prominent traits.
func viewer_pills(weights: Dictionary, region: String, top_n: int = 8, actor: String = "") -> Array:
	var pv := trait_vector(region, actor)
	var arr: Array = []
	for t in weights:
		var w := float(weights[t])
		if w == 0.0:
			continue
		var p := float(pv.get(t, 0.0))
		if p == 0.0:
			continue
		arr.append({"trait": t, "value": p * w})
	arr.sort_custom(func(a, b): return absf(a.value) > absf(b.value))
	return arr.slice(0, top_n)

## Authored standing-event contributions for a scope (the grudges/favors).
func standing_contributions(scope_type: String, scope: String) -> Array:
	var now := current_day()
	var out: Array = []
	for rec in Global.REPUTATION_EVENTS.values():
		if str(rec.get("Scope_Type", "")) != scope_type or str(rec.get("Scope", "")) != scope:
			continue
		var age := float(now - int(rec.get("Campaign_Day", now)))
		var v := _decayed(float(rec.get("Standing", 0)), float(rec.get("Severity", 0.5)), age) / 50.0
		out.append({"label": str(rec.get("Note", "%s standing" % scope_type)), "value": v, "traits": []})
	out.sort_custom(func(a, b): return absf(a.value) > absf(b.value))
	return out

# =============================================================================
# RECORDING (host-authoritative; broadcast like everything else)
# =============================================================================
func record_trait(actor: String, region: String, trait_name: String, points: float, severity: float) -> void:
	_commit_record({
		"Actor": actor, "Region": region, "Trait": trait_name,
		"Points": points, "Severity": severity, "Campaign_Day": current_day(),
	})

func record_standing(actor: String, scope_type: String, scope: String, amount: float, severity: float) -> void:
	_commit_record({
		"Actor": actor, "Scope_Type": scope_type, "Scope": scope,
		"Standing": amount, "Severity": severity, "Campaign_Day": current_day(),
	})

## Fire an authored action: emit its whole bundle of trait deltas for one actor.
func apply_action(action_id: String, actor: String, region: String) -> void:
	var adef: Dictionary = _actions.get(action_id, {})
	if adef.is_empty():
		push_warning("ReputationManager: unknown action '%s'" % action_id)
		return
	for e in adef.get("Emissions", []):
		record_trait(actor, region, str(e.get("Trait", "")), float(e.get("Points", 0)), float(e.get("Severity", 0.5)))

## Expedition type → the reputation it earns the owner. Deliberately divisive:
## mining/hunting please industrious/survivalist viewers but read as Despoiler/
## Poacher to nature-stewards (Forest Watchers, the Adepti). Each: [trait,pts,sev].
const _EXPEDITION_IMPACT := {
	"foraging": [["Steward", 6, 0.25], ["Diligent", 4, 0.20]],
	"mining":   [["Industrious", 6, 0.25], ["Despoiler", 5, 0.30]],
	"hunting":  [["Skilled Hunter", 6, 0.25], ["Poacher", 6, 0.30]],
	"research": [["Scholarly", 7, 0.30], ["Wise", 4, 0.25]],
	"trade":    [["Entrepreneurial", 7, 0.30], ["Shrewd", 4, 0.25]],
}

## Fire the reputation consequence of an expedition the owner ran in a region.
## Attributed to the owner (per-player), so each member's choices shape their own
## standing — and the same expedition pleases some factions while angering others.
func apply_expedition(owner: String, region: String, exp_type: String) -> void:
	for e in _EXPEDITION_IMPACT.get(str(exp_type).to_lower(), []):
		record_trait(owner, region, str(e[0]), float(e[1]), float(e[2]))

func _commit_record(rec: Dictionary) -> void:
	rec["created_at"] = Time.get_datetime_string_from_system()
	if not NetworkManager.is_host:
		NetworkManager.request_insert.rpc_id(1, TABLE, JSON.stringify(rec), "rep-%d" % Time.get_ticks_msec())
		return
	var id := Global._next_offline_id(TABLE)
	rec["id"] = id
	Global._insert_record(TABLE, str(id), rec)
	ChangeLog.append_insert("ReputationManager", TABLE, id, rec)
	DataStore.persist_table(TABLE)
	NetworkManager.broadcast_record_update(TABLE, str(id), rec)
	emit_signal("reputation_changed")

# =============================================================================
# CATALOG ACCESSORS (for UI / DM tools)
# =============================================================================
func all_traits() -> Array: return _traits.values()
func all_actions() -> Array: return _actions.values()
func all_regions() -> Array: return _regions.values()
func all_factions() -> Array: return _factions.values()
func all_npcs() -> Array: return _npcs.values()
func faction_names() -> Array: return _factions.keys()
func region_names() -> Array: return _regions.keys()
func npc_names() -> Array: return _npcs.keys()
func region_def(n: String) -> Dictionary: return _regions.get(n, {})
func faction_def(n: String) -> Dictionary: return _factions.get(n, {})
func npc_def(n: String) -> Dictionary: return _npcs.get(n, {})

## Most-recent reputation events first (by in-game day, then insertion). For the
## DM/player "what changed" feed. Each item is the raw event record dict.
func recent_events(limit: int = 40) -> Array:
	var arr: Array = Global.REPUTATION_EVENTS.values().duplicate()
	arr.sort_custom(func(a, b):
		var da := int(a.get("Campaign_Day", 0))
		var db := int(b.get("Campaign_Day", 0))
		if da != db:
			return da > db
		return int(a.get("id", 0)) > int(b.get("id", 0)))
	return arr.slice(0, limit)
