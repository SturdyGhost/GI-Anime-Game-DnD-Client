# Resource & Role Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace standalone gathering with automated combat loot, add challenge quests, rotate roles randomly after battle, and add companion expeditions.

**Architecture:** Five phases, each independently deployable. Phase 1 (role rotation) and Phase 2 (combat loot) are the core changes. Phase 3 (challenge quests) layers on top of Phase 2's loot system. Phase 4 (companion expeditions) is fully independent. Phase 5 (food buff wiring) is independent but makes Phase 1's Artisan role meaningful.

**Tech Stack:** Godot 4.x, GDScript, host-authoritative networking via ENet/NetworkManager, .tres resources, GameDB singleton, GameEffect system

**Spec:** `docs/superpowers/specs/2026-04-25-resource-and-role-rework-design.md`

---

## File Map

### New Files
| File | Responsibility |
|------|---------------|
| `Scripts/systems/loot_generator.gd` | Calculates difficulty score from enemies, generates per-player loot from regional caches + luck |
| `Scripts/systems/challenge_quest.gd` | Challenge quest data class: challenge text, quest giver, generosity, reward tier |
| `Scripts/systems/challenge_quest_generator.gd` | Generates random challenge quests from a pool, picks quest givers |
| `Scripts/systems/expedition_data.gd` | Expedition resource: name, region, type, trait bonuses |
| `Scripts/systems/expedition_manager.gd` | Generates expedition pool, calculates companion bonuses, processes results |
| `Scenes/UI/expedition_panel.gd` | Expedition board UI: shows available expeditions, companion assignment, results |
| `Scenes/UI/expedition_panel.tscn` | Minimal scene wrapper for expedition panel |
| `Scenes/UI/challenge_quest_display.gd` | Small widget showing current challenge quest in battle prep |
| `Scripts/systems/food_buff_effects.gd` | Maps food buff names to GameEffect arrays for combat registration |

### Modified Files
| File | Changes |
|------|---------|
| `Scenes/BattleScene.gd` | Add role rotation on battle end, DM challenge confirmation popup, pass enemy data to loot generator, add loot to summary |
| `Scenes/battle_summary.gd` | Add loot section below totals showing per-player material rewards |
| `Scenes/player_hub.gd` | Replace Gather button with Expeditions, update role_check for Scout, show current role prominently |
| `Scenes/player_battle_prep.gd` | Add challenge quest display widget to sidebar |
| `Scripts/battle/effect_processor.gd` | Register food buff effects at battle start |
| `Singletons/Global.gd` | Add `_current_challenge_quest` state, add `_returned_from_battle` role data |

---

## Phase 1: Role Rotation

### Task 1: Role Rotation Logic on Battle End

**Files:**
- Modify: `Scenes/BattleScene.gd:1920-1950` (`_host_battle_cleanup`)
- Modify: `Singletons/Global.gd` (add helper)

- [ ] **Step 1: Add role rotation function to BattleScene**

In `_host_battle_cleanup()`, after the existing cleanup logic and before `NetworkManager.broadcast_table_update`, add role rotation. The three roles are assigned randomly to the three players.

```gdscript
# Add at the end of _host_battle_cleanup(), before the broadcast line:
func _assign_random_roles() -> void:
	var roles = ["Artisan", "Blacksmith", "Scout"]
	roles.shuffle()
	var players = []
	for char in Global.CHARACTERS.values():
		if str(char.get("User_Type", "")) != "Dungeon Master":
			players.append(char)
	var updates = []
	for i in range(mini(players.size(), roles.size())):
		updates.append({
			"table": "Characters",
			"record_id": int(players[i].get("id", 0)),
			"field": "Role",
			"value": roles[i]
		})
	if updates.size() > 0:
		Global.Update_Records(updates)
```

- [ ] **Step 2: Call role rotation from _host_battle_cleanup**

Add `_assign_random_roles()` call at the end of `_host_battle_cleanup()`, just before `NetworkManager.broadcast_table_update("BattleEnemies")`:

```gdscript
	_assign_random_roles()
	NetworkManager.broadcast_table_update("Characters")
	NetworkManager.broadcast_table_update("BattleEnemies")
```

- [ ] **Step 3: Test role rotation**

Run the game, enter a battle, end it. Verify:
- Each of the 3 players has a different role
- Roles are one of: Artisan, Blacksmith, Scout
- Run 3-4 times to verify randomness

- [ ] **Step 4: Commit**

```bash
git add Scenes/BattleScene.gd
git commit -m "feat: randomly rotate player roles (Artisan/Blacksmith/Scout) on battle end"
```

### Task 2: Update Hub Role Check for Scout

**Files:**
- Modify: `Scenes/player_hub.gd:77-84` (`role_check`)

- [ ] **Step 1: Update role_check to handle Scout**

Replace the existing `role_check()` function. Scout replaces Scribe — Scouts cannot craft, but also don't get the Research panel (that mechanic is removed). Instead, the Scout just sees a role indicator. For now, disable both Crafting and Research for Scout, and later we'll add a Scout badge.

```gdscript
func role_check():
	if Player_data == null or Player_data.is_empty():
		return
	var role = Player_data.get("Role")
	var crafting_btn = $"UI/BottomHotbar/HBoxContainer/Crafting Button"
	var research_btn = $"UI/BottomHotbar/HBoxContainer/Research Button"
	match role:
		"Artisan", "Blacksmith":
			crafting_btn.disabled = false
			research_btn.disabled = true
		"Scout":
			crafting_btn.disabled = true
			research_btn.disabled = true
		_:
			# Legacy "Scribe" or unknown — treat as Scout
			crafting_btn.disabled = true
			research_btn.disabled = true
```

- [ ] **Step 2: Add role display to hub**

Add a prominent role label below the character portrait in `set_ui()`. Find the section where `$UI/TopHotbar/CharacterPortrait.set_character(...)` is called and add after it:

```gdscript
	# Show current role badge
	var role_label = $UI/TopHotbar.get_node_or_null("RoleLabel")
	if role_label == null:
		role_label = Label.new()
		role_label.name = "RoleLabel"
		role_label.add_theme_font_size_override("font_size", 16)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		$UI/TopHotbar.add_child(role_label)
	var role_text = str(Player_data.get("Role", ""))
	role_label.text = role_text
	match role_text:
		"Artisan":
			role_label.add_theme_color_override("font_color", Color(0.788, 0.659, 0.298))  # Gold
		"Blacksmith":
			role_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))  # Steel blue
		"Scout":
			role_label.add_theme_color_override("font_color", Color(0.292, 0.855, 0.498))  # Green
		_:
			role_label.add_theme_color_override("font_color", Color(0.69, 0.722, 0.8))  # Muted
```

- [ ] **Step 3: Test hub role display**

