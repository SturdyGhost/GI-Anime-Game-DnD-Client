---
title: UI Rebuild & Artifact Forge
date: 2026-04-03
tags: [feature, ui, crafting, battle, accessibility, networking]
scope: BattleScene.gd, CraftingMenu.gd, party_card.gd, enemy_card.gd, character_profile.gd, CompanionsOverview.gd, weapon_detail_scene.gd, artifact_detail_scene.gd, MarketPanel.gd, PlayerInventory.gd, settings_popup.gd, player_battle_prep.gd, battle_logger.gd, battle_summary.gd, turn_processor.gd, test_scene.gd, crafting_recipe_data.gd
status: complete
---

# UI Rebuild & Artifact Forge

## Overview

Full ground-up rebuild of the game's UI and battle system. All scenes now use
dark-themed, programmatically-built layouts with resizable panels, layout
persistence, accessibility-friendly font sizes, and confirmation popups for
destructive actions.

## Battle System

### Unified Battle Scene (BattleScene.gd)
- Replaced 4 separate battle scenes (dm_battle_scene, Enemy_Battle_Scene,
  Player_Battle_Scene, player_hub_mid_battle) with a single BattleScene
- 3-column layout with 9+ resizable HSplitContainer/VSplitContainer panels
- All UI built programmatically in `_build_ui()` (no .tscn node dependencies)
- Layout positions persist to `user://battle_layout.cfg`
- Turn visibility logic: players see their own turns and companion turns,
  host sees all turns

### Turn Processor (turn_processor.gd)
- Pure static methods for turn processing
- `process_turn(input)` returns Array of update dicts
- Fixes: burst charge race condition (cost_subtracted param), ALL_ENEMIES
  effects loop all targets, shield exact-match uses `<=`, status effects
  duplicate GameEffect per target to avoid shared mutation

### Battle Logger & Summary
- Per-battle log files at `user://data/battles/[id]/`
- Pre-initializes all battlers from `Global.BattlerData`
- Summary broadcast to all players via `NetworkManager.broadcast_battle_summary()`
- Summary screen shows per-combatant stats, highlights highest damage dealer

### Health Sync with Effects
- `_sync_health_with_effects()` adjusts HP proportionally when effects change
  max HP (e.g. weapon passive +30% HP applying/expiring)

## Crafting System

### Gem Crafting Recipes
- 35 `.tres` recipe files (IDs 300-334) in `data/resources/crafting_recipes/`
- 3-star and 4-star upgrades for all 7 elements
- Downgrades: 3-to-2, 4-to-3, 2-to-1 for all 7 elements
- Generic material matching ("2-Star Gem" matches any element)
- `output_quantity` field on CraftingRecipeData (default 1, >1 for downgrades)

### Recipe Variant System
- Products with multiple recipes grouped under single list entry
- Expanding a product shows all available recipe variants
- Filter chips: All / Craftable / Missing

### Artifact Forge (CraftingMenu.gd, Artisan role only)
- Two modes: Random Set (sacrifice 2) and Choose Set (sacrifice 3)
- Dice roll fields matching DMHub artifact generator mechanics:
  - Step 1: D12 piece type, D20 substat count
  - Step 2: D8 or D10 stat type (contextual based on piece), D12 sign, D20 value
  - Step 3: Same as Step 2 (enabled when D20 >= 13)
- D10 stat mapping (Sands/Goblet/Circlet): 1-2 HP, 3-4 ATK, 5-7 DEF,
  8-9 EM, 10 special (Energy Recharge / Damage Bonus / Crit Damage)
- D8 stat mapping (Flower/Feather): 1-2 HP, 3-4 ATK, 5-6 DEF, 7-8 EM
- Roll labels dynamically show dice type (D8 vs D10) based on piece type
- SpinBox max value adjusts with piece type (8 vs 10)
- Confirmation popup with bold warning for high-value artifact sacrifice
- Resizable dividers between sacrifice picker, rolls panel, and target/forge
  section with layout persistence to `user://ui_settings.cfg`
- Set bonus preview with expandable cards (min 80px height)

## Popup Scene Rebuilds

### Character Profile (character_profile.gd)
- Portrait picker as popup overlay (96x96 thumbnails)
- Saves filename only (not full path) for Portrait field
- Constellation sub-tabs self-contained via `_populate_constellation_content()`
- Talents filtered to current element
- Close button z_index=10 so it renders on top

