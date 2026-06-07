extends Node
## Static game data registry. Each table is a folder of individual .tres files.
## On first run, auto-converts from JSON. Each record becomes its own .tres file.
##
## Structure:  data/resources/enemies/1.tres, data/resources/enemies/2.tres, ...
## Usage:      GameDB.enemies[id]  or  GameDB.reactions_for_element("Fire")

# ── Primary tables: int id → typed Resource ──────────────────────────────────
var enemies: Dictionary = {}
var enemies_by_name: Dictionary = {}
var weapons: Dictionary = {}
var weapons_by_name: Dictionary = {}
var abilities: Dictionary = {}
var items: Dictionary = {}
var items_by_name: Dictionary = {}
var artifact_sets: Dictionary = {}
var reactions: Dictionary = {}
var status_effects: Dictionary = {}
var crafting_recipes: Dictionary = {}
var material_caches: Dictionary = {}
var minigames: Dictionary = {}

# ── Indexed lookups ──────────────────────────────────────────────────────────
var _reactions_by_element: Dictionary = {}
var _artifact_bonus_index: Dictionary = {}
var _ability_weapon_map: Dictionary = {}  # Ability_ID → Weapon_Type (from Active_Abilities)
var abilities_by_entity: Dictionary = {}  # "EntityType|EntityID|AbilityID" → AbilityData

const JSON_DIR := "res://data/"
const TRES_DIR := "res://data/resources/"

# Table config: key → [json_file, folder_name, converter_method, resource_class]
const TABLE_CONFIG := {
	"enemies":          ["Enemies.json",          "enemies"],
	"weapons":          ["Weapons.json",          "weapons"],
	"abilities":        ["Abilities.json",        "abilities"],
	"items":            ["Items.json",            "items"],
	"artifact_sets":    ["Artifacts.json",        "artifact_sets"],
	"reactions":        ["Reactions.json",        "reactions"],
	"status_effects":   ["Status_Effects.json",   "status_effects"],
	"crafting_recipes": ["Crafting_Recipes.json", "crafting_recipes"],
	"material_caches":  ["Material_Caches.json",  "material_caches"],
	"minigames":        ["Minigames.json",        "minigames"],
}

func _ready() -> void:
	_load_all()

# ── Master loader ────────────────────────────────────────────────────────────

func _load_all() -> void:
	_build_cross_references()
	_load_table("enemies",          _convert_enemy)
	_load_table("weapons",          _convert_weapon)
	_load_abilities()  # custom path: one .tres per entity-ability pair
	_load_table("items",            _convert_item)
	_load_table("artifact_sets",    _convert_artifact_set)
	_load_table("reactions",        _convert_reaction)
	_load_table("status_effects",   _convert_status_effect)
	_load_table("crafting_recipes", _convert_crafting_recipe)
	_load_table("material_caches",  _convert_material_cache)
	_load_table("minigames",        _convert_minigame)
	_build_indexes()
	_populate_weapon_effects()
	_populate_artifact_effects()
	_populate_status_effects()
	_populate_ability_effects()

## Attach structured GameEffect arrays to weapon resources and save to .tres.
## Only updates weapons that don't already have effects saved.
func _populate_weapon_effects() -> void:
	var folder_path: String = TRES_DIR + "weapons/"
	var updated = 0
	for w in weapons.values():
		if w.effects.size() > 0:
			continue  # Already has effects saved in .tres
		var effs = WeaponEffects.get_effects(w.name)
		if effs.size() > 0:
			w.effects = effs
			# Re-save the .tres with effects embedded
			var slug = _slugify(w.name)
			var path = folder_path + slug + ".tres"
			if FileAccess.file_exists(path):
				ResourceSaver.save(w, path)
			updated += 1
	if updated > 0:
		print("GameDB: saved effects into %d weapon .tres files" % updated)
	else:
		print("GameDB: weapon effects already up to date")