Run the game, verify:
- Role label appears in hub with correct color
- Crafting button disabled for Scout, enabled for Artisan/Blacksmith
- Research button disabled for all roles (Scribe mechanic removed)

- [ ] **Step 4: Commit**

```bash
git add Scenes/player_hub.gd
git commit -m "feat: update hub for role rotation — Scout replaces Scribe, show role badge"
```

### Task 3: Remove Gather Button from Hub

**Files:**
- Modify: `Scenes/player_hub.gd:863-879` (`_on_gather_button_pressed`)
- Modify: `Scenes/player_hub.tscn` (remove Gather Button node)

- [ ] **Step 1: Hide or remove the Gather button**

In `_try_initial_setup()`, hide the Gather button since gathering is replaced by combat loot:

```gdscript
	# Gathering replaced by combat loot — hide gather button
	var gather_btn = $"UI/BottomHotbar/HBoxContainer/Gather Button"
	if gather_btn:
		gather_btn.visible = false
```

- [ ] **Step 2: Test that Gather button is gone**

Run the game, verify the Gather button no longer appears in the hub bottom hotbar.

- [ ] **Step 3: Commit**

```bash
git add Scenes/player_hub.gd
git commit -m "feat: hide Gather button from hub — gathering replaced by combat loot"
```

---

## Phase 2: Automated Combat Loot

### Task 4: Create Loot Generator

**Files:**
- Create: `Scripts/systems/loot_generator.gd`

- [ ] **Step 1: Create the loot generator script**

This script takes the battle's enemy list, region, and player luck values, then returns per-player loot dictionaries.

```gdscript
class_name LootGenerator
extends RefCounted

# Enemy tier → difficulty score
const TIER_SCORES := {
	"common": 1, "Common": 1,
	"uncommon": 2, "Uncommon": 2,
	"rare": 5, "Rare": 5,
	"epic": 8, "Epic": 8,
	"world_boss": 25, "World Boss": 25,   # Boss tier
	"story_boss": 25, "Story Boss": 25,   # Boss tier (same as world_boss)
	"legendary": 40, "Legendary": 40,     # No enemies use this yet
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
		if str(cache.get("region", cache.get("Region", ""))) == region:
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
```

- [ ] **Step 2: Test loot generator in isolation**

Create a quick test in the Godot console or a temporary script:
- `LootGenerator.calc_difficulty_score([{"tier": "common"}, {"tier": "common"}, {"tier": "rare"}])` should return 7
- `LootGenerator.get_loot_tier(7)` should return the Light tier config
- `LootGenerator.apply_luck(5, 90)` should return 7

- [ ] **Step 3: Commit**

```bash
git add Scripts/systems/loot_generator.gd
git commit -m "feat: add LootGenerator — difficulty scoring, luck modifier, regional cache loot"
```

### Task 5: Snapshot Enemies Before Cleanup & Generate Loot

**Files:**
- Modify: `Scenes/BattleScene.gd:1894-1908` (battle end flow)

- [ ] **Step 1: Snapshot enemy data before cleanup deletes it**

In `check_battle_end()`, before `_host_battle_cleanup()` is called, snapshot the enemy tiers so loot can be calculated after enemies are removed from the database:

```gdscript
		# (inside the all_enemies_dead or all_players_down block, host path)
		if NetworkManager.is_host:
			await get_tree().create_timer(1.0).timeout
			var summary = {}
			if _battle_logger:
				summary = _battle_logger.end_battle()

			# Snapshot enemies for loot calc before cleanup removes them
			var enemy_snapshot: Array = []
			for enemy in Global.BATTLEENEMIES.values():
				var enemy_name = str(enemy.get("Enemy_Name", enemy.get("Name", "")))
				var enemy_def = GameDB.enemies_by_name.get(enemy_name, null)
				if enemy_def:
					enemy_snapshot.append({"tier": enemy_def.tier})
				else:
					enemy_snapshot.append({"tier": "common"})

			_host_battle_cleanup()

			# Generate loot and attach to summary
			var loot = LootGenerator.generate_all_loot(enemy_snapshot, Global.Current_Region)
			summary["player_loot"] = loot
			summary["difficulty_score"] = LootGenerator.calc_difficulty_score(enemy_snapshot)
			var tier_data = LootGenerator.get_loot_tier(summary["difficulty_score"])
			summary["loot_tier"] = tier_data["tier"] if tier_data else "Nothing"

			if not summary.is_empty():
				NetworkManager.broadcast_battle_summary(summary)
			_show_battle_summary(summary)
```

- [ ] **Step 2: Add loot materials to player inventories (host side)**

Add a function that persists the loot to the database. Call it after loot generation but before broadcasting. This upserts items into CHARACTER_ITEMS:

```gdscript
func _persist_loot(loot: Dictionary) -> void:
	for player_name in loot:
		var player_loot: Dictionary = loot[player_name]
		for mat_name in player_loot:
			var qty: int = player_loot[mat_name]
			if qty <= 0:
				continue
			# Find existing item record for this player+material
			var found_id: int = -1
			for item in Global.CHARACTER_ITEMS.values():
				if str(item.get("Character_Name", "")) == player_name and str(item.get("Item", "")) == mat_name:
					found_id = int(item.get("id", -1))
					break
			if found_id > 0:
				# Update existing quantity
				var old_qty = int(Global.CHARACTER_ITEMS[str(found_id)].get("Quantity", 0))
				Global.Update_Records([{
					"table": "Character_Items",
					"record_id": found_id,
					"field": "Quantity",
					"value": old_qty + qty
				}])
			else:
				# Look up item definition for type/rarity
				var item_def = GameDB.items_by_name.get(mat_name, null)
				var item_type = item_def.type if item_def else "Material"
				var item_rarity = item_def.rarity if item_def else "Common"
				var item_desc = item_def.description if item_def else ""
				Global.Insert("Character_Items",
					["Character_Name", "Item", "Quantity", "Type", "Rarity", "Description"],
					[player_name, mat_name, qty, item_type, item_rarity, item_desc])
```

Call `_persist_loot(loot)` right after generating the loot, before broadcasting:

```gdscript
			var loot = LootGenerator.generate_all_loot(enemy_snapshot, Global.Current_Region)
			_persist_loot(loot)
			summary["player_loot"] = loot
```

- [ ] **Step 3: Test loot generation end-to-end**

Run the game, enter a battle with known enemies, win. Check:
- Summary dictionary contains `player_loot`, `difficulty_score`, `loot_tier`
- Loot materials match the region's caches
- Player inventories updated in database

- [ ] **Step 4: Commit**

```bash
git add Scenes/BattleScene.gd
git commit -m "feat: generate per-player combat loot on battle end with difficulty scoring"
```

### Task 6: Display Loot on Battle Summary Screen

**Files:**
- Modify: `Scenes/battle_summary.gd:126-143` (between totals and continue button)

- [ ] **Step 1: Add loot section to battle summary**