### Companions Overview (CompanionsOverview.gd)
- Three companion states: Player Chosen, DM Set (Always Active), Inactive
- Companion limit enforcement (drops oldest player-chosen)
- Large portrait (280x280) next to scrollable lore
- Resizable splits with persistence

### Weapon & Artifact Detail Scenes
- Lighter blue color palette
- Per-column filter popovers
- Stat comparison showing character stat changes
- Artifact set bonus preview (piece count transition + gained/lost bonuses)
- Confirmation popups for give/equip/unequip

### Market Panel (MarketPanel.gd)
- Nested HSplitContainers for proper 3-panel layout
- Fixed preview visibility bug
- Stock refresh only on battle return (not every hub load)

### Player Inventory (PlayerInventory.gd)
- Dynamic type chips from actual item types
- HFlowContainer for wrapping chips

## Accessibility & Settings

### Font Scaling (settings_popup.gd)
- Font scale slider (50-150%, default 100%)
- `scaled_font(base_size)` static helper used throughout all scenes
- Persists to `user://ui_settings.cfg`

### Volume Control
- Volume slider (0-100, default muted)
- Persists to `user://audio_settings.cfg`

### Minimum Font Sizes
- All UI text minimum 13-14px
- Battle cards, tooltips, and labels scale with font setting

## Resizable Layouts

All resizable split containers persist positions to ConfigFile:
- Battle: `user://battle_layout.cfg` (9+ splits)
- Crafting: `user://ui_settings.cfg` section `crafting_layout`
  - `body_split`: recipe list vs detail panel
  - `right_split`: detail vs requirements
  - `af_body_split`: sacrifice picker vs rolls+target
  - `af_rolls_split`: rolls panel vs target/forge
- Weapons/Artifacts: `user://ui_settings.cfg` section `weapon_layout` / `artifact_layout`
- Companions: `user://ui_settings.cfg` section `companion_layout`

## Battle Prep (player_battle_prep.gd)
- Turn order built inline (not using TurnOrderPanel.gd)
- Includes all active companions (player-chosen + DM-set)
- Ready toggle and consumable dropdown disabled for other players
- Food buff only shows items with "battle" in description
- Turn order syncs in real-time via `data_load_complete`
- Back to Hub button

## Networking

### RPC Path Mismatch Fix
- Host BattleScene at `DMHub/BattleScene` vs client at `/root/BattleScene`
- Fixed by using NetworkManager signals instead of direct scene RPCs
- Added `combat_log_received` and `battle_summary_received` signals

### Stun Skip RPC
- Client sends `stun_skip` RPC to host since client can't call effect_processor
- Host decrements stun duration and advances turn

## Test Coverage (test_scene.gd)

### New Test Group 8: Crafting & Artifact Forge
- Crafting recipes loaded from GameDB
- Recipe data field validation (product, material, quantity, output_quantity)
- Gem upgrade/downgrade recipe existence and output quantities
- Artifact forge piece resolution: all 12 D12 rolls map correctly
- Artifact forge stat resolution: D8 basic (8 rolls) and D10 special (10 rolls)
- Special piece roll-10 mapping per piece type (Sands/Goblet/Circlet)
- Dice boundary overflow: out-of-range rolls return fallback stat

## Key Bug Fixes
- `:=` type inference removed everywhere (project convention: always use `=`)
- `int(null)` crashes guarded with default values on all `.get()` calls
- Gold buttons changed to outline style (gold border + gold text on transparent)
- Portrait `EXPAND_KEEP_SIZE` changed to `EXPAND_IGNORE_SIZE`
- Portrait saves filename only (not full path)
- Burst charge race condition fixed with `cost_subtracted` parameter
- ALL_ENEMIES and status effects loop all targets (not just first)
- GameEffect `.duplicate()` prevents shared resource mutation
- Stun duration reads from ability's `duration_rounds` instead of hardcoded 1
- Shield exact-match uses `<=` instead of `<`
- Market preview visibility flags restored after init
- HSplitContainer with 3 children fixed with nested splits
- Companion green border uses correct color constant
- DAMAGE_REDUCTION removed from harmful effects list
- Battle logger pre-populates combatants from BattlerData