## Attach structured GameEffect arrays to artifact set resources and save to .tres.
func _populate_artifact_effects() -> void:
	var folder_path: String = TRES_DIR + "artifact_sets/"
	var updated = 0
	for a in artifact_sets.values():
		if a.effects.size() > 0:
			continue
		var effs = ArtifactEffects.get_effects(a.artifact_set, a.bonus_type)
		if effs.size() > 0:
			a.effects = effs
			var slug = _slugify(a.artifact_set + " " + str(a.bonus_type) + "pc")
			var path = folder_path + slug + ".tres"
			if FileAccess.file_exists(path):
				ResourceSaver.save(a, path)
			updated += 1
	if updated > 0:
		print("GameDB: saved effects into %d artifact .tres files" % updated)
	else:
		print("GameDB: artifact effects already up to date")

## Attach structured GameEffect arrays to status effect resources and save to .tres.
func _populate_status_effects() -> void:
	var folder_path: String = TRES_DIR + "status_effects/"
	var updated = 0
	for s in status_effects.values():
		if s.effects.size() > 0:
			continue
		var effs = StatusEffectsMap.get_effects(s.name)
		if effs.size() > 0:
			s.effects = effs
			var slug = _slugify(s.name)
			var path = folder_path + slug + ".tres"
			if FileAccess.file_exists(path):
				ResourceSaver.save(s, path)
			updated += 1
	if updated > 0:
		print("GameDB: saved effects into %d status effect .tres files" % updated)
	else:
		print("GameDB: status effects already up to date")

## Attach structured GameEffect arrays to ability resources in memory.
## Effects are populated from AbilityEffects map. The .tres files already
## have effects embedded from initial generation — this just fills any
## that loaded without effects (e.g., newly added abilities).
func _populate_ability_effects() -> void:
	var updated = 0
	for a in abilities.values():
		if a.effects.size() > 0:
			continue
		var effs = AbilityEffects.get_effects(a.id)
		if effs.size() > 0:
			a.effects = effs
			updated += 1
	if updated > 0:
		print("GameDB: populated effects for %d abilities in memory" % updated)

func _load_table(table_key: String, converter: Callable) -> void:
	var info: Array = TABLE_CONFIG[table_key]
	var folder_path: String = TRES_DIR + info[1] + "/"
	var json_path: String = JSON_DIR + info[0]

	# Check if the folder exists and has .tres files
	var resources: Array = _load_folder(folder_path)

	if resources.size() > 0:
		print("GameDB: loaded %s from .tres (%d records)" % [table_key, resources.size()])
	else:
		# First run: convert from JSON, save individual .tres files
		resources = _convert_and_save(json_path, folder_path, converter, table_key)
		if resources.size() > 0:
			print("GameDB: converted %s → %d .tres files" % [table_key, resources.size()])
		else:
			print("GameDB: no data for %s" % table_key)

	_register(table_key, resources)

## Load all .tres files from a folder, returning an array of Resources.
##
## Handles both editor and exported-build cases:
##   - Editor: files appear as <name>.tres on disk.
##   - Export: Godot converts each .tres to a binary resource and ships a
##             <name>.tres.remap sidecar; the original .tres filename does
##             not appear in DirAccess listings. We strip .remap and load
##             via the original .tres path — load() follows the remap
##             transparently. Without this stripping, exported builds
##             enumerate zero resources and fall through to the JSON
##             converter, which silently misses every .tres-only record
##             (e.g., enemies added directly as .tres without round-tripping
##             through the legacy JSON).
func _load_folder(folder_path: String) -> Array:
	var results = []
	var dir = DirAccess.open(folder_path)
	if dir == null:
		return results
	var seen: Dictionary = {}
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var base = file_name.trim_suffix(".remap")
			if base.ends_with(".tres") and not seen.has(base):
				seen[base] = true
				var res = load(folder_path + base)
				if res != null:
					results.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results