After the total kills label and before the continue button, add a loot display section. Insert this code after the `total_kills_label` block (around line 141) and before the final separator + continue button:

```gdscript
	# ── Loot section ─────────────────────────────────────────────────────────
	var player_loot: Dictionary = summary.get("player_loot", {})
	if not player_loot.is_empty():
		root_vbox.add_child(_separator())

		var loot_tier_name: String = str(summary.get("loot_tier", ""))
		var loot_header = _label("BATTLE LOOT" + ("  —  " + loot_tier_name if loot_tier_name != "" and loot_tier_name != "Nothing" else ""), 16, COL_ACCENT)
		loot_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_vbox.add_child(loot_header)

		# Show loot for current player only (each player sees their own)
		var my_name: String = Global.ACTIVE_USER_NAME
		var my_loot: Dictionary = player_loot.get(my_name, {})
		if my_loot.is_empty():
			var no_loot = _label("No loot earned", 14, COL_TEXT_MUTED)
			no_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			root_vbox.add_child(no_loot)
		else:
			var loot_grid = GridContainer.new()
			loot_grid.columns = 4
			loot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			loot_grid.add_theme_constant_override("h_separation", 16)
			loot_grid.add_theme_constant_override("v_separation", 4)
			root_vbox.add_child(loot_grid)

			var sorted_mats = my_loot.keys()
			sorted_mats.sort()
			for mat_name in sorted_mats:
				var qty: int = int(my_loot[mat_name])
				var name_lbl = _label(mat_name, 14, COL_TEXT)
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				loot_grid.add_child(name_lbl)
				var qty_lbl = _label("x%d" % qty, 14, COL_GREEN)
				loot_grid.add_child(qty_lbl)
```

- [ ] **Step 2: Test loot display**

Run a battle, end it, verify:
- Loot section appears below totals on battle summary
- Shows the current player's materials with quantities
- Loot tier label shown (e.g., "BATTLE LOOT — Light")
- Materials listed in sorted order

- [ ] **Step 3: Commit**

```bash
git add Scenes/battle_summary.gd
git commit -m "feat: display per-player combat loot on battle summary screen"
```

---

## Phase 3: Challenge Quests

### Task 7: Challenge Quest Data & Generator

**Files:**
- Create: `Scripts/systems/challenge_quest.gd`
- Create: `Scripts/systems/challenge_quest_generator.gd`

- [ ] **Step 1: Create challenge quest data class**

```gdscript
class_name ChallengeQuest
extends RefCounted

var challenge_text: String          # "Trigger a Melt reaction"
var challenge_category: String      # "reaction", "kill", "defense", "tactical", "speed"
var quest_giver_name: String        # "Zhiqiong"
var quest_giver_personality: String # "Generous", "Fair", "Stingy"
var reward_multiplier: float        # 1.5 for generous, 1.0 for fair, 0.5 for stingy
var completed: bool = false

func _init(text: String = "", category: String = "", giver: String = "", personality: String = "Fair", multiplier: float = 1.0) -> void:
	challenge_text = text
	challenge_category = category
	quest_giver_name = giver
	quest_giver_personality = personality
	reward_multiplier = multiplier

## Returns player-visible dict (no reward info).
func to_player_dict() -> Dictionary:
	return {
		"challenge_text": challenge_text,
		"quest_giver_name": quest_giver_name,
		"quest_giver_personality": quest_giver_personality,
	}

## Returns full dict for host/DM.
func to_dict() -> Dictionary:
	return {
		"challenge_text": challenge_text,
		"challenge_category": challenge_category,
		"quest_giver_name": quest_giver_name,
		"quest_giver_personality": quest_giver_personality,
		"reward_multiplier": reward_multiplier,
		"completed": completed,
	}

static func from_dict(d: Dictionary) -> ChallengeQuest:
	var q = ChallengeQuest.new()
	q.challenge_text = str(d.get("challenge_text", ""))
	q.challenge_category = str(d.get("challenge_category", ""))
	q.quest_giver_name = str(d.get("quest_giver_name", ""))
	q.quest_giver_personality = str(d.get("quest_giver_personality", "Fair"))
	q.reward_multiplier = float(d.get("reward_multiplier", 1.0))
	q.completed = bool(d.get("completed", false))
	return q
```

- [ ] **Step 2: Create the challenge quest generator**

```gdscript
class_name ChallengeQuestGenerator
extends RefCounted

const CHALLENGES := [
	{"text": "Trigger a Melt reaction", "category": "reaction"},
	{"text": "Trigger a Vaporize reaction", "category": "reaction"},
	{"text": "Trigger an Overloaded reaction", "category": "reaction"},
	{"text": "Trigger a Superconduct reaction", "category": "reaction"},
	{"text": "Trigger a Bloom reaction", "category": "reaction"},
	{"text": "Trigger a Burning reaction", "category": "reaction"},
	{"text": "Trigger an Electro-Charged reaction", "category": "reaction"},
	{"text": "Trigger a Swirl reaction", "category": "reaction"},
	{"text": "Trigger a Crystallize reaction", "category": "reaction"},
	{"text": "Trigger a Freeze reaction", "category": "reaction"},
	{"text": "Defeat an enemy with a charged attack", "category": "kill"},
	{"text": "Defeat an enemy with an elemental skill", "category": "kill"},
	{"text": "Defeat an enemy with an elemental burst", "category": "kill"},
	{"text": "Defeat an enemy with a normal attack", "category": "kill"},
	{"text": "No party member takes a crit", "category": "defense"},
	{"text": "No party member is knocked out", "category": "defense"},
	{"text": "Every party member deals damage this battle", "category": "tactical"},
	{"text": "Apply 3 different status effects", "category": "tactical"},
	{"text": "Land 2 or more critical hits", "category": "tactical"},
	{"text": "Use at least 2 elemental bursts", "category": "tactical"},
	{"text": "Win within 8 turns", "category": "speed"},
	{"text": "Win within 6 turns", "category": "speed"},
	{"text": "Win without using any items", "category": "defense"},
]

const QUEST_GIVERS := [
	{"name": "Zhiqiong", "personality": "Generous", "multiplier": 1.5},
	{"name": "Katheryne", "personality": "Fair", "multiplier": 1.0},
	{"name": "Cyrus", "personality": "Fair", "multiplier": 1.0},
	{"name": "Lan", "personality": "Stingy", "multiplier": 0.6},
	{"name": "Ying'er", "personality": "Generous", "multiplier": 1.5},
	{"name": "Wagner", "personality": "Stingy", "multiplier": 0.6},
	{"name": "Sara", "personality": "Fair", "multiplier": 1.0},
	{"name": "Dori", "personality": "Shrewd", "multiplier": 0.75},
	{"name": "Dunyarzad", "personality": "Generous", "multiplier": 1.5},
]

static func generate() -> ChallengeQuest:
	var challenge = CHALLENGES[randi() % CHALLENGES.size()]
	var giver = QUEST_GIVERS[randi() % QUEST_GIVERS.size()]
	return ChallengeQuest.new(
		challenge["text"],
		challenge["category"],
		giver["name"],
		giver["personality"],
		giver["multiplier"]
	)
```

