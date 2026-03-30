---
title: Network Sync & Data Architecture Overhaul
date: 2026-03-29
tags: [networking, data-sync, architecture, bugfix, performance]
scope: Global.gd, NetworkManager.gd, CharacterManager, player_hub.gd
status: complete
---

# Network Sync & Data Architecture Overhaul

## Problem

Clients joining a multiplayer session had no data. The host sent all 13 tables over ENet,
but `Global._process_table()` only stored 4 of them (Characters, Companions, BattleEnemies,
Active_Status_Effects). The other 9 tables (Character_Weapons, Character_Artifacts,
Character_Items, Party, Talents, Constellations, Active_Abilities, Game_Config,
Minigames_Results) were received and silently dropped.

Property getters for these tables went straight to `SaveManager`, which is `null` on clients
(only the host loads save data). Result: empty dicts everywhere on the client.

## Solution: `_synced` as Single Source of Truth

Replaced all scattered legacy fallback dicts (`_legacy_characters`, `_legacy_companions`,
`_battleenemies_fallback`, etc.) with two unified dictionaries:

```gdscript
var _synced: Dictionary = {}       # { "TableName": { "rid": {record}, ... } }
var _synced_name: Dictionary = {}  # { "TableName": { "Name": "rid", ... } }
```

### How it works

1. **Host loads data** from JSON via `DataStore.load_all_tables()` -> `_process_table()` populates `_synced`
2. **Host sends tables** to clients via `_receive_table_sync` RPC
3. **Client receives** -> `_process_table()` populates `_synced` with the host's data
4. **All property getters** (CHARACTERS, CHARACTER_WEAPONS, PARTY, etc.) check `_synced` first

### Files changed

- **Global.gd**: Removed 4 legacy fallback dicts. Added `_synced`/`_synced_name`. Rewrote
  `_process_table()` to generically store all tables. Updated every property getter to
  check `_synced` first. Updated `_apply_update_to_save()` to always write to `_synced`
  (both host and client), plus typed Resources on host.
- **NetworkManager.gd**: No changes to sync protocol itself; the existing `_receive_table_sync`
  now works for all tables because `_process_table` stores everything.

## Field-Level Delta Broadcasts

Previously, any field change (e.g., changing element) triggered `broadcast_table_update()`
which re-serialized and sent the ENTIRE table to all clients.

Added `broadcast_field_updates()` which sends only the changed fields:

```gdscript
# Host side
func broadcast_field_updates(updates: Array) -> void:
    _receive_field_updates.rpc(JSON.stringify(updates))

# Client side
@rpc("authority", "reliable")
func _receive_field_updates(json_str: String) -> void:
    for u in updates:
        Global._apply_update_to_save(u)
    CharacterManager.recalculate_all()
    Global.emit_signal("data_load_complete")
```

Both `host_update_records()` and `request_update()` now use field-level deltas instead of
full table broadcasts.

## Client-Side Stat Calculation

`CharacterManager.calculate_stats()` previously only worked with typed Resources from
SaveManager (host-only). Added `_calculate_from_synced()` which runs the same stat pipeline
using raw dict data from `_synced`:

- Base stats: `(Base_Points + Skill_Points) * scaling`
  - Health: 2.0x, Attack/Defense/EM: 1.0x, ER/CD: 0.1x
- Weapon stats from `_synced["Character_Weapons"]`
- Artifact stats from `_synced["Character_Artifacts"]`
- Set bonuses (2pc/4pc) from `GameDB.get_artifact_bonus()`

`recalculate_all()` iterates `_synced_name["Characters"]` on clients instead of
`SaveManager.get_all_players()`.