## Turn a display name into a safe filename slug: "La Signora (Trounce Domain)" → "la_signora_trounce_domain"
static func _slugify(text: String) -> String:
	var s = text.strip_edges().to_lower()
	s = s.replace("'", "").replace("\"", "").replace("(", "").replace(")", "")
	s = s.replace(" ", "_").replace("-", "_").replace(",", "").replace(".", "")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	s = regex.sub(s, "", true)
	# Collapse multiple underscores
	while s.contains("__"):
		s = s.replace("__", "_")
	return s.trim_prefix("_").trim_suffix("_")

## Extract a human-readable name from a raw JSON record for filename generation.
func _record_label(table_key: String, d: Dictionary) -> String:
	match table_key:
		"enemies":          return str(d.get("name", ""))
		"weapons":          return str(d.get("Name", ""))
		"abilities":
			return str(d.get("name", ""))  # handled by custom _load_abilities()
		"items":            return str(d.get("Item", ""))
		"artifact_sets":
			var set_name = str(d.get("Artifact_Set", ""))
			var bonus = str(int(d.get("Bonus_Type", 0)) if d.get("Bonus_Type") != null else 0)
			return set_name + " " + bonus + "pc" if set_name != "" else ""
		"reactions":
			return str(d.get("First_Element", "")) + "_" + str(d.get("Second_Element", ""))
		"status_effects":   return str(d.get("Name", ""))
		"crafting_recipes": return str(d.get("Product", ""))
		"material_caches":
			return str(d.get("Region", "")) + "_roll_" + str(int(d.get("Roll", 0)) if d.get("Roll") != null else 0)
		"minigames":        return str(d.get("name", d.get("key", "")))
	return ""

## Build cross-reference maps from Active_Abilities + entity name lookups.
## _ability_entity_map: ability_id → Array of { entity_name, weapon_type, element, entity_type }
var _ability_entity_map: Dictionary = {}
var _entity_names: Dictionary = {}  # "Character|1" → "Dylan", "Enemy|5" → "La Signora"

func _build_cross_references() -> void:
	_ability_weapon_map.clear()
	_ability_entity_map.clear()
	_entity_names.clear()

	# Build entity name lookups from JSON
	for d in _read_json(JSON_DIR + "Characters.json"):
		if typeof(d) == TYPE_DICTIONARY and d.has("id"):
			var eid = int(d["id"]) if d["id"] != null else 0
			_entity_names["Character|" + str(eid)] = str(d.get("Name", ""))
	for d in _read_json(JSON_DIR + "Companions.json"):
		if typeof(d) == TYPE_DICTIONARY and d.has("id"):
			var eid = int(d["id"]) if d["id"] != null else 0
			_entity_names["Companion|" + str(eid)] = str(d.get("Name", ""))
	for d in _read_json(JSON_DIR + "Enemies.json"):
		if typeof(d) == TYPE_DICTIONARY and d.has("id"):
			var eid = int(d["id"]) if d["id"] != null else 0
			_entity_names["Enemy|" + str(eid)] = str(d.get("name", ""))

	# Build ability → entity mappings from Active_Abilities
	for d in _read_json(JSON_DIR + "Active_Abilities.json"):
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var ability_id = d.get("Ability_ID")
		var weapon_type = d.get("Weapon_Type")
		var elem = d.get("Element")
		var entity_type = d.get("Entity_Type")
		var entity_id = d.get("Entity_ID")
		if ability_id == null:
			continue
		var aid = int(ability_id)

		# Weapon map (first match wins, used as fallback)
		if weapon_type != null and str(weapon_type) != "":
			_ability_weapon_map[aid] = str(weapon_type)

		# Entity map: collect all entities that use this ability
		var entity_key = str(entity_type) + "|" + str(int(entity_id) if entity_id != null else 0)
		var ename: String = _entity_names.get(entity_key, "")
		var mapping = {
			"entity_name": ename,
			"entity_type": str(entity_type) if entity_type != null else "",
			"weapon_type": str(weapon_type) if weapon_type != null else "",
			"element": str(elem) if elem != null else "",
		}
		if not _ability_entity_map.has(aid):
			_ability_entity_map[aid] = []
		_ability_entity_map[aid].append(mapping)