- [ ] **Step 3: Test generator**

`ChallengeQuestGenerator.generate()` should return a valid ChallengeQuest with non-empty fields. Run several times to verify randomness.

- [ ] **Step 4: Commit**

```bash
git add Scripts/systems/challenge_quest.gd Scripts/systems/challenge_quest_generator.gd
git commit -m "feat: add ChallengeQuest data class and random generator"
```

### Task 8: Store Active Challenge & Show in Battle Prep

**Files:**
- Modify: `Singletons/Global.gd` (add challenge quest state)
- Modify: `Scenes/player_battle_prep.gd` (add challenge display to sidebar)

- [ ] **Step 1: Add challenge quest state to Global**

Add to Global.gd:

```gdscript
var active_challenge_quest: Dictionary = {}  # ChallengeQuest.to_player_dict() for clients, to_dict() for host
```

- [ ] **Step 2: Generate a challenge quest when battle prep loads (host only)**

In player_battle_prep.gd `_ready()`, if the host and no active challenge exists, generate one and broadcast it:

```gdscript
	# Generate challenge quest if host and none active
	if NetworkManager.is_host and Global.active_challenge_quest.is_empty():
		var quest = ChallengeQuestGenerator.generate()
		Global.active_challenge_quest = quest.to_dict()
		# Broadcast player-visible version to clients
		NetworkManager.broadcast_rpc("_receive_challenge_quest", [quest.to_player_dict()])
```

For clients, add a receiver:

```gdscript
func _receive_challenge_quest(quest_data: Dictionary) -> void:
	Global.active_challenge_quest = quest_data
	_update_challenge_display()
```

- [ ] **Step 3: Add challenge display to battle prep sidebar**

In the right sidebar of player_battle_prep.gd, add a challenge quest section above the Turn Order section. Build it in `_build_ui()`:

```gdscript
func _build_challenge_section(parent: VBoxContainer) -> void:
	var quest = Global.active_challenge_quest
	if quest.is_empty():
		return

	var header = Label.new()
	header.text = "CHALLENGE QUEST"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", ACCENT_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(header)

	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = PANEL_COLOR
	sb.border_color = ACCENT_GOLD_DIM
	sb.border_width_left = 2
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Quest giver line
	var giver_name = str(quest.get("quest_giver_name", ""))
	var personality = str(quest.get("quest_giver_personality", ""))
	var giver_label = Label.new()
	giver_label.text = "%s (%s)" % [giver_name, personality]
	giver_label.add_theme_font_size_override("font_size", 13)
	giver_label.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(giver_label)

	# Challenge text
	var challenge_label = Label.new()
	challenge_label.text = str(quest.get("challenge_text", ""))
	challenge_label.add_theme_font_size_override("font_size", 15)
	challenge_label.add_theme_color_override("font_color", TEXT_COLOR)
	challenge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(challenge_label)
```

- [ ] **Step 4: Test challenge display in battle prep**

Run the game, open battle prep, verify:
- Challenge quest section appears in the sidebar
- Shows quest giver name and personality
- Shows challenge text
- Reward is NOT visible to players

- [ ] **Step 5: Commit**

```bash
git add Singletons/Global.gd Scenes/player_battle_prep.gd
git commit -m "feat: generate and display challenge quest in battle prep sidebar"
```

### Task 9: DM Confirmation Popup & Quest Loot

**Files:**
- Modify: `Scenes/BattleScene.gd` (add DM popup between battle end and summary)

- [ ] **Step 1: Add DM challenge confirmation popup**

Create a method that shows a popup to the DM asking whether the challenge was completed. This must happen AFTER battle ends but BEFORE the summary is shown. Modify the host path in `check_battle_end()`:

```gdscript
func _show_challenge_confirmation(summary: Dictionary, enemy_snapshot: Array) -> void:
	var quest = Global.active_challenge_quest
	if quest.is_empty():
		_finalize_battle_summary(summary, enemy_snapshot, false)
		return

	# Build confirmation popup
	var popup = AcceptDialog.new()
	popup.title = "Challenge Quest"
	popup.dialog_text = "Challenge: %s\n\nQuest Giver: %s (%s)\n\nDid the party complete this challenge?" % [
		str(quest.get("challenge_text", "")),
		str(quest.get("quest_giver_name", "")),
		str(quest.get("quest_giver_personality", "")),
	]
	popup.ok_button_text = "Yes — Completed"
	popup.add_cancel_button("No — Failed")
	popup.confirmed.connect(func(): _finalize_battle_summary(summary, enemy_snapshot, true); popup.queue_free())
	popup.canceled.connect(func(): _finalize_battle_summary(summary, enemy_snapshot, false); popup.queue_free())
	add_child(popup)
	popup.popup_centered(Vector2(450, 250))
```

- [ ] **Step 2: Refactor battle end to use the confirmation flow**

Extract the loot generation and summary broadcasting into `_finalize_battle_summary`:

```gdscript
func _finalize_battle_summary(summary: Dictionary, enemy_snapshot: Array, challenge_completed: bool) -> void:
	var loot = LootGenerator.generate_all_loot(enemy_snapshot, Global.Current_Region)

	# Add quest bonus loot if challenge completed
	if challenge_completed and not Global.active_challenge_quest.is_empty():
		var multiplier: float = float(Global.active_challenge_quest.get("reward_multiplier", 1.0))
		var quest_loot = LootGenerator.generate_all_loot(enemy_snapshot, Global.Current_Region)
		# Scale quest loot by multiplier and merge into main loot
		for player_name in quest_loot:
			if player_name not in loot:
				loot[player_name] = {}
			for mat_name in quest_loot[player_name]:
				var bonus_qty: int = int(ceil(quest_loot[player_name][mat_name] * multiplier))
				loot[player_name][mat_name] = loot[player_name].get(mat_name, 0) + bonus_qty
		summary["challenge_completed"] = true
	else:
		summary["challenge_completed"] = false

	_persist_loot(loot)
	summary["player_loot"] = loot
	summary["difficulty_score"] = LootGenerator.calc_difficulty_score(enemy_snapshot)
	var tier_data = LootGenerator.get_loot_tier(summary["difficulty_score"])
	summary["loot_tier"] = tier_data["tier"] if tier_data else "Nothing"
	summary["challenge_quest"] = Global.active_challenge_quest.get("challenge_text", "")

	# Clear active challenge for next battle
	Global.active_challenge_quest = {}

	if not summary.is_empty():
		NetworkManager.broadcast_battle_summary(summary)
	_show_battle_summary(summary)
```

