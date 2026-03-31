---
title: Battle End Detection & Cleanup Overhaul
date: 2026-03-30
tags: [bugfix, combat, networking, performance]
scope: Player_Battle_Scene.gd, Enemy_Battle_Scene.gd, player_hub_mid_battle.gd, enemy_hub_mid_battle.gd, NetworkManager.gd, player_hub.gd
status: complete
---

# Battle End Detection & Cleanup Overhaul

## Problems Solved

### 1. Infinite recursion on battle end
- `check_battle_end()` -> `Remove_Record` -> `host_remove` -> `data_load_complete`
  -> `_on_data_load_complete` -> `check_battle_end()` -> loop
- Fix: `_battle_ending` guard flag prevents re-entry

### 2. HP-based detection replaces "Killed" checkbox
- Old: relied on manual `Killed` boolean set by players
- New: checks `Current_Health == 0` for all enemies/players
- No more manual killed checkbox needed in the turn UI

### 3. Host-only cleanup
- Only the host removes enemies, resets cooldowns, restores health, clears
  elements, resets ready/skipped status
- Clients detect battle end and transition, but do NO cleanup operations
- Prevents duplicate broadcasts and race conditions

### 4. Reduced broadcast flood
- Old: each `Remove_Record` per enemy triggered a full `broadcast_table_update`
  (N enemies = N full table broadcasts)
- New: enemies removed locally via `_remove_record` (no broadcast per enemy),
  then ONE `broadcast_table_update("BattleEnemies")` at the end

### 5. Dangling signal connections caused host freeze
- Battle scenes connected to `Global.data_load_complete` via `Global.connect()`
- When scene changed, connections persisted on freed nodes
- Each `data_load_complete` during cleanup tried to call freed objects, blocking
- Fix: all 4 battle scripts disconnect via `tree_exiting` signal before being freed

### 6. Cascade peer disconnection
- Host paused game tree (`get_tree().paused = true`) on ANY peer disconnect
- During transition, one peer briefly drops -> host pauses -> others time out -> cascade
- Fix: removed game pause on disconnect, added auto-reconnect for clients

### 7. Clients sent unnecessary Update_Records
- `restore_health()` in player_hub ran on clients, sending 5 updates each to host
- Fix: `restore_health()` now host-only

## Cleanup Operations (host-only)
- Remove all BattleEnemies records
- Reset ability cooldowns to 0
- Set Ready=false, Skipped=false on ALL characters (including DM)
- Restore Current_Health to Max_Health on all characters
- Clear Applied_Element to "None" on all characters and companions
- Decrement food buff battles remaining
- Clear effect processor and broadcast empty ActiveEffects

## Scene Transition
- Host: cleanup -> transition directly to DMHub
- Clients: await `data_load_complete` (receives cleanup) -> transition to player_hub
- Skips loading screen entirely (data already present)