## Custom ability loader: creates one .tres per entity-ability pair.
func _load_abilities() -> void:
	var folder_path: String = TRES_DIR + "abilities/"
	var json_path: String = JSON_DIR + "Abilities.json"

	# Try loading existing .tres files
	var resources: Array = _load_folder(folder_path)
	if resources.size() > 0:
		print("GameDB: loaded abilities from .tres (%d records)" % resources.size())
		_register("abilities", resources)
		return

	# Convert from JSON: one .tres per entity-ability pair
	var raw_abilities = _read_json(json_path)
	if raw_abilities.is_empty():
		print("GameDB: no ability data")
		return

	if OS.has_feature("editor"):
		DirAccess.make_dir_recursive_absolute(folder_path)

	var used_names = {}
	var all_resources = []
	var saved_count = 0
	var error_count = 0

	for d in raw_abilities:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var ability_id: int = 0
		if d.get("id") != null:
			ability_id = int(d["id"])
		var ability_name: String = ""
		if d.get("name") != null:
			ability_name = str(d["name"])
		var base_elem: String = ""
		if d.get("element") != null:
			base_elem = str(d["element"])

		var mappings: Array = _ability_entity_map.get(ability_id, [])

		# Parse ability type from name: "Brian C. – Skill" → "Skill"
		var atype: String = ability_name
		for sep in ["–", "—", "-"]:
			if ability_name.find(sep) >= 0:
				var parts = ability_name.split(sep)
				if parts.size() >= 2:
					atype = parts[1].strip_edges()
				break

		var _can_save = OS.has_feature("editor")

		if mappings.is_empty():
			# Orphaned ability — save once
			var res = AbilityData.from_dict(d)
			all_resources.append(res)
			var slug = _slugify(ability_name + " " + base_elem)
			if slug == "":
				slug = str(ability_id)
			if used_names.has(slug):
				slug = slug + "_" + str(ability_id)
			used_names[slug] = true
			if _can_save:
				var err = ResourceSaver.save(res, folder_path + slug + ".tres")
				if err == OK:
					saved_count += 1
				else:
					error_count += 1
					push_warning("GameDB: failed to save ability %d (%s) slug=%s err=%d" % [ability_id, ability_name, slug, err])
			else:
				saved_count += 1
		else:
			# One .tres per entity that uses this ability
			for mapping in mappings:
				var res = AbilityData.from_dict(d)
				all_resources.append(res)

				var ename: String = str(mapping.get("entity_name", ""))
				var elem: String = str(mapping.get("element", ""))
				var wtype: String = str(mapping.get("weapon_type", ""))

				# Build: entity + element + ability_type + weapon
				var label = ""
				if ename != "":
					label += ename + " "
				if elem != "":
					label += elem + " "
				label += atype
				if wtype != "":
					label += " " + wtype

				var slug = _slugify(label)
				if slug == "":
					slug = str(ability_id)
				if used_names.has(slug):
					slug = slug + "_" + str(ability_id)
				used_names[slug] = true

				if _can_save:
					var err = ResourceSaver.save(res, folder_path + slug + ".tres")
					if err == OK:
						saved_count += 1
					else:
						error_count += 1
						push_warning("GameDB: failed to save ability %d (%s) slug=%s err=%d" % [ability_id, ability_name, slug, err])
				else:
					saved_count += 1

	print("GameDB: abilities → %d saved, %d errors, %d total resources" % [saved_count, error_count, all_resources.size()])
	_register("abilities", all_resources)