Update `check_battle_end()` host path to call the confirmation flow instead of directly finalizing:

```gdscript
			_host_battle_cleanup()
			# DM confirms challenge quest before generating loot + summary
			if NetworkManager.is_host:
				_show_challenge_confirmation(summary, enemy_snapshot)
```

- [ ] **Step 3: Show challenge result on battle summary**

In `battle_summary.gd`, add a line above the loot section showing whether the challenge was completed:

```gdscript
	# ── Challenge result ─────────────────────────────────────────────────────
	var challenge_text: String = str(summary.get("challenge_quest", ""))
	if challenge_text != "":
		root_vbox.add_child(_separator())
		var completed: bool = summary.get("challenge_completed", false)
		var status_text = "CHALLENGE COMPLETE!" if completed else "Challenge Failed"
		var status_color = COL_GREEN if completed else COL_RED
		var status_label = _label(status_text, 16, status_color)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_vbox.add_child(status_label)
		var challenge_desc = _label(challenge_text, 14, COL_TEXT_MUTED)
		challenge_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_vbox.add_child(challenge_desc)
```

- [ ] **Step 4: Test full challenge quest flow**

Run the game as DM:
1. Open battle prep — challenge quest should appear
2. Fight and end the battle
3. DM gets popup asking about challenge completion
4. Click Yes — summary shows "CHALLENGE COMPLETE!" and bonus loot
5. Click No — summary shows "Challenge Failed" and base loot only
6. Next battle prep should generate a new challenge

- [ ] **Step 5: Commit**

```bash
git add Scenes/BattleScene.gd Scenes/battle_summary.gd
git commit -m "feat: DM challenge confirmation popup with quest bonus loot on battle end"
```

### Task 10: DM Override for Challenge Quests

**Files:**
- Modify: `Scenes/player_battle_prep.gd` (DM-only override controls)

- [ ] **Step 1: Add DM override UI to battle prep**

In the challenge section, if the current user is the DM, add edit controls below the challenge display:

```gdscript
func _build_challenge_section(parent: VBoxContainer) -> void:
	# ... existing display code from Task 8 ...

	# DM override controls
	if Global.ACTIVE_USER_TYPE == "Dungeon Master":
		var override_btn = Button.new()
		override_btn.text = "Reroll Challenge"
		override_btn.custom_minimum_size = Vector2(0, 32)
		override_btn.add_theme_font_size_override("font_size", 13)
		override_btn.pressed.connect(_reroll_challenge)
		vbox.add_child(override_btn)

		var edit_btn = Button.new()
		edit_btn.text = "Edit Challenge"
		edit_btn.custom_minimum_size = Vector2(0, 32)
		edit_btn.add_theme_font_size_override("font_size", 13)
		edit_btn.pressed.connect(_edit_challenge)
		vbox.add_child(edit_btn)

func _reroll_challenge() -> void:
	var quest = ChallengeQuestGenerator.generate()
	Global.active_challenge_quest = quest.to_dict()
	NetworkManager.broadcast_rpc("_receive_challenge_quest", [quest.to_player_dict()])
	# Rebuild UI to reflect new challenge
	_rebuild_sidebar()

func _edit_challenge() -> void:
	# Open a simple dialog letting DM type a custom challenge text
	var dialog = AcceptDialog.new()
	dialog.title = "Edit Challenge"
	var input = LineEdit.new()
	input.text = str(Global.active_challenge_quest.get("challenge_text", ""))
	input.placeholder_text = "Enter custom challenge..."
	input.custom_minimum_size = Vector2(400, 36)
	dialog.add_child(input)
	dialog.confirmed.connect(func():
		Global.active_challenge_quest["challenge_text"] = input.text
		NetworkManager.broadcast_rpc("_receive_challenge_quest", [ChallengeQuest.new(
			input.text,
			Global.active_challenge_quest.get("challenge_category", ""),
			Global.active_challenge_quest.get("quest_giver_name", ""),
			Global.active_challenge_quest.get("quest_giver_personality", "Fair"),
			float(Global.active_challenge_quest.get("reward_multiplier", 1.0))
		).to_player_dict()])
		dialog.queue_free()
		_rebuild_sidebar()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(450, 150))
```

- [ ] **Step 2: Test DM override**

Run as DM, open battle prep:
- "Reroll Challenge" generates a new random challenge
- "Edit Challenge" opens a dialog to type custom text
- Both update for all clients

- [ ] **Step 3: Commit**

```bash
git add Scenes/player_battle_prep.gd
git commit -m "feat: DM can reroll or edit challenge quests in battle prep"
```

---

## Phase 4: Companion Expeditions

### Task 11: Expedition Data & Manager

**Files:**
- Create: `Scripts/systems/expedition_data.gd`
- Create: `Scripts/systems/expedition_manager.gd`

- [ ] **Step 1: Create expedition data class**

```gdscript
class_name ExpeditionData
extends RefCounted

var expedition_name: String         # "Harvest the Rainforest"
var region: String                  # "Sumeru"
var expedition_type: String         # "mining", "hunting", "foraging", "research", "trade"
var description: String             # "Gather herbs and plants from the rainforest"
var base_materials: int             # Base material quantity per cache material
var cache_roll: int                 # Which regional cache to pull from (1-4)
var risk_level: String              # "safe", "moderate", "risky"

# Trait bonuses: which companion traits get bonuses here
var bonus_region: String            # Companion region that gets bonus
var bonus_weapon: String            # Companion weapon type that gets bonus
var bonus_element: String           # Companion element that gets bonus

func _init(data: Dictionary = {}) -> void:
	expedition_name = str(data.get("name", ""))
	region = str(data.get("region", ""))
	expedition_type = str(data.get("type", ""))
	description = str(data.get("description", ""))
	base_materials = int(data.get("base_materials", 3))
	cache_roll = int(data.get("cache_roll", 1))
	risk_level = str(data.get("risk_level", "safe"))
	bonus_region = str(data.get("bonus_region", ""))
	bonus_weapon = str(data.get("bonus_weapon", ""))
	bonus_element = str(data.get("bonus_element", ""))

func to_dict() -> Dictionary:
	return {
		"name": expedition_name, "region": region, "type": expedition_type,
		"description": description, "base_materials": base_materials,
		"cache_roll": cache_roll, "risk_level": risk_level,
		"bonus_region": bonus_region, "bonus_weapon": bonus_weapon,
		"bonus_element": bonus_element,
	}

static func from_dict(d: Dictionary) -> ExpeditionData:
	return ExpeditionData.new(d)
```

- [ ] **Step 2: Create expedition manager**

