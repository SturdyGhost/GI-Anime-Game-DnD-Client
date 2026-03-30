---
title: Null Safety & Crash Fixes
date: 2026-03-29
tags: [bugfix, null-safety, crash-fix]
scope: NetworkManager.gd, player_hub.gd, weapon_button.gd, weapon_preview.gd, tabs.gd, character_manager.gd
status: complete
---

# Null Safety & Crash Fixes

## Overview

Multiple crashes occurred because scenes ran before data was loaded, or because
JSON-parsed values had unexpected types (null, float instead of int).

## Fixes by File

### NetworkManager.gd (lines 82, 327)
- **Crash:** `Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]` — key didn't exist yet
- **Fix:** Replaced with region read from `Current_Party` (region is now party-wide)

### player_hub.gd
- **Crash:** `set_ui()`, `role_check()`, `restore_health()` all called from `_ready()` before
  data was loaded
- **Fix:** All expensive setup moved to `_try_initial_setup()` which checks
  `Global.CHARACTERS_NAME.has(ACTIVE_USER_NAME)` before proceeding. Runs once via
  `_initial_setup_done` flag. `_on_data_load_complete` triggers it if not yet done,
  otherwise just refreshes `set_ui()`.
- **Crash:** Division by zero in average health calculation when `PartyCharacters` was empty
- **Fix:** `max(PartyCharacters.size(), 1)`
- **Crash:** `Universal_*` `.get()` calls in `_apply_stat()` had no default values
- **Fix:** Added `0` / `0.0` defaults to all four Universal stat bonus lookups
- **Crash:** `set_stats()` used `Global.CHARACTERS[Global.CHARACTERS_NAME[...]]` bracket access
- **Fix:** Changed to safe `.get()` chain

### weapon_button.gd (line 67)
- **Crash:** `Weapon_Data.has("Effect")` — `Weapon_Data` was null (no equipped weapon found)
- **Fix:** Early `return` if `Weapon_Data == null`

### weapon_preview.gd (line 23)
- **Crash:** `weapon["Stat_1_Type"]` — weapon dict was empty
- **Fix:** Early return if `weapon.is_empty()`. All bracket access converted to `.get()`.
  `Global.Current_Weapon` access guarded with null/empty check.

### tabs.gd (lines 45, 117)
- **Crash:** `int(ability.get("Entity_ID", 0))` — value was null, `int(null)` crashes
- **Fix:** Null-check before `int()` cast
- **Crash:** `Global.ABILITIES[str(int(ability.get("Ability_ID", 0)))]` — same null issue,
  plus float-to-string key mismatch (`"409.0"` vs `"409"`)
- **Fix:** Null guard + `.get()` with empty check + `continue` on miss

### character_manager.gd
- **Crash:** `wstat.to_lower()` / `astat.to_lower()` — JSON null values
- **Fix:** Wrapped with `str()` so null becomes `""` safely