## Read JSON, convert each record to a Resource, save each as its own .tres file.
func _convert_and_save(json_path: String, folder_path: String, converter: Callable, table_key: String = "") -> Array:
	var records = _read_json(json_path)
	if records.is_empty():
		return []

	if OS.has_feature("editor"):
		DirAccess.make_dir_recursive_absolute(folder_path)

	var used_names = {}
	var resources = []
	for d in records:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var res = converter.call(d)
		if res == null:
			continue
		resources.append(res)

		# Build filename: slug of name, falling back to ID
		var record_id: int = int(d.get("id", 0)) if d.get("id") != null else resources.size()
		var label: String = _record_label(table_key, d)
		var slug: String = _slugify(label) if label != "" else ""
		var base_name: String = slug if slug != "" else str(record_id)

		# Deduplicate: if two records produce the same slug, append the ID
		if used_names.has(base_name):
			base_name = base_name + "_" + str(record_id)
		used_names[base_name] = true

		if not OS.has_feature("editor"):
			continue  # Skip saving .tres in exported builds — res:// is read-only

		var file_path: String = folder_path + base_name + ".tres"
		var err = ResourceSaver.save(res, file_path)
		if err != OK:
			push_error("GameDB: failed to save %s (error %d)" % [file_path, err])

	return resources