```gdscript
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

## Generate a random pool of expeditions for the current town visit.
## Returns Array of ExpeditionData.
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
		# Pick a bonus element that has affinity for this region
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

## Calculate a companion's bonus multiplier for a given expedition.
## Returns float (1.0 = no bonus, higher = better match).
static func companion_bonus(companion: Dictionary, expedition: ExpeditionData) -> float:
	var bonus := 1.0
	# Region match
	if str(companion.get("Region", "")) == expedition.bonus_region:
		bonus += 0.25
	# Weapon match
	if str(companion.get("Weapon", "")) == expedition.bonus_weapon:
		bonus += 0.25
	# Element match
	if str(companion.get("Element", "")) == expedition.bonus_element:
		bonus += 0.2
	# Personality bonus (derived from lore/description keywords)
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

## Process expedition results. Returns loot dictionary { "material_name": qty }.
static func process_results(expedition: ExpeditionData, companion: Dictionary) -> Dictionary:
	var bonus = companion_bonus(companion, expedition)
	var region = expedition.region
	# Find the specific cache for this expedition
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

	# Risky expeditions: 30% chance of failure (return nothing), else +50% loot
	if expedition.risk_level == "risky":
		if randf() < 0.3:
			return {}
		final_qty = int(ceil(final_qty * 1.5))

	for mat_name in materials:
		loot[mat_name] = final_qty
	return loot
```

- [ ] **Step 3: Test expedition generation and bonus calculation**

- `ExpeditionManager.generate_pool("Sumeru", 4)` returns 4 expeditions with Sumeru region
- A companion with Region="Sumeru", Weapon="Bow" on a foraging expedition with bonus_region="Sumeru", bonus_weapon="Bow" gets bonus > 1.0
- `ExpeditionManager.process_results(expedition, companion)` returns a non-empty loot dict

- [ ] **Step 4: Commit**

```bash
git add Scripts/systems/expedition_data.gd Scripts/systems/expedition_manager.gd
git commit -m "feat: add ExpeditionManager — pool generation, companion bonuses, result processing"
```

### Task 12: Expedition Panel UI

**Files:**
- Create: `Scenes/UI/expedition_panel.gd`
- Create: `Scenes/UI/expedition_panel.tscn`
- Modify: `Scenes/player_hub.gd` (replace Gather button with Expeditions)

- [ ] **Step 1: Create expedition panel scene wrapper**

Create a minimal `expedition_panel.tscn` with a Control root node (same pattern as other panels in the project). The script will build UI programmatically.

- [ ] **Step 2: Create the expedition panel script**

This is a full-screen panel showing:
- Available expeditions (left side)
- Companion roster (right side)
- Assigned expeditions (bottom)
- Collect results section if there are pending results

```gdscript
class_name ExpeditionPanel
extends Control

signal panel_closed

# Theme colors (match project conventions)
const BG = Color(0.102, 0.122, 0.169)
const PANEL = Color(0.133, 0.157, 0.22)
const CARD = Color(0.165, 0.192, 0.27)
const TEXT = Color(0.941, 0.949, 0.973)
const SEC = Color(0.69, 0.722, 0.8)
const MUTED = Color(0.471, 0.51, 0.627)
const ACCENT = Color(0.788, 0.659, 0.298)
const GREEN = Color(0.292, 0.855, 0.498)
const RED = Color(0.937, 0.267, 0.267)

var _expedition_pool: Array = []          # Array of ExpeditionData
var _available_companions: Array = []     # Array of companion dicts
var _assignments: Dictionary = {}         # expedition_index → companion_name
var _pending_results: Array = []          # Array of {expedition, companion, loot} from last session

func _ready() -> void:
	_load_state()
	_build_ui()

func _load_state() -> void:
	# Load expedition pool — generate new if empty
	var saved = Global.get("_expedition_pool")
	if saved is Array and saved.size() > 0:
		_expedition_pool = []
		for d in saved:
			_expedition_pool.append(ExpeditionData.from_dict(d))
	else:
		_expedition_pool = ExpeditionManager.generate_pool(Global.Current_Region)

	# Load pending results from last session
	var results = Global.get("_expedition_results")
	if results is Array:
		_pending_results = results

	# Get idle companions (unlocked but not active)
	_available_companions = []
	for comp in Global.COMPANIONS.values():
		if comp.get("Unlocked", false) and not comp.get("Active", false):
			_available_companions.append(comp)

	# Max slots = ascension level
	var _max_slots: int = 0
	for char in Global.CHARACTERS.values():
		if str(char.get("User_Type", "")) != "Dungeon Master":
			_max_slots = maxi(_max_slots, int(char.get("Ascension_Rank", 0)))

func _build_ui() -> void:
	# Full-screen background
	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	bg.add_child(root)

	# Header with close button
	var header = _build_header(root)

	# Content
	var content = HBoxContainer.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	root.add_child(content)

	# Left: Available expeditions
	_build_expedition_list(content)
	# Right: Companion roster
	_build_companion_list(content)

	# Pending results section at top if there are results to collect
	if _pending_results.size() > 0:
		_build_results_section(root)

func _build_header(parent: VBoxContainer) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var title = Label.new()
	title.text = "EXPEDITIONS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(func(): panel_closed.emit())
	hbox.add_child(close_btn)

	return hbox

func _build_expedition_list(parent: HBoxContainer) -> void:
	var left = VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	parent.add_child(left)

	var header = Label.new()
	header.text = "Available Expeditions"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", TEXT)
	left.add_child(header)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for i in range(_expedition_pool.size()):
		var exp = _expedition_pool[i]
		_build_expedition_card(list, exp, i)

func _build_expedition_card(parent: VBoxContainer, exp: ExpeditionData, index: int) -> void:
	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = exp.expedition_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(name_label)

	var desc = Label.new()
	desc.text = "%s | %s risk | Best: %s, %s" % [exp.description, exp.risk_level, exp.bonus_weapon, exp.bonus_element]
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Assignment status
	var assigned_name = _assignments.get(index, "")
	if assigned_name != "":
		var assigned_label = Label.new()
		assigned_label.text = "Assigned: %s" % assigned_name
		assigned_label.add_theme_font_size_override("font_size", 13)
		assigned_label.add_theme_color_override("font_color", GREEN)
		vbox.add_child(assigned_label)

func _build_companion_list(parent: HBoxContainer) -> void:
	var right = VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	parent.add_child(right)

	var header = Label.new()
	header.text = "Idle Companions"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", TEXT)
	right.add_child(header)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for comp in _available_companions:
		var btn = Button.new()
		btn.text = "%s — %s %s (%s)" % [
			str(comp.get("Name", "")),
			str(comp.get("Element", "")),
			str(comp.get("Weapon", "")),
			str(comp.get("Region", "")),
		]
		btn.add_theme_font_size_override("font_size", 13)
		btn.custom_minimum_size = Vector2(0, 36)
		list.add_child(btn)

func _build_results_section(parent: VBoxContainer) -> void:
	# Show results from previous expedition assignments
	var header = Label.new()
	header.text = "EXPEDITION RESULTS"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", GREEN)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(header)
	# Results display — iterate _pending_results and show loot per companion
	for result in _pending_results:
		var loot: Dictionary = result.get("loot", {})
		var comp_name: String = str(result.get("companion", ""))
		var exp_name: String = str(result.get("expedition", ""))
		var result_label = Label.new()
		if loot.is_empty():
			result_label.text = "%s returned empty-handed from %s" % [comp_name, exp_name]
			result_label.add_theme_color_override("font_color", RED)
		else:
			var items_str = ", ".join(loot.keys().map(func(k): return "%s x%d" % [k, loot[k]]))
			result_label.text = "%s returned from %s: %s" % [comp_name, exp_name, items_str]
			result_label.add_theme_color_override("font_color", TEXT)
		result_label.add_theme_font_size_override("font_size", 13)
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(result_label)
```

Note: This is a scaffold — the full companion assignment interaction (drag-drop or click-to-assign) and the save/load of expedition state between sessions will need refinement during implementation. The core structure and data flow is defined here.

- [ ] **Step 3: Wire expedition panel into hub**

In `player_hub.gd`, replace the hidden Gather button with an Expeditions button, or repurpose it:

```gdscript
	# In _try_initial_setup(), replace the gather button hide with:
	var gather_btn = $"UI/BottomHotbar/HBoxContainer/Gather Button"
	if gather_btn:
		gather_btn.text = "Expeditions"
		# Disconnect old signal and connect new one
		if gather_btn.is_connected("pressed", _on_gather_button_pressed):
			gather_btn.disconnect("pressed", _on_gather_button_pressed)
		if not gather_btn.is_connected("pressed", _on_expeditions_button_pressed):
			gather_btn.connect("pressed", _on_expeditions_button_pressed)
```

Add the handler:

```gdscript
func _on_expeditions_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/UI/expedition_panel.tscn")
	var dlg = s.instantiate()

	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO

	dlg.panel_closed.connect(func(): win.queue_free())
	win.add_child(dlg)
	add_child(win)

	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
```

- [ ] **Step 4: Test expedition panel opens**

Run the game, verify:
- "Expeditions" button appears where Gather used to be
- Clicking it opens the expedition panel
- Panel shows generated expeditions and idle companions
- Close button works

- [ ] **Step 5: Commit**

```bash
git add Scripts/systems/expedition_data.gd Scripts/systems/expedition_manager.gd Scenes/UI/expedition_panel.gd Scenes/UI/expedition_panel.tscn Scenes/player_hub.gd
git commit -m "feat: add companion expedition panel with pool generation and companion bonuses"
```

### Task 13: Expedition Assignment & Processing

**Files:**
- Modify: `Scenes/UI/expedition_panel.gd` (assignment interaction + confirm/dispatch)
- Modify: `Singletons/Global.gd` (persist expedition state)

- [ ] **Step 1: Add expedition state to Global**

```gdscript
# Add to Global.gd
var _expedition_pool: Array = []          # Array of expedition dicts
var _expedition_assignments: Dictionary = {} # expedition_index → companion_name
var _expedition_results: Array = []       # Array of {expedition, companion, loot} pending collection
```

- [ ] **Step 2: Add click-to-assign interaction**

In the expedition panel, clicking a companion then clicking an expedition slot assigns them. Add selection state and assignment logic:

```gdscript
var _selected_companion: String = ""

func _select_companion(comp_name: String) -> void:
	_selected_companion = comp_name
	# Highlight selected companion in UI

func _assign_to_expedition(index: int) -> void:
	if _selected_companion == "":
		return
	# Check slot limit (ascension level)
	var max_slots = _get_max_slots()
	if _assignments.size() >= max_slots and index not in _assignments:
		Toast.notify("All expedition slots full (max %d)" % max_slots, Toast.WARNING)
		return
	_assignments[index] = _selected_companion
	_selected_companion = ""
	_save_state()
	_rebuild_ui()

func _get_max_slots() -> int:
	var max_asc: int = 0
	for char in Global.CHARACTERS.values():
		if str(char.get("User_Type", "")) != "Dungeon Master":
			max_asc = maxi(max_asc, int(char.get("Ascension_Rank", 0)))
	return maxi(max_asc, 1)

func _save_state() -> void:
	Global._expedition_pool = _expedition_pool.map(func(e): return e.to_dict())
	Global._expedition_assignments = _assignments.duplicate()
```

- [ ] **Step 3: Process expedition results on town entry**

When the party returns from battle (detected by `Global._returned_from_battle`), process any pending expedition assignments into results. Add this to `player_hub.gd` in the `_returned_from_battle` section:

```gdscript
	if Global.get("_returned_from_battle") == true:
		Global._returned_from_battle = false
		call_deferred("_deferred_market_refresh")
		# Process expedition returns
		if NetworkManager.is_host:
			_process_expedition_returns()
```

```gdscript
func _process_expedition_returns() -> void:
	var assignments: Dictionary = Global.get("_expedition_assignments")
	if not assignments is Dictionary or assignments.is_empty():
		return
	var pool: Array = Global.get("_expedition_pool")
	if not pool is Array:
		return
	var results: Array = []
	for idx_str in assignments:
		var idx = int(idx_str)
		if idx >= pool.size():
			continue
		var exp = ExpeditionData.from_dict(pool[idx])
		var comp_name: String = str(assignments[idx_str])
		# Find companion data
		var comp_data: Dictionary = {}
		for comp in Global.COMPANIONS.values():
			if str(comp.get("Name", "")) == comp_name:
				comp_data = comp
				break
		if comp_data.is_empty():
			continue
		var loot = ExpeditionManager.process_results(exp, comp_data)
		results.append({"expedition": exp.expedition_name, "companion": comp_name, "loot": loot})
		# Persist loot to inventory
		for mat_name in loot:
			# Upsert into first player's inventory (expedition loot is shared)
			# Or could go to a "party stash" — implementation detail
			_upsert_expedition_loot(mat_name, loot[mat_name])
	Global._expedition_results = results
	# Clear assignments and pool for fresh generation
	Global._expedition_assignments = {}
	Global._expedition_pool = []

func _upsert_expedition_loot(mat_name: String, qty: int) -> void:
	# Add to first non-DM player's inventory (simplest approach)
	var target_name = ""
	for char in Global.CHARACTERS.values():
		if str(char.get("User_Type", "")) != "Dungeon Master":
			target_name = str(char.get("Name", ""))
			break
	if target_name == "":
		return
	for item in Global.CHARACTER_ITEMS.values():
		if str(item.get("Character_Name", "")) == target_name and str(item.get("Item", "")) == mat_name:
			var old_qty = int(item.get("Quantity", 0))
			Global.Update_Records([{"table": "Character_Items", "record_id": int(item.get("id", 0)), "field": "Quantity", "value": old_qty + qty}])
			return
	var item_def = GameDB.items_by_name.get(mat_name, null)
	Global.Insert("Character_Items",
		["Character_Name", "Item", "Quantity", "Type", "Rarity", "Description"],
		[target_name, mat_name, qty, item_def.type if item_def else "Material", item_def.rarity if item_def else "Common", item_def.description if item_def else ""])
```