func _read_json(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed

# ── Converters ───────────────────────────────────────────────────────────────

func _convert_enemy(d: Dictionary) -> EnemyData:             return EnemyData.from_dict(d)
func _convert_weapon(d: Dictionary) -> WeaponData:            return WeaponData.from_dict(d)
func _convert_ability(d: Dictionary) -> AbilityData:          return AbilityData.from_dict(d)
func _convert_item(d: Dictionary) -> ItemData:                return ItemData.from_dict(d)
func _convert_artifact_set(d: Dictionary) -> ArtifactSetData: return ArtifactSetData.from_dict(d)
func _convert_reaction(d: Dictionary) -> ReactionData:        return ReactionData.from_dict(d)
func _convert_status_effect(d: Dictionary) -> StatusEffectData: return StatusEffectData.from_dict(d)
func _convert_crafting_recipe(d: Dictionary) -> CraftingRecipeData: return CraftingRecipeData.from_dict(d)
func _convert_material_cache(d: Dictionary) -> MaterialCacheData: return MaterialCacheData.from_dict(d)
func _convert_minigame(d: Dictionary) -> MinigameData:        return MinigameData.from_dict(d)

# ── Registration ─────────────────────────────────────────────────────────────

func _register(table_key: String, resources: Array) -> void:
	match table_key:
		"enemies":
			enemies.clear(); enemies_by_name.clear()
			for e in resources:
				enemies[e.id] = e
				enemies_by_name[e.name] = e
		"weapons":
			weapons.clear(); weapons_by_name.clear()
			for w in resources:
				weapons[w.id] = w
				weapons_by_name[w.name] = w
		"abilities":
			abilities.clear()
			abilities_by_entity.clear()
			var entity_count = 0
			for a in resources:
				abilities[a.id] = a
				if a.entity_type != "":
					var key = "%s|%d|%d" % [a.entity_type, a.entity_id, a.id]
					abilities_by_entity[key] = a
					entity_count += 1
			print("GameDB: abilities_by_entity populated with %d entries (of %d total abilities)" % [entity_count, resources.size()])
			_validate_kit_abilities()
		"items":
			items.clear(); items_by_name.clear()
			for it in resources:
				items[it.id] = it
				items_by_name[it.item_name] = it
		"artifact_sets":
			artifact_sets.clear()
			for a in resources:
				artifact_sets[a.id] = a
		"reactions":
			reactions.clear()
			for r in resources:
				reactions[r.id] = r
		"status_effects":
			status_effects.clear()
			for s in resources:
				status_effects[s.id] = s
		"crafting_recipes":
			crafting_recipes.clear()
			for c in resources:
				crafting_recipes[c.id] = c
		"material_caches":
			material_caches.clear()
			for m in resources:
				material_caches[m.id] = m
		"minigames":
			minigames.clear()
			for m in resources:
				minigames[m.id] = m

func _build_indexes() -> void:
	_reactions_by_element.clear()
	for r in reactions.values():
		if not _reactions_by_element.has(r.first_element):
			_reactions_by_element[r.first_element] = []
		_reactions_by_element[r.first_element].append(r)
		if not _reactions_by_element.has(r.second_element):
			_reactions_by_element[r.second_element] = []
		_reactions_by_element[r.second_element].append(r)

	_artifact_bonus_index.clear()
	for a in artifact_sets.values():
		var key = a.artifact_set + "|" + str(a.bonus_type)
		_artifact_bonus_index[key] = a

# ── Query helpers ────────────────────────────────────────────────────────────

func reactions_for_element(element: String) -> Array:
	return _reactions_by_element.get(element, [])

func get_reaction(elem_a: String, elem_b: String) -> ReactionData:
	for r in _reactions_by_element.get(elem_a, []):
		if r.first_element == elem_b or r.second_element == elem_b:
			return r
	return null

func get_artifact_bonus(set_name: String, bonus_type: int) -> ArtifactSetData:
	return _artifact_bonus_index.get(set_name + "|" + str(bonus_type), null)

func get_artifact_set_bonuses(set_name: String) -> Array:
	var result = []
	var two_pc = _artifact_bonus_index.get(set_name + "|2", null)
	var four_pc = _artifact_bonus_index.get(set_name + "|4", null)
	if two_pc: result.append(two_pc)
	if four_pc: result.append(four_pc)
	return result

func get_ability(ability_id: int) -> AbilityData:
	return abilities.get(ability_id, null)

## Validate entity-linked kit abilities for data defects that silently break the
## battle attack dropdown. The dropdown only lists a Character's ability when its
## kit_element AND weapon_type both match the character (see battler_state.gd),
## so a blank field drops the ability with no error — exactly how Brian C.'s
## Basic/Burst vanished. This surfaces that class of defect loudly at load.
func _validate_kit_abilities() -> void:
	var issues: Array[String] = []
	for a in abilities_by_entity.values():
		# kit_element/weapon_type matching only gates player Characters; companions
		# and enemies bypass that filter, so blanks there are harmless.
		if a.entity_type == "Character":
			if a.kit_element == "":
				issues.append("%s (id %d): empty kit_element -> never matches the character's element, dropped from the battle dropdown" % [a.name, a.id])
			if a.weapon_type == "":
				issues.append("%s (id %d): empty weapon_type -> never matches the equipped weapon, dropped from the battle dropdown" % [a.name, a.id])
	if issues.is_empty():
		print("GameDB: kit ability validation passed")
	else:
		push_warning("GameDB: %d kit ability data issue(s) detected:" % issues.size())
		for msg in issues:
			push_warning("  ⚠ " + msg)
			printerr("GameDB VALIDATION: " + msg)

## Build the entity->ability mapping from the .tres catalog's entity-context
## fields. This is a pure derived view (no persistence, no synced overlay); it
## replaced the old Active_Abilities table. Keyed by the stable .tres ability id.
## Remaining cooldown is NOT carried here — it lives in BattleManager and is
## injected into battler_data by BattlerState.
## Keyed by the UNIQUE "EntityType|EntityID|AbilityID" composite (abilities_by_entity's
## own key). NOT by ability id alone: shared "default charged attack" abilities reuse
## the same ability id across many entities (e.g. id 266 across 11 characters), so
## keying by id would collapse them to one entry and drop everyone but the last —
## which is what made Ayaka's charged attack disappear.
##   { "EntityType|EntityID|AbilityID": { id, Entity_ID, Entity_Type, Ability_ID, Weapon_Type, Element, Ability_Type } }
func build_active_abilities_table() -> Dictionary:
	var result = {}
	for key in abilities_by_entity:
		var a = abilities_by_entity[key]
		result[key] = {
			"id": a.id,
			"Entity_ID": a.entity_id,
			"Entity_Type": a.entity_type,
			"Ability_ID": a.id,
			"Weapon_Type": a.weapon_type,
			"Element": a.kit_element,
			"Ability_Type": a.ability_type,
		}
	return result

func get_enemy(enemy_id: int) -> EnemyData:
	return enemies.get(enemy_id, null)

func get_status_effect(status_id: int) -> StatusEffectData:
	return status_effects.get(status_id, null)

func get_weapon(weapon_id: int) -> WeaponData:
	return weapons.get(weapon_id, null)

func get_weapon_by_name(weapon_name: String) -> WeaponData:
	return weapons_by_name.get(weapon_name, null)

func get_item_by_name(item_name: String) -> ItemData:
	return items_by_name.get(item_name, null)

func get_enemy_by_name(enemy_name: String) -> EnemyData:
	return enemies_by_name.get(enemy_name, null)

## Dice set used for stat-to-dice conversion (no D16).
const DICE_SET := [4, 6, 8, 10, 12, 20]

## Convert a stat value to the appropriate dice. Returns [die_size, bonus_die_size].
## e.g., 12 → [12, 0], 25 → [20, 4]
static func _stat_to_dice(stat_val: float) -> Array:
	var s = int(stat_val)
	if s < 4:
		return [4, 0]
	if s >= 24:
		# Overflow: D20 + bonus die from remainder
		var remainder = s - 20
		var bonus = 4
		for i in range(DICE_SET.size() - 1, -1, -1):
			if DICE_SET[i] <= remainder:
				bonus = DICE_SET[i]
				break
		return [20, bonus]
	# Single die: floor to nearest valid die
	for i in range(DICE_SET.size() - 1, -1, -1):
		if DICE_SET[i] <= s:
			return [DICE_SET[i], 0]
	return [4, 0]

## Update player ability dice estimates based on current calculated stats.
## Called by Global.calculate_all_stats() after gear/artifacts are factored in.
func update_player_ability_dice(attack_stat: float, em_stat: float) -> void:
	var atk_dice = _stat_to_dice(attack_stat)
	var em_dice = _stat_to_dice(em_stat)
	var updated = 0

	for ability in abilities.values():
		# Only update player abilities (name contains " – " or starts with a player name)
		var aname: String = ability.name
		var is_player = false
		for sep in [" – ", " — ", " - "]:
			if aname.find(sep) >= 0:
				is_player = true
				break
		if not is_player:
			continue

		var is_physical: bool = ability.element in ["Physical", ""]
		if is_physical:
			ability.dice_die = atk_dice[0]
			ability.dice_flat = atk_dice[1]
		else:
			ability.dice_die = em_dice[0]
			ability.dice_flat = em_dice[1]
		ability.dice_count = 1
		updated += 1

	if updated > 0:
		print("GameDB: updated %d player ability dice (Atk→D%d+%d, EM→D%d+%d)" % [updated, atk_dice[0], atk_dice[1], em_dice[0], em_dice[1]])

## Force re-conversion from JSON (e.g., after DM edits source JSON files).
func reimport_all() -> void:
	for table_key in TABLE_CONFIG:
		var folder_path: String = TRES_DIR + TABLE_CONFIG[table_key][1] + "/"
		# Delete existing .tres files in the folder
		var dir = DirAccess.open(folder_path)
		if dir:
			dir.list_dir_begin()
			var f = dir.get_next()
			while f != "":
				if f.ends_with(".tres"):
					DirAccess.remove_absolute(folder_path + f)
				f = dir.get_next()
			dir.list_dir_end()
	_load_all()
	print("GameDB: reimported all static tables from JSON")