- [ ] **Step 4: Test full expedition loop**

1. Open expedition panel, assign companions to expeditions
2. Start and complete a battle
3. Return to hub — expedition results should be processed
4. Open expedition panel — results shown, fresh pool generated

- [ ] **Step 5: Commit**

```bash
git add Scenes/UI/expedition_panel.gd Scenes/player_hub.gd Singletons/Global.gd
git commit -m "feat: companion expedition assignment, dispatch, and result processing"
```

---

## Phase 5: Wire Up Food Buffs

### Task 14: Create Food Buff → GameEffect Mapping

**Files:**
- Create: `Scripts/systems/food_buff_effects.gd`

- [ ] **Step 1: Create food buff effect definitions**

Map each known food buff to GameEffect instances that the EffectProcessor can handle:

```gdscript
class_name FoodBuffEffects
extends RefCounted

## Returns Array of GameEffect for the given food buff name.
## Returns empty array if buff is unknown.
static func get_effects(buff_name: String) -> Array:
	match buff_name:
		"Candied Ajilenakh Nut":
			# +3 ATT all party
			return [_stat_bonus("attack", 3.0)]
		"Padisarah Pudding":
			# +3 EM all party
			return [_stat_bonus("elemental_mastery", 3.0)]
		"Aaru Mixed Rice":
			# +2 to all attack rolls
			return [_roll_bonus(2.0)]
		"Biryani":
			# +2 damage all attacks, all party
			return [_flat_damage(2.0)]
		"Shawarma Wrap":
			# -2 damage taken per hit, all party
			return [_damage_reduction(2.0)]
		"Lambad Fish Roll":
			# 2 HP/turn for 10 turns
			return [_heal_per_turn(2.0, 10)]
		"Sabza Meat Stew":
			# Restore 1d12 Burst Charges — instant, handled separately
			return [_burst_restore("1d12")]
		"Tahchin":
			# Was "double gathering" — now bonus expedition returns
			# This is handled in ExpeditionManager, not in combat
			return []
		_:
			return []

static func _stat_bonus(stat: String, value: float) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.condition = "NONE"
	e.effect_type = "STAT_BONUS"
	e.effect_stat = stat
	e.effect_value = value
	e.target = "ALL_ALLIES"
	e.duration = -1  # Lasts whole battle
	e.description = "+%d %s (food)" % [int(value), stat]
	e.effect_id = "food_buff_%s" % stat
	return e

static func _roll_bonus(value: float) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "PASSIVE"
	e.condition = "NONE"
	e.effect_type = "STAT_BONUS"
	e.effect_stat = "attack_roll"
	e.effect_value = value
	e.target = "ALL_ALLIES"
	e.duration = -1
	e.description = "+%d attack rolls (food)" % int(value)
	e.effect_id = "food_buff_roll"
	return e

static func _flat_damage(value: float) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_HIT"
	e.condition = "NONE"
	e.effect_type = "FLAT_DAMAGE"
	e.effect_value = value
	e.target = "SELF"
	e.duration = -1
	e.description = "+%d damage (food)" % int(value)
	e.effect_id = "food_buff_damage"
	return e

static func _damage_reduction(value: float) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ON_DAMAGE_TAKEN"
	e.condition = "NONE"
	e.effect_type = "DAMAGE_REDUCTION"
	e.effect_value = value
	e.target = "SELF"
	e.duration = -1
	e.description = "-%d damage taken (food)" % int(value)
	e.effect_id = "food_buff_reduction"
	return e

static func _heal_per_turn(value: float, turns: int) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "START_OF_TURN"
	e.condition = "NONE"
	e.effect_type = "HEAL"
	e.effect_value = value
	e.target = "SELF"
	e.duration = turns
	e.description = "Heal %d HP/turn (food)" % int(value)
	e.effect_id = "food_buff_heal"
	return e

static func _burst_restore(dice: String) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = "ONCE_PER_BATTLE"
	e.condition = "NONE"
	e.effect_type = "BURST_CHARGE_GAIN"
	e.effect_dice = dice
	e.target = "SELF"
	e.duration = 0  # Instant
	e.description = "Restore %s burst charges (food)" % dice
	e.effect_id = "food_buff_burst"
	return e
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/systems/food_buff_effects.gd
git commit -m "feat: add FoodBuffEffects — maps food buff names to GameEffect definitions"
```

### Task 15: Register Food Buffs in EffectProcessor at Battle Start

**Files:**
- Modify: `Singletons/Global.gd` (`start_battle_effects`)

- [ ] **Step 1: Register food buff effects when battle starts**

In `Global.start_battle_effects()`, after existing effect registration, check for an active food buff and register its effects on all party members:

```gdscript
# Add to start_battle_effects(), after existing registrations:
	var food_buff_name = str(Current_Party.get("Active_Food_Buff", "None"))
	if food_buff_name != "None" and food_buff_name != "":
		var food_effects = FoodBuffEffects.get_effects(food_buff_name)
		if food_effects.size() > 0:
			for player_name in PartyCharacters:
				for fe in food_effects:
					effect_processor.add_effect(player_name, fe, "food", food_buff_name)
			# Also apply to active companions
			for comp_name in PartyCompanions:
				for fe in food_effects:
					effect_processor.add_effect(comp_name, fe, "food", food_buff_name)
```

- [ ] **Step 2: Test food buffs in combat**

1. Craft and activate "Candied Ajilenakh Nut" (+3 ATT) before battle
2. Start battle
3. Check that all party members have +3 ATT in their stat calculations
4. Verify buff_battles_left decrements after battle ends (already implemented in `_host_battle_cleanup`)

- [ ] **Step 3: Commit**

```bash
git add Singletons/Global.gd
git commit -m "feat: register active food buff effects in EffectProcessor at battle start"
```

---

## Summary & Dependencies

```
Phase 1 (Role Rotation)        → Tasks 1-3  — No dependencies
Phase 2 (Combat Loot)          → Tasks 4-6  — No dependencies
Phase 3 (Challenge Quests)     → Tasks 7-10 — Depends on Phase 2 (loot generator)
Phase 4 (Companion Expeditions)→ Tasks 11-13— No dependencies (uses LootGenerator utils)
Phase 5 (Food Buff Wiring)     → Tasks 14-15— No dependencies
```

Phases 1, 2, 4, and 5 can be implemented in parallel. Phase 3 depends on Phase 2's LootGenerator being complete.
